-- ═══════════════════════════════════════════
--  NAKED
-- ═══════════════════════════════════════════
local function ApplyNaked()
	local char = GetCharacter()
	if not char then return end
	ClothesSaved = {}
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
			ClothesSaved[obj] = obj.Parent
			obj.Parent = nil
		end
	end
end

local function RevertNaked()
	for obj, parent in pairs(ClothesSaved) do
		if obj and parent then obj.Parent = parent end
	end
	ClothesSaved = {}
end

Toggles.Naked:OnChanged(function(val)
	if val then ApplyNaked() else RevertNaked() end
end)

-- ═══════════════════════════════════════════
--  CHARACTER MATERIALS
-- ═══════════════════════════════════════════
local MaterialMap = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Neon          = Enum.Material.Neon,
	Glass         = Enum.Material.Glass,
	Metal         = Enum.Material.Metal,
	Wood          = Enum.Material.Wood,
	Fabric        = Enum.Material.Fabric,
}

Options.CharacterMaterials:OnChanged(function(val)
	local char = GetCharacter()
	if not char then return end
	local mat = MaterialMap[val]
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
	LoopWSConnection = SafeDisconnect(LoopWSConnection)
end

local function StartLoopWS()
	StopLoopWS()
	if not Toggles.LoopWalkspeed.Value then return end
	LoopWSConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.LoopWalkspeed.Value then StopLoopWS() return end
		local hum = GetHum()
		if hum then hum.WalkSpeed = Options.Walkspeed.Value end
	end)
end

Toggles.LoopWalkspeed:OnChanged(function(val)
	if val then StartLoopWS()
	else StopLoopWS(); local hum = GetHum(); if hum then hum.WalkSpeed = 16 end end
end)

Options.Walkspeed:OnChanged(function(val)
	local hum = GetHum(); if hum then hum.WalkSpeed = val end
end)

-- ═══════════════════════════════════════════
--  LOOP JUMP POWER
-- ═══════════════════════════════════════════
local function StopLoopJP()
	LoopJPConnection = SafeDisconnect(LoopJPConnection)
end

local function StartLoopJP()
	StopLoopJP()
	if not Toggles.LoopJumpPower.Value then return end
	LoopJPConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.LoopJumpPower.Value then StopLoopJP() return end
		local hum = GetHum()
		if hum then
			hum.JumpPower  = Options.JumpPower.Value
			hum.JumpHeight = Options.JumpPower.Value
		end
	end)
end

Toggles.LoopJumpPower:OnChanged(function(val)
	if val then StartLoopJP()
	else StopLoopJP(); local hum = GetHum(); if hum then hum.JumpPower = 50; hum.JumpHeight = 7.2 end end
end)

Options.JumpPower:OnChanged(function(val)
	local hum = GetHum(); if hum then hum.JumpPower = val; hum.JumpHeight = val end
end)

-- ═══════════════════════════════════════════
--  LOOP FOV
-- ═══════════════════════════════════════════
local function StopLoopFov()
	LoopFovConnection = SafeDisconnect(LoopFovConnection)
end

local function StartLoopFov()
	StopLoopFov()
	if not Toggles.LoopFOV.Value then return end
	LoopFovConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.LoopFOV.Value then StopLoopFov() return end
		Camera.FieldOfView = Options.FOV.Value
	end)
end

Toggles.LoopFOV:OnChanged(function(val)
	if val then StartLoopFov() else StopLoopFov(); TweenFOV(70) end
end)

Options.FOV:OnChanged(function(val)
	TweenService:Create(Camera, TweenInfo.new(0.3), {FieldOfView = val}):Play()
end)

-- ═══════════════════════════════════════════
--  NOCLIP
-- ═══════════════════════════════════════════
local function StopNoclip()
	NoclipConnection = SafeDisconnect(NoclipConnection)
	local char = GetCharacter()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

local function StartNoclip()
	StopNoclip()
	if not Toggles.Noclip.Value then return end
	NoclipConnection = RunService.Stepped:Connect(function()
		if not Toggles.Noclip.Value then StopNoclip() return end
		local char = GetCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end)
end

Toggles.Noclip:OnChanged(function(val)
	if val then StartNoclip() else StopNoclip() end
end)

-- ═══════════════════════════════════════════
--  PAUSE [FE]
-- ═══════════════════════════════════════════
local function StopPause()
	PauseConnection = SafeDisconnect(PauseConnection)
	local hrp = GetHRP(); local hum = GetHum()
	if hrp then
		hrp.Anchored = false
		if PauseSavedCFrame then hrp.CFrame = PauseSavedCFrame; PauseSavedCFrame = nil end
	end
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
end

