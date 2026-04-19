local util = require(game:GetService("ReplicatedStorage").Modules.Utility)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
 print("heyyyy")
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
local s_distSq = 10000
local s_fov = 80
local s_showFov = true
local s_accuracy = 100
local s_mode = "Hold"
local s_key = "MB2"
local s_highlight = false
local s_bodychance = 98
local s_headchance = 67
 
local c_pos = Vector3.zero
local c_vpx = 0
local c_vpy = 0
local c_fovSq = 0
local c_fovR = 0
 
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
 
-- ✅ FIX #1: Per-shot accuracy tracking (not per-frame)
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
		s_distSq     = d * d
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
	cachedPing = lp:GetNetworkPing()
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
	-- ✅ FIX #1: Clear shot accuracy for removed player
	shotAccuracy[p] = nil
end)
 
-- ── Camera ────────────────────────────────────────────────────────────────────
 
local function syncCamera()
	c_pos = cam.CFrame.Position
	local vp = cam.ViewportSize
	c_vpx = vp.X * 0.5
	c_vpy = vp.Y * 0.5
	c_fovR = (s_fov / 180) * c_vpy
	c_fovSq = c_fovR * c_fovR
end
 
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
 
-- ── Target Finder ─────────────────────────────────────────────────────────────
 
local function getTarget(ox, oy, oz)
	local best, bestDSq = nil, mhuge
	local myChar = lp.Character
	local n = #playerCache
 
	for i = 1, n do
		local p = playerCache[i]
		local char = p.Character
		if not char or char == myChar then continue end
		if s_teamcheck and p.Team == lp.Team then continue end
 
		local head = char:FindFirstChild("Head")
		if not head then continue end
 
		local hx = head.Position.X
		local hy = head.Position.Y
		local hz = head.Position.Z
 
		-- distance from camera
		local ddx = c_pos.X - hx
		local ddy = c_pos.Y - hy
		local ddz = c_pos.Z - hz
		if (ddx*ddx + ddy*ddy + ddz*ddz) > s_distSq then continue end
 
		local hum = char:FindFirstChild("Humanoid")
		if not hum or hum.Health <= 0 then continue end
 
		local sp, vis = cam:WorldToViewportPoint(head.Position)
		if not vis or sp.Z <= 0 then continue end
 
		local sx = sp.X - c_vpx
		local sy = sp.Y - c_vpy
		local dSq = sx*sx + sy*sy
 
		if dSq >= c_fovSq or dSq >= bestDSq then continue end
 
		if s_wallcheck then
			rp.FilterDescendantsInstances = {myChar, char}
			local res = WS:Raycast(c_pos, Vector3.new(hx - c_pos.X, hy - c_pos.Y, hz - c_pos.Z), rp)
			if res then continue end
		end
 
		bestDSq = dSq
		best = head
		targetPlayer = p
	end
 
	if not best then targetPlayer = nil end
	targetHead = best
	return best
end
 
-- ── FOV Circle ────────────────────────────────────────────────────────────────
 
local function drawFOV()
	if not Circlefov then return end
	if not s_showFov or not s_active then
		Circlefov.Visible = false
		return
	end
	local mp = UIS:GetMouseLocation()
	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mp, 0.28) or mp
	local r = c_fovR
	Circlefov.Position = UDim2.new(0, fovCirclePos.X - r, 0, fovCirclePos.Y - r)
	Circlefov.Size = UDim2.new(0, r + r, 0, r + r)
	Circlefov.Visible = true
end
 
-- ✅ FIX #2: Improved accuracy with world position
-- ── Util Hooks ────────────────────────────────────────────────────────────────
 
local origRaycast = util.Raycast
util.Raycast = function(self, origin, direction, dist, ...)
	if s_active and not isLobby() and aimActive() then
		local ox = origin.X
		local oy = origin.Y
		local oz = origin.Z
		local target = getTarget(ox, oy, oz)
 
		if target then
			-- ✅ FIX #2: Per-shot accuracy (not per-frame)
			if not shotAccuracy[targetPlayer] then
				shotAccuracy[targetPlayer] = mrand(100) <= s_accuracy
			end
			
			if shotAccuracy[targetPlayer] then
				local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
				local vel = hrp and hrp.AssemblyLinearVelocity or ZERO3
 
				local tx = target.Position.X
				local ty = target.Position.Y
				local tz = target.Position.Z
 
				-- travel time = bullet travel + ping (in milliseconds, convert to seconds)
				local tdx = tx - ox
				local tdy = ty - oy
				local tdz = tz - oz
				local travelDist = msqrt(tdx*tdx + tdy*tdy + tdz*tdz)
				local bulletSpeed = 300
				local pingSeconds = getPing() / 1000  -- ✅ FIX: Convert ms to seconds
				local travelTime = (travelDist / bulletSpeed) + pingSeconds
 
				-- predicted position with velocity
				local px = tx + vel.X * travelTime
				local py = ty + vel.Y * travelTime
				local pz = tz + vel.Z * travelTime
 
				-- ✅ FIX #2: Use world position directly (RIVALS)
				-- proper direction vector
				local ddx = px - ox
				local ddy = py - oy
				local ddz = pz - oz
				local len = msqrt(ddx*ddx + ddy*ddy + ddz*ddz)
 
				if len > 0 then
					local scale = dist / len
					-- ✅ FIX #2: Return prediction using world position
					return origRaycast(self, origin, Vector3.new(ddx*scale, ddy*scale, ddz*scale), dist, ...)
				end
			else
				-- ✅ FIX #2: Clear shot accuracy after miss
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
 
	syncCamera()
 
	local f6 = frameCount % 6 == 0
	if f6 then
		syncSettings()
		syncKey()
		syncPlayers()
		syncHighlight()
	end
 
	drawFOV()
 
	if not isLobby() and s_active and aimActive() then
		getTarget(c_pos.X, c_pos.Y, c_pos.Z)
 
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
			-- ✅ FIX #2: Clear shot accuracy on deactivate
			for p in pairs(shotAccuracy) do
				shotAccuracy[p] = nil
			end
			restoreHitboxes()
		end
	end
end)
