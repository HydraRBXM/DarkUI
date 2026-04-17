local EspPlayers       = game:GetService("Players")
local EspRunService    = game:GetService("RunService")
local EspCamera        = workspace.CurrentCamera
local EspLocalPlayer   = EspPlayers.LocalPlayer
local UserInputService = game:GetService("UserInputService")

print("CometESP starting (Hybrid build)")

-- ═══════════════════════════════════════════
--  GUI LAYERS  (only for fill + healthbar)
-- ═══════════════════════════════════════════
local EspGui = Instance.new("ScreenGui")
EspGui.Name            = "CometESP"
EspGui.ResetOnSpawn    = false
EspGui.IgnoreGuiInset  = true
EspGui.DisplayOrder    = 9997
EspGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
EspGui.Parent          = (caninjectinto_COREGUI and game.CoreGui) or EspLocalPlayer.PlayerGui

-- ═══════════════════════════════════════════
--  HIGHLIGHT FOLDER
-- ═══════════════════════════════════════════
local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name   = game:GetService("HttpService"):GenerateGUID(true)
HighlightFolder.Parent = workspace

-- ═══════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════
local EspObjects    = {}
local EspRainbowHue = 0
local EspPulseTimer = 0
local sharedEsp     = shared.Esp or nil
local _frameColor   = Color3.new(1, 1, 1)  -- computed once per heartbeat

-- ═══════════════════════════════════════════
--  FONT MAP
-- ═══════════════════════════════════════════
local FontMap = {
    ['Proggy Clean'] = Drawing.Fonts.Monospace,
    ['GothamBold']   = Drawing.Fonts.UI,
    ['Arial']        = Drawing.Fonts.UI,
    ['Code']         = Drawing.Fonts.Monospace,
    ['Pixel Arial']  = Drawing.Fonts.Monospace,
}
local function GetEspFont()
    return FontMap[sharedEsp.EspFont.Value] or Drawing.Fonts.UI
end

local function GetNameStr(player)
    local t = sharedEsp.EspNameType.Value
    if t == 'Display Name' then return player.DisplayName end
    return player.Name
end

-- ═══════════════════════════════════════════
--  COLORING
-- ═══════════════════════════════════════════
local function ComputeColor(baseColor)
    local mode = sharedEsp['ESP Coloring'].Value
    if mode == 'Rainbow' then
        return Color3.fromHSV(EspRainbowHue, 1, 1)
    elseif mode == 'Gradient' then
        return Color3.fromHSV((EspRainbowHue + 0.33) % 1, 0.85, 1)
    elseif mode == 'Pulse' then
        local t = (EspPulseTimer % 1.5) / 1.5
        return sharedEsp.EspPulseColor.Value:Lerp(Color3.new(1,1,1), math.abs(math.sin(t * math.pi)))
    elseif mode == 'Custom Color' then
        return sharedEsp.EspCustomColor.Value
    elseif mode == 'Team Color' then
        local team = EspLocalPlayer.Team
        return team and team.TeamColor.Color or baseColor
    end
    return baseColor
end

-- ═══════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════
local function EspIsAlive(char)
    if not char or not char.Parent then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function EspIsTeammate(player)
    if sharedEsp.EspIncludeTeammates.Value then return false end
    return player.Team ~= nil and player.Team == EspLocalPlayer.Team
end

local function GetDist(hrpA, hrpB)
    return math.floor((hrpA.Position - hrpB.Position).Magnitude)
end

