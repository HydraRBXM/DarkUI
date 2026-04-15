-- Aimbot Handler - v3 OPTIMIZED (Sticky Aim + Performance + Smoothing Fix)

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
local lastTime = tick()

local targetpart = nil
local Mode = nil
local AimKey = nil

-- MODE STATE
local toggleState = false
local lastKeyState = false

-- Drift
local driftX, driftY = 0, 0
local driftSeedX = math.random() * 100
local driftSeedY = math.random() * 50 + 50

-- Settings
local Active = false
local LegitAim = false
local TeamCheck = false
local WallCheck = false
local SmarterPredictions = false
local HitChance = 95
local Xsmoothness = 0.55
local Ysmoothness = 0.55
local Prediction = 0
local Fov = 90
local Strength = 0.85
local distance = 1000
local targetpriority = "Closest"
local Targetpart = "Head"

local sharedAim = shared.Aim or nil

-- Smart prediction storage
local lastVelocities = {}
local lastPositions = {}
local targetHitChance = {}

-- Team check safe
local function SafeTeamCheck(plr)
	if not TeamCheck or not plr then return false end
	if not Player.Team or not plr.Team then return false end
	return plr.Team == Player.Team
end

-- Velocity calc
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

-- Clean memory
local function CleanVelocityCache()
	for part in pairs(lastVelocities) do
		if not part or not part.Parent then
			lastVelocities[part] = nil
			lastPositions[part] = nil
			targetHitChance[part] = nil
		end
	end
end

-- Settings update
local function UpdateSettings()
	pcall(function()
		if not sharedAim then return end

		Active = sharedAim.Active.Value
		LegitAim = sharedAim.LegitAim.Value
		TeamCheck = sharedAim.TeamCheck.Value
		WallCheck = sharedAim.WallCheck.Value
		SmarterPredictions = sharedAim.SmarterPredictions.Value
		Prediction = math.clamp(sharedAim.Prediction.Value, 0, 100)
		HitChance = math.clamp(sharedAim.HitChance.Value, 0, 100)

		Xsmoothness = math.clamp(sharedAim.Xsmoothness.Value, 0.001, 1)
		Ysmoothness = math.clamp(sharedAim.Ysmoothness.Value, 0.001, 1)

		Fov = math.clamp(sharedAim.Fov.Value, 1, 180)
		Strength = math.clamp(sharedAim.Strength.Value, 0, 100) / 100
		distance = math.clamp(sharedAim.distance.Value, 1, 10000)

		Mode = sharedAim.AimbotMode.Value
		AimKey = sharedAim.AimbotActivateKey.Value
		targetpriority = sharedAim.AimbotTargetPriority.Value
		Targetpart = sharedAim.AimbotTargetPart.Value
	end)
end

-- Cache players (LOW FREQUENCY)
local function RefreshCache()
	table.clear(cachedCharacters)
	for _, p in Players:GetPlayers() do
		if p ~= Player and p.Character then
			local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(cachedCharacters, p.Character)
			end
		end
	end
	lastCache = tick()
end

-- Raycast
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function IsVisible(targetPart)
	if not WallCheck or not targetPart then return true end
	local char = Player.Character
	if not char then return true end

	rayParams.FilterDescendantsInstances = {char}

	local res = workspace:Raycast(
		Camera.CFrame.Position,
		targetPart.Position - Camera.CFrame.Position,
		rayParams
	)

	return not res or (res.Instance and res.Instance:IsDescendantOf(targetPart.Parent))
end

local function IsInRange(part)
	return part and (part.Position - Camera.CFrame.Position).Magnitude <= distance
end

-- Prediction
local function PredictPos(part, dt)
	if not part then return Vector3.zero end

	local pos = part.Position
	local vel = part.AssemblyLinearVelocity or Vector3.zero

	if not SmarterPredictions then
		return pos + vel * (Prediction * 0.01)
	end

	local realVel = GetVelocity(part, dt)
	local lastVel = lastVelocities[part] or realVel
	local accel = (realVel - lastVel)
	lastVelocities[part] = realVel

	local dist = (pos - Camera.CFrame.Position).Magnitude
	local t = math.clamp((dist / 300) + (Prediction * 0.01), 0.01, 0.35)

	return pos + realVel * t + accel * (t^2) * 0.5
end

