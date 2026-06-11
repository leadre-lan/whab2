-- ForgeService.lua — Craft sword tiers at the forge using coins + materials
local ForgeService = {}

local RS = game:GetService("ReplicatedStorage")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local dataService = nil
local net         = nil

function ForgeService.init(ds, netRef)
	dataService = ds
	net         = netRef

	net.CraftSword.OnServerEvent:Connect(function(player)
		local pdata = dataService.get(player)
		if not pdata then return end

		local nextTier = (pdata.swordTier or 1) + 1
		local recipe = Balance.FORGE_RECIPES[nextTier]
		if not recipe then
			net.Notify:FireClient(player, "⚔ Du hast bereits das beste Schwert!")
			return
		end

		local matKey = "mat" .. recipe.matLayer
		local have   = (pdata.materials and pdata.materials[matKey]) or 0

		if pdata.coins < recipe.coins then
			net.Notify:FireClient(player, "Zu wenig Bamboos! (" .. recipe.coins .. " benötigt)")
			return
		end
		if have < recipe.matCount then
			net.Notify:FireClient(player,
				"Zu wenig Material! (" .. have .. "/" .. recipe.matCount .. " aus Schicht " .. recipe.matLayer .. ")")
			return
		end

		pdata.coins = pdata.coins - recipe.coins
		pdata.materials[matKey] = have - recipe.matCount
		pdata.swordTier = nextTier
		dataService.sendUpdate(player)

		-- Craft moment: tell everyone for tier 5+
		net.Notify:FireClient(player, "🔨 " .. recipe.name .. " geschmiedet!")
		if nextTier >= 5 then
			local Players = game:GetService("Players")
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then
					net.Notify:FireClient(p, "🔥 " .. player.Name .. " hat " .. recipe.name .. " geschmiedet!")
				end
			end
		end
	end)
end

return ForgeService
