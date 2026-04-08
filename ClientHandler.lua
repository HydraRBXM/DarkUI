-- Client Handler - v2
print("[Comet]: Starting client")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local function GetCharacter() return Player.Character end
local function GetHRP()
	local c = GetCharacter()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
	local c = GetCharacter()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetSeat()
	local hum = GetHum()
	return hum and hum.Sit and hum.SeatPart or nil
end

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

-- ═══════════════════════════════════════════
--  NAKED
-- ═══════════════════════════════════════════
local function ApplyNaked()
	local char = GetCharacter()
	if not char then return end
	shared.Client.ClothesSaved = {}
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
			shared.Client.ClothesSaved[obj] = obj.Parent
			obj.Parent = nil
		end
	end
end

local function RevertNaked()
	for obj, parent in pairs(shared.Client.ClothesSaved) do
		if obj and parent then obj.Parent = parent end
	end
	shared.Client.ClothesSaved = {}
end

shared.Client.Naked:OnChanged(function(val)
	if val then ApplyNaked() else RevertNaked() end
end)

local Player = game.Players:WaitForChild(LocalPlayer, 2)

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

shared.Client.CharacterMaterials:OnChanged(function(val)
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
	shared.Client.LoopWSConnection = SafeDisconnect(shared.Client.LoopWSConnection)
end

local function StartLoopWS()
	StopLoopWS()
	if not shared.Client.LoopWalkspeed.Value then return end
	shared.Client.LoopWSConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.LoopWalkspeed.Value then StopLoopWS() return end
		local hum = GetHum()
		if hum then hum.WalkSpeed = shared.Client.Walkspeed.Value end
	end)
end

shared.Client.LoopWalkspeed:OnChanged(function(val)
	if val then StartLoopWS()
	else StopLoopWS(); local hum = GetHum(); if hum then hum.WalkSpeed = 16 end end
end)

shared.Client.Walkspeed:OnChanged(function(val)
	local hum = GetHum(); if hum then hum.WalkSpeed = val end
end)

-- ═══════════════════════════════════════════
--  LOOP JUMP POWER
-- ═══════════════════════════════════════════
local function StopLoopJP()
	LoopJPConnection = SafeDisconnect(shared.Client.LoopJPConnection)
end

local function StartLoopJP()
	StopLoopJP()
	if not shared.Client.LoopJumpPower.Value then return end
	LoopJPConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.LoopJumpPower.Value then StopLoopJP() return end
		local hum = GetHum()
		if hum then
			hum.JumpPower  = shared.Client.JumpPower.Value
			hum.JumpHeight = shared.Client.JumpPower.Value
		end
	end)
end

shared.Client.LoopJumpPower:OnChanged(function(val)
	if val then StartLoopJP()
	else StopLoopJP(); local hum = GetHum(); if hum then hum.JumpPower = 50; hum.JumpHeight = 7.2 end end
end)

shared.Client.JumpPower:OnChanged(function(val)
	local hum = GetHum(); if hum then hum.JumpPower = val; hum.JumpHeight = val end
end)

-- ═══════════════════════════════════════════
--  LOOP FOV
-- ═══════════════════════════════════════════
local function StopLoopFov()
	shared.Client.LoopFovConnection = SafeDisconnect(shared.Client.LoopFovConnection)
end

local function StartLoopFov()
	StopLoopFov()
	if not shared.Client.LoopFOV.Value then return end
	shared.Client.LoopFovConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.LoopFOV.Value then StopLoopFov() return end
		Camera.FieldOfView = shared.Client.FOV.Value
	end)
end

shared.Client.LoopFOV:OnChanged(function(val)
	if val then StartLoopFov() else StopLoopFov(); TweenFOV(70) end
end)

shared.Client.FOV:OnChanged(function(val)
	TweenService:Create(Camera, TweenInfo.new(0.3), {FieldOfView = val}):Play()
end)

-- ═══════════════════════════════════════════
--  NOCLIP
-- ═══════════════════════════════════════════
local function StopNoclip()
	shared.Client.NoclipConnection = SafeDisconnect(shared.Client.NoclipConnection)
	local char = GetCharacter()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