local function StartPause()
	StopPause()
	if not Toggles.PauseFE.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	PauseSavedCFrame = hrp.CFrame
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity  = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	SetHumanoidStates(hum, false)
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	PauseConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.PauseFE.Value then StopPause() return end
		local h = GetHRP()
		if h then
			h.Anchored = true
			h.AssemblyLinearVelocity  = Vector3.zero
			h.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

Toggles.PauseFE:OnChanged(function(val)
	if val then StartPause() else StopPause() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW TOOL
-- ═══════════════════════════════════════════
local function StopRainbowTool()
	RainbowtoolCon = SafeDisconnect(RainbowtoolCon)
	for part, color in pairs(RainbowToolOrigColors) do
		if part and part.Parent then part.Color = color end
	end
	RainbowToolOrigColors = {}
end

local function StartRainbowTool()
	StopRainbowTool()
	if not Toggles.RainbowTool.Value then return end
	RainbowtoolCon = RunService.Heartbeat:Connect(function()
		if not Toggles.RainbowTool.Value then StopRainbowTool() return end
		local char = GetCharacter(); if not char then return end
		local tool = nil
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then tool = child break end
		end
		if not tool then RainbowToolOrigColors = {} return end
		local hue = (tick() * 0.4) % 1
		for _, part in ipairs(tool:GetDescendants()) do
			if part:IsA("BasePart") then
				if not RainbowToolOrigColors[part] then RainbowToolOrigColors[part] = part.Color end
				part.Color = Color3.fromHSV(hue, 0.9, 1)
			end
		end
	end)
end

Toggles.RainbowTool:OnChanged(function(val)
	if val then StartRainbowTool() else StopRainbowTool() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW CHARACTER
-- ═══════════════════════════════════════════
local function StopRainbowChar()
	RainbowcharCon = SafeDisconnect(RainbowcharCon)
	for part, color in pairs(RainbowCharOrigColors) do
		if part and part.Parent then part.Color = color end
	end
	RainbowCharOrigColors = {}
end

local function StartRainbowChar()
	StopRainbowChar()
	if not Toggles.RainbowCharacter.Value then return end
	RainbowcharCon = RunService.Heartbeat:Connect(function()
		if not Toggles.RainbowCharacter.Value then StopRainbowChar() return end
		local char = GetCharacter(); if not char then return end
		local parts = {}
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then parts[#parts+1] = part end
		end
		local total   = math.max(#parts, 1)
		local baseHue = (tick() * 0.35) % 1
		for i, part in ipairs(parts) do
			if not RainbowCharOrigColors[part] then RainbowCharOrigColors[part] = part.Color end
			part.Color = Color3.fromHSV((baseHue + (i/total)*0.5) % 1, 0.95, 1)
		end
	end)
end

Toggles.RainbowCharacter:OnChanged(function(val)
	if val then StartRainbowChar() else StopRainbowChar() end
end)

-- ═══════════════════════════════════════════
--  RTX
-- ═══════════════════════════════════════════
local function RTXSaveLightingProp(prop)
	if RTXLightingSaved[prop] == nil then RTXLightingSaved[prop] = Lighting[prop] end
end

local function RTXAddLightingInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = Lighting
	table.insert(RTXLightingInstances, inst)
end

local function RTXApplyToPart(part)
	if not part:IsA("BasePart") or RTXPartSaved[part] then return end
	RTXPartSaved[part] = {Material=part.Material, Reflectance=part.Reflectance, CastShadow=part.CastShadow}
	part.Reflectance = 0.45; part.CastShadow = true
	if part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
		part.Material = Enum.Material.Glass
	end
end

local function RTXRemoveFromPart(part)
	local saved = RTXPartSaved[part]; if not saved then return end
	for prop, val in pairs(saved) do part[prop] = val end
	RTXPartSaved[part] = nil
end

local function ApplyRTX()
	for _, prop in ipairs({"Ambient","OutdoorAmbient","Brightness","ColorShift_Bottom","ColorShift_Top",
		"FogEnd","FogStart","ShadowSoftness","EnvironmentDiffuseScale","EnvironmentSpecularScale","ExposureCompensation"}) do
		RTXSaveLightingProp(prop)
	end
	Lighting.Ambient=Color3.fromRGB(20,20,30);   Lighting.OutdoorAmbient=Color3.fromRGB(60,70,90)
	Lighting.Brightness=3;                        Lighting.ColorShift_Bottom=Color3.fromRGB(30,40,80)
	Lighting.ColorShift_Top=Color3.fromRGB(255,240,200)
	Lighting.FogEnd=2000;    Lighting.FogStart=800
	Lighting.ShadowSoftness=0.5
	Lighting.EnvironmentDiffuseScale=1;  Lighting.EnvironmentSpecularScale=1
	Lighting.ExposureCompensation=0.4
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") or child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	RTXAddLightingInstance("BloomEffect",           {Intensity=0.6, Size=20, Threshold=0.95})
	RTXAddLightingInstance("BlurEffect",            {Size=4})
	RTXAddLightingInstance("ColorCorrectionEffect", {Brightness=0.03, Contrast=0.15, Saturation=0.20, TintColor=Color3.fromRGB(255,248,235)})
	RTXAddLightingInstance("SunRaysEffect",         {Intensity=0.10, Spread=0.4})
	RTXAddLightingInstance("Atmosphere",            {Density=0.35, Offset=0.06, Color=Color3.fromRGB(199,215,255), Decay=Color3.fromRGB(106,112,125), Glare=0.35, Haze=1.8})
	for _, part in ipairs(workspace:GetDescendants()) do RTXApplyToPart(part) end
	RTXDescendantConn = workspace.DescendantAdded:Connect(function(obj)
		if Toggles.RTX.Value then RTXApplyToPart(obj) end
	end)
end

local function RevertRTX()
	RTXDescendantConn = SafeDisconnect(RTXDescendantConn)
	for _, inst in ipairs(RTXLightingInstances) do if inst and inst.Parent then inst:Destroy() end end
	RTXLightingInstances = {}
	for prop, val in pairs(RTXLightingSaved) do Lighting[prop] = val end
	RTXLightingSaved = {}
	for part in pairs(RTXPartSaved) do RTXRemoveFromPart(part) end
	RTXPartSaved = {}
end

Toggles.RTX:OnChanged(function(val)
	if val then ApplyRTX() else RevertRTX() end
end)

-- ═══════════════════════════════════════════
--  NO ZOOM LIMIT
-- ═══════════════════════════════════════════
Toggles.NoZoomLimit:OnChanged(function(val)
	pcall(function()
		local PlayerModule = require(Player.PlayerScripts:WaitForChild("PlayerModule"))
		local cameraModule = PlayerModule:GetCameras()
		if val then
			cameraModule:SetMinZoomDistance(0)
			cameraModule:SetMaxZoomDistance(500)
		else
			cameraModule:SetMinZoomDistance(0.5)
			cameraModule:SetMaxZoomDistance(400)
		end
	end)
end)

-- ═══════════════════════════════════════════
--  FLY (F to activate)
-- ═══════════════════════════════════════════
local function StopFly()
	Flying = false; flyUp = false; flyDown = false
	FlyConnection = SafeDisconnect(FlyConnection)
	FlyInputBegan = SafeDisconnect(FlyInputBegan)
	FlyInputEnded = SafeDisconnect(FlyInputEnded)
	local hum = GetHum(); local hrp = GetHRP()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	if hrp then
		local bv = hrp:FindFirstChild("FlyBodyVelocity"); if bv then bv:Destroy() end
		local bg = hrp:FindFirstChild("FlyBodyGyro");     if bg then bg:Destroy() end
		local snd = hrp:FindFirstChild("Running");        if snd then snd.Volume = 0.65 end
	end
	TweenFOV(70)
end

local function StartFly()
	StopFly()
	if not Toggles.Fly.Value then return end

	local function GetFlyDir()
		local camCF = Camera.CFrame; local hum = GetHum()
		local md = hum and hum.MoveDirection or Vector3.zero
		local dir = camCF.LookVector * md:Dot(camCF.LookVector)
			+ camCF.RightVector * md:Dot(camCF.RightVector)
			+ Vector3.new(0, (flyUp and 1 or 0) - (flyDown and 1 or 0), 0)
		return dir.Magnitude > 0.001 and dir.Unit or Vector3.zero
	end

	FlyConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.Fly.Value then StopFly() return end
		if not Flying then return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local bg = hrp:FindFirstChild("FlyBodyGyro"); local bv = hrp:FindFirstChild("FlyBodyVelocity")
		if not bg or not bv then return end
		hum:ChangeState(6); bg.CFrame = bg.CFrame:Lerp(Camera.CFrame, 0.2)
		local dir = GetFlyDir()
		TweenService:Create(bv, TweenInfo.new(0.15), {Velocity = dir * Options.FlySpeed.Value}):Play()
		TweenFOV(dir ~= Vector3.zero and 100 or 70)
	end)

	FlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not Toggles.Fly.Value then return end
		if key.KeyCode == Enum.KeyCode.F then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not Flying then
				Flying = true; SetHumanoidStates(hum, false); hum:ChangeState(6)
				local snd = hrp:FindFirstChild("Running"); if snd then snd.Volume = 0 end
				local bg = Instance.new("BodyGyro")
				bg.Name="FlyBodyGyro"; bg.MaxTorque=Vector3.new(4e5,4e5,4e5)
				bg.P=2e4; bg.D=100; bg.CFrame=Camera.CFrame; bg.Parent=hrp
				local bv = Instance.new("BodyVelocity")
				bv.Name="FlyBodyVelocity"; bv.Velocity=Vector3.zero
				bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
			else
				Flying=false; flyUp=false; flyDown=false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				local snd=hrp:FindFirstChild("Running"); if snd then snd.Volume=0.65 end
				local bv=hrp:FindFirstChild("FlyBodyVelocity"); if bv then bv:Destroy() end
				local bg=hrp:FindFirstChild("FlyBodyGyro");     if bg then bg:Destroy() end
				TweenFOV(70)
			end
		elseif key.KeyCode == Enum.KeyCode.Space     then flyUp   = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then flyDown = true
		end
	end)

	FlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space     then flyUp   = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then flyDown = false end
	end)
end

Toggles.Fly:OnChanged(function(val)
	if val then StartFly() else StopFly() end
end)

-- ═══════════════════════════════════════════
--  CFRAME FLY (G to activate)
-- ═══════════════════════════════════════════
local function StopCframeFly()
	CFlying=false; cfUp=false; cfDown=false
	CframeFlyConnection = SafeDisconnect(CframeFlyConnection)
	CframeFlyInputBegan = SafeDisconnect(CframeFlyInputBegan)
	CframeFlyInputEnded = SafeDisconnect(CframeFlyInputEnded)
	local hrp = GetHRP(); if hrp then hrp.Anchored = false end
	SetCharacterCollision(true)
	local hum = GetHum()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	TweenFOV(70)
end

local function StartCframeFly()
	StopCframeFly()
	if not Toggles.CFly.Value then return end

	CframeFlyConnection = RunService.RenderStepped:Connect(function(dt)
		if not Toggles.CFly.Value then StopCframeFly() return end
		if not CFlying then return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		hrp.Anchored = true; SetCharacterCollision(false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:ChangeState(6)
		local camCF = Camera.CFrame; local md = hum.MoveDirection
		hrp.CFrame = hrp.CFrame:Lerp(
			CFrame.new(hrp.Position, hrp.Position + camCF.LookVector),
			math.min(1, CFLY_ROTATE_SPEED * dt)
		)
		local dir = camCF.LookVector*md:Dot(camCF.LookVector)
			+ camCF.RightVector*md:Dot(camCF.RightVector)
			+ Vector3.new(0, (cfUp and 1 or 0)-(cfDown and 1 or 0), 0)
		local moving = dir.Magnitude > 0.001; if moving then dir = dir.Unit end
		hrp.CFrame = CFrame.new(hrp.Position + dir*Options.FlySpeed.Value*dt) * (hrp.CFrame - hrp.Position)
		TweenFOV(moving and 100 or 70)
	end)

	CframeFlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not Toggles.CFly.Value then return end
		if key.KeyCode == Enum.KeyCode.G then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not CFlying then
				CFlying=true; SetHumanoidStates(hum, false); hum:ChangeState(6)
				hrp.Anchored=true; SetCharacterCollision(false)
			else
				CFlying=false; cfUp=false; cfDown=false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				hrp.Anchored=false; SetCharacterCollision(true); TweenFOV(70)
			end
		elseif key.KeyCode == Enum.KeyCode.Space     then cfUp   = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then cfDown = true
		end
	end)

	CframeFlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space     then cfUp   = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then cfDown = false end
	end)
