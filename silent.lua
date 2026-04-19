local util = require(game:GetService("ReplicatedStorage").Modules.Utility)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
print("localt")
-- hard locals, fastest possible lookup
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local WS = workspace
local UIS = UserInputService
local mrand = math.random
local mhuge = math.huge
local tick = tick
local ipairs = ipairs
local pairs = pairs

local sharedsilent = shared.Silentaim

-- state
local targetPlayer = nil
local targetHead = nil
local toggleState = false
local lastKeyState = false
local frameCount = 0

-- settings (flat locals, no table lookups in hot path)
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

-- camera cache (updated once per frame)
local c_pos = Vector3.zero
local c_vpx = 0
local c_vpy = 0
local c_fovSq = 0
local c_fovR = 0

-- caches
local lobbyCache = false
local lastLobbyTick = 0
local cachedPing = 0
local lastPingTick = 0
local lastSettingsTick = 0
local lastPlayersTick = 0
local playerCache = {}

-- hitbox
local hrpCache = {}
local HRP_SIZE = Vector3.new(6, 6, 6)

-- key cache
local keyMB = nil
local keyEnum = nil
local keyStr = ""

-- pre-alloc rayparams once
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

-- pre-cache enums
local _MB1 = Enum.UserInputType.MouseButton1
local _MB2 = Enum.UserInputType.MouseButton2
local _MB3 = Enum.UserInputType.MouseButton3
local ZERO3 = Vector3.zero

-- fov circle
local Circlefov = sharedsilent.sfovCircle
local fovCirclePos = nil

-- highlight cache
local hlCache = {}

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
    if s_key:sub(1,2) == "MB" then
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

-- ── Lobby Check ───────────────────────────────────────────────────────────────

local _lobbyRef = nil
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

-- ── Ping Cache ────────────────────────────────────────────────────────────────

local function getPing()
    local now = tick()
    if now - lastPingTick < 1 then return cachedPing end
    lastPingTick = now
    cachedPing = lp:GetNetworkPing()
    return cachedPing
end

-- ── Player Cache ──────────────────────────────────────────────────────────────

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
end)

-- ── Camera Cache ──────────────────────────────────────────────────────────────

local function syncCamera()
    local cf = cam.CFrame
    c_pos = cf.Position
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

        -- inline squared distance, zero allocations
        local hx = head.Position.X
        local hy = head.Position.Y
        local hz = head.Position.Z
        local ddx = ox - hx
        local ddy = oy - hy
        local ddz = oz - hz
        if (ddx*ddx + ddy*ddy + ddz*ddz) > s_distSq then continue end

        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        -- screen projection
        local sp, vis = cam:WorldToViewportPoint(head.Position)
        if not vis then continue end

        local sx = sp.X - c_vpx
        local sy = sp.Y - c_vpy
        local dSq = sx*sx + sy*sy

        if dSq >= c_fovSq or dSq >= bestDSq then continue end

        -- wallcheck last (most expensive)
        if s_wallcheck then
            rp.FilterDescendantsInstances = {myChar, char}
            local dirx = hx - c_pos.X
            local diry = hy - c_pos.Y
            local dirz = hz - c_pos.Z
            local res = WS:Raycast(c_pos, Vector3.new(dirx, diry, dirz), rp)
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

-- ── Util Hooks ────────────────────────────────────────────────────────────────

local origRaycast = util.Raycast
util.Raycast = function(self, origin, direction, dist, ...)
    if s_active and not isLobby() and aimActive() then
        local ox = origin.X
        local oy = origin.Y
        local oz = origin.Z
        local target = getTarget(ox, oy, oz)
        if target and mrand(100) <= s_accuracy then
            local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
            local vel = hrp and hrp.AssemblyLinearVelocity or ZERO3
            local ping = getPing()
            local px = target.Position.X + vel.X * ping
            local py = target.Position.Y + vel.Y * ping
            local pz = target.Position.Z + vel.Z * ping
            return origRaycast(self, origin, Vector3.new(px, py, pz), dist, ...)
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

    -- sync camera every frame (cheap, needed for accuracy)
    syncCamera()

    -- throttled syncs
    local f6 = frameCount % 6 == 0
    if f6 then
        syncSettings()
        syncKey()
        syncPlayers()
        syncHighlight()
    end

    drawFOV()

    if not isLobby() and s_active and aimActive() then
        local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local op = myRoot and myRoot.Position or c_pos
        getTarget(op.X, op.Y, op.Z)

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
            restoreHitboxes()
        end
    end
end)
