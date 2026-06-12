-- DefuseService.lua — CS-Style Bomben-Defusal (3v3, Spieler + Bots).
--
-- Ablauf pro Runde: Angreifer (T) müssen die Bombe am Bombenplatz legen,
-- Verteidiger (CT) halten den Platz / entschärfen. Kein Respawn in der Runde
-- (CS-Regeln) — wer stirbt, schaut von der Zuschauer-Plattform zu.
-- Bots laufen Routen (Mid/Links/Rechts), kämpfen gegen Spieler UND Bots,
-- T-Bots legen die Bombe, CT-Bots entschärfen. Seitenwechsel jede Runde.
local DefuseService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Debris  = game:GetService("Debris")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local dataService = nil
local botService  = nil
local net         = nil

-- ── Map-Layout (eine Map, ein Match gleichzeitig) ─────────────────────────────
local C = Vector3.new(-1500, 0, 0)   -- Map-Zentrum
local T_COLOR  = Color3.fromRGB(255, 170, 60)
local CT_COLOR = Color3.fromRGB(80, 170, 255)

local sitePart    = nil   -- Bombenplatz-Zone (Prompt-Träger)
local spectatorCF = CFrame.new(C + Vector3.new(0, 85, 0))
local tSpawnCF    = CFrame.new(C + Vector3.new(0, 4, 62)) * CFrame.Angles(0, math.rad(180), 0)
local ctSpawnCF   = CFrame.new(C + Vector3.new(0, 4, -62))

-- Bot-Routen (Welt-Koordinaten): T drückt Richtung Bombenplatz (z -30)
local function P(x, z) return C + Vector3.new(x, 1, z) end
local T_ROUTES = {
	{ P(6, 40), P(6, 12), P(-1, -8), P(0, -28) },        -- Mid (um die Kisten herum)
	{ P(-36, 42), P(-30, 24), P(-36, 4), P(-16, -28) },  -- Links
	{ P(36, 42), P(30, 24), P(36, 4), P(16, -28) },      -- Rechts
}
local CT_HOLDS = { P(0, -50), P(-20, -40), P(20, -40), P(-8, -22), P(8, -22) }
local CT_ROUTES = {
	{ P(-12, -50), P(-18, -38) },
	{ P(12, -50), P(18, -38) },
	{ P(0, -52), P(0, -40) },
}

-- ── Map bauen ─────────────────────────────────────────────────────────────────
local function part(props, parent)
	local p = Instance.new("Part")
	p.Size = props.size
	if props.cframe then p.CFrame = props.cframe else p.Position = props.pos end
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.color then p.Color = props.color end
	p.Anchored = true
	p.CanCollide = props.collide ~= false
	if props.transparency then p.Transparency = props.transparency end
	if props.name then p.Name = props.name end
	p.Parent = parent
	return p
end

