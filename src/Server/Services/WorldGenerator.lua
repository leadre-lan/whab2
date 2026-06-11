-- WorldGenerator.lua — Reusable procedural layer generator (see GAME_DESIGN 6.5)
--
-- Input:  a gen-config (seed, size, material, prop densities, lighting preset)
-- Output: terrain (Perlin-noise heightmap via the Terrain API), organic prop
--         scattering (clusters + clearings, never rows), 2-3 landmarks,
--         invisible borders (terrain rises into cliffs at the edge), and the
--         interactive spawn positions (bamboo/ore) for WorldService to wire up.
--
-- The player must NEVER see the edge of the world: the border cliffs rise
-- beyond the fog distance defined in the layer's lighting preset.

local WorldGenerator = {}

local RS      = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain

local VOXEL = 4

-- ── Asset templates ───────────────────────────────────────────────────────────
-- Drop Toolbox models into ReplicatedStorage/Assets/Trees (or /Rocks) and the
-- generator clones them instead of building procedural props. No assets folder
-- → procedural fallback, the game always works.
local function spawnTemplate(folderName, rng, pos, scale, parent)
	local assets = RS:FindFirstChild("Assets")
	local tf = assets and assets:FindFirstChild(folderName)
	if not tf then return nil end
	local kids = tf:GetChildren()
	if #kids == 0 then return nil end

	local m = kids[rng:NextInteger(1, #kids)]:Clone()
	if m:IsA("Model") then
		pcall(function() m:ScaleTo(scale) end)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		local height = m:GetExtentsSize().Y
		m:PivotTo(CFrame.new(pos + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	elseif m:IsA("BasePart") then
		m.Anchored = true
		m.CFrame = CFrame.new(pos + Vector3.new(0, m.Size.Y / 2, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	m.Parent = parent
	return m
end

-- Ellipsoid helper: a Block part + sphere mesh renders as a squashed organic
-- blob instead of a perfect (blocky-looking) ball
local function ellipsoid(size, cframe, material, color, parent)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = parent
	return p
end

-- ── Heightmap factory ─────────────────────────────────────────────────────────
-- Returns heightAt(x, z) in world coords. Includes:
--   • rolling hills (two noise octaves)
--   • border rise into cliffs (quadratic past the playable edge)
--   • flattened spawn pad in the center
--   • lake depression + landmark mounds
local function makeHeightFunc(cfg, landmarks)
	local seed   = cfg.seed
	local cx, cz = cfg.center.X, cfg.center.Z
	local half   = cfg.size / 2
	local edge   = half - 140          -- playable area ends here, cliffs begin

	return function(x, z)
		local dx, dz = x - cx, z - cz

		-- Base rolling terrain: large soft hills + small detail
		local h = 12
			+ 13 * math.noise(x / 150, z / 150, seed)
			+ 4.5 * math.noise(x / 45, z / 45, seed * 0.73 + 17)

		-- Border: rise into impassable cliff ring (invisible world edge)
		local r = math.max(math.abs(dx), math.abs(dz))
		if r > edge then
			local t = (r - edge) / 140
			h += t * t * 110
		end

		-- Lake: smooth depression
		local lake = landmarks.lake
		if lake then
			local d = math.sqrt((x - lake.X) ^ 2 + (z - lake.Z) ^ 2)
			if d < 34 then
				local t = 1 - d / 34
				h -= t * t * 13
			end
		end

		-- Big tree: gentle mound
		local tree = landmarks.bigTree
		if tree then
			local d = math.sqrt((x - tree.X) ^ 2 + (z - tree.Z) ^ 2)
			if d < 30 then
				h += (1 - d / 30) * 4
			end
		end

		-- Spawn pad: flatten the center so teleports land cleanly
		local dc = math.sqrt(dx * dx + dz * dz)
		if dc < 35 then
			local t = math.clamp(dc / 35, 0, 1)
			h = 12 + (h - 12) * (t * t)
		end

		return h
	end
end

-- ── Terrain writer (chunked WriteVoxels) ─────────────────────────────────────
local function writeTerrain(cfg, heightAt)
	local material = cfg.material or Enum.Material.Grass
	local cx, cz   = cfg.center.X, cfg.center.Z
	local half     = cfg.size / 2

	local CHUNK = 80                       -- studs per WriteVoxels call (multiple of 4)
	local yMin, yMax = -16, 144            -- vertical voxel range (covers cliffs)
	local ySize = (yMax - yMin) / VOXEL

	-- WriteVoxels regions MUST be voxel-grid-aligned, otherwise the array
	-- dimensions won't match the region and the call errors. Snap the whole
	-- area to multiples of 4 first.
	local x0 = math.floor((cx - half) / VOXEL) * VOXEL
	local x1 = math.ceil((cx + half) / VOXEL) * VOXEL
	local z0 = math.floor((cz - half) / VOXEL) * VOXEL
	local z1 = math.ceil((cz + half) / VOXEL) * VOXEL

	for chunkX = x0, x1 - 1, CHUNK do
		local xEnd = math.min(chunkX + CHUNK, x1)
		for chunkZ = z0, z1 - 1, CHUNK do
			local zEnd = math.min(chunkZ + CHUNK, z1)
			local region = Region3.new(
				Vector3.new(chunkX, yMin, chunkZ),
				Vector3.new(xEnd, yMax, zEnd))

			local xCount = (xEnd - chunkX) / VOXEL
			local zCount = (zEnd - chunkZ) / VOXEL

			local materials = {}
			local occupancy = {}
			for xi = 1, xCount do
				materials[xi] = {}
				occupancy[xi] = {}
				for yi = 1, ySize do
					materials[xi][yi] = {}
					occupancy[xi][yi] = {}
				end
			end

			for xi = 1, xCount do
				local wx = chunkX + (xi - 0.5) * VOXEL
				for zi = 1, zCount do
					local wz = chunkZ + (zi - 0.5) * VOXEL
					local h = heightAt(wx, wz)
					for yi = 1, ySize do
						local wy = yMin + (yi - 0.5) * VOXEL
						local occ = math.clamp((h - wy) / VOXEL + 0.5, 0, 1)
						occupancy[xi][yi][zi] = occ
						materials[xi][yi][zi] = occ > 0 and material or Enum.Material.Air
					end
				end
			end

			Terrain:WriteVoxels(region, VOXEL, materials, occupancy)
		end
		task.wait()   -- yield between chunk columns so the server stays responsive
	end
end

-- ── Decorative prop builders (theme-aware) ────────────────────────────────────
-- Jedes Biom hat eine eigene Vegetations-Sprache statt überall derselben
-- grünen Blob-Bäume: forest/gold = Laubbäume, crystal = Kristallformationen,
-- shadow = tote Bäume + Leuchtpilze, lava = verkohlte Dornen + Glutrisse,
-- sky = Blütenbäume mit fallenden Blütenblättern.

local function buildLeafTree(rng, pos, scale, parent, leafColor, golden)
	local tH = 9 * scale
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size  = Vector3.new(tH, 1.5 * scale, 1.5 * scale)
	trunk.CFrame = CFrame.new(pos.X, pos.Y + tH / 2, pos.Z)
		* CFrame.Angles(
			math.rad(rng:NextNumber(-4, 4)),       -- slight tilt
			0,
			math.rad(90 + rng:NextNumber(-4, 4)))
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(92, 62, 38)
	trunk.Anchored = true
	trunk.Parent = parent

	-- Organic canopy: 3 squashed, offset blobs instead of perfect balls
	for c = 1, 3 do
		local w = (7.2 - c * 1.4) * scale
		ellipsoid(
			Vector3.new(w, w * rng:NextNumber(0.55, 0.75), w),
			CFrame.new(
					pos.X + rng:NextNumber(-1.6, 1.6),
					pos.Y + tH - 0.5 + (c - 1) * 1.7 * scale,
					pos.Z + rng:NextNumber(-1.6, 1.6))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-9, 9)), rng:NextNumber(0, math.pi),
					math.rad(rng:NextNumber(-9, 9))),
			Enum.Material.Grass,
			leafColor:Lerp(Color3.fromRGB(40, 90, 35), rng:NextNumber(0, 0.4)),
			parent)
	end

	-- Goldener Hain: ein paar glühende "Früchte" in der Krone
	if golden then
		for _ = 1, rng:NextInteger(2, 4) do
			local fruit = Instance.new("Part")
			fruit.Shape = Enum.PartType.Ball
			fruit.Size = Vector3.new(0.5, 0.5, 0.5) * scale
			fruit.Position = pos + Vector3.new(
				rng:NextNumber(-3, 3) * scale,
				tH + rng:NextNumber(-1, 2.5) * scale,
				rng:NextNumber(-3, 3) * scale)
			fruit.Material = Enum.Material.Neon
			fruit.Color = Color3.fromRGB(255, 214, 70)
			fruit.Anchored = true
			fruit.CanCollide = false
			fruit.CastShadow = false
			fruit.Parent = parent
		end
	end
end

local function buildCrystalCluster(rng, pos, scale, parent, glowColor)
	-- 3-5 schief stehende Neon-Prismen, gemeinsame Lichtquelle
	local count = rng:NextInteger(3, 5)
	local main = nil
	for i = 1, count do
		local h = (i == 1 and rng:NextNumber(7, 11) or rng:NextNumber(2.5, 6)) * scale
		local w = h * rng:NextNumber(0.18, 0.3)
		local c = Instance.new("Part")
		c.Size = Vector3.new(w, h, w)
		c.CFrame = CFrame.new(
				pos.X + (i == 1 and 0 or rng:NextNumber(-2.2, 2.2) * scale),
				pos.Y + h * 0.38,
				pos.Z + (i == 1 and 0 or rng:NextNumber(-2.2, 2.2) * scale))
			* CFrame.Angles(
				math.rad(rng:NextNumber(-16, 16)),
				rng:NextNumber(0, math.pi),
				math.rad(45 + rng:NextNumber(-16, 16)))
		c.Material = Enum.Material.Neon
		c.Color = glowColor:Lerp(Color3.fromRGB(255, 255, 255), rng:NextNumber(0, 0.35))
		c.Transparency = 0.12
		c.Anchored = true
		c.CanCollide = (i == 1)
		c.Parent = parent
		if i == 1 then main = c end
	end
	if main then
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Range = 14 * scale
		light.Brightness = 0.7
		light.Parent = main
	end
end

local function buildDeadTree(rng, pos, scale, parent)
	local tH = 8 * scale
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(tH, 1.1 * scale, 1.1 * scale)
	trunk.CFrame = CFrame.new(pos.X, pos.Y + tH / 2, pos.Z)
		* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(90 + rng:NextNumber(-6, 6)))
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(48, 40, 36)
	trunk.Anchored = true
	trunk.Parent = parent

	-- Kahle, verdrehte Äste statt einer Krone
	for _ = 1, rng:NextInteger(3, 5) do
		local bL = rng:NextNumber(2.5, 5) * scale
		local ang = rng:NextNumber(0, math.pi * 2)
		local branch = Instance.new("Part")
		branch.Shape = Enum.PartType.Cylinder
		branch.Size = Vector3.new(bL, 0.45 * scale, 0.45 * scale)
		branch.CFrame = CFrame.new(
				pos.X + math.cos(ang) * bL * 0.4,
				pos.Y + tH * rng:NextNumber(0.55, 0.95),
				pos.Z + math.sin(ang) * bL * 0.4)
			* CFrame.Angles(0, -ang, math.rad(rng:NextNumber(15, 55)))
		branch.Material = Enum.Material.Wood
		branch.Color = Color3.fromRGB(42, 35, 32)
		branch.Anchored = true
		branch.CanCollide = false
		branch.Parent = parent
	end
end

local function buildGlowMushroom(rng, pos, scale, parent, glowColor)
	local sH = rng:NextNumber(1.2, 2.4) * scale
	local stem = Instance.new("Part")
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(sH, 0.5 * scale, 0.5 * scale)
	stem.CFrame = CFrame.new(pos.X, pos.Y + sH / 2, pos.Z)
		* CFrame.Angles(0, 0, math.rad(90 + rng:NextNumber(-8, 8)))
	stem.Material = Enum.Material.SmoothPlastic
	stem.Color = Color3.fromRGB(225, 218, 235)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Parent = parent

	local cap = ellipsoid(
		Vector3.new(1.7, 1.0, 1.7) * scale,
		CFrame.new(pos.X, pos.Y + sH + 0.25 * scale, pos.Z),
		Enum.Material.Neon, glowColor, parent)
	cap.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Range = 9 * scale
	light.Brightness = 0.55
	light.Parent = cap
end

local function buildCharredSpike(rng, pos, scale, parent)
	-- Verkohlter Dornbaum: dunkler Kegel + glühender Riss am Fuß
	local tH = rng:NextNumber(7, 11) * scale
	local spike = Instance.new("Part")
	spike.Size = Vector3.new(1.6 * scale, tH, 1.6 * scale)
	spike.CFrame = CFrame.new(pos.X, pos.Y + tH / 2, pos.Z)
		* CFrame.Angles(
			math.rad(rng:NextNumber(-7, 7)),
			rng:NextNumber(0, math.pi),
			math.rad(rng:NextNumber(-7, 7)))
	spike.Material = Enum.Material.Basalt
	spike.Color = Color3.fromRGB(32, 28, 28)
	spike.Anchored = true
	spike.Parent = parent
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = spike

	local crack = Instance.new("Part")
	crack.Size = Vector3.new(0.5 * scale, 1.6 * scale, 0.5 * scale)
	crack.Position = pos + Vector3.new(
		rng:NextNumber(-0.6, 0.6), 0.6 * scale, rng:NextNumber(-0.6, 0.6))
	crack.Material = Enum.Material.Neon
	crack.Color = Color3.fromRGB(255, 110, 30)
	crack.Anchored = true
	crack.CanCollide = false
	crack.CastShadow = false
	crack.Parent = parent
end

local function buildBlossomTree(rng, pos, scale, parent, withPetals)
	local tH = 9 * scale
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(tH, 1.3 * scale, 1.3 * scale)
	trunk.CFrame = CFrame.new(pos.X, pos.Y + tH / 2, pos.Z)
		* CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(90 + rng:NextNumber(-5, 5)))
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(122, 102, 96)
	trunk.Anchored = true
	trunk.Parent = parent

	local petalColor = Color3.fromRGB(248, 198, 222)
	for c = 1, 3 do
		local w = (7.5 - c * 1.5) * scale
		local blob = ellipsoid(
			Vector3.new(w, w * rng:NextNumber(0.5, 0.65), w),
			CFrame.new(
					pos.X + rng:NextNumber(-1.8, 1.8),
					pos.Y + tH - 0.5 + (c - 1) * 1.6 * scale,
					pos.Z + rng:NextNumber(-1.8, 1.8))
				* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi), 0),
			Enum.Material.Grass,
			petalColor:Lerp(Color3.fromRGB(255, 246, 250), rng:NextNumber(0, 0.5)),
			parent)

		-- Fallende Blütenblätter nur an manchen Bäumen (Performance)
		if withPetals and c == 1 then
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 1.6
			pe.Lifetime = NumberRange.new(3, 5)
			pe.Speed = NumberRange.new(0.5, 1.2)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.Acceleration = Vector3.new(0.4, -1.6, 0.2)
			pe.Size = NumberSequence.new(0.22)
			pe.Color = ColorSequence.new(petalColor)
			pe.LightEmission = 0.25
			pe.Parent = blob
		end
	end
