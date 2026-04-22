-- Client Handler - v3 (Optimized)
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local C = shared.Client -- shorthand alias

local function GetCharacter() return Player.Character end
local function GetHRP()
	local c = GetCharacter()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
	local c = GetCharacter()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local CFLY_ROTATE_SPEED = 12

-- ═══════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════
local function SafeDisconnect(conn)
	if conn then conn:Disconnect() end
	return nil
end

local function WaitUntil(fn, interval)
	interval = interval or 0.5
	while true do
		local result = fn()
		if result then return result end
		task.wait(interval)
	end
end

local function SetHumanoidStates(hum, enabled)
	if not hum then return end
	for _, state in ipairs({
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Freefall,
	}) do
		hum:SetStateEnabled(state, enabled)
	end
end

local function SetCharacterCollision(enabled)
	local char = GetCharacter()
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = enabled end
	end
end

local function TweenFOV(target)
	TweenService:Create(Camera, TweenInfo.new(0.5), { FieldOfView = target }):Play()
end

-- ═══════════════════════════════════════════
--  NAKED
-- ═══════════════════════════════════════════
local function ApplyNaked()
	local char = GetCharacter()
	if not char then return end
	C.ClothesSaved = {}
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
			C.ClothesSaved[obj] = obj.Parent
			obj.Parent = nil
		end
	end
end

local function RevertNaked()
	for obj, parent in pairs(C.ClothesSaved or {}) do
		if obj and parent then obj.Parent = parent end
	end
	C.ClothesSaved = {}
end

C.Naked:OnChanged(function()
	if C.Naked.Value then ApplyNaked() else RevertNaked() end
end)

-- ═══════════════════════════════════════════
--  CHARACTER MATERIALS
-- ═══════════════════════════════════════════
local MaterialMap = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Metal = Enum.Material.Metal,
	Wood = Enum.Material.Wood,
	Fabric = Enum.Material.Fabric,
}

C.CharacterMaterials:OnChanged(function()
	local char = GetCharacter()
	if not char then return end
	local mat = MaterialMap[C.CharacterMaterials.Value]
	if not mat then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.Material = mat end)
		end
	end
end)

-- ═══════════════════════════════════════════
--  LOOP WALKSPEED
-- ═══════════════════════════════════════════
local function StopLoopWS()
	C.LoopWSConnection = SafeDisconnect(C.LoopWSConnection)
end

local function StartLoopWS()
	StopLoopWS()
	if not C.LoopWalkspeed.Value then return end
	C.LoopWSConnection = RunService.Heartbeat:Connect(function()
		if not C.LoopWalkspeed.Value then StopLoopWS() return end
		local hum = GetHum()
		if hum then hum.WalkSpeed = C.Walkspeed.Value end
	end)
end

C.LoopWalkspeed:OnChanged(function()
	if C.LoopWalkspeed.Value then
		StartLoopWS()
	else
		StopLoopWS()
		local hum = GetHum()
		if hum then hum.WalkSpeed = 16 end
	end
end)

C.Walkspeed:OnChanged(function()
	local hum = GetHum()
	if hum then hum.WalkSpeed = C.Walkspeed.Value end
end)

-- ═══════════════════════════════════════════
--  LOOP JUMP POWER
-- ═══════════════════════════════════════════
local function StopLoopJP()
	C.LoopJPConnection = SafeDisconnect(C.LoopJPConnection) -- fixed: was writing to bare LoopJPConnection
end

local function StartLoopJP()
	StopLoopJP()
	if not C.LoopJumpPower.Value then return end
	C.LoopJPConnection = RunService.Heartbeat:Connect(function()
		if not C.LoopJumpPower.Value then StopLoopJP() return end
		local hum = GetHum()
		if hum then
			hum.JumpPower = C.JumpPower.Value
			hum.JumpHeight = C.JumpPower.Value
		end
	end)
end

C.LoopJumpPower:OnChanged(function()
	if C.LoopJumpPower.Value then
		StartLoopJP()
	else
		StopLoopJP()
		local hum = GetHum()
		if hum then hum.JumpPower = 50; hum.JumpHeight = 7.2 end
	end
end)

