-- Aimbot Handler - v2
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

-- ── Drift ────────────────────────────────────────────────────────────────────
local driftX, driftY = 0, 0
local driftSeedX = math.random() * 100
local driftSeedY = math.random() * 100 + 50

-- ── Settings ─────────────────────────────────────────────────────────────────
local Active = false
local LegitAim = false
local TeamCheck = false
local WallCheck = false
local HitChance = 95
local HeadshotChance = 68
local BodyShotChance = 92
local Xsmoothness = 0.55
local Ysmoothness = 0.55
local Prediction = 0
local Fov = 90
local Strength = 0.85
local ShakeIntensity = 4
local distance = 1000   -- max stud distance to lock onto a target

local sharedAim = shared.Aim or nil
local Toggles = getgenv().Toggles or {}
local Options = getgenv().Options or {}

local function UpdateSettings()
	pcall(function()
		if not sharedAim then return end

		Active = (sharedAim["Active"] and sharedAim["Active"].Value) or false
		LegitAim = (sharedAim["LegitAim"] and sharedAim["LegitAim"].Value) or false
		TeamCheck = (sharedAim["TeamCheck"] and sharedAim["TeamCheck"].Value) or false
		WallCheck = (sharedAim["WallCheck"] and sharedAim["WallCheck"].Value) or false

		HitChance = math.clamp(tonumber(sharedAim["HitChance"] and sharedAim["HitChance"].Value) or 95, 0, 100)
		HeadshotChance = math.clamp(tonumber(sharedAim["HeadshotChance"] and sharedAim["HeadshotChance"].Value) or 68, 0, 100)
		BodyShotChance = math.clamp(tonumber(sharedAim["BodyShotChance"] and sharedAim["BodyShotChance"].Value) or 92, 0, 100)
		Xsmoothness = math.clamp(tonumber(sharedAim["Xsmoothness"] and sharedAim["Xsmoothness"].Value) or 0.55, 0.01, 1)
		Ysmoothness = math.clamp(tonumber(sharedAim["Ysmoothness"] and sharedAim["Ysmoothness"].Value) or 0.55, 0.01, 1)
		Fov = math.clamp(tonumber(sharedAim["Fov"] and sharedAim["Fov"].Value) or 90, 1, 180)
		Strength = math.clamp(tonumber(sharedAim["Strength"] and sharedAim["Strength"].Value) or 85, 0, 100) / 100
		distance = math.clamp(tonumber(sharedAim["distance"] and sharedAim["distance"].Value) or 1000, 1, 10000)
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

local function PredictPos(part)
	if not part then return Vector3.zero end
	if Prediction <= 0 then return part.Position end
	local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
	if vel.Magnitude < 0.5 then return part.Position end
	local dist = (part.Position - Camera.CFrame.Position).Magnitude
	local travelTime = Prediction * (dist / 65) * (vel.Magnitude / 16)
	travelTime = math.clamp(travelTime, 0, 0.22)
	return part.Position + vel * travelTime
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
	if not head then return char:FindFirstChild("HumanoidRootPart") or torso end
	local r = math.random(100)
	if r <= HeadshotChance then return head end
	if r <= HeadshotChance + BodyShotChance then return torso end
	return char:FindFirstChild("HumanoidRootPart") or torso
end

local function FindTarget()
	RefreshCache()

	if lockedTarget and lockedTarget.Parent then
		local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then
			local part = (lockedAimPart and lockedAimPart.Parent == lockedTarget)
				and lockedAimPart
				or ChooseAimPart(lockedTarget)
			if part then
				if not IsInRange(part) then
					lockedTarget = nil
					lockedAimPart = nil
				else
					local pred = PredictPos(part)
					local ok, scr = InFov(pred)
					if ok and IsVisible(part) then
						return part, scr
					end
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
		if not root then continue end

		if not IsInRange(root) then continue end
		if not IsVisible(root) then continue end

		local part = ChooseAimPart(char)
		local pred = PredictPos(part)
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
		driftX = 0
		driftY = 0
		return
	end
	driftSeedX = driftSeedX + dt * 1.8
	driftSeedY = driftSeedY + dt * 2.3
	local amp = 0.013
	driftX = math.sin(driftSeedX * 3.4) * amp + math.sin(driftSeedX * 6.8) * amp * 0.3
	driftY = math.cos(driftSeedY * 2.7) * amp + math.cos(driftSeedY * 5.1) * amp * 0.25
end

local function ApplyMouseMove(targetWorldPos, dt)
	if not targetWorldPos then return end
	local vp = Camera:WorldToViewportPoint(targetWorldPos)
	if vp.Z <= 0 then return end

	local mouse = UserInputService:GetMouseLocation()
	local targetX = vp.X + driftX
	local targetY = vp.Y + driftY
	local dx = targetX - mouse.X
	local dy = targetY - mouse.Y
	local dist = math.sqrt(dx*dx + dy*dy)

	if dist < 2.4 then return end
	if math.random(100) > HitChance then return end

	local frameScale = math.clamp(dt * 60, 0.4, 2.8)
	local rateX = math.clamp((1 - Xsmoothness) * Strength, 0.06, 1.0)
	local rateY = math.clamp((1 - Ysmoothness) * Strength, 0.06, 1.0)
	local alphaX = 1 - (1 - rateX) ^ frameScale
	local alphaY = 1 - (1 - rateY) ^ frameScale

	local maxStep = LegitAim and 28 or 58
	local stepX = math.clamp(dx * alphaX, -maxStep, maxStep)
	local stepY = math.clamp(dy * alphaY, -maxStep, maxStep)
	local mx, my = math.round(stepX), math.round(stepY)

	if mx ~= 0 or my ~= 0 then
		pcall(function() mousemoverel(mx, my) end)
	end
end

local function UpdateFOVCircle()
	print("Updating FOV circle...")
	if not fovCircle then 
		fovCircle = shared.Aim.fovCircle
	end
	if not fovCircle then return end

	local showFov = shared.Aim.ShowFOV and shared.Aim.ShowFOV.Value or false
	local aimbotActive = shared.Aim.AimbotEnabled and shared.Aim.AimbotEnabled.Value or false

	if not showFov or not aimbotActive then
		fovCircle.Visible = false
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)
	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos
	fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
	fovCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)

	local stroke = fovCircle:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Color = isAiming and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(220, 220, 255)
		stroke.Transparency = isAiming and 0.25 or 0.55
	end

	fovCircle.Visible = true
