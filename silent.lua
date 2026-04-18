-- SILENT AIM v1 FIXED by oblivion
-- Fixed targeting logic

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local silentshared = shared.SilentAim

-- ═══════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════
local isAiming         = false
local currentTarget    = nil
local lockedTarget     = nil
local lockedAimPart    = nil
local cachedViewport   = Vector2.zero
local cachedCharacters = {}
local lastCache        = 0
local fovCirclePos     = nil
local lastTime         = tick()
local fovCircle        = nil
local toggleState      = false
local lastKeyState     = false
local targetHitChance  = {}

local driftX, driftY = 0, 0
local driftSeedX = math.random() * 100
local driftSeedY = math.random() * 50 + 50

-- ═══════════════════════════════════════════
--  LIVE SETTINGS  (updated every frame from silentshared)
-- ═══════════════════════════════════════════
local Active         = false
local LegitAim       = false
local TeamCheck      = false
local WallCheck      = false
local HitChance      = 95
local HeadshotChance = 68
local BodyShotChance = 92
local Fov            = 90
local distance       = 1000
local Targetpart     = "Head"
local targetpriority = "Closest"
local Mode           = "Hold"
local AimKey         = "MB2"

-- ═══════════════════════════════════════════
--  UPDATE SETTINGS FROM SHARED
-- ═══════════════════════════════════════════
local function UpdateSettings()
	if not silentshared then return end
	pcall(function()
		-- Toggles
		Active         = silentshared.Active       and silentshared.Active.Value       or false
		LegitAim       = silentshared.LegitAim     and silentshared.LegitAim.Value     or false
		TeamCheck      = silentshared.TeamCheck     and silentshared.TeamCheck.Value    or false
		WallCheck      = silentshared.WallCheck     and silentshared.WallCheck.Value    or false

		-- Sliders / values
		HitChance      = silentshared.HitChance     and silentshared.HitChance.Value    or 95
		HeadshotChance = silentshared.HeadshotChance and silentshared.HeadshotChance.Value or 68
		BodyShotChance = silentshared.BodyShotChance and silentshared.BodyShotChance.Value or 92
		Fov            = silentshared.Fov           and silentshared.Fov.Value          or 90
		distance       = silentshared.distance      and silentshared.distance.Value     or 1000

		-- Dropdowns
		Targetpart     = silentshared.TargetBodyPart   and silentshared.TargetBodyPart.Value   or "Head"
		targetpriority = silentshared.TargetPriority   and silentshared.TargetPriority.Value   or "Closest"

		-- Key picker — Value is the key string e.g. "MB2", "E", "None"
		local keyPicker = silentshared.SilentAimKey
		AimKey = keyPicker and keyPicker.Value or "MB2"

		-- Mode comes from the key picker's Mode field ("Hold" / "Toggle" / "Always")
		Mode = keyPicker and keyPicker.Mode or "Hold"

		-- FOV circle reference
		fovCircle = silentshared.fovCircle or fovCircle

		-- Legit mode overrides: make hit/headshot chances realistic
		if LegitAim then
			HitChance      = math.clamp(math.random(60, 80), 0, 100)
			HeadshotChance = math.clamp(math.random(20, 45), 0, 100)
			BodyShotChance = math.clamp(math.random(55, 75), 0, 100)
		end
	end)
end

-- ═══════════════════════════════════════════
--  LOBBY CHECK
-- ═══════════════════════════════════════════
local function isLobbyVisible()
	local ok, result = pcall(function()
		return localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible == true
	end)
	return ok and result or false
end

-- ═══════════════════════════════════════════
--  RAYCAST PARAMS
-- ═══════════════════════════════════════════
local rayParams = RaycastParams.new()
rayParams.FilterType  = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- ═══════════════════════════════════════════
--  FOV HELPERS
-- ═══════════════════════════════════════════

-- Convert the Fov slider value (degrees) into a screen-space pixel radius.
local function GetFovRadius()
	return (Fov / 180) * (camera.ViewportSize.Y / 2)
end

-- Check whether a world position falls inside the circular FOV.
-- Returns: inFov (bool), screenPos (Vector2 | nil)
local function InFov(worldPos)
	local sp, onScreen = camera:WorldToViewportPoint(worldPos)
	if not onScreen or sp.Z <= 0 then return false, nil end

	local screenPos   = Vector2.new(sp.X, sp.Y)
	local mousePos    = UserInputService:GetMouseLocation()
	local radius      = GetFovRadius()

	if (screenPos - mousePos).Magnitude <= radius then
		return true, screenPos
	end
	return false, nil
