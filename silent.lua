local util = require(game:GetService("ReplicatedStorage").Modules.Utility)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local targetPlayer = nil
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
local hrpSizeCache = {}
local lastAimActive = nil
local lastActive = nil
local lastIsLobby = nil
local toggleState = false
local lastKeyState = false

local HRP_EXPANDED_SIZE = Vector3.new(6, 6, 6)

local function updatesilentvalues()
	pcall(function()
		active          = sharedsilent.sActive.Value
		legit           = sharedsilent.sLegit.Value
		wallcheck       = sharedsilent.sWallCheck.Value
		teamcheck       = sharedsilent.sTeamCheck.Value
		distance        = sharedsilent.sdistance.Value
		target_priority = sharedsilent.sTargetPriority.Value
		target_body_part = sharedsilent.sTargetBodyPart.Value
		activatetoggle  = sharedsilent.sSilentAimKey.Value
		mode            = sharedsilent.sMode
		ShowFov         = sharedsilent.sShowfov.Value
		FOVsize         = sharedsilent.sFov.Value
		highlight_target = sharedsilent.sShowTarget.Value
		accuracy        = sharedsilent.sHitChance.Value
		bodyshotchance  = sharedsilent.sBodyShotChance.Value
		headshotchance  = sharedsilent.sHeadshotChance.Value
		if ShowFov then Circlefov.Visible = ShowFov end
	end)
end

local function isLobbyVisible()
	return localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible == true
end

local function isAimKeyDown()
	if not activatetoggle then return false end
	if activatetoggle:match("^MB%d") then
		local buttonNum = tonumber(activatetoggle:match("%d"))
		if buttonNum then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton" .. buttonNum])
		end
	else
		local keyEnum = Enum.KeyCode[activatetoggle]
		if keyEnum then
			return UserInputService:IsKeyDown(keyEnum)
		end
	end
	return false
end

local function isAimActive()
	local keyDown = isAimKeyDown()
	if mode == "Hold" then
		return keyDown
	elseif mode == "Toggle" then
		if keyDown and not lastKeyState then
			toggleState = not toggleState
		end
		lastKeyState = keyDown
		return toggleState
	elseif mode == "Always" then
		return true
	end
	return false
end

local function expandHitbox(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not hrpSizeCache[character] then
		hrpSizeCache[character] = hrp.Size
		hrp.Size = HRP_EXPANDED_SIZE
	end
end

local function restoreHitbox(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if hrpSizeCache[character] then
		hrp.Size = hrpSizeCache[character]
		hrpSizeCache[character] = nil
	end
end

local function restoreAllHitboxes()
	for character, originalSize in pairs(hrpSizeCache) do
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Size = originalSize end
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
	if not highlight_target or not targetPlayer or not targetPlayer.Character then return end
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

-- exact same logic as open source, just with your settings plugged in
local function getTarget(origin)
	local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local best, bestDist = nil, math.huge
	local myChar = localPlayer.Character

	for _, p in pairs(Players:GetPlayers()) do
		if p == localPlayer then continue end
		local char = p.Character
		if not char or char == myChar then continue end
		if teamcheck and p.Team == localPlayer.Team then continue end

		local head = char:FindFirstChild("Head")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not head or not hum or hum.Health <= 0 then continue end
		if (origin - head.Position).Magnitude > distance then continue end

		if wallcheck then
			local rp = RaycastParams.new()
			rp.FilterDescendantsInstances = {myChar, char}
			rp.FilterType = Enum.RaycastFilterType.Exclude
			local res = workspace:Raycast(camera.CFrame.Position, head.Position - camera.CFrame.Position, rp)
			if res then continue end
		end

		local sp, vis = camera:WorldToViewportPoint(head.Position)
		if not vis then continue end

		local fovRadius = (FOVsize / 180) * (camera.ViewportSize.Y / 2)
		local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if d < fovRadius and d < bestDist then
			bestDist = d
			best = head
			targetPlayer = p
		end
	end

	if not best then targetPlayer = nil end
	return best
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

-- EXACTLY like open source: pass target.Position directly, no unit math
local origRaycast = util.Raycast
util.Raycast = function(self, origin, direction, dist, ...)
	if active and not isLobbyVisible() and isAimActive() then
		local target = getTarget(origin)
		if target and math.random(1, 100) <= accuracy then
			local rootPart = target.Parent:FindFirstChild("HumanoidRootPart")
			local velocity = rootPart and rootPart.AssemblyLinearVelocity or Vector3.zero
			local ping = localPlayer:GetNetworkPing()
			local predictedPos = target.Position + (velocity * ping)
			return origRaycast(self, origin, predictedPos, dist, ...)
		end
	end
	return origRaycast(self, origin, direction, dist, ...)
end

local origParticles = util.PlayParticles
util.PlayParticles = function(self, obj)
	if typeof(obj) == "Instance" then
		local n = obj.Name:lower()
		if n:find("flash") or n:find("smoke") or n:find("blind") then return end
	end
	return origParticles(self, obj)
end

RunService:BindToRenderStep("SilentAim", Enum.RenderPriority.Camera.Value + 1, function()
	updatesilentvalues()
	UpdateFOVCircle()

	local islobby = isLobbyVisible()
	local aimActive = isAimActive()

	if aimActive ~= lastAimActive then
		print("[SilentAim] Aim state: " .. tostring(aimActive))
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
		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		getTarget(myRoot and myRoot.Position or camera.CFrame.Position)
		if targetPlayer and targetPlayer.Character then
			expandHitbox(targetPlayer.Character)
		else
			restoreAllHitboxes()
		end
	else
		targetPlayer = nil
		toggleState = false
		restoreAllHitboxes()
	end

	updateHighlight()
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		restoreHitbox(player.Character)
	end
end)
