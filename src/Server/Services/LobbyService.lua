-- LobbyService.lua — Neon-Cyber-Mythos-Hauptlobby:
--   Mitte-Rechts: Omega-Gehäuse (Case-Opening, schwebendes Artefakt)
--   Links:        COMPETITIVE 5V5 Portal + Rangschild + RANGTABELLE
--   Rechts:       1v1 SNIPER-ARENA Terminal (AKTIVE DUELLE, Wager) + Pads
--   Hinten:       Prachtvolle Treppe → obere Ebene "HANDELSHALLE" (+ Live-Ticker)
--   Vorne-Links:  BESTENLISTE (Kills/Pulls/Rang)
local LobbyService = {}

local RS                = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local arenaService = nil
local eggService   = nil
local dataService  = nil
local net          = nil

local CYAN    = Color3.fromRGB(70, 200, 255)
local MAGENTA = Color3.fromRGB(255, 70, 200)
local PURPLE  = Color3.fromRGB(150, 80, 255)
local GOLD    = Color3.fromRGB(255, 200, 60)
local DARK    = Color3.fromRGB(34, 36, 52)
local STONE   = Color3.fromRGB(78, 76, 98)
local FLOOR   = Color3.fromRGB(30, 32, 48)

local tickerLabel = nil   -- Live-Ticker der Handelshalle

local function part(props, parent)
	local p = Instance.new("Part")
	p.Size = props.size
	if props.cframe then p.CFrame = props.cframe else p.Position = props.pos end
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color
	p.Anchored = true
	p.CanCollide = props.collide ~= false
	if props.transparency then p.Transparency = props.transparency end
	if props.reflectance then p.Reflectance = props.reflectance end
	if props.shape then p.Shape = props.shape end
	if props.name then p.Name = props.name end
	p.Parent = parent
	return p
end

local function billboard(parent, offset, title, subtitle, color, width)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, width or 240, 0, 70)
	bb.StudsOffset = offset
	bb.MaxDistance = 160
	bb.Parent = parent

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 0.55, 0)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = title
	tl.Parent = bb

	if subtitle then
		local sl = Instance.new("TextLabel")
		sl.Size = UDim2.new(1, 0, 0.45, 0)
		sl.Position = UDim2.new(0, 0, 0.55, 0)
		sl.BackgroundTransparency = 1
		sl.TextColor3 = Color3.fromRGB(215, 220, 235)
		sl.TextStrokeTransparency = 0
		sl.TextScaled = true
		sl.Font = Enum.Font.Gotham
		sl.Text = subtitle
		sl.Parent = bb
	end
end

-- SurfaceGui-Textpanel (Terminals, Boards)
local function surfacePanel(parent, face, lines)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = parent

	local labels = {}
	local n = #lines
	for i, line in ipairs(lines) do
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, -12, 1 / n, -4)
		tl.Position = UDim2.new(0, 6, (i - 1) / n, 2)
		tl.BackgroundTransparency = 1
		tl.Text = line.text
		tl.TextColor3 = line.color or Color3.fromRGB(225, 230, 245)
		tl.TextScaled = true
		tl.Font = line.font or Enum.Font.Gotham
		tl.TextXAlignment = line.align or Enum.TextXAlignment.Center
		tl.Parent = sg
		labels[i] = tl
	end
	return labels
end

-- "Antike Glyphen": Reihe kleiner Neon-Formen (Balken/Ringe/Punkte) auf Stein
local function glyphRow(parent, originCF, count, color, rng)
	for i = 0, count - 1 do
		local kind = rng:NextInteger(1, 3)
		local cf = originCF * CFrame.new(i * 1.4, 0, 0)
		if kind == 1 then
			part({ size = Vector3.new(0.18, rng:NextNumber(0.6, 1.1), 0.12), cframe = cf,
				material = Enum.Material.Neon, color = color, transparency = 0.25, collide = false }, parent)
		elseif kind == 2 then
			part({ size = Vector3.new(0.55, 0.55, 0.12), cframe = cf * CFrame.Angles(0, 0, math.rad(45)),
				material = Enum.Material.Neon, color = color, transparency = 0.35, collide = false }, parent)
		else
			part({ size = Vector3.new(0.3, 0.3, 0.12), cframe = cf, shape = Enum.PartType.Ball,
				material = Enum.Material.Neon, color = color, transparency = 0.2, collide = false }, parent)
		end
	end
end

