-- SniperBuilder.lua — Baut das Sniper-Modell für einen Skin (server-seitig,
-- damit JEDER den Skin sieht — der Flex ist der Kern des Spiels).
--
-- Das Modell ist eine prozedurale AWP-Silhouette in CS:GO-Proportionen:
-- skeletierter Schaft mit Daumenloch, Receiver mit Bolt, Magazin, langer
-- Handschutz, freiliegender Lauf mit Mündungsbremse und das große Scope mit
-- Objektivglocke + Türmen. Skins färben Furniture (body) und Akzente (accent);
-- Metallteile bleiben dunkel. Bewusst KEIN Mesh: nach LoadAsset-Permissions
-- und SpecialMesh-Fallstricken ist das die Variante, die überall gleich
-- aussieht und sich sauber tinten lässt.
--
-- Konvention: Schussrichtung = Handle-lokal -Z.
local SniperBuilder = {}

local CollectionService = game:GetService("CollectionService")

local Skins  = require(script.Parent:WaitForChild("Skins"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local METAL = Color3.fromRGB(46, 47, 54)   -- Lauf/Scope/Bolt (immer dunkel)

-- ── Echtes AWP-Mesh (optional, via Studio-Template) ───────────────────────────
-- Zieht man das Toolbox-AWP nach ReplicatedStorage/Assets/Awp, extrahiert der
-- WeaponService Mesh-/Textur-ID + Maße + Lauf-Richtung und setzt awpInfo:
-- { meshId, textureId, scale, rot (CFrame), length, height }
-- Dann rendert JEDER Skin das echte texturierte AWP-Modell (VertexColor-Tint).
local awpInfo = nil

function SniperBuilder.setAwpInfo(info)
	awpInfo = info
end

function SniperBuilder.hasAwpMesh()
	return awpInfo ~= nil
end

local function weldTo(handle, part, offset)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = part
	part.CFrame = handle.CFrame * offset
	part.Parent = handle.Parent
	return part
end

local function mkPart(props)
	local p = Instance.new("Part")
	p.Size = props.size
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color
	if props.shape then p.Shape = props.shape end
	if props.reflectance then p.Reflectance = props.reflectance end
	if props.transparency then p.Transparency = props.transparency end
	if props.name then p.Name = props.name end
	return p
end

-- Markiert ein Akzent-Teil für den client-seitigen Puls-Loop (Godly/Mythical).
local function tagPulse(part, baseColor, rainbow)
	part:SetAttribute("PulseR", baseColor.R)
	part:SetAttribute("PulseG", baseColor.G)
	part:SetAttribute("PulseB", baseColor.B)
	part:SetAttribute("PulseRainbow", rainbow == true)
	CollectionService:AddTag(part, "PulseFX")
end

-- Baut das fertige Tool. mountTo = Backpack/Character übernimmt der Aufrufer.
function SniperBuilder.buildTool(skin)
	local fx = Skins.fxFor(skin.tier)
	local accentMat = fx.neon and Enum.Material.Neon or Enum.Material.Metal

	local tool = Instance.new("Tool")
	tool.Name = "Sniper"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = skin.name .. " [" .. Skins.TIERS[skin.tier].label .. "]"
		.. (skin.flavor and (" — \"" .. skin.flavor .. "\"") or "")
	tool.GripPos     = Vector3.new(0, -0.1, 0.5)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)
	tool:SetAttribute("SkinId", skin.id)
	tool:SetAttribute("SkinTier", skin.tier)

	-- Handle: unsichtbarer Griffpunkt (Massless — sonst zieht die Waffe am
	-- Charakter und die Lauf-Animation wirkt zappelig)
	local handle = mkPart({ size = Vector3.new(0.34, 0.5, 2.2), color = skin.body, name = "Handle" })
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local function accent(part)
		if fx.pulse then tagPulse(part, skin.accent, fx.rainbow) end
		return part
	end

	local muzzleZ, barrelY

	if awpInfo then
		-- ── Echtes AWP-Mesh (Studio-Template): MeshPart-Klon ──
		-- Die ECHTE AWP-Textur bleibt drauf; der Skin tönt sie nur (MeshPart.Color
		-- multipliziert mit der Textur). Prozedurale Volltexturen sahen auf dem
		-- UV-Atlas des Meshes kaputt aus — Tint erhält alle Details (Panels,
		-- Schrauben, Verschattung) und färbt trotzdem sichtbar um.
		local body = awpInfo.template:Clone()
		body:ClearAllChildren()   -- Kit-Templates schleppen Welds/SurfaceAppearance mit
		body.Name = "Body"
		body.Size = awpInfo.nativeSize * awpInfo.scale
		body.Material = Enum.Material.Metal   -- PBR-Highlights statt mattem Plastik
		body:SetAttribute("SkinId", skin.id)
		if skin.id == "standard" then
			body.Color = Color3.new(1, 1, 1)              -- Original-Look pur
		else
			body.Color = skin.body:Lerp(Color3.new(1, 1, 1), 0.25)
		end
		weldTo(handle, body, CFrame.new(0, 0.05, -0.6) * awpInfo.rot)

		muzzleZ = -0.6 - awpInfo.length / 2 + 0.05
		barrelY = 0.12

		-- Aufgesetztes Scope (das gebakte Mesh ist der nackte AWP-Körper)
		local scopeY = 0.58
		local METALDARK = Color3.fromRGB(30, 30, 36)
		weldTo(handle, mkPart({ size = Vector3.new(1.5, 0.26, 0.26), color = METALDARK,
			material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, name = "ScopeTube" }),
			CFrame.new(0, scopeY, -0.2) * CFrame.Angles(0, math.rad(90), 0))
		weldTo(handle, mkPart({ size = Vector3.new(0.38, 0.4, 0.4), color = METALDARK,
			material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, name = "ScopeBell" }),
			CFrame.new(0, scopeY, -1.04) * CFrame.Angles(0, math.rad(90), 0))
		weldTo(handle, mkPart({ size = Vector3.new(0.26, 0.3, 0.3), color = METALDARK,
			material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, name = "ScopeEye" }),
			CFrame.new(0, scopeY, 0.66) * CFrame.Angles(0, math.rad(90), 0))
		accent(weldTo(handle, mkPart({ size = Vector3.new(0.06, 0.3, 0.3), color = skin.accent,
			material = fx.neon and Enum.Material.Neon or Enum.Material.Glass,
			shape = Enum.PartType.Cylinder, name = "Lens" }),
			CFrame.new(0, scopeY, -1.25) * CFrame.Angles(0, math.rad(90), 0)))
		for _, z in ipairs({ -0.65, 0.35 }) do
			weldTo(handle, mkPart({ size = Vector3.new(0.1, 0.3, 0.14), color = METALDARK,
				material = Enum.Material.Metal }),
				CFrame.new(0, scopeY - 0.2, z))
		end

		-- Akzent: kurzer Glow-Strip am Vorderschaft (feste Position — die
		-- berechnete Mesh-Höhe hat je nach Modell durch die Waffe geclippt)
		accent(weldTo(handle, mkPart({
			size = Vector3.new(0.06, 0.06, 1.5),
			color = skin.accent, material = accentMat,
		}), CFrame.new(0, -0.38, -1.3)))
	else
	-- ── Part-Fallback: AWP-Körper (CS:GO-Proportionen, gebaut entlang -Z) ──
	local furnMat  = skin.material or (fx.metallic and Enum.Material.Metal or Enum.Material.SmoothPlastic)
	local furnRefl = (fx.metallic and not fx.neon) and 0.25 or 0
	local function furniture(size, cf, name)
		local p = mkPart({ size = size, color = skin.body, material = furnMat, reflectance = furnRefl, name = name })
		return weldTo(handle, p, cf)
	end
	local function metal(size, cf, opts)
		opts = opts or {}
		local p = mkPart({ size = size, color = METAL, material = Enum.Material.Metal,
			shape = opts.shape, name = opts.name })
		return weldTo(handle, p, cf)
	end

	-- Schaft: skeletiert mit Daumenloch (oberer + unterer Holm, Wangenauflage,
	-- Schulterplatte) — die markante AWP-Silhouette
	furniture(Vector3.new(0.26, 0.3, 1.25), CFrame.new(0, 0.22, 1.85))                                   -- oberer Holm
	furniture(Vector3.new(0.24, 0.24, 1.35), CFrame.new(0, -0.34, 1.78) * CFrame.Angles(math.rad(-14), 0, 0)) -- unterer Holm
	furniture(Vector3.new(0.3, 0.2, 0.75),  CFrame.new(0, 0.45, 1.7), "CheekRest")                       -- Wangenauflage
	furniture(Vector3.new(0.3, 0.95, 0.22), CFrame.new(0, -0.02, 2.5))                                   -- Schulterplatte
	furniture(Vector3.new(0.26, 0.62, 0.3), CFrame.new(0, -0.18, 1.06) * CFrame.Angles(math.rad(12), 0, 0)) -- Pistolengriff

	-- Receiver + Abzugsbügel
	furniture(Vector3.new(0.34, 0.46, 1.6), CFrame.new(0, 0.12, 0.12), "Receiver")
	metal(Vector3.new(0.05, 0.06, 0.5), CFrame.new(0, -0.22, 0.55))                                      -- Bügel unten
	metal(Vector3.new(0.05, 0.22, 0.06), CFrame.new(0, -0.14, 0.32))                                     -- Bügel vorn

	-- Bolt (rechts, mit Kugel-Knauf)
	metal(Vector3.new(0.45, 0.1, 0.1), CFrame.new(0.22, 0.3, 0.42) * CFrame.Angles(0, 0, math.rad(-32)),
		{ shape = Enum.PartType.Cylinder, name = "Bolt" })
	metal(Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.4, 0.2, 0.42), { shape = Enum.PartType.Ball })

	-- Magazin (leicht angewinkelte Box unterm Receiver)
	metal(Vector3.new(0.26, 0.42, 0.62), CFrame.new(0, -0.36, -0.18) * CFrame.Angles(math.rad(-8), 0, 0),
		{ name = "Magazine" })

	-- Handschutz (lang, AWP-typisch kantig) + Akzent-Rails an den Seiten
	furniture(Vector3.new(0.32, 0.36, 2.0), CFrame.new(0, 0.08, -1.55), "Handguard")
	for side = -1, 1, 2 do
		accent(weldTo(handle, mkPart({ size = Vector3.new(0.05, 0.12, 1.7), color = skin.accent,
			material = accentMat }),
			CFrame.new(side * 0.185, 0.1, -1.45)))
	end
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.34, 0.05, 1.7), color = skin.accent,
		material = accentMat }),
		CFrame.new(0, -0.12, -1.45)))

	-- Freiliegender Lauf + Mündungsbremse
	metal(Vector3.new(1.45, 0.14, 0.14), CFrame.new(0, 0.18, -3.2) * CFrame.Angles(0, math.rad(90), 0),
		{ shape = Enum.PartType.Cylinder, name = "Barrel" })
	metal(Vector3.new(0.42, 0.24, 0.24), CFrame.new(0, 0.18, -3.95) * CFrame.Angles(0, math.rad(90), 0),
		{ shape = Enum.PartType.Cylinder, name = "MuzzleBrake" })
	for side = -1, 1, 2 do
		metal(Vector3.new(0.06, 0.1, 0.26), CFrame.new(side * 0.13, 0.18, -3.95))
	end

	muzzleZ = -4.16
	barrelY = 0.18

	-- ── Das große AWP-Scope ──
	local scopeY = 0.62
	metal(Vector3.new(1.5, 0.26, 0.26), CFrame.new(0, scopeY, 0.0) * CFrame.Angles(0, math.rad(90), 0),
		{ shape = Enum.PartType.Cylinder, name = "ScopeTube" })
	metal(Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, scopeY, -0.85) * CFrame.Angles(0, math.rad(90), 0),
		{ shape = Enum.PartType.Cylinder, name = "ScopeBell" })
	metal(Vector3.new(0.28, 0.32, 0.32), CFrame.new(0, scopeY, 0.85) * CFrame.Angles(0, math.rad(90), 0),
		{ shape = Enum.PartType.Cylinder, name = "ScopeEye" })
	-- Verstelltürme (oben + rechts)
	metal(Vector3.new(0.14, 0.12, 0.12), CFrame.new(0, scopeY + 0.2, 0.12) * CFrame.Angles(0, 0, math.rad(90)),
		{ shape = Enum.PartType.Cylinder })
	metal(Vector3.new(0.14, 0.12, 0.12), CFrame.new(0.2, scopeY, 0.12), { shape = Enum.PartType.Cylinder })
	-- Linse vorn (Akzentfarbe — leuchtet ab Legendary) + Scope-Füße
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.06, 0.3, 0.3), color = skin.accent,
		material = fx.neon and Enum.Material.Neon or Enum.Material.Glass,
		shape = Enum.PartType.Cylinder, name = "Lens" }),
		CFrame.new(0, scopeY, -1.07) * CFrame.Angles(0, math.rad(90), 0)))
	for _, z in ipairs({ -0.55, 0.5 }) do
		metal(Vector3.new(0.12, 0.3, 0.16), CFrame.new(0, scopeY - 0.22, z))
	end
	end   -- Ende Part-Fallback

	-- ── Mündung: Marker (Shot-Origin) + Glow-Ring bei Legendary+ ──
	local muzzle = mkPart({
		size = Vector3.new(0.12, 0.3, 0.3),
		color = skin.accent,
		material = accentMat,
		shape = Enum.PartType.Cylinder,
		name = "Muzzle",
	})
	muzzle.Transparency = fx.neon and 0.1 or 1
	accent(muzzle)
	weldTo(handle, muzzle, CFrame.new(0, barrelY, muzzleZ + 0.18) * CFrame.Angles(0, math.rad(90), 0))
	local muzzleAtt = Instance.new("Attachment")
	muzzleAtt.Name = "MuzzleAtt"
	muzzleAtt.Parent = muzzle

	-- ── Tier-Effekte ──
	if fx.particles then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = Assets.PARTICLES.Sparkles
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(0.4, 0.9)
		pe.Speed = NumberRange.new(0.4, 1.2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.12)
		pe.Color = ColorSequence.new(skin.accent)
		pe.LightEmission = 0.9
		pe.Parent = muzzleAtt
	end

	if fx.light then
		local light = Instance.new("PointLight")
		light.Color = skin.accent
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = muzzle
	end

	if fx.trail then
		-- Lichtspur beim Laufen: Trail über die Lauflänge, immer aktiv
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, barrelY, muzzleZ + 0.2)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, barrelY, muzzleZ + 2.4)
		a1.Parent = handle
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(skin.accent)
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.Lifetime = 0.45
		trail.LightEmission = 1
		trail.WidthScale = NumberSequence.new(1, 0.2)
		trail.Parent = handle
	end

	-- Schuss-/Bolt-Sounds spielt der CLIENT über das ShotFired-Event ab
	-- (AWP-Sound mit Fallback-Kette, siehe Assets.resolveSfx). Hier nur Equip:
	local equip = Instance.new("Sound")
	equip.Name = "EquipSound"
	equip.SoundId = Assets.SFX.Magazine
	equip.Volume = 0.5
	equip.Parent = handle

	return tool
end

return SniperBuilder
