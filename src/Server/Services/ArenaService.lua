-- ArenaService.lua — PVP arena: queue zone, 1v1 matches, fame + ELO
local ArenaService = {}

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")

local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))

-- Arena is south of the hub
local ARENA_X = -320
local ARENA_Z = -160
local QUEUE_POS = Vector3.new(-320, 1, -75)   -- queue circle just south of hub arch
local QUEUE_RADIUS = 8

local dataService = nil
local net         = nil

local queue        = {}   -- ordered list of players standing in the queue circle
local inQueue      = {}   -- [player] = true
local activeMatch  = nil  -- { p1, p2, conns = {} }

-- ── Arena geometry ───────────────────────────────────────────────────────────
local function buildArena(parent)
	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(2, 90, 90)
	floor.CFrame = CFrame.new(ARENA_X, 0.5, ARENA_Z) * CFrame.Angles(0, 0, math.rad(90))
	floor.Material = Enum.Material.Sand
	floor.Color = Color3.fromRGB(205, 185, 145)
	floor.Anchored = true
	floor.Parent = parent

	-- Bamboo ring wall
	local rng = Random.new(5)
	for a = 0, 35 do
		local ang = a / 36 * math.pi * 2
		local bx = ARENA_X + math.cos(ang) * 46
		local bz = ARENA_Z + math.sin(ang) * 46
		local h = rng:NextNumber(16, 24)
		local stalk = Instance.new("Part")
		stalk.Shape = Enum.PartType.Cylinder
		stalk.Size = Vector3.new(h, 1.6, 1.6)
		stalk.CFrame = CFrame.new(bx, h / 2 + 1, bz) * CFrame.Angles(0, 0, math.rad(90))
		stalk.Material = Enum.Material.SmoothPlastic
		stalk.Color = Color3.fromRGB(62, 165, 52)
		stalk.Anchored = true
		stalk.Parent = parent
	end

	-- Queue circle marker
	local qc = Instance.new("Part")
	qc.Name = "QueueCircle"
	qc.Shape = Enum.PartType.Cylinder
	qc.Size = Vector3.new(0.3, QUEUE_RADIUS * 2, QUEUE_RADIUS * 2)
	qc.CFrame = CFrame.new(QUEUE_POS.X, 1.2, QUEUE_POS.Z) * CFrame.Angles(0, 0, math.rad(90))
	qc.Material = Enum.Material.Neon
	qc.Color = Color3.fromRGB(235, 90, 70)
	qc.Transparency = 0.55
	qc.Anchored = true
	qc.CanCollide = false
	qc.Parent = parent

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 240, 0, 70)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.Parent = qc

	local lbl = Instance.new("TextLabel")
	lbl.Name = "QueueLabel"
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 120, 100)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = "⚔ 1v1 Queue\nReinstellen = beitreten"
	lbl.Parent = bb

	return lbl
end

-- ── Match lifecycle ──────────────────────────────────────────────────────────
local function endMatch(winner, loser)
	if not activeMatch then return end
	for _, c in ipairs(activeMatch.conns) do c:Disconnect() end
	local p1, p2 = activeMatch.p1, activeMatch.p2
	activeMatch = nil

	-- Rewards + ELO
	if winner and loser then
		local wd = dataService.get(winner)
		local ld = dataService.get(loser)
		if wd and ld then
			wd.fame    = (wd.fame or 0) + Balance.FAME_WIN
			wd.pvpWins = (wd.pvpWins or 0) + 1
			ld.pvpLosses = (ld.pvpLosses or 0) + 1

			-- Standard ELO
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

	-- Teleport both back to hub, heal
	for _, p in ipairs({ p1, p2 }) do
		if p and p.Parent then
			local char = p.Character
			local hum  = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum then hum.Health = hum.MaxHealth end
			if root then root.CFrame = CFrame.new(-320, 5, -40) end
		end
	end
end

local function startMatch(p1, p2)
	local conns = {}
	activeMatch = { p1 = p1, p2 = p2, conns = conns }

	for _, info in ipairs({ { p = p1, x = -18 }, { p = p2, x = 18 } }) do
		local char = info.p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			activeMatch = nil
			return
		end
		hum.Health = hum.MaxHealth
		root.CFrame = CFrame.new(ARENA_X + info.x, 5, ARENA_Z)

		-- Death ends the match
		table.insert(conns, hum.Died:Connect(function()
			local winner = (info.p == p1) and p2 or p1
			endMatch(winner, info.p)
		end))
	end

	-- Leaving ends the match
	table.insert(conns, Players.PlayerRemoving:Connect(function(p)
		if activeMatch and (p == p1 or p == p2) then
			local winner = (p == p1) and p2 or p1
			endMatch(winner, p)
		end
	end))

	net.Notify:FireClient(p1, "⚔ Match gegen " .. p2.Name .. " — KÄMPFE!")
	net.Notify:FireClient(p2, "⚔ Match gegen " .. p1.Name .. " — KÄMPFE!")
end

-- ── Public: is this pair currently fighting? (CombatService asks) ────────────
function ArenaService.areOpponents(a, b)
	if not activeMatch then return false end
	return (activeMatch.p1 == a and activeMatch.p2 == b)
		or (activeMatch.p1 == b and activeMatch.p2 == a)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function ArenaService.init(ds, netRef)
	dataService = ds
	net         = netRef

	local old = workspace:FindFirstChild("Arena")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local queueLabel = buildArena(folder)

	-- Queue detection: poll player positions inside the queue circle
	task.spawn(function()
		while true do
			task.wait(0.5)

			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local inCircle = false
				if root then
					local flat = (root.Position - QUEUE_POS) * Vector3.new(1, 0, 1)
					inCircle = flat.Magnitude <= QUEUE_RADIUS
				end

				local isFighting = activeMatch and (activeMatch.p1 == p or activeMatch.p2 == p)

				if inCircle and not inQueue[p] and not isFighting then
					inQueue[p] = true
					table.insert(queue, p)
					net.Notify:FireClient(p, "⚔ In der Queue! (" .. #queue .. " wartend)")
				elseif not inCircle and inQueue[p] then
					inQueue[p] = nil
					for i, qp in ipairs(queue) do
						if qp == p then table.remove(queue, i) break end
					end
				end
			end

			-- Remove disconnected players
			for i = #queue, 1, -1 do
				if not queue[i].Parent then
					inQueue[queue[i]] = nil
					table.remove(queue, i)
				end
			end

			queueLabel.Text = "⚔ 1v1 Queue (" .. #queue .. ")\nReinstellen = beitreten"

			-- Start a match when 2+ queued and no match running
			if #queue >= 2 and not activeMatch then
				local p1 = table.remove(queue, 1)
				local p2 = table.remove(queue, 1)
				inQueue[p1], inQueue[p2] = nil, nil
				startMatch(p1, p2)
			end
		end
	end)

	print("[ArenaService] PVP-Arena bereit.")
end

return ArenaService
