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
		health             = 10,
		reward             = 1,
		requiredSwordLevel = 1,
		respawnTime        = 3,
		brickColorName     = "Bright green",
		thickness          = 1.2,
		height             = 8,
	},
	[2] = {
		health             = 80,
		reward             = 15,
		requiredSwordLevel = 5,
		respawnTime        = 6,
		brickColorName     = "Dark green",
		thickness          = 1.5,
		height             = 10,
	},
	[3] = {
		health             = 500,
		reward             = 120,
		requiredSwordLevel = 12,
		respawnTime        = 10,
		brickColorName     = "Olive",
		thickness          = 1.8,
		height             = 12,
	},
	[4] = {
		health             = 2500,
		reward             = 600,
		requiredSwordLevel = 20,
		respawnTime        = 16,
		brickColorName     = "Sand green",
		thickness          = 2.1,
		height             = 14,
	},
	[5] = {
		health             = 8000,
		reward             = 2000,
		requiredSwordLevel = 30,
		respawnTime        = 25,
		brickColorName     = "Bright yellowish green",
		thickness          = 2.5,
		height             = 16,
	},
}

-- ============================================================
-- SWORDS  (10 levels)
-- cost = 0 for the starter sword; swingDelay in seconds
-- ============================================================
Config.SWORDS = {
	[1]  = { name = "Holzschwert",     damage = 1,    swingDelay = 0.80, cost = 0       },
	[2]  = { name = "Steinschwert",    damage = 5,    swingDelay = 0.75, cost = 50      },
	[3]  = { name = "Eisenschwert",    damage = 20,   swingDelay = 0.70, cost = 250     },
	[4]  = { name = "Goldschwert",     damage = 70,   swingDelay = 0.65, cost = 1200    },
	[5]  = { name = "Rubinschwert",    damage = 200,  swingDelay = 0.60, cost = 6000    },
	[6]  = { name = "Diamantschwert",  damage = 550,  swingDelay = 0.55, cost = 30000   },
	[7]  = { name = "Drachenschwert",  damage = 1200, swingDelay = 0.52, cost = 150000  },
	[8]  = { name = "Schattenschwert", damage = 2000, swingDelay = 0.48, cost = 600000  },
	[9]  = { name = "Himmelschwert",   damage = 2800, swingDelay = 0.44, cost = 1200000 },
	[10] = { name = "Uralt Schwert",   damage = 3500, swingDelay = 0.40, cost = 2500000 },
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
		name               = "Bambushain",
		requiredSwordLevel = 1,
		bambooTypeId       = 1,
		bambooCount        = 25,
		offset             = Vector3.new(0,   0, 0),
	},
	[2] = {
		name               = "Dunkler Hain",
		requiredSwordLevel = 5,
		bambooTypeId       = 2,
		bambooCount        = 25,
		offset             = Vector3.new(120, 0, 0),
	},
	[3] = {
		name               = "Olivenhain",
		requiredSwordLevel = 12,
		bambooTypeId       = 3,
		bambooCount        = 25,
		offset             = Vector3.new(240, 0, 0),
	},
	[4] = {
		name               = "Sandhain",
		requiredSwordLevel = 20,
		bambooTypeId       = 4,
		bambooCount        = 25,
		offset             = Vector3.new(360, 0, 0),
	},
	[5] = {
		name               = "Urwald",
		requiredSwordLevel = 30,
		bambooTypeId       = 5,
		bambooCount        = 25,
		offset             = Vector3.new(480, 0, 0),
	},
}

return Config
