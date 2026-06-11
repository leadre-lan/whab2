-- Skins.lua — Der komplette Skin-Katalog inkl. Drop-Chancen.
--
-- WICHTIG (Fairness): Skins sind 100% kosmetisch. Schaden/Cooldown/Range sind
-- für alle identisch (Config.lua) — der Flex ist das Aussehen, nicht die Power.
--
-- Tier-Eskalation:
--   Common    matte Plastik/Holz-Looks, dumpfer Schuss-Sound
--   Rare      Metallic (Chrom/Gold), reflektiert das Licht
--   Legendary Neon-Akzente + permanente Partikel am Lauf + Licht
--   Godly     pulsiert, Lichtspur beim Laufen, Gegner-Screenflash beim Treffer
--   Mythical  Regenbogen-Puls + alles davon — der Server-König
local Skins = {}

-- Drop-Gewichte pro Tier (Summe egal, wird normalisiert; UI zeigt Prozente).
-- Luck Potion multipliziert alle Nicht-Common-Gewichte mit Config.LUCK_MULTIPLIER.
Skins.TIERS = {
	Common    = { weight = 60,  color = Color3.fromRGB(170, 175, 185), order = 1 },
	Rare      = { weight = 28,  color = Color3.fromRGB(70, 150, 255),  order = 2 },
	Legendary = { weight = 9.5, color = Color3.fromRGB(255, 170, 30),  order = 3 },
	Godly     = { weight = 2,   color = Color3.fromRGB(255, 60, 90),   order = 4 },
	Mythical  = { weight = 0.5, color = Color3.fromRGB(255, 0, 255),   order = 5 },
}

-- body = Hauptfarbe, accent = Lauf/Scope/Glow-Farbe.
-- material überschreibt das Tier-Standard-Material (optional).
Skins.CATALOG = {
	-- ── Common ──
	-- keepTexture: behält die Original-AWP-Textur des Mesh-Modells
	{ id = "standard",  name = "Klassik-Tarn",  tier = "Common", body = Color3.fromRGB(95, 98, 105),   accent = Color3.fromRGB(120, 130, 80), keepTexture = true },
	{ id = "holz",      name = "Holz",          tier = "Common", body = Color3.fromRGB(130, 95, 60),   accent = Color3.fromRGB(90, 64, 40),  material = Enum.Material.Wood },
	{ id = "beton",     name = "Beton",         tier = "Common", body = Color3.fromRGB(140, 140, 135), accent = Color3.fromRGB(110, 110, 105), material = Enum.Material.Concrete },
	{ id = "khaki",     name = "Khaki",         tier = "Common", body = Color3.fromRGB(125, 125, 90),  accent = Color3.fromRGB(90, 92, 60) },
	{ id = "schiefer",  name = "Schiefer",      tier = "Common", body = Color3.fromRGB(75, 78, 88),    accent = Color3.fromRGB(50, 52, 60),  material = Enum.Material.Slate },
	{ id = "rost",      name = "Rost",          tier = "Common", body = Color3.fromRGB(135, 85, 55),   accent = Color3.fromRGB(95, 60, 40),  material = Enum.Material.CorrodedMetal },

	-- ── Rare ──
	{ id = "chrom",     name = "Chrom",         tier = "Rare", body = Color3.fromRGB(210, 215, 225), accent = Color3.fromRGB(160, 168, 180) },
	{ id = "gold",      name = "Gold",          tier = "Rare", body = Color3.fromRGB(240, 195, 50),  accent = Color3.fromRGB(190, 145, 30) },
	{ id = "rosegold",  name = "Roségold",      tier = "Rare", body = Color3.fromRGB(235, 165, 150), accent = Color3.fromRGB(200, 120, 110) },
	{ id = "saphir",    name = "Saphirstahl",   tier = "Rare", body = Color3.fromRGB(70, 110, 220),  accent = Color3.fromRGB(45, 70, 160) },
	{ id = "smaragd",   name = "Smaragdstahl",  tier = "Rare", body = Color3.fromRGB(55, 180, 110),  accent = Color3.fromRGB(35, 125, 75) },

	-- ── Legendary ──
	{ id = "viper",     name = "Neon-Viper",    tier = "Legendary", body = Color3.fromRGB(25, 30, 25),  accent = Color3.fromRGB(90, 255, 60) },
	{ id = "plasma",    name = "Plasma-Pink",   tier = "Legendary", body = Color3.fromRGB(35, 22, 35),  accent = Color3.fromRGB(255, 70, 200) },
	{ id = "blaufeuer", name = "Blaufeuer",     tier = "Legendary", body = Color3.fromRGB(20, 25, 40),  accent = Color3.fromRGB(70, 170, 255) },
	{ id = "solar",     name = "Solarflare",    tier = "Legendary", body = Color3.fromRGB(40, 28, 18),  accent = Color3.fromRGB(255, 150, 30) },
	{ id = "toxin",     name = "Toxin",         tier = "Legendary", body = Color3.fromRGB(28, 35, 22),  accent = Color3.fromRGB(190, 255, 40) },

	-- ── Godly ──
	{ id = "galaxie",   name = "Galaxie",       tier = "Godly", body = Color3.fromRGB(30, 15, 60),  accent = Color3.fromRGB(150, 80, 255) },
	{ id = "drachen",   name = "Drachenglut",   tier = "Godly", body = Color3.fromRGB(50, 12, 12),  accent = Color3.fromRGB(255, 90, 30) },
	{ id = "frost",     name = "Frostgeist",    tier = "Godly", body = Color3.fromRGB(15, 35, 50),  accent = Color3.fromRGB(140, 235, 255) },

	-- ── Mythical ──
	{ id = "singularitaet", name = "Singularität", tier = "Mythical", body = Color3.fromRGB(10, 10, 14), accent = Color3.fromRGB(255, 255, 255) },
}