end

local function makeTree(rng, pos, scale, parent, leafColor, theme)
	-- Prefer a real asset if the user dropped one into ReplicatedStorage/Assets/Trees
	if spawnTemplate("Trees", rng, pos, scale, parent) then return end

	if theme == "crystal" then
		buildCrystalCluster(rng, pos, scale, parent, leafColor)
	elseif theme == "shadow" then
		if rng:NextNumber() < 0.3 then
			buildGlowMushroom(rng, pos, scale * 1.4, parent, leafColor)
		else
			buildDeadTree(rng, pos, scale, parent)
		end
	elseif theme == "lava" then
		buildCharredSpike(rng, pos, scale, parent)
	elseif theme == "sky" then
		buildBlossomTree(rng, pos, scale, parent, rng:NextNumber() < 0.3)
	else
		buildLeafTree(rng, pos, scale, parent, leafColor, theme == "gold")
	end
end

local THEME_ROCK = {
	forest  = { material = Enum.Material.Slate,   tint = nil },
	gold    = { material = Enum.Material.Sandstone, tint = Color3.fromRGB(178, 152, 105) },
	crystal = { material = Enum.Material.Glacier, tint = Color3.fromRGB(168, 205, 218) },
	shadow  = { material = Enum.Material.Slate,   tint = Color3.fromRGB(62, 54, 78) },
	lava    = { material = Enum.Material.Basalt,  tint = Color3.fromRGB(45, 38, 38) },
	sky     = { material = Enum.Material.Marble,  tint = Color3.fromRGB(212, 222, 238) },
}

