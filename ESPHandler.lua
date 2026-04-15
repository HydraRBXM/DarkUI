local EspPlayers = game:GetService("Players")
local EspRunService = game:GetService("RunService")
local EspCamera = workspace.CurrentCamera
local EspLocalPlayer = EspPlayers.LocalPlayer
local UserInputService = game:GetService("UserInputService")
print("starting")
-- ═══════════════════════════════════════════
--  ESP GUI
-- ═══════════════════════════════════════════
local EspGui = Instance.new("ScreenGui")
EspGui.Name = "CometESP"
EspGui.ResetOnSpawn = false
EspGui.IgnoreGuiInset = true
EspGui.DisplayOrder = 9998
EspGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
EspGui.Parent = caninjectinto_COREGUI and game.CoreGui or EspLocalPlayer.PlayerGui

-- ═══════════════════════════════════════════
--  TRACER GUI  (separate layer, lower DisplayOrder)
-- ═══════════════════════════════════════════
local tracerGui = Instance.new("ScreenGui")
tracerGui.Name = "CometTracers"
tracerGui.ResetOnSpawn = false
tracerGui.IgnoreGuiInset = true
tracerGui.DisplayOrder = 9997
tracerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
tracerGui.Parent = caninjectinto_COREGUI and game.CoreGui or EspLocalPlayer.PlayerGui

-- ═══════════════════════════════════════════
--  HIGHLIGHT FOLDER (unique GUID)
-- ═══════════════════════════════════════════
local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = game:GetService("HttpService"):GenerateGUID(true)
HighlightFolder.Parent = workspace

-- ═══════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════
local EspObjects   = {}
local tracerCache  = {}

local EspRainbowHue = 0
local EspPulseTimer = 0
local LastUpdateTime = 0
local UpdateInterval = 0.016
local MaxRange = 1500

-- Tracer origin modes: BottomScreen | CenterScreen | TopScreen | Mouse
local tracerattachment = "BottomScreen"

local function GetPulseSpeed() return 1.5 end

local sharedEsp = shared.Esp or nil

-- ═══════════════════════════════════════════
--  FONT MAP
-- ═══════════════════════════════════════════
local FontMap = {
	['Proggy Clean'] = Enum.Font.Code,
	['GothamBold']   = Enum.Font.GothamBold,
	['Arial']        = Enum.Font.Arial,
	['Code']         = Enum.Font.Code,
	['Pixel Arial']  = Enum.Font.Code,
}

local function updateTracerAttachment()
	tracerattachment = sharedEsp.TracerAttachmentPoint.Value
end
local function GetEspFont()
	return FontMap[sharedEsp.EspFont.Value] or Enum.Font.GothamBold
end

local function GetNameStr(player)
	local t = sharedEsp.EspNameType.Value
	if t == 'Display Name' then return player.DisplayName
	elseif t == 'Username'  then return player.Name
	else                         return player.Name end
end

-- ═══════════════════════════════════════════
--  COLORING
-- ═══════════════════════════════════════════
local function GetEspColor(baseColor)
	local mode = sharedEsp['ESP Coloring'].Value
	if mode == 'Rainbow' then
		return Color3.fromHSV(EspRainbowHue, 1, 1)
	elseif mode == 'Gradient' then
		return Color3.fromHSV((EspRainbowHue + 0.33) % 1, 0.85, 1)
	elseif mode == 'Pulse' then
		local speed = GetPulseSpeed()
		local t     = (EspPulseTimer % speed) / speed
		local alpha = math.abs(math.sin(t * math.pi))
		local pc    = sharedEsp.EspPulseColor.Value
		return pc:Lerp(Color3.new(1, 1, 1), alpha)
	elseif mode == 'Custom Color' then
		return sharedEsp.EspCustomColor.Value
	elseif mode == 'Team Color' then
		local team = EspLocalPlayer.Team
		return team and team.TeamColor.Color or baseColor
	else
		return baseColor
	end
end

local function GetHighlightColor(baseColor)
	return GetEspColor(baseColor)
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