end

Toggles.CFly:OnChanged(function(val)
	if val then StartCframeFly() else StopCframeFly() end
end)

-- ═══════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════
local function StopAntiAFK()
	AntiAFKConnection = SafeDisconnect(AntiAFKConnection)
end

local function StartAntiAFK()
	StopAntiAFK()
	if not Toggles.AntiAFK.Value then return end
	local elapsed = 0
	AntiAFKConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.AntiAFK.Value then StopAntiAFK() return end
		elapsed += dt
		if elapsed >= 900 then
			elapsed = 0
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.zero)
		end
	end)
end

Player.Idled:Connect(function()
	if Toggles.AntiAFK.Value then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end
end)

Toggles.AntiAFK:OnChanged(function(val)
	if val then StartAntiAFK() else StopAntiAFK() end
end)

-- ═══════════════════════════════════════════
--  INFINITE JUMP
-- ═══════════════════════════════════════════
local function StopInfJump()
	InfJumpConn = SafeDisconnect(InfJumpConn)
end

local function StartInfJump()
	StopInfJump()
	if not Toggles.InfiniteJump.Value then return end
	InfJumpConn = UIS.JumpRequest:Connect(function()
		if not Toggles.InfiniteJump.Value then StopInfJump() return end
		local h = GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end

Toggles.InfiniteJump:OnChanged(function(val)
	if val then StartInfJump() else StopInfJump() end
end)

-- ═══════════════════════════════════════════
--  FREEZE
-- ═══════════════════════════════════════════
local function SetFreeze(enabled)
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	hrp.Anchored = enabled
	if enabled then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	else
		hrp.Anchored = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

Toggles.Freeze:OnChanged(function(val) SetFreeze(val) end)

-- ═══════════════════════════════════════════
--  USE VELOCITY
-- ═══════════════════════════════════════════
local function StopUseVelocity()
	UseVelocityConnection = SafeDisconnect(UseVelocityConnection)
end

local function StartUseVelocity()
	StopUseVelocity()
	if not Toggles.Velocity.Value then return end
	UseVelocityConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.Velocity.Value then StopUseVelocity() return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local md = hum.MoveDirection
		if md.Magnitude < 0.01 then return end
		hrp.CFrame = hrp.CFrame + md * Options.VelocitySpeed.Value * dt
	end)
