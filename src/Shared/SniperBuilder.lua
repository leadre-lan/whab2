-- SniperBuilder.lua — Baut das Sniper-Modell für einen Skin (server-seitig,
-- damit JEDER den Skin sieht — der Flex ist der Kern des Spiels).
--
-- Zwei Bau-Pfade:
--  1) Mesh-Pfad: echtes AWP-Modell aus dem Creator Store. WeaponService lädt
--     und vermisst es beim Server-Start (setMeshInfo). Der Standard-Skin
--     behält die Original-Textur, alle anderen färben das Modell pro Tier.
--  2) Prozeduraler Fallback (Parts) — falls das Asset nicht laden konnte.
--
-- Konvention: Schussrichtung = Handle-lokal -Z.
local SniperBuilder = {}

local CollectionService = game:GetService("CollectionService")

local Skins  = require(script.Parent:WaitForChild("Skins"))
local Assets = require(script.Parent:WaitForChild("Assets"))

-- Vom WeaponService nach der Vermessung gesetzt:
-- { template = MeshPart, rot = CFrame (Mesh→Handle-Achsen), scale = number,
--   length = number (Studs nach Skalierung) }
local meshInfo = nil

function SniperBuilder.setMeshInfo(info)
	meshInfo = info
end

function SniperBuilder.hasMesh()
	return meshInfo ~= nil
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
	if props.name then p.Name = props.name end
	return p
end

-- Markiert ein Akzent-Teil für den client-seitigen Puls-Loop (Godly/Mythical).
-- Der Server animiert NICHTS — jeder Client pulst die getaggten Teile lokal.
local function tagPulse(part, baseColor, rainbow)
	part:SetAttribute("PulseR", baseColor.R)
	part:SetAttribute("PulseG", baseColor.G)
	part:SetAttribute("PulseB", baseColor.B)
	part:SetAttribute("PulseRainbow", rainbow == true)
	CollectionService:AddTag(part, "PulseFX")
end

-- ── Bau-Pfad 1: echtes AWP-Mesh ───────────────────────────────────────────────
local function buildMeshBody(handle, skin, fx)
	local body = meshInfo.template:Clone()
	body.Name = "Body"
	body.Size = meshInfo.template.Size * meshInfo.scale

	if not skin.keepTexture then
		body.TextureID = ""
		body.Color = skin.body
		body.Material = skin.material
			or (fx.metallic and Enum.Material.Metal or Enum.Material.SmoothPlastic)
		body.Reflectance = (fx.metallic and not fx.neon) and 0.3 or 0
	end

	-- Mesh-Mitte etwas vor/über den Griffpunkt (Handle hält am hinteren Drittel)
	weldTo(handle, body, CFrame.new(0, 0.12, -0.45) * meshInfo.rot)
	return -meshInfo.length / 2 - 0.55   -- Mündungs-Z (handle-lokal)
end