-- Bogen aus Segmenten (vertikale Halbkreis-Architektur statt Kastenbalken —
-- runde Formen nehmen der Lobby den Klötzchen-Look)
local function buildArc(folder, cx, cy, cz, radius, fromDeg, toDeg, segments, thickness, depth, color, material)
	for i = 0, segments - 1 do
		local a0 = math.rad(fromDeg + (toDeg - fromDeg) * i / segments)
		local a1 = math.rad(fromDeg + (toDeg - fromDeg) * (i + 1) / segments)
		local mid = (a0 + a1) / 2
		local chord = 2 * radius * math.sin((a1 - a0) / 2) + 0.25
		part({
			size = Vector3.new(chord, thickness, depth),
			cframe = CFrame.new(cx + math.cos(mid) * radius, cy + math.sin(mid) * radius, cz)
				* CFrame.Angles(0, 0, mid + math.rad(90)),
			material = material or Enum.Material.Slate,
			color = color,
		}, folder)
	end
end

-- ── Omega-Gehäuse (Case-Opening-Terminal, Mitte-Rechts) ───────────────────────
local function buildOmegaCase(folder)
	local egg = Config.EGGS.omega
	local center = Vector3.new(18, 0, 8)

	-- Podest mit "Zahnrädern" (flache Zylinder)
	part({ size = Vector3.new(20, 1.4, 20), pos = center + Vector3.new(0, 0.7, 0),
		material = Enum.Material.Slate, color = STONE }, folder)
	for a = 0, 3 do
		local ang = a / 4 * math.pi * 2
		part({ size = Vector3.new(0.8, 3.2, 3.2),
			cframe = CFrame.new(center + Vector3.new(math.cos(ang) * 8, 1.5, math.sin(ang) * 8))
				* CFrame.Angles(0, 0, math.rad(90)),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Metal, color = Color3.fromRGB(90, 85, 105) }, folder)
	end
	part({ size = Vector3.new(16, 0.4, 16), pos = center + Vector3.new(0, 1.6, 0),
		material = Enum.Material.Neon, color = egg.color, transparency = 0.4, collide = false }, folder)

	-- Das schwebende Artefakt-Gehäuse (Würfel + Neon-Kanten, dreht/schwebt
	-- client-seitig). Heller Korpus + Eigenlicht, damit es nachts nicht im
	-- Schwarz verschwindet und nur die Kanten schweben.
	local case = part({ size = Vector3.new(7, 7, 7), pos = center + Vector3.new(0, 9, 0),
		material = Enum.Material.Slate, color = Color3.fromRGB(66, 58, 96), reflectance = 0.15, name = "OmegaCase" }, folder)
	local caseGlow = Instance.new("SurfaceLight")
	caseGlow.Face = Enum.NormalId.Bottom
	caseGlow.Color = egg.color
	caseGlow.Range = 16
	caseGlow.Brightness = 1.5
	caseGlow.Parent = case

	-- Glas-Hülle: weiche Reflexionen statt nackter Box
	local shell = part({ size = Vector3.new(10.5, 10.5, 10.5), pos = case.Position,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Glass, color = Color3.fromRGB(180, 160, 255),
		transparency = 0.82, reflectance = 0.12, collide = false }, folder)
	local shellWeld = Instance.new("WeldConstraint")
	shellWeld.Part0 = case
	shellWeld.Part1 = shell
	shellWeld.Parent = shell
	shell.Anchored = false
	CollectionService:AddTag(case, "EggFloat")
	for _, off in ipairs({
		Vector3.new(3.5, 0, 3.5), Vector3.new(-3.5, 0, 3.5),
		Vector3.new(3.5, 0, -3.5), Vector3.new(-3.5, 0, -3.5),
	}) do
		local edge = part({ size = Vector3.new(0.35, 7.4, 0.35), pos = case.Position + off,
			material = Enum.Material.Neon, color = egg.color, collide = false }, folder)
		local w = Instance.new("WeldConstraint")
		w.Part0 = case
		w.Part1 = edge
		w.Parent = edge
		edge.Anchored = false
	end
	for _, dy in ipairs({ 3.7, -3.7 }) do
		local frame = part({ size = Vector3.new(7.6, 0.35, 7.6), pos = case.Position + Vector3.new(0, dy, 0),
			material = Enum.Material.Neon, color = CYAN, transparency = 0.2, collide = false }, folder)
		local w = Instance.new("WeldConstraint")
		w.Part0 = case
		w.Part1 = frame
		w.Parent = frame
		frame.Anchored = false
	end

	-- Statische Leucht-Ringe (gekippt — bewusst NICHT getaggt, s. EggFloat-Handler)
	for i, tilt in ipairs({ 18, -14 }) do
		part({
			size = Vector3.new(0.3, 13 + i * 2, 13 + i * 2),
			cframe = CFrame.new(center + Vector3.new(0, 9, 0))
				* CFrame.Angles(math.rad(tilt), 0, math.rad(90 + tilt)),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon, color = (i == 1) and CYAN or MAGENTA,
			transparency = 0.45, collide = false,
		}, folder)
	end

	-- Holo-Projektion + Partikel + Licht
	local att = Instance.new("Attachment")
	att.Parent = case
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Assets.PARTICLES.Sparkles
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35)
	pe.Color = ColorSequence.new(egg.color, CYAN)
	pe.LightEmission = 1
	pe.Parent = att
	local light = Instance.new("PointLight")
	light.Color = egg.color
	light.Range = 30
	light.Brightness = 1.6
	light.Parent = case

	billboard(case, Vector3.new(0, 7.5, 0),
		"📦 " .. egg.name, "E: Öffnen — " .. egg.cost .. " " .. Config.CURRENCY_NAME, egg.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Gehäuse öffnen"
	prompt.ObjectText = egg.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.Parent = case
	prompt.Triggered:Connect(function(player)
		net.OpenEgg:FireClient(player, "omega")
	end)
end

-- ── COMPETITIVE 5V5 Portal + Rang (Links) ─────────────────────────────────────
local function buildPortal5v5(folder, rng)
	local cx, cz = -45, 25

	-- Runde Stein-Säulen mit Trims + Gravur-Textur statt Kasten-Pfeiler
	for side = -1, 1, 2 do
		local pillar = part({ size = Vector3.new(26, 5.4, 5.4),
			cframe = CFrame.new(cx + side * 11, 13, cz) * CFrame.Angles(0, 0, math.rad(90)),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Slate, color = STONE }, folder)
		pillar:SetAttribute("EnvKind", "stone")
		pillar:SetAttribute("EnvFaces", "Front,Back")
		pillar:SetAttribute("EnvStuds", 8)
		pillar:SetAttribute("EnvAlpha", 0.15)
		CollectionService:AddTag(pillar, "EnvTexture")
		for _, ty in ipairs({ 1.4, 24.8 }) do
			part({ size = Vector3.new(1.4, 6.6, 6.6),
				cframe = CFrame.new(cx + side * 11, ty, cz) * CFrame.Angles(0, 0, math.rad(90)),
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Metal, color = Color3.fromRGB(95, 92, 115) }, folder)
		end
		glyphRow(folder, CFrame.new(Vector3.new(cx + side * 11 - 0.7, 7, cz - 3)) * CFrame.Angles(0, 0, math.rad(90)),
			6, PURPLE, rng)
	end
	-- Verzierter Rundbogen über dem Portal
	buildArc(folder, cx, 24, cz, 11.5, 8, 172, 11, 3.4, 5.4, STONE)
	buildArc(folder, cx, 24, cz, 10, 15, 165, 11, 0.6, 1.4, PURPLE, Enum.Material.Neon)

	-- Wirbelndes Energieportal (zwei Ebenen + Partikel)
	local portal = part({ size = Vector3.new(17, 22, 0.6), pos = Vector3.new(cx, 12, cz),
		material = Enum.Material.Neon, color = PURPLE, transparency = 0.35, collide = false, name = "Portal5v5" }, folder)
	part({ size = Vector3.new(14, 18, 0.4), pos = Vector3.new(cx, 12, cz + 0.3),
		material = Enum.Material.Neon, color = CYAN, transparency = 0.6, collide = false }, folder)
	local patt = Instance.new("Attachment")
	patt.Parent = portal
	local pswirl = Instance.new("ParticleEmitter")
	pswirl.Texture = Assets.PARTICLES.Smoke
	pswirl.Rate = 14
	pswirl.Lifetime = NumberRange.new(1.4, 2.6)
	pswirl.Speed = NumberRange.new(2, 5)
	pswirl.SpreadAngle = Vector2.new(180, 180)
	pswirl.Size = NumberSequence.new(2.4)
	pswirl.Color = ColorSequence.new(PURPLE, CYAN)
	pswirl.LightEmission = 0.8
	pswirl.Parent = patt
	local plight = Instance.new("PointLight")
	plight.Color = PURPLE
	plight.Range = 34
	plight.Brightness = 1.8
	plight.Parent = portal

	billboard(portal, Vector3.new(0, 13.5, 0),
		"COMPETITIVE: 5V5 BOMBEN-DEFUSAL", "Matchmaking in Entwicklung — Rang steigt im 1v1!", PURPLE, 340)

	-- Anker für das client-seitige Rangschild ("DEIN RANG: …" sieht jeder nur für sich)
	local anchor = part({ size = Vector3.new(1, 1, 1), pos = Vector3.new(cx, 7.5, cz - 7),
		transparency = 1, collide = false, name = "RankShieldAnchor" }, folder)
	anchor.CanQuery = false

	-- Touch-Hinweis
	local touchCd = {}
	portal.Touched:Connect(function(hit)
		local player = hit and hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if os.clock() - (touchCd[player] or 0) < 4 then return end
		touchCd[player] = os.clock()
		net.Notify:FireClient(player, "🚧 5v5 Bomben-Defusal kommt bald — dein Rang steigt im 1v1!")
	end)

	-- RANGTABELLE-Terminal (rechts neben dem Portal)
	local board = part({ size = Vector3.new(0.8, 13, 9), pos = Vector3.new(cx + 19, 7.5, cz - 2),
		material = Enum.Material.Slate, color = DARK }, folder)
	local lines = { { text = "RANGTABELLE:", color = GOLD, font = Enum.Font.GothamBold } }
	for i = #Config.RANKS, 1, -1 do
		local r = Config.RANKS[i]
		table.insert(lines, { text = r.name .. "  (" .. r.min .. "+)", color = r.color })
	end
	surfacePanel(board, Enum.NormalId.Right, lines)
end

-- ── 1v1 SNIPER-ARENA Terminal + Pads (Rechts) ─────────────────────────────────
local duelCountLabel = nil

local function buildArenaTerminal(folder, rng)
	local cx, cz = 52, 22

	-- Glyphen-Steinwand mit stilisierten Scope-Symbolen
	local wall = part({ size = Vector3.new(2, 18, 30), pos = Vector3.new(cx + 10, 9, cz),
		material = Enum.Material.Slate, color = STONE }, folder)
	for i = 0, 2 do
		local ring = part({
			size = Vector3.new(0.3, 3.4, 3.4),
			cframe = CFrame.new(wall.Position + Vector3.new(-1.2, 3 + (i % 2) * 4, -9 + i * 9))
				* CFrame.Angles(0, 0, math.rad(90)),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon, color = Color3.fromRGB(235, 65, 80),
			transparency = 0.35, collide = false,
		}, folder)
		-- Fadenkreuz im Ring
		part({ size = Vector3.new(0.15, 4.2, 0.2), pos = ring.Position + Vector3.new(-0.1, 0, 0),
			material = Enum.Material.Neon, color = Color3.fromRGB(235, 65, 80), transparency = 0.45, collide = false }, folder)
		part({ size = Vector3.new(0.15, 0.2, 4.2), pos = ring.Position + Vector3.new(-0.1, 0, 0),
			material = Enum.Material.Neon, color = Color3.fromRGB(235, 65, 80), transparency = 0.45, collide = false }, folder)
	end
	glyphRow(folder, CFrame.new(wall.Position + Vector3.new(-1.2, -7, -10)) * CFrame.Angles(0, math.rad(90), 0),
		8, Color3.fromRGB(235, 65, 80), rng)

	-- Terminal mit Live-Anzeige
	local term = part({ size = Vector3.new(1, 8, 10), pos = Vector3.new(cx + 5, 4, cz),
		material = Enum.Material.Metal, color = DARK }, folder)
	billboard(term, Vector3.new(0, 6, 0), "1v1 SNIPER-ARENA", nil, Color3.fromRGB(255, 90, 100), 280)
	local labels = surfacePanel(term, Enum.NormalId.Left, {
		{ text = "1v1 SNIPER-ARENA", color = Color3.fromRGB(255, 90, 100), font = Enum.Font.GothamBold },
		{ text = "AKTIVE DUELLE: 0", color = CYAN },
		{ text = "NÄCHSTER WAGER: WÄHLEN.", color = GOLD },
		{ text = "Rotes Pad: PvP  ·  Blaues Pad: Bot", color = Color3.fromRGB(200, 205, 220) },
	})
	duelCountLabel = labels[2]

	-- ── Queue-Pad (rot): öffnet die Wager-Wahl / verlässt die Queue ──
	local pad = part({ size = Vector3.new(11, 0.5, 11), pos = Vector3.new(cx - 8, 0.25, cz + 6),
		material = Enum.Material.Neon, color = Color3.fromRGB(235, 65, 80), transparency = 0.2,
		name = "QueuePad" }, folder)
	part({ size = Vector3.new(12, 0.2, 12), pos = pad.Position + Vector3.new(0, 0.2, 0),
		material = Enum.Material.Neon, color = Color3.fromRGB(255, 130, 140), transparency = 0.7, collide = false }, folder)
	billboard(pad, Vector3.new(0, 5.5, 0), "⚔ 1v1 PVP", "Drauftreten: Wager wählen", Color3.fromRGB(255, 90, 100))

	local padCooldown = {}
	local function padTouch(callback)
		return function(hit)
			local char = hit and hit.Parent
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then return end
			local last = padCooldown[player] or 0
			if os.clock() - last < 1.5 then return end
			padCooldown[player] = os.clock()
			callback(player)
		end
	end
	pad.Touched:Connect(padTouch(function(player)
		if arenaService.isQueued(player) then
			arenaService.toggleQueue(player)   -- verlassen
		else
			net.OpenWager:FireClient(player)   -- Einsatz wählen → Client sendet QueueJoin
		end
	end))

	-- ── Bot-Pad (blau): Training ──
	local botPad = part({ size = Vector3.new(11, 0.5, 11), pos = Vector3.new(cx - 8, 0.25, cz - 10),
		material = Enum.Material.Neon, color = CYAN, transparency = 0.25,
		name = "BotPad" }, folder)
	billboard(botPad, Vector3.new(0, 5.5, 0), "🤖 1v1 VS BOT", "Drauftreten: Training starten", CYAN)
	botPad.Touched:Connect(padTouch(function(player)
		arenaService.startBotMatch(player)
	end))
end

-- ── Handelshalle (obere Ebene, hinten) + Treppe + Live-Ticker ─────────────────
local function buildHandelshalle(folder, rng)
	local cz = 78
	local Y = 12

	-- Prachtvolle Treppe (Mitte)
	local steps = 10
	for i = 1, steps do
		part({ size = Vector3.new(18, 1.2, 3.4),
			pos = Vector3.new(0, i * (Y / steps) - 0.6, 52 + i * 3),
			material = Enum.Material.Slate, color = STONE }, folder)
		if i % 2 == 0 then
			part({ size = Vector3.new(18.4, 0.15, 0.5),
				pos = Vector3.new(0, i * (Y / steps), 52 + i * 3 + 1.6),
				material = Enum.Material.Neon, color = (i % 4 == 0) and CYAN or MAGENTA,
				transparency = 0.35, collide = false }, folder)
		end
	end

	-- Plattform + Geländer
	local platform = part({ size = Vector3.new(90, 2, 40), pos = Vector3.new(0, Y - 1, cz + 8),
		material = Enum.Material.SmoothPlastic, color = FLOOR, reflectance = 0.18 }, folder)
	platform:SetAttribute("EnvKind", "panels")
	platform:SetAttribute("EnvFaces", "Top")
	platform:SetAttribute("EnvStuds", 16)
	platform:SetAttribute("EnvAlpha", 0.15)
	CollectionService:AddTag(platform, "EnvTexture")
	for _, side in ipairs({ -1, 1 }) do
		part({ size = Vector3.new(0.6, 3, 40), pos = Vector3.new(side * 45, Y + 1.5, cz + 8),
			material = Enum.Material.Slate, color = STONE }, folder)
	end
	part({ size = Vector3.new(34, 3, 0.6), pos = Vector3.new(-27, Y + 1.5, cz - 12),
		material = Enum.Material.Slate, color = STONE }, folder)
	part({ size = Vector3.new(34, 3, 0.6), pos = Vector3.new(27, Y + 1.5, cz - 12),
		material = Enum.Material.Slate, color = STONE }, folder)
	part({ size = Vector3.new(90, 0.25, 0.7), pos = Vector3.new(0, Y + 3.1, cz + 8 - 20),
		material = Enum.Material.Neon, color = GOLD, transparency = 0.4, collide = false }, folder)

	-- Schild
	local sign = part({ size = Vector3.new(1, 1, 1), pos = Vector3.new(0, Y + 10, cz + 4),
		transparency = 1, collide = false }, folder)
	billboard(sign, Vector3.new(0, 0, 0), "⇆ HANDELSPLATZ", "Kiosk: E zum Handeln  ·  >3 Items: Trader-Pass", GOLD, 300)

	-- Handelskioske (Stein + glühendes Metall + Holo-Panel)
	for k = -1, 1 do
		local kx = k * 26
		part({ size = Vector3.new(8, 3.4, 3), pos = Vector3.new(kx, Y + 1.7, cz + 14),
			material = Enum.Material.Slate, color = STONE }, folder)
		part({ size = Vector3.new(8.4, 0.3, 3.4), pos = Vector3.new(kx, Y + 3.5, cz + 14),
			material = Enum.Material.Neon, color = GOLD, transparency = 0.3, collide = false }, folder)
		local holo = part({ size = Vector3.new(6, 3, 0.25), pos = Vector3.new(kx, Y + 6, cz + 14),
			material = Enum.Material.Neon, color = CYAN, transparency = 0.55, collide = false }, folder)
		surfacePanel(holo, Enum.NormalId.Front, {
			{ text = "HANDELSPLATZ", color = Color3.fromRGB(240, 245, 255), font = Enum.Font.GothamBold },
			{ text = "E: Trade starten", color = Color3.fromRGB(215, 225, 240) },
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Handeln"
		prompt.ObjectText = "Handelskiosk"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = holo
		prompt.Triggered:Connect(function(player)
			net.OpenTrade:FireClient(player)
		end)
	end

	-- Live-Ticker (massives integriertes Terminal an der Rückwand)
	local tickerBoard = part({ size = Vector3.new(34, 5, 0.8), pos = Vector3.new(0, Y + 9, cz + 26),
		material = Enum.Material.Slate, color = DARK }, folder)
	local labels = surfacePanel(tickerBoard, Enum.NormalId.Front, {
		{ text = "● LIVE-TICKER", color = MAGENTA, font = Enum.Font.GothamBold },
		{ text = "ZULETZT GEHANDELT: —", color = Color3.fromRGB(225, 230, 245) },
	})
	tickerLabel = labels[2]
	glyphRow(folder, CFrame.new(Vector3.new(-15, Y + 5.6, cz + 25.4)), 22, PURPLE, rng)
end

-- ── Bestenliste (Vorne-Links) ─────────────────────────────────────────────────
local lbLabels = nil

local function buildLeaderboard(folder)
	local board = part({ size = Vector3.new(0.8, 14, 18), pos = Vector3.new(-60, 8, -28),
		material = Enum.Material.Slate, color = DARK }, folder)
	part({ size = Vector3.new(1, 14.6, 18.6), pos = board.Position + Vector3.new(0.2, 0, 0),
		material = Enum.Material.Neon, color = CYAN, transparency = 0.75, collide = false }, folder)

	local lines = { { text = "BESTENLISTE (KILLS/PULLS/RANG)", color = GOLD, font = Enum.Font.GothamBold } }
	for _ = 1, 8 do
		table.insert(lines, { text = "—", color = Color3.fromRGB(210, 216, 232), align = Enum.TextXAlignment.Left })
	end
	lbLabels = surfacePanel(board, Enum.NormalId.Right, lines)
end

local function refreshLeaderboard()
	if not lbLabels then return end
	local rows = {}
	for player, data in dataService.eachPlayer() do
		table.insert(rows, {
			name = player.Name,
			kills = data.kills or 0,
			pulls = data.hatches or 0,
			rank = Config.rankFor(data.rating or Config.ELO_START),
		})
	end
	table.sort(rows, function(a, b) return a.kills > b.kills end)
	for i = 1, 8 do
		local lbl = lbLabels[i + 1]
		local r = rows[i]
		if r then
			lbl.Text = ("%d. %s  ·  %d Kills  ·  %d Pulls  ·  %s")
				:format(i, r.name, r.kills, r.pulls, r.rank.name)
			lbl.TextColor3 = r.rank.color
		else
			lbl.Text = "—"
			lbl.TextColor3 = Color3.fromRGB(120, 126, 145)
		end
	end
end

-- ── Grundfläche, Bögen, Skyline ───────────────────────────────────────────────
local function buildLobbyBase(folder, rng)
	-- Polierter Glanzboden + kachelnde Tech-Panel-Textur (client-seitig via
	-- EditableImage — echte Oberfläche statt flacher Farbe)
	local floorPart = part({ size = Vector3.new(200, 2, 200), pos = Vector3.new(0, -1, 10),
		material = Enum.Material.SmoothPlastic, color = FLOOR, reflectance = 0.22, name = "LobbyFloor" }, folder)
	floorPart:SetAttribute("EnvKind", "panels")
	floorPart:SetAttribute("EnvFaces", "Top")
	floorPart:SetAttribute("EnvStuds", 22)
	floorPart:SetAttribute("EnvAlpha", 0.15)
	CollectionService:AddTag(floorPart, "EnvTexture")

	-- Dezentere Neon-Gridlinien (das Panel-Muster trägt jetzt den Boden)
	for i = -4, 4 do
		part({ size = Vector3.new(0.35, 0.1, 200), pos = Vector3.new(i * 22, 0.05, 10),
			material = Enum.Material.Neon, color = CYAN, transparency = 0.62, collide = false }, folder)
		part({ size = Vector3.new(200, 0.1, 0.35), pos = Vector3.new(0, 0.05, 10 + i * 22),
			material = Enum.Material.Neon, color = MAGENTA, transparency = 0.72, collide = false }, folder)
	end

	-- Begrenzungswände mit Stein-Gravur-Textur + Cove-Licht am Fuß
	for _, w in ipairs({
		{ Vector3.new(200, 20, 2), Vector3.new(0, 10, -90), "Back" },
		{ Vector3.new(200, 20, 2), Vector3.new(0, 10, 110), "Front" },
		{ Vector3.new(2, 20, 200), Vector3.new(-100, 10, 10), "Right" },
		{ Vector3.new(2, 20, 200), Vector3.new(100, 10, 10), "Left" },
	}) do
		local wall = part({ size = w[1], pos = w[2], material = Enum.Material.Concrete, color = DARK }, folder)
		wall:SetAttribute("EnvKind", "stone")
		wall:SetAttribute("EnvFaces", w[3])
		wall:SetAttribute("EnvStuds", 14)
		wall:SetAttribute("EnvAlpha", 0.1)
		CollectionService:AddTag(wall, "EnvTexture")

		-- Cove-Light: Neon-Leiste am Wandfuß + Licht-Wash nach oben
		local inward = (Vector3.new(0, 0, 10) - w[2]) * Vector3.new(1, 0, 1)
		inward = inward.Magnitude > 0 and inward.Unit or Vector3.zAxis
		local along = math.abs(inward.X) > 0.5 and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local strip = part({
			size = along * 192 + Vector3.new(0.45, 0.45, 0.45),
			pos = w[2] * Vector3.new(1, 0, 1) + inward * 1.6 + Vector3.new(0, 0.4, 0),
			material = Enum.Material.Neon, color = PURPLE, transparency = 0.35, collide = false,
		}, folder)
		local wash = Instance.new("SurfaceLight")
		wash.Face = Enum.NormalId.Top
		wash.Color = PURPLE
		wash.Range = 18
		wash.Brightness = 0.6
		wash.Parent = strip
	end

	-- Rund-Bögen über dem Hauptgang: Zylinder-Säulen + Halbkreis-Segmente
	for _, az in ipairs({ -30, 40 }) do
		local accentColor = (az < 0) and CYAN or MAGENTA
		for side = -1, 1, 2 do
			part({ size = Vector3.new(16, 2.6, 2.6),
				cframe = CFrame.new(side * 14, 8, az) * CFrame.Angles(0, 0, math.rad(90)),
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Slate, color = STONE }, folder)
			-- Säulen-Trims (Fuß + Kapitell)
			for _, ty in ipairs({ 1, 15.4 }) do
				part({ size = Vector3.new(1, 3.6, 3.6),
					cframe = CFrame.new(side * 14, ty, az) * CFrame.Angles(0, 0, math.rad(90)),
					shape = Enum.PartType.Cylinder,
					material = Enum.Material.Metal, color = Color3.fromRGB(95, 92, 115) }, folder)
			end
		end
		buildArc(folder, 0, 16, az, 14, 12, 168, 9, 2.2, 2.4, STONE)
		buildArc(folder, 0, 16, az, 12.4, 20, 160, 9, 0.5, 1.2, accentColor, Enum.Material.Neon)
		glyphRow(folder, CFrame.new(Vector3.new(-10, 13.5, az - 1.4)), 15, accentColor, rng)
		local beam = part({ size = Vector3.new(1, 1, 1), pos = Vector3.new(0, 16, az),
			transparency = 1, collide = false }, folder)
		local att = Instance.new("Attachment")
		att.Parent = beam
		local stream = Instance.new("ParticleEmitter")
		stream.Texture = Assets.PARTICLES.Sparkles
		stream.Rate = 5
		stream.Lifetime = NumberRange.new(2, 3.5)
		stream.Speed = NumberRange.new(3, 5)
		stream.SpreadAngle = Vector2.new(8, 8)
		stream.Size = NumberSequence.new(0.2)
		stream.Color = ColorSequence.new(CYAN, MAGENTA)
		stream.LightEmission = 1
		stream.Parent = att
	end

	-- Neon-Skyline (Fenster-Streifen, damit die Türme nachts lesbar sind)
	for a = 0, 13 do
		local ang = a / 14 * math.pi * 2
		local d = 135 + rng:NextNumber(0, 60)
		local h = rng:NextNumber(45, 120)
		local accentColor = ({ CYAN, MAGENTA, PURPLE })[(a % 3) + 1]
		local tower = part({
			size = Vector3.new(rng:NextNumber(12, 26), h, rng:NextNumber(12, 26)),
			pos = Vector3.new(math.cos(ang) * d, h / 2 - 4, 10 + math.sin(ang) * d),
			material = Enum.Material.Concrete, color = DARK,
		}, folder)
		part({
			size = Vector3.new(tower.Size.X + 0.4, 0.7, tower.Size.Z + 0.4),
			pos = tower.Position + Vector3.new(0, h / 2 - 1, 0),
			material = Enum.Material.Neon, color = accentColor,
			collide = false,
		}, folder)
		-- Vertikale Fenster-Lichtbänder zur Lobby hin
		local toCenter = (Vector3.new(0, 0, 10) - tower.Position) * Vector3.new(1, 0, 1)
		local facing = toCenter.Unit
		for w = -1, 1 do
			if rng:NextNumber() < 0.7 then
				part({
					size = Vector3.new(0.9, h * rng:NextNumber(0.45, 0.8), 0.4),
					cframe = CFrame.lookAt(
						tower.Position + facing * (math.max(tower.Size.X, tower.Size.Z) / 2 + 0.3)
							+ Vector3.new(0, rng:NextNumber(-h * 0.1, h * 0.1), 0)
							+ facing:Cross(Vector3.yAxis) * (w * tower.Size.X * 0.28),
						tower.Position),
					material = Enum.Material.Neon,
					color = accentColor,
					transparency = 0.35,
					collide = false,
				}, folder)
			end
		end
	end

	-- Licht-Pylonen entlang des Hauptgangs (beleuchten Spieler + Waffen —
	-- ohne echte Lichtquellen bleibt nachts alles flach-schwarz)
	for _, pos in ipairs({
		Vector3.new(-30, 0, -50), Vector3.new(30, 0, -50),
		Vector3.new(-30, 0, 5),   Vector3.new(30, 0, 5),
		Vector3.new(-30, 0, 55),  Vector3.new(30, 0, 55),
	}) do
		part({ size = Vector3.new(1.2, 9, 1.2), pos = pos + Vector3.new(0, 4.5, 0),
			material = Enum.Material.Metal, color = STONE }, folder)
		local lamp = part({ size = Vector3.new(1.6, 0.8, 1.6), pos = pos + Vector3.new(0, 9.4, 0),
			material = Enum.Material.Neon, color = Color3.fromRGB(225, 215, 255), collide = false }, folder)
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(215, 205, 255)
		pl.Range = 42
		pl.Brightness = 1.1
		pl.Parent = lamp
	end

	-- Spawn (Süden, Blick in den Hauptgang)
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "LobbySpawn"
	spawnLoc.Size = Vector3.new(14, 1, 14)
	spawnLoc.Position = Vector3.new(0, 0.5, -65)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(40, 43, 60)
	spawnLoc.Parent = folder

	-- Daily-Terminal (nahe Spawn)
	local terminal = part({ size = Vector3.new(3, 6, 1.6), pos = Vector3.new(-18, 3, -55),
		material = Enum.Material.Metal, color = DARK }, folder)
	part({ size = Vector3.new(2.2, 3, 0.3), pos = Vector3.new(-18, 3.6, -55.8),
		material = Enum.Material.Neon, color = GOLD, collide = false }, folder)
	billboard(terminal, Vector3.new(0, 4.5, 0), "🎁 DAILY", "E: +"
		.. Config.DAILY_REWARD .. " " .. Config.CURRENCY_NAME .. " täglich", GOLD)
	local dailyPrompt = Instance.new("ProximityPrompt")
	dailyPrompt.ActionText = "Abholen"
	dailyPrompt.ObjectText = "Daily-Reward"
	dailyPrompt.HoldDuration = 0
	dailyPrompt.MaxActivationDistance = 12
	dailyPrompt.RequiresLineOfSight = false
	dailyPrompt.Parent = terminal
	dailyPrompt.Triggered:Connect(function(player)
		eggService.claimDaily(player)
	end)
end

-- ── Public ────────────────────────────────────────────────────────────────────

-- Live-Ticker der Handelshalle aktualisieren (TradeService.onTicker)
function LobbyService.pushTicker(text)
	if tickerLabel then
		tickerLabel.Text = text
	end
end

function LobbyService.init(arenaSvc, eggSvc, ds, netRef)
	arenaService = arenaSvc
	eggService   = eggSvc
	dataService  = ds
	net          = netRef

	local old = workspace:FindFirstChild("Lobby")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	local rng = Random.new(42)
	buildLobbyBase(folder, rng)
	buildOmegaCase(folder)
	buildPortal5v5(folder, rng)
	buildArenaTerminal(folder, rng)
	buildHandelshalle(folder, rng)
	buildLeaderboard(folder)

	-- Live-Anzeigen: AKTIVE DUELLE + Bestenliste
	task.spawn(function()
		while folder.Parent do
			if duelCountLabel then
				duelCountLabel.Text = "AKTIVE DUELLE: " .. arenaService.getActiveDuelCount()
			end
			refreshLeaderboard()
			task.wait(5)
		end
	end)

	print("[LobbyService] Neon-Cyber-Mythos-Lobby gebaut.")
end

return LobbyService
