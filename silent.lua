-- Due to the way I manipulate the camera, it is necessary to implement the shooting mechanics in this specific manner.
-- WORKS ON ALL EXECUTORS

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local targetPlayer = nil
local isLeftMouseDown = false
local isRightMouseDown = false
local autoClickConnection = nil

local sharedsilent = shared.Silentaim

local accuracy = 100
local bodyshotchance = 98
local headshotchance = 67

local FOVsize = 80
local ShowFov = true
local active = false
local legit = false
local wallcheck = false
local teamcheck = false
local distance = 100
local target_priority = "Closest"
local target_body_part = "UpperTorso"
local activatetoggle = "MB2"
local mode = "Hold"
local highlight_target = false

local fovCirclePos = nil
local Circlefov = sharedsilent.sfovCircle

local highlightCache = {}
local hrpSizeCache = {} -- store original HRP sizes

local lastAimActive = nil
local lastActive = nil
local lastIsLobby = nil
local lastTarget = nil

local isShooting = false

local HRP_EXPANDED_SIZE = Vector3.new(6, 6, 6) -- expanded hitbox size, tweak as needed

local function updatesilentvalues()
	pcall(function()
		active = sharedsilent.sActive.Value
		legit = sharedsilent.sLegit.Value
		wallcheck = sharedsilent.sWallCheck.Value
		teamcheck = sharedsilent.sTeamCheck.Value
		distance = sharedsilent.sdistance.Value
		target_priority = sharedsilent.sTargetPriority.Value
		target_body_part = sharedsilent.sTargetBodyPart.Value
		activatetoggle = sharedsilent.sSilentAimKey.Value
		mode = sharedsilent.sMode
		ShowFov = sharedsilent.sShowfov.Value
		FOVsize = sharedsilent.sFov.Value
		highlight_target = sharedsilent.sShowTarget.Value
		accuracy = sharedsilent.sHitChance.Value
		bodyshotchance = sharedsilent.sBodyShotChance.Value
		headshotchance = sharedsilent.sHeadshotChance.Value

		if ShowFov then
			Circlefov.Visible = ShowFov
		end
	end)
end

local function isLobbyVisible()
	return localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible == true
end