C.JumpPower:OnChanged(function()
	local hum = GetHum()
	if hum then
		hum.JumpPower = C.JumpPower.Value
		hum.JumpHeight = C.JumpPower.Value
	end
end)

-- ═══════════════════════════════════════════
--  LOOP FOV
-- ═══════════════════════════════════════════
local function StopLoopFov()
	C.LoopFovConnection = SafeDisconnect(C.LoopFovConnection)
end

local function StartLoopFov()
	StopLoopFov()
	if not C.LoopFOV.Value then return end
	C.LoopFovConnection = RunService.Heartbeat:Connect(function()
		if not C.LoopFOV.Value then StopLoopFov() return end
		Camera.FieldOfView = C.Fov.Value
	end)
end

C.LoopFOV:OnChanged(function()
	if C.LoopFOV.Value then StartLoopFov() else StopLoopFov(); TweenFOV(70) end
end)

C.Fov:OnChanged(function()
	TweenService:Create(Camera, TweenInfo.new(0.3), { FieldOfView = C.Fov.Value }):Play()
end)

-- ═══════════════════════════════════════════
--  NOCLIP
-- ═══════════════════════════════════════════
local function StopNoclip()
	C.NoclipConnection = SafeDisconnect(C.NoclipConnection)
	local char = GetCharacter()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

local function StartNoclip()
	StopNoclip()
	if not C.Noclip.Value then return end
	C.NoclipConnection = RunService.Stepped:Connect(function()
		if not C.Noclip.Value then StopNoclip() return end
		local char = GetCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end)
end

C.Noclip:OnChanged(function()
	if C.Noclip.Value then StartNoclip() else StopNoclip() end
end)

-- ═══════════════════════════════════════════
--  PAUSE [FE]
-- ═══════════════════════════════════════════
local PauseSavedCFrame

local function StopPause()
	C.PauseConnection = SafeDisconnect(C.PauseConnection)
	local hrp = GetHRP(); local hum = GetHum()
	if hrp then
		hrp.Anchored = false
		if PauseSavedCFrame then hrp.CFrame = PauseSavedCFrame; PauseSavedCFrame = nil end
	end
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
end

