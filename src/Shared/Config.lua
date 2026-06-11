-- Config.lua
-- Place as a ModuleScript in ReplicatedStorage
-- Shared configuration for Bamboo Slasher Simulator

local Config = {}

-- ============================================================
-- BAMBOO TYPES
-- Each type maps to a zone. Health, reward, and required sword
-- level scale up with zone number.
-- ============================================================
Config.BAMBOO_TYPES = {
	[1] = {
		health            = 10,
		reward            = 1,
		requiredSwordLevel = 1,
		respawnTime       = 3,
		brickColorName    = "Bright green",
		thickness         = 1.2,
		height            = 8,
	},
	[2] = {
		health            = 100,
		reward            = 10,
		requiredSwordLevel = 5,
		respawnTime       = 6,
		brickColorName    = "Medium green",
		thickness         = 1.5,
		height            = 10,
	},
	[3] = {
		health            = 800,
		reward            = 80,
		requiredSwordLevel = 12,
		respawnTime       = 10,
		brickColorName    = "Bright yellow",
		thickness         = 1.8,
		height            = 12,
	},
	[4] = {
		health            = 4000,
		reward            = 500,
		requiredSwordLevel = 20,
		respawnTime       = 16,
		brickColorName    = "Reddish brown",
		thickness         = 2.2,
		height            = 14,
	},
	[5] = {
		health            = 8000,
		reward            = 2000,
		requiredSwordLevel = 30,
		respawnTime       = 25,
		brickColorName    = "Dark orange",
		thickness         = 2.8,
		height            = 16,
	},
}

-- ============================================================
-- SWORDS  (10 levels)
-- cost = 0 for the starter sword; swingDelay in seconds
-- ============================================================
Config.SWORDS = {
	[1]  = { name = "Holzschwert",    damage = 1,    swingDelay = 0.80, cost = 0       },
	[2]  = { name = "Steinschwert",   damage = 5,    swingDelay = 0.75, cost = 50      },
	[3]  = { name = "Eisenschwert",   damage = 20,   swingDelay = 0.70, cost = 300     },
	[4]  = { name = "Goldschwert",    damage = 60,   swingDelay = 0.65, cost = 1500    },
	[5]  = { name = "Diamantschwert", damage = 150,  swingDelay = 0.60, cost = 8000    },
	[6]  = { name = "Obsidianschwert",damage = 400,  swingDelay = 0.55, cost = 40000   },
	[7]  = { name = "Drachenschwert", damage = 900,  swingDelay = 0.52, cost = 150000  },
	[8]  = { name = "Kristallschwert",damage = 1800, swingDelay = 0.48, cost = 500000  },
	[9]  = { name = "Schattenschwert",damage = 2800, swingDelay = 0.44, cost = 1200000 },
	[10] = { name = "Uralt Schwert",  damage = 3500, swingDelay = 0.40, cost = 2500000 },
}

-- ============================================================
-- ZONES  (5 zones)
-- bambooCount  = number of stalks spawned per zone
-- offset       = world-space origin of the zone platform centre
-- Zones are laid out 120 studs apart on the X axis so they
-- never overlap (platform is 100 studs wide).
-- ============================================================
Config.ZONES = {
	[1] = {
		name               = "Gruner Hain",
		requiredSwordLevel = 1,
		bambooTypeId       = 1,
		bambooCount        = 25,
		offset             = Vector3.new(0,   0, 0),
	},
	[2] = {
		name               = "Nebel Wald",
		requiredSwordLevel = 5,
		bambooTypeId       = 2,
		bambooCount        = 25,
		offset             = Vector3.new(120, 0, 0),
	},
	[3] = {
		name               = "Goldener Forst",
		requiredSwordLevel = 12,
		bambooTypeId       = 3,
		bambooCount        = 25,
		offset             = Vector3.new(240, 0, 0),
	},
	[4] = {
		name               = "Feuer Dickicht",
		requiredSwordLevel = 20,
		bambooTypeId       = 4,
		bambooCount        = 25,
		offset             = Vector3.new(360, 0, 0),
	},
	[5] = {
		name               = "Ewiges Paradies",
		requiredSwordLevel = 30,
		bambooTypeId       = 5,
		bambooCount        = 25,
		offset             = Vector3.new(480, 0, 0),
	},
}

return Config
