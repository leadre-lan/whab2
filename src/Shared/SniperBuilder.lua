-- SniperBuilder.lua — Baut das Sniper-Modell für einen Skin (server-seitig,
-- damit JEDER den Skin sieht — der Flex ist der Kern des Spiels).
--
-- Basis ist IMMER das texturierte Gewehr-Mesh aus Assets.WEAPON (Roblox-eigenes
-- Asset → lädt garantiert, kein InsertService/LoadAsset nötig). Es wird per
-- SpecialMesh gerendert; Skins tönen die Textur über VertexColor — so behält
-- jede Variante echte Holz-/Metall-Texturdetails. Dazu kommt ein aufgesetztes
-- Scope (das Gear ist ein Langgewehr) und die Tier-Effekte.
--
-- Konvention: Schussrichtung = Handle-lokal -Z (Mesh-Mündung liegt nativ
-- entlang -Z — offline vermessen, keine Rotation nötig).
local SniperBuilder = {}

local CollectionService = game:GetService("CollectionService")

local Skins  = require(script.Parent:WaitForChild("Skins"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local TARGET_LEN = 4.8   -- Studs (Gesamtlänge des Gewehrs in der Hand)

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

-- VertexColor-Tönung aus der Skin-Farbe: multipliziert die Gewehr-Textur.
-- Werte > 1 hellen auf (Gold/Chrom), dunkle Skins geben den Moody-Look für
-- Neon-Tiers. keepTexture = Original (1,1,1).
local function tintFor(skin)
	if skin.keepTexture then
		return Vector3.new(1, 1, 1)
	end
	local c = skin.body
	return Vector3.new(0.3 + c.R * 1.7, 0.3 + c.G * 1.7, 0.3 + c.B * 1.7)
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

	-- Handle: unsichtbarer Griffpunkt
	local handle = mkPart({ size = Vector3.new(0.34, 0.5, 2.2), color = skin.body, name = "Handle" })
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Parent = tool

	local function accent(part)
		if fx.pulse then tagPulse(part, skin.accent, fx.rainbow) end
		return part
	end

	-- ── Gewehr-Körper: texturiertes Mesh (SpecialMesh + VertexColor-Tint) ──
	local meshScale = TARGET_LEN / Assets.WEAPON.length
	local body = mkPart({ size = Vector3.new(0.5, 1.2, TARGET_LEN), color = skin.body, name = "Body" })
	body.Transparency = 1   -- sichtbar ist nur das Mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "BodyMesh"
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = Assets.WEAPON.meshId
	mesh.TextureId = Assets.WEAPON.textureId
	mesh.Scale = Vector3.new(meshScale, meshScale, meshScale)
	mesh.VertexColor = tintFor(skin)
	mesh.Parent = body
	-- Mesh-Mitte etwas vor/über dem Griffpunkt (Hand liegt am Abzug/Receiver)
	weldTo(handle, body, CFrame.new(0, 0.1, -0.55))

	local muzzleZ = -0.55 - TARGET_LEN / 2   -- ≈ -2.95 (Laufspitze)
	local barrelY = 0.1 + Assets.WEAPON.barrelY

	-- ── Aufgesetztes Scope (macht aus dem Gewehr die Sniper) ──
	local scopeY = barrelY + 0.42
	weldTo(handle, mkPart({ size = Vector3.new(1.5, 0.24, 0.24), color = Color3.fromRGB(28, 28, 34),
		material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, name = "ScopeTube" }),
		CFrame.new(0, scopeY, -0.45) * CFrame.Angles(0, math.rad(90), 0))
	-- Linse vorn (Akzentfarbe) + Okular hinten
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.06, 0.22, 0.22), color = skin.accent,
		material = fx.neon and Enum.Material.Neon or Enum.Material.Glass,
		shape = Enum.PartType.Cylinder, name = "Lens" }),
		CFrame.new(0, scopeY, -1.24) * CFrame.Angles(0, math.rad(90), 0)))
	weldTo(handle, mkPart({ size = Vector3.new(0.08, 0.26, 0.26), color = Color3.fromRGB(20, 20, 24),
		material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }),
		CFrame.new(0, scopeY, 0.34) * CFrame.Angles(0, math.rad(90), 0))
	-- Scope-Füße
	for _, z in ipairs({ -0.85, 0.05 }) do
		weldTo(handle, mkPart({ size = Vector3.new(0.1, 0.34, 0.14), color = Color3.fromRGB(28, 28, 34),
			material = Enum.Material.Metal }),
			CFrame.new(0, scopeY - 0.22, z))
	end

	-- Seitliche Akzent-Rails am Receiver (tragen die Skin-Farbe sichtbar)
	for side = -1, 1, 2 do
		accent(weldTo(handle, mkPart({ size = Vector3.new(0.05, 0.12, 1.2), color = skin.accent,
			material = accentMat, transparency = fx.neon and 0 or 0.1 }),
			CFrame.new(side * 0.18, 0.18, 0.3)))
	end

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