end

Toggles.Velocity:OnChanged(function(val)
	if val then StartUseVelocity() else StopUseVelocity() end
end)

-- ═══════════════════════════════════════════
--  CAR SPIN
-- ═══════════════════════════════════════════
local function StopSpin()
	SpinConnection = SafeDisconnect(SpinConnection)
end

local function StartSpin()
	StopSpin()
	if not Toggles.CarSpin.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local spinSpeed = 0
	SpinConnection = RunService.RenderStepped:Connect(function(dt)
		if not Toggles.CarSpin.Value then StopSpin() return end
		if not hrp.Parent then StopSpin() return end
		spinSpeed += dt * 2
		local rotation = CFrame.Angles(0, math.rad(spinSpeed * Options.CarSpinSpeed.Value), 0)
		local seat = GetSeat()
		if seat then seat.CFrame = seat.CFrame * rotation
		else hrp.CFrame = hrp.CFrame * rotation end
	end)
end

Toggles.CarSpin:OnChanged(function(val)
	if val then StartSpin() else StopSpin() end
end)

-- ═══════════════════════════════════════════
--  BOUNCY CAR
-- ═══════════════════════════════════════════
local function StopBouncy()
	BounceConnection = SafeDisconnect(BounceConnection)
end

local function StartBouncy()
	StopBouncy()
	if not Toggles.BouncyCar.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local bounceTimer = 0; local isGoingUp = true
	local upVelocity = 80; local downVelocity = -100
	BounceConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.BouncyCar.Value then StopBouncy() return end
		if not hrp.Parent then StopBouncy() return end
		bounceTimer += dt
		local targetPart = GetSeat() or hrp
		local vel = targetPart.AssemblyLinearVelocity
		targetPart.AssemblyLinearVelocity = Vector3.new(vel.X, isGoingUp and upVelocity or downVelocity, vel.Z)
		if not GetSeat() then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
		if bounceTimer >= 2 then
			bounceTimer = 0
			if isGoingUp then upVelocity += 20; downVelocity -= 20 end
			isGoingUp = not isGoingUp
		end
	end)
