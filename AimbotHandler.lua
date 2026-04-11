-- Aimbot Handler - v2 (Smarter Prediction Upgrade Integrated)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local isAiming = false
local currentTarget = nil
local lockedTarget = nil
local lockedAimPart = nil
local cachedViewport = Vector2.zero
local cachedCharacters = {}
local lastCache = 0
local settingsCounter = 0
local fovCirclePos = nil
local lastTime = tick()
local fovCircle = nil

local targetpart = nil
local Mode = nil
local AimKey = nil

-- ✅ MODE SYSTEM STATE
local toggleState = false
local lastKeyState = false

-- ── Drift ─────────────────────────────────────────────────
local driftX, driftY = 0, 0
local driftSeedX = math.random() * 100
local driftSeedY = math.random() * 100 + 50

-- ── Settings ──────────────────────────────────────────────
local Active = false
local LegitAim = false
local TeamCheck = false
local WallCheck = false
local SmarterPredictions = false
local HitChance = 95
local HeadshotChance = 68
local BodyShotChance = 92
local Xsmoothness = 0.55
local Ysmoothness = 0.55
local Prediction = 0
local Fov = 90
local Strength = 0.85
local ShakeIntensity = 0
local distance = 1000

local sharedAim = shared.Aim or nil
local Toggles = getgenv().Toggles or {}
local Options = getgenv().Options or {}

-- 🔥 SMART PRED STORAGE
local lastVelocities = {}
local lastPositions = {}

local function GetVelocity(part, dt)
	local lastPos = lastPositions[part]
	local currentPos = part.Position

	if not lastPos then
		lastPositions[part] = currentPos
		return part.AssemblyLinearVelocity or Vector3.zero
	end

	local velocity = (currentPos - lastPos) / math.max(dt, 0.016)
	lastPositions[part] = currentPos
	return velocity
end

local function UpdateSettings()
	pcall(function()
		if not sharedAim then return end

		Active = (sharedAim["Active"] and sharedAim["Active"].Value) or false
		LegitAim = (sharedAim["LegitAim"] and sharedAim["LegitAim"].Value) or false
		TeamCheck = (sharedAim["TeamCheck"] and sharedAim["TeamCheck"].Value) or false
		WallCheck = (sharedAim["WallCheck"] and sharedAim["WallCheck"].Value) or false
		SmarterPredictions = (sharedAim["SmarterPredictions"] and sharedAim["SmarterPredictions"].Value) or false
		Prediction = math.clamp(tonumber(sharedAim["Prediction"] and sharedAim["Prediction"].Value) or 0, 0, 100)
		HitChance = math.clamp(tonumber(sharedAim["HitChance"] and sharedAim["HitChance"].Value) or 95, 0, 100)
		HeadshotChance = math.clamp(tonumber(sharedAim["HeadshotChance"] and sharedAim["HeadshotChance"].Value) or 68, 0, 100)
		BodyShotChance = math.clamp(tonumber(sharedAim["BodyShotChance"] and sharedAim["BodyShotChance"].Value) or 92, 0, 100)
		Xsmoothness = math.clamp(tonumber(sharedAim["Xsmoothness"] and sharedAim["Xsmoothness"].Value) or 0.55, 0.01, 1)
		Ysmoothness = math.clamp(tonumber(sharedAim["Ysmoothness"] and sharedAim["Ysmoothness"].Value) or 0.55, 0.01, 1)
		Fov = math.clamp(tonumber(sharedAim["Fov"] and sharedAim["Fov"].Value) or 90, 1, 180)
		Strength = math.clamp(tonumber(sharedAim["Strength"] and sharedAim["Strength"].Value) or 85, 0, 100) / 100
		distance = math.clamp(tonumber(sharedAim["distance"] and sharedAim["distance"].Value) or 1000, 1, 10000)

		Mode = (sharedAim["AimbotMode"] and sharedAim["AimbotMode"].Value) or "Hold"
		AimKey = (sharedAim["AimbotActivateKey"] and sharedAim["AimbotActivateKey"].Value) or "MB2"
		targetpart = (sharedAim["AimbotTargetPart"] and sharedAim["AimbotTargetPart"].Value) or "UpperTorso"
	end)
end

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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function IsVisible(targetPart)
	if not WallCheck or not targetPart then return true end
	local char = Player.Character
	if not char then return true end
	rayParams.FilterDescendantsInstances = {char}
	local dir = targetPart.Position - Camera.CFrame.Position
	local res = workspace:Raycast(Camera.CFrame.Position, dir, rayParams)
	return not res or (res.Instance and res.Instance:IsDescendantOf(targetPart.Parent))
end

local function IsInRange(part)
	if not part then return false end
	local studs = (part.Position - Camera.CFrame.Position).Magnitude
	return studs <= distance
end