end

-- ═══════════════════════════════════════════
--  GET CLOSEST PLAYER TO MOUSE (SIMPLIFIED)
-- ═══════════════════════════════════════════
local function GetClosestPlayerToMouse()
	local closestPlayer  = nil
	local shortestDist   = math.huge
	local mousePosition  = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end

		-- Team check
		if TeamCheck and player.Team ~= nil and player.Team == localPlayer.Team then continue end

		local head = player.Character:FindFirstChild("Head")
		if not head then continue end

		-- Distance check (studs)
		local myChar = localPlayer.Character
		local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if myHRP and (head.Position - myHRP.Position).Magnitude > distance then continue end

		local headPosition, onScreen = camera:WorldToViewportPoint(head.Position)
		if not onScreen or headPosition.Z <= 0 then continue end

		local screenPosition = Vector2.new(headPosition.X, headPosition.Y)
		local pixelDist = (screenPosition - mousePosition).Magnitude

		if pixelDist < shortestDist then
			closestPlayer = player
			shortestDist = pixelDist
		end
	end

	return closestPlayer
end

-- ═══════════════════════════════════════════
--  WALL CHECK / RANGE
-- ═══════════════════════════════════════════
local function IsVisible(targetPart)
	if not WallCheck or not targetPart then return true end
	local char = localPlayer.Character
	if not char then return true end
	rayParams.FilterDescendantsInstances = {char}
	local dir = targetPart.Position - camera.CFrame.Position
	local res = workspace:Raycast(camera.CFrame.Position, dir, rayParams)
	return not res or (res.Instance and res.Instance:IsDescendantOf(targetPart.Parent))
end

local function IsInRange(part)
	if not part or not part.Parent then return false end
	return (part.Position - camera.CFrame.Position).Magnitude <= distance
end

-- ═══════════════════════════════════════════
--  TEAM CHECK HELPER
-- ═══════════════════════════════════════════
local function SafeTeamCheck(plr)
	if not TeamCheck then return false end
	if not plr then return true end
	return plr.Team ~= nil and plr.Team == localPlayer.Team
end

-- ═══════════════════════════════════════════
--  AIM PART CHOOSER
-- ═══════════════════════════════════════════
local function ChooseAimPart(char)
	if not char then return nil end
	local preferred = char:FindFirstChild(Targetpart)
	if preferred then return preferred end
	return char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
end

-- ═══════════════════════════════════════════
--  HIT CHANCE
-- ═══════════════════════════════════════════
local function ShouldHitTarget(part)
	if not part then return true end
	if targetHitChance[part] == nil then
		targetHitChance[part] = math.random(100) <= HitChance
	end
	return targetHitChance[part]
end

-- ═══════════════════════════════════════════
--  DRIFT  (subtle humanisation)
-- ═══════════════════════════════════════════
local function UpdateDrift(dt)
	driftX = math.sin(tick() * 1.3 + driftSeedX) * 0.6
	driftY = math.cos(tick() * 1.1 + driftSeedY) * 0.6
end

-- ═══════════════════════════════════════════
--  FIND TARGET (SIMPLIFIED - NO FOV LOCK)
-- ═══════════════════════════════════════════
local function FindTarget()
	-- Get closest player to mouse (not restricted by FOV)
	local targetPlayer = GetClosestPlayerToMouse()
	
	if not targetPlayer or not targetPlayer.Character then
		lockedTarget = nil
		lockedAimPart = nil
		return nil, nil
	end

	-- Get aim part
	local part = ChooseAimPart(targetPlayer.Character)
	if not part then return nil, nil end

	-- Get screen position
	local sp, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen or sp.Z <= 0 then return nil, nil end

	local screenPos = Vector2.new(sp.X, sp.Y)

	lockedTarget = targetPlayer.Character
	lockedAimPart = part

	return part, screenPos
end

-- ═══════════════════════════════════════════
--  LEGIT MODE — lock camera toward target head
--  (SIMPLIFIED - directly from working reference)
-- ═══════════════════════════════════════════
local function LegitLockCamera(targetChar)
	if not targetChar then return end
	local head = targetChar:FindFirstChild("Head")
	if not head then return end

	local headPosition = camera:WorldToViewportPoint(head.Position)
	if headPosition.Z <= 0 then return end

	local cameraPosition = camera.CFrame.Position
	camera.CFrame = CFrame.new(cameraPosition, head.Position)
