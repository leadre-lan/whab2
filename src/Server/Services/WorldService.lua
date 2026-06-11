-- WorldService.lua — Builds and manages the 6-layer bamboo forest world
local WorldService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Layers  = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))
local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local rng = Random.new(42)

local chopHandlers    = {}  -- [hitboxPart] = handler(player, dmgOverride?)
local bambooHP        = {}  -- [hitboxPart] = currentHP
local playerCooldowns = {}  -- ["uid_addr"] = os.clock()
local playerCombo     = {}  -- [player] = { count, lastHitTime }

local dataService = nil
local net         = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function broadcastHit(pos, color, died, combo, damage, sliceInfo)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude <= 80 then
			net.HitEffect:FireClient(p, pos, color, died, combo, damage, sliceInfo)
		end
	end
end

local function trackCombo(player)
	local now = os.clock()
	local cd  = playerCombo[player]
	if not cd then
		playerCombo[player] = { count = 1, lastHitTime = now }
		return 1
	end
	if (now - cd.lastHitTime) <= Balance.COMBO_WINDOW then
		cd.count += 1
	else
		cd.count = 1
	end
	cd.lastHitTime = now
	return cd.count
end

local function computeDamage(player, damageOverride)
	if damageOverride then return damageOverride end
	local d = dataService.get(player)
	if not d then return 1 end
	local sharpness = d.stats.sharpness or 0
	local tier      = d.swordTier or 1
	local base = (1 + sharpness * Balance.SHARPNESS_MULT) * (Balance.TIER_MULT[tier] or 1)
	local dmg  = math.ceil(base)
	-- Crit
	local luck = d.stats.luck or 0
	if math.random() < math.min(0.60, luck * Balance.LUCK_CRIT_CHANCE) then
		dmg = dmg * 2
	end
	return dmg
end

-- ── Bamboo stalk visual builder (returns hitbox, visuals[], segH) ─────────────
local function buildBambooVisuals(layer, bx, bz, zoneFolder, baseY)
	baseY = baseY or 1
	local h  = layer.bambooH
	local th = layer.bambooThick
	local segCount = math.max(3, math.floor(h / 3))
	local segH     = h / segCount

	local model  = Instance.new("Model")
	model.Name   = "Bamboo"
	model.Parent = zoneFolder

	local hitbox = Instance.new("Part")
	hitbox.Name  = "Hitbox"
	hitbox.Size  = Vector3.new(th * 2.5, h, th * 2.5)
	hitbox.Position = Vector3.new(bx, baseY + h / 2, bz)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = true
	hitbox:SetAttribute("IsBamboo", true)
	hitbox:SetAttribute("IsDead", false)
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	local visuals = {}

	for s = 1, segCount do
		local segY = baseY + (s - 0.5) * segH
		local seg  = Instance.new("Part")
		seg.Shape   = Enum.PartType.Cylinder
		seg.Size    = Vector3.new(segH - 0.1, th, th)
		seg.CFrame  = CFrame.new(bx, segY, bz) * CFrame.Angles(0, 0, math.rad(90))
		seg.Material = Enum.Material.SmoothPlastic
		seg.Color    = layer.bambooColor
		seg.Anchored = true
		seg.CanCollide = false
		seg.Parent  = model
		table.insert(visuals, { part = seg, color = layer.bambooColor })

		if s < segCount then
			local ring = Instance.new("Part")
			ring.Shape   = Enum.PartType.Cylinder
			ring.Size    = Vector3.new(0.22, th * 1.2, th * 1.2)
			ring.CFrame  = CFrame.new(bx, baseY + s * segH, bz) * CFrame.Angles(0, 0, math.rad(90))
			ring.Material = Enum.Material.SmoothPlastic
			ring.Color    = layer.nodeColor
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent  = model
			table.insert(visuals, { part = ring, color = layer.nodeColor })
		end
	end

	-- Leaves
	local leafCol = layer.bambooColor:Lerp(Color3.fromRGB(55, 140, 48), 0.45)
	for l = 1, 4 do
		local ang  = (l / 4) * math.pi * 2 + rng:NextNumber(0, 0.9)
		local leaf = Instance.new("Part")
		leaf.Size  = Vector3.new(2.6, 0.1, 0.9)
		leaf.CFrame = CFrame.new(bx, baseY + h - 0.5, bz)
			* CFrame.Angles(0, ang, math.rad(-32))
			* CFrame.new(1.3, 0, 0)
		leaf.Material = Enum.Material.Grass
		leaf.Color    = leafCol
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Parent  = model
		table.insert(visuals, { part = leaf, color = leafCol })
	end

	return hitbox, visuals, segH, model, baseY
