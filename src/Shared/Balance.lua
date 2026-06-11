-- Balance.lua — All game numbers. Edit here, not in service code.
local Balance = {}

-- XP needed to reach level N (simple sqrt formula: level = 1 + floor(sqrt(xp/50)))
-- Level 2 = 50 XP, Level 5 = 800 XP, Level 10 = 4050 XP, Level 18 = 15050 XP
function Balance.levelFromXP(xp)
	return math.max(1, math.floor(1 + math.sqrt(xp / 50)))
end

-- XP earned per fell by layer
Balance.XP_PER_FELL  = { 5, 15, 40, 90, 160, 280 }

-- Coins earned per fell by layer (base, before multipliers)
Balance.COINS_PER_FELL = { 1, 3, 8, 20, 45, 100 }

-- Bamboo HP per layer
Balance.BAMBOO_HP = { 3, 6, 14, 28, 55, 100 }

-- Bamboo respawn time (seconds) per layer
Balance.BAMBOO_RESPAWN = { 4, 6, 10, 16, 24, 35 }

-- Bamboo count per layer
Balance.BAMBOO_COUNT = { 22, 22, 20, 18, 16, 14 }

-- Rock HP / respawn / coins per layer
Balance.ROCK_HP      = { 5, 9, 16, 28, 45, 70 }
Balance.ROCK_RESPAWN = { 15, 20, 28, 38, 50, 65 }
Balance.COINS_PER_MINE = { 3, 9, 25, 60, 135, 300 }

-- Swing cooldown base (seconds)
Balance.SWING_DELAY = 0.5

-- Stat effects per upgrade level
Balance.SHARPNESS_MULT   = 0.15   -- +15% damage per level
Balance.SPEED_REDUCTION  = 0.025  -- -0.025s per level (min 0.15s)
Balance.LUCK_CRIT_CHANCE = 0.03   -- +3% crit per level (max 60%)
Balance.RANGE_BONUS      = 3      -- +3 studs per level (base 22)

-- Stat upgrade cost: floor(30 * 1.55 ^ level)
Balance.STAT_COST_BASE = 30
Balance.STAT_COST_MULT = 1.55

function Balance.statCost(currentLevel)
	return math.floor(Balance.STAT_COST_BASE * (Balance.STAT_COST_MULT ^ currentLevel))
end

-- Sword tier damage multipliers (tiers 1-10)
Balance.TIER_MULT = { 1, 1.8, 3.0, 5.0, 8.0, 13.0, 20.0, 31.0, 48.0, 75.0 }

-- Sword tier upgrade cost (coins)
Balance.TIER_COST = { 0, 40, 120, 350, 900, 2500, 7000, 20000, 55000, 150000 }

-- Combo window (seconds)
Balance.COMBO_WINDOW = 2.5

-- Combo coin multipliers { minCombo → multiplier }
Balance.COMBO_MULT = { { 25, 3.0 }, { 10, 2.0 }, { 5, 1.5 } }

function Balance.comboMult(count)
	for _, entry in ipairs(Balance.COMBO_MULT) do
		if count >= entry[1] then return entry[2] end
	end
	return 1.0
end

-- Slam
Balance.SLAM_MULT   = 3.5
Balance.SLAM_RADIUS = 12

return Balance
