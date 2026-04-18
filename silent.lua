-- SILENT AIM v1 by oblivion
-- Completed

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
--  GET PLAYER IN FOV  (fixed – proper FOV radius check)
-- ═══════════════════════════════════════════
local function GetPlayerInFov()
	local closestPlayer  = nil
	local shortestDist   = math.huge          -- start at infinity so any hit replaces it
	local mousePosition  = UserInputService:GetMouseLocation()
	local fovRadius      = GetFovRadius()

	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character  then continue end

		-- Team check
		if TeamCheck and player.Team ~= nil and player.Team == localPlayer.Team then continue end

		local aimPart = player.Character:FindFirstChild(Targetpart)
			or player.Character:FindFirstChild("Head")
		if not aimPart then continue end

		-- Distance (studs) check
		local myChar = localPlayer.Character
		local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if myHRP and (aimPart.Position - myHRP.Position).Magnitude > distance then continue end

		local sp, onScreen = camera:WorldToViewportPoint(aimPart.Position)
		if not onScreen or sp.Z <= 0 then continue end

		local screenPos = Vector2.new(sp.X, sp.Y)
		local pixelDist = (screenPos - mousePosition).Magnitude

		-- Must be inside the FOV circle
		if pixelDist > fovRadius then continue end

		if pixelDist < shortestDist then
			shortestDist  = pixelDist
			closestPlayer = player
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
--  OBSTRUCTED BY ANOTHER PLAYER
--  (returns true if a *different* player's character is between us and the target)
-- ═══════════════════════════════════════════
local function IsObstructedByPlayer(targetChar)
	if not targetChar then return false end
	local myChar = localPlayer.Character
	if not myChar then return false end

	local origin = camera.CFrame.Position
	local hrp    = targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local dir = hrp.Position - origin

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {myChar, targetChar}
	rp.IgnoreWater = true

	local res = workspace:Raycast(origin, dir, rp)
	if res and res.Instance then
		-- hit something else – check if it belongs to another player
		for _, p in Players:GetPlayers() do
			if p ~= localPlayer and p.Character and res.Instance:IsDescendantOf(p.Character) then
				return true
			end
		end
	end
	return false
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
--  CHARACTER CACHE
-- ═══════════════════════════════════════════
local function RefreshCache()
	lastCache = tick()
	table.clear(cachedCharacters)
	for _, p in Players:GetPlayers() do
		if p ~= localPlayer and p.Character then
			local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(cachedCharacters, p.Character)
			end
		end
	end
end

-- ═══════════════════════════════════════════
--  DRIFT  (subtle humanisation)
-- ═══════════════════════════════════════════
local function UpdateDrift(dt)
	driftX = math.sin(tick() * 1.3 + driftSeedX) * 0.6
	driftY = math.cos(tick() * 1.1 + driftSeedY) * 0.6
end

-- ═══════════════════════════════════════════
--  FIND TARGET
-- ═══════════════════════════════════════════
local function FindTarget()
	RefreshCache()

	-- Re-use locked target if still valid
	if lockedTarget and lockedTarget.Parent then
		local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then
			local part = (lockedAimPart and lockedAimPart.Parent == lockedTarget)
				and lockedAimPart or ChooseAimPart(lockedTarget)

			if part and IsInRange(part) then
				local ok, scr = InFov(part.Position)
				if ok and IsVisible(part) and not IsObstructedByPlayer(lockedTarget) then
					return part, scr
				end
			end
		end
	end

	lockedTarget  = nil
	lockedAimPart = nil

	local screenCenter = cachedViewport * 0.5
	local candidates   = {}

	for _, char in cachedCharacters do
		local plr = Players:GetPlayerFromCharacter(char)
		if SafeTeamCheck(plr) then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not IsInRange(root) then continue end
		if not IsVisible(root) then continue end
		if IsObstructedByPlayer(char) then continue end

		local part = ChooseAimPart(char)
		if not part then continue end

		local ok, scr = InFov(part.Position)
		if ok and scr then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			table.insert(candidates, {
				part      = part,
				char      = char,
				screenPos = scr,
				distance  = (root.Position - camera.CFrame.Position).Magnitude,
				health    = hum and hum.Health or 100,
			})
		end
	end

	if #candidates == 0 then return nil, nil end

	if targetpriority == "Distance" then
		table.sort(candidates, function(a, b) return a.distance < b.distance end)
	elseif targetpriority == "Health" then
		table.sort(candidates, function(a, b) return a.health < b.health end)
	elseif targetpriority == "Random" then
		local pick     = candidates[math.random(#candidates)]
		lockedTarget   = pick.char
		lockedAimPart  = pick.part
		return pick.part, pick.screenPos
	else -- Closest to crosshair
		table.sort(candidates, function(a, b)
			return (a.screenPos - screenCenter).Magnitude < (b.screenPos - screenCenter).Magnitude
		end)
	end

	local best    = candidates[1]
	lockedTarget  = best.char
	lockedAimPart = best.part
	return best.part, best.screenPos
end

-- ═══════════════════════════════════════════
--  LEGIT MODE — lock camera toward target head
--  (same method as the reference in the task comments)
-- ═══════════════════════════════════════════
local function LegitLockCamera(targetChar)
	if not targetChar then return end
	local head = targetChar:FindFirstChild("Head")
	if not head then return end

	local headPos = camera:WorldToViewportPoint(head.Position)
	if headPos.Z <= 0 then return end

	local camPos  = camera.CFrame.Position
	camera.CFrame = CFrame.new(camPos, head.Position)
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
	print("SILENT AIM v1 Loaded!333")
	fovCircle = silentshared and silentshared.fovCircle or nil
	RunService.RenderStepped:Connect(UpdateFOVCircle)
	RunService.Heartbeat:Connect(MainLoop)
	print("SILENT AIM v1 Ready!")
end)