local function buildMap()
	local folder = Instance.new("Folder")
	folder.Name = "DefuseMap"
	folder.Parent = workspace

	local DARK  = Color3.fromRGB(30, 32, 46)
	local FLOOR = Color3.fromRGB(36, 38, 54)
	local COVER = Color3.fromRGB(56, 60, 84)

	-- Boden + Wände
	local floorPart = part({ size = Vector3.new(210, 2, 170), pos = C + Vector3.new(0, -1, 0),
		material = Enum.Material.SmoothPlastic, color = FLOOR }, folder)
	floorPart.Reflectance = 0.1
	floorPart:SetAttribute("EnvKind", "panels")
	floorPart:SetAttribute("EnvFaces", "Top")
	floorPart:SetAttribute("EnvStuds", 16)
	floorPart:SetAttribute("EnvAlpha", 0.2)
	game:GetService("CollectionService"):AddTag(floorPart, "EnvTexture")

	for _, w in ipairs({
		{ Vector3.new(210, 26, 2), C + Vector3.new(0, 13, -85) },
		{ Vector3.new(210, 26, 2), C + Vector3.new(0, 13, 85) },
		{ Vector3.new(2, 26, 170), C + Vector3.new(-105, 13, 0) },
		{ Vector3.new(2, 26, 170), C + Vector3.new(105, 13, 0) },
	}) do
		part({ size = w[1], pos = w[2], material = Enum.Material.Concrete, color = DARK }, folder)
	end

	-- Lane-Trennwände (Mid vs Links/Rechts) mit Durchgängen
	for _, side in ipairs({ -1, 1 }) do
		part({ size = Vector3.new(2, 9, 60), pos = C + Vector3.new(side * 22, 4.5, 18),
			material = Enum.Material.Concrete, color = DARK }, folder)
		part({ size = Vector3.new(2, 9, 34), pos = C + Vector3.new(side * 22, 4.5, -46),
			material = Enum.Material.Concrete, color = DARK }, folder)
	end

	-- Deckung: Kisten in den Lanes + am Bombenplatz
	for _, c in ipairs({
		{ x = 0, z = 22, s = Vector3.new(8, 4, 4) },
		{ x = -6, z = -4, s = Vector3.new(5, 5, 5) },
		{ x = 8, z = 4, s = Vector3.new(5, 3.4, 5) },
		{ x = -36, z = 18, s = Vector3.new(6, 5, 6) },
		{ x = 36, z = 14, s = Vector3.new(6, 5, 6) },
		{ x = -34, z = -20, s = Vector3.new(5, 4, 5) },
		{ x = 34, z = -24, s = Vector3.new(5, 4, 5) },
		{ x = -10, z = -34, s = Vector3.new(6, 4, 5) },
		{ x = 10, z = -38, s = Vector3.new(6, 4, 5) },
	}) do
		part({ size = c.s, pos = C + Vector3.new(c.x, c.s.Y / 2, c.z),
			material = Enum.Material.Metal, color = COVER }, folder)
	end

	-- Bombenplatz A (markierte Zone)
	sitePart = part({ size = Vector3.new(26, 0.4, 26), pos = C + Vector3.new(0, 0.2, -30),
		material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 60),
		transparency = 0.55, name = "BombSite" }, folder)
	local siteBB = Instance.new("BillboardGui")
	siteBB.Size = UDim2.new(0, 120, 0, 40)
	siteBB.StudsOffset = Vector3.new(0, 8, 0)
	siteBB.MaxDistance = 200
	siteBB.Parent = sitePart
	local siteLbl = Instance.new("TextLabel")
	siteLbl.Size = UDim2.new(1, 0, 1, 0)
	siteLbl.BackgroundTransparency = 1
	siteLbl.Text = "💣 A"
	siteLbl.TextColor3 = Color3.fromRGB(255, 170, 60)
	siteLbl.TextStrokeTransparency = 0
	siteLbl.TextScaled = true
	siteLbl.Font = Enum.Font.GothamBold
	siteLbl.Parent = siteBB

	-- Team-Spawns markieren
	part({ size = Vector3.new(14, 0.4, 14), pos = C + Vector3.new(0, 0.2, 62),
		material = Enum.Material.Neon, color = T_COLOR, transparency = 0.5 }, folder)
	part({ size = Vector3.new(14, 0.4, 14), pos = C + Vector3.new(0, 0.2, -62),
		material = Enum.Material.Neon, color = CT_COLOR, transparency = 0.5 }, folder)

	-- Flutlichter
	for _, z in ipairs({ -55, 0, 55 }) do
		local lamp = part({ size = Vector3.new(2.4, 0.6, 2.4), pos = C + Vector3.new(0, 22, z),
			material = Enum.Material.Neon, color = Color3.fromRGB(230, 222, 255), collide = false }, folder)
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(220, 212, 255)
		pl.Range = 60
		pl.Brightness = 1.0
		pl.Parent = lamp
	end

	-- Zuschauer-Plattform (Tote schauen von oben zu)
	part({ size = Vector3.new(14, 1, 14), pos = C + Vector3.new(0, 80, 0),
		material = Enum.Material.Glass, color = Color3.fromRGB(120, 130, 170),
		transparency = 0.4, name = "SpectatorPerch" }, folder)

	return folder
end

-- ── Match-State ───────────────────────────────────────────────────────────────
local match = nil   -- nur EIN Defuse-Match gleichzeitig (eine Map)

local function teleport(player, cf)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
		root.CFrame = cf
	end
end

local function lobbyCFrame()
	local spawnLoc = workspace:FindFirstChild("LobbySpawn", true)
	return spawnLoc and (spawnLoc.CFrame + Vector3.new(0, 4, 0)) or CFrame.new(0, 6, -30)
end

