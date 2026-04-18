-- SILENT AIM v1 by oblivion (completed)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local silentshared = shared.Silentaim

-- ─── state ────────────────────────────────────────────────────────────────────
local isAiming        = false
local currentTarget   = nil
local lockedTarget    = nil
local lockedAimPart   = nil
local cachedViewport  = Vector2.zero
local cachedCharacters = {}
local lastCache       = 0
local fovCirclePos    = nil
local lastTime        = tick()
local fovCircle       = nil
local Mode            = nil
local AimKey          = nil

local toggleState  = false
local lastKeyState = false

-- ─── settings (pulled from silentshared each frame) ───────────────────────────
local Active          = false
local LegitMode       = false
local TeamCheck       = false
local WallCheck       = false
local HitChance       = 95
local HeadshotChance  = 68
local BodyShotChance  = 92
local Fov             = 90
local MaxDistance     = 1000
local TargetPriority  = "Closest"
local Targetpart      = "Head"

local targetHitChance = {}

-- ═══════════════════════════════════════════
--  SHARED VALUE READER
-- ═══════════════════════════════════════════
local function readBool(key, default)
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "boolean" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end
local function readNum(key, default)
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "number" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end
local function readStr(key, default)
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "string" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end

local function UpdateSettings()
    if not silentshared then return end
    pcall(function()
        fovCircle    = silentshared.fovCircle

        Active        = readBool("Active",        false)
        LegitMode     = readBool("LegitAim",      false)
        TeamCheck     = readBool("TeamCheck",     false)
        WallCheck     = readBool("WallCheck",     false)
        HitChance     = readNum ("HitChance",     95)
        HeadshotChance= readNum ("HeadshotChance",68)
        BodyShotChance= readNum ("BodyShotChance",92)
        Fov           = readNum ("Fov",           90)
        MaxDistance   = readNum ("distance",      1000)
        TargetPriority= readStr ("TargetPriority","Closest")
        Targetpart    = readStr ("TargetBodyPart","Head")
        AimKey        = readStr ("SilentAimKey",  nil)
        Mode          = readStr ("Mode",          "Always")

        if LegitMode then
            HitChance      = math.min(HitChance,      85)
            HeadshotChance = math.min(HeadshotChance, 55)
            BodyShotChance = math.min(BodyShotChance, 80)
        end
    end)
end

-- ═══════════════════════════════════════════
--  LOBBY CHECK
-- ═══════════════════════════════════════════
local function isLobbyVisible()
    local ok, result = pcall(function()
        return Player.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible
    end)
    return ok and result == true
end

-- ═══════════════════════════════════════════
--  TEAM CHECK
-- ═══════════════════════════════════════════
local function SafeTeamCheck(plr)
    if not TeamCheck then return false end
    if not plr or not plr.Team then return false end
    return plr.Team == Player.Team
end

-- ═══════════════════════════════════════════
--  WALL CHECK
-- ═══════════════════════════════════════════
local rayParams = RaycastParams.new()
rayParams.FilterType  = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function IsVisible(targetPart)
    if not WallCheck or not targetPart then return true end
    local char = Player.Character
    if not char then return true end
    rayParams.FilterDescendantsInstances = { char }
    local origin = Camera.CFrame.Position
    local dir    = targetPart.Position - origin
    local res    = workspace:Raycast(origin, dir, rayParams)
    return not res or (res.Instance and res.Instance:IsDescendantOf(targetPart.Parent))
end

-- ═══════════════════════════════════════════
--  DISTANCE CHECK
-- ═══════════════════════════════════════════
local function IsInRange(part)
    if not part or not part.Parent then return false end
    return (part.Position - Camera.CFrame.Position).Magnitude <= MaxDistance
end

-- ═══════════════════════════════════════════
--  AIM PART CHOOSER
-- ═══════════════════════════════════════════
local function ChooseAimPart(char)
    if not char then return nil end
    local rollHead = math.random(100) <= HeadshotChance
    if rollHead then
        local head = char:FindFirstChild("Head")
        if head then return head end
    end
    local rollBody = math.random(100) <= BodyShotChance
    if rollBody then
        return char:FindFirstChild(Targetpart)
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- ═══════════════════════════════════════════
--  HIT CHANCE GATE
-- ═══════════════════════════════════════════
local function ShouldHitTarget(char)
    if not char then return true end
    if targetHitChance[char] == nil then
        targetHitChance[char] = math.random(100) <= HitChance
    end
    return targetHitChance[char]
end

-- ═══════════════════════════════════════════
--  FOV CHECK  (screen-space circle around mouse)
-- ═══════════════════════════════════════════
local function InFov(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen or screenPos.Z <= 0 then return false, nil end
    local sp2    = Vector2.new(screenPos.X, screenPos.Y)
    local mouse  = UserInputService:GetMouseLocation()
    local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)
    if (sp2 - mouse).Magnitude <= radius then
        return true, sp2
    end
    return false, nil
end

-- ═══════════════════════════════════════════
--  CHARACTER CACHE
-- ═══════════════════════════════════════════
local function RefreshCache()
    lastCache = tick()
    table.clear(cachedCharacters)
    for _, p in Players:GetPlayers() do
        if p ~= Player and p.Character then
            local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(cachedCharacters, p.Character)
            end
        end
    end
end

