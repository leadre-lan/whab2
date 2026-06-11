-- ArenaService.lua — 1v1-Sniper-Arenen: Queue, Match-Loop, Respawns, Rewards
local ArenaService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local dataService = nil
local botService  = nil   -- via setBotService (Server-Wiring)
local net         = nil

local queue          = {}    -- Array von Playern
local playerMatch    = {}    -- [player] = match
local arenaFree      = {}    -- [idx] = true/false
local arenaSpawns    = {}    -- [idx] = { CFrame, CFrame }
local arenaWaypoints = {}    -- [idx] = { Vector3 } (Deckungen auf der Bot-Hälfte)

function ArenaService.setBotService(svc)
	botService = svc
end

-- ── Arena-Geometrie ───────────────────────────────────────────────────────────
local function part(props, parent)
	local p = Instance.new("Part")
	p.Size = props.size
	if props.cframe then p.CFrame = props.cframe else p.Position = props.pos end
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color
	p.Anchored = true
	p.CanCollide = props.collide ~= false
	if props.transparency then p.Transparency = props.transparency end
	p.Parent = parent
	return p
end

local function buildArena(idx, folder)
	local cx = Config.ARENA_BASE_X + (idx - 1) * Config.ARENA_SPACING
	local W, L, WALL_H = 70, 150, 24

	local dark  = Color3.fromRGB(28, 30, 42)
	local floor = Color3.fromRGB(38, 41, 58)
	local neon  = Color3.fromRGB(150, 80, 255)

	part({ size = Vector3.new(W, 2, L), pos = Vector3.new(cx, -1, 0),
		material = Enum.Material.Slate, color = floor }, folder)

	-- Wände (hoch genug, dass niemand rausspringt)
	for _, w in ipairs({
		{ Vector3.new(W, WALL_H, 2),  Vector3.new(cx, WALL_H / 2, -L / 2) },
		{ Vector3.new(W, WALL_H, 2),  Vector3.new(cx, WALL_H / 2, L / 2) },
		{ Vector3.new(2, WALL_H, L),  Vector3.new(cx - W / 2, WALL_H / 2, 0) },
		{ Vector3.new(2, WALL_H, L),  Vector3.new(cx + W / 2, WALL_H / 2, 0) },
	}) do
		part({ size = w[1], pos = w[2], material = Enum.Material.Concrete, color = dark }, folder)
	end

	-- Neon-Bodenlinien (Mitte + Spawn-Linien)
	for _, z in ipairs({ 0, -55, 55 }) do
		part({ size = Vector3.new(W, 0.2, 0.8), pos = Vector3.new(cx, 0.05, z),
			material = Enum.Material.Neon, color = neon, collide = false }, folder)
	end

	-- Symmetrische Deckung: Kisten + niedrige Mauern + Mittel-Pylon
	-- (beide Seiten identisch → fair)
	local coverColor = Color3.fromRGB(52, 56, 80)
	arenaWaypoints[idx] = {}
	for _, side in ipairs({ -1, 1 }) do
		for _, c in ipairs({
			{ x = -18, z = 28, s = Vector3.new(6, 5, 6) },
			{ x = 16,  z = 34, s = Vector3.new(8, 4, 5) },
			{ x = 2,   z = 18, s = Vector3.new(10, 3.2, 3) },
			{ x = -24, z = 12, s = Vector3.new(5, 6, 5) },
			{ x = 22,  z = 14, s = Vector3.new(5, 7, 5) },
		}) do
			part({ size = c.s,
				pos = Vector3.new(cx + c.x * side, c.s.Y / 2, c.z * side),
				material = Enum.Material.Metal, color = coverColor }, folder)
			-- Bot-Wegpunkte: jeweils HINTER der Deckung der +Z-Hälfte
			if side == 1 then
				table.insert(arenaWaypoints[idx],
					Vector3.new(cx + c.x, 1, c.z + c.s.Z / 2 + 3.5))
			end
		end
	end
	table.insert(arenaWaypoints[idx], Vector3.new(cx, 1, 55))
	part({ size = Vector3.new(4, 9, 4), pos = Vector3.new(cx, 4.5, 0),
		material = Enum.Material.Metal, color = coverColor }, folder)
	part({ size = Vector3.new(4.4, 0.4, 4.4), pos = Vector3.new(cx, 9.2, 0),
		material = Enum.Material.Neon, color = neon, collide = false }, folder)

	-- Spawn-Podeste an beiden Enden
	for i, z in ipairs({ -62, 62 }) do
		part({ size = Vector3.new(10, 0.6, 10), pos = Vector3.new(cx, 0.4, z),
			material = Enum.Material.Neon, color = neon, transparency = 0.5 }, folder)
		arenaSpawns[idx] = arenaSpawns[idx] or {}
		arenaSpawns[idx][i] = CFrame.new(cx, 4, z) * CFrame.Angles(0, z > 0 and math.rad(180) or 0, 0)
	end
