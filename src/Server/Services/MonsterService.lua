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
local function buildMonsterModel(layer, pos, isBoss)
	local scale = isBoss and 2.6 or 1
	local color = layer.glowColor:Lerp(Color3.fromRGB(30, 30, 30), isBoss and 0.25 or 0.45)

	local model = Instance.new("Model")
	model.Name = isBoss and (layer.boss and layer.boss.name or "Boss") or layer.monsterName

	local body = Instance.new("Part")
	body.Name  = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size  = Vector3.new(3.4, 3.4, 3.4) * scale
	body.Position = pos + Vector3.new(0, 1.7 * scale, 0)
	body.Material = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Color = color
	body.Anchored = true
	body.CanCollide = false
	body:SetAttribute("IsMonster", true)
	body.Parent = model
	model.PrimaryPart = body

	-- Eyes
	for side = -1, 1, 2 do
		local eye = Instance.new("Part")
		eye.Name  = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size  = Vector3.new(0.55, 0.55, 0.55) * scale
		eye.Material = Enum.Material.Neon
		eye.Color = isBoss and Color3.fromRGB(255, 60, 40) or Color3.fromRGB(255, 235, 200)
		eye.Anchored = true
		eye.CanCollide = false
		eye.CFrame = body.CFrame * CFrame.new(side * 0.7 * scale, 0.5 * scale, -1.4 * scale)
		eye.Parent = model
	end

	-- Spikes on top (bosses get a crown of them)
	local spikeCount = isBoss and 5 or 2
	for i = 1, spikeCount do
		local spike = Instance.new("Part")
		spike.Name = "Spike"
		spike.Size = Vector3.new(0.4, 1.3, 0.4) * scale
		spike.Material = Enum.Material.SmoothPlastic
		spike.Color = layer.glowColor
		spike.Anchored = true
		spike.CanCollide = false
		spike.CFrame = body.CFrame
			* CFrame.Angles(0, (i / spikeCount) * math.pi * 2, math.rad(25))
			* CFrame.new(0, 1.9 * scale, 0)
		spike.Parent = model
	end

	-- Health bar billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.new(0, isBoss and 130 or 80, 0, isBoss and 32 or 22)
	bb.StudsOffset = Vector3.new(0, 3 * scale, 0)
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

	net.HitEffect:FireClient(player, body.Position, m.baseColor, false, nil, damage, nil)

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
		net.HitEffect:FireClient(player, m.body.Position, m.baseColor, true, nil, nil, nil)
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

local groundRayParams = nil  -- set in init (excludes the Monsters folder)

local function groundYAt(x, z, fallback)
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
				net.HitEffect:FireClient(p, r.Position, Color3.fromRGB(255, 60, 40), false, nil, nil, nil)
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
			m.groundY = groundYAt(m.pos.X, m.pos.Z, m.groundY)
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
