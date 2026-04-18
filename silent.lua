-- Due to the way I manipulate the camera, it is necessary to implement the shooting mechanics in this specific manner.
-- WORKS ON ALL EXECUTORS
print("test")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local targetPlayer = nil
local ClickInterval = 0.10
local isLeftMouseDown = false
local isRightMouseDown = false
local autoClickConnection = nil

local sharedsilent = shared.Silentaim

local FOVsize = 80
local ShowFov = true

local active = false
local accuracy = 67
local legit = false
local wallcheck = false
local teamcheck = false
local distance = 100
local target_priority = "Closest"
local target_body_part = "UpperTorso"
local activatetoggle = "MB2"
local mode = "Hold"
local headshotchance = 55
local bodyshotchance = 55

local fovCirclePos = nil
local highlight_target = false
local Circlefov = sharedsilent.sfovCircle

local whitelistedparts = {'Head', 'UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm'}
local whitelistedbuttons = {'MB2', 'MB1'}

local function updatesilentvalues()
	pcall(function()
		active = sharedsilent.sActive.Value
		accuracy = sharedsilent.sHitChance.Value
		legit = sharedsilent.sLegit.Value
		wallcheck = sharedsilent.sWallCheck.Value
		teamcheck = sharedsilent.sTeamCheck.Value
		distance = sharedsilent.sdistance.Value
		target_priority = sharedsilent.sTargetPriority.Value
		target_body_part = sharedsilent.sTargetBodyPart.Value
		activatetoggle = sharedsilent.sSilentAimKey.Value
		mode = sharedsilent.sMode.Value
		headshotchance = sharedsilent.sHeadshotChance.Value
		bodyshotchance = sharedsilent.sBodyShotChance.Value
		ShowFov = sharedsilent.sShowfov.Value
		FOVsize = sharedsilent.SilentAimFOV.Value
		highlight_target = sharedsilent.sShowTarget.Value

		if ShowFov then
			Circlefov.Visible = ShowFov
		end
	end)
end

local function isLobbyVisible()
	return localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible == true
end

local function Getplayerinfov()
	local target = nil
	local bestScore = math.huge
	local mousePos = UserInputService:GetMouseLocation()
	local fovRadius = (FOVsize / 180) * (camera.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end

		-- Team check
		if teamcheck and player.Team == localPlayer.Team then continue end

		local character = player.Character

		-- Humanoid alive check
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		-- Root part for distance
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		-- Distance check
		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local dist = myRoot and (rootPart.Position - myRoot.Position).Magnitude or math.huge
		if dist > distance then continue end

		-- Resolve target body part
		local targetPart = character:FindFirstChild(target_body_part)
			or character:FindFirstChild("UpperTorso")
			or rootPart
		if not targetPart then continue end

		-- Screen position / FOV check
		local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then continue end
		local screenVec = Vector2.new(screenPos.X, screenPos.Y)
		local distToCrosshair = (screenVec - mousePos).Magnitude
		if distToCrosshair > fovRadius then continue end

		-- Wall check
		if wallcheck then
			local origin = camera.CFrame.Position
			local direction = targetPart.Position - origin
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {localPlayer.Character, character}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(origin, direction, rayParams)
			if result then continue end
		end

		-- Accuracy/hit chance check
		if math.random(1, 100) > accuracy then continue end

		-- Priority scoring
		local score
		if target_priority == "Closest To Crosshair" or target_priority == "Closest" then
			score = distToCrosshair
		elseif target_priority == "Distance" then
			score = dist
		elseif target_priority == "Health" then
			score = humanoid.Health
		elseif target_priority == "Random" then
			score = math.random()
		else
			score = distToCrosshair
		end

		if score < bestScore then
			bestScore = score
			target = player
		end
	end

	return target
end

local function lockCameraToHead()
	if not targetPlayer or not targetPlayer.Character then return end

	local character = targetPlayer.Character

	-- Decide part based on headshot/bodyshot chance
	local partName = target_body_part
	local roll = math.random(1, 100)
	if roll <= headshotchance then
		partName = "Head"
	elseif roll <= headshotchance + bodyshotchance then
		partName = "UpperTorso"
	end

	local part = character:FindFirstChild(partName)
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("HumanoidRootPart")

	if not part then return end

	local screenPos = camera:WorldToViewportPoint(part.Position)
	if screenPos.Z > 0 then
		local cameraPosition = camera.CFrame.Position
		camera.CFrame = CFrame.new(cameraPosition, part.Position)
	end
end

-- autoclick (not used, kept for reference)
local function autoClick()
	if autoClickConnection then
		autoClickConnection:Disconnect()
	end
	autoClickConnection = RunService.Heartbeat:Connect(function()
		if isLeftMouseDown or isRightMouseDown then
			if not isLobbyVisible() then
				mouse1click()
			end
		else
			autoClickConnection:Disconnect()
		end
	end)
end

local function IsAimKeyDown()
	local AimKey = activatetoggle
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

local function UpdateFOVCircle()
	local fovCircle = Circlefov
	if not fovCircle then return end

	local showFov = (sharedsilent and sharedsilent.sShowfov and sharedsilent.sShowfov.Value) or false
	local aimbotActive = (sharedsilent and sharedsilent.sActive and sharedsilent.sActive.Value) or false

	if not showFov or not aimbotActive then
		pcall(function() fovCircle.Visible = false end)
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local radius = (FOVsize / 180) * (camera.ViewportSize.Y / 2)

	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos

	pcall(function()
		fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
		fovCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)
		fovCircle.Visible = true
	end)
end

local toggleState = false
local wasAimKeyDown = false

local function loop()
	updatesilentvalues()
	UpdateFOVCircle()

	local isaimkeydown = IsAimKeyDown()
	local islobby = isLobbyVisible()

	-- Handle toggle mode
	if mode == "Toggle" then
		if isaimkeydown and not wasAimKeyDown then
			toggleState = not toggleState
		end
		wasAimKeyDown = isaimkeydown
	elseif mode == "Hold" then
		toggleState = isaimkeydown
	elseif mode == "Always" then
		toggleState = true
	end

	if not islobby and active and toggleState then
		targetPlayer = Getplayerinfov()
		if targetPlayer then
			lockCameraToHead()
		end
	else
		targetPlayer = nil
	end
end

RunService.Heartbeat:Connect(function()
	loop()
end)