end

-- ── Match-Verwaltung ──────────────────────────────────────────────────────────
local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char ~= nil and hum ~= nil and hum.Health > 0 and player.Parent ~= nil
end

local function teleport(player, cf)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = cf end
end

local function lobbyCFrame()
	local spawnLoc = workspace:FindFirstChild("LobbySpawn", true)
	return spawnLoc and (spawnLoc.CFrame + Vector3.new(0, 4, 0)) or CFrame.new(0, 6, -30)
end

local function sendState(match, state, extra)
	for _, p in ipairs(match.players) do
		local opponent = (p == match.players[1]) and match.players[2] or match.players[1]
		local payload = {
			state    = state,
			opponent = opponent.Name,
			score    = { you = match.score[p], enemy = match.score[opponent] },
			timeLeft = math.max(0, math.ceil(match.endTime - os.clock())),
		}
		if extra then
			for k, v in pairs(extra) do payload[k] = v end
		end
		if p.Parent then
			net.MatchState:FireClient(p, payload)
		end
	end
end

-- Forward-Declaration: endMatch stößt nach Arena-Freigabe die Queue wieder an
local tryStartMatchesRef

-- Endscreen pro Spieler (eigene Sicht: youWon)
local function sendStateForPlayer(p, match, winner)
	if not p.Parent then return end
	net.MatchState:FireClient(p, {
		state = "ended",
		winner = winner and winner.Name or "—",
		youWon = (p == winner),
	})
end

local function endMatch(match, winner)
	if match.ended then return end
	match.ended = true
	match.live = false

	for _, p in ipairs(match.players) do
		playerMatch[p] = nil
	end
	arenaFree[match.arenaIdx] = true

	for _, p in ipairs(match.players) do
		if p.Parent then
			-- Falls das Match noch im (angefrorenen) Countdown endete
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = false end

			local won = (p == winner)
			dataService.addCredits(p, won and Config.WIN_REWARD or Config.LOSS_REWARD)
			if won then
				local d = dataService.get(p)
				if d then d.wins += 1 end
				dataService.sendUpdate(p)
			end
			net.PlaySFX:FireClient(p, won and "Chime" or "ChimeSoft", 0.7)
			net.Notify:FireClient(p, won
				and ("🏆 Sieg! +" .. Config.WIN_REWARD .. " " .. Config.CURRENCY_NAME)
				or ("💀 Niederlage. +" .. Config.LOSS_REWARD .. " " .. Config.CURRENCY_NAME))
			sendStateForPlayer(p, match, winner)
			teleport(p, lobbyCFrame())
		end
	end

	-- Arena ist frei → wartende Queue-Paare können starten
	task.defer(tryStartMatchesRef)
end

local function startMatch(a, b)
	local arenaIdx = nil
	for i = 1, Config.ARENA_COUNT do
		if arenaFree[i] then
			arenaIdx = i
			break
		end
	end
	if not arenaIdx then
		-- keine Arena frei → zurück in die Queue (vorne); Aufrufer stoppt die Schleife
		table.insert(queue, 1, b)
		table.insert(queue, 1, a)
		return false
	end
	arenaFree[arenaIdx] = false

	local match = {
		arenaIdx = arenaIdx,
		players  = { a, b },
		score    = { [a] = 0, [b] = 0 },
		live     = false,
		ended    = false,
		endTime  = os.clock() + Config.MATCH_TIME + Config.COUNTDOWN,
	}
	playerMatch[a] = match
	playerMatch[b] = match

	task.spawn(function()
		-- Teleport auf die Spawns + einfrieren
		for i, p in ipairs(match.players) do
			teleport(p, arenaSpawns[arenaIdx][i])
			net.PlaySFX:FireClient(p, "Teleport", 0.6)
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = true end
		end

		-- Countdown
		for n = Config.COUNTDOWN, 1, -1 do
			sendState(match, "countdown", { countdown = n })
			task.wait(1)
			if match.ended then return end
		end

		for _, p in ipairs(match.players) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = false end
		end
		match.live = true
		match.endTime = os.clock() + Config.MATCH_TIME
		sendState(match, "live")

		-- Match-Loop
		while not match.ended do
			task.wait(1)
			if match.ended then break end
			local a1, a2 = match.players[1], match.players[2]
			if not a1.Parent and not a2.Parent then
				endMatch(match, nil)
			elseif not a1.Parent then
				endMatch(match, a2)
			elseif not a2.Parent then
				endMatch(match, a1)
			elseif os.clock() >= match.endTime then
				-- Zeit um: der Führende gewinnt (Gleichstand → niemand)
				local s1, s2 = match.score[a1], match.score[a2]
				endMatch(match, s1 > s2 and a1 or (s2 > s1 and a2 or nil))
			else
				sendState(match, "live")
			end
		end
	end)
	return true
