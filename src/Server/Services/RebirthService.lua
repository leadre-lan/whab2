-- RebirthService.lua — Reset progress for permanent multiplier + tokens
local RebirthService = {}

local RS = game:GetService("ReplicatedStorage")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local dataService = nil
local net         = nil

function RebirthService.tryRebirth(player)
	local pdata = dataService.get(player)
	if not pdata then return end

		if (pdata.level or 1) < Balance.REBIRTH_LEVEL then
			net.Notify:FireClient(player,
				"✨ Rebirth ab Level " .. Balance.REBIRTH_LEVEL .. "! (Du: Lv. " .. pdata.level .. ")")
			return
		end

		-- Reset (sword tier resets, recipes are coin+material-gated anyway;
		-- materials stay so re-crafting goes faster — per plan recommendation)
		pdata.coins        = 0
		pdata.xp           = 0
		pdata.level        = 1
		pdata.highestLayer = 1
		pdata.swordTier    = 1
		pdata.stats = {
			sharpness = 0, speed = 0, luck = 0,
			range = 0, stamina = 0, dodge = 0,
		}

		pdata.rebirths      = (pdata.rebirths or 0) + 1
		pdata.rebirthTokens = (pdata.rebirthTokens or 0) + Balance.REBIRTH_TOKENS

		dataService.sendUpdate(player)
		net.RebirthDone:FireClient(player, pdata.rebirths, Balance.rebirthMult(pdata.rebirths))

		-- Move back to hub spawn
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(-320, 5, -20)
		end
end

function RebirthService.init(ds, netRef)
	dataService = ds
	net         = netRef

	net.DoRebirth.OnServerEvent:Connect(function(player)
		RebirthService.tryRebirth(player)
	end)
end

return RebirthService