local function makeBoulder(rng, pos, scale, parent, theme)
	if spawnTemplate("Rocks", rng, pos, scale, parent) then return end

	local style = THEME_ROCK[theme] or THEME_ROCK.forest
	-- Two overlapping squashed blobs read as one organic rock
	local g = rng:NextInteger(95, 140)
	local color = style.tint
		and style.tint:Lerp(Color3.fromRGB(g, g, g), 0.3)
		or Color3.fromRGB(g, g, g)
	for i = 1, 2 do
		local sz = Vector3.new(
			rng:NextNumber(2.2, 4.5),
			rng:NextNumber(1.4, 2.6),
			rng:NextNumber(2.2, 4.5)) * scale * (i == 2 and 0.6 or 1)
		local blob = ellipsoid(sz,
			CFrame.new(
					pos.X + (i - 1) * rng:NextNumber(-1.4, 1.4),
					pos.Y + sz.Y * 0.3,
					pos.Z + (i - 1) * rng:NextNumber(-1.4, 1.4))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-10, 10))),
			style.material, color, parent)
		blob.CanCollide = (i == 1)   -- main blob blocks movement like before
	end

	-- Vulkan-Felsen glimmen an einer Stelle
	if theme == "lava" and rng:NextNumber() < 0.4 then
		local ember = Instance.new("Part")
		ember.Size = Vector3.new(0.7, 0.25, 0.7) * scale
		ember.Position = pos + Vector3.new(rng:NextNumber(-1, 1), 0.4 * scale, rng:NextNumber(-1, 1))
		ember.Material = Enum.Material.Neon
		ember.Color = Color3.fromRGB(255, 96, 24)
		ember.Anchored = true
		ember.CanCollide = false
		ember.CastShadow = false
		ember.Parent = parent
	end
