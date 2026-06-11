-- MonsterService.lua — Per-layer mobs with telegraph→attack AI, loot, bosses
local MonsterService = {}

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Layers  = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))
local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

local rng = Random.new(99)

local dataService = nil
local net         = nil

local monsters = {}   -- [model] = state table

-- ── Monster model builder ─────────────────────────────────────────────────────
-- A proper little creature instead of a ball with spikes: body, head with
-- angry eyes + pupils + brows, horns, mouth, stub arms, feet and back spikes.
-- The face points toward -Z (matches the AI's yaw math).
local function buildMonsterModel(layer, pos, isBoss)
	local s = isBoss and 2.6 or 1
	local bodyColor = layer.glowColor:Lerp(Color3.fromRGB(30, 30, 30), isBoss and 0.25 or 0.45)
	local darkColor = bodyColor:Lerp(Color3.fromRGB(15, 15, 20), 0.45)
	local hornColor = Color3.fromRGB(228, 218, 198)

	local model = Instance.new("Model")
	model.Name = isBoss and (layer.boss and layer.boss.name or "Boss") or layer.monsterName

	local center = pos + Vector3.new(0, 1.7 * s, 0)

	local function mpart(props)
		local p = Instance.new("Part")
		if props.shape then p.Shape = props.shape end
		p.Size = props.size
		p.CFrame = CFrame.new(center) * props.offset
		p.Material = props.material or Enum.Material.SmoothPlastic
		p.Color = props.color
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		if props.ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		if props.name then p.Name = props.name end
		p.Parent = model
		return p
	end

	-- Body: squashed blob (organic, not a perfect ball)
	local body = mpart({
		name = "Body", ellipsoid = true,
		size = Vector3.new(3.4, 2.9, 3.2) * s, offset = CFrame.new(),
		color = bodyColor,
		material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})
	body:SetAttribute("IsMonster", true)
	model.PrimaryPart = body

	-- Head (slightly forward, a touch oval)
	mpart({
		ellipsoid = true,
		size = Vector3.new(2.2, 1.95, 2.05) * s,
		offset = CFrame.new(0, 1.45 * s, -0.15 * s),
		color = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.06),
		material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})

	-- Eyes + pupils + angry brows
	for side = -1, 1, 2 do
		mpart({
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.56, 0.56, 0.56) * s,
			offset = CFrame.new(side * 0.42 * s, 1.72 * s, -1.02 * s),
			color = isBoss and Color3.fromRGB(255, 70, 45) or Color3.fromRGB(250, 248, 240),
			material = Enum.Material.Neon,
		})
		mpart({
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.26, 0.26, 0.26) * s,
			offset = CFrame.new(side * 0.42 * s, 1.72 * s, -1.26 * s),
			color = Color3.fromRGB(20, 18, 24),
		})
		mpart({
			size = Vector3.new(0.62, 0.14, 0.22) * s,
			offset = CFrame.new(side * 0.44 * s, 2.04 * s, -1.0 * s)
				* CFrame.Angles(0, 0, side * math.rad(-16)),
			color = darkColor,
		})
		-- Horns (bosses get longer ones)
		mpart({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new((isBoss and 1.25 or 0.85) * s, 0.28 * s, 0.28 * s),
			offset = CFrame.new(side * 0.78 * s, 2.35 * s, -0.1 * s)
				* CFrame.Angles(0, 0, math.rad(90 - side * 32)),
			color = hornColor,
		})
		-- Stub arms
		mpart({
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9) * s,
			offset = CFrame.new(side * 1.55 * s, -0.15 * s, -0.35 * s),
			color = darkColor,
		})
		-- Feet (flat pucks)
		mpart({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.5 * s, 1.05 * s, 1.05 * s),
			offset = CFrame.new(side * 0.65 * s, -1.42 * s, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			color = darkColor,
		})
	end

	-- Mouth (slight smirk)
	mpart({
		size = Vector3.new(0.95, 0.16, 0.18) * s,
		offset = CFrame.new(0, 1.22 * s, -1.08 * s) * CFrame.Angles(0, 0, math.rad(5)),
		color = Color3.fromRGB(25, 20, 28),
	})

	-- Back spikes along the spine (bosses: glowing crown row)
	local spikeCount = isBoss and 4 or 3
	for i = 1, spikeCount do
		mpart({
			size = Vector3.new(0.3, 0.95 - i * 0.12, 0.3) * s,
			offset = CFrame.new(0, (1.15 - (i - 1) * 0.62) * s, (1.15 + (i - 1) * 0.18) * s)
				* CFrame.Angles(math.rad(28 + i * 8), 0, 0),
			color = layer.glowColor,
			material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
	end

	-- Health bar billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.new(0, isBoss and 130 or 80, 0, isBoss and 32 or 22)
	bb.StudsOffset = Vector3.new(0, 3.4 * s, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90    -- never visible from other worlds
	bb.Parent = body

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = isBoss and Color3.fromRGB(255, 90, 60) or Color3.fromRGB(235, 235, 245)
	nameLbl.TextStrokeTransparency = 0
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Text = (isBoss and "👑 " or "") .. model.Name
	nameLbl.Parent = bb

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, 0, 0.3, 0)
	barBg.Position = UDim2.new(0, 0, 0.6, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(230, 60, 50)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	return model, body, barFill
end

-- ── Spawn one monster ─────────────────────────────────────────────────────────
local function spawnMonster(layerIdx, homePos, parent, isBoss, opts)
	opts = opts or {}
	local layer = Layers.DATA[layerIdx]
	local model, body, hpFill = buildMonsterModel(layer, homePos, isBoss)
	if opts.name then model.Name = opts.name end
	model.Parent = parent

	local maxHP = Balance.monsterHP(layerIdx) * (isBoss and (layer.boss and layer.boss.hpMult or 10) or 1)
	local dmg   = Balance.monsterDamage(layerIdx) * (isBoss and (layer.boss and layer.boss.dmgMult or 2) or 1)
	if opts.hpMult then maxHP = math.ceil(maxHP * opts.hpMult) end

	local scale = isBoss and 2.6 or 1
	monsters[model] = {
		layerIdx   = layerIdx,
		isBoss     = isBoss or false,
		scale      = scale,
		hp         = maxHP,
		maxHP      = maxHP,
		damage     = dmg,
		homePos    = homePos,
		body       = body,
		hpFill     = hpFill,
		state      = "idle",       -- idle | chase | telegraph | attack | dead
		lastAttack = 0,
		baseColor  = body.Color,
		baseSize   = body.Size,
		noRespawn  = opts.noRespawn or false,
		noLoot     = opts.noLoot or false,
		onDeath    = opts.onDeath,
		-- Animation state (integrated every frame, decisions at 10 Hz)
		pos        = Vector3.new(homePos.X, 0, homePos.Z),
		groundY    = homePos.Y,
		curGroundY = homePos.Y,
		yaw        = rng:NextNumber(0, math.pi * 2),
		targetYaw  = 0,
		hopT       = rng:NextNumber(0, math.pi),
		moving     = false,
		active     = false,
		targetRoot = nil,
	}
	monsters[model].targetYaw = monsters[model].yaw
	return model
end

-- Public: wild monster owned by a streamed chunk. No respawn — the chunk
-- itself deterministically rebuilds it when it reloads.
function MonsterService.spawnWild(layerIdx, pos, parent)
	return spawnMonster(layerIdx, pos, parent, false, { noRespawn = true })
end

-- Public: spawn a one-off training bot (used by ArenaService demo fights)
function MonsterService.spawnTrainingBot(layerIdx, pos, parent, onDeath)
	return spawnMonster(layerIdx, pos, parent, false, {
		name = "🤖 Trainings-Bot",
		noRespawn = true,
		noLoot = true,
		hpMult = 2,
		onDeath = onDeath,
	})
end

function MonsterService.despawn(model)
	local m = monsters[model]
	if m then
		monsters[model] = nil
		model:Destroy()
	end
end

-- ── Damage a monster (called by CombatService) ───────────────────────────────
function MonsterService.damageMonster(player, model, damage)
	local m = monsters[model]
	if not m or m.state == "dead" then return false end

	m.hp -= damage
	if m.hpFill then
		m.hpFill.Size = UDim2.new(math.clamp(m.hp / m.maxHP, 0, 1), 0, 1, 0)
	end

	-- Flash white
	local body = m.body
	task.spawn(function()
		local oc = m.baseColor
		body.Color = Color3.fromRGB(255, 255, 255)
		task.wait(0.07)
		if m.state ~= "dead" then body.Color = oc end
	end)

	net.HitEffect:FireClient(player, body.Position, m.baseColor, false, nil, damage, nil, "monster")

	if m.hp <= 0 then
		m.state = "dead"

		-- Loot
		local pdata = dataService.get(player)
		if pdata and not m.noLoot then
			local mult  = Balance.rebirthMult(pdata.rebirths or 0)
			local coins = math.ceil(Balance.monsterCoins(m.layerIdx) * mult)
				* (m.isBoss and 10 or 1)
			local xp = Balance.monsterXP(m.layerIdx) * (m.isBoss and 8 or 1)
			pdata.coins = pdata.coins + coins
			pdata.totalKills = (pdata.totalKills or 0) + 1

			-- Material drop
			if m.isBoss or math.random() < Balance.MONSTER_MAT_CHANCE then
				local key = "mat" .. m.layerIdx
				pdata.materials = pdata.materials or {}
				pdata.materials[key] = (pdata.materials[key] or 0) + (m.isBoss and 5 or 1)
			end

			local leveledUp, newLevel = dataService.addXP(player, xp)
			if leveledUp then
				for li, ld in ipairs(Layers.DATA) do
					if newLevel >= ld.requiredLevel and li > pdata.highestLayer then
						pdata.highestLayer = li
						net.LayerUnlocked:FireClient(player, li)
					end
				end
			end
			dataService.sendUpdate(player)
		end

		-- Death effect: dissolve
		net.HitEffect:FireClient(player, m.body.Position, m.baseColor, true, nil, nil, nil, "monster")
		local respawnPos = m.homePos
		local layerIdx   = m.layerIdx
		local isBoss     = m.isBoss
		local parent     = model.Parent

		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.6),
					{ Transparency = 1, Size = p.Size * 0.3 }):Play()
			end
		end
		local noRespawn = m.noRespawn
		local onDeath   = m.onDeath
		monsters[model] = nil
		task.delay(0.7, function() model:Destroy() end)

		if onDeath then
			task.spawn(onDeath, player)
		end

		-- Respawn (bosses take 4x longer; training bots never respawn)
		if not noRespawn then
			task.delay(Balance.MONSTER_RESPAWN * (isBoss and 4 or 1), function()
				if parent and parent.Parent then
					spawnMonster(layerIdx, respawnPos, parent, isBoss)
				end
			end)
		end
		return true
	end
	return false
end

function MonsterService.isMonster(model)
	return monsters[model] ~= nil
end

-- ── AI loop ───────────────────────────────────────────────────────────────────
-- Decisions (targeting, attacks, ground checks) run at 10 Hz; the actual
-- movement is integrated EVERY frame via animStep — moving anchored parts at
-- 10 Hz looked like a slideshow, and the old idle bob moved only the Body so
-- eyes and spikes visually detached from the monster.

local groundRayParams = nil  -- set in init
local monstersFolder  = nil  -- set in init

-- excludeModel: chunk-spawned monsters live under Zones, so each monster must
-- exclude ITSELF or the ray hits its own head and it climbs upward.
local function groundYAt(x, z, fallback, excludeModel)
	if groundRayParams then
		groundRayParams.FilterDescendantsInstances = excludeModel
			and { monstersFolder, excludeModel } or { monstersFolder }
	end
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), groundRayParams)
	if not hit then return fallback end
	-- Never treat a player standing there as "ground"
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then return fallback end
	return hit.Position.Y
