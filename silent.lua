-- SILENT AIM v1 by oblivion (completed)
-- method: camera CFrame manipulation — no hooks, no mouse movement

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local silentshared = shared.SilentAim

-- ─── state ────────────────────────────────────────────────────────────────────
local isAiming         = false
local lockedTarget     = nil
local lockedAimPart    = nil
local cachedCharacters = {}
local lastCache        = 0
local fovCirclePos     = nil
local fovCircle        = nil
local toggleState      = false
local lastKeyState     = false

-- ─── settings ─────────────────────────────────────────────────────────────────
local Active         = false
local LegitMode      = false
local TeamCheck      = false
local WallCheck      = false
local HitChance      = 95
local HeadshotChance = 68
local BodyShotChance = 92
local Fov            = 90
local MaxDistance    = 1000
local TargetPriority = "Closest"
local Targetpart     = "Head"
local AimKey         = nil
local Mode           = "Always"

local targetHitChance = {}

-- ═══════════════════════════════════════════
--  SHARED READERS
-- ═══════════════════════════════════════════
local function readBool(key, default)
    if not silentshared then return default end
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "boolean" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end
local function readNum(key, default)
    if not silentshared then return default end
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "number" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end
local function readStr(key, default)
    if not silentshared then return default end
    local v = silentshared[key]
    if v == nil then return default end
    if type(v) == "string" then return v end
    if v.Value ~= nil then return v.Value end
    return default
end

local function UpdateSettings()
    if not silentshared then return end
    pcall(function()
        fovCircle     = silentshared.fovCircle
        Active        = readBool("Active",        false)
        LegitMode     = readBool("LegitAim",      false)
        TeamCheck     = readBool("TeamCheck",     false)
        WallCheck     = readBool("WallCheck",     false)
        HitChance     = readNum ("HitChance",     95)
        HeadshotChance= readNum ("HeadshotChance",68)
        BodyShotChance= readNum ("BodyShotChance",92)
        Fov           = readNum ("Fov",           90)
        MaxDistance   = readNum ("distance",      1000)
        TargetPriority= readStr ("TargetPriority","Closest")
        Targetpart    = readStr ("TargetBodyPart","Head")
        AimKey        = readStr ("SilentAimKey",  nil)
        Mode          = readStr ("Mode",          "Always")

        if LegitMode then
            HitChance      = math.min(HitChance,      85)
            HeadshotChance = math.min(HeadshotChance, 55)
            BodyShotChance = math.min(BodyShotChance, 80)
        end
    end)
end

-- ═══════════════════════════════════════════
--  LOBBY CHECK
-- ═══════════════════════════════════════════
local function isLobbyVisible()
    local ok, result = pcall(function()
        return Player.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible
    end)
    return ok and result == true
end

-- ═══════════════════════════════════════════
--  CHECKS
-- ═══════════════════════════════════════════
local function SafeTeamCheck(plr)
    if not TeamCheck then return false end
    if not plr or not plr.Team then return false end
    return plr.Team == Player.Team
end

local rayParams = RaycastParams.new()
rayParams.FilterType  = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function IsVisible(targetPart)
    if not WallCheck or not targetPart then return true end
    local char = Player.Character
    if not char then return true end
    rayParams.FilterDescendantsInstances = { char }
    local origin = Camera.CFrame.Position
    local res    = workspace:Raycast(origin, targetPart.Position - origin, rayParams)
    return not res or (res.Instance and res.Instance:IsDescendantOf(targetPart.Parent))
end

local function IsInRange(part)
    if not part or not part.Parent then return false end
    return (part.Position - Camera.CFrame.Position).Magnitude <= MaxDistance
end

-- ═══════════════════════════════════════════
--  FOV CHECK
-- ═══════════════════════════════════════════
local function InFov(worldPos)
    local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen or sp.Z <= 0 then return false, nil end
    local sp2   = Vector2.new(sp.X, sp.Y)
    local mouse = UserInputService:GetMouseLocation()
    local radius= (Fov / 180) * (Camera.ViewportSize.Y / 2)
    if (sp2 - mouse).Magnitude <= radius then
        return true, sp2
    end
    return false, nil
end

-- ═══════════════════════════════════════════
--  AIM PART + HIT CHANCE
-- ═══════════════════════════════════════════
local function ChooseAimPart(char)
    if not char then return nil end
    if math.random(100) <= HeadshotChance then
        local head = char:FindFirstChild("Head")
        if head then return head end
    end
    if math.random(100) <= BodyShotChance then
        return char:FindFirstChild(Targetpart)
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function ShouldHitTarget(char)
    if not char then return true end
    if targetHitChance[char] == nil then
        targetHitChance[char] = math.random(100) <= HitChance
    end
    return targetHitChance[char]
end