local function StartNoclip()
	StopNoclip()
	if not shared.Client.Noclip.Value then return end
	shared.Client.NoclipConnection = RunService.Stepped:Connect(function()
		if not shared.Client.Noclip.Value then StopNoclip() return end
		local char = GetCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end)
end

shared.Client.Noclip:OnChanged(function(val)
	if val then StartNoclip() else StopNoclip() end
end)

-- ═══════════════════════════════════════════
--  PAUSE [FE]
-- ═══════════════════════════════════════════
local function StopPause()
	shared.Client.PauseConnection = SafeDisconnect(shared.Client.PauseConnection)
	local hrp = GetHRP(); local hum = GetHum()
	if hrp then
		hrp.Anchored = false
		if PauseSavedCFrame then hrp.CFrame = PauseSavedCFrame; PauseSavedCFrame = nil end
	end
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
end

local function StartPause()
	StopPause()
	if not shared.Client.PauseFE.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	PauseSavedCFrame = hrp.CFrame
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity  = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	SetHumanoidStates(hum, false)
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	shared.Client.PauseConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.PauseFE.Value then StopPause() return end
		local h = GetHRP()
		if h then
			h.Anchored = true
			h.AssemblyLinearVelocity  = Vector3.zero
			h.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

shared.Client.PauseFE:OnChanged(function(val)
	if val then StartPause() else StopPause() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW TOOL
-- ═══════════════════════════════════════════
local function StopRainbowTool()
	shared.Client.RainbowtoolCon = SafeDisconnect(shared.Client.RainbowtoolCon)
	for part, color in pairs(RainbowToolOrigColors) do
		if part and part.Parent then part.Color = color end
	end
	RainbowToolOrigColors = {}
end

local function StartRainbowTool()
	StopRainbowTool()
	if not shared.Client.RainbowTool.Value then return end
	shared.Client.RainbowtoolCon = RunService.Heartbeat:Connect(function()
		if not shared.Client.RainbowTool.Value then StopRainbowTool() return end
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

shared.Client.RainbowTool:OnChanged(function(val)
	if val then StartRainbowTool() else StopRainbowTool() end
end)

-- ═══════════════════════════════════════════
--  RAINBOW CHARACTER
-- ═══════════════════════════════════════════
local function StopRainbowChar()
	shared.Client.RainbowcharCon = SafeDisconnect(shared.Client.RainbowcharCon)
	for part, color in pairs(RainbowCharOrigColors) do
		if part and part.Parent then part.Color = color end
	end
	RainbowCharOrigColors = {}
end

local function StartRainbowChar()
	StopRainbowChar()
	if not shared.Client.RainbowCharacter.Value then return end
	shared.Client.RainbowcharCon = RunService.Heartbeat:Connect(function()
		if not shared.Client.RainbowCharacter.Value then StopRainbowChar() return end
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

shared.Client.RainbowCharacter:OnChanged(function(val)
	if val then StartRainbowChar() else StopRainbowChar() end
end)

-- ═══════════════════════════════════════════
--  RTX
-- ═══════════════════════════════════════════
local function RTXSaveLightingProp(prop)
	if shared.Client.RTXLightingSaved[prop] == nil then shared.Client.RTXLightingSaved[prop] = Lighting[prop] end
end

local function RTXAddLightingInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = Lighting
	table.insert(RTXLightingInstances, inst)
end

local function RTXApplyToPart(part)
	if not part:IsA("BasePart") or shared.Client.RTXPartSaved[part] then return end
	shared.Client.RTXPartSaved[part] = {Material=part.Material, Reflectance=part.Reflectance, CastShadow=part.CastShadow}
	part.Reflectance = 0.45; part.CastShadow = true
	if part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
		part.Material = Enum.Material.Glass
	end
end

local function RTXRemoveFromPart(part)
	local saved = shared.Client.RTXPartSaved[part]; if not saved then return end
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
		if shared.Client.RTX.Value then RTXApplyToPart(obj) end
	end)
end

local function RevertRTX()
	RTXDescendantConn = SafeDisconnect(RTXDescendantConn)
	for _, inst in ipairs(shared.Client.RTXLightingInstances) do if inst and inst.Parent then inst:Destroy() end end
	shared.Client.RTXLightingInstances = {}
	for prop, val in pairs(shared.Client.RTXLightingSaved) do Lighting[prop] = val end
	shared.Client.RTXLightingSaved = {}
	for part in pairs(shared.Client.RTXPartSaved) do RTXRemoveFromPart(part) end
	shared.Client.RTXPartSaved = {}
end

shared.Client.RTX:OnChanged(function(val)
	if val then ApplyRTX() else RevertRTX() end
end)

-- ═══════════════════════════════════════════
--  NO ZOOM LIMIT
-- ═══════════════════════════════════════════
shared.Client.NoZoomLimit:OnChanged(function(val)
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
	shared.Client.Flying = false; flyUp = false; flyDown = false
	shared.Client.FlyConnection = SafeDisconnect(shared.Client.FlyConnection)
	shared.Client.FlyInputBegan = SafeDisconnect(shared.Client.FlyInputBegan)
	shared.Client.FlyInputEnded = SafeDisconnect(shared.Client.FlyInputEnded)
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
	if not shared.Client.Fly.Value then return end

	local function GetFlyDir()
		local camCF = Camera.CFrame; local hum = GetHum()
		local md = hum and hum.MoveDirection or Vector3.zero
		local dir = camCF.LookVector * md:Dot(camCF.LookVector)
			+ camCF.RightVector * md:Dot(camCF.RightVector)
			+ Vector3.new(0, (flyUp and 1 or 0) - (flyDown and 1 or 0), 0)
		return dir.Magnitude > 0.001 and dir.Unit or Vector3.zero
	end

	shared.Client.FlyConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.Fly.Value then StopFly() return end
		if not shared.Client.Flying then return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local bg = hrp:FindFirstChild("FlyBodyGyro"); local bv = hrp:FindFirstChild("FlyBodyVelocity")
		if not bg or not bv then return end
		hum:ChangeState(6); bg.CFrame = bg.CFrame:Lerp(Camera.CFrame, 0.2)
		local dir = GetFlyDir()
		TweenService:Create(bv, TweenInfo.new(0.15), {Velocity = dir * shared.Client.FlySpeed.Value}):Play()
		TweenFOV(dir ~= Vector3.zero and 100 or 70)
	end)

	shared.Client.FlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not shared.Client.Fly.Value then return end
		if key.KeyCode == Enum.KeyCode.F then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not shared.Client.Flying then
				shared.Client.Flying = true; SetHumanoidStates(hum, false); hum:ChangeState(6)
				local snd = hrp:FindFirstChild("Running"); if snd then snd.Volume = 0 end
				local bg = Instance.new("BodyGyro")
				bg.Name="FlyBodyGyro"; bg.MaxTorque=Vector3.new(4e5,4e5,4e5)
				bg.P=2e4; bg.D=100; bg.CFrame=Camera.CFrame; bg.Parent=hrp
				local bv = Instance.new("BodyVelocity")
				bv.Name="FlyBodyVelocity"; bv.Velocity=Vector3.zero
				bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
			else
				shared.Client.Flying = false; shared.Client.flyUp = false; shared.Client.flyDown = false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				local snd=hrp:FindFirstChild("Running"); if snd then snd.Volume=0.65 end
				local bv=hrp:FindFirstChild("FlyBodyVelocity"); if bv then bv:Destroy() end
				local bg=hrp:FindFirstChild("FlyBodyGyro");     if bg then bg:Destroy() end
				TweenFOV(70)
			end
		elseif key.KeyCode == Enum.KeyCode.Space     then shared.Client.flyUp   = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then shared.Client.flyDown = true
		end
	end)

	shared.Client.FlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space     then shared.Client.flyUp   = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then shared.Client.flyDown = false end
	end)