end

Toggles.BouncyCar:OnChanged(function(val)
	if val then StartBouncy() else StopBouncy() end
end)

-- ═══════════════════════════════════════════
--  FLING CAR (seated)
-- ═══════════════════════════════════════════
local function StopFlingCar()
	FlingCarConnection = SafeDisconnect(FlingCarConnection)
end

local function StartFlingCar()
	StopFlingCar()
	if not Toggles.FlingCar.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local seat = GetSeat()
	if not seat then
		Toggles.FlingCar:SetValue(false)
		return
	end
	local spinSpeed, crazyTimer, phase = 0, 0, 1
	local skyPower = 0
	FlingCarConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.FlingCar.Value then StopFlingCar() return end
		if not hum.Sit or not hum.SeatPart then StopFlingCar() return end
		seat = hum.SeatPart
		crazyTimer += dt
		local strength = Options.CarFlingStrength.Value
		if phase == 1 then
			spinSpeed += dt * 20
			seat.AssemblyAngularVelocity = Vector3.new(math.random(-50,50), spinSpeed*30, math.random(-50,50))
			seat.AssemblyLinearVelocity  = Vector3.new(math.random(-200,200)*(strength/50), math.abs(math.sin(crazyTimer*20))*50, math.random(-200,200)*(strength/50))
			if crazyTimer >= 3 then phase=2; crazyTimer=0; skyPower=0 end
		elseif phase == 2 then
			skyPower += dt * 100 * (strength/50)
			seat.AssemblyAngularVelocity = Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100))
			seat.AssemblyLinearVelocity  = Vector3.new(math.sin(crazyTimer*10)*50, skyPower, math.cos(crazyTimer*10)*50)
			if crazyTimer >= 5 then phase=3; crazyTimer=0 end
		elseif phase == 3 then
			seat.AssemblyAngularVelocity = Vector3.new(math.random(-200,200), math.random(-200,200), math.random(-200,200))
			seat.AssemblyLinearVelocity  = Vector3.new(math.sin(crazyTimer*15)*150*(strength/50), -50+math.sin(crazyTimer*20)*30, math.cos(crazyTimer*15)*150*(strength/50))
			if crazyTimer >= 8 then phase=1; crazyTimer=0; spinSpeed=0 end
		end
	end)
