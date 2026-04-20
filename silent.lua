local util = require(game:GetService("ReplicatedStorage").Modules.Utility)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
 print("gfn")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local WS = workspace
local UIS = UserInputService
local mrand = math.random
local mhuge = math.huge
local msqrt = math.sqrt
local tick = tick
 
local sharedsilent = shared.Silentaim
 
local targetPlayer = nil
local targetHead = nil
local toggleState = false
local lastKeyState = false
local frameCount = 0
 
local s_active = false
local s_wallcheck = false
local s_teamcheck = false
local s_distance = 100
local s_fov = 80
local s_showFov = true
local s_accuracy = 100
local s_mode = "Hold"
local s_key = "MB2"
local s_highlight = false
local s_bodychance = 98
local s_headchance = 67
 
local lobbyCache = false
local lastLobbyTick = 0
local cachedPing = 0
local lastPingTick = 0
local lastSettingsTick = 0
local lastPlayersTick = 0
local playerCache = {}
 
local hrpCache = {}
local HRP_SIZE = Vector3.new(6, 6, 6)
 
local keyMB = nil
local keyEnum = nil
local keyStr = ""
 
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true
 
local _MB1 = Enum.UserInputType.MouseButton1
local _MB2 = Enum.UserInputType.MouseButton2
local _MB3 = Enum.UserInputType.MouseButton3
local ZERO3 = Vector3.zero
 
local Circlefov = sharedsilent.sfovCircle
local fovCirclePos = nil
local hlCache = {}
 
local _lobbyRef = nil
 
-- ✅ FIX #1: Per-shot accuracy tracking
local shotAccuracy = {}
 
-- ── Settings ──────────────────────────────────────────────────────────────────
 
local function syncSettings()
	local now = tick()
	if now - lastSettingsTick < 0.15 then return end
	lastSettingsTick = now
	pcall(function()
		s_active     = sharedsilent.sActive.Value
		s_wallcheck  = sharedsilent.sWallCheck.Value
		s_teamcheck  = sharedsilent.sTeamCheck.Value
		s_highlight  = sharedsilent.sShowTarget.Value
		s_showFov    = sharedsilent.sShowfov.Value
		s_accuracy   = sharedsilent.sHitChance.Value
		s_bodychance = sharedsilent.sBodyShotChance.Value
		s_headchance = sharedsilent.sHeadshotChance.Value
		s_mode       = sharedsilent.sMode
		s_key        = sharedsilent.sSilentAimKey.Value
		s_fov        = sharedsilent.sFov.Value
		local d      = sharedsilent.sdistance.Value
		s_distance   = d
	end)
end
 
-- ── Key Cache ─────────────────────────────────────────────────────────────────
 
local function syncKey()
	if s_key == keyStr then return end
	keyStr = s_key
	keyMB = nil
	keyEnum = nil
	if not s_key then return end
	if s_key:sub(1, 2) == "MB" then
		local n = tonumber(s_key:sub(3))
		if n == 1 then keyMB = _MB1
		elseif n == 2 then keyMB = _MB2
		elseif n == 3 then keyMB = _MB3 end
	else
		keyEnum = Enum.KeyCode[s_key]
	end
end
 
local function keyDown()
	if keyMB then return UIS:IsMouseButtonPressed(keyMB) end
	if keyEnum then return UIS:IsKeyDown(keyEnum) end
	return false
end
 
local function aimActive()
	local kd = keyDown()
	if s_mode == "Hold" then return kd end
	if s_mode == "Toggle" then
		if kd and not lastKeyState then toggleState = not toggleState end
		lastKeyState = kd
		return toggleState
	end
	if s_mode == "Always" then return true end
	return false
end
 
-- ── Lobby ─────────────────────────────────────────────────────────────────────
 
local function isLobby()
	local now = tick()
	if now - lastLobbyTick < 0.5 then return lobbyCache end
	lastLobbyTick = now
	if not _lobbyRef then
		pcall(function()
			_lobbyRef = lp.PlayerGui.MainGui.MainFrame.Lobby.Currency
		end)
	end
	lobbyCache = _lobbyRef and _lobbyRef.Visible or false
	return lobbyCache
end
 
-- ── Ping ──────────────────────────────────────────────────────────────────────
 
local function getPing()
	local now = tick()
	if now - lastPingTick < 1 then return cachedPing end
	lastPingTick = now
	cachedPing = lp:GetNetworkPing() / 1000  -- ✅ Convert to seconds
	return cachedPing
end
 
-- ── Players ───────────────────────────────────────────────────────────────────
 
local function syncPlayers()
	local now = tick()
	if now - lastPlayersTick < 2 then return end
	lastPlayersTick = now
	table.clear(playerCache)
	local all = Players:GetPlayers()
	local n = 0
	for i = 1, #all do
		local p = all[i]
		if p ~= lp then
			n += 1
			playerCache[n] = p
		end
	end
end
 
Players.PlayerAdded:Connect(function() lastPlayersTick = 0 end)
Players.PlayerRemoving:Connect(function(p)
	lastPlayersTick = 0
	local char = p.Character
	if char and hrpCache[char] then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Size = hrpCache[char] end
		hrpCache[char] = nil
	end
	shotAccuracy[p] = nil
end)
 
-- ── Hitbox ────────────────────────────────────────────────────────────────────
 
