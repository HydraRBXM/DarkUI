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
local fovCirclePos = nil
local lastTime = tick()
local fovCircle = nil
local targetpart = nil
local Mode = nil
local AimKey = nil

local toggleState = false
local lastKeyState = false

local driftX, driftY = 0, 0
local driftSeedX = math.random() * 100
local driftSeedY = math.random() * 50 + 50

local Active = false
local LegitAim = false
local TeamCheck = false
local WallCheck = false
local SmarterPredictions = false
local Trackingv2 = false
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
local targetpriority = "Closest"
local Targetpart = "Head"
local sharedAim = shared.Aim or nil

local lastVelocities = {}
local lastPositions = {}
local targetHitChance = {}

-- Trackingv2 state
local tv2_smoothedDelta = Vector2.zero
local tv2_lastScreenPos = nil
local tv2_velocity = Vector2.zero

local function SafeTeamCheck(plr)
	if not TeamCheck or not plr then return false end
	if not Player.Team or not plr.Team then return false end
	return plr.Team == Player.Team
end

local function GetVelocity(part, dt)
	if not part or not part.Parent then return Vector3.zero end
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

local function CleanVelocityCache()
	for part in pairs(lastVelocities) do
		if not part or not part.Parent then
			lastVelocities[part] = nil
			lastPositions[part] = nil
			targetHitChance[part] = nil
		end
	end
	for part in pairs(lastPositions) do
		if not part or not part.Parent then
			lastPositions[part] = nil
		end
	end
end

