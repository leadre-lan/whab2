-- Balance.lua — All game numbers. Edit here, not in service code.
local Balance = {}

local LAYER_COUNT = 12

-- ── XP / Level ────────────────────────────────────────────────────────────────
-- Level = 1 + floor(sqrt(xp/50)). Lv2 = 50 XP, Lv5 = 800, Lv10 = 4050, Lv30 = 42050
function Balance.levelFromXP(xp)
	return math.max(1, math.floor(1 + math.sqrt(xp / 50)))
end

-- ── Per-layer scaling (formula-driven so procedural layers 7+ just work) ──────
-- base * 1.6^(layer-1), as the plan specifies
local function scaled(base, layer)
	return math.floor(base * (1.6 ^ (layer - 1)) + 0.5)
end

function Balance.xpPerFell(layer)     return scaled(5, layer) end
function Balance.coinsPerFell(layer)  return scaled(1.5, layer) end
function Balance.bambooHP(layer)      return scaled(2, layer) end
function Balance.coinsPerMine(layer)  return scaled(4, layer) end
function Balance.rockHP(layer)        return scaled(5, layer) end

Balance.BAMBOO_RESPAWN = {}
Balance.ROCK_RESPAWN   = {}
Balance.BAMBOO_COUNT   = {}
for l = 1, LAYER_COUNT do
	Balance.BAMBOO_RESPAWN[l] = math.min(40, 3 + l * 3)
	Balance.ROCK_RESPAWN[l]   = math.min(70, 12 + l * 8)
	Balance.BAMBOO_COUNT[l]   = math.max(45, 65 - l * 2)
end

-- ── Combat / Stats ────────────────────────────────────────────────────────────
Balance.SWING_DELAY      = 0.35
Balance.LEVEL_DMG        = 0.12   -- +12% damage per player level — higher level
                                  -- = the sword cuts bamboo like a sharp knife
Balance.CLEAVE_RADIUS    = 8      -- one swing slices ALL bamboo around the target
Balance.SHARPNESS_MULT   = 0.15   -- +15% damage per Schärfe level
Balance.SPEED_REDUCTION  = 0.025  -- -0.025s swing delay per level (min 0.15)
Balance.LUCK_CRIT_CHANCE = 0.03   -- +3% crit per level (cap 60%)
Balance.RANGE_BONUS      = 3      -- +3 studs reach per level (base 26)
Balance.STAMINA_HP_BONUS = 10     -- +10 max HP per Ausdauer level
Balance.DODGE_CD_REDUCT  = 0.25   -- -0.25s dash cooldown per Ausweichen level

-- Stat upgrade cost: floor(30 * 1.55^level)
function Balance.statCost(currentLevel)
	return math.floor(30 * (1.55 ^ currentLevel))
end

-- ── Sword tiers (1-10): damage multiplier + forge recipe ─────────────────────
Balance.TIER_MULT = { 1, 1.8, 3.0, 5.0, 8.0, 13.0, 20.0, 31.0, 48.0, 75.0 }

-- Forge recipes: tier N requires coins + materials from a given layer.
-- Material id = layer index it drops from (rocks drop "mat<layer>").
Balance.FORGE_RECIPES = {
	[2]  = { coins = 40,     matLayer = 1, matCount = 5,  name = "Steinschwert" },
	[3]  = { coins = 150,    matLayer = 1, matCount = 12, name = "Eisenschwert" },
	[4]  = { coins = 450,    matLayer = 2, matCount = 10, name = "Goldschwert" },
	[5]  = { coins = 1200,   matLayer = 3, matCount = 10, name = "Diamantschwert" },
	[6]  = { coins = 3200,   matLayer = 3, matCount = 20, name = "Rubin Klinge" },
	[7]  = { coins = 9000,   matLayer = 4, matCount = 15, name = "Smaragdklinge" },
	[8]  = { coins = 25000,  matLayer = 4, matCount = 30, name = "Mondklinge" },
	[9]  = { coins = 70000,  matLayer = 5, matCount = 20, name = "Sonnenklinge" },
	[10] = { coins = 200000, matLayer = 6, matCount = 25, name = "Legendäre Klinge" },
}

-- Materials dropped per rock break (by layer)
Balance.MAT_PER_ROCK = 1

-- ── Combo ─────────────────────────────────────────────────────────────────────
Balance.COMBO_WINDOW = 2.5
local COMBO_MULT = { { 25, 3.0 }, { 10, 2.0 }, { 5, 1.5 } }
function Balance.comboMult(count)
	for _, e in ipairs(COMBO_MULT) do
		if count >= e[1] then return e[2] end
	end
	return 1.0
end

-- ── Slam ──────────────────────────────────────────────────────────────────────
Balance.SLAM_MULT   = 3.5
Balance.SLAM_RADIUS = 12

-- ── Monsters ──────────────────────────────────────────────────────────────────
function Balance.monsterHP(layer)     return scaled(15, layer) end
function Balance.monsterDamage(layer) return scaled(5, layer) end
function Balance.monsterCoins(layer)  return scaled(6, layer) end
function Balance.monsterXP(layer)     return scaled(15, layer) end
Balance.MONSTER_COUNT      = 4      -- per layer
Balance.MONSTER_AGGRO      = 35     -- studs
Balance.MONSTER_SPEED      = 9      -- studs/s
Balance.MONSTER_ATK_RANGE  = 7
Balance.MONSTER_TELEGRAPH  = 0.7    -- wind-up seconds (dodge window)
Balance.MONSTER_ATK_CD     = 2.2
Balance.MONSTER_RESPAWN    = 25
Balance.MONSTER_MAT_CHANCE = 0.35   -- chance to drop 1 material

-- Player melee vs monsters/players
Balance.MELEE_RANGE = 12

-- ── Dash / Block ──────────────────────────────────────────────────────────────
Balance.DASH_COOLDOWN = 3.0    -- base, reduced by Ausweichen
Balance.DASH_SPEED    = 70
Balance.DASH_TIME     = 0.22
Balance.BLOCK_REDUCTION = 0.65 -- blocked hits deal 35% damage

-- ── Rebirth ───────────────────────────────────────────────────────────────────
Balance.REBIRTH_LEVEL = 50
function Balance.rebirthMult(rebirths)
	return 1 + 0.25 * rebirths
end
Balance.REBIRTH_TOKENS = 1     -- tokens per rebirth

-- ── PVP / Arena ───────────────────────────────────────────────────────────────
Balance.PVP_BASE_DAMAGE = 12   -- M1 base in arena (stats scale on top, softly)
Balance.PVP_STAT_SCALE  = 0.05 -- each Schärfe level = +5% pvp damage
Balance.FAME_WIN        = 25
Balance.ELO_K           = 32

-- ── Daily Reward ──────────────────────────────────────────────────────────────
Balance.DAILY_COINS = 250

return Balance
