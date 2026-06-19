-- Assets.lua — Zentrales Register aller externen Roblox-Assets.
--
-- Jede ID wurde über die Roblox-APIs verifiziert (Typ korrekt + öffentlich
-- abrufbar, Stand 2026-06-11):
--   • SFX: "ProSoundEffects" (Robloxs lizenzfreie Sound-Library)
--   • Musik: "DistrokidOfficial"/"APMOfficial" (Robloxs lizenzierte Musik-Library)
-- Hinweis: Sniper-Sounds von normalen Usern sind seit dem Audio-Privacy-Update
-- meist privat und würden im Spiel NICHT laden — deshalb der verifizierte
-- Whip-Crack (Knall mit Hall) als Schuss-Sound, pro Tier gepitcht.

local Assets = {}

-- Das Waffen-Modell ist eine prozedurale AWP-Silhouette (SniperBuilder) —
-- nach mehreren Mesh-Anläufen (LoadAsset-Permissions, SpecialMesh-Fallstricke)
-- ist das die einzige Variante, die GARANTIERT überall korrekt aussieht und
-- sich pro Skin frei einfärben lässt.

Assets.SFX = {
	Shot      = "rbxassetid://9126213373",  -- Fallback: Whip Crack (verifiziert)
	GunBoom   = "rbxassetid://94191736",    -- Roblox-Gear-FireSound (garantiert) — Layer 1
	Boom      = "rbxassetid://9125404320",  -- Deep Boom Impact (verifiziert) — Layer 2
	Bolt      = "rbxassetid://9114004212",  -- Fallback: Crossbow Latch
	Magazine  = "rbxassetid://9113104176",  -- Ammo Magazine (Equip-Sound)
	EggCrack  = "rbxassetid://9113959337",  -- Crack Egg Crunchy 10
	EggCrack2 = "rbxassetid://9113959539",  -- Crack Egg Crunchy 12
	DrumRoll  = "rbxassetid://1846418712",  -- Drum Roll Off C (Hatch-Spannung)
	Chime     = "rbxassetid://9116395089",  -- Magic Glow Chime (Reveal/Win)
	ChimeSoft = "rbxassetid://9116394876",  -- Magic Glow Chime (UI/Unlock)
	Coin      = "rbxassetid://9113848490",  -- Coin Bounce (Credits)
	Teleport  = "rbxassetid://9116394545",  -- Magic Glow (Arena-Teleport)
	Whoosh    = "rbxassetid://9126284532",  -- Wood Swish (verifiziert — Slide)
}

-- Echte AWP-Sounds (CS-Ports) zuerst — wenn einer lädt, spielt der Client ihn
-- pur (authentisch). Lädt keiner, baut der Client den AWP-Knall als LAYERING
-- aus garantierten Sounds nach: Gewehr-Boom + Deep-Boom + Crack-Tail
-- (EffectsController.playShotSound prüft Assets.RESOLVED.Shot).
Assets.SFX_PREFERRED = {
	Shot = {
		"rbxassetid://138705939667182",  -- Awp_Fire (CS:GO-Port)
		"rbxassetid://131254751896361",  -- awp fire 1.6
	},
	Bolt = {
		"rbxassetid://133852631085337",  -- Awp_BoltPull (CS CZ:DS)
		"rbxassetid://140632128823885",  -- awp_boltforward
		"rbxassetid://94191778",         -- Trench-Rifle PumpSound (Roblox — garantiert)
	},
}

-- Merkt sich pro Key, ob eine bevorzugte ID geladen werden konnte
Assets.RESOLVED = {}

-- Client-seitig: bevorzugte IDs testen, erste ladbare gewinnt (sonst Fallback)
function Assets.resolveSfx()
	local ContentProvider = game:GetService("ContentProvider")
	for key, candidates in pairs(Assets.SFX_PREFERRED) do
		task.spawn(function()
			for _, id in ipairs(candidates) do
				local status = nil
				pcall(function()
					ContentProvider:PreloadAsync({ id }, function(_, fetchStatus)
						status = fetchStatus
					end)
				end)
				if status == Enum.AssetFetchStatus.Success then
					Assets.SFX[key] = id
					Assets.RESOLVED[key] = true
					return
				end
			end
			-- nichts ladbar → verifizierter Fallback bleibt aktiv
		end)
	end
end

Assets.MUSIC = {
	Lobby = {   -- Synthwave-Lounge
		"rbxassetid://139180277700549",  -- Calm Retro Wave
		"rbxassetid://140487226538429",  -- Dreams Across the Skyline
	},
	Arena = {   -- treibend
		"rbxassetid://117068758599157",  -- auraincrease
		"rbxassetid://1843819038",       -- Moving Drone 60 (APM)
	},
}

-- Eingebaute Partikel-Texturen (immer verfügbar, kein Lade-Risiko)
Assets.PARTICLES = {
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke    = "rbxasset://textures/particles/smoke_main.dds",
	Fire     = "rbxasset://textures/particles/fire_main.dds",
}

-- ── Helfer ────────────────────────────────────────────────────────────────────

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
	s.RollOffMaxDistance = 250
	if minPitch then
		s.PlaybackSpeed = minPitch + math.random() * ((maxPitch or minPitch) - minPitch)
	end
	s.Parent = p
	s:Play()
	game:GetService("Debris"):AddItem(p, 5)
	return s
end

function Assets.play2D(soundId, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	if pitch then s.PlaybackSpeed = pitch end
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 8)
	return s
end

function Assets.preloadList()
	local list = {}
	for _, id in pairs(Assets.SFX) do
		table.insert(list, id)
	end
	return list
end

return Assets