end

-- Bodendeko: Grasbüschel/Blumen (forest, gold, sky) bzw. Glutfunken (lava)
local function makeGroundTuft(rng, pos, parent, leafColor, theme)
	if theme == "lava" then
		local ember = Instance.new("Part")
		ember.Size = Vector3.new(0.35, 0.35, 0.35)
		ember.Position = pos + Vector3.new(0, 0.2, 0)
		ember.Material = Enum.Material.Neon
		ember.Color = Color3.fromRGB(255, 120, 40)
		ember.Anchored = true
		ember.CanCollide = false
		ember.CastShadow = false
		ember.Parent = parent
		return
	end
	if theme == "crystal" or theme == "shadow" then
		-- kleine Leucht-Splitter am Boden
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.3, rng:NextNumber(0.5, 1.1), 0.3)
		shard.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, math.pi), math.rad(45))
		shard.Material = Enum.Material.Neon
		shard.Color = leafColor
		shard.Transparency = 0.25
		shard.Anchored = true
		shard.CanCollide = false
		shard.CastShadow = false
		shard.Parent = parent
		return
	end

	local tuftH = rng:NextNumber(0.6, 1.4)
	local tuft = Instance.new("Part")
	tuft.Shape = Enum.PartType.Cylinder
	tuft.Size = Vector3.new(tuftH, 0.2, 0.2)
	tuft.CFrame = CFrame.new(pos + Vector3.new(0, tuftH / 2, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90 + rng:NextNumber(-18, 18)))
	tuft.Material = Enum.Material.Grass
	tuft.Color = leafColor:Lerp(Color3.fromRGB(48, 130, 38), 0.5)
	tuft.Anchored = true
	tuft.CanCollide = false
	tuft.CastShadow = false
	tuft.Parent = parent

	-- gelegentlich eine Blüte obendrauf
	if rng:NextNumber() < 0.3 then
		local bloom = Instance.new("Part")
		bloom.Shape = Enum.PartType.Ball
		bloom.Size = Vector3.new(0.34, 0.34, 0.34)
		bloom.Position = pos + Vector3.new(0, tuftH + 0.1, 0)
		bloom.Material = Enum.Material.Neon
		bloom.Color = ({
			Color3.fromRGB(255, 120, 160),
			Color3.fromRGB(255, 214, 70),
			Color3.fromRGB(160, 160, 255),
		})[rng:NextInteger(1, 3)]
		bloom.Anchored = true
		bloom.CanCollide = false
		bloom.CastShadow = false
		bloom.Parent = parent
	end
