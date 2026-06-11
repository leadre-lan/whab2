-- LobbyService.lua — Cyber-Lobby: Omega-Ei in der Mitte, Queue-Pad, Daily-Terminal
local LobbyService = {}

local RS                = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local arenaService = nil
local eggService   = nil
local net          = nil

local NEON   = Color3.fromRGB(150, 80, 255)
local CYAN   = Color3.fromRGB(70, 200, 255)
local DARK   = Color3.fromRGB(22, 24, 34)
local FLOOR  = Color3.fromRGB(32, 34, 48)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Size = props.size
	if props.cframe then p.CFrame = props.cframe else p.Position = props.pos end
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color
	p.Anchored = true
	p.CanCollide = props.collide ~= false
	if props.transparency then p.Transparency = props.transparency end
	if props.name then p.Name = props.name end
	p.Parent = parent
	return p
end

local function billboard(parent, offset, title, subtitle, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 220, 0, 70)
	bb.StudsOffset = offset
	bb.MaxDistance = 120
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

local function buildMegaEgg(folder)
	local egg = Config.EGGS.omega
	local center = Vector3.new(0, 0, 15)

	-- Podest
	part({ size = Vector3.new(18, 1.2, 18), pos = center + Vector3.new(0, 0.6, 0),
		material = Enum.Material.Slate, color = DARK }, folder)
	part({ size = Vector3.new(15, 0.4, 15), pos = center + Vector3.new(0, 1.4, 0),
		material = Enum.Material.Neon, color = egg.color, transparency = 0.35, collide = false }, folder)

	-- Das massive Omega-Ei (Sphere-Mesh vertikal gestreckt)
	local shell = part({ size = Vector3.new(10, 10, 10), pos = center + Vector3.new(0, 8.5, 0),
		material = Enum.Material.SmoothPlastic, color = egg.color, name = "OmegaEgg" }, folder)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.35, 1)
	mesh.Parent = shell
	shell.Reflectance = 0.08
	-- Client-Animation (Schweben/Drehen) via Tag — kostet den Server nichts
	CollectionService:AddTag(shell, "EggFloat")

	-- Leucht-Ringe um das Ei
	for i, y in ipairs({ 6.2, 8.5, 10.8 }) do
		local ring = part({
			size = Vector3.new(0.35, 11 - math.abs(i - 2) * 3, 11 - math.abs(i - 2) * 3),
			cframe = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Neon, color = CYAN, transparency = 0.25, collide = false,
		}, folder)
		-- Ringe NICHT taggen: die Float-Animation überschreibt die Orientierung,
		-- gekippte Zylinder würden dadurch aufrecht springen
		ring.Shape = Enum.PartType.Cylinder
	end

	-- Orbit-Partikel
	local att = Instance.new("Attachment")
	att.Parent = shell
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Assets.PARTICLES.Sparkles
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(1, 2.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35)
	pe.Color = ColorSequence.new(egg.color, CYAN)
	pe.LightEmission = 1
	pe.Parent = att

	local light = Instance.new("PointLight")
	light.Color = egg.color
	light.Range = 28
	light.Brightness = 1.4
	light.Parent = shell

	billboard(shell, Vector3.new(0, 9, 0),
		"🥚 " .. egg.name, "E: Öffnen — " .. egg.cost .. " " .. Config.CURRENCY_NAME, egg.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ei öffnen"
	prompt.ObjectText = egg.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player)
		net.OpenEgg:FireClient(player, "omega")
	end)
end

