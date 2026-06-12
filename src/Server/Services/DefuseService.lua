-- DefuseService.lua — CS-Style Bomben-Defusal (3v3, Spieler + Bots).
--
-- Map: "Dorado" — sandige Wüstenstadt im Dust-2-Stil. Drei Lanes
-- (Long / Mid mit Doppeltür / Tunnels) führen zu ZWEI Bombenplätzen (A Ost,
-- B West). T-Bots wählen pro Runde ein Ziel-Site, CT-Bots verteilen sich auf
-- A / B / Mid. Kein Respawn in der Runde (CS-Regeln) — wer stirbt, schaut von
-- der Zuschauer-Plattform zu. Seitenwechsel jede Runde.
local DefuseService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Debris  = game:GetService("Debris")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local dataService   = nil
local botService    = nil
local weaponService = nil
local net           = nil

-- ── Map-Layout (eine Map, ein Match gleichzeitig) ─────────────────────────────
local C = Vector3.new(-1500, 0, 0)   -- Map-Zentrum
local T_COLOR  = Color3.fromRGB(255, 170, 60)
local CT_COLOR = Color3.fromRGB(80, 170, 255)

local sitePartA   = nil   -- Bombenplatz-Zonen (Prompt-Träger)
local sitePartB   = nil
local spectatorCF = CFrame.new(C + Vector3.new(0, 100, -10))
local tSpawnCF    = CFrame.new(C + Vector3.new(0, 4, 105))                                  -- blickt nach Norden
local ctSpawnCF   = CFrame.new(C + Vector3.new(0, 4, -118)) * CFrame.Angles(0, math.rad(180), 0)

-- Bot-Routen (Welt-Koordinaten). Wichtig: MoveTo hat KEIN Pathfinding —
-- jedes Segment muss eine freie Gerade innerhalb der Korridore sein.
local function P(x, z) return C + Vector3.new(x, 1, z) end

-- T-Angriffsrouten pro Ziel-Site (Long/Mid Richtung A, Tunnels/Mid Richtung B)
local T_SETS = {
	A = {
		{ P(80, 95), P(80, 42), P(80, 18), P(82, -49), P(80, -77) },                      -- Long A
		{ P(0, 95), P(0, 20), P(0, -8), P(0, -49), P(45, -49), P(62, -62), P(80, -77) },  -- Mid → A
		{ P(76, 95), P(76, 40), P(84, 16), P(78, -49), P(86, -72) },                      -- Long A (Variante)
	},
	B = {
		{ P(-77, 95), P(-77, 50), P(-77, 28), P(-80, -49), P(-80, -77) },                       -- Tunnels B
		{ P(0, 95), P(0, 20), P(0, -8), P(0, -49), P(-45, -49), P(-62, -62), P(-80, -77) },     -- Mid → B
		{ P(-73, 95), P(-73, 48), P(-81, 26), P(-76, -49), P(-86, -72) },                       -- Tunnels (Variante)
	},
}
-- T nach dem Plant: Site verteidigen
local T_DEFEND = {
	A = { P(62, -62), P(95, -88), P(60, -49) },
	B = { P(-62, -62), P(-95, -88), P(-60, -49) },
}