end

Toggles.FlingCar:OnChanged(function(val)
	if val then StartFlingCar() else StopFlingCar() end
end)

-- ═══════════════════════════════════════════
--  CAR FLY (F to activate, uses CarFlying)
-- ═══════════════════════════════════════════
local function StopCarFly()
	CarFlying = false
	CarFlyConnection = SafeDisconnect(CarFlyConnection)
	CarFlyInputBegan = SafeDisconnect(CarFlyInputBegan)
	CarFlyInputEnded = SafeDisconnect(CarFlyInputEnded)
	local hrp = GetHRP()
	if hrp then
		local bv = hrp:FindFirstChild("CarFlyBV"); if bv then bv:Destroy() end
		local bg = hrp:FindFirstChild("CarFlyBG"); if bg then bg:Destroy() end
	end
	local hum = GetHum()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	TweenFOV(70)
end

local function StartCarFly()
	StopCarFly()
	if not Toggles.CarFly.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end

	CarFlyConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.CarFly.Value then StopCarFly() return end
		if not CarFlying then return end
		local bv = hrp:FindFirstChild("CarFlyBV")
		local bg = hrp:FindFirstChild("CarFlyBG")
		if not bv or not bg then return end
		local camCF = Camera.CFrame; local md = hum.MoveDirection
		local dir = camCF.LookVector*md:Dot(camCF.LookVector) + camCF.RightVector*md:Dot(camCF.RightVector)
		local moving = dir.Magnitude > 0.001; if moving then dir = dir.Unit end
		bg.CFrame = bg.CFrame:Lerp(camCF, 0.2)
		TweenService:Create(bv, TweenInfo.new(0.15), {Velocity = dir * Options.CarFlySpeed.Value}):Play()
		TweenFOV(moving and 100 or 70)
	end)

	CarFlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not Toggles.CarFly.Value then return end
		if key.KeyCode == Enum.KeyCode.F then
			if not CarFlying then
				CarFlying = true
				SetHumanoidStates(hum, false); hum:ChangeState(6)
				local bv = Instance.new("BodyVelocity")
				bv.Name="CarFlyBV"; bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
				local bg = Instance.new("BodyGyro")
				bg.Name="CarFlyBG"; bg.MaxTorque=Vector3.new(4e5,4e5,4e5); bg.P=2e4; bg.D=100; bg.CFrame=Camera.CFrame; bg.Parent=hrp
			else
				CarFlying = false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				local bv=hrp:FindFirstChild("CarFlyBV"); if bv then bv:Destroy() end
				local bg=hrp:FindFirstChild("CarFlyBG"); if bg then bg:Destroy() end
				TweenFOV(70)
			end
		end
	end)