end

-- ── Landmark builders ─────────────────────────────────────────────────────────
local function buildBigTree(rng, pos, parent, leafColor)
	-- Ancient tree: thick tilted trunk, huge layered canopy
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size  = Vector3.new(34, 7, 7)
	trunk.CFrame = CFrame.new(pos.X, pos.Y + 17, pos.Z)
		* CFrame.Angles(math.rad(3), 0, math.rad(90 + rng:NextNumber(-3, 3)))
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(82, 56, 34)
	trunk.Anchored = true
	trunk.Parent = parent

	-- Root flares
	for a = 0, 4 do
		local ang = a / 5 * math.pi * 2
		local root = Instance.new("Part")
		root.Size = Vector3.new(2.4, 3.5, 7)
		root.CFrame = CFrame.new(
				pos.X + math.cos(ang) * 4.5,
				pos.Y + 1.2,
				pos.Z + math.sin(ang) * 4.5)
			* CFrame.Angles(math.rad(-22), -ang + math.rad(90), 0)
		root.Material = Enum.Material.Wood
		root.Color = Color3.fromRGB(75, 50, 30)
		root.Anchored = true
		root.Parent = parent
	end

	for c = 1, 4 do
		local s = 27 - c * 4.5
		ellipsoid(
			Vector3.new(s, s * rng:NextNumber(0.55, 0.7), s),
			CFrame.new(
					pos.X + rng:NextNumber(-4, 4),
					pos.Y + 28 + c * 3.5,
					pos.Z + rng:NextNumber(-4, 4))
				* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi), 0),
			Enum.Material.Grass,
			leafColor:Lerp(Color3.fromRGB(40, 90, 35), rng:NextNumber(0, 0.3)),
			parent)
	end

	-- Fireflies / glow
	for _ = 1, 6 do
		local fly = Instance.new("Part")
		fly.Size = Vector3.new(0.4, 0.4, 0.4)
		fly.Position = pos + Vector3.new(
			rng:NextNumber(-10, 10),
			rng:NextNumber(8, 26),
			rng:NextNumber(-10, 10))
		fly.Material = Enum.Material.Neon
		fly.Color = Color3.fromRGB(220, 255, 150)
		fly.Anchored = true
		fly.CanCollide = false
		fly.CastShadow = false
		fly.Parent = parent
	end
end

local function buildRockFormation(rng, pos, parent)
	-- Circle of large standing stones with a flat boulder pile in the middle
	for a = 0, 5 do
		local ang = a / 6 * math.pi * 2 + rng:NextNumber(0, 0.4)
		local d   = rng:NextNumber(9, 14)
		local g   = rng:NextInteger(95, 130)
		local stone = Instance.new("Part")
		stone.Size = Vector3.new(
			rng:NextNumber(3, 5),
			rng:NextNumber(8, 14),
			rng:NextNumber(2.5, 4))
		stone.CFrame = CFrame.new(
				pos.X + math.cos(ang) * d,
				pos.Y + stone.Size.Y * 0.42,
				pos.Z + math.sin(ang) * d)
			* CFrame.Angles(
				math.rad(rng:NextNumber(-8, 8)),
				rng:NextNumber(0, math.pi),
				math.rad(rng:NextNumber(-8, 8)))
		stone.Material = Enum.Material.Slate
		stone.Color = Color3.fromRGB(g, g, g)
		stone.Anchored = true
		stone.Parent = parent
	end
	for _ = 1, 4 do
		makeBoulder(rng, pos + Vector3.new(
			rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), 1.4, parent, "forest")
	end
end

