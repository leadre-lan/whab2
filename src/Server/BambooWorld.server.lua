-- BambooWorld.server.lua
-- Place as a Script in ServerScriptService.
-- Procedurally generates the bamboo world at runtime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the config module (stored in ReplicatedStorage by convention)
local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ============================================================
-- Ground & spawn (created via script so XML parsing doesn't matter)
-- ============================================================
local baseplate       = Instance.new("Part")
baseplate.Name        = "Baseplate"
baseplate.Anchored    = true
baseplate.CanCollide  = true
baseplate.Size        = Vector3.new(2048, 20, 2048)
baseplate.Position    = Vector3.new(240, -10, 0)
baseplate.BrickColor  = BrickColor.new("Medium green")
baseplate.Material    = Enum.Material.Grass
baseplate.CastShadow  = false
baseplate.Parent      = workspace

local spawn           = Instance.new("SpawnLocation")
spawn.Name            = "SpawnLocation"
spawn.Anchored        = true
spawn.Size            = Vector3.new(6, 1, 6)
spawn.Position        = Vector3.new(0, 0.5, 0)
spawn.BrickColor      = BrickColor.new("Bright blue")
spawn.Neutral         = true
spawn.AllowTeamChangeOnTouch = false
spawn.Parent          = workspace

-- ============================================================
-- Workspace containers
-- ============================================================
local zonesFolder = Instance.new("Folder")
zonesFolder.Name   = "Zones"
zonesFolder.Parent = workspace

-- ============================================================
-- Helpers
-- ============================================================

-- Simple seeded pseudo-random so the map looks the same on every
-- server restart (not strictly required, but keeps things tidy).
local rng = Random.new(12345)

local function randRange(min, max)
	return rng:NextNumber(min, max)
end

-- Create the flat grass platform for a zone
local function createPlatform(zone)
	local part        = Instance.new("Part")
	part.Name         = zone.name .. "_Platform"
	part.Size         = Vector3.new(100, 2, 100)
	part.Position     = zone.offset + Vector3.new(0, -1, 0)  -- top surface at Y = 0
	part.Anchored     = true
	part.CanCollide   = true
	part.BrickColor   = BrickColor.new("Bright green")
	part.Material     = Enum.Material.Grass
	return part
end

-- Create a BillboardGui sign above the platform
local function createSign(zone, platformPart)
	local signPart        = Instance.new("Part")
	signPart.Name         = "Sign_" .. zone.name
	signPart.Size         = Vector3.new(0.5, 4, 0.5)
	signPart.Position     = zone.offset + Vector3.new(0, 6, -45)
	signPart.Anchored     = true
	signPart.CanCollide   = false
	signPart.BrickColor   = BrickColor.new("Reddish brown")
	signPart.Material     = Enum.Material.Wood

	local billboard           = Instance.new("BillboardGui")
	billboard.Name            = "ZoneSign"
	billboard.Size            = UDim2.new(0, 220, 0, 80)
	billboard.StudsOffset     = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop     = false
	billboard.Parent          = signPart

	local titleLabel              = Instance.new("TextLabel")
	titleLabel.Name               = "Title"
	titleLabel.Size               = UDim2.new(1, 0, 0.6, 0)
	titleLabel.BackgroundColor3   = Color3.fromRGB(30, 80, 30)
	titleLabel.BackgroundTransparency = 0.2
	titleLabel.TextColor3         = Color3.fromRGB(255, 255, 200)
	titleLabel.TextScaled         = true
	titleLabel.Font               = Enum.Font.GothamBold
	titleLabel.Text               = zone.name
	titleLabel.Parent             = billboard

	local reqLabel                = Instance.new("TextLabel")
	reqLabel.Name                 = "Req"
	reqLabel.Size                 = UDim2.new(1, 0, 0.4, 0)
	reqLabel.Position             = UDim2.new(0, 0, 0.6, 0)
	reqLabel.BackgroundColor3     = Color3.fromRGB(20, 50, 20)
	reqLabel.BackgroundTransparency = 0.2
	reqLabel.TextColor3           = Color3.fromRGB(200, 255, 200)
	reqLabel.TextScaled           = true
	reqLabel.Font                 = Enum.Font.Gotham
	reqLabel.Text                 = "Schwertlevel " .. zone.requiredSwordLevel .. " erforderlich"
	reqLabel.Parent               = billboard

	return signPart
end

-- Create a single bamboo stalk as a tall cylinder-ish Part
local function createBambooStalk(bambooType, position, bambooTypeId)
	local part            = Instance.new("Part")
	part.Name             = "Bamboo"
	part.Size             = Vector3.new(bambooType.thickness, bambooType.height, bambooType.thickness)
	-- Bottom of stalk sits on platform surface (Y = 0)
	part.Position         = Vector3.new(position.X, bambooType.height / 2, position.Z)
	part.Anchored         = true
	part.CanCollide       = true
	part.BrickColor       = BrickColor.new(bambooType.brickColorName)
	part.Material         = Enum.Material.SmoothPlastic
	part.CastShadow       = true

	-- CylinderMesh is vertical by default in Roblox (Y-axis aligned)
	local mesh            = Instance.new("SpecialMesh")
	mesh.MeshType         = Enum.MeshType.Cylinder
	mesh.Scale            = Vector3.new(1, 1, 1)
	mesh.Parent           = part

	-- Attributes used by GameManager to identify and track bamboo
	part:SetAttribute("IsBamboo",    true)
	part:SetAttribute("IsDead",      false)
	part:SetAttribute("BambooTypeId", bambooTypeId)

	return part
end

-- ============================================================
-- World generation
-- ============================================================
for zoneIndex, zone in ipairs(Config.ZONES) do
	local zoneFolder       = Instance.new("Folder")
	zoneFolder.Name        = "Zone_" .. zoneIndex
	zoneFolder.Parent      = zonesFolder

	-- Platform
	local platform         = createPlatform(zone)
	platform.Parent        = zoneFolder

	-- Sign post
	local sign             = createSign(zone, platform)
	sign.Parent            = zoneFolder

	-- Bamboo folder
	local bambooFolder     = Instance.new("Folder")
	bambooFolder.Name      = "Bamboo"
	bambooFolder.Parent    = zoneFolder

	local bambooType       = Config.BAMBOO_TYPES[zone.bambooTypeId]
	local halfExtent       = 45  -- scatter radius inside the 100-stud platform

	for i = 1, zone.bambooCount do
		-- Random position within the zone platform (leave a 5-stud border)
		local localX  = randRange(-halfExtent, halfExtent)
		local localZ  = randRange(-halfExtent, halfExtent)
		local worldPos = zone.offset + Vector3.new(localX, 0, localZ)

		local stalk   = createBambooStalk(bambooType, worldPos, zone.bambooTypeId)
		stalk.Parent  = bambooFolder
	end

	print(string.format("[BambooWorld] Zone %d '%s' generated with %d stalks.",
		zoneIndex, zone.name, zone.bambooCount))
end

-- ROJO TEST: sichtbares Schild am Spawn
local testSign = Instance.new("Part")
testSign.Name = "RojoTestSign"
testSign.Size = Vector3.new(12, 4, 0.5)
testSign.Position = Vector3.new(0, 5, -10)
testSign.Anchored = true
testSign.BrickColor = BrickColor.new("Bright red")
testSign.Parent = workspace
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.new(0, 400, 0, 100)
bb.StudsOffset = Vector3.new(0, 3, 0)
bb.Parent = testSign
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1,0,1,0)
lbl.BackgroundTransparency = 1
lbl.Text = "🎋 ROJO SYNC FUNKTIONIERT! 🎋"
lbl.TextColor3 = Color3.fromRGB(255,255,0)
lbl.TextScaled = true
lbl.Font = Enum.Font.GothamBold
lbl.Parent = bb

print("[BambooWorld] World generation complete.")