end

Toggles.CarFly:OnChanged(function(val)
	if val then StartCarFly() else StopCarFly() end
end)

-- ═══════════════════════════════════════════
--  CAR BOOST (hold B)
-- ═══════════════════════════════════════════
local function StopBoost()
	BoostConnection = SafeDisconnect(BoostConnection)
	BoostInputBegan = SafeDisconnect(BoostInputBegan)
	BoostInputEnded = SafeDisconnect(BoostInputEnded)
end

local function StartBoost()
	StopBoost()
	if not Toggles.CarBoost.Value then return end
	local hum = GetHum(); if not hum then return end
	local boosting = false
	BoostInputBegan = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.B then boosting = true end
	end)
	BoostInputEnded = UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.B then boosting = false end
	end)
	BoostConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.CarBoost.Value then StopBoost() return end
		if not boosting then return end
		local seat = GetSeat(); if not seat or not seat.Parent then return end
		local look = seat.CFrame.LookVector; local vel = seat.AssemblyLinearVelocity
		local speed = math.random(250, 1000)
		seat.AssemblyLinearVelocity = Vector3.new(look.X*speed, vel.Y, look.Z*speed)
	end)
end

Toggles.CarBoost:OnChanged(function(val)
	if val then StartBoost() else StopBoost() end
end)

-- ═══════════════════════════════════════════
--  CAR FLINGER (hover + click)
-- ═══════════════════════════════════════════
local function StopHovering()
	HoverConnection    = SafeDisconnect(HoverConnection)
	FlingcarConnection = SafeDisconnect(FlingcarConnection)
	if HoverHighlight then HoverHighlight:Destroy(); HoverHighlight = nil end
	HoveredCar = nil
end

local function StartHovering()
	StopHovering()
	if not Toggles.CarFlinger.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local Mouse = Player:GetMouse()

	local function GetCarFromInstance(instance)
		local obj = instance
		while obj and obj ~= workspace do
			if obj:IsA("Model") then
				for _, v in ipairs(obj:GetDescendants()) do
					if v:IsA("VehicleSeat") then return obj end
				end
			end
			obj = obj.Parent
		end
		return nil
	end

	local function ClearHighlight(car)
		if not car then return end
		for _, v in ipairs(car:GetDescendants()) do
			if v:IsA("SelectionBox") and v.Name == "FlingcarHighlight" then v:Destroy() end
		end
		if HoverHighlight then HoverHighlight:Destroy(); HoverHighlight = nil end
	end

	local function SetHighlight(car)
		if HoveredCar == car then return end
		if HoveredCar then ClearHighlight(HoveredCar) end
		HoveredCar = car
		local box = Instance.new("SelectionBox")
		box.Name="FlingcarHighlight"; box.Adornee=car
		box.Color3=Color3.fromRGB(255,50,50); box.LineThickness=0.05
		box.SurfaceTransparency=0.6; box.SurfaceColor3=Color3.fromRGB(255,80,80)
		box.Parent=car; HoverHighlight=box
	end

	local function FlingTargetCar(car)
		local seat = nil
		for _, v in ipairs(car:GetDescendants()) do
			if v:IsA("VehicleSeat") then seat=v break end
		end
		if not seat then return end
		local savedCF = hrp.CFrame; local offsetX = math.random(-1,1); local elapsed = 0
		local char = GetCharacter()
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not Toggles.CarFlinger.Value or elapsed >= 1.5 then
				conn:Disconnect()
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = true end
				end
				hrp.CFrame = savedCF
				return
			end
			elapsed += dt
			seat.AssemblyAngularVelocity = Vector3.new(math.random(-300,300), math.random(-300,300), math.random(-300,300))
			seat.AssemblyLinearVelocity  = Vector3.new(math.random(-200,200), math.random(100,300), math.random(-200,200))
			hrp.CFrame = seat.CFrame * CFrame.new(offsetX, 1.5, -4)
		end)
		hrp.CFrame = seat.CFrame * CFrame.new(offsetX, 1.5, -4)
	end

	HoverConnection = RunService.RenderStepped:Connect(function()
		if not Toggles.CarFlinger.Value then StopHovering() return end
		local target = Mouse.Target
		if target then
			local car = GetCarFromInstance(target)
			if car then SetHighlight(car) return end
		end
		if HoveredCar then ClearHighlight(HoveredCar); HoveredCar = nil end
	end)

	FlingcarConnection = Mouse.Button1Down:Connect(function()
		if not Toggles.CarFlinger.Value or not HoveredCar then return end
		local car = HoveredCar
		ClearHighlight(car); HoveredCar = nil
		FlingTargetCar(car)
	end)