local function StartPause()
	StopPause()
	if not C.PauseFE.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	PauseSavedCFrame = hrp.CFrame
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	SetHumanoidStates(hum, false)
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	C.PauseConnection = RunService.Heartbeat:Connect(function()
		if not C.PauseFE.Value then StopPause() return end
		local h = GetHRP()
		if h then
			h.Anchored = true
			h.AssemblyLinearVelocity = Vector3.zero
			h.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

C.PauseFE:OnChanged(function()
	if C.PauseFE.Value then StartPause() else StopPause() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW TOOL  (ViewModel-based — workspace.ViewModels)
--  Colorizes every BasePart/MeshPart/SpecialMesh inside all
--  models found under workspace.ViewModels.
-- ═══════════════════════════════════════════
local function StopRainbowTool()
	C.RainbowtoolCon = SafeDisconnect(C.RainbowtoolCon)
	for part, color in pairs(C.RainbowToolOrigColors or {}) do
		if part and part.Parent then part.Color = color end
	end
	C.RainbowToolOrigColors = {}
end

local function StartRainbowTool()
	StopRainbowTool()
	if not C.RainbowTool.Value then return end

	local ViewModels = workspace:FindFirstChild("ViewModels")
	if not ViewModels then
		warn("[RainbowTool] workspace.ViewModels not found")
		return
	end

	C.RainbowtoolCon = RunService.Heartbeat:Connect(function()
		if not C.RainbowTool.Value then StopRainbowTool() return end

		local hue = (tick() * 0.4) % 1
		local color = Color3.fromHSV(hue, 0.9, 1)

		for _, model in ipairs(ViewModels:GetChildren()) do
			if not model:IsA("Model") then continue end
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					-- save original color once
					if not C.RainbowToolOrigColors[part] then
						C.RainbowToolOrigColors[part] = part.Color
					end
					part.Color = color
				end
			end
		end
	end)
end

C.RainbowTool:OnChanged(function()
	if C.RainbowTool.Value then StartRainbowTool() else StopRainbowTool() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW CHARACTER
--  Fixed: was referencing bare cfUp/cfDown globals; now uses per-part spread hue
-- ═══════════════════════════════════════════
local function StopRainbowChar()
	C.RainbowcharCon = SafeDisconnect(C.RainbowcharCon)
	for part, color in pairs(C.RainbowCharOrigColors or {}) do
		if part and part.Parent then part.Color = color end
	end
	C.RainbowCharOrigColors = {}
end

local function StartRainbowChar()
	StopRainbowChar()
	if not C.RainbowCharacter.Value then return end

	C.RainbowcharCon = RunService.Heartbeat:Connect(function()
		if not C.RainbowCharacter.Value then StopRainbowChar() return end
		local char = GetCharacter()
		if not char then return end

		-- collect BaseParts once per frame
		local parts = {}
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				parts[#parts + 1] = part
			end
		end

		local total = math.max(#parts, 1)
		local baseHue = (tick() * 0.35) % 1

		for i, part in ipairs(parts) do
			if not C.RainbowCharOrigColors[part] then
				C.RainbowCharOrigColors[part] = part.Color
			end
			-- spread hue evenly across the whole character
			part.Color = Color3.fromHSV((baseHue + (i - 1) / total) % 1, 0.95, 1)
		end
	end)
end

C.RainbowCharacter:OnChanged(function()
	if C.RainbowCharacter.Value then StartRainbowChar() else StopRainbowChar() end
end)

-- ═══════════════════════════════════════════
--  RTX
-- ═══════════════════════════════════════════
local RTXDescendantConn
local RTXLightingInstances = {}  -- local, mirrored into C below when needed

local function RTXSaveLightingProp(prop)
	if C.RTXLightingSaved[prop] == nil then
		C.RTXLightingSaved[prop] = Lighting[prop]
	end
end

local function RTXAddLightingInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = Lighting
	table.insert(RTXLightingInstances, inst)
end

local function RTXApplyToPart(part)
	if not part:IsA("BasePart") or C.RTXPartSaved[part] then return end
	C.RTXPartSaved[part] = { Material = part.Material, Reflectance = part.Reflectance, CastShadow = part.CastShadow }
	part.Reflectance = 0.45
	part.CastShadow = true
	if part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
		part.Material = Enum.Material.Glass
	end
end

local function RTXRemoveFromPart(part)
	local saved = C.RTXPartSaved[part]
	if not saved then return end
	for prop, val in pairs(saved) do part[prop] = val end
	C.RTXPartSaved[part] = nil
end

local function ApplyRTX()
	for _, prop in ipairs({
		"Brightness", "ColorShift_Bottom", "ColorShift_Top",
		"FogEnd", "FogStart", "ShadowSoftness", "EnvironmentDiffuseScale",
		"EnvironmentSpecularScale", "ExposureCompensation"
	}) do
		RTXSaveLightingProp(prop)
	end

	Lighting.Brightness = 3
	Lighting.ColorShift_Bottom = Color3.fromRGB(30, 40, 80)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 200)
	Lighting.FogEnd = 2000
	Lighting.FogStart = 800
	Lighting.ShadowSoftness = 0.5
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.4

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") or child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	RTXAddLightingInstance("BloomEffect", { Intensity = 0.6, Size = 20, Threshold = 0.95 })
	RTXAddLightingInstance("BlurEffect", { Size = 4 })
	RTXAddLightingInstance("ColorCorrectionEffect", { Brightness = 0.03, Contrast = 0.15, Saturation = 0.20, TintColor = Color3.fromRGB(255, 248, 235) })
	RTXAddLightingInstance("SunRaysEffect", { Intensity = 0.10, Spread = 0.4 })
	RTXAddLightingInstance("Atmosphere", { Density = 0.35, Offset = 0.06, Color = Color3.fromRGB(199, 215, 255), Decay = Color3.fromRGB(106, 112, 125), Glare = 0.35, Haze = 1.8 })

	for _, part in ipairs(workspace:GetDescendants()) do RTXApplyToPart(part) end
	RTXDescendantConn = workspace.DescendantAdded:Connect(function(obj)
		if C.RTX.Value then RTXApplyToPart(obj) end
	end)
end

local function RevertRTX()
	RTXDescendantConn = SafeDisconnect(RTXDescendantConn)
	for _, inst in ipairs(RTXLightingInstances) do
		if inst and inst.Parent then inst:Destroy() end
	end
	RTXLightingInstances = {}
	for prop, val in pairs(C.RTXLightingSaved) do Lighting[prop] = val end
	C.RTXLightingSaved = {}
	for part in pairs(C.RTXPartSaved) do RTXRemoveFromPart(part) end
	C.RTXPartSaved = {}
end

C.RTX:OnChanged(function()
	if C.RTX.Value then ApplyRTX() else RevertRTX() end
end)

-- ═══════════════════════════════════════════
--  NO ZOOM LIMIT
-- ═══════════════════════════════════════════
C.NoZoomLimit:OnChanged(function()
	pcall(function()
		local PlayerModule = require(Player.PlayerScripts:WaitForChild("PlayerModule"))
		local cameraModule = PlayerModule:GetCameras()
		if C.NoZoomLimit.Value then
			cameraModule:SetMinZoomDistance(0)
			cameraModule:SetMaxZoomDistance(500)
		else
			cameraModule:SetMinZoomDistance(0.5)
			cameraModule:SetMaxZoomDistance(400)
		end
	end)
end)

-- ═══════════════════════════════════════════
--  FLY  (F to toggle)
-- ═══════════════════════════════════════════
local flyUp, flyDown = false, false

local function StopFly()
	C.Flying = false; flyUp = false; flyDown = false
	C.FlyConnection = SafeDisconnect(C.FlyConnection)
	C.FlyInputBegan = SafeDisconnect(C.FlyInputBegan)
	C.FlyInputEnded = SafeDisconnect(C.FlyInputEnded)
	local hum = GetHum(); local hrp = GetHRP()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	if hrp then
		local bv = hrp:FindFirstChild("FlyBodyVelocity"); if bv then bv:Destroy() end
		local bg = hrp:FindFirstChild("FlyBodyGyro"); if bg then bg:Destroy() end
		local snd = hrp:FindFirstChild("Running"); if snd then snd.Volume = 0.65 end
	end
end

local function StartFly()
	StopFly()
	if not C.Fly.Value then return end

	local function GetFlyDir()
		local camCF = Camera.CFrame
		local hum = GetHum()
		local md = hum and hum.MoveDirection or Vector3.zero
		local dir = camCF.LookVector * md:Dot(camCF.LookVector)
			+ camCF.RightVector * md:Dot(camCF.RightVector)
			+ Vector3.new(0, (flyUp and 1 or 0) - (flyDown and 1 or 0), 0)
		return dir.Magnitude > 0.001 and dir.Unit or Vector3.zero
	end

	C.FlyConnection = RunService.Heartbeat:Connect(function()
		if not C.Fly.Value then StopFly() return end
		if not C.Flying then return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local bg = hrp:FindFirstChild("FlyBodyGyro")
		local bv = hrp:FindFirstChild("FlyBodyVelocity")
		if not bg or not bv then return end
		hum:ChangeState(6)
		bg.CFrame = bg.CFrame:Lerp(Camera.CFrame, 0.2)
		TweenService:Create(bv, TweenInfo.new(0.15), { Velocity = GetFlyDir() * C.FlySpeed.Value }):Play()
	end)

	C.FlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not C.Fly.Value then return end
		if key.KeyCode == Enum.KeyCode.F then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not C.Flying then
				C.Flying = true
				SetHumanoidStates(hum, false); hum:ChangeState(6)
				local snd = hrp:FindFirstChild("Running"); if snd then snd.Volume = 0 end
				local bg = Instance.new("BodyGyro")
				bg.Name = "FlyBodyGyro"; bg.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
				bg.P = 2e4; bg.D = 100; bg.CFrame = Camera.CFrame; bg.Parent = hrp
				local bv = Instance.new("BodyVelocity")
				bv.Name = "FlyBodyVelocity"; bv.Velocity = Vector3.zero
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5); bv.Parent = hrp
			else
				C.Flying = false; flyUp = false; flyDown = false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				local snd = hrp:FindFirstChild("Running"); if snd then snd.Volume = 0.65 end
				local bv = hrp:FindFirstChild("FlyBodyVelocity"); if bv then bv:Destroy() end
				local bg = hrp:FindFirstChild("FlyBodyGyro"); if bg then bg:Destroy() end
			end
		elseif key.KeyCode == Enum.KeyCode.Space then flyUp = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then flyDown = true
		end
	end)

	C.FlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space then flyUp = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then flyDown = false end
	end)
end

C.Fly:OnChanged(function()
	if C.Fly.Value then StartFly() else StopFly() end
end)

-- ═══════════════════════════════════════════
--  CFRAME FLY  (G to toggle)
-- ═══════════════════════════════════════════
local cfUp, cfDown = false, false  -- fixed: were bare globals referenced inconsistently

local function StopCframeFly()
	C.CFlying = false; cfUp = false; cfDown = false
	C.CframeFlyConnection = SafeDisconnect(C.CframeFlyConnection)
	C.CframeFlyInputBegan = SafeDisconnect(C.CframeFlyInputBegan)
	C.CframeFlyInputEnded = SafeDisconnect(C.CframeFlyInputEnded)
	local hrp = GetHRP(); if hrp then hrp.Anchored = false end
	SetCharacterCollision(true)
	local hum = GetHum()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
end

local function StartCframeFly()
	StopCframeFly()
	if not C.CFly.Value then return end

	C.CframeFlyConnection = RunService.RenderStepped:Connect(function(dt)
		if not C.CFly.Value then StopCframeFly() return end
		if not C.CFlying then return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		hrp.Anchored = true
		SetCharacterCollision(false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:ChangeState(6)
		local camCF = Camera.CFrame
		local md = hum.MoveDirection
		hrp.CFrame = hrp.CFrame:Lerp(
			CFrame.new(hrp.Position, hrp.Position + camCF.LookVector),
			math.min(1, CFLY_ROTATE_SPEED * dt)
		)
		local dir = camCF.LookVector * md:Dot(camCF.LookVector)
			+ camCF.RightVector * md:Dot(camCF.RightVector)
			+ Vector3.new(0, (cfUp and 1 or 0) - (cfDown and 1 or 0), 0)
		if dir.Magnitude > 0.001 then dir = dir.Unit end
		hrp.CFrame = CFrame.new(hrp.Position + dir * C.FlySpeed.Value * dt) * (hrp.CFrame - hrp.Position)
	end)

	C.CframeFlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not C.CFly.Value then return end
		if key.KeyCode == Enum.KeyCode.G then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not C.CFlying then
				C.CFlying = true
				SetHumanoidStates(hum, false); hum:ChangeState(6)
				hrp.Anchored = true; SetCharacterCollision(false)
			else
				C.CFlying = false; cfUp = false; cfDown = false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				hrp.Anchored = false; SetCharacterCollision(true); TweenFOV(70)
			end
		elseif key.KeyCode == Enum.KeyCode.Space then cfUp = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then cfDown = true
		end
	end)

	C.CframeFlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space then cfUp = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then cfDown = false end
	end)