local function GetHealthPct(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return 1 end
    return math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
end

-- ═══════════════════════════════════════════
--  BOUNDS
-- ═══════════════════════════════════════════
local function GetBoundsFixed(char, cam)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return nil end
    local topSP, topOn = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
    local botSP, botOn = cam:WorldToViewportPoint(hrp.Position  - Vector3.new(0, hrp.Size.Y  * 0.5, 0))
    if not topOn or not botOn or topSP.Z <= 0 or botSP.Z <= 0 then return nil end
    local h = botSP.Y - topSP.Y
    if h <= 2 then return nil end
    local w = h * 0.6 * (sharedEsp.EspFixedWidthScaler.Value / 100)
    return topSP.X - w * 0.5, topSP.Y, w, h
end

local function GetBoundsAccurate(char, cam)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return nil end
    local topSP, topOn = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
    local botSP, botOn = cam:WorldToViewportPoint(hrp.Position  - Vector3.new(0, hrp.Size.Y  * 0.5, 0))
    if not topOn or not botOn or topSP.Z <= 0 or botSP.Z <= 0 then return nil end
    local h = botSP.Y - topSP.Y
    if h <= 2 then return nil end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local w
    if torso then
        local halfW = torso.Size.X * 0.5
        local root  = hrp.CFrame
        local lSP   = cam:WorldToViewportPoint((root * CFrame.new(-halfW, 0, 0)).Position)
        local rSP   = cam:WorldToViewportPoint((root * CFrame.new( halfW, 0, 0)).Position)
        w = math.clamp(math.abs(rSP.X - lSP.X), h * 0.25, h * 1.5)
    else
        w = h * 0.6
    end
    return topSP.X - w * 0.5, topSP.Y, w, h
end

local _SIGNS = {
    Vector3.new( 1, 1, 1), Vector3.new(-1, 1, 1),
    Vector3.new( 1,-1, 1), Vector3.new(-1,-1, 1),
    Vector3.new( 1, 1,-1), Vector3.new(-1, 1,-1),
    Vector3.new( 1,-1,-1), Vector3.new(-1,-1,-1),
}
local function GetBoundsAutomatic(char, cam)
    local minX, minY, maxX, maxY
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local cf, hs = part.CFrame, part.Size * 0.5
            for _, s in ipairs(_SIGNS) do
                local sp, on = cam:WorldToViewportPoint((cf * CFrame.new(hs * s)).Position)
                if on and sp.Z > 0 then
                    minX = math.min(minX or sp.X, sp.X)
                    minY = math.min(minY or sp.Y, sp.Y)
                    maxX = math.max(maxX or sp.X, sp.X)
                    maxY = math.max(maxY or sp.Y, sp.Y)
                end
            end
        end
    end
    if not minX then return nil end
    local w, h = maxX - minX, maxY - minY
    if w <= 2 or h <= 2 then return nil end
    return minX - 4, minY - 4, w + 8, h + 8
end

local function GetBounds(char, cam)
    local mode = sharedEsp.EspBoundingMode.Value
    if     mode == 'Fixed'    then return GetBoundsFixed(char, cam)
    elseif mode == 'Accurate' then return GetBoundsAccurate(char, cam)
    else                           return GetBoundsAutomatic(char, cam) end
end

-- ═══════════════════════════════════════════
--  TRACER ORIGIN
-- ═══════════════════════════════════════════
local function GetTracerOrigin(vp)
    local mode = sharedEsp.TracerAttachmentPoint.Value
    if     mode == "BottomScreen"  then return Vector2.new(vp.X * 0.5, vp.Y)
    elseif mode == "CenterScreen"  then return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    elseif mode == "TopScreen"     then return Vector2.new(vp.X * 0.5, 0)
    elseif mode == "Mouse"         then
        local m = UserInputService:GetMouseLocation()
        return Vector2.new(m.X, m.Y)
    end
    return Vector2.new(vp.X * 0.5, vp.Y)
end

-- ═══════════════════════════════════════════
--  FACTORY HELPERS
-- ═══════════════════════════════════════════
local function NewLine(thickness, color)
    local l = Drawing.new("Line")
    l.Thickness = thickness or 1
    l.Color     = color or Color3.new(1, 1, 1)
    l.Visible   = false
    return l
end

local function NewText(size)
    local t = Drawing.new("Text")
    t.Size         = size or 13
    t.Font         = Drawing.Fonts.UI
    t.Color        = Color3.new(1, 1, 1)
    t.Outline      = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Center       = true
    t.Visible      = false
    return t
end

local function NewCircle(thickness, color)
    local c = Drawing.new("Circle")
    c.Thickness = thickness or 1.5
    c.Color     = color or Color3.new(1, 1, 1)
    c.Filled    = false
    c.Visible   = false
    return c
end

local function NewQuad(color)
    local q = Drawing.new("Quad")
    q.Color     = color or Color3.new(1, 1, 1)
    q.Filled    = false
    q.Thickness = 1.5
    q.Visible   = false
    return q
end

-- Frame helpers (only used for fill + healthbar)
local function NewFrame(parent, zindex)
    local f = Instance.new("Frame")
    f.BackgroundColor3       = Color3.new(1, 1, 1)
    f.BorderSizePixel        = 0
    f.BackgroundTransparency = 0
    f.Visible                = false
    f.ZIndex                 = zindex or 5
    f.Parent                 = parent or EspGui
    return f
end

-- ═══════════════════════════════════════════
--  BONE TABLES
-- ═══════════════════════════════════════════
local BONES_R15 = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},  {"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},    {"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},  {"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},    {"RightLowerArm","RightHand"},
}
local BONES_R6 = {
    {"Head","Torso"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}
local MAX_BONES = math.max(#BONES_R15, #BONES_R6)

-- ═══════════════════════════════════════════
--  CREATE ESP
-- ═══════════════════════════════════════════
local function CreateEsp(player)
    if EspObjects[player] then return end

    -- Corner box: 8 Drawing Lines
    local cornerLines = {}
    for i = 1, 8 do cornerLines[i] = NewLine(1.5) end

    -- Full box: Drawing Quad (no UIStroke overhead)
    local boxQuad = NewQuad()

    -- Circle mode
    local circleD = NewCircle(1.5)

    -- Fill: Frame (Drawing filled shapes unreliable cross-executor)
    local fillFrame = NewFrame(EspGui, 4)
    fillFrame.BackgroundTransparency = 0.5

    -- Healthbar: 2 Frames (tiny count, negligible cost)
    local hbBg   = NewFrame(EspGui, 5)
    hbBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    local hbFill = NewFrame(hbBg, 6)
    hbFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

    -- Skeleton: Drawing Lines (native, fast)
    local skeleton = {}
    for i = 1, MAX_BONES do skeleton[i] = NewLine(1) end

    -- Name + Distance: Drawing Text
    local nameText = NewText(13)
    local distText = NewText(11)
    distText.Color = Color3.fromRGB(180, 180, 180)

    -- Tracer: outline + colored line
    local tracerOutline = NewLine(3, Color3.new(0, 0, 0))
    tracerOutline.Transparency = 0.5
    local tracerLine = NewLine(1)

    -- Highlight (Instance — no Drawing equivalent exists)
    local hl = Instance.new("Highlight")
    hl.FillTransparency    = 1
    hl.OutlineTransparency = 0
    hl.Enabled             = false
    hl.Parent              = HighlightFolder

    EspObjects[player] = {
        cornerLines   = cornerLines,
        boxQuad       = boxQuad,
        circleD       = circleD,
        fillFrame     = fillFrame,
        hbBg          = hbBg,
        hbFill        = hbFill,
        skeleton      = skeleton,
        nameText      = nameText,
        distText      = distText,
        tracerOutline = tracerOutline,
        tracerLine    = tracerLine,
        highlight     = hl,
    }
end

-- ═══════════════════════════════════════════
--  DESTROY ESP
-- ═══════════════════════════════════════════
local function DestroyEsp(player)
    local obj = EspObjects[player]
    if not obj then return end
    for _, l in ipairs(obj.cornerLines) do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.skeleton)    do pcall(function() l:Remove() end) end
    pcall(function() obj.boxQuad:Remove()       end)
    pcall(function() obj.circleD:Remove()       end)
    pcall(function() obj.nameText:Remove()      end)
    pcall(function() obj.distText:Remove()      end)
    pcall(function() obj.tracerOutline:Remove() end)
    pcall(function() obj.tracerLine:Remove()    end)
    pcall(function() obj.fillFrame:Destroy()    end)
    pcall(function() obj.hbBg:Destroy()         end)
    pcall(function() obj.highlight:Destroy()    end)
    EspObjects[player] = nil
end

-- ═══════════════════════════════════════════
--  HIDE ALL  (fast, no allocation)
-- ═══════════════════════════════════════════
local function HideEsp(obj)
    for _, l in ipairs(obj.cornerLines) do l.Visible = false end
    for _, l in ipairs(obj.skeleton)    do l.Visible = false end
    obj.boxQuad.Visible       = false
    obj.circleD.Visible       = false
    obj.fillFrame.Visible     = false
    obj.hbBg.Visible          = false
    obj.hbFill.Visible        = false
    obj.nameText.Visible      = false
    obj.distText.Visible      = false
    obj.tracerLine.Visible    = false
    obj.tracerOutline.Visible = false
    obj.highlight.Enabled     = false
end

-- ═══════════════════════════════════════════
--  CORNER BOX  (8 Drawing Lines)
-- ═══════════════════════════════════════════
local function DrawCornerBox(lines, x, y, w, h, color, tk)
    local cL = math.min(w, h) * 0.2
    lines[1].From = Vector2.new(x,   y);   lines[1].To = Vector2.new(x+cL, y)
    lines[2].From = Vector2.new(x,   y);   lines[2].To = Vector2.new(x,    y+cL)
    lines[3].From = Vector2.new(x+w, y);   lines[3].To = Vector2.new(x+w-cL, y)
    lines[4].From = Vector2.new(x+w, y);   lines[4].To = Vector2.new(x+w,  y+cL)
    lines[5].From = Vector2.new(x,   y+h); lines[5].To = Vector2.new(x+cL, y+h)
    lines[6].From = Vector2.new(x,   y+h); lines[6].To = Vector2.new(x,    y+h-cL)
    lines[7].From = Vector2.new(x+w, y+h); lines[7].To = Vector2.new(x+w-cL, y+h)
    lines[8].From = Vector2.new(x+w, y+h); lines[8].To = Vector2.new(x+w,  y+h-cL)
    for _, l in ipairs(lines) do
        l.Color     = color
        l.Thickness = tk
        l.Visible   = true
    end
end

-- ═══════════════════════════════════════════
--  FULL BOX  (Drawing Quad — no UIStroke)
-- ═══════════════════════════════════════════
local function DrawFullBox(quad, x, y, w, h, color, tk)
    quad.PointA   = Vector2.new(x,     y)
    quad.PointB   = Vector2.new(x + w, y)
    quad.PointC   = Vector2.new(x + w, y + h)
    quad.PointD   = Vector2.new(x,     y + h)
    quad.Color    = color
    quad.Thickness= tk
    quad.Filled   = false
    quad.Visible  = true
end

-- ═══════════════════════════════════════════
--  UPDATE SINGLE PLAYER
-- ═══════════════════════════════════════════
local function UpdateEsp(player, cam, vp, myHRP)
    local obj = EspObjects[player]
    if not obj then return end

    if not sharedEsp.EspEnabled.Value then HideEsp(obj); return end

    local char = player.Character
    if not char or not EspIsAlive(char) then HideEsp(obj); return end
    if EspIsTeammate(player)            then HideEsp(obj); return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then HideEsp(obj); return end

    local hrpSP = cam:WorldToViewportPoint(hrp.Position)
    if hrpSP.Z <= 0 then HideEsp(obj); return end

    local x, y, w, h = GetBounds(char, cam)
    local onScreen    = x ~= nil
    local espColor    = _frameColor
    local tk          = 1.5

    -- ── BOX ──────────────────────────────────
    if sharedEsp.BoxESP.Value and onScreen then
        local boxMode = sharedEsp.BoxESPMode.Value
        if boxMode == 'Corner' then
            obj.boxQuad.Visible = false
            obj.circleD.Visible = false
            DrawCornerBox(obj.cornerLines, x, y, w, h, espColor, tk)
        elseif boxMode == 'Circle' then
            for _, l in ipairs(obj.cornerLines) do l.Visible = false end
            obj.boxQuad.Visible  = false
            obj.circleD.Position = Vector2.new(x + w * 0.5, y + h * 0.5)
            obj.circleD.Radius   = math.min(w, h) * 0.5
            obj.circleD.Color    = espColor
            obj.circleD.Visible  = true
        else
            for _, l in ipairs(obj.cornerLines) do l.Visible = false end
            obj.circleD.Visible = false
            DrawFullBox(obj.boxQuad, x, y, w, h, espColor, tk)
        end
    else
        for _, l in ipairs(obj.cornerLines) do l.Visible = false end
        obj.boxQuad.Visible = false
        obj.circleD.Visible = false
    end

    -- ── FILL  (Frame) ─────────────────────────
    if sharedEsp.FillESP.Value and onScreen then
        local fc = ComputeColor(sharedEsp.FillESPColor.Value)
        obj.fillFrame.BackgroundColor3       = fc
        obj.fillFrame.BackgroundTransparency = math.clamp(sharedEsp.FillESPTransparency.Value / 100, 0, 1)
        obj.fillFrame.Position               = UDim2.fromOffset(x, y)
        obj.fillFrame.Size                   = UDim2.fromOffset(w, h)
        obj.fillFrame.Visible                = true
    else
        obj.fillFrame.Visible = false
    end

    -- ── HEALTHBAR  (Frames) ───────────────────
    if sharedEsp.HealthBarESP.Value and onScreen then
        local pct  = GetHealthPct(char)
        local hbW  = sharedEsp.HealthBarThickness.Value
        local size = sharedEsp.HealthBarSize.Value / 100
        local offX = sharedEsp.HealthBarXOffset.Value
        local offY = sharedEsp.HealthBarYOffset.Value
        local hbH  = h * size
        local hbX  = x - hbW - 3 + offX
        local hbY  = y + offY
        obj.hbBg.BackgroundColor3       = sharedEsp.HealthBarBackgroundColor.Value
        obj.hbBg.BackgroundTransparency = math.clamp(sharedEsp.HealthBarBackgroundTransparency.Value / 100, 0, 1)
        obj.hbBg.Position               = UDim2.fromOffset(hbX, hbY)
        obj.hbBg.Size                   = UDim2.fromOffset(hbW, hbH)
        obj.hbBg.Visible                = true
        obj.hbFill.AnchorPoint          = Vector2.new(0, 1)
        obj.hbFill.Position             = UDim2.new(0, 0, 1, 0)
        obj.hbFill.Size                 = UDim2.new(1, 0, pct, 0)
        obj.hbFill.BackgroundColor3     = sharedEsp.HealthBarColor.Value
        obj.hbFill.BackgroundTransparency = math.clamp(sharedEsp.HealthBarTransparency.Value / 100, 0, 1)
        obj.hbFill.Visible              = true
    else
        obj.hbBg.Visible   = false
        obj.hbFill.Visible = false
    end

    -- ── SKELETON  (Drawing Lines) ─────────────
    if sharedEsp.SkeletonESP.Value then
        local sc           = ComputeColor(sharedEsp.SkeletonESPColor.Value)
        local thickness    = sharedEsp.SkeletonESPThickness.Value
        local transparency = math.clamp(sharedEsp.SkeletonESPTransparency.Value / 100, 0, 1)
        local isR6         = char:FindFirstChild("Torso") ~= nil
        local bones        = isR6 and BONES_R6 or BONES_R15
        for i, f in ipairs(obj.skeleton) do
            local bone = bones[i]
            if not bone then f.Visible = false; continue end
            local pA = char:FindFirstChild(bone[1])
            local pB = char:FindFirstChild(bone[2])
            if not pA or not pB then f.Visible = false; continue end
            local sA, onA = cam:WorldToViewportPoint(pA.Position)
            local sB, onB = cam:WorldToViewportPoint(pB.Position)
            if sA.Z > 0 and sB.Z > 0 and (onA or onB) then
                f.From         = Vector2.new(sA.X, sA.Y)
                f.To           = Vector2.new(sB.X, sB.Y)
                f.Color        = sc
                f.Thickness    = thickness
                f.Transparency = transparency
                f.Visible      = true
            else
                f.Visible = false
            end
        end
    else
        for _, f in ipairs(obj.skeleton) do f.Visible = false end
    end

    -- ── NAME ─────────────────────────────────
    if sharedEsp.NameESP.Value and onScreen then
        local nc   = ComputeColor(sharedEsp.NameTextColor.Value)
        local offX = sharedEsp.NameXOffset.Value
        local offY = sharedEsp.NameYOffset.Value
        obj.nameText.Text     = GetNameStr(player)
        obj.nameText.Color    = nc
        obj.nameText.Font     = GetEspFont()
        obj.nameText.Size     = 13
        obj.nameText.Position = Vector2.new(x + w * 0.5 + offX, y - 16 + offY)
        obj.nameText.Visible  = true
    else
        obj.nameText.Visible = false
    end

    -- ── DISTANCE ─────────────────────────────
    local showDist = sharedEsp.DistanceESP and sharedEsp.DistanceESP.Value
    if showDist and onScreen and myHRP then
        local offX = sharedEsp.NameXOffset.Value
        obj.distText.Text     = GetDist(hrp, myHRP) .. "m"
        obj.distText.Size     = 11
        obj.distText.Position = Vector2.new(x + w * 0.5 + offX, y + h + 4)
        obj.distText.Visible  = true
    else
        obj.distText.Visible = false
    end

    -- ── HIGHLIGHT ────────────────────────────
    if sharedEsp.HighlightEnabled.Value then
        local fillColor    = ComputeColor(sharedEsp.HighlightFillColor.Value)
        local outlineColor = ComputeColor(sharedEsp.HighlightOutlineColor.Value)
        local fillT        = math.clamp(sharedEsp.HighlightFillTransparency.Value, 0, 1)
        local outT         = math.clamp(sharedEsp.HighlightOutlineTransparency.Value, 0, 1)
        local extra        = sharedEsp.HighlightExtra.Value
        if extra == 'Flicker' then
            fillT = (math.random() > 0.4) and fillT or 1
        elseif extra == 'Breathe' then
            local t = (EspPulseTimer % 1.5) / 1.5
            fillT = fillT + (1 - fillT) * math.abs(math.sin(t * math.pi))
        end
        obj.highlight.Adornee             = char
        obj.highlight.FillColor           = fillColor
        obj.highlight.OutlineColor        = outlineColor
        obj.highlight.FillTransparency    = math.clamp(fillT, 0, 1)
        obj.highlight.OutlineTransparency = math.clamp(outT, 0, 1)
        obj.highlight.DepthMode           = sharedEsp.HighlightThroughWalls.Value
            and Enum.HighlightDepthMode.AlwaysOnTop
            or  Enum.HighlightDepthMode.Occluded
        obj.highlight.Enabled = true
    else
        obj.highlight.Enabled = false
    end

    -- ── TRACER  (2 Drawing Lines) ─────────────
    local showTracer = sharedEsp.TracerESP and sharedEsp.TracerESP.Value
    if showTracer then
        local targetWorld  = hrp.Position + Vector3.new(0, hrp.Size.Y * 0.5, 0)
        local targetSP, on = cam:WorldToViewportPoint(targetWorld)
        if on and targetSP.Z > 0 then
            local origin = GetTracerOrigin(vp)
            local tgt    = Vector2.new(targetSP.X, targetSP.Y)
            obj.tracerOutline.From    = origin
            obj.tracerOutline.To      = tgt
            obj.tracerOutline.Visible = true
            obj.tracerLine.From       = origin
            obj.tracerLine.To         = tgt
            obj.tracerLine.Color      = espColor
            obj.tracerLine.Visible    = true
        else
            obj.tracerLine.Visible    = false
            obj.tracerOutline.Visible = false
        end
    else
        obj.tracerLine.Visible    = false
        obj.tracerOutline.Visible = false
    end
end

-- ═══════════════════════════════════════════
--  PLAYER LIFECYCLE
-- ═══════════════════════════════════════════
local function OnEspPlayerAdded(player)
    if player == EspLocalPlayer then return end
    CreateEsp(player)
end

for _, p in ipairs(EspPlayers:GetPlayers()) do OnEspPlayerAdded(p) end
EspPlayers.PlayerAdded:Connect(OnEspPlayerAdded)
EspPlayers.PlayerRemoving:Connect(DestroyEsp)

-- ═══════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════
EspRunService.Heartbeat:Connect(function(dt)
    EspRainbowHue = (EspRainbowHue + 0.003) % 1
    EspPulseTimer = EspPulseTimer + dt

    local cam   = EspCamera
    local vp    = cam.ViewportSize
    local myC   = EspLocalPlayer.Character
    local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")

    -- compute box colour ONCE per frame, shared across all players
    _frameColor = ComputeColor(sharedEsp.BoxESPColor.Value)

    for player in pairs(EspObjects) do
        if player.Parent then
            UpdateEsp(player, cam, vp, myHRP)
        else
            DestroyEsp(player)
        end
    end
end)