end

-- ── Register bamboo with full chop handler (self-contained closure) ───────────
local function registerBamboo(hitbox, layerIdx, visuals, segH, model, bx, bz, baseY, layerOverride)
	baseY = baseY or 1
	local layer    = layerOverride or Layers.DATA[layerIdx]
	local maxHP    = Balance.bambooHP(layerIdx)
	local respTime = Balance.BAMBOO_RESPAWN[layerIdx]
	local h        = layer.bambooH
	local th       = layer.bambooThick

	local extraSegs  = 0
	local extraParts = {}
	local growToken  = 0

	local function setTransp(t)
		for _, v in ipairs(visuals) do v.part.Transparency = t end
		for _, p in ipairs(extraParts) do pcall(function() p.Transparency = t end) end
	end
	local function resetColors()
		for _, v in ipairs(visuals) do v.part.Color = v.color end
	end
	local function clearExtra()
		extraSegs = 0
		for _, p in ipairs(extraParts) do pcall(function() p:Destroy() end) end
		table.clear(extraParts)
	end

	local function growAnim()
		setTransp(1)
		for _, v in ipairs(visuals) do
			v.part.Transparency = 0
			task.wait(0.035)
		end
	end

	local function startGrowth()
		growToken += 1
		local tok = growToken
		task.spawn(function()
			while true do
				task.wait(10)
				if tok ~= growToken or not hitbox.Parent then return end
				if hitbox:GetAttribute("IsDead") or extraSegs >= 4 then return end
				extraSegs += 1
				local segY = baseY + h + (extraSegs - 0.5) * segH
				local seg  = Instance.new("Part")
				seg.Shape   = Enum.PartType.Cylinder
				seg.Size    = Vector3.new(segH - 0.1, th, th)
				seg.CFrame  = CFrame.new(bx, segY, bz) * CFrame.Angles(0, 0, math.rad(90))
				seg.Material = Enum.Material.SmoothPlastic
				seg.Color    = layer.bambooColor
				seg.Anchored = true
				seg.CanCollide = false
				seg.Transparency = 1
				seg.Parent  = model
				table.insert(extraParts, seg)
				task.spawn(function()
					for i = 1, 8 do
						task.wait(0.05)
						if seg.Parent then seg.Transparency = 1 - i / 8 end
					end
				end)
			end
		end)
	end

	local handler
	handler = function(player, damageOverride)
		local pdata = dataService.get(player)
		if not pdata then return end
		if hitbox:GetAttribute("IsDead") then return end

		-- Layer gate check
		if pdata.highestLayer < layerIdx then
			net.Notify:FireClient(player, "🔒 " .. layer.name .. " — Level " .. layer.requiredLevel .. " benötigt!")
			return
		end

		-- Swing cooldown
		if not damageOverride then
			local speed = pdata.stats.speed or 0
			local delay = math.max(0.15, Balance.SWING_DELAY - speed * Balance.SPEED_REDUCTION)
			local key   = player.UserId .. "_" .. tostring(hitbox)
			local now   = os.clock()
			local last  = playerCooldowns[key]
			if last and (now - last) < delay then return end
			playerCooldowns[key] = now
		end

		local combo  = trackCombo(player)
		local damage = computeDamage(player, damageOverride)

		bambooHP[hitbox] = (bambooHP[hitbox] or maxHP) - damage

		-- Tint toward orange as HP drops
		local frac = math.max(0, bambooHP[hitbox]) / maxHP
		for _, v in ipairs(visuals) do
			v.part.Color = v.color:Lerp(Color3.fromRGB(255, 80, 0), 1 - frac)
		end

		local died = bambooHP[hitbox] <= 0
		local sliceInfo = died and {
			slicePos  = hitbox.Position,
			topHeight = h + extraSegs * segH,
			color     = layer.bambooColor,
			thickness = th,
		} or nil

		broadcastHit(hitbox.Position, layer.bambooColor, died, combo, damage, sliceInfo)

		if died then
			hitbox:SetAttribute("IsDead", true)
			hitbox.CanCollide = false
			setTransp(1)

			local bonus = extraSegs
			clearExtra()

			local mult  = Balance.comboMult(combo)
			local rebirthMult = Balance.rebirthMult(pdata.rebirths or 0)
			local coins = math.ceil(Balance.coinsPerFell(layerIdx) * mult * rebirthMult) + bonus
			local xpAmt = Balance.xpPerFell(layerIdx)

			pdata.coins       = pdata.coins + coins
			pdata.totalFelled = pdata.totalFelled + 1

			local leveledUp, newLevel = dataService.addXP(player, xpAmt)
			if leveledUp then
				for li, ld in ipairs(Layers.DATA) do
					if newLevel >= ld.requiredLevel and li > pdata.highestLayer then
						pdata.highestLayer = li
						net.LayerUnlocked:FireClient(player, li)
					end
				end
			end

			dataService.sendUpdate(player)

			task.spawn(function()
				task.wait(respTime)
				if not hitbox.Parent then return end
				bambooHP[hitbox] = maxHP
				hitbox:SetAttribute("IsDead", false)
				hitbox.CanCollide = true
				resetColors()
				growAnim()
				startGrowth()
			end)
		end
	end

	bambooHP[hitbox]     = maxHP
	chopHandlers[hitbox] = handler
	startGrowth()