end

Toggles.CarFlinger:OnChanged(function(val)
	if val then StartHovering() else StopHovering() end
end)

-- ═══════════════════════════════════════════
--  GET CAR
-- ═══════════════════════════════════════════
local GetCarButton = CarBox:AddButton({ Text = 'Get Car', Func = function()
	local hrp = GetHRP(); if not hrp then return end
	local closest, closestDist = nil, math.huge
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("VehicleSeat") then
			local dist = (v.Position - hrp.Position).Magnitude
			if dist < closestDist then closestDist=dist; closest=v end
		end
	end
	if not closest then return end
	hrp.CFrame = CFrame.new(closest.Position + Vector3.new(0, 5, 0))
	task.wait(0.1)
	local hum = GetHum(); if hum then hum:ChangeState(Enum.HumanoidStateType.Landed) end
end })

-- ═══════════════════════════════════════════
--  DESPAWN CAR
-- ═══════════════════════════════════════════
local DespawnCarButton = CarBox:AddButton({ Text = 'Despawn Car', Func = function()
	local hum = GetHum(); if not hum then return end
	local seat = GetSeat(); if not seat then return end
	local car = seat:FindFirstAncestorOfClass("Model"); if car then car:Destroy() end
end })

-- ═══════════════════════════════════════════
--  GET ALL CARS
-- ═══════════════════════════════════════════
local GetAllCarsButton = CarBox:AddButton({ Text = 'Get All Cars', Func = function()
	local hrp = GetHRP(); if not hrp then return end
	local cars = {}
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("VehicleSeat") then
			local model = v:FindFirstAncestorOfClass("Model")
			if model and not table.find(cars, model) then table.insert(cars, model) end
		end
	end
	for i, car in ipairs(cars) do
		task.delay(i * 0.1, function()
			car:PivotTo(hrp.CFrame * CFrame.new(0, 0, -(i * 8)))
		end)
	end
end })

-- ═══════════════════════════════════════════
--  CHARACTER RESPAWN
-- ═══════════════════════════════════════════
local function OnCharacterAdded(newChar)
	WaitUntil(function() return newChar:FindFirstChildOfClass("Humanoid") end)
	WaitUntil(function() return newChar:FindFirstChild("HumanoidRootPart") end)
	task.wait(0.15)

	local hum = GetHum()
	if hum then
		hum.WalkSpeed = Options.Walkspeed.Value
		hum.JumpPower = Options.JumpPower.Value
	end

	if Toggles.LoopWalkspeed.Value    then StartLoopWS()       end
	if Toggles.LoopJumpPower.Value    then StartLoopJP()       end
	if Toggles.LoopFOV.Value          then StartLoopFov()      end
	if Toggles.Noclip.Value           then StartNoclip()       end
	if Toggles.AntiAFK.Value          then StartAntiAFK()      end
	if Toggles.InfiniteJump.Value     then StartInfJump()      end
	if Toggles.Velocity.Value         then StartUseVelocity()  end
	if Toggles.PauseFE.Value          then StartPause()        end
	if Toggles.RainbowTool.Value      then StartRainbowTool()  end
	if Toggles.RainbowCharacter.Value then StartRainbowChar()  end
	if Toggles.Naked.Value            then task.delay(0.5, ApplyNaked) end
	if Toggles.Fly.Value  then Flying=false;  flyUp=false;  flyDown=false;  StartFly()        end
	if Toggles.CFly.Value then CFlying=false; cfUp=false;   cfDown=false;   StartCframeFly()  end

	-- car handlers
	CarFlying = false
	if Toggles.CarSpin.Value    then StartSpin()       end
	if Toggles.CarFly.Value     then StartCarFly()     end
	if Toggles.BouncyCar.Value  then StartBouncy()     end
	if Toggles.CarBoost.Value   then StartBoost()      end
	if Toggles.CarFlinger.Value then StartHovering()   end
end

Player.CharacterAdded:Connect(function(char)
	task.spawn(OnCharacterAdded, char)
end)

task.spawn(function()
	local char = WaitUntil(function() return Player.Character end)
	task.spawn(OnCharacterAdded, char)
end)

-- persistent on load
if Toggles.AntiAFK.Value then StartAntiAFK() end
if Toggles.LoopFOV.Value then StartLoopFov() end
if Toggles.RTX.Value     then ApplyRTX()     end