-- FOV check
local function InFov(worldPos)
	local screen, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen or screen.Z < 0.1 then return false end

	local center = cachedViewport * 0.5
	local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
	local radius = (Fov / 180) * (cachedViewport.Y * 0.5)

	return dist <= radius, Vector2.new(screen.X, screen.Y)
end

-- Aim part
local function ChooseAimPart(char)
	return char:FindFirstChild(Targetpart)
		or char:FindFirstChild("Head")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("HumanoidRootPart")
end

-- Hit chance
local function ShouldHitTarget(part)
	if targetHitChance[part] == nil then
		targetHitChance[part] = math.random(100) <= HitChance
	end
	return targetHitChance[part]
end

-- 🔒 STICKY AIM + FAST TARGETING
local function FindTarget(dt)
	-- KEEP LOCK
	if lockedTarget and lockedTarget.Parent then
		local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then
			local part = lockedAimPart or ChooseAimPart(lockedTarget)

			if part and IsInRange(part) then
				if WallCheck and not IsVisible(part) then
					lockedTarget = nil
				else
					local pred = PredictPos(part, dt)
					local ok = InFov(pred)
					if ok then return part end
				end
			end
		end
	end

	-- FIND NEW (NO TABLES = FAST)
	local bestPart, bestScore = nil, math.huge
	local center = cachedViewport * 0.5

	for _, char in cachedCharacters do
		local plr = Players:GetPlayerFromCharacter(char)
		if SafeTeamCheck(plr) then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not IsInRange(root) then continue end
		if WallCheck and not IsVisible(root) then continue end

		local part = ChooseAimPart(char)
		local pred = PredictPos(part, dt)
		local ok, scr = InFov(pred)

		if ok and scr then
			local score = (scr - center).Magnitude

			if score < bestScore then
				bestScore = score
				bestPart = part
				lockedTarget = char
				lockedAimPart = part
			end
		end
	end

	return bestPart
end

-- Drift
local function UpdateDrift(dt)
	if not isAiming or not currentTarget then
		driftX, driftY = 0, 0
		return
	end

	driftSeedX += dt * 2
	driftSeedY += dt * 2

	driftX = math.sin(driftSeedX) * 0.01
	driftY = math.cos(driftSeedY) * 0.01
end

-- Key check
local function IsAimKeyDown()
	-- 🔥 FIX: handle nil / invalid AimKey
	if not AimKey or AimKey == "" then
		return false
	end

	-- Mouse buttons (MB1, MB2, etc)
	if typeof(AimKey) == "string" and AimKey:match("^MB%d") then
		local num = tonumber(AimKey:match("%d"))
		if num then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton"..num])
		end
	end

	-- Keyboard keys
	if typeof(AimKey) == "string" then
		local keyEnum = Enum.KeyCode[AimKey]
		if keyEnum then
			return UserInputService:IsKeyDown(keyEnum)
		end
	end

	return false
end

-- Apply aim (SMOOTH FIXED)
local function ApplyMouseMove(pos, dt)
	if not pos or not currentTarget then return end
	if not ShouldHitTarget(currentTarget) then return end

	local vp = Camera:WorldToViewportPoint(pos)
	if vp.Z <= 0 then return end

	local mouse = UserInputService:GetMouseLocation()
	local dx = (vp.X + driftX) - mouse.X
	local dy = (vp.Y + driftY) - mouse.Y

	local smoothX = math.max(0.001, Xsmoothness)
	local smoothY = math.max(0.001, Ysmoothness)

	mousemoverel(dx * smoothX * Strength, dy * smoothY * Strength)
end

-- MAIN LOOP
local function MainLoop()
	cachedViewport = Camera.ViewportSize

	local now = tick()
	local dt = math.clamp(now - lastTime, 0.001, 0.05)
	lastTime = now

	UpdateSettings()

	-- refresh cache every 0.25s (BIG perf)
	if tick() - lastCache > 0.25 then
		RefreshCache()
	end

	if tick() % 5 < 0.05 then
		CleanVelocityCache()
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
	else
		isAiming = Active
	end

	if not isAiming then
		currentTarget = nil
		lockedTarget = nil
		table.clear(targetHitChance)
		return
	end

	UpdateDrift(dt)

	local part = FindTarget(dt)
	currentTarget = part

	if part then
		ApplyMouseMove(PredictPos(part, dt), dt)
	end
end

-- START
task.delay(1, function()
	print("[Aimbot v3 OPTIMIZED] Loaded")

	RunService.Heartbeat:Connect(MainLoop)
end)