end

-- ── Rock cluster builder ──────────────────────────────────────────────────────
local function buildRock(layerIdx, rx, rz, zoneFolder, baseY)
	baseY = baseY or 1
	local layer    = Layers.DATA[layerIdx]
	local maxHP    = Balance.rockHP(layerIdx)
	local respTime = Balance.ROCK_RESPAWN[layerIdx] or 20

	local rockModel = Instance.new("Model")
	rockModel.Name  = "Rock"
	rockModel.Parent = zoneFolder

	local rockParts = {}
	for _ = 1, rng:NextInteger(3, 5) do
		local g     = rng:NextInteger(98, 142)
		local chunk = Instance.new("Part")
		chunk.Size  = Vector3.new(
			rng:NextNumber(1.5, 3.5),
			rng:NextNumber(1.5, 3.5),
			rng:NextNumber(1.5, 3.5))
		chunk.CFrame = CFrame.new(
				rx + rng:NextNumber(-1.2, 1.2),
				baseY + chunk.Size.Y / 2 - rng:NextNumber(0, 0.8),
				rz + rng:NextNumber(-1.2, 1.2))
			* CFrame.Angles(
				rng:NextNumber(0, math.pi),
				rng:NextNumber(0, math.pi),
				rng:NextNumber(0, math.pi))
		chunk.Material  = Enum.Material.Slate
		chunk.Color     = Color3.fromRGB(g, g, g)
		chunk.Anchored  = true
		chunk.CanCollide = true
		chunk.Parent    = rockModel
		table.insert(rockParts, { part = chunk, color = chunk.Color })
	end

	-- Ore sparkles tinted to layer glow
	for _ = 1, rng:NextInteger(2, 3) do
		local sp = Instance.new("Part")
		sp.Size  = Vector3.new(0.38, 0.38, 0.38)
		sp.CFrame = CFrame.new(
			rx + rng:NextNumber(-1.6, 1.6),
			baseY + rng:NextNumber(0.5, 2.4),
			rz + rng:NextNumber(-1.6, 1.6))
		sp.Material  = Enum.Material.Neon
		sp.Color     = layer.glowColor
		sp.Anchored  = true
		sp.CanCollide = false
		sp.CastShadow = false
		sp.Parent     = rockModel
		table.insert(rockParts, { part = sp, color = sp.Color })
	end

	local rock = Instance.new("Part")
	rock.Name  = "Hitbox"
	rock.Size  = Vector3.new(4, 4, 4)
	rock.Position = Vector3.new(rx, baseY + 2, rz)
	rock.Transparency = 1
	rock.Anchored  = true
	rock.CanCollide = false
	rock:SetAttribute("IsRock", true)
	rock:SetAttribute("IsDead", false)
	rock.Parent = rockModel

	local function setTransp(t)
		for _, v in ipairs(rockParts) do v.part.Transparency = t end
	end
	local function resetColors()
		for _, v in ipairs(rockParts) do v.part.Color = v.color end
	end

	bambooHP[rock] = maxHP

	local handler
	handler = function(player, damageOverride)
		local pdata = dataService.get(player)
		if not pdata then return end
		if rock:GetAttribute("IsDead") then return end

		if pdata.highestLayer < layerIdx then
			net.Notify:FireClient(player, "🔒 Stein: " .. layer.name .. " benötigt!")
			return
		end

		if not damageOverride then
			local key  = player.UserId .. "_r_" .. tostring(rock)
			local now  = os.clock()
			local last = playerCooldowns[key]
			if last and (now - last) < Balance.SWING_DELAY then return end
			playerCooldowns[key] = now
		end

		local combo  = trackCombo(player)
		local damage = computeDamage(player, damageOverride)

		bambooHP[rock] = (bambooHP[rock] or maxHP) - damage

		local frac = math.max(0, bambooHP[rock]) / maxHP
		for _, v in ipairs(rockParts) do
			v.part.Color = v.color:Lerp(Color3.fromRGB(255, 80, 0), 1 - frac)
		end

		local died = bambooHP[rock] <= 0
		broadcastHit(rock.Position, layer.glowColor, died, combo, damage, nil)

		if died then
			rock:SetAttribute("IsDead", true)
			setTransp(1)

			local mult  = Balance.comboMult(combo)
			local rebirthMult = Balance.rebirthMult(pdata.rebirths or 0)
			local coins = math.ceil(Balance.coinsPerMine(layerIdx) * mult * rebirthMult)
			pdata.coins      = pdata.coins + coins
			pdata.totalMined = pdata.totalMined + 1

			-- Rocks drop crafting material for the forge
			local matKey = "mat" .. layerIdx
			pdata.materials = pdata.materials or {}
			pdata.materials[matKey] = (pdata.materials[matKey] or 0) + Balance.MAT_PER_ROCK
			net.Notify:FireClient(player, "⛏ +1 Material (Schicht " .. layerIdx .. ")")
			dataService.sendUpdate(player)

			task.spawn(function()
				task.wait(respTime)
				if not rock.Parent then return end
				bambooHP[rock] = maxHP
				rock:SetAttribute("IsDead", false)
				setTransp(0)
				resetColors()
			end)
		end
	end

	chopHandlers[rock] = handler
