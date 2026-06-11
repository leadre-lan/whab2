-- StatService.lua — Handles stat upgrades and sword tier upgrades
local StatService = {}

local RS      = game:GetService("ReplicatedStorage")
local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local VALID_STATS = {
	sharpness = true,
	speed     = true,
	luck      = true,
	range     = true,
	stamina   = true,
	dodge     = true,
}

local dataService = nil
local net         = nil

function StatService.init(ds, netRef)
	dataService = ds
	net = netRef

	-- Upgrade stat
	net.UpgradeStat.OnServerEvent:Connect(function(player, statName)
		if not VALID_STATS[statName] then return end
		local pdata = dataService.get(player)
		if not pdata then return end

		local currentLevel = pdata.stats[statName] or 0
		local cost = Balance.statCost(currentLevel)

		if pdata.coins < cost then
			net.Notify:FireClient(player, "Zu wenig Münzen! (" .. cost .. " benötigt)")
			return
		end

		pdata.coins          = pdata.coins - cost
		pdata.stats[statName] = currentLevel + 1
		dataService.sendUpdate(player)
	end)

	-- Sword tier upgrade (buy with coins; Forge system comes later)
	net.BuySword.OnServerEvent:Connect(function(player)
		local pdata = dataService.get(player)
		if not pdata then return end

		local nextTier = pdata.swordTier + 1
		local cost     = Balance.TIER_COST[nextTier]
		if not cost then return end   -- already max tier

		if pdata.coins < cost then
			net.Notify:FireClient(player, "Zu wenig Münzen!")
			return
		end

		pdata.coins     = pdata.coins - cost
		pdata.swordTier = nextTier
		dataService.sendUpdate(player)
	end)
end

return StatService
