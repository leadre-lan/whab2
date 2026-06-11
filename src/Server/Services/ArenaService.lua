-- ArenaService.lua — PVP arena (own world, far from the hub): 1v1 queue,
-- training fights vs an AI bot, fame + ELO
local ArenaService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

-- The arena is its own world — far south, never visible from the overworld
local ARENA_X = -320
local ARENA_Z = -6000
local ARENA_R = 70            -- fight area radius (bigger than before)

-- Queue circles in the hub (south of the plaza)
local QUEUE_1V1   = Vector3.new(-330, 1, -78)
local QUEUE_TRAIN = Vector3.new(-306, 1, -78)
local QUEUE_RADIUS = 6
local HUB_RETURN   = Vector3.new(-320, 5, -45)

local dataService    = nil
local monsterService = nil
local net            = nil

local queue       = {}
local inQueue     = {}
local activeMatch = nil   -- { p1, p2, conns }
local training    = {}    -- [player] = botModel

-- ── Arena geometry ───────────────────────────────────────────────────────────
local function buildArena(parent)
	local rng = Random.new(5)

	-- Ground: large sand disc + a slightly larger grass disc under it
	local ground = Instance.new("Part")
	ground.Shape = Enum.PartType.Cylinder
	ground.Size = Vector3.new(4, (ARENA_R + 90) * 2, (ARENA_R + 90) * 2)
	ground.CFrame = CFrame.new(ARENA_X, -1.5, ARENA_Z) * CFrame.Angles(0, 0, math.rad(90))
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(92, 118, 56)
	ground.Anchored = true
	ground.Parent = parent

	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(2, ARENA_R * 2, ARENA_R * 2)
	floor.CFrame = CFrame.new(ARENA_X, 0.5, ARENA_Z) * CFrame.Angles(0, 0, math.rad(90))
	floor.Material = Enum.Material.Sand
	floor.Color = Color3.fromRGB(208, 188, 148)
	floor.Anchored = true
	floor.Parent = parent

	-- ── Bamboo wall: 3 staggered rings, grown together, no gaps. ──
	-- The radius wobbles with noise so the circle looks natural, stalks
	-- overlap, vary in height/thickness/color and have node rings.
	for ring = 0, 2 do
		local baseR = ARENA_R + 6 + ring * 3.2
		local count = math.floor(baseR * 1.05)   -- dense: ~1 stalk per stud of arc
		for i = 0, count - 1 do
			local ang = (i / count) * math.pi * 2 + ring * 0.045
			-- Natural wobble of the ring radius
			local wobble = math.noise(math.cos(ang) * 2.2, math.sin(ang) * 2.2, ring * 7) * 5
			local r = baseR + wobble + rng:NextNumber(-1.2, 1.2)
			local bx = ARENA_X + math.cos(ang) * r
			local bz = ARENA_Z + math.sin(ang) * r

			local h  = rng:NextNumber(34, 52) - ring * 3
			local th = rng:NextNumber(1.6, 2.4)
			local green = Color3.fromRGB(
				50 + rng:NextInteger(0, 28),
				140 + rng:NextInteger(0, 45),
				42 + rng:NextInteger(0, 20))

			local stalk = Instance.new("Part")
			stalk.Shape = Enum.PartType.Cylinder
			stalk.Size = Vector3.new(h, th, th)
			stalk.CFrame = CFrame.new(bx, h / 2 + 1, bz)
				* CFrame.Angles(
					math.rad(rng:NextNumber(-2.5, 2.5)),   -- slight lean
					0,
					math.rad(90 + rng:NextNumber(-2.5, 2.5)))
			stalk.Material = Enum.Material.Wood     -- subtle texture, reads as bamboo
			stalk.Color = green
			stalk.Anchored = true
			stalk.Parent = parent

			-- Node rings every ~5 studs (only inner ring gets them — perf)
			if ring == 0 then
				local nodeColor = green:Lerp(Color3.fromRGB(30, 80, 25), 0.5)
				for ny = 5, h - 3, 5.5 do
					local node = Instance.new("Part")
					node.Shape = Enum.PartType.Cylinder
					node.Size = Vector3.new(0.35, th * 1.15, th * 1.15)
					node.CFrame = CFrame.new(bx, ny + 1, bz) * CFrame.Angles(0, 0, math.rad(90))
					node.Material = Enum.Material.Wood
					node.Color = nodeColor
					node.Anchored = true
					node.CanCollide = false
					node.Parent = parent
				end
			end
		end
	end

	-- Canopy of leaves leaning inward at the top (closes the view upward a bit)
	for i = 0, 47 do
		local ang = (i / 48) * math.pi * 2
		local r = ARENA_R + 4
		local leaf = Instance.new("Part")
		leaf.Size = Vector3.new(7, 0.3, 3.2)
		leaf.CFrame = CFrame.new(
				ARENA_X + math.cos(ang) * r,
				rng:NextNumber(30, 42),
				ARENA_Z + math.sin(ang) * r)
			* CFrame.Angles(0, -ang, math.rad(-28))
		leaf.Material = Enum.Material.Grass
		leaf.Color = Color3.fromRGB(58, 150, 48)
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Parent = parent
	end

	-- Exit prompt in the middle of the arena edge
	local exitPost = Instance.new("Part")
	exitPost.Size = Vector3.new(1, 5, 1)
	exitPost.Position = Vector3.new(ARENA_X, 3.5, ARENA_Z + ARENA_R - 4)
	exitPost.Material = Enum.Material.Wood
	exitPost.Color = Color3.fromRGB(110, 78, 45)
	exitPost.Anchored = true
	exitPost.Parent = parent

	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ActionText = "Arena verlassen"
	exitPrompt.ObjectText = "Ausgang"
	exitPrompt.HoldDuration = 0
	exitPrompt.MaxActivationDistance = 12
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = exitPost
	exitPrompt.Triggered:Connect(function(player)
		ArenaService.leaveArena(player)
	end)