end

-- Telegraph (inflate + red flash) → lunge at the target → bounce back
local function doAttack(m, targetRoot)
	m.state = "telegraph"
	local body = m.body
	TweenService:Create(body,
		TweenInfo.new(Balance.MONSTER_TELEGRAPH, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Color = Color3.fromRGB(255, 50, 30), Size = m.baseSize * 1.2 }):Play()

	task.spawn(function()
		task.wait(Balance.MONSTER_TELEGRAPH)
		if m.state ~= "telegraph" or not body.Parent then return end

		-- Release: snap back to base size, lunge toward the target
		body.Size  = m.baseSize
		body.Color = m.baseColor
		m.state = "attack"

		local dir = Vector3.new(0, 0, -1)
		if targetRoot and targetRoot.Parent then
			local flat = (targetRoot.Position - Vector3.new(m.pos.X, targetRoot.Position.Y, m.pos.Z))
				* Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.1 then dir = flat.Unit end
		end
		m.targetYaw = math.atan2(-dir.X, -dir.Z)

		local startPos  = m.pos
		local strikePos = startPos + dir * 4 * m.scale
		local t0 = os.clock()
		while os.clock() - t0 < 0.14 do
			if m.state ~= "attack" or not body.Parent then return end
			local a = math.min(1, (os.clock() - t0) / 0.14)
			m.pos = startPos:Lerp(strikePos, a * a)  -- accelerate into the hit
			task.wait()
		end

		-- Impact: hit all players still in range (dodge by moving away!)
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			local h = char and char:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0
				and (r.Position - body.Position).Magnitude <= Balance.MONSTER_ATK_RANGE + 2 then
				local dmg = m.damage
				-- Blocking reduces damage
				if char:GetAttribute("Blocking") then
					dmg = math.ceil(dmg * (1 - Balance.BLOCK_REDUCTION))
				end
				h:TakeDamage(dmg)
				net.HitEffect:FireClient(p, r.Position, Color3.fromRGB(255, 60, 40), false, nil, nil, nil, "hurt")
			end
		end

		-- Bounce back to where the lunge started
		t0 = os.clock()
		while os.clock() - t0 < 0.22 do
			if m.state ~= "attack" or not body.Parent then return end
			local a = math.min(1, (os.clock() - t0) / 0.22)
			m.pos = strikePos:Lerp(startPos, 1 - (1 - a) * (1 - a))
			task.wait()
		end
		if m.state == "attack" then m.state = "chase" end
	end)
