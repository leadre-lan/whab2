-- GameManager.server.lua
-- Place as a Script in ServerScriptService.
-- Handles all game logic: data persistence, chopping, upgrades.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

-- Wait for Config and Remotes
local Config      = require(ReplicatedStorage:WaitForChild("Config"))
local remotes     = ReplicatedStorage:WaitForChild("BambooRemotes")
local chopEvent   = remotes:WaitForChild("ChopBamboo")
local upgradeEvent= remotes:WaitForChild("BuyUpgrade")
local updateEvent = remotes:WaitForChild("UpdateData")

-- DataStore
local playerDataStore = DataStoreService:GetDataStore("BambooSlasher_v1")

-- ============================================================
-- In-memory state
-- ============================================================
-- playerData[player] = { coins, swordLevel, totalChopped }
local playerData = {}

-- bambooHealth[part] = current health (number)
-- Populated lazily when a bamboo is first hit.
local bambooHealth = {}

-- ============================================================
-- Default data for a new player
-- ============================================================
local function defaultData()
	return {
		coins        = 0,
		swordLevel   = 1,
		totalChopped = 0,
	}
end

-- ============================================================
-- DataStore helpers
-- ============================================================
local function loadData(player)
	local key  = "player_" .. player.UserId
	local success, result = pcall(function()
		return playerDataStore:GetAsync(key)
	end)
	if success and result then
		-- Ensure all fields exist (handles old saves missing new keys)
		local data = defaultData()
		for k, v in pairs(result) do
			data[k] = v
		end
		return data
	else
		if not success then
			warn("[GameManager] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		end
		return defaultData()
	end
end

local function saveData(player)
	local data = playerData[player]
	if not data then return end
	local key  = "player_" .. player.UserId
	local success, err = pcall(function()
		playerDataStore:SetAsync(key, {
			coins        = data.coins,
			swordLevel   = data.swordLevel,
			totalChopped = data.totalChopped,
		})
	end)
	if not success then
		warn("[GameManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- ============================================================
-- Fire UpdateData to a single client
-- ============================================================
local function sendUpdate(player)
	local data = playerData[player]
	if not data then return end
	updateEvent:FireClient(player, {
		coins        = data.coins,
		swordLevel   = data.swordLevel,
		totalChopped = data.totalChopped,
	})
end

-- ============================================================
-- Color helpers for hit feedback
-- ============================================================
local COLOR_HEALTHY  = nil   -- set per-bamboo type at hit time
local COLOR_DEAD     = Color3.fromRGB(80, 50, 20)

-- Lerp a bamboo part's color based on health fraction
local function updateBambooColor(part, bambooType, healthFraction)
	local baseColor   = BrickColor.new(bambooType.brickColorName).Color
	-- Fade toward brown/dark as health drops
	local damagedColor = Color3.fromRGB(160, 100, 40)
	part.Color = baseColor:Lerp(damagedColor, 1 - healthFraction)
end

-- ============================================================
-- Bamboo respawn
-- ============================================================
local function respawnBamboo(part, bambooType)
	task.delay(bambooType.respawnTime, function()
		if not part or not part.Parent then return end
		local maxHealth     = bambooType.health
		bambooHealth[part]  = maxHealth
		part.Transparency   = 0
		part.CanCollide     = true
		part:SetAttribute("IsDead", false)
		part.Color          = BrickColor.new(bambooType.brickColorName).Color
	end)
end

-- ============================================================
-- ChopBamboo handler
-- ============================================================
chopEvent.OnServerEvent:Connect(function(player, bambooPart)
	-- Basic validation
	if typeof(bambooPart) ~= "Instance" then return end
	if not bambooPart:IsA("BasePart") then return end
	if not bambooPart:GetAttribute("IsBamboo") then return end
	if bambooPart:GetAttribute("IsDead") then return end

	local data = playerData[player]
	if not data then return end

	local bambooTypeId = bambooPart:GetAttribute("BambooTypeId")
	local bambooType   = Config.BAMBOO_TYPES[bambooTypeId]
	if not bambooType then return end

	-- Check player sword level
	if data.swordLevel < bambooType.requiredSwordLevel then
		-- Silently reject; client should show a warning
		return
	end

	-- Distance sanity check (anti-exploit): must be within 25 studs
	local character = player.Character
	if not character then return end
	local rootPart  = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if (rootPart.Position - bambooPart.Position).Magnitude > 25 then return end

	-- Lazy-init health
	if not bambooHealth[bambooPart] then
		bambooHealth[bambooPart] = bambooType.health
	end

	-- Apply damage
	local sword       = Config.SWORDS[data.swordLevel]
	local damage      = sword and sword.damage or 1
	bambooHealth[bambooPart] = bambooHealth[bambooPart] - damage

	-- Color feedback
	local healthFraction = math.clamp(bambooHealth[bambooPart] / bambooType.health, 0, 1)
	updateBambooColor(bambooPart, bambooType, healthFraction)

	if bambooHealth[bambooPart] <= 0 then
		-- Kill the bamboo
		bambooPart:SetAttribute("IsDead", true)
		bambooPart.Transparency = 1
		bambooPart.CanCollide   = false
		bambooPart.Color        = COLOR_DEAD

		-- Award coins
		data.coins        = data.coins + bambooType.reward
		data.totalChopped = data.totalChopped + 1
		sendUpdate(player)

		-- Schedule respawn
		respawnBamboo(bambooPart, bambooType)
	end
end)

-- ============================================================
-- BuyUpgrade handler
-- ============================================================
upgradeEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local nextLevel = data.swordLevel + 1
	local nextSword = Config.SWORDS[nextLevel]
	if not nextSword then return end  -- already at max

	if data.coins < nextSword.cost then return end

	data.coins     = data.coins - nextSword.cost
	data.swordLevel = nextLevel
	sendUpdate(player)
end)

-- ============================================================
-- Player lifecycle
-- ============================================================
local function onPlayerAdded(player)
	local data         = loadData(player)
	playerData[player] = data

	-- Send data when the character spawns (HumanoidRootPart is ready)
	player.CharacterAdded:Connect(function(character)
		-- Short wait so the client LocalScripts have time to connect
		task.wait(0.5)
		sendUpdate(player)
	end)

	-- If character already exists (e.g. fast respawn)
	if player.Character then
		task.wait(0.5)
		sendUpdate(player)
	end
end

local function onPlayerRemoving(player)
	saveData(player)
	playerData[player] = nil
	-- Clean up bamboo health entries is not strictly necessary since
	-- parts persist, but we don't track per-player health anyway.
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before this script ran
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ============================================================
-- Auto-save every 60 seconds
-- ============================================================
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
		print("[GameManager] Auto-saved all player data.")
	end
end)

print("[GameManager] Server logic ready.")