local function PredictPos(part, dt)
	if not part then return Vector3.zero end

	local pos = part.Position
	local vel = part.AssemblyLinearVelocity or Vector3.zero

	if not SmarterPredictions then
		if Prediction <= 0 then return pos end
		return pos + vel * (Prediction * 0.01)
	end

	local realVel = GetVelocity(part, dt)

	local lastVel = lastVelocities[part] or realVel
	local accel = (realVel - lastVel)
	lastVelocities[part] = realVel

	local dist = (pos - Camera.CFrame.Position).Magnitude

	local travelTime = (dist / 300) + (Prediction * 0.01)
	travelTime = math.clamp(travelTime, 0.01, 0.35)

	if realVel.Magnitude < 2 then
		return pos
	end

	return pos + realVel * travelTime + accel * (travelTime ^ 2) * 0.5
end

local function InFov(worldPos)
	local screen, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen or screen.Z < 0.1 then return false, nil end
	local screenCenter = cachedViewport * 0.5
	local dist = (Vector2.new(screen.X, screen.Y) - screenCenter).Magnitude
	local rad = (Fov / 180) * (cachedViewport.Y * 0.5)
	return dist <= rad, Vector2.new(screen.X, screen.Y)
end

local function ChooseAimPart(char)
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")

	if not head then return torso end

	local r = math.random(100)
	if r <= HeadshotChance then return head end
	if r <= HeadshotChance + BodyShotChance then return torso end
	return torso
end

local function FindTarget(dt)
	RefreshCache()

	if lockedTarget and lockedTarget.Parent then
		local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then
			local part = (lockedAimPart and lockedAimPart.Parent == lockedTarget)
				and lockedAimPart or ChooseAimPart(lockedTarget)

			if part and IsInRange(part) then
				local pred = PredictPos(part, dt)
				local ok, scr = InFov(pred)
				if ok and IsVisible(part) then
					return part, scr
				end
			end
		end
	end

	lockedTarget = nil
	lockedAimPart = nil

	local screenCenter = cachedViewport * 0.5
	local closest, minDist, bestScr = nil, math.huge, nil

	for _, char in cachedCharacters do
		local plr = Players:GetPlayerFromCharacter(char)
		if TeamCheck and plr and plr.Team == Player.Team then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not IsInRange(root) or not IsVisible(root) then continue end

		local part = ChooseAimPart(char)
		local pred = PredictPos(part, dt)
		local ok, scr = InFov(pred)

		if ok and scr then
			local d = (scr - screenCenter).Magnitude
			if d < minDist then
				minDist = d
				closest = part
				bestScr = scr
			end
		end
	end

	if closest then
		lockedTarget = closest.Parent
		lockedAimPart = closest
	end

	return closest, bestScr
end

local function UpdateDrift(dt)
	if not isAiming or not currentTarget then
		driftX, driftY = 0, 0
		return
	end

	driftSeedX += dt * 1.8
	driftSeedY += dt * 2.3

	local amp = 0.013
	driftX = math.sin(driftSeedX * 3.4) * amp
	driftY = math.cos(driftSeedY * 2.7) * amp
end

local function ApplyMouseMove(targetWorldPos, dt)
	if not targetWorldPos then return end

	local vp = Camera:WorldToViewportPoint(targetWorldPos)
	if vp.Z <= 0 then return end

	local mouse = UserInputService:GetMouseLocation()

	local dx = (vp.X + driftX) - mouse.X
	local dy = (vp.Y + driftY) - mouse.Y

	if math.random(100) > HitChance then return end

	local smoothX = (1 - Xsmoothness) * Strength
	local smoothY = (1 - Ysmoothness) * Strength

	pcall(function()
		mousemoverel(dx * smoothX, dy * smoothY)
	end)
end

local function UpdateFOVCircle()
	if not fovCircle then 
		fovCircle = shared.Aim.fovCircle
	end
	if not fovCircle then return end

	local showFov = shared.Aim.ShowFOV and shared.Aim.ShowFOV.Value or false
	local aimbotActive = shared.Aim.Active and shared.Aim.Active.Value or false

	if not showFov or not aimbotActive then
		fovCircle.Visible = false
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)

	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos

	fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
	fovCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)

	fovCircle.Visible = true
end

-- ✅ UPDATED KEY HANDLER (LINORIA SUPPORT)
local function IsAimKeyDown()
	if AimKey == "MB2" then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	elseif AimKey == "MB1" then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	else
		local keyEnum = Enum.KeyCode[AimKey]
		return keyEnum and UserInputService:IsKeyDown(keyEnum)
	end
end

local function MainLoop()
	cachedViewport = Camera.ViewportSize

	local now = tick()
	local dt = math.clamp(now - lastTime, 0.001, 0.06)
	lastTime = now

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

	elseif Mode == "Always" then
		isAiming = Active
	end

	if not isAiming then
		currentTarget = nil
		return
	end

	UpdateDrift(dt)

	local part = FindTarget(dt)
	currentTarget = part

	if part then
		ApplyMouseMove(PredictPos(part, dt), dt)
	end
end

task.delay(1, function()
	print("Updating aimbot...")
	fovCircle = shared.Aim.fovCircle
	RunService.RenderStepped:Connect(UpdateFOVCircle)
	RunService.Heartbeat:Connect(MainLoop)
	print("Loaded aimbot...")
end)
