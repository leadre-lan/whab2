-- PrimeService.lua — Prime Status (Gamepass): exklusiver Skin + Aura,
-- +25% Rang-Fortschritt, wöchentliche Belohnung. NIEMALS stärkere Waffen —
-- Matches bleiben 100% skill-basiert.
local PrimeService = {}

local Players            = game:GetService("Players")
local RS                 = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local dataService   = nil
local weaponService = nil
local net           = nil

local function checkPrime(player)
	if Config.PRIME_PASS_ID == 0 then return false end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.PRIME_PASS_ID)
	end)
	return ok and owns or false
end

-- Prime erkennen + Vorteile gewähren (Exklusiv-Skin, Flag für Aura/Rang-Boost)
local function applyPrime(player)
	local data = dataService.get(player)
	if not data or data.prime then return end
	data.prime = true
	if (data.skins.primeaegis or 0) < 1 then
		data.skins.primeaegis = 1
		net.Notify:FireClient(player, "👑 Prime aktiv! Exklusiv-Skin 'Prime: Ägis' freigeschaltet.")
	end
	dataService.sendUpdate(player)
	weaponService.giveWeapon(player)   -- Aura aktualisieren
end

function PrimeService.init(ds, ws, netRef)
	dataService   = ds
	weaponService = ws
	net           = netRef

	local function onJoin(player)
		task.spawn(function()
			-- warten bis Daten geladen sind
			local tries = 0
			while not dataService.get(player) and tries < 50 and player.Parent do
				task.wait(0.2)
				tries += 1
			end
			if player.Parent and checkPrime(player) then
				applyPrime(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do
		onJoin(p)
	end

	-- Kauf-Prompt aus dem Prime-Menü
	net.BuyPrime.OnServerEvent:Connect(function(player)
		if Config.PRIME_PASS_ID == 0 then
			net.Notify:FireClient(player, "👑 Prime: Gamepass-ID noch nicht konfiguriert (Config.lua)")
			return
		end
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, Config.PRIME_PASS_ID)
		end)
	end)

	if Config.PRIME_PASS_ID ~= 0 then
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if purchased and passId == Config.PRIME_PASS_ID then
				applyPrime(player)
			end
		end)
	end

	-- Wöchentliche Prime-Belohnung
	net.ClaimWeekly.OnServerEvent:Connect(function(player)
		local data = dataService.get(player)
		if not data then return end
		if not data.prime then
			net.Notify:FireClient(player, "👑 Weekly-Belohnung ist Prime-exklusiv.")
			return
		end
		local now = os.time()
		local remaining = 7 * 24 * 3600 - (now - (data.lastWeekly or 0))
		if remaining > 0 then
			net.Notify:FireClient(player,
				"👑 Schon abgeholt! Wieder in ~" .. math.ceil(remaining / 3600 / 24) .. " Tagen")
			return
		end
		data.lastWeekly = now
		data.credits = data.credits + Config.PRIME_WEEKLY
		dataService.sendUpdate(player)
		net.PlaySFX:FireClient(player, "Coin")
		net.Notify:FireClient(player, "👑 +" .. Config.PRIME_WEEKLY .. " " .. Config.CURRENCY_NAME .. " (Prime-Weekly)!")
	end)

	print("[PrimeService] bereit.")
end

return PrimeService