local function buildLake(pos, heightAt)
	-- Water disc inside the terrain bowl (depression carved by heightAt)
	local floorY = heightAt(pos.X, pos.Z)
	Terrain:FillCylinder(
		CFrame.new(pos.X, floorY + 3, pos.Z),
		5, 24, Enum.Material.Water)
end

-- ── Organic scattering ────────────────────────────────────────────────────────
-- Cluster mask: noise > threshold = dense cluster, noise < -0.25 = clearing.
local function scatterPositions(cfg, heightAt, landmarks, count, clusterScale, seedOffset)
	local rng  = Random.new(cfg.seed + seedOffset)
	local cx, cz = cfg.center.X, cfg.center.Z
	local half = cfg.size / 2
	local margin = 170          -- stay inside the cliff ring

	local spots = {}
	local attempts = 0
	while #spots < count and attempts < count * 30 do
		attempts += 1
		local x = cx + rng:NextNumber(-(half - margin), half - margin)
		local z = cz + rng:NextNumber(-(half - margin), half - margin)

		-- Cluster/clearing mask
		local mask = math.noise(x / clusterScale, z / clusterScale, cfg.seed * 1.31 + seedOffset)
		if mask < -0.05 then continue end                       -- clearing → skip
		if mask < 0.18 and rng:NextNumber() > 0.35 then continue end  -- sparse zone

		-- Keep landmarks clear
		local tooClose = false
		for _, lm in pairs(landmarks) do
			local d = math.sqrt((x - lm.X) ^ 2 + (z - lm.Z) ^ 2)
			if d < 38 then tooClose = true break end
		end
		if tooClose then continue end

		-- Keep the spawn pad clear
		if math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) < 30 then continue end

		-- Min spacing to other spots of the same kind (tight → dense clusters)
		for _, s in ipairs(spots) do
			if (Vector3.new(x, 0, z) - Vector3.new(s.pos.X, 0, s.pos.Z)).Magnitude < 4.5 then
				tooClose = true
				break
			end
		end
		if tooClose then continue end

		table.insert(spots, {
			pos   = Vector3.new(x, heightAt(x, z), z),
			scale = rng:NextNumber(0.8, 1.3),
			rot   = rng:NextNumber(0, math.pi * 2),
		})
	end
	return spots
end

-- ── Public: generate a full layer ────────────────────────────────────────────
-- cfg = {
--   seed      = number,
--   center    = Vector3 (Y ignored),
--   size      = number (>= 800),
--   material  = Enum.Material,
--   layer     = Layers.DATA entry (colors),
--   bambooCount, oreCount, treeCount, boulderCount = numbers,
-- }
-- Returns { folder, spawnPoint, bambooSpots, oreSpots, landmarks, camps }
function WorldGenerator.generate(cfg)
	local rng = Random.new(cfg.seed)
	local cx, cz = cfg.center.X, cfg.center.Z

	-- 1) Pick landmark positions (spread around the center, min 160 apart)
	local landmarks = {}
	local function pickLandmarkPos(minR, maxR)
		for _ = 1, 40 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d   = rng:NextNumber(minR, maxR)
			local p   = Vector3.new(cx + math.cos(ang) * d, 0, cz + math.sin(ang) * d)
			local ok = true
			for _, lm in pairs(landmarks) do
				if (p - Vector3.new(lm.X, 0, lm.Z)).Magnitude < 160 then
					ok = false
					break
				end
			end
			if ok then return p end
		end
		return Vector3.new(cx + minR, 0, cz)
	end
	landmarks.lake          = pickLandmarkPos(120, 250)
	landmarks.bigTree       = pickLandmarkPos(110, 250)
	landmarks.rockFormation = pickLandmarkPos(110, 250)

	-- 2) Heightmap (landmark-aware) + terrain
	local heightAt = makeHeightFunc(cfg, landmarks)
	writeTerrain(cfg, heightAt)
	Terrain.Decoration = true   -- animated grass on Grass material

	-- 3) Folder for all props of this layer
	local folder = Instance.new("Model")
	folder.Name = "Gen_" .. (cfg.layer and cfg.layer.name or "Layer")
	folder.Parent = workspace

	-- 4) Build landmarks
	local leafColor = (cfg.layer and cfg.layer.bambooColor or Color3.fromRGB(72, 185, 62))
		:Lerp(Color3.fromRGB(50, 130, 45), 0.5)

	buildLake(landmarks.lake, heightAt)
	buildBigTree(rng,
		Vector3.new(landmarks.bigTree.X, heightAt(landmarks.bigTree.X, landmarks.bigTree.Z), landmarks.bigTree.Z),
		folder, leafColor)
	buildRockFormation(rng,
		Vector3.new(landmarks.rockFormation.X, heightAt(landmarks.rockFormation.X, landmarks.rockFormation.Z), landmarks.rockFormation.Z),
		folder)

	-- 5) Decorative scattering (trees + boulders), clustered, varied
	local theme = cfg.layer and cfg.layer.theme or "forest"
	local treeSpots = scatterPositions(cfg, heightAt, landmarks, cfg.treeCount or 90, 110, 500)
	for _, s in ipairs(treeSpots) do
		makeTree(rng, s.pos, s.scale, folder, leafColor, theme)
	end
	local boulderSpots = scatterPositions(cfg, heightAt, landmarks, cfg.boulderCount or 30, 90, 900)
	for _, s in ipairs(boulderSpots) do
		makeBoulder(rng, s.pos, s.scale, folder, theme)
	end

	-- 6) Interactive spots for WorldService (bamboo clusters + ore)
	local bambooSpots = scatterPositions(cfg, heightAt, landmarks, cfg.bambooCount or 120, 70, 1300)

	-- Ore: 60% clustered around the rock formation, rest scattered
	local oreSpots = {}
	local oreCount = cfg.oreCount or 16
	local nearRock = math.floor(oreCount * 0.6)
	local rf = landmarks.rockFormation
	for _ = 1, nearRock do
		local ang = rng:NextNumber(0, math.pi * 2)
		local d   = rng:NextNumber(18, 55)
		local x, z = rf.X + math.cos(ang) * d, rf.Z + math.sin(ang) * d
		table.insert(oreSpots, {
			pos = Vector3.new(x, heightAt(x, z), z),
			scale = rng:NextNumber(0.8, 1.3),
		})
	end
	for _, s in ipairs(scatterPositions(cfg, heightAt, landmarks, oreCount - nearRock, 100, 1700)) do
		table.insert(oreSpots, s)
	end

	-- 7) Monster camp positions (coupled to landmarks → exploration pays off)
	local camps = {}
	for _, lm in ipairs({ landmarks.bigTree, landmarks.rockFormation }) do
		for _ = 1, 2 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d   = rng:NextNumber(25, 50)
			local x, z = lm.X + math.cos(ang) * d, lm.Z + math.sin(ang) * d
			table.insert(camps, Vector3.new(x, heightAt(x, z), z))
		end
	end

	local spawnPoint = Vector3.new(cx, heightAt(cx, cz) + 4, cz)

	return {
		folder      = folder,
		spawnPoint  = spawnPoint,
		bambooSpots = bambooSpots,
		oreSpots    = oreSpots,
		landmarks   = landmarks,
		camps       = camps,
		heightAt    = heightAt,
	}
