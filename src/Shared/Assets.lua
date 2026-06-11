-- Assets.lua — Zentrales Register aller externen Roblox-Assets.
--
-- Jede ID hier wurde über die Roblox-APIs verifiziert (Typ + öffentliche
-- Verfügbarkeit, Stand 2026-06-11):
--   • Meshes/Texturen: offizielle Roblox-Classic-Assets (Creator "Roblox"),
--     Maße offline aus den Mesh-Dateien geparst — Skalierung/Achsen stimmen.
--   • SFX: "ProSoundEffects" (Robloxs lizenzfreie Sound-Library).
--   • Musik: "DistrokidOfficial"/"APMOfficial" (Robloxs lizenzierte Musik-
--     Library) + die alten, noch funktionierenden IDs als Fallback.
--
-- IDs austauschen: einfach hier ändern — kein Service-Code nötig.

local Assets = {}

-- ── Meshes (SpecialMesh/FileMesh — zur Laufzeit setzbar) ──────────────────────
-- axis  = Achse der Klinge in Mesh-Koordinaten (+Z bei beiden)
-- length = gerenderte Länge in Studs bei Scale = 1
-- handleZ = Z-Position der Griffmitte im Mesh (für den Weld-Offset)
Assets.MESHES = {
	-- "sword.mesh" by Roblox — das klassische Linked-Sword-Modell
	ClassicSword = {
		meshId    = "rbxassetid://12221720",
		textureId = "rbxasset://textures/SwordTexture.png",
		length    = 4.37,
		handleZ   = -1.5,
	},
	-- "Katana Mesh" + "Katana Texture" by Roblox
	Katana = {
		meshId    = "rbxassetid://11442510",
		textureId = "rbxassetid://11442524",
		length    = 2.93,
		handleZ   = -1.0,
	},
}

-- ── Sound-Effekte (alle kurz, alle öffentlich) ────────────────────────────────
Assets.SFX = {
	Swing        = "rbxassetid://9126284532",  -- Wood Swish Whoosh (schnell)
	Slice        = "rbxassetid://9116333867",  -- Machete Cutting Cactus (saftiger Schnitt)
	RockHit      = "rbxassetid://9118627392",  -- Rock Impact
	RockBreak    = "rbxassetid://9125869797",  -- Rock Drops/Smashes
	Anvil        = "rbxassetid://9113446174",  -- Blacksmith Anvil Hammer Hit
	MonsterHit   = "rbxassetid://9113980480",  -- Creature Roar/Growl (kurz)
	MonsterDeath = "rbxassetid://9113988071",  -- Creature Death Shriek
	Chime        = "rbxassetid://9116395089",  -- Magic Glow Chime (Level-Up)
	ChimeSoft    = "rbxassetid://9116394876",  -- Magic Glow Chime (Unlock)
	Coin         = "rbxassetid://9113848490",  -- Coin Bounce
	Teleport     = "rbxassetid://9116394545",  -- Magic Glow (kurz — Portal)
}

-- ── Musik pro Biom-Gruppe (erste ladbare ID gewinnt) ──────────────────────────
Assets.MUSIC = {
	Hub = {        -- ruhig, japanischer Garten
		"rbxassetid://89453444795932",   -- Koi Fish Dream Beneath Lotus Flowers
		"rbxassetid://9043887091",       -- Fallback (alt, verifiziert)
	},
	Forest = {     -- hell, entspannt (Grüner/Goldener Hain)
		"rbxassetid://98002463968288",   -- Forest Calm Ambient
		"rbxassetid://119364922573470",  -- Cherry Blossoms Falling on Still Water
		"rbxassetid://1843463175",       -- Fallback (alt, verifiziert)
	},
	Mystic = {     -- geheimnisvoll (Kristall/Schatten)
		"rbxassetid://106152951949961",  -- Mysterious Endeavour (APM)
		"rbxassetid://73731220283940",   -- Mysterious Magic (APM)
		"rbxassetid://1843463175",
	},
	Epic = {       -- treibend (Vulkan/Himmel)
		"rbxassetid://130204756191999",  -- Epic Inspirational Adventure
		"rbxassetid://113554213644551",  -- Fantastic Race (APM)
		"rbxassetid://9046515361",       -- Fallback (alt, verifiziert)
	},
}

-- ── Partikel-Texturen (eingebaute rbxasset-Inhalte — immer verfügbar) ─────────
Assets.PARTICLES = {
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke    = "rbxasset://textures/particles/smoke_main.dds",
	Fire     = "rbxasset://textures/particles/fire_main.dds",
}

-- ── Helfer ────────────────────────────────────────────────────────────────────

-- 3D-Sound an einer Weltposition abspielen (Wegwerf-Part als Träger)
function Assets.playAt(position, soundId, volume, minPitch, maxPitch)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Position = position
	p.Parent = workspace

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.8
	s.RollOffMaxDistance = 90
	if minPitch then
		s.PlaybackSpeed = minPitch + math.random() * ((maxPitch or minPitch) - minPitch)
	end
	s.Parent = p
	s:Play()
	game:GetService("Debris"):AddItem(p, 4)
	return s
end

-- 2D-Sound (UI / global)
function Assets.play2D(soundId, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	if pitch then s.PlaybackSpeed = pitch end
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 6)
	return s
end

-- Alles, was der Client vorladen sollte (Meshes, Texturen, SFX)
function Assets.preloadList()
	local list = {}
	for _, m in pairs(Assets.MESHES) do
		table.insert(list, m.meshId)
		table.insert(list, m.textureId)
	end
	for _, id in pairs(Assets.SFX) do
		table.insert(list, id)
	end
	return list
end

return Assets