local function expandHitbox(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp or hrpCache[char] then return end
	hrpCache[char] = hrp.Size
	hrp.Size = HRP_SIZE
end
 
local function restoreHitboxes()
	for char, sz in pairs(hrpCache) do
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Size = sz end
		hrpCache[char] = nil
	end
end
 
-- ── Highlight ─────────────────────────────────────────────────────────────────
 
local function syncHighlight()
	for p, hl in pairs(hlCache) do
		if p ~= targetPlayer then
			hl:Destroy()
			hlCache[p] = nil
		end
	end
	if not s_highlight or not targetPlayer then return end
	local char = targetPlayer.Character
	if not char then return end
	local hl = hlCache[targetPlayer]
	if not hl then
		hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 0, 0)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = char
		hl.Parent = char
		hlCache[targetPlayer] = hl
	else
		hl.Adornee = char
	end
end
 
-- ✅ EXACT METHOD: getTarget function from the example
local function getTarget(origin)
	local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local best, bestDist = nil, math.huge
	local myChar = lp.Character
	for _, p in pairs(Players:GetPlayers()) do
		if p == lp then continue end
		local char = p.Character
		if not char or char == myChar then continue end
		local head = char:FindFirstChild("Head")
		local hum  = char:FindFirstChildOfClass("Humanoid")
		if not head or not hum or hum.Health <= 0 then continue end
		if (origin - head.Position).Magnitude > s_distance then continue end
		local sp, vis = cam:WorldToViewportPoint(head.Position)
		if not vis then continue end
		local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if d < s_fov and d < bestDist then
			bestDist = d
			best = head
			targetPlayer = p
		end
	end
	if not best then targetPlayer = nil end
	return best
end
 
-- ✅ EXACT METHOD: GUI FOV Circle update
local function updateFOVCircle()
	if not Circlefov then return end
	if not s_showFov or not s_active then
		Circlefov.Visible = false
		return
	end
	local center = cam.ViewportSize / 2
	local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local origin = myRoot and myRoot.Position or cam.CFrame.Position
	local target = getTarget(origin)
	
	-- Update FOV circle position
	Circlefov.Position = UDim2.new(0, center.X - s_fov, 0, center.Y - s_fov)
	Circlefov.Size = UDim2.new(0, s_fov * 2, 0, s_fov * 2)
	
	-- Change color based on target
	if target then
		Circlefov.BackgroundColor3 = Color3.fromRGB(255, 50, 50)  -- Red = locked
	else
		Circlefov.BackgroundColor3 = Color3.fromRGB(0, 200, 255)  -- Blue = searching
	end
	Circlefov.Visible = true
end
 
-- ── Util Hooks ────────────────────────────────────────────────────────────────
 
local origRaycast = util.Raycast
util.Raycast = function(self, origin, direction, dist, ...)
	if s_active and not isLobby() and aimActive() then
		local target = getTarget(origin)
 
		if target then
			-- ✅ Per-shot accuracy (not per-frame)
			if not shotAccuracy[targetPlayer] then
				shotAccuracy[targetPlayer] = mrand(100) <= s_accuracy
			end
			
			if shotAccuracy[targetPlayer] then
				local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
				local vel = hrp and hrp.AssemblyLinearVelocity or ZERO3
 
				local tx = target.Position.X
				local ty = target.Position.Y
				local tz = target.Position.Z
 
				-- ✅ Improved prediction with proper ping conversion
				local tdx = tx - origin.X
				local tdy = ty - origin.Y
				local tdz = tz - origin.Z
				local travelDist = msqrt(tdx*tdx + tdy*tdy + tdz*tdz)
				local bulletSpeed = 300
				local travelTime = (travelDist / bulletSpeed) + getPing()
 
				-- predicted position
				local px = tx + vel.X * travelTime
				local py = ty + vel.Y * travelTime
				local pz = tz + vel.Z * travelTime
 
				-- Use world position directly
				local ddx = px - origin.X
				local ddy = py - origin.Y
				local ddz = pz - origin.Z
				local len = msqrt(ddx*ddx + ddy*ddy + ddz*ddz)
 
				if len > 0 then
					local scale = dist / len
					return origRaycast(self, origin, Vector3.new(ddx*scale, ddy*scale, ddz*scale), dist, ...)
				end
			else
				shotAccuracy[targetPlayer] = nil
			end
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
 
-- ── Main Loop ─────────────────────────────────────────────────────────────────
 
RunService:BindToRenderStep("SilentAim", Enum.RenderPriority.Camera.Value + 1, function()
	frameCount += 1
 
	local f6 = frameCount % 6 == 0
	if f6 then
		syncSettings()
		syncKey()
		syncPlayers()
		syncHighlight()
	end
 
	-- ✅ EXACT METHOD: Update FOV circle
	updateFOVCircle()
 
	if not isLobby() and s_active and aimActive() then
		local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local origin = myRoot and myRoot.Position or cam.CFrame.Position
		getTarget(origin)
 
		if targetPlayer and targetPlayer.Character then
			expandHitbox(targetPlayer.Character)
		else
			restoreHitboxes()
		end
	else
		if targetPlayer or toggleState then
			targetPlayer = nil
			targetHead = nil
			toggleState = false
			for p in pairs(shotAccuracy) do
				shotAccuracy[p] = nil
			end
			restoreHitboxes()
		end
	end
end)