-- ── Abgeleitete Lookups ───────────────────────────────────────────────────────
Skins.BY_ID = {}
local tierCounts = {}
for _, skin in ipairs(Skins.CATALOG) do
	Skins.BY_ID[skin.id] = skin
	tierCounts[skin.tier] = (tierCounts[skin.tier] or 0) + 1
end

-- Effekt-Flags pro Tier (zentral, damit alle Skins eines Tiers konsistent sind)
function Skins.fxFor(tier)
	local order = Skins.TIERS[tier].order
	return {
		metallic  = order >= 2,   -- Reflectance
		neon      = order >= 3,   -- Akzent-Teile leuchten
		particles = order >= 3,   -- Funken am Lauf
		light     = order >= 3,   -- PointLight
		pulse     = order >= 4,   -- Farb-Puls (Client-Animation via Tag)
		trail     = order >= 4,   -- Lichtspur beim Laufen
		flash     = order >= 4,   -- Gegner-Screenflash beim Treffer
		rainbow   = order >= 5,   -- Regenbogen-Puls
	}
end

-- Drop-Chance eines einzelnen Skins in Prozent (für die Odds-Anzeige; Roblox
-- verlangt offengelegte Wahrscheinlichkeiten bei bezahlten Zufalls-Items).
function Skins.chanceOf(skinId, luckActive, luckMult)
	local skin = Skins.BY_ID[skinId]
	if not skin then return 0 end
	local total = 0
	for tierName, tier in pairs(Skins.TIERS) do
		local w = tier.weight
		if luckActive and tierName ~= "Common" then w = w * luckMult end
		total = total + w
	end
	local w = Skins.TIERS[skin.tier].weight
	if luckActive and skin.tier ~= "Common" then w = w * luckMult end
	return (w / total) * 100 / tierCounts[skin.tier]
end

-- Gewichteter Pull (Server). rng = Random-Instanz.
function Skins.roll(rng, luckActive, luckMult)
	local total = 0
	local weights = {}
	for tierName, tier in pairs(Skins.TIERS) do
		local w = tier.weight
		if luckActive and tierName ~= "Common" then w = w * luckMult end
		weights[tierName] = w
		total = total + w
	end
	local pick = rng:NextNumber() * total
	local chosenTier = "Common"
	for tierName, w in pairs(weights) do
		pick = pick - w
		if pick <= 0 then
			chosenTier = tierName
			break
		end
	end
	-- Innerhalb des Tiers: gleichverteilt
	local pool = {}
	for _, skin in ipairs(Skins.CATALOG) do
		if skin.tier == chosenTier then table.insert(pool, skin) end
	end
	return pool[rng:NextInteger(1, #pool)]
end

return Skins
