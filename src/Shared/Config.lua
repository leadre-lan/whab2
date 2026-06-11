-- Config.lua — Alle Spielwerte von Hatch Snipers an einem Ort.
local Config = {}

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
Config.LOBBY_SHOOTING  = true        -- in der Lobby knallt's, aber ohne Schaden

-- ── Eier ──────────────────────────────────────────────────────────────────────
-- Ein massives Omega-Ei in der Lobby-Mitte; weitere Eier einfach ergänzen
-- (EggService + UI sind komplett config-getrieben).
Config.EGGS = {
	omega = {
		name  = "Omega-Ei",
		cost  = 750,
		color = Color3.fromRGB(150, 80, 255),
	},
}

-- ── Monetarisierung (IDs im Creator-Dashboard anlegen und hier eintragen;
--     0 = deaktiviert, Buttons melden dann "nicht konfiguriert") ───────────────
Config.LUCK_PRODUCT_ID  = 0          -- Dev-Product: Luck Potion
Config.LUCK_DURATION    = 15 * 60    -- 15 Minuten
Config.LUCK_MULTIPLIER  = 2          -- verdoppelt die Nicht-Common-Gewichte
Config.TRADER_PASS_ID   = 0          -- Gamepass: mehr Trade-Slots
Config.TRADE_SLOTS      = 3          -- ohne Gamepass
Config.TRADE_SLOTS_PASS = 6          -- mit Trader-Gamepass

return Config