local function buildLobby(folder)
	-- Boden + Neon-Grid
	part({ size = Vector3.new(180, 2, 180), pos = Vector3.new(0, -1, 0),
		material = Enum.Material.Slate, color = FLOOR, name = "LobbyFloor" }, folder)
	for i = -3, 3 do
		part({ size = Vector3.new(0.5, 0.15, 180), pos = Vector3.new(i * 25, 0.05, 0),
			material = Enum.Material.Neon, color = NEON, transparency = 0.55, collide = false }, folder)
		part({ size = Vector3.new(180, 0.15, 0.5), pos = Vector3.new(0, 0.05, i * 25),
			material = Enum.Material.Neon, color = CYAN, transparency = 0.65, collide = false }, folder)
	end

	-- Begrenzung + Neon-Türme als Skyline
	for _, w in ipairs({
		{ Vector3.new(180, 18, 2), Vector3.new(0, 9, -90) },
		{ Vector3.new(180, 18, 2), Vector3.new(0, 9, 90) },
		{ Vector3.new(2, 18, 180), Vector3.new(-90, 9, 0) },
		{ Vector3.new(2, 18, 180), Vector3.new(90, 9, 0) },
	}) do
		part({ size = w[1], pos = w[2], material = Enum.Material.Concrete, color = DARK }, folder)
	end
	local towerRng = Random.new(7)
	for a = 0, 11 do
		local ang = a / 12 * math.pi * 2
		local d = 120 + towerRng:NextNumber(0, 60)
		local h = towerRng:NextNumber(40, 110)
		local tower = part({
			size = Vector3.new(towerRng:NextNumber(12, 24), h, towerRng:NextNumber(12, 24)),
			pos = Vector3.new(math.cos(ang) * d, h / 2 - 4, math.sin(ang) * d),
			material = Enum.Material.Concrete, color = DARK,
		}, folder)
		-- Leuchtkanten
		part({
			size = Vector3.new(tower.Size.X + 0.4, 0.6, tower.Size.Z + 0.4),
			pos = tower.Position + Vector3.new(0, h / 2 - 1, 0),
			material = Enum.Material.Neon,
			color = (a % 2 == 0) and NEON or CYAN,
			collide = false,
		}, folder)
	end

	-- Spawn
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "LobbySpawn"
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.Position = Vector3.new(0, 0.5, -55)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(45, 48, 66)
	spawnLoc.Parent = folder

	-- ── Queue-Pad (drauftreten = 1v1-Queue) ──
	local pad = part({ size = Vector3.new(10, 0.5, 10), pos = Vector3.new(55, 0.25, 0),
		material = Enum.Material.Neon, color = Color3.fromRGB(235, 65, 80), transparency = 0.25,
		name = "QueuePad" }, folder)
	billboard(pad, Vector3.new(0, 6, 0), "⚔ 1v1 SNIPER-ARENA", "Drauftreten: Queue (rein/raus)", Color3.fromRGB(255, 90, 100))

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
		arenaService.toggleQueue(player)
	end))

	-- ── Bot-Pad (Training gegen den Bot, reduzierte Rewards) ──
	local botPad = part({ size = Vector3.new(10, 0.5, 10), pos = Vector3.new(55, 0.25, -22),
		material = Enum.Material.Neon, color = CYAN, transparency = 0.25,
		name = "BotPad" }, folder)
	billboard(botPad, Vector3.new(0, 6, 0), "🤖 1v1 VS BOT", "Drauftreten: Training starten", CYAN)
	botPad.Touched:Connect(padTouch(function(player)
		arenaService.startBotMatch(player)
	end))

	-- ── Daily-Terminal ──
	local terminal = part({ size = Vector3.new(3, 6, 1.6), pos = Vector3.new(-55, 3, 0),
		material = Enum.Material.Metal, color = DARK }, folder)
	part({ size = Vector3.new(2.2, 3, 0.3), pos = Vector3.new(-55, 3.6, -0.75),
		material = Enum.Material.Neon, color = Color3.fromRGB(255, 200, 45), collide = false }, folder)
	billboard(terminal, Vector3.new(0, 4.5, 0), "🎁 DAILY", "E: +"
		.. Config.DAILY_REWARD .. " " .. Config.CURRENCY_NAME .. " täglich", Color3.fromRGB(255, 200, 45))

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

	buildMegaEgg(folder)
end

function LobbyService.init(arenaSvc, eggSvc, netRef)
	arenaService = arenaSvc
	eggService   = eggSvc
	net          = netRef

	local old = workspace:FindFirstChild("Lobby")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	buildLobby(folder)
	print("[LobbyService] Lobby gebaut.")
end

return LobbyService