end

-- Queue circle marker in the hub
local function makeQueueCircle(parent, pos, color, text)
	local qc = Instance.new("Part")
	qc.Shape = Enum.PartType.Cylinder
	qc.Size = Vector3.new(0.3, QUEUE_RADIUS * 2, QUEUE_RADIUS * 2)
	qc.CFrame = CFrame.new(pos.X, 1.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	qc.Material = Enum.Material.Neon
	qc.Color = color
	qc.Transparency = 0.55
	qc.Anchored = true
	qc.CanCollide = false
	qc.Parent = parent

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 46)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 60
	bb.Parent = qc

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.Parent = bb
	return lbl
end

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function teleportTo(player, pos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(pos)
	end
end

local function healPlayer(player)
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = hum.MaxHealth end
end

function ArenaService.leaveArena(player)
	-- Cancel training fight if running
	local bot = training[player]
	if bot then
		training[player] = nil
		monsterService.despawn(bot)
	end
	-- Forfeit active match if in one
	if activeMatch and (activeMatch.p1 == player or activeMatch.p2 == player) then
		local winner = (activeMatch.p1 == player) and activeMatch.p2 or activeMatch.p1
		ArenaService._endMatch(winner, player)
		return
	end
	healPlayer(player)
	teleportTo(player, HUB_RETURN)
	net.ApplyLayerLighting:FireClient(player, 0)
end

-- ── 1v1 match lifecycle ──────────────────────────────────────────────────────
function ArenaService._endMatch(winner, loser)
	if not activeMatch then return end
	for _, c in ipairs(activeMatch.conns) do c:Disconnect() end
	local p1, p2 = activeMatch.p1, activeMatch.p2
	activeMatch = nil

	if winner and loser then
		local wd = dataService.get(winner)
		local ld = dataService.get(loser)
		if wd and ld then
			wd.fame    = (wd.fame or 0) + Balance.FAME_WIN
			wd.pvpWins = (wd.pvpWins or 0) + 1
			ld.pvpLosses = (ld.pvpLosses or 0) + 1

			local we, le = wd.elo or 1000, ld.elo or 1000
			local expected = 1 / (1 + 10 ^ ((le - we) / 400))
			local delta = math.floor(Balance.ELO_K * (1 - expected) + 0.5)
			wd.elo = we + delta
			ld.elo = math.max(0, le - delta)

			dataService.sendUpdate(winner)
			dataService.sendUpdate(loser)

			net.Notify:FireClient(winner, "🏆 SIEG! +" .. Balance.FAME_WIN .. " Ruhm, +" .. delta .. " ELO")
			net.Notify:FireClient(loser, "💀 Niederlage… -" .. delta .. " ELO")
		end
	end

	for _, p in ipairs({ p1, p2 }) do
		if p and p.Parent then
			healPlayer(p)
			teleportTo(p, HUB_RETURN)
			net.ApplyLayerLighting:FireClient(p, 0)
		end
	end
end

local function startMatch(p1, p2)
	local conns = {}
	activeMatch = { p1 = p1, p2 = p2, conns = conns }

	for _, info in ipairs({ { p = p1, x = -ARENA_R / 2 }, { p = p2, x = ARENA_R / 2 } }) do
		local char = info.p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			activeMatch = nil
			return
		end
		hum.Health = hum.MaxHealth
		root.CFrame = CFrame.new(ARENA_X + info.x, 5, ARENA_Z)

		table.insert(conns, hum.Died:Connect(function()
			local winner = (info.p == p1) and p2 or p1
			ArenaService._endMatch(winner, info.p)
		end))
	end

	table.insert(conns, Players.PlayerRemoving:Connect(function(p)
		if activeMatch and (p == p1 or p == p2) then
			local winner = (p == p1) and p2 or p1
			ArenaService._endMatch(winner, p)
		end
	end))

	net.Notify:FireClient(p1, "⚔ Match gegen " .. p2.Name .. " — KÄMPFE!")
	net.Notify:FireClient(p2, "⚔ Match gegen " .. p1.Name .. " — KÄMPFE!")
end

-- ── Training fight vs AI bot ──────────────────────────────────────────────────
local function startTraining(player, botFolder)
	if training[player] then return end

	local pdata = dataService.get(player)
	local layerIdx = pdata and math.max(1, pdata.highestLayer or 1) or 1

	healPlayer(player)
	teleportTo(player, Vector3.new(ARENA_X - ARENA_R / 2, 5, ARENA_Z))
	net.Notify:FireClient(player, "🤖 Trainings-Kampf! Besiege den Bot (Q: Dash, F: Block)")

	local botPos = Vector3.new(ARENA_X + ARENA_R / 2, 1, ARENA_Z)
	local bot = monsterService.spawnTrainingBot(layerIdx, botPos, botFolder, function(killer)
		training[player] = nil
		net.Notify:FireClient(player, "🏆 Bot besiegt! Gutes Training.")
		task.wait(2)
		if player.Parent then
			healPlayer(player)
			teleportTo(player, HUB_RETURN)
			net.ApplyLayerLighting:FireClient(player, 0)
		end
	end)
	training[player] = bot

	-- Player death or leaving cancels training
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local conn
		conn = hum.Died:Connect(function()
			conn:Disconnect()
			if training[player] then
				monsterService.despawn(training[player])
				training[player] = nil
				net.Notify:FireClient(player, "💀 Vom Bot besiegt — versuch's nochmal!")
			end
		end)
	end
end

function ArenaService.areOpponents(a, b)
	if not activeMatch then return false end
	return (activeMatch.p1 == a and activeMatch.p2 == b)
		or (activeMatch.p1 == b and activeMatch.p2 == a)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function ArenaService.init(ds, ms, netRef)
	dataService    = ds
	monsterService = ms
	net            = netRef

	local old = workspace:FindFirstChild("Arena")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	buildArena(folder)

	local botFolder = Instance.new("Folder")
	botFolder.Name = "TrainingBots"
	botFolder.Parent = folder

	local queueLabel = makeQueueCircle(folder, QUEUE_1V1,
		Color3.fromRGB(235, 90, 70), "⚔ 1v1 Queue")
	makeQueueCircle(folder, QUEUE_TRAIN,
		Color3.fromRGB(90, 160, 255), "🤖 Training vs Bot")

	-- Zone polling: queue + training circles
	task.spawn(function()
		while true do
			task.wait(0.5)

			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not root then continue end
				local flat1 = (root.Position - QUEUE_1V1) * Vector3.new(1, 0, 1)
				local flatT = (root.Position - QUEUE_TRAIN) * Vector3.new(1, 0, 1)

				local isFighting = (activeMatch and (activeMatch.p1 == p or activeMatch.p2 == p))
					or training[p] ~= nil

				-- 1v1 queue
				if flat1.Magnitude <= QUEUE_RADIUS and not inQueue[p] and not isFighting then
					inQueue[p] = true
					table.insert(queue, p)
					net.Notify:FireClient(p, "⚔ In der Queue! (" .. #queue .. " wartend)")
				elseif flat1.Magnitude > QUEUE_RADIUS and inQueue[p] then
					inQueue[p] = nil
					for i, qp in ipairs(queue) do
						if qp == p then table.remove(queue, i) break end
					end
				end

				-- Training circle: instant start
				if flatT.Magnitude <= QUEUE_RADIUS and not isFighting and not inQueue[p] then
					startTraining(p, botFolder)
				end
			end

			for i = #queue, 1, -1 do
				if not queue[i].Parent then
					inQueue[queue[i]] = nil
					table.remove(queue, i)
				end
			end

			queueLabel.Text = "⚔ 1v1 Queue (" .. #queue .. ")"

			if #queue >= 2 and not activeMatch then
				local p1 = table.remove(queue, 1)
				local p2 = table.remove(queue, 1)
				inQueue[p1], inQueue[p2] = nil, nil
				startMatch(p1, p2)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		local bot = training[p]
		if bot then
			training[p] = nil
			monsterService.despawn(bot)
		end
	end)

	print("[ArenaService] Arena (eigene Welt) + Trainings-Bots bereit.")
end

return ArenaService