end

-- ── Decorative tree ───────────────────────────────────────────────────────────
local function makeTree(x, z, parent)
	local sc = rng:NextNumber(0.85, 1.7)
	local tH = 9 * sc

	local trunk = Instance.new("Part")
	trunk.Shape   = Enum.PartType.Cylinder
	trunk.Size    = Vector3.new(tH, 1.6 * sc, 1.6 * sc)
	trunk.CFrame  = CFrame.new(x, tH / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Material = Enum.Material.Wood
	trunk.Color   = Color3.fromRGB(92, 62, 38)
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.Parent  = parent

	for c = 1, 2 do
		local can = Instance.new("Part")
		can.Shape   = Enum.PartType.Ball
		local s     = (7 - c * 1.5) * sc
		can.Size    = Vector3.new(s, s, s)
		can.Position = Vector3.new(
			x + rng:NextNumber(-1, 1),
			tH + (c - 1) * 2.2 * sc,
			z + rng:NextNumber(-1, 1))
		can.Material = Enum.Material.Grass
		can.Color    = Color3.fromRGB(
			44 + rng:NextInteger(0, 28),
			108 + rng:NextInteger(0, 32),
			38)
		can.Anchored = true
		can.CanCollide = false
		can.Parent   = parent
	end
end

-- ── Zone sign helper ──────────────────────────────────────────────────────────
local function makeZoneSign(layer, li, pos, parent)
	local post = Instance.new("Part")
	post.Size     = Vector3.new(0.42, 6.5, 0.42)
	post.Position = pos + Vector3.new(0, 3.25, 0)
	post.Material = Enum.Material.Wood
	post.Color    = Color3.fromRGB(98, 68, 38)
	post.Anchored = true
	post.CanCollide = false
	post.Parent   = parent

	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 270, 0, 105)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.Parent      = post

	local tl = Instance.new("TextLabel")
	tl.Size  = UDim2.new(1, 0, 0.52, 0)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = layer.glowColor
	tl.TextStrokeTransparency = 0
	tl.TextScaled = true
	tl.Font       = Enum.Font.GothamBold
	tl.Text       = layer.name
	tl.Parent     = bb

	local ll = Instance.new("TextLabel")
	ll.Size     = UDim2.new(1, 0, 0.48, 0)
	ll.Position = UDim2.new(0, 0, 0.52, 0)
	ll.BackgroundTransparency = 1
	ll.TextColor3 = Color3.fromRGB(255, 228, 78)
	ll.TextStrokeTransparency = 0
	ll.TextScaled = true
	ll.Font       = Enum.Font.Gotham
	ll.Text       = li == 1 and "⭐ Start-Schicht" or ("🔒 Level " .. layer.requiredLevel)
	ll.Parent     = bb