end

C.CFly:OnChanged(function()
	if C.CFly.Value then StartCframeFly() else StopCframeFly() end
end)

-- ═══════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════
local function StopAntiAFK()
	C.AntiAFKConnection = SafeDisconnect(C.AntiAFKConnection)
end

local function StartAntiAFK()
	StopAntiAFK()
	if not C.AntiAFK.Value then return end
	local elapsed = 0
	C.AntiAFKConnection = RunService.Heartbeat:Connect(function(dt)
		if not C.AntiAFK.Value then StopAntiAFK() return end
		elapsed += dt
		if elapsed >= 900 then
			elapsed = 0
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.zero)
		end
	end)
end

Player.Idled:Connect(function()
	if C.AntiAFK.Value then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end
end)

C.AntiAFK:OnChanged(function()
	if C.AntiAFK.Value then StartAntiAFK() else StopAntiAFK() end
end)

-- ═══════════════════════════════════════════
--  INFINITE JUMP
-- ═══════════════════════════════════════════
local function StopInfJump()
	C.InfJumpConn = SafeDisconnect(C.InfJumpConn)
end

local function StartInfJump()
	StopInfJump()
	if not C.InfiniteJump.Value then return end
	C.InfJumpConn = UIS.JumpRequest:Connect(function()
		if not C.InfiniteJump.Value then StopInfJump() return end
		local h = GetHum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end

C.InfiniteJump:OnChanged(function()
	if C.InfiniteJump.Value then StartInfJump() else StopInfJump() end
end)

-- ═══════════════════════════════════════════
--  FREEZE
-- ═══════════════════════════════════════════
local function SetFreeze(enabled)
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	if enabled then
		hrp.Anchored = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	else
		hrp.Anchored = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

C.Freeze:OnChanged(function() SetFreeze(C.Freeze.Value) end)

-- ═══════════════════════════════════════════
--  USE VELOCITY
-- ═══════════════════════════════════════════
local function StopUseVelocity()
	C.UseVelocityConnection = SafeDisconnect(C.UseVelocityConnection)
end

local function StartUseVelocity()
	StopUseVelocity()
	if not C.Velocity.Value then return end
	C.UseVelocityConnection = RunService.Heartbeat:Connect(function(dt)
		if not C.Velocity.Value then StopUseVelocity() return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local md = hum.MoveDirection
		if md.Magnitude < 0.01 then return end
		hrp.CFrame = hrp.CFrame + md * C.VelocitySpeed.Value * dt
	end)
end

C.Velocity:OnChanged(function()
	if C.Velocity.Value then StartUseVelocity() else StopUseVelocity() end
end)

-- ═══════════════════════════════════════════
--  CHARACTER RESPAWN — re-enable features on respawn
-- ═══════════════════════════════════════════
local function OnCharacterAdded(newChar)
	WaitUntil(function() return newChar:FindFirstChildOfClass("Humanoid") end)
	WaitUntil(function() return newChar:FindFirstChild("HumanoidRootPart") end)
	task.wait(0.15)

	local hum = GetHum()
	if hum then
		hum.WalkSpeed = C.Walkspeed.Value
		hum.JumpPower = C.JumpPower.Value
	end

	if C.LoopWalkspeed.Value then StartLoopWS() end
	if C.LoopJumpPower.Value then StartLoopJP() end
	if C.LoopFOV.Value then StartLoopFov() end
	if C.Noclip.Value then StartNoclip() end
	if C.AntiAFK.Value then StartAntiAFK() end
	if C.InfiniteJump.Value then StartInfJump() end
	if C.Velocity.Value then StartUseVelocity() end
	if C.PauseFE.Value then StartPause() end
	if C.RainbowTool.Value then StartRainbowTool() end
	if C.RainbowCharacter.Value then StartRainbowChar() end
	if C.Naked.Value then task.delay(0.5, ApplyNaked) end
	if C.Fly.Value then C.Flying = false; flyUp = false; flyDown = false; StartFly() end
	if C.CFly.Value then C.CFlying = false; cfUp = false; cfDown = false; StartCframeFly() end
end

Player.CharacterAdded:Connect(function(char)
	task.spawn(OnCharacterAdded, char)
end)

task.spawn(function()
	local char = WaitUntil(function() return Player.Character end)
	task.spawn(OnCharacterAdded, char)
end)

if C.AntiAFK.Value then StartAntiAFK() end
if C.LoopFOV.Value then StartLoopFov() end
if C.RTX.Value then ApplyRTX() end