-- CT: Bot 1 hält A, Bot 2 hält B, Bot 3 spielt Mid (durch den CT-Tunnel)
local CT_ASSIGN = {
	{ route = { P(70, -118), P(70, -90) },
	  loiter = { P(62, -88), P(92, -68), P(70, -58) } },
	{ route = { P(-70, -118), P(-70, -90) },
	  loiter = { P(-62, -88), P(-92, -68), P(-70, -58) } },
	{ route = { P(0, -110), P(0, -80), P(0, -58), P(0, -49) },
	  loiter = { P(-20, -49), P(20, -49), P(0, -60) } },
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

-- Sandstein-Block mit Putz-Textur (Gebäude/Wände)
local function sandBlock(folder, size, pos, color)
	local p = part({ size = size, pos = pos, material = Enum.Material.Sandstone,
		color = color or Color3.fromRGB(205, 178, 128) }, folder)
	p:SetAttribute("EnvKind", "plaster")
	p:SetAttribute("EnvFaces", "Front,Back,Left,Right")
	p:SetAttribute("EnvStuds", 12)
	p:SetAttribute("EnvAlpha", 0.35)
	game:GetService("CollectionService"):AddTag(p, "EnvTexture")
	return p
end

-- Holzkiste (Deckung)
local function crate(folder, size, pos)
	return part({ size = size, pos = pos, material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(152, 112, 64) }, folder)
end

-- Bombenplatz-Zone: aufgemalte Bodenfläche + Schild
local function buildSite(folder, label, pos)
	local pad = part({ size = Vector3.new(30, 0.4, 30), pos = pos + Vector3.new(0, 0.2, 0),
		material = Enum.Material.Concrete, color = Color3.fromRGB(196, 120, 44),
		transparency = 0.25, name = "BombSite" .. label }, folder)
	local siteBB = Instance.new("BillboardGui")
	siteBB.Size = UDim2.new(0, 120, 0, 44)
	siteBB.StudsOffset = Vector3.new(0, 9, 0)
	siteBB.MaxDistance = 300
	siteBB.Parent = pad
	local siteLbl = Instance.new("TextLabel")
	siteLbl.Size = UDim2.new(1, 0, 1, 0)
	siteLbl.BackgroundTransparency = 1
	siteLbl.Text = "💣 " .. label
	siteLbl.TextColor3 = Color3.fromRGB(255, 170, 60)
	siteLbl.TextStrokeTransparency = 0
	siteLbl.TextScaled = true
	siteLbl.Font = Enum.Font.GothamBold
	siteLbl.Parent = siteBB
	return pad
end

-- Palme (Deko): Stamm-Zylinder + zwei Blätter-Kugeln
local function palm(folder, x, z)
	local trunk = part({ size = Vector3.new(13, 1.7, 1.7), pos = C + Vector3.new(x, 6.5, z),
		material = Enum.Material.Wood, color = Color3.fromRGB(124, 88, 52), collide = false }, folder)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = CFrame.new(C + Vector3.new(x, 6.5, z)) * CFrame.Angles(0, 0, math.rad(90))
	for i, off in ipairs({ Vector3.new(0, 13.5, 0), Vector3.new(1.6, 12.6, 1.2) }) do
		local leaf = part({ size = Vector3.new(7 - i, 2.6, 7 - i), pos = C + Vector3.new(x, 0, z) + off,
			material = Enum.Material.Grass, color = Color3.fromRGB(92, 142, 64), collide = false }, folder)
		leaf.Shape = Enum.PartType.Ball
	end
end

local function buildMap()
	local folder = Instance.new("Folder")
	folder.Name = "DefuseMap"
	folder.Parent = workspace

	local SAND      = Color3.fromRGB(214, 189, 142)   -- Boden
	local WALL      = Color3.fromRGB(199, 170, 120)   -- Außenmauern
	local BUILDING  = Color3.fromRGB(208, 182, 132)   -- Häuserblöcke
	local BUILDING2 = Color3.fromRGB(190, 160, 112)   -- dunklere Variante
	local TRIM      = Color3.fromRGB(140, 112, 76)    -- Bögen/Stürze

	-- Sandboden (Spielfeld) + weite Sandfläche außenrum (Horizont)
	local floorPart = part({ size = Vector3.new(246, 2, 276), pos = C + Vector3.new(0, -1, -5),
		material = Enum.Material.Sandstone, color = SAND }, folder)
	floorPart:SetAttribute("EnvKind", "sand")
	floorPart:SetAttribute("EnvFaces", "Top")
	floorPart:SetAttribute("EnvStuds", 24)
	floorPart:SetAttribute("EnvAlpha", 0.25)
	game:GetService("CollectionService"):AddTag(floorPart, "EnvTexture")
	part({ size = Vector3.new(900, 1, 900), pos = C + Vector3.new(0, -1.6, -5),
		material = Enum.Material.Sand, color = Color3.fromRGB(206, 180, 132) }, folder)

	-- Außenmauern (hoch genug, dass niemand rausschaut)
	for _, w in ipairs({
		{ Vector3.new(246, 20, 3), C + Vector3.new(0, 10, -133) },
		{ Vector3.new(246, 20, 3), C + Vector3.new(0, 10, 123) },
		{ Vector3.new(3, 20, 256), C + Vector3.new(-120, 10, -5) },
		{ Vector3.new(3, 20, 256), C + Vector3.new(120, 10, -5) },
	}) do
		sandBlock(folder, w[1], w[2], WALL)
	end

	-- Häuserblöcke: trennen die drei Lanes (Tunnels West / Mid / Long Ost)
	sandBlock(folder, Vector3.new(30, 16, 114), C + Vector3.new(-37, 8, 15), BUILDING)
	sandBlock(folder, Vector3.new(30, 16, 114), C + Vector3.new(37, 8, 15), BUILDING2)
	sandBlock(folder, Vector3.new(20, 14, 114), C + Vector3.new(-110, 7, 15), BUILDING2)
	sandBlock(folder, Vector3.new(20, 14, 114), C + Vector3.new(110, 7, 15), BUILDING)
	-- Nord-Zentrum (trennt A und B; Lücke x±7 = CT-Mid-Tunnel)
	sandBlock(folder, Vector3.new(35, 18, 46), C + Vector3.new(-24.5, 9, -79), BUILDING)
	sandBlock(folder, Vector3.new(35, 18, 46), C + Vector3.new(24.5, 9, -79), BUILDING2)
	-- Dach-Aufbauten = Skyline (reine Optik, unbegehbar)
	sandBlock(folder, Vector3.new(14, 6, 18), C + Vector3.new(-34, 19, -10), BUILDING2)
	sandBlock(folder, Vector3.new(12, 8, 14), C + Vector3.new(40, 20, 40), BUILDING)
	sandBlock(folder, Vector3.new(16, 5, 16), C + Vector3.new(20, 20.5, -82), BUILDING)

	-- Mid-Doppeltür (Lücke x ±4)
	sandBlock(folder, Vector3.new(18, 12, 3), C + Vector3.new(-13, 6, 8), BUILDING2)
	sandBlock(folder, Vector3.new(18, 12, 3), C + Vector3.new(13, 6, 8), BUILDING2)
	part({ size = Vector3.new(10, 3, 3), pos = C + Vector3.new(0, 10.5, 8),
		material = Enum.Material.Wood, color = TRIM }, folder)

	-- Long-Tor (Lücke x 72..88) mit Sturz
	sandBlock(folder, Vector3.new(20, 12, 3), C + Vector3.new(62, 6, 30), BUILDING)
	sandBlock(folder, Vector3.new(32, 12, 3), C + Vector3.new(104, 6, 30), BUILDING)
	part({ size = Vector3.new(18, 4, 3), pos = C + Vector3.new(80, 14, 30),
		material = Enum.Material.Wood, color = TRIM }, folder)

	-- Tunnel-Bogen West (Lücke x -86..-68)
	sandBlock(folder, Vector3.new(14, 12, 3), C + Vector3.new(-93, 6, 40), BUILDING2)
	sandBlock(folder, Vector3.new(16, 12, 3), C + Vector3.new(-60, 6, 40), BUILDING2)
	part({ size = Vector3.new(20, 4, 3), pos = C + Vector3.new(-77, 14, 40),
		material = Enum.Material.Wood, color = TRIM }, folder)

	-- Bombenplätze: A Ost, B West
	sitePartA = buildSite(folder, "A", C + Vector3.new(80, 0, -77))
	sitePartB = buildSite(folder, "B", C + Vector3.new(-80, 0, -77))

	-- Deckung: Kisten-Stacks an den Sites, Boxen in den Lanes
	crate(folder, Vector3.new(6, 5, 6),  C + Vector3.new(80, 2.5, -80))
	crate(folder, Vector3.new(4, 4, 4),  C + Vector3.new(80, 7, -79))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(64, 2, -90))
	crate(folder, Vector3.new(5, 5, 5),  C + Vector3.new(98, 2.5, -62))
	crate(folder, Vector3.new(6, 5, 6),  C + Vector3.new(-80, 2.5, -80))
	crate(folder, Vector3.new(4, 4, 4),  C + Vector3.new(-80, 7, -79))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(-64, 2, -90))
	crate(folder, Vector3.new(7, 4, 5),  C + Vector3.new(0, 2, -20))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(-12, 2, 46))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(76, 2, -8))
	crate(folder, Vector3.new(6, 5, 6),  C + Vector3.new(98, 2.5, 52))
	crate(folder, Vector3.new(6, 5, 6),  C + Vector3.new(-76, 2.5, 18))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(-92, 2, -12))
	crate(folder, Vector3.new(6, 5, 6),  C + Vector3.new(32, 2.5, 98))
	crate(folder, Vector3.new(5, 4, 5),  C + Vector3.new(-36, 2, 92))
	-- Fass am B-Platz
	local barrel = part({ size = Vector3.new(4, 3, 3), pos = C + Vector3.new(-98, 2, -62),
		material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(120, 80, 48) }, folder)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame = CFrame.new(C + Vector3.new(-98, 2, -62)) * CFrame.Angles(0, 0, math.rad(90))
	-- Niedrige Mauern im Connector
	sandBlock(folder, Vector3.new(10, 3, 3), C + Vector3.new(30, 1.5, -45), BUILDING2)
	sandBlock(folder, Vector3.new(10, 3, 3), C + Vector3.new(-30, 1.5, -45), BUILDING2)

	-- Team-Spawns markieren (dezent — Wüste, kein Neon)
	part({ size = Vector3.new(16, 0.4, 16), pos = C + Vector3.new(0, 0.2, 105),
		material = Enum.Material.Concrete, color = T_COLOR, transparency = 0.6 }, folder)
	part({ size = Vector3.new(16, 0.4, 16), pos = C + Vector3.new(0, 0.2, -118),
		material = Enum.Material.Concrete, color = CT_COLOR, transparency = 0.6 }, folder)

	-- Palmen in den Ecken (Wüsten-Vibe)
	palm(folder, -106, 114)
	palm(folder, 106, 114)
	palm(folder, -106, -126)
	palm(folder, 106, -126)

	-- Zuschauer-Plattform (Tote schauen von oben zu)
	part({ size = Vector3.new(14, 1, 14), pos = C + Vector3.new(0, 95, -10),
		material = Enum.Material.Glass, color = Color3.fromRGB(170, 160, 130),
		transparency = 0.4, name = "SpectatorPerch" }, folder)

	-- Eigene Store-Assets: Modelle aus ReplicatedStorage/Assets/MapProps werden
	-- automatisch an Deko-Punkten verteilt (Toolbox-Modell in Studio reinziehen,
	-- speichern, fertig — zur LAUFZEIT lässt Roblox fremde Assets nicht laden).
	local assets = RS:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("MapProps")
	if props then
		local spots = {
			Vector3.new(-48, 0, 100), Vector3.new(48, 0, 100),
			Vector3.new(-30, 0, -118), Vector3.new(30, 0, -118),
			Vector3.new(95, 0, -95), Vector3.new(-95, 0, -95),
			Vector3.new(95, 0, 80), Vector3.new(-95, 0, 80),
		}
		for i, prop in ipairs(props:GetChildren()) do
			local spot = C + spots[((i - 1) % #spots) + 1]
			local clone = prop:Clone()
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				elseif d:IsA("BaseScript") or d:IsA("ModuleScript") then
					d:Destroy()   -- Sicherheit: fremde Toolbox-Scripts NIE ausführen
				end
			end
			if clone:IsA("Model") then
				local _, size = clone:GetBoundingBox()
				clone:PivotTo(CFrame.new(spot + Vector3.new(0, size.Y / 2, 0)))
				clone.Parent = folder
			elseif clone:IsA("BasePart") then
				clone.Anchored = true
				clone.CFrame = CFrame.new(spot + Vector3.new(0, clone.Size.Y / 2, 0))
				clone.Parent = folder
			else
				clone:Destroy()
			end
		end
	end

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
				-- Anrückroute: über den Connector zur richtigen Site (MoveTo hat
				-- kein Pathfinding); steht der Bot schon am Platz → Direktweg
				local route
				local botPos = defender.bot.model.PrimaryPart and defender.bot.model.PrimaryPart.Position
				if botPos and (botPos - bombPos).Magnitude < 45 then
					route = { bombPos }
				elseif (bombPos - C).X > 0 then
					route = { P(45, -49), P(62, -62), bombPos }
				else
					route = { P(-45, -49), P(-62, -62), bombPos }
				end
				defender.bot.setRoute(route, function(bot)
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

-- Plant-Prompts auf BEIDEN Sites (nur Spieler im T-Team)
local plantPrompts = {}

local function setPlantPromptsEnabled(enabled)
	for _, prompt in ipairs(plantPrompts) do
		prompt.Enabled = enabled
	end
end

local function setPrompts()
	for _, prompt in ipairs(plantPrompts) do
		prompt:Destroy()
	end
	plantPrompts = {}
	for label, site in pairs({ A = sitePartA, B = sitePartB }) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Bombe legen"
		prompt.ObjectText = "Bombenplatz " .. label
		prompt.HoldDuration = Config.DEFUSE_PLANT_TIME
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = site
		prompt.Triggered:Connect(function(plr)
			if match and plr == match.player and match.playerTeam == "T"
				and match.live and not match.bombPlanted then
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				plantBomb(root and root.Position or site.Position)
				setPlantPromptsEnabled(false)
			end
		end)
		table.insert(plantPrompts, prompt)
	end
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
	if weaponService then weaponService.giveWeapon(match.player) end   -- Tool in die Hand
	local root = match.player.Character and match.player.Character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end

	-- Ziel-Site der Runde: T-Bots committen geschlossen auf A oder B
	match.targetSite = (math.random(2) == 1) and "A" or "B"
	local tRoutes = T_SETS[match.targetSite]
	local tDefend = T_DEFEND[match.targetSite]

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
			local assign = (not isT) and CT_ASSIGN[((i - 1) % #CT_ASSIGN) + 1] or nil
			local route = isT and tRoutes[((i - 1) % #tRoutes) + 1] or assign.route
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
				loiter = isT and tDefend or assign.loiter,
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
		setPlantPromptsEnabled(match.playerTeam == "T")
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
	setPlantPromptsEnabled(false)
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
	if p.Parent and weaponService then
		weaponService.giveWeapon(p)   -- zurück ins Rücken-Holster
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function DefuseService.init(ds, bs, ws, netRef)
	dataService   = ds
	botService    = bs
	weaponService = ws
	net           = netRef

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