end

local function tryStartMatches()
	while #queue >= 2 do
		local a = table.remove(queue, 1)
		local b = table.remove(queue, 1)
		if not a.Parent then
			if b.Parent then table.insert(queue, 1, b) end
		elseif not b.Parent then
			table.insert(queue, 1, a)
		elseif not alive(a) then
			table.insert(queue, b)
		elseif not alive(b) then
			table.insert(queue, a)
		elseif startMatch(a, b) == false then
			-- keine Arena frei: warten, bis eine frei wird
			break
		end
	end
end
tryStartMatchesRef = tryStartMatches

-- ── Bot-1v1 (Training) ────────────────────────────────────────────────────────
local function sendBotState(match, state, extra)
	local p = match.players[1]
	if not p.Parent then return end
	local payload = {
		state    = state,
		opponent = Config.BOT_NAME,
		score    = { you = match.score, enemy = match.botScore },
		timeLeft = math.max(0, math.ceil(match.endTime - os.clock())),
	}
	if extra then
		for k, v in pairs(extra) do payload[k] = v end
	end
	net.MatchState:FireClient(p, payload)
end

local function endBotMatch(match, playerWon)
	if match.ended then return end
	match.ended = true
	match.live = false

	local p = match.players[1]
	playerMatch[p] = nil
	arenaFree[match.arenaIdx] = true
	if match.bot then match.bot.destroy() end

	if p.Parent then
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = false end

		if playerWon then
			dataService.addCredits(p, Config.BOT_WIN_REWARD)
			net.PlaySFX:FireClient(p, "Chime", 0.7)
			net.Notify:FireClient(p, "🏆 Trainings-Sieg! +" .. Config.BOT_WIN_REWARD .. " " .. Config.CURRENCY_NAME)
		else
			net.PlaySFX:FireClient(p, "ChimeSoft", 0.6)
			net.Notify:FireClient(p, "🤖 Der Bot gewinnt — nochmal!")
		end
		net.MatchState:FireClient(p, {
			state = "ended",
			winner = playerWon and p.Name or Config.BOT_NAME,
			youWon = playerWon == true,
		})
		teleport(p, lobbyCFrame())
	end

	task.defer(tryStartMatchesRef)
end

local function spawnBotForMatch(match)
	if match.ended or not botService then return end
	local p = match.players[1]
	match.bot = botService.spawn({
		spawnCF   = arenaSpawns[match.arenaIdx][2],
		waypoints = arenaWaypoints[match.arenaIdx] or {},
		getTarget = function()
			return p.Parent and p or nil
		end,
		shouldAct = function()
			return match.live and not match.ended
		end,
		onHitPlayer = function(victim)
			if match.ended or not match.live or victim ~= p then return end
			local char = victim.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
			hum.Health = 0
			match.botScore += 1
			sendBotState(match, "live", { killBy = Config.BOT_NAME })

			if match.botScore >= Config.KILLS_TO_WIN then
				endBotMatch(match, false)
				return
			end
			task.delay(Config.RESPAWN_DELAY, function()
				if victim.Parent and playerMatch[victim] == match and not match.ended then
					victim:LoadCharacter()
				end
			end)
		end,
	})
end

function ArenaService.startBotMatch(player)
	if playerMatch[player] then return end
	if not botService then
		net.Notify:FireClient(player, "Bot-Service nicht verfügbar.")
		return
	end
	-- aus der PvP-Queue nehmen
	for i, p in ipairs(queue) do
		if p == player then
			table.remove(queue, i)
			net.QueueState:FireClient(player, false)
			break
		end
	end

	local arenaIdx = nil
	for i = 1, Config.ARENA_COUNT do
		if arenaFree[i] then
			arenaIdx = i
			break
		end
	end
	if not arenaIdx then
		net.Notify:FireClient(player, "Alle Arenen belegt — gleich nochmal versuchen!")
		return
	end
	arenaFree[arenaIdx] = false

	local match = {
		botMode  = true,
		arenaIdx = arenaIdx,
		players  = { player },
		score    = 0,
		botScore = 0,
		live     = false,
		ended    = false,
		endTime  = os.clock() + Config.MATCH_TIME + Config.COUNTDOWN,
	}
	playerMatch[player] = match

	task.spawn(function()
		teleport(player, arenaSpawns[arenaIdx][1])
		net.PlaySFX:FireClient(player, "Teleport", 0.6)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = true end

		spawnBotForMatch(match)

		for n = Config.COUNTDOWN, 1, -1 do
			sendBotState(match, "countdown", { countdown = n })
			task.wait(1)
			if match.ended then return end
		end

		local root2 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root2 then root2.Anchored = false end
		match.live = true
		match.endTime = os.clock() + Config.MATCH_TIME
		sendBotState(match, "live")

		while not match.ended do
			task.wait(1)
			if match.ended then break end
			if not player.Parent then
				endBotMatch(match, false)
			elseif os.clock() >= match.endTime then
				endBotMatch(match, match.score > match.botScore)
			else
				sendBotState(match, "live")
			end
		end
	end)