end

shared.Client.Fly:OnChanged(function(val)
	if val then StartFly() else StopFly() end
end)

-- ═══════════════════════════════════════════
--  CFRAME FLY (G to activate)
-- ═══════════════════════════════════════════
local function StopCframeFly()
	shared.Client.CFlying=false; shared.Client.cfUp=false; shared.Client.cfDown=false
	shared.Client.CframeFlyConnection = SafeDisconnect(shared.Client.CframeFlyConnection)
	shared.Client.CframeFlyInputBegan = SafeDisconnect(shared.Client.CframeFlyInputBegan)
	shared.Client.CframeFlyInputEnded = SafeDisconnect(shared.Client.CframeFlyInputEnded)
	local hrp = GetHRP(); if hrp then hrp.Anchored = false end
	SetCharacterCollision(true)
	local hum = GetHum()
	if hum then SetHumanoidStates(hum, true); hum:ChangeState(Enum.HumanoidStateType.Freefall) end
	TweenFOV(70)
end

local function StartCframeFly()
	StopCframeFly()
	if not shared.Client.CFly.Value then return end

	shared.Client.CframeFlyConnection = RunService.RenderStepped:Connect(function(dt)
		if not shared.Client.CFly.Value then StopCframeFly() return end
		if not shared.Client.CFlying then return end
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
		hrp.CFrame = CFrame.new(hrp.Position + dir*shared.Client.FlySpeed.Value*dt) * (hrp.CFrame - hrp.Position)
		TweenFOV(moving and 100 or 70)
	end)

	shared.Client.CframeFlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not shared.Client.CFly.Value then return end
		if key.KeyCode == Enum.KeyCode.G then
			local hrp = GetHRP(); local hum = GetHum()
			if not hrp or not hum then return end
			if not shared.Client.CFlying then
				shared.Client.CFlying=true; SetHumanoidStates(hum, false); hum:ChangeState(6)
				hrp.Anchored=true; SetCharacterCollision(false)
			else
				shared.Client.CFlying=false; shared.Client.cfUp=false; shared.Client.cfDown=false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				hrp.Anchored=false; SetCharacterCollision(true); TweenFOV(70)
			end
		elseif key.KeyCode == Enum.KeyCode.Space     then shared.Client.cfUp   = true
		elseif key.KeyCode == Enum.KeyCode.LeftShift then shared.Client.cfDown = true
		end
	end)

	shared.Client.CframeFlyInputEnded = UIS.InputEnded:Connect(function(key)
		if key.KeyCode == Enum.KeyCode.Space     then shared.Client.cfUp   = false end
		if key.KeyCode == Enum.KeyCode.LeftShift then shared.Client.cfDown = false end
	end)
