-- TradeService.lua — Skin-Trading zwischen Spielern.
-- Trading ist gratis; mehr als Config.TRADE_SLOTS Items pro Seite erfordert
-- den Trader-Gamepass (Config.TRADER_PASS_ID).
local TradeService = {}

-- Callback für den Live-Ticker der Handelshalle (vom Server-Wiring gesetzt)
TradeService.onTicker = nil

local Players            = game:GetService("Players")
local RS                 = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins  = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))

local dataService   = nil
local weaponService = nil
local net           = nil

local sessions = {}   -- [player] = session
local requests = {}   -- [target] = { from = player, at = os.clock() }
local passCache = {}  -- [player] = bool

local REQUEST_TTL = 30

local function maxSlots(player)
	if Config.TRADER_PASS_ID == 0 then return Config.TRADE_SLOTS end
	if passCache[player] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.TRADER_PASS_ID)
		end)
		passCache[player] = ok and owns or false
	end
	return passCache[player] and Config.TRADE_SLOTS_PASS or Config.TRADE_SLOTS
end

local function other(session, player)
	return (player == session.a) and session.b or session.a
end

local function pushState(session)
	for _, p in ipairs({ session.a, session.b }) do
		if p.Parent then
			local o = other(session, p)
			net.TradeUpdate:FireClient(p, {
				state        = "open",
				partner      = o.Name,
				yourOffer    = session.offers[p],
				theirOffer   = session.offers[o],
				youAccepted  = session.accepted[p],
				theyAccepted = session.accepted[o],
				maxSlots     = maxSlots(p),
			})
		end
	end
end

local function closeSession(session, reason)
	for _, p in ipairs({ session.a, session.b }) do
		sessions[p] = nil
		if p.Parent then
			net.TradeUpdate:FireClient(p, { state = "closed", reason = reason })
		end
	end
end

-- Angebot gegen das Inventar prüfen (Array von skinIds, Duplikate erlaubt)
local function validOffer(player, offer)
	if type(offer) ~= "table" then return false end
	if #offer > maxSlots(player) then return false end
	local data = dataService.get(player)
	if not data then return false end
	local needed = {}
	for _, id in ipairs(offer) do
		if type(id) ~= "string" or not Skins.BY_ID[id] then return false end
		if id == "standard" then return false end   -- Standard ist nicht handelbar
		needed[id] = (needed[id] or 0) + 1
	end
	for id, n in pairs(needed) do
		if (data.skins[id] or 0) < n then return false end
	end
	return true
end

local function executeTrade(session)
	-- Beide Angebote nochmal final validieren
	if not validOffer(session.a, session.offers[session.a])
		or not validOffer(session.b, session.offers[session.b]) then
		closeSession(session, "Angebot ungültig geworden.")
		return
	end

	local function transfer(from, to, offer)
		local dFrom, dTo = dataService.get(from), dataService.get(to)
		for _, id in ipairs(offer) do
			dFrom.skins[id] = dFrom.skins[id] - 1
			if dFrom.skins[id] <= 0 then dFrom.skins[id] = nil end
			dTo.skins[id] = (dTo.skins[id] or 0) + 1
		end
		-- Equipped-Skin weggetauscht → zurück auf Standard
		if not dFrom.skins[dFrom.equipped] then
			dFrom.equipped = "standard"
			weaponService.giveWeapon(from)
		end
	end
	transfer(session.a, session.b, session.offers[session.a])
	transfer(session.b, session.a, session.offers[session.b])

	-- Live-Ticker der Handelshalle: das hochwertigste Item des Trades
	if TradeService.onTicker then
		local best, bestOrder = nil, 0
		for _, offer in ipairs({ session.offers[session.a], session.offers[session.b] }) do
			for _, id in ipairs(offer) do
				local s = Skins.BY_ID[id]
				if s and Skins.TIERS[s.tier].order > bestOrder then
					best, bestOrder = s, Skins.TIERS[s.tier].order
				end
			end
		end
		if best then
			TradeService.onTicker(("ZULETZT GEHANDELT: %s [%s]  ·  %s ⇄ %s")
				:format(best.name, Skins.TIERS[best.tier].label, session.a.Name, session.b.Name))
		end
	end

	for _, p in ipairs({ session.a, session.b }) do
		sessions[p] = nil
		if p.Parent then
			dataService.sendUpdate(p)
			net.PlaySFX:FireClient(p, "Chime", 0.7)
			net.TradeUpdate:FireClient(p, { state = "done" })
			net.Notify:FireClient(p, "🤝 Trade abgeschlossen!")
		end
	end
end

function TradeService.init(ds, ws, netRef)
	dataService   = ds
	weaponService = ws
	net           = netRef

	net.TradeRequest.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
		if target == player or sessions[player] or sessions[target] then
			net.Notify:FireClient(player, "Trade gerade nicht möglich.")
			return
		end
		requests[target] = { from = player, at = os.clock() }
		net.TradeUpdate:FireClient(target, { state = "request", from = player.Name })
		net.Notify:FireClient(player, "📨 Trade-Anfrage an " .. target.Name .. " gesendet.")
	end)

	net.TradeRespond.OnServerEvent:Connect(function(player, accept)
		local req = requests[player]
		requests[player] = nil
		if not req or os.clock() - req.at > REQUEST_TTL then return end
		local from = req.from
		if not from.Parent or sessions[from] or sessions[player] then return end
		if accept ~= true then
			net.Notify:FireClient(from, player.Name .. " hat den Trade abgelehnt.")
			return
		end
		local session = {
			a = from, b = player,
			offers   = { [from] = {}, [player] = {} },
			accepted = { [from] = false, [player] = false },
		}
		sessions[from] = session
		sessions[player] = session
		pushState(session)
	end)

	net.TradeSetOffer.OnServerEvent:Connect(function(player, offer)
		local session = sessions[player]
		if not session then return end
		if not validOffer(player, offer) then
			net.Notify:FireClient(player, "Ungültiges Angebot (max. " .. maxSlots(player) .. " Items"
				.. (Config.TRADER_PASS_ID ~= 0 and ", mehr mit Trader-Gamepass" or "") .. ").")
			return
		end
		session.offers[player] = offer
		-- Jede Änderung setzt beide Bestätigungen zurück (Scam-Schutz)
		session.accepted[session.a] = false
		session.accepted[session.b] = false
		pushState(session)
	end)

	net.TradeAccept.OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if not session then return end
		session.accepted[player] = true
		if session.accepted[session.a] and session.accepted[session.b] then
			executeTrade(session)
		else
			pushState(session)
		end
	end)

	net.TradeCancel.OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if session then
			closeSession(session, player.Name .. " hat abgebrochen.")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
		requests[player] = nil
		local session = sessions[player]
		if session then
			closeSession(session, player.Name .. " hat das Spiel verlassen.")
		end
	end)

	print("[TradeService] bereit.")
end

return TradeService