end

local function thinkStep()
	for model, m in pairs(monsters) do
		if m.state == "dead" or not m.body.Parent then continue end

		-- Find nearest living player
		local nearest, nearestDist = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum  = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local d = (root.Position - m.body.Position).Magnitude
				if d < nearestDist then
					nearest, nearestDist = root, d
				end
			end
		end

		-- Animation culling: don't replicate movement nobody can see
		m.active = nearestDist < 140

		-- Follow the terrain (layers are hilly — fixed home height looked floaty)
		if m.active then
			m.groundY = groundYAt(m.pos.X, m.pos.Z, m.groundY, model)
		end

		if m.state == "telegraph" or m.state == "attack" then continue end

		local aggro = Balance.MONSTER_AGGRO * (m.isBoss and 1.5 or 1)
		if nearest and nearestDist <= aggro then
			m.targetRoot = nearest
			if nearestDist <= Balance.MONSTER_ATK_RANGE then
				local now = os.clock()
				if now - m.lastAttack >= Balance.MONSTER_ATK_CD then
					m.lastAttack = now
					doAttack(m, nearest)
				else
					m.state = "chase"  -- hold position, keep facing the player
				end
			else
				m.state = "chase"
			end
		else
			m.state = "idle"
			m.targetRoot = nil
		end
	end