end

-- WeaponService meldet Bot-Treffer hierher (true = Kill zählt)
function ArenaService.tryHitBot(shooter, botModel)
	local match = playerMatch[shooter]
	if not match or not match.botMode or not match.live or match.ended then return false end
	if not match.bot or match.bot.model ~= botModel or not match.bot.alive then return false end

	match.bot.kill()
	match.score += 1
	sendBotState(match, "live", { killBy = shooter.Name })

	if match.score >= Config.KILLS_TO_WIN then
		endBotMatch(match, true)
		return true
	end
	task.delay(Config.RESPAWN_DELAY, function()
		if not match.ended then
			spawnBotForMatch(match)
		end
	end)
	return true
end

-- ── Public API (für WeaponService / LobbyService) ─────────────────────────────
function ArenaService.isInLiveMatch(player)
	local match = playerMatch[player]
	return match ~= nil and match.live and not match.ended
end

function ArenaService.canDamage(shooter, victim)
	local match = playerMatch[shooter]
	return match ~= nil and match.live and not match.ended and playerMatch[victim] == match
end

function ArenaService.onKill(killer, victim)
	local match = playerMatch[killer]
	if not match or match.ended then return end
	match.score[killer] += 1
	sendState(match, "live", { killBy = killer.Name })

	if match.score[killer] >= Config.KILLS_TO_WIN then
		endMatch(match, killer)
		return
	end

	-- Respawn des Opfers zurück auf seinen Arena-Spawn
	task.delay(Config.RESPAWN_DELAY, function()
		if victim.Parent and playerMatch[victim] == match and not match.ended then
			victim:LoadCharacter()
		end
	end)
end

function ArenaService.toggleQueue(player)
	if playerMatch[player] then return end
	for i, p in ipairs(queue) do
		if p == player then
			table.remove(queue, i)
			net.Notify:FireClient(player, "🚪 Queue verlassen.")
			net.QueueState:FireClient(player, false)
			return
		end
	end
	table.insert(queue, player)
	net.Notify:FireClient(player, "⚔ In der 1v1-Queue… (" .. #queue .. " wartend)")
	net.QueueState:FireClient(player, true)
	tryStartMatches()
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function ArenaService.init(ds, _ws, netRef)
	dataService = ds
	net         = netRef

	local folder = Instance.new("Folder")
	folder.Name = "Arenas"
	folder.Parent = workspace
	for i = 1, Config.ARENA_COUNT do
		arenaFree[i] = true
		buildArena(i, folder)
	end

	net.QueueJoin.OnServerEvent:Connect(function(player)
		ArenaService.toggleQueue(player)
	end)

	net.QueueBot.OnServerEvent:Connect(function(player)
		ArenaService.startBotMatch(player)
	end)

	-- Respawn während eines Matches → zurück in die Arena (statt Lobby)
	local function hookRespawn(player)
		player.CharacterAdded:Connect(function()
			local match = playerMatch[player]
			if match and not match.ended then
				task.wait(0.2)
				local slot = (player == match.players[1]) and 1 or 2
				teleport(player, arenaSpawns[match.arenaIdx][slot])
			end
		end)
	end
	Players.PlayerAdded:Connect(hookRespawn)
	for _, p in ipairs(Players:GetPlayers()) do
		hookRespawn(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		for i, p in ipairs(queue) do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
		local match = playerMatch[player]
		if match and not match.ended then
			if match.botMode then
				endBotMatch(match, false)
			else
				local opponent = (player == match.players[1]) and match.players[2] or match.players[1]
				endMatch(match, opponent.Parent and opponent or nil)
			end
		end
	end)

	print("[ArenaService] " .. Config.ARENA_COUNT .. " Arenen bereit.")
end

return ArenaService