-- ═══════════════════════════════════════════
--  TARGET FINDER
-- ═══════════════════════════════════════════
local function FindTarget()
    if lockedTarget and lockedTarget.Parent then
        local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.Health > 0 then
            local part = (lockedAimPart and lockedAimPart.Parent == lockedTarget)
                and lockedAimPart or ChooseAimPart(lockedTarget)
            if part and IsInRange(part) and IsVisible(part) then
                local ok, scr = InFov(part.Position)
                if ok then return part, scr end
            end
        end
    end

    lockedTarget  = nil
    lockedAimPart = nil

    RefreshCache()

    local screenCenter = Camera.ViewportSize * 0.5
    local candidates   = {}

    for _, char in ipairs(cachedCharacters) do
        local plr = Players:GetPlayerFromCharacter(char)
        if SafeTeamCheck(plr) then continue end
        if not ShouldHitTarget(char) then continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root or not IsInRange(root) then continue end
        if not IsVisible(root) then continue end

        local part = ChooseAimPart(char)
        if not part then continue end

        local ok, scr = InFov(part.Position)
        if not ok then continue end

        local hum = char:FindFirstChildWhichIsA("Humanoid")
        table.insert(candidates, {
            part      = part,
            char      = char,
            screenPos = scr,
            distance  = (root.Position - Camera.CFrame.Position).Magnitude,
            health    = hum and hum.Health or 100,
        })
    end

    if #candidates == 0 then return nil, nil end

    if TargetPriority == "Distance" then
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
    elseif TargetPriority == "Health" then
        table.sort(candidates, function(a, b) return a.health < b.health end)
    elseif TargetPriority == "Random" then
        local pick = candidates[math.random(#candidates)]
        lockedTarget  = pick.char
        lockedAimPart = pick.part
        return pick.part, pick.screenPos
    else
        table.sort(candidates, function(a, b)
            return (a.screenPos - screenCenter).Magnitude < (b.screenPos - screenCenter).Magnitude
        end)
    end

    local best = candidates[1]
    lockedTarget  = best.char
    lockedAimPart = best.part
    return best.part, best.screenPos
end

-- ═══════════════════════════════════════════
--  PLAYER IN FOV  (simple public helper)
-- ═══════════════════════════════════════════
local function GetPlayerInFov()
    local best     = nil
    local bestDist = math.huge
    local mouse    = UserInputService:GetMouseLocation()
    local radius   = (Fov / 180) * (Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == Player then continue end
        if SafeTeamCheck(player) then continue end
        local char = player.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen or sp.Z <= 0 then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
        if dist <= radius and dist < bestDist then
            bestDist = dist
            best     = player
        end
    end

    return best
end

-- ═══════════════════════════════════════════
--  AIM KEY CHECK
-- ═══════════════════════════════════════════
local function IsAimKeyDown()
    if not AimKey then return false end
    if AimKey:match("^MB%d") then
        local n = tonumber(AimKey:match("%d"))
        if n then return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton"..n]) end
    else
        local key = Enum.KeyCode[AimKey]
        if key then return UserInputService:IsKeyDown(key) end
    end
    return false
end

-- ═══════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════
local function UpdateFOVCircle()
    if not fovCircle then
        fovCircle = silentshared and silentshared.fovCircle or nil
    end
    if not fovCircle then return end

    local showFov     = silentshared and readBool("Showfov", false)
    local aimActive   = silentshared and readBool("Active",  false)

    if not showFov or not aimActive then
        pcall(function() fovCircle.Visible = false end)
        return
    end

    local mouse  = UserInputService:GetMouseLocation()
    local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)

    fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mouse, 0.28) or mouse

    pcall(function()
        fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
        fovCircle.Size     = UDim2.new(0, radius * 2, 0, radius * 2)
        fovCircle.Visible  = true
    end)
end

-- ═══════════════════════════════════════════
--  SHOW TARGET HIGHLIGHT
-- ═══════════════════════════════════════════
local function UpdateTargetHighlight()
    if not silentshared then return end
    local showTarget = readBool("ShowTarget", false)
    local ok, _ = pcall(function()
        silentshared._lockedChar = (showTarget and lockedTarget) or nil
    end)
end

-- ═══════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════
local function MainLoop()
    cachedViewport = Camera.ViewportSize

    UpdateSettings()

    local keyDown = IsAimKeyDown()
    if Mode == "Hold" then
        isAiming = Active and keyDown
    elseif Mode == "Toggle" then
        if keyDown and not lastKeyState then
            toggleState = not toggleState
        end
        lastKeyState = keyDown
        isAiming = Active and toggleState
    else 
        isAiming = Active
    end

    if isLobbyVisible() then
        isAiming = false
    end

    if not isAiming then
        currentTarget = nil
        table.clear(targetHitChance)
        lockedTarget  = nil
        lockedAimPart = nil
        UpdateTargetHighlight()
        return
    end

    local part, _ = FindTarget()
    currentTarget  = part
    UpdateTargetHighlight()
end

-- ═══════════════════════════════════════════
--  SILENT AIM HOOK
--  Intercepts camera:ScreenPointToRay / WorldToScreenPoint
--  so the bullet redirect happens without touching the mouse.
--  Works by hooking workspace.CurrentCamera via __index override
--  on the firing function's ray origin — standard silent aim pattern.
-- ═══════════════════════════════════════════
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if self == Camera and (method == "ScreenPointToRay" or method == "ViewportPointToRay") then
        if currentTarget and currentTarget.Parent then
            local pos = currentTarget.Position
            local origin = Camera.CFrame.Position
            local dir    = (pos - origin).Unit * 5000
            return Ray.new(origin, dir)
        end
    end
    return oldNamecall(self, ...)
end)

-- ═══════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════
task.delay(1, function()
    print("SILENT AIM v1 Loaded!")
    fovCircle = silentshared and silentshared.fovCircle or nil

    RunService.RenderStepped:Connect(UpdateFOVCircle)
    RunService.Heartbeat:Connect(MainLoop)

    print("SILENT AIM v1 Ready!")
end)