-- ═══════════════════════════════════════════
--  BOUNDING MODES
-- ═══════════════════════════════════════════
local function GetBoundsFixed(char)
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not hrp or not head then return nil end
	local topSP, topOn = EspCamera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
	local botSP, botOn = EspCamera:WorldToViewportPoint(hrp.Position  - Vector3.new(0, hrp.Size.Y  * 0.5, 0))
	if not topOn or not botOn then return nil end
	if topSP.Z <= 0 or botSP.Z <= 0 then return nil end
	local vp = EspCamera.ViewportSize
	if (topSP.X < -50 or topSP.X > vp.X + 50) and (botSP.X < -50 or botSP.X > vp.X + 50) then return nil end
	local h = botSP.Y - topSP.Y
	if h <= 2 then return nil end
	local scaler = sharedEsp.EspFixedWidthScaler.Value / 100
	local w = h * 0.6 * scaler
	return topSP.X - w * 0.5, topSP.Y, w, h
end

local function GetBoundsAccurate(char)
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not hrp or not head then return nil end
	local topSP, topOn = EspCamera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
	local botSP, botOn = EspCamera:WorldToViewportPoint(hrp.Position  - Vector3.new(0, hrp.Size.Y  * 0.5, 0))
	if not topOn or not botOn then return nil end
	if topSP.Z <= 0 or botSP.Z <= 0 then return nil end
	local vp = EspCamera.ViewportSize
	if (topSP.X < -50 or topSP.X > vp.X + 50) and (botSP.X < -50 or botSP.X > vp.X + 50) then return nil end
	local h = botSP.Y - topSP.Y
	if h <= 2 then return nil end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local w
	if torso then
		local halfW = torso.Size.X * 0.5
		local root  = hrp.CFrame
		local lSP   = EspCamera:WorldToViewportPoint((root * CFrame.new(-halfW, 0, 0)).Position)
		local rSP   = EspCamera:WorldToViewportPoint((root * CFrame.new( halfW, 0, 0)).Position)
		w = math.abs(rSP.X - lSP.X)
		w = math.clamp(w, h * 0.25, h * 1.5)
	else
		w = h * 0.6
	end
	return topSP.X - w * 0.5, topSP.Y, w, h
end

local function GetBoundsAutomatic(char)
	local minX, minY, maxX, maxY
	local anyOnScreen = false
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local cf = part.CFrame
			local hs = part.Size * 0.5
			local signs = {
				Vector3.new( 1,  1,  1), Vector3.new(-1,  1,  1),
				Vector3.new( 1, -1,  1), Vector3.new(-1, -1,  1),
				Vector3.new( 1,  1, -1), Vector3.new(-1,  1, -1),
				Vector3.new( 1, -1, -1), Vector3.new(-1, -1, -1),
			}
			for _, s in ipairs(signs) do
				local worldPt    = (cf * CFrame.new(hs * s)).Position
				local sp, on     = EspCamera:WorldToViewportPoint(worldPt)
				if on and sp.Z > 0 then
					anyOnScreen = true
					minX = math.min(minX or sp.X, sp.X)
					minY = math.min(minY or sp.Y, sp.Y)
					maxX = math.max(maxX or sp.X, sp.X)
					maxY = math.max(maxY or sp.Y, sp.Y)
				end
			end
		end
	end
	if not anyOnScreen or not minX then return nil end
	local w   = maxX - minX
	local h   = maxY - minY
	if w <= 2 or h <= 2 then return nil end
	local pad = 4
	return minX - pad, minY - pad, w + pad * 2, h + pad * 2
end

local function GetBounds(char)
	local mode = sharedEsp.EspBoundingMode.Value
	if mode == 'Fixed'    then return GetBoundsFixed(char)
	elseif mode == 'Accurate' then return GetBoundsAccurate(char)
	else return GetBoundsAutomatic(char) end
end

-- ═══════════════════════════════════════════
--  MISC HELPERS
-- ═══════════════════════════════════════════
local function IsOnScreen(worldPos)
	local sp, onScreen = EspCamera:WorldToViewportPoint(worldPos)
	if not onScreen or sp.Z <= 0 then return false, sp end
	local vp = EspCamera.ViewportSize
	if sp.X < -50 or sp.X > vp.X + 50 then return false, sp end
	if sp.Y < -50 or sp.Y > vp.Y + 50 then return false, sp end
	return true, sp
end

local function GetDist(char)
	local myChar = EspLocalPlayer.Character
	local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local hrp    = char:FindFirstChild("HumanoidRootPart")
	if not myHRP or not hrp then return 0 end
	return math.floor((hrp.Position - myHRP.Position).Magnitude)