local function sendState(state, extra)
	if not match or not match.player.Parent then return end
	local payload = {
		state    = state,
		mode     = "defuse",
		opponent = "Bot-Team",
		round    = match.round,
		yourTeam = match.playerTeam,
		score    = { you = match.score[match.playerTeam],
			enemy = match.score[match.playerTeam == "T" and "CT" or "T"] },
		tScore   = match.score.T,
		ctScore  = match.score.CT,
		bombPlanted = match.bombPlanted == true,
		timeLeft = math.max(0, math.ceil((match.deadline or 0) - os.clock())),
	}
	if extra then
		for k, v in pairs(extra) do payload[k] = v end
	end
	net.MatchState:FireClient(match.player, payload)
end

local function countAlive(team)
	if not match then return 0 end
	local n = 0
	for _, e in ipairs(match.entities) do
		if e.team == team then
			if e.bot then
				if e.bot.alive then n += 1 end
			elseif e.alive then
				n += 1
			end
		end
	end
	return n
end

-- ── Bombe ─────────────────────────────────────────────────────────────────────
local bombModel = nil

local function destroyBomb()
	if bombModel then
		bombModel:Destroy()
		bombModel = nil
	end
end

local function spawnBombModel(pos)
	destroyBomb()
	local b = Instance.new("Part")
	b.Name = "Bomb"
	b.Size = Vector3.new(1.6, 0.8, 1.1)
	b.Position = pos + Vector3.new(0, 0.5, 0)
	b.Color = Color3.fromRGB(45, 48, 56)
	b.Material = Enum.Material.Metal
	b.Anchored = true
	b.Parent = workspace

	local light = Instance.new("Part")
	light.Size = Vector3.new(0.3, 0.15, 0.3)
	light.Position = b.Position + Vector3.new(0.4, 0.5, 0)
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Material = Enum.Material.Neon
	light.Anchored = true
	light.CanCollide = false
	light.Parent = b

	-- Blinken + Piepen (beschleunigt gegen Ende)
	task.spawn(function()
		while b.Parent and match and match.bombPlanted do
			local left = math.max(0.5, (match.deadline or 0) - os.clock())
			local rate = math.clamp(left / Config.DEFUSE_BOMB_TIME, 0.12, 1)
			light.Transparency = 0
			Assets.playAt(b.Position, Assets.SFX.Bolt, 0.6, 1.7, 1.8)
			task.wait(0.12)
			light.Transparency = 0.8
			task.wait(math.max(0.15, rate * 0.9))
		end
	end)

	bombModel = b
	return b
end

