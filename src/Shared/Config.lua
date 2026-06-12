-- Config.lua — Alle Spielwerte von Hatch Snipers an einem Ort.
local Config = {}

-- Wird im HUD angezeigt — so siehst du sofort, ob der richtige Build läuft
Config.VERSION = "v1.4 — AWP fest eingebaut"

-- ── Währung / Economy ─────────────────────────────────────────────────────────
Config.CURRENCY_NAME   = "Credits"
Config.START_CREDITS   = 1000        -- reicht für den ersten Pull sofort
Config.KILL_REWARD     = 25
Config.WIN_REWARD      = 100
Config.LOSS_REWARD     = 30
Config.DAILY_REWARD    = 500
Config.DAILY_COOLDOWN  = 20 * 3600   -- 20h
Config.DRIP_AMOUNT     = 5           -- passives Einkommen …
Config.DRIP_INTERVAL   = 30          -- … alle 30s Spielzeit

-- ── Arena / Match ─────────────────────────────────────────────────────────────
Config.ARENA_COUNT     = 4
Config.ARENA_BASE_X    = 1200
Config.ARENA_SPACING   = 400
Config.KILLS_TO_WIN    = 5
Config.MATCH_TIME      = 150         -- Sekunden, danach gewinnt der Führende
Config.RESPAWN_DELAY   = 2.5
Config.COUNTDOWN       = 3

-- ── Waffe (IMMER gleich für alle Skins — 100% skill-basiert) ──────────────────
Config.SHOT_COOLDOWN   = 1.4         -- Bolt-Action-Takt
Config.SHOT_RANGE      = 800
Config.LOBBY_SHOOTING  = false       -- Snipen NUR in der Arena (Lobby = Showroom)

-- ── Slide (Movement-Skill: Ctrl/C im Lauf) ────────────────────────────────────
Config.SLIDE_SPEED    = 44           -- Boost in Bewegungsrichtung
Config.SLIDE_TIME     = 0.42         -- Sekunden Rutschphase
Config.SLIDE_COOLDOWN = 2.0

-- Das Waffen-Modell (texturiertes Roblox-Gewehr-Mesh) ist in Shared/Assets.lua
-- definiert (Assets.WEAPON) — Roblox-eigenes Asset, lädt garantiert überall.

-- ── Bot-1v1 (Training) ────────────────────────────────────────────────────────
Config.BOT_NAME        = "🤖 Trainings-Bot"
Config.BOT_ACCURACY    = 0.40        -- Trefferchance pro Bot-Schuss
Config.BOT_REACTION    = { 0.7, 1.4 }-- Ziel-Zeit nach Sichtkontakt (Sekunden)
Config.BOT_SHOT_CD     = 1.9         -- Bot schießt etwas langsamer als Spieler
Config.BOT_MOVE_EVERY  = { 2.5, 5 }  -- Sekunden zwischen Positionswechseln
Config.BOT_KILL_REWARD = 10          -- reduzierte Rewards im Training
Config.BOT_WIN_REWARD  = 40

-- ── Cases ─────────────────────────────────────────────────────────────────────
-- Das Omega-Gehäuse in der Lobby-Mitte; weitere Cases einfach ergänzen
-- (EggService + UI sind komplett config-getrieben).
Config.EGGS = {
	omega = {
		name  = "Omega-Gehäuse",
		cost  = 750,
		color = Color3.fromRGB(150, 80, 255),
	},
}

-- Pity-System: spätestens nach so vielen Pulls ohne Legendary+ ist der
-- nächste Pull garantiert Legendary oder besser (Zähler in der Case-UI)
Config.PITY_LEGENDARY = 45

-- ── Wager-Duelle (1v1 um Credits) ─────────────────────────────────────────────
Config.WAGER_OPTIONS = { 0, 50, 100, 250, 500 }   -- 0 = Casual

-- ── Rang-System (ELO; gespeist aus 1v1-PvP, Bot-Matches zählen nicht) ─────────
Config.ELO_START = 1000
Config.ELO_K     = 40
Config.RANKS = {
	{ min = 0,    name = "Silber I",       color = Color3.fromRGB(170, 175, 185) },
	{ min = 850,  name = "Silber II",      color = Color3.fromRGB(180, 185, 195) },
	{ min = 950,  name = "Silber Elite",   color = Color3.fromRGB(205, 210, 220) },
	{ min = 1050, name = "Gold Nova I",    color = Color3.fromRGB(235, 195, 80) },
	{ min = 1150, name = "Gold Nova II",   color = Color3.fromRGB(245, 205, 90) },
	{ min = 1250, name = "Gold Nova III",  color = Color3.fromRGB(255, 215, 100) },
	{ min = 1350, name = "Meister-Wächter",color = Color3.fromRGB(120, 200, 255) },
	{ min = 1500, name = "Adler-Meister",  color = Color3.fromRGB(90, 150, 255) },
	{ min = 1650, name = "Übermacht",      color = Color3.fromRGB(190, 90, 255) },
	{ min = 1800, name = "GLOBAL ELITE",   color = Color3.fromRGB(255, 70, 200) },
}

function Config.rankFor(rating)
	local best = Config.RANKS[1]
	for _, r in ipairs(Config.RANKS) do
		if rating >= r.min then best = r end
	end
	return best
end

-- ── Monetarisierung (IDs im Creator-Dashboard anlegen und hier eintragen;
--     0 = deaktiviert, Buttons melden dann "nicht konfiguriert") ───────────────
Config.LUCK_PRODUCT_ID  = 0          -- Dev-Product: Luck Potion
Config.LUCK_DURATION    = 15 * 60    -- 15 Minuten
Config.LUCK_MULTIPLIER  = 2          -- verdoppelt die Nicht-Common-Gewichte
Config.TRADER_PASS_ID   = 0          -- Gamepass: mehr Trade-Slots
Config.TRADE_SLOTS      = 3          -- ohne Gamepass
Config.TRADE_SLOTS_PASS = 6          -- mit Trader-Gamepass

-- Prime Status (Gamepass): exklusiver Skin + Aura, Rang-Boost, Weekly-Reward
Config.PRIME_PASS_ID    = 0
Config.PRIME_PRICE_TEXT = "1200 Robux"
Config.PRIME_WEEKLY     = 1500       -- Credits pro Woche
Config.PRIME_RANK_BOOST = 1.25       -- +25% ELO-Gewinn (keine stärkeren Waffen!)

return Config