end

shared.Client.CFly:OnChanged(function(val)
	if val then StartCframeFly() else StopCframeFly() end
end)

-- ═══════════════════════════════════════════
--  ANTI AFK
-- ═══════════════════════════════════════════
local function StopAntiAFK()
	shared.Client.AntiAFKConnection = SafeDisconnect(AntiAFKConnection)
end

local function StartAntiAFK()
	StopAntiAFK()
	if not shared.Client.AntiAFK.Value then return end
	local elapsed = 0
	shared.Client.AntiAFKConnection = RunService.Heartbeat:Connect(function(dt)
		if not shared.Client.AntiAFK.Value then StopAntiAFK() return end
		elapsed += dt
		if elapsed >= 900 then
			elapsed = 0
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.zero)
		end
	end)
end

Player.Idled:Connect(function()
	if shared.Client.AntiAFK.Value then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end
end)

shared.Client.AntiAFK:OnChanged(function(val)
	if val then StartAntiAFK() else StopAntiAFK() end
end)

-- ═══════════════════════════════════════════
--  INFINITE JUMP
-- ═══════════════════════════════════════════
local function StopInfJump()
	shared.Client.InfJumpConn = SafeDisconnect(shared.Client.InfJumpConn)
end

local function StartInfJump()
	StopInfJump()
	if not shared.Client.InfiniteJump.Value then return end
	shared.Client.InfJumpConn = UIS.JumpRequest:Connect(function()
		if not shared.Client.InfiniteJump.Value then StopInfJump() return end
		local h = GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end

shared.Client.InfiniteJump:OnChanged(function(val)
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

shared.Client.Freeze:OnChanged(function(val) SetFreeze(val) end)

-- ═══════════════════════════════════════════
--  USE VELOCITY
-- ═══════════════════════════════════════════
local function StopUseVelocity()
	shared.Client.UseVelocityConnection = SafeDisconnect(shared.Client.UseVelocityConnection)
end

local function StartUseVelocity()
	StopUseVelocity()
	if not shared.Client.Velocity.Value then return end
	shared.Client.UseVelocityConnection = RunService.Heartbeat:Connect(function(dt)
		if not shared.Client.Velocity.Value then StopUseVelocity() return end
		local hrp = GetHRP(); local hum = GetHum()
		if not hrp or not hum then return end
		local md = hum.MoveDirection
		if md.Magnitude < 0.01 then return end
		hrp.CFrame = hrp.CFrame + md * shared.Client.VelocitySpeed.Value * dt
	end)
end

shared.Client.Velocity:OnChanged(function(val)
	if val then StartUseVelocity() else StopUseVelocity() end
end)

-- ═══════════════════════════════════════════
--  CAR SPIN
-- ═══════════════════════════════════════════
local function StopSpin()
	shared.Client.SpinConnection = SafeDisconnect(SpinConnection)
end

local function StartSpin()
	StopSpin()
	if not shared.Client.CarSpin.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local spinSpeed = 0
	shared.Client.SpinConnection = RunService.RenderStepped:Connect(function(dt)
		if not shared.Client.CarSpin.Value then StopSpin() return end
		if not hrp.Parent then StopSpin() return end
		spinSpeed += dt * 2
		local rotation = CFrame.Angles(0, math.rad(spinSpeed * shared.Client.CarSpinSpeed.Value), 0)
		local seat = GetSeat()
		if seat then seat.CFrame = seat.CFrame * rotation
		else hrp.CFrame = hrp.CFrame * rotation end
	end)
end

shared.Client.CarSpin:OnChanged(function(val)
	if val then StartSpin() else StopSpin() end
end)

-- ═══════════════════════════════════════════
--  BOUNCY CAR
-- ═══════════════════════════════════════════
local function StopBouncy()
	shared.Client.BounceConnection = SafeDisconnect(shared.Client.BounceConnection)
end

local function StartBouncy()
	StopBouncy()
	if not shared.Client.BouncyCar.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local bounceTimer = 0; local isGoingUp = true
	local upVelocity = 80; local downVelocity = -100
	shared.Client.BounceConnection = RunService.Heartbeat:Connect(function(dt)
		if not shared.Client.BouncyCar.Value then StopBouncy() return end
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

shared.Client.BouncyCar:OnChanged(function(val)
	if val then StartBouncy() else StopBouncy() end
end)

-- ═══════════════════════════════════════════
--  FLING CAR (seated)
-- ═══════════════════════════════════════════
local function StopFlingCar()
	shared.Client.FlingCarConnection = SafeDisconnect(shared.Client.FlingCarConnection)
end

local function StartFlingCar()
	StopFlingCar()
	if not shared.Client.FlingCar.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end
	local seat = GetSeat()
	if not seat then
		shared.Client.FlingCar:SetValue(false)
		return
	end
	local spinSpeed, crazyTimer, phase = 0, 0, 1
	local skyPower = 0
	shared.Client.FlingCarConnection = RunService.Heartbeat:Connect(function(dt)
		if not shared.Client.FlingCar.Value then StopFlingCar() return end
		if not hum.Sit or not hum.SeatPart then StopFlingCar() return end
		seat = hum.SeatPart
		crazyTimer += dt
		local strength = shared.Client.CarFlingStrength.Value
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

shared.Client.FlingCar:OnChanged(function(val)
	if val then StartFlingCar() else StopFlingCar() end
end)

-- ═══════════════════════════════════════════
--  CAR FLY (F to activate, uses CarFlying)
-- ═══════════════════════════════════════════
local function StopCarFly()
	shared.Client.CarFlying = false
	shared.Client.CarFlyConnection = SafeDisconnect(shared.Client.CarFlyConnection)
	shared.Client.CarFlyInputBegan = SafeDisconnect(shared.Client.CarFlyInputBegan)
	shared.Client.CarFlyInputEnded = SafeDisconnect(shared.Client.CarFlyInputEnded)
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
	if not shared.Client.CarFly.Value then return end
	local hrp = GetHRP(); local hum = GetHum()
	if not hrp or not hum then return end

	shared.Client.CarFlyConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.CarFly.Value then StopCarFly() return end
		if not shared.Client.CarFlying then return end
		local bv = hrp:FindFirstChild("CarFlyBV")
		local bg = hrp:FindFirstChild("CarFlyBG")
		if not bv or not bg then return end
		local camCF = Camera.CFrame; local md = hum.MoveDirection
		local dir = camCF.LookVector*md:Dot(camCF.LookVector) + camCF.RightVector*md:Dot(camCF.RightVector)
		local moving = dir.Magnitude > 0.001; if moving then dir = dir.Unit end
		bg.CFrame = bg.CFrame:Lerp(camCF, 0.2)
		TweenService:Create(bv, TweenInfo.new(0.15), {Velocity = dir * shared.Client.CarFlySpeed.Value}):Play()
		TweenFOV(moving and 100 or 70)
	end)

	shared.Client.CarFlyInputBegan = UIS.InputBegan:Connect(function(key, gp)
		if gp or not shared.Client.CarFly.Value then return end
		if key.KeyCode == Enum.KeyCode.F then
			if not shared.Client.CarFlying then
				shared.Client.CarFlying = true
				SetHumanoidStates(hum, false); hum:ChangeState(6)
				local bv = Instance.new("BodyVelocity")
				bv.Name="CarFlyBV"; bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
				local bg = Instance.new("BodyGyro")
				bg.Name="CarFlyBG"; bg.MaxTorque=Vector3.new(4e5,4e5,4e5); bg.P=2e4; bg.D=100; bg.CFrame=Camera.CFrame; bg.Parent=hrp
			else
				shared.Client.CarFlying = false
				SetHumanoidStates(hum, true); hum:ChangeState(8)
				local bv=hrp:FindFirstChild("CarFlyBV"); if bv then bv:Destroy() end
				local bg=hrp:FindFirstChild("CarFlyBG"); if bg then bg:Destroy() end
				TweenFOV(70)
			end
		end
	end)
end

shared.Client.CarFly:OnChanged(function(val)
	if val then StartCarFly() else StopCarFly() end
end)

-- ═══════════════════════════════════════════
--  CAR BOOST (hold B)
-- ═══════════════════════════════════════════
local function StopBoost()
	shared.Client.BoostConnection = SafeDisconnect(shared.Client.BoostConnection)
	shared.Client.BoostInputBegan = SafeDisconnect(shared.Client.BoostInputBegan)
	shared.Client.BoostInputEnded = SafeDisconnect(shared.Client.BoostInputEnded)
end

local function StartBoost()
	StopBoost()
	if not shared.Client.CarBoost.Value then return end
	local hum = GetHum(); if not hum then return end
	local boosting = false
	shared.Client.BoostInputBegan = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.B then boosting = true end
	end)
	shared.Client.BoostInputEnded = UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.B then boosting = false end
	end)
	shared.Client.BoostConnection = RunService.Heartbeat:Connect(function()
		if not shared.Client.CarBoost.Value then StopBoost() return end
		if not boosting then return end
		local seat = GetSeat(); if not seat or not seat.Parent then return end
		local look = seat.CFrame.LookVector; local vel = seat.AssemblyLinearVelocity
		local speed = math.random(250, 1000)
		seat.AssemblyLinearVelocity = Vector3.new(look.X*speed, vel.Y, look.Z*speed)
	end)
end

shared.Client.CarBoost:OnChanged(function(val)
	if val then StartBoost() else StopBoost() end
end)

-- ═══════════════════════════════════════════
--  CAR FLINGER (hover + click)
-- ═══════════════════════════════════════════
local function StopHovering()
	shared.Client.HoverConnection    = SafeDisconnect(shared.Client.HoverConnection)
	shared.Client.FlingcarConnection = SafeDisconnect(shared.Client.FlingcarConnection)
	if HoverHighlight then HoverHighlight:Destroy(); HoverHighlight = nil end
	HoveredCar = nil
end

local function StartHovering()
	StopHovering()
	if not shared.Client.CarFlinger.Value then return end
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
			if not shared.Client.CarFlinger.Value or elapsed >= 1.5 then
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
		if not shared.Client.CarFlinger.Value then StopHovering() return end
		local target = Mouse.Target
		if target then
			local car = GetCarFromInstance(target)
			if car then SetHighlight(car) return end
		end
		if HoveredCar then ClearHighlight(HoveredCar); HoveredCar = nil end
	end)

	FlingcarConnection = Mouse.Button1Down:Connect(function()
		if not shared.Client.CarFlinger.Value or not HoveredCar then return end
		local car = HoveredCar
		ClearHighlight(car); HoveredCar = nil
		FlingTargetCar(car)
	end)