local function UpdateSettings()
	pcall(function()
		if not sharedAim then return end

		Active          = (sharedAim["Active"] and sharedAim["Active"].Value) or false
		LegitAim        = (sharedAim["LegitAim"] and sharedAim["LegitAim"].Value) or false
		TeamCheck       = (sharedAim["TeamCheck"] and sharedAim["TeamCheck"].Value) or false
		WallCheck       = (sharedAim["WallCheck"] and sharedAim["WallCheck"].Value) or false
		SmarterPredictions = (sharedAim["SmarterPredictions"] and sharedAim["SmarterPredictions"].Value) or false
		Trackingv2      = (sharedAim["Trackingv2"] and sharedAim["Trackingv2"].Value) or false
		Prediction      = math.clamp(tonumber(sharedAim["Prediction"] and sharedAim["Prediction"].Value) or 0, 0, 100)
		HitChance       = math.clamp(tonumber(sharedAim["HitChance"] and sharedAim["HitChance"].Value) or 95, 0, 100)
		HeadshotChance  = math.clamp(tonumber(sharedAim["HeadshotChance"] and sharedAim["HeadshotChance"].Value) or 68, 0, 100)
		BodyShotChance  = math.clamp(tonumber(sharedAim["BodyShotChance"] and sharedAim["BodyShotChance"].Value) or 92, 0, 100)
		Xsmoothness     = math.clamp(tonumber(sharedAim["Xsmoothness"] and sharedAim["Xsmoothness"].Value) or 0.55, 0.01, 0.99)
		Ysmoothness     = math.clamp(tonumber(sharedAim["Ysmoothness"] and sharedAim["Ysmoothness"].Value) or 0.55, 0.01, 0.99)
		Fov             = math.clamp(tonumber(sharedAim["Fov"] and sharedAim["Fov"].Value) or 90, 1, 180)
		Strength        = math.clamp(tonumber(sharedAim["Strength"] and sharedAim["Strength"].Value) or 85, 0, 100) / 100
		distance        = math.clamp(tonumber(sharedAim["distance"] and sharedAim["distance"].Value) or 1000, 1, 10000)
		Mode            = (sharedAim["AimbotMode"] and sharedAim["AimbotMode"].Value) or "Hold"
		AimKey          = (sharedAim["AimbotActivateKey"] and sharedAim["AimbotActivateKey"].Value) or "MB2"
		targetpart      = (sharedAim["AimbotTargetPart"] and sharedAim["AimbotTargetPart"].Value) or "UpperTorso"
		targetpriority  = (sharedAim["AimbotTargetPriority"] and sharedAim["AimbotTargetPriority"].Value) or "Closest"
		Targetpart      = (sharedAim["AimbotTargetPart"] and sharedAim["AimbotTargetPart"].Value) or "Head"
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
	if not part or not part.Parent then return false end
	return (part.Position - Camera.CFrame.Position).Magnitude <= distance
end

local function PredictPos(part, dt)
	if not part or not part.Parent then return Vector3.zero end

	local pos = part.Position
	local vel = part.AssemblyLinearVelocity or Vector3.zero

	if not SmarterPredictions then
		if Prediction <= 0 then return pos end
		return pos + vel * (Prediction * 0.01)
	end

	local realVel = GetVelocity(part, dt)
	local lastVel = lastVelocities[part] or realVel
	local accel = realVel - lastVel
	lastVelocities[part] = realVel

	local dist = (pos - Camera.CFrame.Position).Magnitude
	local travelTime = math.clamp((dist / 300) + (Prediction * 0.01), 0.01, 0.35)

	if realVel.Magnitude < 2 then return pos end

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
	if not char then return nil end

	local preferred = char:FindFirstChild(Targetpart)
	if preferred then return preferred end

	return char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
end

local function ShouldHitTarget(part)
	if not part then return true end
	if targetHitChance[part] == nil then
		targetHitChance[part] = math.random(100) <= HitChance
	end
	return targetHitChance[part]
end

-- Checks if another character is between the camera and the target
local function IsObstructedByPlayer(targetChar)
	if not targetChar then return false end
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end

	local origin = Camera.CFrame.Position
	local dir = targetRoot.Position - origin

	local excludeList = {Player.Character or game:GetService("Workspace")}
	table.insert(excludeList, targetChar)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, dir, params)

	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
		if hitChar and Players:GetPlayerFromCharacter(hitChar) then
			return true
		end
	end

	return false
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
				if ok and IsVisible(part) and not IsObstructedByPlayer(lockedTarget) then
					return part, scr
				end
			end
		end
	end

	lockedTarget = nil
	lockedAimPart = nil

	local screenCenter = cachedViewport * 0.5
	local candidates = {}

	for _, char in cachedCharacters do
		local plr = Players:GetPlayerFromCharacter(char)
		if SafeTeamCheck(plr) then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not IsInRange(root) then continue end
		if not IsVisible(root) then continue end
		if IsObstructedByPlayer(char) then continue end

		local part = ChooseAimPart(char)
		if not part then continue end

		local pred = PredictPos(part, dt)
		local ok, scr = InFov(pred)

		if ok and scr then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			table.insert(candidates, {
				part     = part,
				char     = char,
				screenPos = scr,
				distance = (root.Position - Camera.CFrame.Position).Magnitude,
				health   = hum and hum.Health or 100
			})
		end
	end

	if #candidates == 0 then return nil, nil end

	if targetpriority == "Distance" then
		table.sort(candidates, function(a, b) return a.distance < b.distance end)
	elseif targetpriority == "Health" then
		table.sort(candidates, function(a, b) return a.health < b.health end)
	elseif targetpriority == "Random" then
		local pick = candidates[math.random(#candidates)]
		lockedTarget = pick.char
		lockedAimPart = pick.part
		return pick.part, pick.screenPos
	else
		table.sort(candidates, function(a, b)
			return (a.screenPos - screenCenter).Magnitude < (b.screenPos - screenCenter).Magnitude
		end)
	end

	local best = candidates[1]
	lockedTarget = best.char
	lockedAimPart = best.part
	return best.part, best.screenPos
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

local function IsAimKeyDown()
	if AimKey and AimKey:match("^MB%d") then
		local buttonNum = tonumber(AimKey:match("%d"))
		if buttonNum then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton" .. buttonNum])
		end
	elseif AimKey then
		local keyEnum = Enum.KeyCode[AimKey]
		if keyEnum then
			return UserInputService:IsKeyDown(keyEnum)
		end
	end
	return false
end

-- Trackingv2: advanced tracking with velocity-based prediction and screen-space smoothing
local function ApplyMouseMoveV2(targetWorldPos, dt)
	if not targetWorldPos or not currentTarget then return end

	local vp = Camera:WorldToViewportPoint(targetWorldPos)
	if vp.Z <= 0 then return end
	if not ShouldHitTarget(currentTarget) then return end

	local mouse = UserInputService:GetMouseLocation()
	local targetScreen = Vector2.new(vp.X, vp.Y)

	if tv2_lastScreenPos then
		tv2_velocity = (targetScreen - tv2_lastScreenPos) / math.max(dt, 0.001)
	end
	tv2_lastScreenPos = targetScreen

	local predictedScreen = targetScreen + tv2_velocity * dt * 0.5

	local rawDelta = predictedScreen - mouse
	local smoothFactor = math.clamp(Strength * dt * 60, 0.01, 1)

	tv2_smoothedDelta = tv2_smoothedDelta:Lerp(rawDelta, smoothFactor)

	local finalX = tv2_smoothedDelta.X * (1 - Xsmoothness)
	local finalY = tv2_smoothedDelta.Y * (1 - Ysmoothness)

	-- Clamp to prevent screen wobble
	local maxMove = 80
	finalX = math.clamp(finalX, -maxMove, maxMove)
	finalY = math.clamp(finalY, -maxMove, maxMove)

	pcall(function()
		mousemoverel(finalX + driftX, finalY + driftY)
	end)
end

local function ApplyMouseMove(targetWorldPos, dt)
	if not targetWorldPos or not currentTarget then return end

	local vp = Camera:WorldToViewportPoint(targetWorldPos)
	if vp.Z <= 0 then return end
	if not ShouldHitTarget(currentTarget) then return end

	local mouse = UserInputService:GetMouseLocation()

	-- Fix max smoothing bug: clamp smoothness so 1.0 doesnt cause zero movement
	local sx = math.clamp(1 - Xsmoothness, 0.01, 1) * Strength
	local sy = math.clamp(1 - Ysmoothness, 0.01, 1) * Strength

	local dx = (vp.X + driftX) - mouse.X
	local dy = (vp.Y + driftY) - mouse.Y

	pcall(function()
		mousemoverel(dx * sx, dy * sy)
	end)
end

local function UpdateFOVCircle()
	if not fovCircle then
		fovCircle = shared.Aim and shared.Aim.fovCircle or nil
	end
	if not fovCircle then return end

	local showFov = (shared.Aim and shared.Aim.ShowFOV and shared.Aim.ShowFOV.Value) or false
	local aimbotActive = (shared.Aim and shared.Aim.Active and shared.Aim.Active.Value) or false

	if not showFov or not aimbotActive then
		pcall(function() fovCircle.Visible = false end)
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)

	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos

	pcall(function()
		fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
		fovCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)
		fovCircle.Visible = true
	end)
end

local function MainLoop()
	cachedViewport = Camera.ViewportSize

	local now = tick()
	local dt = math.clamp(now - lastTime, 0.001, 0.06)
	lastTime = now

	UpdateSettings()

	if tick() - lastCache > 5 then
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
	elseif Mode == "Always" then
		isAiming = Active
	end

	if not isAiming then
		currentTarget = nil
		tv2_smoothedDelta = Vector2.zero
		tv2_lastScreenPos = nil
		tv2_velocity = Vector2.zero
		table.clear(targetHitChance)
		return
	end

	UpdateDrift(dt)

	local part = FindTarget(dt)
	currentTarget = part

	if part then
		local predicted = PredictPos(part, dt)
		if Trackingv2 then
			ApplyMouseMoveV2(predicted, dt)
		else
			ApplyMouseMove(predicted, dt)
		end
	end
end

task.delay(1, function()
	print("[Aimbot v2] Loading...")
	fovCircle = shared.Aim and shared.Aim.fovCircle or nil
	RunService.RenderStepped:Connect(UpdateFOVCircle)
	RunService.Heartbeat:Connect(MainLoop)
	print("[Aimbot v2] Ready!")
end)