end

-- ════ Infinite biome mode (Minecraft-style chunk streaming) ═══════════════════
-- Terrain + props are generated in CHUNK×CHUNK pieces around the players at
-- runtime, deterministically from the seed: a chunk always rebuilds exactly
-- the same way, so far-away props can be despawned and rebuilt on revisit.

WorldGenerator.CHUNK = 80

-- Landmark builders, exported for WorldService (placed once at the layer center)
WorldGenerator.buildBigTree       = buildBigTree
WorldGenerator.buildRockFormation = buildRockFormation

function WorldGenerator.makeInfiniteHeightFunc(cfg)
	local seed   = cfg.seed
	local cx, cz = cfg.center.X, cfg.center.Z
	return function(x, z)
		-- Rolling hills, NO border cliffs — the biome never ends
		local h = 12
			+ 13 * math.noise(x / 150, z / 150, seed)
			+ 4.5 * math.noise(x / 45, z / 45, seed * 0.73 + 17)
		-- Flat spawn pad at the center so teleports land cleanly
		local dx, dz = x - cx, z - cz
		local dc = math.sqrt(dx * dx + dz * dz)
		if dc < 35 then
			local t = math.clamp(dc / 35, 0, 1)
			h = 12 + (h - 12) * (t * t)
		end
		return h
	end
end

-- Write one voxel-aligned terrain chunk (ci/cj are integer chunk indices)
function WorldGenerator.writeChunkTerrain(heightAt, material, ci, cj)
	local CHUNK  = WorldGenerator.CHUNK
	local x0, z0 = ci * CHUNK, cj * CHUNK
	local yMin, yMax = -16, 48          -- hills stay within ~ -6..30
	local ySize  = (yMax - yMin) / VOXEL
	local count  = CHUNK / VOXEL

	local region = Region3.new(
		Vector3.new(x0, yMin, z0),
		Vector3.new(x0 + CHUNK, yMax, z0 + CHUNK))

	local materials, occupancy = {}, {}
	for xi = 1, count do
		materials[xi] = {}
		occupancy[xi] = {}
		for yi = 1, ySize do
			materials[xi][yi] = {}
			occupancy[xi][yi] = {}
		end
	end
	for xi = 1, count do
		local wx = x0 + (xi - 0.5) * VOXEL
		for zi = 1, count do
			local wz = z0 + (zi - 0.5) * VOXEL
			local h = heightAt(wx, wz)
			for yi = 1, ySize do
				local wy  = yMin + (yi - 0.5) * VOXEL
				local occ = math.clamp((h - wy) / VOXEL + 0.5, 0, 1)
				occupancy[xi][yi][zi] = occ
				materials[xi][yi][zi] = occ > 0 and material or Enum.Material.Air
			end
		end
	end
	Terrain:WriteVoxels(region, VOXEL, materials, occupancy)