end

-- ═══════════════════════════════════════════
--  SHOW TARGET HIGHLIGHT
-- ═══════════════════════════════════════════
local showTargetHL = nil

local function UpdateShowTarget(targetChar)
	local shouldShow = silentshared and silentshared.ShowTarget and silentshared.ShowTarget.Value or false

	if not shouldShow or not targetChar then
		if showTargetHL then
			showTargetHL.Enabled = false
		end
		return
	end

	if not showTargetHL then
		showTargetHL = Instance.new("Highlight")
		showTargetHL.Name                = "SilentAimHL"
		showTargetHL.FillColor           = Color3.fromRGB(255, 80, 80)
		showTargetHL.OutlineColor        = Color3.fromRGB(255, 255, 255)
		showTargetHL.FillTransparency    = 0.5
		showTargetHL.OutlineTransparency = 0
		showTargetHL.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
		showTargetHL.Parent              = workspace
	end

	if showTargetHL.Parent ~= targetChar then
		showTargetHL.Parent = targetChar
	end
	showTargetHL.Enabled = true
end

-- ═══════════════════════════════════════════
--  AIM KEY CHECK
-- ═══════════════════════════════════════════
local function IsAimKeyDown()
	if not AimKey or AimKey == "None" or AimKey == "" then return false end

	if AimKey:match("^MB%d") then
		local n = tonumber(AimKey:match("%d"))
		if n then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton" .. n])
		end
	end

	local keyEnum = Enum.KeyCode[AimKey]
	if keyEnum then
		return UserInputService:IsKeyDown(keyEnum)
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

	local showFov      = silentshared and silentshared.Showfov  and silentshared.Showfov.Value  or false
	local aimbotActive = silentshared and silentshared.Active   and silentshared.Active.Value   or false

	if not showFov or not aimbotActive then
		pcall(function() fovCircle.Visible = false end)
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local radius   = GetFovRadius()

	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos

	pcall(function()
		fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
		fovCircle.Size     = UDim2.new(0, radius * 2, 0, radius * 2)
		fovCircle.Visible  = true
	end)
end

-- ═══════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════
local function MainLoop()
	cachedViewport = camera.ViewportSize

	local now = tick()
	local dt  = math.clamp(now - lastTime, 0.001, 0.06)
	lastTime  = now

	UpdateSettings()

	-- Lobby guard — disable while in lobby UI
	if isLobbyVisible() then
		currentTarget = nil
		if showTargetHL then showTargetHL.Enabled = false end
		return
	end

	local keyDown = IsAimKeyDown()

	if Mode == "Hold" then
		isAiming = Active and keyDown
	elseif Mode == "Toggle" then
		if keyDown and not lastKeyState then
			toggleState = not toggleState
		end
		lastKeyState = keyDown
		isAiming = Active and toggleState
	elseif Mode == "Always" then
		isAiming = Active
	else
		isAiming = Active and keyDown
	end

	if not isAiming then
		currentTarget = nil
		table.clear(targetHitChance)
		UpdateShowTarget(nil)
		return
	end

	UpdateDrift(dt)

	local part, _ = FindTarget()
	currentTarget = part

	if part then
		-- Hit / headshot chance roll
		if not ShouldHitTarget(part) then
			UpdateShowTarget(nil)
			return
		end

		local targetChar = part.Parent

		-- ShowTarget highlight
		UpdateShowTarget(targetChar)

		-- Legit mode: smoothly rotate camera toward the target head
		-- Normal mode: camera stays put — bullet redirection is handled by
		-- whatever hook calls currentTarget externally (e.g. FireBullet hook).
		if LegitAim then
			LegitLockCamera(targetChar)
		end
	else
		UpdateShowTarget(nil)
	end
end

-- ═══════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════
task.delay(1, function()
	print("SILENT AIM v1 FIXED Loaded!")
	fovCircle = silentshared and silentshared.fovCircle or nil
	RunService.RenderStepped:Connect(UpdateFOVCircle)
	RunService.Heartbeat:Connect(MainLoop)
	print("SILENT AIM v1 FIXED Ready!")
end)
