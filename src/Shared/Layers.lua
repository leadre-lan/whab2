-- Layers.lua — 6 hand-crafted biomes + procedurally generated layers 7-12
local Layers = {}

Layers.DATA = {
	[1] = {
		name          = "Grüner Hain",
		requiredLevel = 1,
		offsetX       = 5000,
		bambooColor   = Color3.fromRGB(72, 185, 62),
		bambooThick   = 1.4,
		bambooH       = 14,
		nodeColor     = Color3.fromRGB(42, 115, 36),
		platform      = Color3.fromRGB(80, 118, 50),
		fog = { color = Color3.fromRGB(138, 178, 128), start = 80, finish = 250 },
		ambient       = Color3.fromRGB(118, 142, 108),
		glowColor     = Color3.fromRGB(75, 210, 75),
		monsterName   = "Bambusgeist",
		lighting      = { clockTime = 13.5, atmoDensity = 0.42, atmoColor = Color3.fromRGB(170, 210, 160) },
		theme         = "forest",   -- steuert Prop-Bauweise im WorldGenerator
		-- gen = endless biome via chunk streaming (seed → reproducible world)
		gen = { seed = 20260611, material = Enum.Material.LeafyGrass },
	},
	[2] = {
		name          = "Goldener Hain",
		requiredLevel = 2,
		offsetX       = 10000,
		bambooColor   = Color3.fromRGB(212, 188, 52),
		bambooThick   = 1.7,
		bambooH       = 18,
		nodeColor     = Color3.fromRGB(148, 128, 32),
		platform      = Color3.fromRGB(128, 108, 50),
		fog = { color = Color3.fromRGB(198, 175, 118), start = 75, finish = 235 },
		ambient       = Color3.fromRGB(158, 148, 90),
		glowColor     = Color3.fromRGB(220, 190, 45),
		monsterName   = "Wildschwein",
		theme         = "gold",
		gen = { seed = 20260612, material = Enum.Material.Sand },
	},
	[3] = {
		name          = "Kristallwald",
		requiredLevel = 5,
		offsetX       = 15000,
		bambooColor   = Color3.fromRGB(98, 212, 232),
		bambooThick   = 2.0,
		bambooH       = 22,
		nodeColor     = Color3.fromRGB(58, 148, 172),
		platform      = Color3.fromRGB(65, 118, 140),
		fog = { color = Color3.fromRGB(98, 198, 218), start = 68, finish = 218 },
		ambient       = Color3.fromRGB(78, 178, 198),
		glowColor     = Color3.fromRGB(80, 220, 235),
		monsterName   = "Kristallkäfer",
		theme         = "crystal",
		gen = { seed = 20260613, material = Enum.Material.Glacier },
	},
	[4] = {
		name          = "Schattendickicht",
		requiredLevel = 10,
		offsetX       = 20000,
		bambooColor   = Color3.fromRGB(78, 58, 112),
		bambooThick   = 2.4,
		bambooH       = 26,
		nodeColor     = Color3.fromRGB(48, 34, 76),
		platform      = Color3.fromRGB(38, 34, 54),
		fog = { color = Color3.fromRGB(55, 45, 88), start = 55, finish = 175 },
		ambient       = Color3.fromRGB(55, 45, 88),
		glowColor     = Color3.fromRGB(165, 80, 225),
		monsterName   = "Schatten-Ninja",
		theme         = "shadow",
		gen = { seed = 20260614, material = Enum.Material.Mud },
	},
	[5] = {
		name          = "Vulkanhain",
		requiredLevel = 18,
		offsetX       = 25000,
		bambooColor   = Color3.fromRGB(198, 78, 28),
		bambooThick   = 2.8,
		bambooH       = 30,
		nodeColor     = Color3.fromRGB(138, 48, 18),
		platform      = Color3.fromRGB(78, 38, 28),
		fog = { color = Color3.fromRGB(178, 88, 38), start = 55, finish = 195 },
		ambient       = Color3.fromRGB(148, 78, 48),
		glowColor     = Color3.fromRGB(255, 118, 35),
		monsterName   = "Lava-Golem",
		theme         = "lava",
		gen = { seed = 20260615, material = Enum.Material.Basalt },
		boss          = { name = "Aschegeneral", hpMult = 12, dmgMult = 2.5 },
	},
	[6] = {
		name          = "Himmelsgarten",
		requiredLevel = 30,
		offsetX       = 30000,
		bambooColor   = Color3.fromRGB(198, 228, 255),
		bambooThick   = 3.2,
		bambooH       = 36,
		nodeColor     = Color3.fromRGB(148, 178, 218),
		platform      = Color3.fromRGB(158, 198, 238),
		fog = { color = Color3.fromRGB(198, 228, 255), start = 95, finish = 295 },
		ambient       = Color3.fromRGB(178, 208, 238),
		glowColor     = Color3.fromRGB(195, 228, 255),
		monsterName   = "Wächter",
		theme         = "sky",
		gen = { seed = 20260616, material = Enum.Material.Snow },
		boss          = { name = "Bambus-Drache", hpMult = 20, dmgMult = 3.5 },
	},
}

-- ── Procedural layers 7-12 (deterministic — identical on server and client) ──
local PREFIXES = { "Uralter", "Verlorener", "Ewiger", "Astraler", "Mystischer", "Verfluchter" }
local SUFFIXES = { "Dschungel", "Hain", "Abgrund", "Nebelwald", "Pfad", "Garten" }
local MONSTERS = { "Urgeist", "Nebelschleicher", "Leerenwurm", "Sternwächter", "Astralbestie", "Chronos-Echo" }

local procRng = Random.new(1337)
for i = 7, 12 do
	local idx = i - 6
	local hue = (i * 0.137) % 1   -- golden-ratio hue walk → distinct colors
	local baseColor = Color3.fromHSV(hue, 0.65, 0.85)
	local darkColor = Color3.fromHSV(hue, 0.7, 0.45)

	Layers.DATA[i] = {
		name          = PREFIXES[idx] .. " " .. SUFFIXES[((i * 3) % #SUFFIXES) + 1],
		requiredLevel = 30 + idx * 15,    -- 45, 60, 75, 90, 105, 120
		offsetX       = 30000 + idx * 5000,
		bambooColor   = baseColor,
		bambooThick   = 3.2 + idx * 0.3,
		bambooH       = 36 + idx * 4,
		nodeColor     = darkColor,
		platform      = darkColor:Lerp(Color3.fromRGB(40, 40, 40), 0.4),
		fog = {
			color  = baseColor:Lerp(Color3.fromRGB(128, 128, 128), 0.5),
			start  = 60,
			finish = 200,
		},
		ambient       = baseColor:Lerp(Color3.fromRGB(100, 100, 100), 0.6),
		glowColor     = baseColor,
		monsterName   = MONSTERS[idx],
		theme         = ({ "forest", "gold", "crystal", "shadow", "lava", "sky" })[idx],
		gen = {
			seed     = 20260620 + i,
			material = ({ Enum.Material.LeafyGrass, Enum.Material.Sand, Enum.Material.Glacier,
				Enum.Material.Mud, Enum.Material.Basalt, Enum.Material.Snow })[idx],
		},
		boss = (i % 3 == 0) and {
			name = "Titan: " .. MONSTERS[idx],
			hpMult = 15 + idx * 5, dmgMult = 3 + idx * 0.5,
		} or nil,
	}
end

return Layers