local function explodeBomb()
	if not bombModel then return end
	local pos = bombModel.Position
	-- Explosion: Blitz + fetter Boom + Kill-Radius
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(6, 6, 6)
	flash.Position = pos
	flash.Color = Color3.fromRGB(255, 200, 90)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace
	game:GetService("TweenService"):Create(flash, TweenInfo.new(0.7),
		{ Size = Vector3.new(70, 70, 70), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.8)
	Assets.playAt(pos, Assets.SFX.GunBoom, 1, 0.55, 0.6)
	Assets.playAt(pos, Assets.SFX.Boom, 1, 0.8, 0.9)

	-- alles im Radius stirbt
	if match then
		for _, e in ipairs(match.entities) do
			if e.bot and e.bot.alive and e.bot.model.PrimaryPart
				and (e.bot.model.PrimaryPart.Position - pos).Magnitude < 45 then
				e.bot.kill()
			elseif e.player then
				local char = e.player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and (root.Position - pos).Magnitude < 45 then
					hum.Health = 0
				end
			end
		end
	end
	destroyBomb()
end

-- ── Runden-Logik ──────────────────────────────────────────────────────────────
local endRound   -- forward
local plantPrompt = nil

local function plantBomb(pos)
	if not match or match.ended or not match.live or match.bombPlanted then return end
	match.bombPlanted = true
	match.deadline = os.clock() + Config.DEFUSE_BOMB_TIME
	spawnBombModel(pos)
	net.Notify:FireClient(match.player, "💣 BOMBE GELEGT! " .. Config.DEFUSE_BOMB_TIME .. "s bis zur Explosion")
	net.PlaySFX:FireClient(match.player, "ChimeSoft", 0.8, 0.8)
	sendState("live")

	-- CT-Bots: nächster lebender Bot rückt zum Entschärfen aus
	task.spawn(function()
		while match and match.live and match.bombPlanted and not match.ended do
			local defender = nil
			local bombPos = bombModel and bombModel.Position
			if not bombPos then return end
			for _, e in ipairs(match.entities) do
				if e.team == "CT" and e.bot and e.bot.alive and not e.defusing then
					defender = e
					break
				end
			end
			if defender then
				defender.defusing = true
				defender.bot.setRoute({ bombPos }, function(bot)
					-- am Ziel: entschärfen (unterbrochen, wenn der Bot stirbt)
					task.delay(Config.DEFUSE_DEFUSE_TIME, function()
						if match and match.live and match.bombPlanted and bot.alive
							and bombModel and bot.model.PrimaryPart
							and (bot.model.PrimaryPart.Position - bombModel.Position).Magnitude < 12 then
							endRound("CT", "Bombe entschärft!")
						end
					end)
				end)
			end
			task.wait(2)
		end
	end)
end

local function setPrompts()
	-- Plant-Prompt (nur Spieler im T-Team)
	if plantPrompt then plantPrompt:Destroy() end
	plantPrompt = Instance.new("ProximityPrompt")
	plantPrompt.ActionText = "Bombe legen"
	plantPrompt.ObjectText = "Bombenplatz A"
	plantPrompt.HoldDuration = Config.DEFUSE_PLANT_TIME
	plantPrompt.MaxActivationDistance = 16
	plantPrompt.RequiresLineOfSight = false
	plantPrompt.Enabled = false
	plantPrompt.Parent = sitePart
	plantPrompt.Triggered:Connect(function(plr)
		if match and plr == match.player and match.playerTeam == "T"
			and match.live and not match.bombPlanted then
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			plantBomb(root and root.Position or sitePart.Position)
			plantPrompt.Enabled = false
		end
	end)
end

local function startRound()
	match.round += 1
	match.live = false
	match.bombPlanted = false
	match.deadline = os.clock() + Config.DEFUSE_ROUND_TIME + Config.COUNTDOWN
	destroyBomb()

	-- Seitenwechsel jede Runde: ungerade = Spieler greift an (T)
	match.playerTeam = (match.round % 2 == 1) and "T" or "CT"
	local botTeamT  = match.playerTeam == "T" and Config.DEFUSE_TEAM_SIZE - 1 or Config.DEFUSE_TEAM_SIZE
	local botTeamCT = match.playerTeam == "CT" and Config.DEFUSE_TEAM_SIZE - 1 or Config.DEFUSE_TEAM_SIZE

	-- alte Bots weg
	for _, e in ipairs(match.entities) do
		if e.bot then e.bot.destroy() end
	end
	match.entities = {}

	-- Spieler (tot aus der Vorrunde? → frisch respawnen)
	local pchar = match.player.Character
	local phum = pchar and pchar:FindFirstChildOfClass("Humanoid")
	if not pchar or not phum or phum.Health <= 0 then
		match.player:LoadCharacter()
		task.wait(0.6)
	end
	local pe = { player = match.player, team = match.playerTeam, alive = true }
	table.insert(match.entities, pe)
	teleport(match.player, match.playerTeam == "T" and tSpawnCF or ctSpawnCF)
	local root = match.player.Character and match.player.Character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end

	-- Ziel-Suche: nächster lebender Feind (Spieler oder Bot) des Teams.
	-- entity.bot wird direkt nach dem Spawn gesetzt — der Closure liest es lazy.
	local function acquireFor(myTeam, entity)
		return function()
			if not match or not match.live then return nil end
			local myBot = entity.bot
			local myPos = myBot and myBot.model.PrimaryPart and myBot.model.PrimaryPart.Position
			if not myPos then return nil end
			local best, bestDist = nil, math.huge
			for _, e in ipairs(match.entities) do
				if e.team ~= myTeam then
					local head, applyHit
					if e.bot then
						if e.bot.alive then
							head = e.bot.model:FindFirstChild("Head")
							local victim = e.bot
							applyHit = function() victim.kill() end
						end
					elseif e.alive then
						local char = e.player.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if char and hum and hum.Health > 0 then
							head = char:FindFirstChild("Head")
							applyHit = function()
								local h = e.player.Character and e.player.Character:FindFirstChildOfClass("Humanoid")
								if h and h.Health > 0 then h.Health = 0 end
							end
						end
					end
					if head then
						local d = (head.Position - myPos).Magnitude
						if d < bestDist then
							bestDist = d
							best = { head = head, applyHit = applyHit }
						end
					end
				end
			end
			return best
		end
	end

	-- Bots spawnen
	local function spawnTeamBots(team, count)
		for i = 1, count do
			local isT = team == "T"
			local route = isT and T_ROUTES[((i - 1) % #T_ROUTES) + 1] or CT_ROUTES[((i - 1) % #CT_ROUTES) + 1]
			local spawnBase = isT and tSpawnCF or ctSpawnCF
			local entity = { team = team }
			local bot = botService.spawn({
				spawnCF = spawnBase * CFrame.new((i - 2) * 5, 0, 0),
				name = (isT and "[T] " or "[CT] ") .. "Bot " .. i,
				visorColor = isT and T_COLOR or CT_COLOR,
				shouldAct = function()
					return match ~= nil and match.live and not match.ended
				end,
				acquire = acquireFor(team, entity),
				route = route,
				loiter = isT and { P(0, -28), P(-12, -30), P(12, -30) } or CT_HOLDS,
				onRouteDone = isT and function(bot)
					-- T-Bot am Platz: legen (wenn noch keiner gelegt hat)
					task.delay(Config.DEFUSE_PLANT_TIME, function()
						if match and match.live and not match.bombPlanted and bot.alive
							and bot.model.PrimaryPart then
							plantBomb(bot.model.PrimaryPart.Position)
						end
					end)
				end or nil,
			})
			entity.bot = bot
			table.insert(match.entities, entity)
		end
	end

	spawnTeamBots("T", botTeamT)
	spawnTeamBots("CT", botTeamCT)

	-- Countdown → live
	task.spawn(function()
		for n = Config.COUNTDOWN, 1, -1 do
			sendState("countdown", { countdown = n })
			task.wait(1)
			if not match or match.ended then return end
		end
		local r = match.player.Character and match.player.Character:FindFirstChild("HumanoidRootPart")
		if r then r.Anchored = false end
		match.live = true
		match.deadline = os.clock() + Config.DEFUSE_ROUND_TIME
		plantPrompt.Enabled = (match.playerTeam == "T")
		sendState("live")

		-- Runden-Loop
		while match and not match.ended and match.live do
			task.wait(1)
			if not match or match.ended or not match.live then break end
			if not match.player.Parent then
				DefuseService.stop()
				break
			end

			if countAlive("CT") == 0 then
				endRound("T", "Verteidiger ausgeschaltet!")
			elseif countAlive("T") == 0 and not match.bombPlanted then
				endRound("CT", "Angreifer ausgeschaltet!")
			elseif match.bombPlanted and os.clock() >= match.deadline then
				explodeBomb()
				endRound("T", "💥 Die Bombe ist explodiert!")
			elseif not match.bombPlanted and os.clock() >= match.deadline then
				endRound("CT", "Zeit abgelaufen — keine Bombe gelegt.")
			else
				sendState("live")
			end
		end
	end)
end

endRound = function(winnerTeam, reason)
	if not match or match.ended or not match.live then return end
	match.live = false
	match.bombPlanted = false
	destroyBomb()
	plantPrompt.Enabled = false
	match.score[winnerTeam] += 1

	local playerWonRound = winnerTeam == match.playerTeam
	if playerWonRound then
		dataService.addCredits(match.player, Config.DEFUSE_ROUND_REWARD)
	end
	net.Notify:FireClient(match.player,
		(playerWonRound and "✅ Runde gewonnen: " or "❌ Runde verloren: ") .. reason)
	net.PlaySFX:FireClient(match.player, playerWonRound and "Chime" or "ChimeSoft", 0.7)
	sendState("live", { roundOver = true })

	-- Match vorbei?
	if match.score[winnerTeam] >= Config.DEFUSE_ROUNDS_WIN then
		local playerWon = winnerTeam == match.playerTeam
		task.delay(2, function()
			if match then DefuseService.stop(playerWon) end
		end)
		return
	end

	task.delay(4, function()
		if match and not match.ended then
			startRound()
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────
function DefuseService.isInLiveMatch(player)
	return match ~= nil and not match.ended and match.player == player and match.live
end

function DefuseService.isInMatch(player)
	return match ~= nil and not match.ended and match.player == player
end

-- Spieler ist tot bis Rundenende → darf nicht schießen
function DefuseService.canShoot(player)
	if not DefuseService.isInLiveMatch(player) then return false end
	for _, e in ipairs(match.entities) do
		if e.player == player then return e.alive end
	end
	return false
end

-- Schuss des Spielers auf einen Defuse-Bot
function DefuseService.tryHitBot(shooter, botModel)
	if not match or match.ended or not match.live or shooter ~= match.player then return false end
	for _, e in ipairs(match.entities) do
		if e.bot and e.bot.model == botModel and e.bot.alive and e.team ~= match.playerTeam then
			e.bot.kill()
			dataService.addCredits(shooter, Config.KILL_REWARD)
			local pd = dataService.get(shooter)
			if pd then
				pd.kills += 1
				dataService.sendUpdate(shooter)
			end
			net.PlaySFX:FireClient(shooter, "ChimeSoft", 0.5, 1.6)
			return true
		end
	end
	return false
end

function DefuseService.start(player)
	if match and not match.ended then
		net.Notify:FireClient(player, "🚧 Defuse-Map ist gerade belegt — gleich nochmal!")
		return
	end
	local data = dataService.get(player)
	if not data then return end

	match = {
		player     = player,
		playerTeam = "T",
		entities   = {},
		score      = { T = 0, CT = 0 },
		round      = 0,
		live       = false,
		ended      = false,
	}
	net.PlaySFX:FireClient(player, "Teleport", 0.6)
	net.Notify:FireClient(player, "💣 BOMBEN-DEFUSAL: Erster auf " .. Config.DEFUSE_ROUNDS_WIN
		.. " Runden. Seitenwechsel jede Runde!")
	startRound()
end

function DefuseService.stop(playerWon)
	if not match then return end
	match.ended = true
	match.live = false
	destroyBomb()
	for _, e in ipairs(match.entities) do
		if e.bot then e.bot.destroy() end
	end
	local p = match.player
	if p.Parent then
		if playerWon ~= nil then
			dataService.addCredits(p, playerWon and Config.DEFUSE_WIN_REWARD or math.floor(Config.DEFUSE_WIN_REWARD / 3))
			net.Notify:FireClient(p, playerWon
				and ("🏆 DEFUSE GEWONNEN! +" .. Config.DEFUSE_WIN_REWARD .. " " .. Config.CURRENCY_NAME)
				or "💀 Defuse verloren — Revanche?")
			net.MatchState:FireClient(p, { state = "ended", mode = "defuse",
				winner = playerWon and p.Name or "Bot-Team", youWon = playerWon == true })
		else
			net.MatchState:FireClient(p, { state = "ended", mode = "defuse", winner = "—", youWon = false })
		end
		teleport(p, lobbyCFrame())
	end
	match = nil
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function DefuseService.init(ds, bs, netRef)
	dataService = ds
	botService  = bs
	net         = netRef

	local old = workspace:FindFirstChild("DefuseMap")
	if old then old:Destroy() end
	buildMap()
	setPrompts()

	-- Defuse-Prompt erscheint auf der Bombe, sobald sie liegt
	task.spawn(function()
		while true do
			task.wait(0.5)
			if match and match.live and match.bombPlanted and bombModel
				and match.playerTeam == "CT" and not bombModel:FindFirstChildOfClass("ProximityPrompt") then
				local dp = Instance.new("ProximityPrompt")
				dp.ActionText = "Entschärfen"
				dp.ObjectText = "Bombe"
				dp.HoldDuration = Config.DEFUSE_DEFUSE_TIME
				dp.MaxActivationDistance = 10
				dp.RequiresLineOfSight = false
				dp.Parent = bombModel
				dp.Triggered:Connect(function(plr)
					if match and plr == match.player and match.playerTeam == "CT"
						and match.live and match.bombPlanted then
						endRound("CT", "Bombe entschärft!")
						destroyBomb()
					end
				end)
			end
		end
	end)

	-- Spieler-Tod: tot bis Rundenende, Respawn auf der Zuschauer-Plattform
	local function hookPlayer(player)
		player.CharacterAdded:Connect(function(char)
			if match and match.player == player and not match.ended then
				task.wait(0.2)
				local entity = nil
				for _, e in ipairs(match.entities) do
					if e.player == player then entity = e end
				end
				if match.live and entity and not entity.alive then
					-- tot → zuschauen
					teleport(player, spectatorCF)
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then root.Anchored = true end
				else
					teleport(player, match.playerTeam == "T" and tSpawnCF or ctSpawnCF)
				end
			end

			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					if match and match.player == player and match.live then
						for _, e in ipairs(match.entities) do
							if e.player == player then e.alive = false end
						end
						sendState("live", { youDied = true })
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		if match and match.player == player then
			DefuseService.stop()
		end
	end)

	print("[DefuseService] Bomben-Defusal-Map bereit.")
end

return DefuseService