end

-- True rendered terrain height. WriteVoxels quantizes the surface to the
-- voxel grid, so the visible ground sits up to ~2 studs ABOVE heightAt —
-- props placed at heightAt ended up half-buried ("overlapped" stumps).
local terrainRay = RaycastParams.new()
terrainRay.FilterType = Enum.RaycastFilterType.Include
terrainRay.FilterDescendantsInstances = { Terrain }

function WorldGenerator.surfaceY(heightAt, x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), terrainRay)
	return hit and hit.Position.Y or heightAt(x, z)
end

-- Build the decorative props of one chunk into `folder` and return the
-- interactive spots. RNG derives from (seed, ci, cj) → fully deterministic.
function WorldGenerator.populateChunk(cfg, heightAt, ci, cj, folder)
	local CHUNK  = WorldGenerator.CHUNK
	local rng    = Random.new((cfg.seed % 100000) + ci * 73856093 + cj * 19349663)
	local x0, z0 = ci * CHUNK, cj * CHUNK
	local layer  = cfg.layer
	local leafColor = (layer and layer.bambooColor or Color3.fromRGB(72, 185, 62))
		:Lerp(Color3.fromRGB(50, 130, 45), 0.5)

	-- Cross-kind spacing so trees/bamboo/rocks never overlap each other
	local placed = {}
	local function isFree(x, z, minD)
		for _, p in ipairs(placed) do
			local dx, dz = x - p.X, z - p.Z
			if dx * dx + dz * dz < minD * minD then return false end
		end
		return true
	end
	local function nearCenter(x, z, r)
		local dx, dz = x - cfg.center.X, z - cfg.center.Z
		return dx * dx + dz * dz < r * r
	end

	local bambooSpots, oreSpots = {}, {}

	-- Bamboo: dense clusters via noise mask (clearings stay walkable)
	for _ = 1, 34 do
		local x = x0 + rng:NextNumber(2, CHUNK - 2)
		local z = z0 + rng:NextNumber(2, CHUNK - 2)
		local mask = math.noise(x / 70, z / 70, cfg.seed * 1.31)
		if mask > 0 and not nearCenter(x, z, 30) and isFree(x, z, 3.5) then
			table.insert(placed, Vector3.new(x, 0, z))
			table.insert(bambooSpots, {
				pos   = Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z),
				scale = rng:NextNumber(0.8, 1.35),
			})
		end
	end

	-- Trees: separate mask channel so woods and bamboo fields interleave
	local theme = layer and layer.theme or "forest"
	for _ = 1, 9 do
		local x = x0 + rng:NextNumber(3, CHUNK - 3)
		local z = z0 + rng:NextNumber(3, CHUNK - 3)
		local mask = math.noise(x / 110, z / 110, cfg.seed * 2.17 + 31)
		if mask > 0.05 and not nearCenter(x, z, 32) and isFree(x, z, 7) then
			table.insert(placed, Vector3.new(x, 0, z))
			makeTree(rng, Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z),
				rng:NextNumber(0.85, 1.5), folder, leafColor, theme)
		end
	end

	-- Boulders
	for _ = 1, 3 do
		if rng:NextNumber() < 0.55 then
			local x = x0 + rng:NextNumber(3, CHUNK - 3)
			local z = z0 + rng:NextNumber(3, CHUNK - 3)
			if not nearCenter(x, z, 30) and isFree(x, z, 5) then
				table.insert(placed, Vector3.new(x, 0, z))
				makeBoulder(rng, Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z),
					rng:NextNumber(0.9, 1.6), folder, theme)
			end
		end
	end

	-- Bodendeko: Grasbüschel, Blumen, Splitter, Glut — billig, aber macht den
	-- Boden lebendig (CanCollide/CastShadow aus → kaum Kosten)
	for _ = 1, 10 do
		local x = x0 + rng:NextNumber(2, CHUNK - 2)
		local z = z0 + rng:NextNumber(2, CHUNK - 2)
		if isFree(x, z, 2) then
			makeGroundTuft(rng,
				Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z),
				folder, leafColor, theme)
		end
	end

	-- Ore rock: roughly every 3rd chunk
	if rng:NextNumber() < 0.35 then
		local x = x0 + rng:NextNumber(6, CHUNK - 6)
		local z = z0 + rng:NextNumber(6, CHUNK - 6)
		if not nearCenter(x, z, 30) and isFree(x, z, 5) then
			table.insert(oreSpots, { pos = Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z) })
		end
	end

	-- Wild monster: roughly every 5th chunk
	local monsterSpot = nil
	if rng:NextNumber() < 0.2 then
		local x = x0 + rng:NextNumber(10, CHUNK - 10)
		local z = z0 + rng:NextNumber(10, CHUNK - 10)
		if not nearCenter(x, z, 60) then
			monsterSpot = Vector3.new(x, WorldGenerator.surfaceY(heightAt, x, z), z)
		end
	end

	return bambooSpots, oreSpots, monsterSpot
end

return WorldGenerator
