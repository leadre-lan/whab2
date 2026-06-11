-- DataService.lua — Laden/Speichern/Replizieren der Spielerdaten
local DataService = {}

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS               = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("HatchSnipers_v1")
end)

local cache = {}   -- [player] = data

local net = nil

local function defaultData()
	return {
		credits   = Config.START_CREDITS,
		skins     = { standard = 1 },   -- jeder startet mit dem Standard-Skin
		equipped  = "standard",
		kills     = 0,
		wins      = 0,
		hatches   = 0,
		luckUntil = 0,
		lastDaily = 0,
		rating    = Config.ELO_START,   -- Rang (1v1-ELO)
		pullsSinceLegendary = 0,        -- Pity-Zähler fürs Omega-Gehäuse
		lastWeekly = 0,                 -- Prime-Weekly
	}
end

function DataService.load(player)
	if cache[player] then return cache[player] end
	local data = defaultData()
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			-- fehlende Felder auffüllen (Schema-Migrationen)
			for k, v in pairs(defaultData()) do
				if saved[k] == nil then saved[k] = v end
			end
			if type(saved.skins) ~= "table" or not next(saved.skins) then
				saved.skins = { standard = 1 }
			end
			data = saved
		end
	end
	cache[player] = data
	DataService.sendUpdate(player)
	return data
end

function DataService.get(player)
	return cache[player]
end

function DataService.getOrLoad(player)
	return cache[player] or DataService.load(player)
end

function DataService.flush(player)
	local data = cache[player]
	cache[player] = nil
	if data and store then
		pcall(function()
			store:SetAsync("p_" .. player.UserId, data)
		end)
	end
end

function DataService.sendUpdate(player)
	local data = cache[player]
	if data and net then
		net.UpdateData:FireClient(player, data)
	end
end

-- Für Bestenliste/Leaderboard: über alle geladenen Spieler iterieren
function DataService.eachPlayer()
	return pairs(cache)
end

function DataService.addCredits(player, amount)
	local data = cache[player]
	if not data then return end
	data.credits = math.max(0, data.credits + amount)
	DataService.sendUpdate(player)
end

function DataService.init(netRef)
	net = netRef

	Players.PlayerRemoving:Connect(DataService.flush)

	-- Auto-Save alle 60s
	task.spawn(function()
		while true do
			task.wait(60)
			if store then
				for player, data in pairs(cache) do
					pcall(function()
						store:SetAsync("p_" .. player.UserId, data)
					end)
				end
			end
		end
	end)

	-- Passives Einkommen (Spielzeit-Drip)
	task.spawn(function()
		while true do
			task.wait(Config.DRIP_INTERVAL)
			for player, data in pairs(cache) do
				data.credits = data.credits + Config.DRIP_AMOUNT
				DataService.sendUpdate(player)
			end
		end
	end)

	game:BindToClose(function()
		if store then
			for player, data in pairs(cache) do
				pcall(function()
					store:SetAsync("p_" .. player.UserId, data)
				end)
			end
		end
	end)

	print("[DataService] bereit.")
end

return DataService