end

local function IsAimKeyDown()
	local keyPicker = Options.AimbotKey
	if keyPicker then
		local key = keyPicker.Value
		if key and key ~= "None" then
			local mouseMap = {
				MB1 = Enum.UserInputType.MouseButton1,
				MB2 = Enum.UserInputType.MouseButton2,
				MB3 = Enum.UserInputType.MouseButton3,
			}
			if mouseMap[key] then
				return UserInputService:IsMouseButtonPressed(mouseMap[key])
			end
			local ut = Enum.UserInputType[key]
			if ut then return UserInputService:IsMouseButtonPressed(ut) end
			local kc = Enum.KeyCode[key]
			if kc then return UserInputService:IsKeyDown(kc) end
		end
	end
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function MainLoop()
	cachedViewport = Camera.ViewportSize
	settingsCounter = (settingsCounter + 1) % 4
	if settingsCounter == 0 then UpdateSettings() end

	local now = tick()
	local dt = math.clamp(now - lastTime, 0.001, 0.06)
	lastTime = now

	isAiming = Active and IsAimKeyDown()

	if not isAiming then
		currentTarget = nil
		lockedTarget = nil
		lockedAimPart = nil
		driftX = 0
		driftY = 0
		return
	end

	UpdateDrift(dt)

	local part, screenPos = FindTarget()
	currentTarget = part

	if part and screenPos then
		ApplyMouseMove(PredictPos(part), dt)
	end
end

task.delay(1, function()
	print("Updating aimbot...")
	fovCircle = shared.Aim.fovCircle
	UpdateSettings()
	RunService.RenderStepped:Connect(UpdateFOVCircle)
	RunService.Heartbeat:Connect(MainLoop)
end)