end

shared.Client.CarFlinger:OnChanged(function(val)
	if val then StartHovering() else StopHovering() end
end)

-- ═══════════════════════════════════════════
--  CHARACTER RESPAWN
-- ═══════════════════════════════════════════
local function OnCharacterAdded(newChar)
	WaitUntil(function() return newChar:FindFirstChildOfClass("Humanoid") end)
	WaitUntil(function() return newChar:FindFirstChild("HumanoidRootPart") end)
	task.wait(0.15)

	local hum = GetHum()
	if hum then
		hum.WalkSpeed = shared.Client.Walkspeed.Value
		hum.JumpPower = shared.Client.JumpPower.Value
	end

	if shared.Client.LoopWalkspeed.Value    then StartLoopWS()       end
	if shared.Client.LoopJumpPower.Value    then StartLoopJP()       end
	if shared.Client.LoopFOV.Value          then StartLoopFov()      end
	if shared.Client.Noclip.Value           then StartNoclip()       end
	if shared.Client.AntiAFK.Value          then StartAntiAFK()      end
	if shared.Client.InfiniteJump.Value     then StartInfJump()      end
	if shared.Client.Velocity.Value         then StartUseVelocity()  end
	if shared.Client.PauseFE.Value          then StartPause()        end
	if shared.Client.RainbowTool.Value      then StartRainbowTool()  end
	if shared.Client.RainbowCharacter.Value then StartRainbowChar()  end
	if shared.Client.Naked.Value            then task.delay(0.5, ApplyNaked) end
	if shared.Client.Fly.Value  then Flying=false;  flyUp=false;  flyDown=false;  StartFly()        end
	if shared.Client.CFly.Value then CFlying=false; cfUp=false;   cfDown=false;   StartCframeFly()  end

	-- car handlers
	CarFlying = false
	if shared.Client.CarSpin.Value    then StartSpin()       end
	if shared.Client.CarFly.Value     then StartCarFly()     end
	if shared.Client.BouncyCar.Value  then StartBouncy()     end
	if shared.Client.CarBoost.Value   then StartBoost()      end
	if shared.Client.CarFlinger.Value then StartHovering()   end
end

Player.CharacterAdded:Connect(function(char)
	task.spawn(OnCharacterAdded, char)
end)

task.spawn(function()
	local char = WaitUntil(function() return Player.Character end)
	task.spawn(OnCharacterAdded, char)
end)

-- persistent on load
if shared.Client.AntiAFK.Value then StartAntiAFK() end
if shared.Client.LoopFOV.Value then StartLoopFov() end
if shared.Client.RTX.Value     then ApplyRTX()     end