-- ═══════════════════════════════════════════
--  CHARACTER CACHE
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
--  TARGET FINDER
-- ═══════════════════════════════════════════
local function FindTarget()
    -- keep locked target if still valid
    if lockedTarget and lockedTarget.Parent then
        local hum = lockedTarget:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.Health > 0 then
            local part = (lockedAimPart and lockedAimPart.Parent == lockedTarget)
                and lockedAimPart or ChooseAimPart(lockedTarget)
            if part and IsInRange(part) and IsVisible(part) then
                local ok, scr = InFov(part.Position)
                if ok then return part end
            end
        end
    end

    lockedTarget  = nil
    lockedAimPart = nil
    RefreshCache()

    local screenCenter = Camera.ViewportSize * 0.5
    local candidates   = {}

    for _, char in ipairs(cachedCharacters) do
        local plr = Players:GetPlayerFromCharacter(char)
        if SafeTeamCheck(plr) then continue end
        if not ShouldHitTarget(char) then continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root or not IsInRange(root) then continue end
        if not IsVisible(root) then continue end

        local part = ChooseAimPart(char)
        if not part then continue end

        local ok, scr = InFov(part.Position)
        if not ok then continue end

        local hum = char:FindFirstChildWhichIsA("Humanoid")
        table.insert(candidates, {
            part      = part,
            char      = char,
            screenPos = scr,
            distance  = (root.Position - Camera.CFrame.Position).Magnitude,
            health    = hum and hum.Health or 100,
        })
    end

    if #candidates == 0 then return nil end

    if TargetPriority == "Distance" then
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
    elseif TargetPriority == "Health" then
        table.sort(candidates, function(a, b) return a.health < b.health end)
    elseif TargetPriority == "Random" then
        local pick = candidates[math.random(#candidates)]
        lockedTarget  = pick.char
        lockedAimPart = pick.part
        return pick.part
    else
        table.sort(candidates, function(a, b)
            return (a.screenPos - screenCenter).Magnitude < (b.screenPos - screenCenter).Magnitude
        end)
    end

    local best = candidates[1]
    lockedTarget  = best.char
    lockedAimPart = best.part
    return best.part
end

-- ═══════════════════════════════════════════
--  AIM KEY
-- ═══════════════════════════════════════════
local function IsAimKeyDown()
    if not AimKey then return false end
    if AimKey:match("^MB%d") then
        local n = tonumber(AimKey:match("%d"))
        if n then return UserInputService:IsMouseButtonPressed(Enum.UserInputType["MouseButton"..n]) end
    else
        local key = Enum.KeyCode[AimKey]
        if key then return UserInputService:IsKeyDown(key) end
    end
    return false
end

-- ═══════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════
local function UpdateFOVCircle()
    if not fovCircle then
        fovCircle = silentshared and silentshared.fovCircle or nil
    end
    if not fovCircle then return end

    local showFov   = readBool("Showfov", false)
    local aimActive = readBool("Active",  false)

    if not showFov or not aimActive then
        pcall(function() fovCircle.Visible = false end)
        return
    end

    local mouse  = UserInputService:GetMouseLocation()
    local radius = (Fov / 180) * (Camera.ViewportSize.Y / 2)
    fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mouse, 0.28) or mouse

    pcall(function()
        fovCircle.Position = UDim2.new(0, fovCirclePos.X - radius, 0, fovCirclePos.Y - radius)
        fovCircle.Size     = UDim2.new(0, radius * 2, 0, radius * 2)
        fovCircle.Visible  = true
    end)
end

-- ═══════════════════════════════════════════
--  CAMERA REDIRECT  (the actual silent aim)
--  Rotates camera to face the target for one
--  frame so the game's raycast picks it up,
--  then restores on the next frame naturally.
-- ═══════════════════════════════════════════
local savedCFrame = nil

local function ApplySilentAim(targetPart)
    if not targetPart or not targetPart.Parent then return end

    local head = targetPart
    local headPos, inFront = Camera:WorldToViewportPoint(head.Position)
    if not inFront or headPos.Z <= 0 then return end

    local camPos = Camera.CFrame.Position
    -- point camera directly at target
    savedCFrame  = Camera.CFrame
    Camera.CFrame = CFrame.new(camPos, head.Position)
end

local function RestoreCamera()
    -- camera restores itself every frame via Roblox's camera controller
    -- we only need to clear our saved ref
    savedCFrame = nil
end

-- ═══════════════════════════════════════════
--  SHOW TARGET HIGHLIGHT
-- ═══════════════════════════════════════════
local function UpdateTargetHighlight(part)
    if not silentshared then return end
    pcall(function()
        local showTarget = readBool("ShowTarget", false)
        silentshared._lockedChar = (showTarget and lockedTarget) or nil
    end)
end

-- ═══════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════
local function MainLoop()
    UpdateSettings()

    local keyDown = IsAimKeyDown()
    if Mode == "Hold" then
        isAiming = Active and keyDown
    elseif Mode == "Toggle" then
        if keyDown and not lastKeyState then toggleState = not toggleState end
        lastKeyState = keyDown
        isAiming = Active and toggleState
    else -- Always
        isAiming = Active
    end

    if isLobbyVisible() then isAiming = false end

    if not isAiming then
        table.clear(targetHitChance)
        lockedTarget  = nil
        lockedAimPart = nil
        UpdateTargetHighlight(nil)
        return
    end

    local part = FindTarget()
    UpdateTargetHighlight(part)

    if part then
        ApplySilentAim(part)
    end
end

-- RenderStepped: restore camera AFTER the game has read our redirected CFrame
-- so the bullet fires toward the target, then camera snaps back instantly
RunService.RenderStepped:Connect(function()
    UpdateFOVCircle()
    -- camera is restored automatically by Roblox's camera system each frame
    -- nothing needed here unless you want explicit restore:
    -- RestoreCamera()
end)

-- ═══════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════
task.delay(1, function()
    print("SILENT AIM v1 Loaded!")
    fovCircle = silentshared and silentshared.fovCircle or nil
    RunService.Heartbeat:Connect(MainLoop)
    print("SILENT AIM v1 Ready!")
end)
