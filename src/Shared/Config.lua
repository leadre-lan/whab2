-- Config.lua (ModuleScript in ReplicatedStorage)
-- Shared configuration for Bamboo Slasher

local Config = {}

-- ─── Bamboo Types (1-5) ────────────────────────────────────────────────────────
Config.BAMBOO_TYPES = {
	[1] = {
		name        = "Junger Bambus",
		health      = 3,
		coins       = 1,
		color       = Color3.fromRGB(134, 200, 90),
		thickness   = 1.2,
		height      = 8,
		respawnTime = 4,
	},
	[2] = {
		name        = "Gruener Bambus",
		health      = 6,
		coins       = 2,
		color       = Color3.fromRGB(72, 160, 60),
		thickness   = 1.5,
		height      = 11,
		respawnTime = 6,
	},
	[3] = {
		name        = "Goldener Bambus",
		health      = 12,
		coins       = 5,
		color       = Color3.fromRGB(210, 185, 50),
		thickness   = 1.8,
		height      = 14,
		respawnTime = 10,
	},
	[4] = {
		name        = "Roter Bambus",
		health      = 22,
		coins       = 10,
		color       = Color3.fromRGB(190, 60, 50),
		thickness   = 2.0,
		height      = 17,
		respawnTime = 15,
	},
	[5] = {
		name        = "Kristall Bambus",
		health      = 40,
		coins       = 20,
		color       = Color3.fromRGB(100, 210, 230),
		thickness   = 2.3,
		height      = 20,
		respawnTime = 20,
	},
}

-- ─── Swords (levels 1-10) ─────────────────────────────────────────────────────
Config.SWORDS = {
	[1]  = { name = "Holzschwert",        damage = 1,   cost = 0,     color = Color3.fromRGB(180, 130, 70)  },
	[2]  = { name = "Steinschwert",       damage = 2,   cost = 25,    color = Color3.fromRGB(160, 160, 160) },
	[3]  = { name = "Eisenschwert",       damage = 4,   cost = 75,    color = Color3.fromRGB(200, 210, 220) },
	[4]  = { name = "Goldschwert",        damage = 7,   cost = 200,   color = Color3.fromRGB(240, 200, 50)  },
	[5]  = { name = "Diamantschwert",     damage = 12,  cost = 500,   color = Color3.fromRGB(80, 220, 230)  },
	[6]  = { name = "Rubin Klinge",       damage = 20,  cost = 1200,  color = Color3.fromRGB(220, 50, 70)   },
	[7]  = { name = "Smaragdklinge",      damage = 32,  cost = 3000,  color = Color3.fromRGB(50, 200, 100)  },
	[8]  = { name = "Mondklinge",         damage = 50,  cost = 7500,  color = Color3.fromRGB(180, 160, 240) },
	[9]  = { name = "Sonnenklinge",       damage = 80,  cost = 18000, color = Color3.fromRGB(255, 180, 50)  },
	[10] = { name = "Legendaere Klinge",  damage = 130, cost = 50000, color = Color3.fromRGB(255, 80, 200)  },
}

-- Global swing cooldown in seconds
Config.SWING_DELAY = 0.5

-- ─── Zones (5 zones, 130 studs apart on X axis) ───────────────────────────────
Config.ZONES = {
	[1] = {
		name          = "Anfaenger Wald",
		bambooTypeId  = 1,
		count         = 18,
		requiredLevel = 1,
		offsetX       = 0,
	},
	[2] = {
		name          = "Gruener Hain",
		bambooTypeId  = 2,
		count         = 20,
		requiredLevel = 2,
		offsetX       = 130,
	},
	[3] = {
		name          = "Goldener Hain",
		bambooTypeId  = 3,
		count         = 22,
		requiredLevel = 4,
		offsetX       = 260,
	},
	[4] = {
		name          = "Rotes Dickicht",
		bambooTypeId  = 4,
		count         = 20,
		requiredLevel = 6,
		offsetX       = 390,
	},
	[5] = {
		name          = "Kristallwald",
		bambooTypeId  = 5,
		count         = 18,
		requiredLevel = 8,
		offsetX       = 520,
	},
}

return Config