end

-- Per-layer spawn points (filled during init; HubService teleports here)
WorldService.layerSpawns = {}

-- ── Public: init ─────────────────────────────────────────────────────────────
function WorldService.init(ds, netRef)
	dataService = ds
	net         = netRef

	local WorldGenerator = require(script.Parent:WaitForChild("WorldGenerator"))

	-- Performance: stream the world around each player (layers are 5000 apart)
	pcall(function()
		workspace.StreamingEnabled = true
	end)

	workspace.Terrain:Clear()
	for _, n in ipairs({ "Baseplate", "SpawnLocation", "Zones", "Forest" }) do
		local old = workspace:FindFirstChild(n)
		if old then old:Destroy() end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name:match("^Gen_") then child:Destroy() end
	end

	-- Hub ground (the hub itself is parts; layers are separate worlds)
	local bp = Instance.new("Part")
	bp.Name     = "Baseplate"
	bp.Size     = Vector3.new(1100, 20, 1100)
	bp.Position = Vector3.new(-320, -10, -60)
	bp.Material = Enum.Material.Grass
	bp.Color    = Color3.fromRGB(98, 122, 58)
	bp.Anchored = true
	bp.CanCollide = true
	bp.Parent   = workspace

	-- Players spawn in the Overworld hub
	local sl = Instance.new("SpawnLocation")
	sl.Name     = "SpawnLocation"
	sl.Size     = Vector3.new(10, 1, 10)
	sl.Position = Vector3.new(-320, 1.5, -25)
	sl.Anchored = true
	sl.Neutral  = true
	sl.Color    = Color3.fromRGB(162, 162, 165)
	sl.Parent   = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name  = "Zones"
	zonesFolder.Parent = workspace

	-- Decorations around the hub (so the hub horizon isn't empty either)
	local forestFolder = Instance.new("Folder")
	forestFolder.Name  = "Forest"
	forestFolder.Parent = workspace
	do
		local placed = 0
		while placed < 120 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d   = rng:NextNumber(130, 480)
			local x, z = -320 + math.cos(ang) * d, -60 + math.sin(ang) * d
			makeTree(x, z, forestFolder)
			placed += 1
		end
		for a = 0, 13 do
			local ang = a / 14 * math.pi * 2
			local mh = rng:NextNumber(120, 260)
			local mountain = Instance.new("Part")
			mountain.Size   = Vector3.new(rng:NextNumber(160, 300), mh, rng:NextNumber(160, 300))
			mountain.CFrame = CFrame.new(-320 + math.cos(ang) * 560, mh / 2 - 35, -60 + math.sin(ang) * 560)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			mountain.Material = Enum.Material.Rock
			mountain.Color    = Color3.fromRGB(86, 98, 86)
			mountain.Anchored = true
			mountain.Parent   = forestFolder
		end
	end

	for li, layer in ipairs(Layers.DATA) do
		local zf = Instance.new("Folder")
		zf.Name   = "L" .. li .. "_" .. layer.name
		zf.Parent = zonesFolder

		local genResult = nil
		if layer.gen then
			-- ── Generated layer: Terrain + organic scattering (GAME_DESIGN 6.5) ──
			local genCfg = {
				seed         = layer.gen.seed,
				center       = Vector3.new(layer.offsetX, 0, 0),
				size         = layer.gen.size,
				material     = layer.gen.material,
				layer        = layer,
				bambooCount  = layer.gen.bambooCount,
				oreCount     = layer.gen.oreCount,
				treeCount    = layer.gen.treeCount,
				boulderCount = layer.gen.boulderCount,
			}
			-- Never let a generator bug take down the whole server init —
			-- fall back to the part-based island instead.
			local ok, resultOrErr = pcall(WorldGenerator.generate, genCfg)
			if ok then
				genResult = resultOrErr
			else
				warn("[WorldService] WorldGenerator für '" .. layer.name .. "' fehlgeschlagen: "
					.. tostring(resultOrErr) .. " — nutze Part-Insel als Fallback.")
			end
		end

		if genResult then
			local result = genResult
			WorldService.layerSpawns[li] = result.spawnPoint
			WorldService.layerCamps = WorldService.layerCamps or {}
			WorldService.layerCamps[li] = result.camps

			-- Interactive bamboo at the generated spots (scale + rotation variation)
			for _, spot in ipairs(result.bambooSpots) do
				local scaled = table.clone(layer)
				scaled.bambooH     = layer.bambooH * spot.scale
				scaled.bambooThick = layer.bambooThick * spot.scale
				local hitbox, visuals, segH, model, bY = buildBambooVisuals(
					scaled, spot.pos.X, spot.pos.Z, zf, spot.pos.Y)
				registerBamboo(hitbox, li, visuals, segH, model,
					spot.pos.X, spot.pos.Z, bY, scaled)
			end

			-- Interactive ore rocks (clustered at the rock formation landmark)
			for _, spot in ipairs(result.oreSpots) do
				buildRock(li, spot.pos.X, spot.pos.Z, zf, spot.pos.Y)
			end

			makeZoneSign(layer, li, result.spawnPoint + Vector3.new(6, 0, 6), zf)
		else
			-- ── Part-based layer (own island, far from everything else) ──
			local plat = Instance.new("Part")
			plat.Size     = Vector3.new(400, 20, 400)
			plat.Position = Vector3.new(layer.offsetX, -9, 0)
			plat.Material = Enum.Material.LeafyGrass
			plat.Color    = layer.platform
			plat.Anchored = true
			plat.CanCollide = true
			plat.Parent   = zf

			WorldService.layerSpawns[li] = Vector3.new(layer.offsetX, 5, 0)

			-- Grass tufts
			for _ = 1, rng:NextInteger(10, 18) do
				local tx  = layer.offsetX + rng:NextNumber(-80, 80)
				local tz  = rng:NextNumber(-80, 80)
				local tft = Instance.new("Part")
				tft.Shape = Enum.PartType.Cylinder
				local th2 = rng:NextNumber(0.5, 1.5)
				tft.Size  = Vector3.new(th2, 0.22, 0.22)
				tft.CFrame = CFrame.new(tx, 1 + th2 / 2, tz)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90 + rng:NextNumber(-15, 15)))
				tft.Material = Enum.Material.Grass
				tft.Color    = layer.bambooColor:Lerp(Color3.fromRGB(48, 130, 38), 0.55)
				tft.Anchored = true
				tft.CanCollide = false
				tft.CastShadow = false
				tft.Parent   = zf
			end

			makeZoneSign(layer, li, Vector3.new(layer.offsetX - 20, 1, -20), zf)

			-- Bamboo (random scatter with scale variation, no rows)
			local count = Balance.BAMBOO_COUNT[li] or 18
			for _ = 1, count do
				local bx = layer.offsetX + rng:NextNumber(-90, 90)
				local bz = rng:NextNumber(-90, 90)
				local scale = rng:NextNumber(0.8, 1.3)
				local scaled = table.clone(layer)
				scaled.bambooH     = layer.bambooH * scale
				scaled.bambooThick = layer.bambooThick * scale
				local hitbox, visuals, segH, model, bY = buildBambooVisuals(scaled, bx, bz, zf, 1)
				registerBamboo(hitbox, li, visuals, segH, model, bx, bz, bY, scaled)
			end

			-- Rocks
			for _ = 1, rng:NextInteger(5, 8) do
				local rx = layer.offsetX + rng:NextNumber(50, 130)
				local rz = rng:NextNumber(-90, 90)
				buildRock(li, rx, rz, zf)
			end

			-- Tree ring around the island so the edge is never visible
			for _ = 1, 60 do
				local ang = rng:NextNumber(0, math.pi * 2)
				local d   = rng:NextNumber(115, 190)
				makeTree(layer.offsetX + math.cos(ang) * d, math.sin(ang) * d, zf)
			end
		end
	end

	-- Base lighting (hub defaults; per-layer lighting applied client-side on teleport)
	local L = game:GetService("Lighting")
	L.FogStart       = 120
	L.FogEnd         = 380
	L.FogColor       = Color3.fromRGB(168, 185, 168)
	L.OutdoorAmbient = Color3.fromRGB(140, 150, 135)

	print("[WorldService] " .. #Layers.DATA .. " Schichten generiert (Schicht 1 via WorldGenerator).")
end

function WorldService.getLayerSpawn(layerIdx)
	return WorldService.layerSpawns[layerIdx]
end

-- ── Public: handle chop ───────────────────────────────────────────────────────
function WorldService.handleChop(player, part)
	if typeof(part) ~= "Instance" then return end
	local handler = chopHandlers[part]
	if not handler then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local pdata   = dataService.get(player)
	local range   = pdata and (pdata.stats.range or 0) or 0
	local maxDist = 26 + range * Balance.RANGE_BONUS

	if (root.Position - part.Position).Magnitude > maxDist then return end
	handler(player)
end

-- ── Public: handle slam ───────────────────────────────────────────────────────
function WorldService.handleSlam(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if root.AssemblyLinearVelocity.Y >= -2 then return end

	local pos   = root.Position
	local pdata = dataService.get(player)
	local sharp = pdata and (pdata.stats.sharpness or 0) or 0
	local tier  = pdata and (pdata.swordTier or 1) or 1
	local baseDmg = (1 + sharp * Balance.SHARPNESS_MULT)
		* (Balance.TIER_MULT[tier] or 1) * Balance.SLAM_MULT

	local zonesF = workspace:FindFirstChild("Zones")
	if not zonesF then return end
	for _, desc in ipairs(zonesF:GetDescendants()) do
		if desc:IsA("BasePart")
			and (desc:GetAttribute("IsBamboo") or desc:GetAttribute("IsRock"))
			and not desc:GetAttribute("IsDead")
			and (desc.Position - pos).Magnitude <= Balance.SLAM_RADIUS then
			local h = chopHandlers[desc]
			if h then h(player, math.ceil(baseDmg)) end
		end
	end
end

-- Clean up combo on leave
Players.PlayerRemoving:Connect(function(player)
	playerCombo[player] = nil
end)

return WorldService
