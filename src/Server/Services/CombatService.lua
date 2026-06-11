-- CombatService.lua — Shared melee combat for PVE (monsters) and PVP (arena)
local CombatService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local dataService    = nil
local monsterService = nil
local arenaService   = nil
local net            = nil

local attackCooldowns = {}  -- [player] = os.clock()

local function playerDamage(player)
	local d = dataService.get(player)
	if not d then return 1 end
	local sharp = d.stats.sharpness or 0
	return math.ceil((1 + sharp * Balance.SHARPNESS_MULT) * (Balance.TIER_MULT[d.swordTier or 1] or 1))
end

local function pvpDamage(player)
	local d = dataService.get(player)
	local sharp = d and (d.stats.sharpness or 0) or 0
	-- Soft stat scaling in PVP so skill matters more than grind
	return math.ceil(Balance.PVP_BASE_DAMAGE * (1 + sharp * Balance.PVP_STAT_SCALE))
end

function CombatService.init(ds, ms, netRef)
	dataService    = ds
	monsterService = ms
	net            = netRef

	-- Client sends a target: monster Model or another player's Character
	net.AttackEntity.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" then return end

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Global attack cooldown (speed stat reduces it)
		local d = dataService.get(player)
		local speed = d and (d.stats.speed or 0) or 0
		local cd = math.max(0.15, Balance.SWING_DELAY - speed * Balance.SPEED_REDUCTION)
		local now = os.clock()
		local last = attackCooldowns[player]
		if last and (now - last) < cd then return end
		attackCooldowns[player] = now

		-- ── Monster target ──
		if target:IsA("Model") and monsterService.isMonster(target) then
			local body = target.PrimaryPart
			if not body then return end
			if (body.Position - root.Position).Magnitude > Balance.MELEE_RANGE + 4 then return end
			monsterService.damageMonster(player, target, playerDamage(player))
			return
		end

		-- ── Player target (only valid inside an arena match) ──
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer and arenaService then
			if not arenaService.areOpponents(player, targetPlayer) then return end
			local tChar = targetPlayer.Character
			local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
			local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
			if not tRoot or not tHum or tHum.Health <= 0 then return end
			if (tRoot.Position - root.Position).Magnitude > Balance.MELEE_RANGE then return end

			local dmg = pvpDamage(player)
			if tChar:GetAttribute("Blocking") then
				dmg = math.ceil(dmg * (1 - Balance.BLOCK_REDUCTION))
			end
			tHum:TakeDamage(dmg)
			net.HitEffect:FireClient(player, tRoot.Position, Color3.fromRGB(255, 90, 60), false, nil, dmg, nil)
			net.HitEffect:FireClient(targetPlayer, tRoot.Position, Color3.fromRGB(255, 90, 60), false, nil, nil, nil)
		end
	end)

	-- Block state: client toggles, server stores as character attribute
	net.SetBlocking.OnServerEvent:Connect(function(player, blocking)
		local char = player.Character
		if char then
			char:SetAttribute("Blocking", blocking == true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		attackCooldowns[player] = nil
	end)
end

function CombatService.setArenaService(as)
	arenaService = as
end

return CombatService