end

local function animStep(dt)
	local now = os.clock()
	for model, m in pairs(monsters) do
		if m.state == "dead" or not m.active or not m.body.Parent then continue end

		m.moving = false

		-- Chase movement (integrated per frame for smooth motion)
		if m.state == "chase" and m.targetRoot and m.targetRoot.Parent then
			local toTarget = (m.targetRoot.Position - m.pos) * Vector3.new(1, 0, 1)
			local dist = toTarget.Magnitude
			if dist > 0.1 then
				m.targetYaw = math.atan2(-toTarget.X / dist, -toTarget.Z / dist)
			end
			if dist > Balance.MONSTER_ATK_RANGE - 2 then
				local speed  = Balance.MONSTER_SPEED * (m.isBoss and 0.8 or 1)
				local newPos = m.pos + toTarget.Unit * speed * dt
				-- Keep monsters near their home platform
				if ((newPos - m.homePos) * Vector3.new(1, 0, 1)).Magnitude < 70 then
					m.pos = newPos
					m.moving = true
				end
			end
		end

		-- Smooth turn toward the target yaw (no more snap rotation)
		local dy = (m.targetYaw - m.yaw + math.pi) % (math.pi * 2) - math.pi
		m.yaw += dy * math.min(1, dt * 9)

		-- Smooth ground following
		m.curGroundY += (m.groundY - m.curGroundY) * math.min(1, dt * 10)

		-- Vertical animation per state
		local offY, pitch = 0, 0
		if m.moving then
			-- Hop locomotion: the ball bounces forward instead of sliding
			m.hopT += dt * 7
			local s = math.abs(math.sin(m.hopT))
			offY  = s * 1.1 * m.scale
			pitch = math.sin(m.hopT * 2) * 0.10   -- slight forward tumble
		elseif m.state == "telegraph" then
			offY = math.abs(math.sin(now * 35)) * 0.12  -- tremble during wind-up
		else
			offY = math.sin(now * 2 + m.homePos.X) * 0.15 * m.scale  -- breathing bob
		end

		model:PivotTo(
			CFrame.new(m.pos.X, m.curGroundY + 1.7 * m.scale + offY, m.pos.Z)
			* CFrame.Angles(0, m.yaw, 0)
			* CFrame.Angles(pitch, 0, 0))
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function MonsterService.init(ds, netRef)
	dataService = ds
	net         = netRef

	local old = workspace:FindFirstChild("Monsters")
	if old then old:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name  = "Monsters"
	folder.Parent = workspace

	-- Find ground height via raycast (terrain layers are not flat)
	monstersFolder = folder
	groundRayParams = RaycastParams.new()
	groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRayParams.FilterDescendantsInstances = { folder }
	local function groundY(x, z)
		return groundYAt(x, z, 1)
	end

	local WorldService = require(script.Parent:WaitForChild("WorldService"))

	for li, layer in ipairs(Layers.DATA) do
		local lf = Instance.new("Folder")
		lf.Name = "L" .. li
		lf.Parent = folder

		-- Generated layers: monster camps sit at the landmarks (exploration pays off)
		local camps = WorldService.layerCamps and WorldService.layerCamps[li]
		if camps and #camps > 0 then
			for _, campPos in ipairs(camps) do
				spawnMonster(li, campPos, lf, false)
			end
		end

		local remaining = Balance.MONSTER_COUNT - (camps and #camps or 0)
		for _ = 1, math.max(0, remaining) do
			local mx = layer.offsetX + rng:NextNumber(-60, 60)
			local mz = rng:NextNumber(-60, 60)
			spawnMonster(li, Vector3.new(mx, groundY(mx, mz), mz), lf, false)
		end

		-- Boss on milestone layers
		if layer.boss then
			local bx, bz = layer.offsetX, 60
			spawnMonster(li, Vector3.new(bx, groundY(bx, bz), bz), lf, true)
		end
	end

	-- Decisions at ~10 Hz, animation every frame (smooth movement)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			thinkStep()
			acc = 0
		end
		animStep(dt)
	end)

	print("[MonsterService] Monster + Bosse gespawnt.")
end

return MonsterService