-- ── Bau-Pfad 2: prozeduraler Fallback (Parts) ─────────────────────────────────
local function buildProceduralBody(handle, skin, fx, accent)
	local bodyMat   = skin.material or (fx.metallic and Enum.Material.Metal or Enum.Material.SmoothPlastic)
	local accentMat = fx.neon and Enum.Material.Neon or bodyMat

	handle.Transparency = 0
	handle.Color = skin.body
	handle.Material = bodyMat

	-- Stock (hinten, leicht abfallend)
	weldTo(handle, mkPart({ size = Vector3.new(0.3, 0.52, 1.15), color = skin.body, material = bodyMat }),
		CFrame.new(0, -0.08, 1.62) * CFrame.Angles(math.rad(-4), 0, 0))
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.32, 0.5, 0.14), color = skin.accent, material = accentMat }),
		CFrame.new(0, -0.12, 2.2)))

	-- Lauf (Zylinderachse = X → um 90° gieren, damit er entlang Z liegt)
	accent(weldTo(handle, mkPart({ size = Vector3.new(2.5, 0.16, 0.16), color = skin.accent, material = accentMat, shape = Enum.PartType.Cylinder }),
		CFrame.new(0, 0.08, -2.25) * CFrame.Angles(0, math.rad(90), 0)))

	-- Scope (Rohr + Linse)
	weldTo(handle, mkPart({ size = Vector3.new(1.15, 0.2, 0.2), color = skin.body, material = bodyMat, shape = Enum.PartType.Cylinder }),
		CFrame.new(0, 0.45, -0.35) * CFrame.Angles(0, math.rad(90), 0))
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.05, 0.18, 0.18), color = skin.accent, material = fx.neon and Enum.Material.Neon or Enum.Material.Glass, shape = Enum.PartType.Cylinder, name = "Lens" }),
		CFrame.new(0, 0.45, -0.95) * CFrame.Angles(0, math.rad(90), 0)))
	for _, z in ipairs({ -0.7, 0.05 }) do
		weldTo(handle, mkPart({ size = Vector3.new(0.1, 0.18, 0.12), color = skin.body, material = bodyMat }),
			CFrame.new(0, 0.32, z))
	end

	-- Bolt (rechts)
	accent(weldTo(handle, mkPart({ size = Vector3.new(0.42, 0.1, 0.1), color = skin.accent, material = accentMat, shape = Enum.PartType.Cylinder, name = "Bolt" }),
		CFrame.new(0.3, 0.18, 0.35) * CFrame.Angles(0, 0, math.rad(-20))))

	-- Magazin + Griff (unten)
	weldTo(handle, mkPart({ size = Vector3.new(0.28, 0.5, 0.5), color = skin.body, material = bodyMat }),
		CFrame.new(0, -0.45, -0.25) * CFrame.Angles(math.rad(8), 0, 0))
	weldTo(handle, mkPart({ size = Vector3.new(0.26, 0.55, 0.34), color = skin.body, material = bodyMat }),
		CFrame.new(0, -0.45, 0.75) * CFrame.Angles(math.rad(-14), 0, 0))

	-- Seitliche Zier-Rails (Akzent)
	for side = -1, 1, 2 do
		accent(weldTo(handle, mkPart({ size = Vector3.new(0.04, 0.1, 1.4), color = skin.accent, material = accentMat }),
			CFrame.new(side * 0.2, 0.12, -0.2)))
	end

	return -3.55   -- Mündungs-Z (handle-lokal)
end

-- Baut das fertige Tool. mountTo = Backpack/Character übernimmt der Aufrufer.
function SniperBuilder.buildTool(skin)
	local fx = Skins.fxFor(skin.tier)
	local accentMat = fx.neon and Enum.Material.Neon or Enum.Material.Metal

	local tool = Instance.new("Tool")
	tool.Name = "Sniper"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = skin.name .. " [" .. skin.tier .. "]"
	tool.GripPos     = Vector3.new(0, -0.1, 0.5)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)
	tool:SetAttribute("SkinId", skin.id)
	tool:SetAttribute("SkinTier", skin.tier)

	-- Handle: unsichtbarer Griffpunkt (im Fallback-Pfad wird er zum Receiver)
	local handle = mkPart({ size = Vector3.new(0.34, 0.5, 2.2), color = skin.body, name = "Handle" })
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Parent = tool

	local function accent(part)
		if fx.pulse then tagPulse(part, skin.accent, fx.rainbow) end
		return part
	end

	local muzzleZ
	if meshInfo then
		muzzleZ = buildMeshBody(handle, skin, fx)
	else
		muzzleZ = buildProceduralBody(handle, skin, fx, accent)
	end

	-- Mündungs-Marker: Shot-Origin für Tracer + Träger für Partikel/Licht.
	-- Bei Legendary+ als sichtbarer Glow-Ring um den Lauf.
	local muzzle = mkPart({
		size = Vector3.new(0.12, 0.3, 0.3),
		color = skin.accent,
		material = accentMat,
		shape = Enum.PartType.Cylinder,
		name = "Muzzle",
	})
	muzzle.Transparency = fx.neon and 0.1 or 1
	accent(muzzle)
	weldTo(handle, muzzle, CFrame.new(0, 0.1, muzzleZ + 0.3) * CFrame.Angles(0, math.rad(90), 0))
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
		a0.Position = Vector3.new(0, 0.08, muzzleZ + 0.2)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0.08, muzzleZ + 2.4)
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
