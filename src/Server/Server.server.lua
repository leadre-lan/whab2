-- Server.server.lua (Script in ServerScriptService)
-- All server-side logic for Bamboo Slasher

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ─── RemoteEvents Setup ───────────────────────────────────────────────────────
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "BambooRemotes"
remotesFolder.Parent = ReplicatedStorage

local UpdateData = Instance.new("RemoteEvent")
UpdateData.Name = "UpdateData"
UpdateData.Parent = remotesFolder

local BuyUpgrade = Instance.new("RemoteEvent")
BuyUpgrade.Name = "BuyUpgrade"
BuyUpgrade.Parent = remotesFolder

-- ─── World Setup ──────────────────────────────────────────────────────────────
workspace.Terrain:Clear()

local existingBase = workspace:FindFirstChild("Baseplate")
if existingBase then
	existingBase:Destroy()
end

local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = Vector3.new(2048, 20, 2048)
baseplate.Position = Vector3.new(260, -10, 0)
baseplate.Material = Enum.Material.Grass
baseplate.Color = Color3.fromRGB(106, 127, 63)
baseplate.Anchored = true
baseplate.CanCollide = true
baseplate.Parent = workspace

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "SpawnLocation"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = Vector3.new(0, 0.5, 0)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Color = Color3.fromRGB(163, 162, 165)
spawnLocation.Parent = workspace

-- ─── DataStore ────────────────────────────────────────────────────────────────
local dataStore = DataStoreService:GetDataStore("BambooSlasher_v2")
local playerData = {}

local function defaultData()
	return {
		coins        = 0,
		swordLevel   = 1,
		totalChopped = 0,
	}
end

local function mergeWithDefault(data)
	local def = defaultData()
	if type(data) ~= "table" then return def end
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

local function loadData(player)
	local success, result = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)
	if success and result then
		playerData[player] = mergeWithDefault(result)
	else
		playerData[player] = defaultData()
	end
end

local function saveData(player)
	local data = playerData[player]
	if not data then return end
	pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, data)
	end)
end

local function sendUpdate(player)
	local data = playerData[player]
	if data then
		UpdateData:FireClient(player, data)
	end
end

-- ─── Player Events ────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	loadData(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		sendUpdate(player)
	end)
	if player.Character then
		task.wait(0.5)
		sendUpdate(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
end)

-- Auto-save every 60 seconds
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- ─── BuyUpgrade Handler ───────────────────────────────────────────────────────
BuyUpgrade.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local nextLevel = data.swordLevel + 1
	local nextSword = Config.SWORDS[nextLevel]
	if not nextSword then return end -- already max level

	if data.coins < nextSword.cost then return end -- can't afford

	data.coins     = data.coins - nextSword.cost
	data.swordLevel = nextLevel
	sendUpdate(player)
end)

-- ─── World Generation ─────────────────────────────────────────────────────────
local rng             = Random.new(42)
local bambooHealth    = {}   -- [part] = currentHealth number
local playerCooldowns = {}   -- ["userId_partInstance"] = lastSwingTime (os.clock)

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = workspace

local function respawnBamboo(part, bambooType)
	task.wait(bambooType.respawnTime)
	if not part or not part.Parent then return end
	bambooHealth[part] = bambooType.health
	part:SetAttribute("IsDead", false)
	part.Color = bambooType.color
	part.Transparency = 0
	part.CanCollide = true
end

for _, zone in ipairs(Config.ZONES) do
	local bambooType = Config.BAMBOO_TYPES[zone.bambooTypeId]
	local zoneX      = zone.offsetX

	-- Zone folder
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.name
	zoneFolder.Parent = zonesFolder

	-- Grass platform (110x2x110)
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(110, 2, 110)
	platform.Position = Vector3.new(zoneX, -1, 0)
	platform.Material = Enum.Material.Grass
	platform.Color = Color3.fromRGB(106, 127, 63)
	platform.Anchored = true
	platform.CanCollide = true
	platform.Parent = zoneFolder

	-- Zone sign post
	local signPart = Instance.new("Part")
	signPart.Name = "ZoneSign"
	signPart.Size = Vector3.new(0.2, 5, 0.2)
	signPart.Position = Vector3.new(zoneX - 50, 2.5, 0)
	signPart.Material = Enum.Material.Wood
	signPart.Color = Color3.fromRGB(106, 74, 40)
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.Parent = zoneFolder

	-- BillboardGui on sign post
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 240, 0, 90)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = signPart

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = zone.name
	titleLabel.Parent = billboard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(1, 0, 0.45, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.55, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	levelLabel.TextStrokeTransparency = 0
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Text = "⚔ Level " .. zone.requiredLevel .. " erforderlich"
	levelLabel.Parent = billboard

	-- Spawn bamboo stalks
	for i = 1, zone.count do
		local rx = rng:NextNumber(-48, 48)
		local rz = rng:NextNumber(-48, 48)
		local h  = bambooType.height
		local th = bambooType.thickness

		local part = Instance.new("Part")
		part.Name = "Bamboo"
		-- Upright block: X=thickness, Y=height, Z=thickness
		part.Size = Vector3.new(th, h, th)
		-- Bottom of bamboo sits on platform surface (platform top is at y=0)
		part.Position = Vector3.new(zoneX + rx, h / 2, rz)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = bambooType.color
		part.Anchored = true
		part.CanCollide = true
		part:SetAttribute("IsBamboo", true)
		part:SetAttribute("IsDead", false)
		part:SetAttribute("BambooTypeId", zone.bambooTypeId)
		part.Parent = zoneFolder

		bambooHealth[part] = bambooType.health

		-- ClickDetector so client doesn't need raycasts
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = part

		-- Capture loop variables explicitly
		local capturedPart       = part
		local capturedBambooType = bambooType
		local capturedZone       = zone

		clickDetector.MouseClick:Connect(function(player)
			local data = playerData[player]
			if not data then return end

			-- Must be alive
			if capturedPart:GetAttribute("IsDead") then return end

			-- Zone level requirement
			if data.swordLevel < capturedZone.requiredLevel then return end

			-- Per-player per-bamboo cooldown
			local cdKey = tostring(player.UserId) .. "_" .. tostring(capturedPart)
			local now   = os.clock()
			local last  = playerCooldowns[cdKey]
			if last and (now - last) < Config.SWING_DELAY then return end
			playerCooldowns[cdKey] = now

			-- Deal damage
			local sword  = Config.SWORDS[data.swordLevel]
			local damage = sword and sword.damage or 1
			bambooHealth[capturedPart] = bambooHealth[capturedPart] - damage

			-- Lerp color toward orange as health drops
			local maxHealth  = capturedBambooType.health
			local healthFrac = math.max(0, bambooHealth[capturedPart]) / maxHealth
			capturedPart.Color = capturedBambooType.color:Lerp(Color3.fromRGB(255, 80, 0), 1 - healthFrac)

			-- Check if destroyed
			if bambooHealth[capturedPart] <= 0 then
				capturedPart:SetAttribute("IsDead", true)
				capturedPart.Transparency = 1
				capturedPart.CanCollide   = false

				data.coins        = data.coins + capturedBambooType.coins
				data.totalChopped = data.totalChopped + 1
				sendUpdate(player)

				-- Schedule respawn
				task.spawn(respawnBamboo, capturedPart, capturedBambooType)
			end
		end)
	end
end
