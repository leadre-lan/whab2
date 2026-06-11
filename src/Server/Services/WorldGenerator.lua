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

local Terrain = workspace.Terrain

local VOXEL = 4

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

-- ── Decorative prop builders ──────────────────────────────────────────────────
local function makeTree(rng, pos, scale, parent, leafColor)
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

	for c = 1, 2 do
		local can = Instance.new("Part")
		can.Shape = Enum.PartType.Ball
		local s = (7 - c * 1.5) * scale
		can.Size = Vector3.new(s, s, s)
		can.Position = Vector3.new(
			pos.X + rng:NextNumber(-1, 1),
			pos.Y + tH + (c - 1) * 2.2 * scale,
			pos.Z + rng:NextNumber(-1, 1))
		can.Material = Enum.Material.Grass
		can.Color = leafColor:Lerp(
			Color3.fromRGB(40, 90, 35),
			rng:NextNumber(0, 0.4))
		can.Anchored = true
		can.CanCollide = false
		can.Parent = parent
	end
end

local function makeBoulder(rng, pos, scale, parent)
	local g = rng:NextInteger(95, 140)
	local b = Instance.new("Part")
	b.Size = Vector3.new(
		rng:NextNumber(2, 4.5),
		rng:NextNumber(1.5, 3.5),
		rng:NextNumber(2, 4.5)) * scale
	b.CFrame = CFrame.new(pos.X, pos.Y + b.Size.Y * 0.3, pos.Z)
		* CFrame.Angles(
			rng:NextNumber(0, math.pi),
			rng:NextNumber(0, math.pi),
			rng:NextNumber(0, math.pi))
	b.Material = Enum.Material.Slate
	b.Color = Color3.fromRGB(g, g, g)
	b.Anchored = true
	b.Parent = parent
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

	for c = 1, 3 do
		local can = Instance.new("Part")
		can.Shape = Enum.PartType.Ball
		local s = 26 - c * 5
		can.Size = Vector3.new(s, s * 0.75, s)
		can.Position = Vector3.new(
			pos.X + rng:NextNumber(-3, 3),
			pos.Y + 30 + c * 4,
			pos.Z + rng:NextNumber(-3, 3))
		can.Material = Enum.Material.Grass
		can.Color = leafColor
		can.Anchored = true
		can.CanCollide = false
		can.Parent = parent
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
			rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), 1.4, parent)
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
	local treeSpots = scatterPositions(cfg, heightAt, landmarks, cfg.treeCount or 90, 110, 500)
	for _, s in ipairs(treeSpots) do
		makeTree(rng, s.pos, s.scale, folder, leafColor)
	end
	local boulderSpots = scatterPositions(cfg, heightAt, landmarks, cfg.boulderCount or 30, 90, 900)
	for _, s in ipairs(boulderSpots) do
		makeBoulder(rng, s.pos, s.scale, folder)
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

return WorldGenerator