end

local function GetHealthPct(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 1 end
	return math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
end

-- ═══════════════════════════════════════════
--  FRAME / LABEL FACTORIES
-- ═══════════════════════════════════════════
local function MakeFrame(parent, zindex)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0
	f.Visible = false
	f.ZIndex = zindex or 5
	f.Parent = parent or EspGui
	return f
end

local function MakeLabel(parent, zindex)
	local l  = Instance.new("TextLabel")
	local ts = Instance.new("UIStroke", l)
	ts.Name      = "ts"
	ts.Thickness = 1
	ts.Color     = Color3.new(0, 0, 0)
	l.BorderSizePixel        = 0
	l.BackgroundTransparency = 1
	l.TextStrokeTransparency = 0.5
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Size = UDim2.new(0, 0, 0, 0)
	l.AutomaticSize          = Enum.AutomaticSize.XY
	l.AnchorPoint            = Vector2.new(0, 0)
	l.TextXAlignment         = Enum.TextXAlignment.Center
	l.Visible                = false
	l.ZIndex                 = zindex or 6
	l.Parent                 = parent or EspGui
	return l
end

-- ═══════════════════════════════════════════
--  BONES
-- ═══════════════════════════════════════════
local BONES_R15 = {
	{"Head",        "UpperTorso"},
	{"UpperTorso",  "LowerTorso"},
	{"LowerTorso",  "LeftUpperLeg"},  {"LowerTorso",  "RightUpperLeg"},
	{"LeftUpperLeg","LeftLowerLeg"},  {"RightUpperLeg","RightLowerLeg"},
	{"LeftLowerLeg","LeftFoot"},      {"RightLowerLeg","RightFoot"},
	{"UpperTorso",  "LeftUpperArm"},  {"UpperTorso",  "RightUpperArm"},
	{"LeftUpperArm","LeftLowerArm"},  {"RightUpperArm","RightLowerArm"},
	{"LeftLowerArm","LeftHand"},      {"RightLowerArm","RightHand"},
}
local BONES_R6 = {
	{"Head",  "Torso"},
	{"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

-- ═══════════════════════════════════════════
--  TRACER HELPERS
-- ═══════════════════════════════════════════

--- Returns the 2D screen origin for tracers based on tracerattachment mode.
local function GetTracerOrigin()
	local vp = EspCamera.ViewportSize
	if tracerattachment == "BottomScreen" then
		return Vector2.new(vp.X * 0.5, vp.Y)
	elseif tracerattachment == "CenterScreen" then
		return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	elseif tracerattachment == "TopScreen" then
		return Vector2.new(vp.X * 0.5, 0)
	elseif tracerattachment == "Mouse" then
		local mouse = UserInputService:GetMouseLocation()
		return Vector2.new(mouse.X, mouse.Y)
	end
	-- fallback
	return Vector2.new(vp.X * 0.5, vp.Y)
end

--- Allocates two Frames (outline + line) for a tracer. Only called once per player.
local function MakeTracerLine(color)
	local function F(col, zindex)
		local f = Instance.new("Frame")
		f.BorderSizePixel  = 0
		f.BackgroundColor3 = col
		f.AnchorPoint      = Vector2.new(0.5, 0.5)  -- centred so mid-point rotation is correct
		f.ZIndex           = zindex
		f.Visible          = false
		f.Parent           = tracerGui
		return f
	end
	return {
		outline = F(Color3.new(0, 0, 0), 4),
		line    = F(color, 5),
	}
end

--- Positions and shows an existing tracer pair. Pure math — no new instances.
local function SetTracerLine(t, from, to, color)
	local delta  = to - from
	local length = delta.Magnitude
	if length < 1 then
		t.line.Visible    = false
		t.outline.Visible = false
		return
	end
	local angle = math.atan2(delta.Y, delta.X)
	local mid   = (from + to) * 0.5

	-- outline  (3 px tall, semi-transparent black)
	t.outline.BackgroundTransparency = 0.5
	t.outline.Size     = UDim2.new(0, length, 0, 3)
	t.outline.Position = UDim2.new(0, mid.X,  0, mid.Y)
	t.outline.Rotation = math.deg(angle)
	t.outline.Visible  = true

	-- coloured line on top (1 px tall)
	t.line.BackgroundColor3       = color
	t.line.BackgroundTransparency = 0
	t.line.Size     = UDim2.new(0, length, 0, 1)
	t.line.Position = UDim2.new(0, mid.X,  0, mid.Y)
	t.line.Rotation = math.deg(angle)
	t.line.Visible  = true
end

--- Destroys the cached tracer frames for a player and clears the entry.
local function RemoveTracer(player)
	local t = tracerCache[player]
	if not t then return end
	pcall(function() t.line:Destroy()    end)
	pcall(function() t.outline:Destroy() end)
	tracerCache[player] = nil
end

-- ═══════════════════════════════════════════
--  CREATE ESP
-- ═══════════════════════════════════════════
local function CreateEsp(player)
	if EspObjects[player] then return end

	local boxFrame   = MakeFrame(EspGui, 5)
	boxFrame.BackgroundTransparency = 1
	local boxStroke  = Instance.new("UIStroke", boxFrame)
	boxStroke.Thickness = 1.5
	boxStroke.Color     = Color3.new(1, 1, 1)

	local circleFrame  = MakeFrame(EspGui, 5)
	circleFrame.BackgroundTransparency = 1
	local circleStroke = Instance.new("UIStroke", circleFrame)
	circleStroke.Thickness = 1.5
	circleStroke.Color     = Color3.new(1, 1, 1)
	local circleCorner = Instance.new("UICorner", circleFrame)
	circleCorner.CornerRadius = UDim.new(0.5, 0)

	local corners = {}
	for i = 1, 8 do corners[i] = MakeFrame(EspGui, 5) end

	local fill = MakeFrame(EspGui, 4)
	fill.BackgroundTransparency = 0.5

	local hbBg = MakeFrame(EspGui, 5)
	hbBg.BackgroundColor3      = Color3.fromRGB(20, 20, 20)
	hbBg.BackgroundTransparency = 0
	local hbFill = MakeFrame(hbBg, 6)
	hbFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

	local skeleton  = {}
	local maxBones  = math.max(#BONES_R15, #BONES_R6)
	for i = 1, maxBones do
		local f = MakeFrame(EspGui, 4)
		f.AnchorPoint = Vector2.new(0.5, 0)
		skeleton[i]   = f
	end

	local nameLabel = MakeLabel(EspGui, 7)
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)

	local distLabel = MakeLabel(EspGui, 7)
	distLabel.AnchorPoint = Vector2.new(0.5, 0)
	distLabel.TextSize    = 11

	local hl = Instance.new("Highlight")
	hl.Name                  = "CometHL"
	hl.FillTransparency      = 1
	hl.OutlineTransparency   = 0
	hl.Enabled               = false
	hl.Parent                = HighlightFolder

	EspObjects[player] = {
		boxFrame     = boxFrame,
		boxStroke    = boxStroke,
		circleFrame  = circleFrame,
		circleStroke = circleStroke,
		corners      = corners,
		fill         = fill,
		hbBg         = hbBg,
		hbFill       = hbFill,
		skeleton     = skeleton,
		nameLabel    = nameLabel,
		distLabel    = distLabel,
		highlight    = hl,
	}
end

-- ═══════════════════════════════════════════
--  DESTROY ESP
-- ═══════════════════════════════════════════
local function DestroyEsp(player)
	RemoveTracer(player)   -- clean up tracer frames first
	local obj = EspObjects[player]
	if not obj then return end
	pcall(function() obj.boxFrame:Destroy()   end)
	pcall(function() obj.circleFrame:Destroy() end)
	pcall(function() obj.fill:Destroy()        end)
	pcall(function() obj.hbBg:Destroy()        end)
	pcall(function() obj.nameLabel:Destroy()   end)
	pcall(function() obj.distLabel:Destroy()   end)
	pcall(function() obj.highlight:Destroy()   end)
	for _, f in ipairs(obj.corners)   do pcall(function() f:Destroy() end) end
	for _, f in ipairs(obj.skeleton)  do pcall(function() f:Destroy() end) end
	EspObjects[player] = nil
end

-- ═══════════════════════════════════════════
--  HIDE ALL
-- ═══════════════════════════════════════════
local function HideEsp(obj, player)
	obj.boxFrame.Visible    = false
	obj.circleFrame.Visible = false
	obj.fill.Visible        = false
	obj.hbBg.Visible        = false
	obj.nameLabel.Visible   = false
	obj.distLabel.Visible   = false
	obj.highlight.Enabled   = false
	for _, f in ipairs(obj.corners)  do f.Visible = false end
	for _, f in ipairs(obj.skeleton) do f.Visible = false end
	-- hide tracer if it exists
	if player then
		local t = tracerCache[player]
		if t then
			t.line.Visible    = false
			t.outline.Visible = false
		end
	end
end

-- ═══════════════════════════════════════════
--  DRAW LINE  (skeleton)
-- ═══════════════════════════════════════════
local function DrawLine(frame, from, to, color, thickness, transparency)
	local delta  = to - from
	local length = delta.Magnitude
	if length < 1 then frame.Visible = false; return end
	local angle = math.atan2(delta.Y, delta.X)
	local mid   = (from + to) * 0.5
	frame.Size                   = UDim2.new(0, length, 0, math.max(1, thickness))
	frame.Position               = UDim2.new(0, mid.X,  0, mid.Y)
	frame.Rotation               = math.deg(angle)
	frame.BackgroundColor3       = color
	frame.BackgroundTransparency = math.clamp(transparency or 0, 0, 1)
	frame.Visible                = true
end

-- ═══════════════════════════════════════════
--  DRAW CORNER BOX
-- ═══════════════════════════════════════════
local function DrawCornerBox(corners, x, y, w, h, color, tk)
	local cLen = math.min(w, h) * 0.2
	corners[1].Position = UDim2.new(0, x,           0, y);           corners[1].Size = UDim2.new(0, cLen, 0, tk)
	corners[2].Position = UDim2.new(0, x,           0, y);           corners[2].Size = UDim2.new(0, tk,   0, cLen)
	corners[3].Position = UDim2.new(0, x + w - cLen,0, y);           corners[3].Size = UDim2.new(0, cLen, 0, tk)
	corners[4].Position = UDim2.new(0, x + w - tk,  0, y);           corners[4].Size = UDim2.new(0, tk,   0, cLen)
	corners[5].Position = UDim2.new(0, x,           0, y + h - tk);  corners[5].Size = UDim2.new(0, cLen, 0, tk)
	corners[6].Position = UDim2.new(0, x,           0, y + h - cLen);corners[6].Size = UDim2.new(0, tk,   0, cLen)
	corners[7].Position = UDim2.new(0, x + w - cLen,0, y + h - tk);  corners[7].Size = UDim2.new(0, cLen, 0, tk)
	corners[8].Position = UDim2.new(0, x + w - tk,  0, y + h - cLen);corners[8].Size = UDim2.new(0, tk,   0, cLen)
	for _, c in ipairs(corners) do
		c.BackgroundColor3 = color
		c.Visible = true
	end
end

-- ═══════════════════════════════════════════
--  UPDATE SINGLE PLAYER
-- ═══════════════════════════════════════════
local function UpdateEsp(player)
	local obj = EspObjects[player]
	if not obj then return end

	if not sharedEsp.EspEnabled.Value then HideEsp(obj, player); return end

	local char = player.Character
	if not char or not EspIsAlive(char) then HideEsp(obj, player); return end
	if EspIsTeammate(player)            then HideEsp(obj, player); return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then HideEsp(obj, player); return end

	local _, hrpSP = IsOnScreen(hrp.Position)
	if hrpSP.Z <= 0 then HideEsp(obj, player); return end

	local x, y, w, h = GetBounds(char)
	local onScreen   = x ~= nil
	local tk         = 1.5
	local font       = GetEspFont()
	local espColor   = GetEspColor(sharedEsp.BoxESPColor.Value)

	-- ── BOX ──────────────────────────────────
	if sharedEsp.BoxESP.Value and onScreen then
		local boxMode = sharedEsp.BoxESPMode.Value
		if boxMode == 'Corner' then
			obj.boxFrame.Visible    = false
			obj.circleFrame.Visible = false
			DrawCornerBox(obj.corners, x, y, w, h, espColor, tk)
		elseif boxMode == 'Circle' then
			obj.boxFrame.Visible = false
			for _, f in ipairs(obj.corners) do f.Visible = false end
			local side = math.min(w, h)
			local cx   = x + w * 0.5 - side * 0.5
			local cy   = y + h * 0.5 - side * 0.5
			obj.circleFrame.Position    = UDim2.new(0, cx, 0, cy)
			obj.circleFrame.Size        = UDim2.new(0, side, 0, side)
			obj.circleStroke.Color      = espColor
			obj.circleStroke.Thickness  = tk
			obj.circleFrame.Visible     = true
		else
			obj.circleFrame.Visible = false
			for _, f in ipairs(obj.corners) do f.Visible = false end
			obj.boxFrame.Position   = UDim2.new(0, x, 0, y)
			obj.boxFrame.Size       = UDim2.new(0, w, 0, h)
			obj.boxStroke.Color     = espColor
			obj.boxStroke.Thickness = tk
			obj.boxFrame.Visible    = true
		end
	else
		obj.boxFrame.Visible    = false
		obj.circleFrame.Visible = false
		for _, f in ipairs(obj.corners) do f.Visible = false end
	end

	-- ── FILL ─────────────────────────────────
	if sharedEsp.FillESP.Value and onScreen then
		local fc = GetEspColor(sharedEsp.FillESPColor.Value)
		obj.fill.Position               = UDim2.new(0, x, 0, y)
		obj.fill.Size                   = UDim2.new(0, w, 0, h)
		obj.fill.BackgroundColor3       = fc
		obj.fill.BackgroundTransparency = math.clamp(sharedEsp.FillESPTransparency.Value / 100, 0, 1)
		obj.fill.Visible                = true
	else
		obj.fill.Visible = false
	end

	-- ── HEALTHBAR ────────────────────────────
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
		obj.hbBg.Position               = UDim2.new(0, hbX, 0, hbY)
		obj.hbBg.Size                   = UDim2.new(0, hbW, 0, hbH)
		obj.hbBg.Visible                = true
		obj.hbFill.AnchorPoint          = Vector2.new(0, 1)
		obj.hbFill.Position             = UDim2.new(0, 0, 1, 0)
		obj.hbFill.Size                 = UDim2.new(1, 0, pct, 0)
		obj.hbFill.BackgroundColor3     = sharedEsp.HealthBarColor.Value
		obj.hbFill.BackgroundTransparency = math.clamp(sharedEsp.HealthBarTransparency.Value / 100, 0, 1)
	else
		obj.hbBg.Visible = false
	end

	-- ── SKELETON ─────────────────────────────
	if sharedEsp.SkeletonESP.Value then
		local sc           = GetEspColor(sharedEsp.SkeletonESPColor.Value)
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
			local visA, sA = IsOnScreen(pA.Position)
			local visB, sB = IsOnScreen(pB.Position)
			if sA.Z > 0 and sB.Z > 0 and (visA or visB) then
				DrawLine(f, Vector2.new(sA.X, sA.Y), Vector2.new(sB.X, sB.Y), sc, thickness, transparency)
			else
				f.Visible = false
			end
		end
	else
		for _, f in ipairs(obj.skeleton) do f.Visible = false end
	end

	-- ── NAME ─────────────────────────────────
	if sharedEsp.NameESP.Value and onScreen then
		local nc   = GetEspColor(sharedEsp.NameTextColor.Value)
		local offX = sharedEsp.NameXOffset.Value
		local offY = sharedEsp.NameYOffset.Value
		obj.nameLabel.Text          = GetNameStr(player)
		obj.nameLabel.TextColor3    = nc
		obj.nameLabel.Font          = font
		obj.nameLabel.ts.Thickness  = sharedEsp.NameStrokeThickness.Value
		obj.nameLabel.ts.Color      = Color3.new(0, 0, 0)
		obj.nameLabel.TextSize      = 13
		obj.nameLabel.Position      = UDim2.new(0, x + w * 0.5 + offX, 0, y - 2 + offY)
		obj.nameLabel.Visible       = true
	else
		obj.nameLabel.Visible = false
	end

	-- ── DISTANCE ─────────────────────────────
	local showDist = (sharedEsp.DistanceESP and sharedEsp.DistanceESP.Value) or false
	if showDist and onScreen then
		local offX = sharedEsp.NameXOffset.Value
		obj.distLabel.Text         = GetDist(char) .. "m"
		obj.distLabel.TextColor3   = Color3.fromRGB(180, 180, 180)
		obj.distLabel.Font         = font
		obj.distLabel.TextSize     = 11
		obj.distLabel.ts.Thickness = 1
		obj.distLabel.ts.Color     = Color3.new(0, 0, 0)
		obj.distLabel.Position     = UDim2.new(0, x + w * 0.5 + offX, 0, y + h + 4)
		obj.distLabel.Visible      = true
	else
		obj.distLabel.Visible = false
	end

	-- ── HIGHLIGHT ────────────────────────────
	if sharedEsp.HighlightEnabled.Value and hrp then
		local fillColor    = GetHighlightColor(sharedEsp.HighlightFillColor.Value)
		local outlineColor = GetHighlightColor(sharedEsp.HighlightOutlineColor.Value)
		local fillT        = math.clamp(sharedEsp.HighlightFillTransparency.Value, 0, 1)
		local outT         = math.clamp(sharedEsp.HighlightOutlineTransparency.Value, 0, 1)
		local extra        = sharedEsp.HighlightExtra.Value
		if extra == 'Flicker' then
			local visible = math.random() > 0.4
			fillT = visible and fillT or 1
		elseif extra == 'Breathe' then
			local speed = GetPulseSpeed()
			local t     = (EspPulseTimer % speed) / speed
			local alpha = math.abs(math.sin(t * math.pi))
			fillT = fillT + (1 - fillT) * alpha
		end
		if not obj.highlight:FindFirstChild("Adornee") then
			obj.highlight.Adornee = char
		end
		obj.highlight.FillColor            = fillColor
		obj.highlight.OutlineColor         = outlineColor
		obj.highlight.FillTransparency     = math.clamp(fillT, 0, 1)
		obj.highlight.OutlineTransparency  = math.clamp(outT, 0, 1)
		obj.highlight.DepthMode            = sharedEsp.HighlightThroughWalls.Value
			and Enum.HighlightDepthMode.AlwaysOnTop
			or  Enum.HighlightDepthMode.Occluded
		obj.highlight.Enabled = true
	else
		obj.highlight.Enabled = false
	end

	-- ── TRACER ───────────────────────────────
	-- Origin: configurable screen point (bottom / center / top / mouse).
	-- Target: top of HRP so the line visually "arrives" at the player model.
	local showTracer = sharedEsp.TracerESP and sharedEsp.TracerESP.Value or false
	if showTracer then
		-- lazily allocate frames once per player — never re-created each frame
		if not tracerCache[player] then
			tracerCache[player] = MakeTracerLine(espColor)
		end
		local t = tracerCache[player]

		-- project the top of the HRP to screen space
		local targetWorld = hrp.Position + Vector3.new(0, hrp.Size.Y * 0.5, 0)
		local targetSP, targetOn = EspCamera:WorldToViewportPoint(targetWorld)

		if targetOn and targetSP.Z > 0 then
			local origin = GetTracerOrigin()                    -- from   (screen origin)
			local target = Vector2.new(targetSP.X, targetSP.Y) -- to     (player on screen)
			SetTracerLine(t, origin, target, espColor)
		else
			t.line.Visible    = false
			t.outline.Visible = false
		end
	else
		-- tracer toggled off — just hide existing frames, don't destroy them
		local t = tracerCache[player]
		if t then
			t.line.Visible    = false
			t.outline.Visible = false
		end
	end
end

-- ═══════════════════════════════════════════
--  PLAYER ADDED / REMOVED
-- ═══════════════════════════════════════════
local function OnEspPlayerAdded(player)
	if player == EspLocalPlayer then return end
	CreateEsp(player)
end

for _, p in ipairs(EspPlayers:GetPlayers()) do
	OnEspPlayerAdded(p)
end

EspPlayers.PlayerAdded:Connect(OnEspPlayerAdded)

EspPlayers.PlayerRemoving:Connect(function(player)
	DestroyEsp(player)
end)

-- ═══════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════
EspRunService.Heartbeat:Connect(function(dt)
	EspRainbowHue = (EspRainbowHue + 0.003) % 1
	EspPulseTimer = EspPulseTimer + dt
	updateTracerAttachment()
	for player in pairs(EspObjects) do
		if player.Parent then
			UpdateEsp(player)
		else
			DestroyEsp(player)
		end
	end
end)
