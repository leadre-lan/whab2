-- DataService.lua — Player data management with DataStore + session fallback
local DataService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local DS_KEY       = "BambooSlasher_v4"
local SAVE_INTERVAL = 60

local store = nil
do
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(DS_KEY)
	end)
	if ok then
		store = s
	else
		warn("[DataService] DataStore unavailable – session-only mode")
	end
end

local playerData = {}   -- [player] = data table
local net        = nil  -- set by init()

local function defaultData()
	return {
		dataVersion   = 4,
		coins         = 0,
		xp            = 0,
		level         = 1,
		totalFelled   = 0,
		totalMined    = 0,
		totalKills    = 0,
		stats = {
			sharpness = 0,
			speed     = 0,
			luck      = 0,
			range     = 0,
			stamina   = 0,
			dodge     = 0,
		},
		swordTier     = 1,
		materials     = {},     -- { ["mat1"] = 12, ... } keyed by layer
		highestLayer  = 1,
		rebirths      = 0,
		rebirthTokens = 0,
		fame          = 0,
		elo           = 1000,
		pvpWins       = 0,
		pvpLosses     = 0,
		lastDaily     = 0,      -- os.time of last daily reward
	}
end

local function deepMerge(base, incoming)
	if type(incoming) ~= "table" then return base end
	for k, v in pairs(base) do
		if incoming[k] == nil then
			incoming[k] = v
		elseif type(v) == "table" and type(incoming[k]) == "table" then
			incoming[k] = deepMerge(v, incoming[k])
		end
	end
	return incoming
end

function DataService.init(netRef)
	net = netRef
	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.save(player)
			end
		end
	end)
end

function DataService.load(player)
	local loaded = nil
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and type(result) == "table" then
			loaded = deepMerge(defaultData(), result)
		end
	end
	playerData[player] = loaded or defaultData()
end

function DataService.save(player)
	if not store then return end
	local d = playerData[player]
	if not d then return end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, d)
	end)
end

function DataService.get(player)
	return playerData[player]
end

function DataService.flush(player)
	DataService.save(player)
	playerData[player] = nil
end

function DataService.sendUpdate(player)
	local d = playerData[player]
	if d and net then
		net.UpdateData:FireClient(player, d)
	end
end

-- Adds XP, recalculates level; returns (didLevelUp, newLevel)
function DataService.addXP(player, amount)
	local d = playerData[player]
	if not d then return false, 1 end
	local oldLevel = d.level
	d.xp    = d.xp + amount
	d.level = Balance.levelFromXP(d.xp)
	return d.level > oldLevel, d.level
end

return DataService
