-- PlayerController.client.lua
-- Place as a LocalScript in StarterPlayer > StarterPlayerScripts.
-- Manages the sword Tool, swing raycasting, chop firing, and
-- local cooldown enforcement.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

-- ============================================================
-- Wait for shared resources
-- ============================================================
local Config    = require(ReplicatedStorage:WaitForChild("Config"))
local remotes   = ReplicatedStorage:WaitForChild("BambooRemotes")
local chopEvent = remotes:WaitForChild("ChopBamboo")
local updateEvent = remotes:WaitForChild("UpdateData")

local player    = Players.LocalPlayer
-- Wait for the character; retry until it exists
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- Local state (updated by UpdateData from server)
-- ============================================================
local localData = {
	coins        = 0,
	swordLevel   = 1,
	totalChopped = 0,
}

-- ============================================================
-- Build a Sword Tool and insert it into the player's Backpack
-- ============================================================
local function buildSword(swordLevel)
	local swordConfig = Config.SWORDS[swordLevel] or Config.SWORDS[1]

	local tool       = Instance.new("Tool")
	tool.Name        = "Sword"
	tool.ToolTip     = swordConfig.name
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	-- Handle (the visible blade part)
	local handle           = Instance.new("Part")
	handle.Name            = "Handle"
	handle.Size            = Vector3.new(0.2, 2.5, 0.1)
	handle.BrickColor      = BrickColor.new("Bright yellow")
	handle.Material        = Enum.Material.SmoothPlastic
	handle.CanCollide      = false
	handle.Parent          = tool

	return tool
end

-- ============================================================
-- Swing cooldown
-- ============================================================
local lastSwingTime = 0

local function canSwing()
	local swordConfig  = Config.SWORDS[localData.swordLevel] or Config.SWORDS[1]
	local delay        = swordConfig.swingDelay
	return (tick() - lastSwingTime) >= delay
end

-- ============================================================
-- Raycast: find bamboo within reach
-- Max reach = 15 studs from HumanoidRootPart.
-- We cast in the camera look direction so the player swings
-- toward wherever they are looking.
-- ============================================================
local MAX_REACH = 20

local function findBamboo()
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local origin = root.Position

	-- Find closest bamboo within reach using distance search
	local zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder then return nil end

	local closest     = nil
	local closestDist = MAX_REACH

	for _, zoneFolder in ipairs(zonesFolder:GetChildren()) do
		local bambooFolder = zoneFolder:FindFirstChild("Bamboo")
		if bambooFolder then
			for _, stalk in ipairs(bambooFolder:GetChildren()) do
				if stalk:IsA("BasePart")
					and stalk:GetAttribute("IsBamboo")
					and not stalk:GetAttribute("IsDead")
				then
					local dist = (Vector3.new(stalk.Position.X, origin.Y, stalk.Position.Z) - origin).Magnitude
					if dist < closestDist then
						closestDist = dist
						closest     = stalk
					end
				end
			end
		end
	end

	return closest
end

-- ============================================================
-- Swing animation twitch (purely visual, client-side)
-- ============================================================
local function playSwingTween(tool)
	-- Simple: briefly change handle color then restore
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	local original = handle.BrickColor
	handle.BrickColor = BrickColor.new("Bright orange")
	task.delay(0.08, function()
		if handle and handle.Parent then
			handle.BrickColor = original
		end
	end)
end

-- ============================================================
-- Tool wiring – called every time we (re)create the tool
-- ============================================================
local currentTool = nil

local function wireTool(tool)
	currentTool = tool

	tool.Activated:Connect(function()
		if not canSwing() then return end

		lastSwingTime = tick()
		playSwingTween(tool)

		local bambooPart = findBamboo()
		if bambooPart then
			chopEvent:FireServer(bambooPart)
		end
	end)
end

-- ============================================================
-- Equip the sword on spawn (and after respawn)
-- ============================================================
local function equipSword()
	-- Remove any existing sword tools from the backpack/character first
	for _, item in ipairs(player.Backpack:GetChildren()) do
		if item:IsA("Tool") and item.Name == "Sword" then
			item:Destroy()
		end
	end
	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") and item.Name == "Sword" then
				item:Destroy()
			end
		end
	end

	local sword = buildSword(localData.swordLevel)
	wireTool(sword)
	sword.Parent = player.Backpack
end

-- ============================================================
-- UpdateData listener
-- Updates local state, refreshes sword name/stats
-- ============================================================
updateEvent.OnClientEvent:Connect(function(data)
	local prevLevel      = localData.swordLevel
	localData.coins        = data.coins
	localData.swordLevel   = data.swordLevel
	localData.totalChopped = data.totalChopped

	-- Update displayed tool name if the tool is in use
	local swordConfig = Config.SWORDS[localData.swordLevel] or Config.SWORDS[1]

	if currentTool then
		currentTool.ToolTip = swordConfig.name
	end

	-- If sword level changed, rebuild the tool so damage/delay update
	if data.swordLevel ~= prevLevel then
		equipSword()
	end
end)

-- ============================================================
-- Character respawn: re-equip sword
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid  = newChar:WaitForChild("Humanoid")
	rootPart  = newChar:WaitForChild("HumanoidRootPart")
	-- Give server a moment to fire UpdateData on CharacterAdded
	task.wait(0.6)
	equipSword()
end)

-- ============================================================
-- Initial equip (may run before CharacterAdded fires UpdateData)
-- ============================================================
task.wait(0.2)
equipSword()
