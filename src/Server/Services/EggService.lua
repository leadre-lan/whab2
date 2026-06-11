-- EggService.lua — Hatch-Logik, Luck Potion (Dev-Product), Daily Reward
local EggService = {}

local Players            = game:GetService("Players")
local RS                 = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins  = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))

local rng = Random.new()

local dataService = nil
local net         = nil

local FLEX_TIERS = { Godly = true, Mythical = true }

local function luckActive(data)
	return os.time() < (data.luckUntil or 0)
end

local function hatch(player, eggId)
	local egg = Config.EGGS[eggId]
	if not egg then return end
	local data = dataService.get(player)
	if not data then return end

	if data.credits < egg.cost then
		net.Notify:FireClient(player, "Zu wenig " .. Config.CURRENCY_NAME .. "! (" .. egg.cost .. " benötigt)")
		return
	end
	data.credits = data.credits - egg.cost
	data.hatches = (data.hatches or 0) + 1

	-- Pity: nach PITY_LEGENDARY Pulls ohne Legendary+ ist der nächste garantiert
	data.pullsSinceLegendary = (data.pullsSinceLegendary or 0) + 1
	local forced = data.pullsSinceLegendary >= Config.PITY_LEGENDARY

	local skin = Skins.roll(rng, luckActive(data), Config.LUCK_MULTIPLIER, forced and 3 or nil)
	if Skins.TIERS[skin.tier].order >= 3 then
		data.pullsSinceLegendary = 0
	end

	data.skins[skin.id] = (data.skins[skin.id] or 0) + 1
	dataService.sendUpdate(player)

	-- Client spielt den Case-Spinner (Spin → Reveal → "GEWONNEN!")
	net.HatchResult:FireClient(player, skin.id, data.skins[skin.id],
		math.max(0, Config.PITY_LEGENDARY - data.pullsSinceLegendary))

	-- Godly+/Mythical: der ganze Server soll es sehen — DAS ist der Flex
	if FLEX_TIERS[skin.tier] then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				net.Notify:FireClient(p,
					"🌌 " .. player.Name .. " hat " .. skin.name .. " [" .. Skins.TIERS[skin.tier].label .. "] gezogen!")
			end
		end
	end
end

-- Öffentlich, damit das Lobby-Terminal sie direkt aufrufen kann
function EggService.claimDaily(player)
	local data = dataService.get(player)
	if not data then return end
	local now = os.time()
	local remaining = Config.DAILY_COOLDOWN - (now - (data.lastDaily or 0))
	if remaining > 0 then
		net.Notify:FireClient(player,
			"🎁 Schon abgeholt! Wieder in ~" .. math.ceil(remaining / 3600) .. "h")
		return
	end
	data.lastDaily = now
	data.credits = data.credits + Config.DAILY_REWARD
	dataService.sendUpdate(player)
	net.PlaySFX:FireClient(player, "Coin")
	net.Notify:FireClient(player, "🎁 +" .. Config.DAILY_REWARD .. " " .. Config.CURRENCY_NAME .. "!")
end

function EggService.init(ds, netRef)
	dataService = ds
	net         = netRef

	net.HatchEgg.OnServerEvent:Connect(function(player, eggId)
		if type(eggId) ~= "string" then return end
		hatch(player, eggId)
	end)

	net.ClaimDaily.OnServerEvent:Connect(function(player)
		EggService.claimDaily(player)
	end)

	-- ── Luck Potion (Dev-Product) ──
	net.BuyLuck.OnServerEvent:Connect(function(player)
		if Config.LUCK_PRODUCT_ID == 0 then
			net.Notify:FireClient(player, "⚗ Luck Potion: Produkt-ID noch nicht konfiguriert (Config.lua)")
			return
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, Config.LUCK_PRODUCT_ID)
		end)
	end)

	if Config.LUCK_PRODUCT_ID ~= 0 then
		MarketplaceService.ProcessReceipt = function(receipt)
			if receipt.ProductId ~= Config.LUCK_PRODUCT_ID then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local player = Players:GetPlayerByUserId(receipt.PlayerId)
			if not player then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local data = dataService.get(player)
			if not data then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local base = math.max(os.time(), data.luckUntil or 0)
			data.luckUntil = base + Config.LUCK_DURATION
			dataService.sendUpdate(player)
			net.Notify:FireClient(player, "⚗ Luck Potion aktiv! Doppelte Chance auf seltene Skins.")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	print("[EggService] bereit (" .. tostring(#Skins.CATALOG) .. " Skins im Pool).")
end

return EggService