-- expand HRP of a character, cache original size
local function expandHitbox(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if not hrpSizeCache[character] then
		hrpSizeCache[character] = hrp.Size
		hrp.Size = HRP_EXPANDED_SIZE
	end
end

-- restore HRP to original size
local function restoreHitbox(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if hrpSizeCache[character] then
		hrp.Size = hrpSizeCache[character]
		hrpSizeCache[character] = nil
	end
end

-- restore all hitboxes (called when aim is off or no target)
local function restoreAllHitboxes()
	for character, originalSize in pairs(hrpSizeCache) do
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Size = originalSize
		end
		hrpSizeCache[character] = nil
	end
end

local function updateHighlight()
	for player, highlight in pairs(highlightCache) do
		if player ~= targetPlayer then
			highlight:Destroy()
			highlightCache[player] = nil
		end
	end

	if not highlight_target or not targetPlayer or not targetPlayer.Character then
		return
	end

	local character = targetPlayer.Character

	if not highlightCache[targetPlayer] then
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 0, 0)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = character
		hl.Parent = character
		highlightCache[targetPlayer] = hl
	else
		highlightCache[targetPlayer].Adornee = character
	end
end

local function Getplayerinfov()
	local target = nil
	local bestScore = math.huge
	local mousePos = UserInputService:GetMouseLocation()
	local fovRadius = (FOVsize / 180) * (camera.ViewportSize.Y / 2)

	local checkedCount = 0
	local skippedCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if player == localPlayer then continue end
		if not player.Character then continue end

		if teamcheck and player.Team == localPlayer.Team then
			skippedCount += 1
			continue
		end

		local character = player.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			skippedCount += 1
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local dist = myRoot and (rootPart.Position - myRoot.Position).Magnitude or math.huge
		if dist > distance then
			skippedCount += 1
			continue
		end

		local targetPart = character:FindFirstChild(target_body_part)
			or character:FindFirstChild("UpperTorso")
			or rootPart
		if not targetPart then continue end

		local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then
			skippedCount += 1
			continue
		end

		local screenVec = Vector2.new(screenPos.X, screenPos.Y)
		local distToCrosshair = (screenVec - mousePos).Magnitude
		if distToCrosshair > fovRadius then
			skippedCount += 1
			continue
		end

		if wallcheck then
			local origin = camera.CFrame.Position
			local direction = targetPart.Position - origin
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {localPlayer.Character, character}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(origin, direction, rayParams)
			if result then
				skippedCount += 1
				continue
			end
		end

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

		checkedCount += 1

		if score < bestScore then
			bestScore = score
			target = player
		end
	end

	if target ~= lastTarget then
		print("[SilentAim] Target changed: " .. (target and target.Name or "nil") .. " | Checked: " .. checkedCount .. " | Skipped: " .. skippedCount)
		lastTarget = target
	end

	return target
end

local function getTargetPart(character)
	local roll = math.random(1, 100)
	local partName

	if roll <= headshotchance then
		partName = "Head"
	elseif roll <= headshotchance + bodyshotchance then
		partName = "UpperTorso"
	else
		partName = target_body_part
	end

	return character:FindFirstChild(partName)
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("HumanoidRootPart")
end

local function lockCameraToHead()
	if not targetPlayer or not targetPlayer.Character then return end
	if math.random(1, 100) > accuracy then return end

	local character = targetPlayer.Character
	local part = getTargetPart(character)
	if not part then return end

	-- predict position based on velocity + ping
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local velocity = rootPart and rootPart.AssemblyLinearVelocity or Vector3.zero
	local pingSeconds = localPlayer:GetNetworkPing()
	local predictedPosition = part.Position + (velocity * pingSeconds)

	local screenPos = camera:WorldToViewportPoint(predictedPosition)
	if screenPos.Z > 0 then
		local targetCFrame = CFrame.new(camera.CFrame.Position, predictedPosition)
		camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.85)
	end
end
--[[
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

UserInputService.InputBegan:Connect(function(input, isProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not isProcessed then
		if not isLeftMouseDown then
			isLeftMouseDown = true
			isShooting = true
			autoClick()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isProcessed then
		if not isRightMouseDown then
			isRightMouseDown = true
			isShooting = true
			autoClick()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, isProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not isProcessed then
		isLeftMouseDown = false
		if not isRightMouseDown then isShooting = false end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isProcessed then
		isRightMouseDown = false
		if not isLeftMouseDown then isShooting = false end
	end
end)]]

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

RunService:BindToRenderStep("SilentAim", Enum.RenderPriority.Camera.Value + 1, function()
	updatesilentvalues()
	UpdateFOVCircle()

	local islobby = isLobbyVisible()
	local aimActive = sharedsilent.sAimActive

	if aimActive ~= lastAimActive then
		print("[SilentAim] Aim state: " .. tostring(aimActive) .. " | mode: " .. tostring(mode))
		lastAimActive = aimActive
	end

	if active ~= lastActive then
		print("[SilentAim] Active changed: " .. tostring(active))
		lastActive = active
	end

	if islobby ~= lastIsLobby then
		print("[SilentAim] Lobby state: " .. tostring(islobby))
		lastIsLobby = islobby
	end

	if not islobby and active and aimActive then
		targetPlayer = Getplayerinfov()

		if targetPlayer and targetPlayer.Character then
			-- expand hitbox while targeting
			expandHitbox(targetPlayer.Character)

			if isShooting then
				lockCameraToHead()
			end
		else
			-- no target, restore all hitboxes
			restoreAllHitboxes()
		end
	else
		targetPlayer = nil
		restoreAllHitboxes()
	end

	updateHighlight()
end)

-- clean up hitboxes if character is removed mid game
Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		restoreHitbox(player.Character)
	end
end)
