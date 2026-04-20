--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local util = require(game:GetService("ReplicatedStorage").Modules.Utility)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer
local MAX_DIST = 200
local FOV = 150
local circle = Drawing.new("Circle")
circle.Thickness = 1.5
circle.Filled    = false
circle.NumSides  = 64
circle.Visible   = true

-- ✅ NEW: Distance display
local distanceText = Drawing.new("Text")
distanceText.Visible = true
distanceText.Size = 18
distanceText.Color = Color3.fromRGB(255, 255, 255)
distanceText.OutlineColor = Color3.fromRGB(0, 0, 0)

-- ✅ FIX: Tracking with GUI FOV from shared
local Circlefov = nil
local fovCirclePos = nil

local function getTarget(origin)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    local myChar = LP.Character
    for _, p in pairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char or char == myChar then continue end
        local head = char:FindFirstChild("Head")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then continue end
        if (origin - head.Position).Magnitude > MAX_DIST then continue end
        local sp, vis = Camera:WorldToViewportPoint(head.Position)
        if not vis then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < FOV and d < bestDist then
            bestDist = d
            best = head
        end
    end
    return best
end

-- ✅ NEW: Get distance from myRoot
local function getDistance()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return 0 end
    local target = getTarget(myRoot.Position)
    if not target then return 0 end
    return math.floor((target.Position - myRoot.Position).Magnitude)
end

-- ✅ NEW: Draw GUI FOV (from loader)
local function drawFOV()
	if not Circlefov then 
		pcall(function()
			Circlefov = shared.Aim.fovCircle
		end)
	end
	if not Circlefov then return end
	
	local mousePos = (LP:GetMouse() and LP:GetMouse().Hit.Position) or Camera.CFrame.Position
	fovCirclePos = fovCirclePos and fovCirclePos:Lerp(mousePos, 0.28) or mousePos
	local r = FOV
	Circlefov.Position = UDim2.new(0, Camera.ViewportSize.X / 2 - r, 0, Camera.ViewportSize.Y / 2 - r)
	Circlefov.Size = UDim2.new(0, r + r, 0, r + r)
	Circlefov.Visible = true
end

RunService.RenderStepped:Connect(function()
    local center = Camera.ViewportSize / 2
    circle.Position = Vector2.new(center.X, center.Y)
    circle.Radius   = FOV
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local target = getTarget(myRoot and myRoot.Position or Camera.CFrame.Position)
    circle.Color = target and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 200, 255)
    
    -- ✅ NEW: Update distance display
    local distance = getDistance()
    distanceText.Position = Vector2.new(center.X - 50, center.Y + 100)
    distanceText.Text = "Distance: " .. distance .. " studs"
    
    -- ✅ NEW: Update GUI FOV circle
    drawFOV()
end)

local orig = util.Raycast
util.Raycast = function(self, origin, direction, distance, ...)
    local target = getTarget(origin)
    if target then
        -- ✅ FIX: No prediction - use exact head position
        return orig(self, origin, target.Position, distance, ...)
    end
    return orig(self, origin, direction, distance, ...)
end

local orig = util.PlayParticles
util.PlayParticles = function(self, obj)
    if typeof(obj) == "Instance" then
        local n = obj.Name:lower()
        if n:find("flash") or n:find("smoke") or n:find("blind") then return end
    end
    return orig(self, obj)
end
