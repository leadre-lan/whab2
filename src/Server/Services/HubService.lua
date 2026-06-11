-- HubService.lua — Overworld hub: spawn plaza, forest portal, layer teleports,
-- placeholder buildings for forge/arena/shrine (full features come in later phases)
local HubService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layers = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))

-- Hub is far west of the forest layers (layers start at x=0)
local HUB_X = -320
local HUB_Z = 0

local dataService = nil
local net         = nil

-- ── Builders ──────────────────────────────────────────────────────────────────

local function part(props, parent)
	local p = Instance.new(props.shape == "Wedge" and "WedgePart" or "Part")
	if props.shape and props.shape ~= "Wedge" then p.Shape = props.shape end
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

local function makeSign(parent, pos, title, subtitle, titleColor)
	local post = part({
		size = Vector3.new(0.4, 5.5, 0.4), pos = pos,
		material = Enum.Material.Wood, color = Color3.fromRGB(98, 68, 38),
		collide = false,
	}, parent)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 56)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 70    -- tags from other areas must never bleed through
	bb.Parent = post

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 0.55, 0)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = titleColor or Color3.fromRGB(255, 255, 255)
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
		sl.TextColor3 = Color3.fromRGB(210, 215, 230)
		sl.TextStrokeTransparency = 0
		sl.TextScaled = true
		sl.Font = Enum.Font.Gotham
		sl.Text = subtitle
		sl.Parent = bb
	end
	return post
end

local function buildHub(hubFolder)
	local rng = Random.new(7)

	-- Plaza: large round-ish stone platform
	part({
		name = "PlazaFloor",
		size = Vector3.new(150, 2, 150),
		pos = Vector3.new(HUB_X, 0, HUB_Z),
		material = Enum.Material.Cobblestone,
		color = Color3.fromRGB(132, 128, 120),
	}, hubFolder)

	-- Inner decorative circle
	local circle = part({
		name = "PlazaCenter",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, 40, 40),
		cframe = CFrame.new(HUB_X, 1.15, HUB_Z) * CFrame.Angles(0, 0, math.rad(90)),
		material = Enum.Material.Marble,
		color = Color3.fromRGB(190, 186, 178),
		collide = false,
	}, hubFolder)

	-- ── Fountain (center) ──
	part({
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.6, 14, 14),
		cframe = CFrame.new(HUB_X, 1.8, HUB_Z) * CFrame.Angles(0, 0, math.rad(90)),
		material = Enum.Material.Slate,
		color = Color3.fromRGB(110, 108, 102),
	}, hubFolder)
	part({
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, 11, 11),
		cframe = CFrame.new(HUB_X, 2.4, HUB_Z) * CFrame.Angles(0, 0, math.rad(90)),
		material = Enum.Material.Glass,
		color = Color3.fromRGB(85, 170, 220),
		transparency = 0.35, collide = false,
	}, hubFolder)
	local pillar = part({
		size = Vector3.new(1.4, 7, 1.4),
		pos = Vector3.new(HUB_X, 5, HUB_Z),
		material = Enum.Material.Marble,
		color = Color3.fromRGB(205, 200, 192),
	}, hubFolder)
	-- "Statue" placeholder (Ranked #1 statue comes with RankedService)
	part({
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.6, 2.6, 2.6),
		pos = Vector3.new(HUB_X, 9.6, HUB_Z),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(255, 215, 80),
		collide = false,
	}, hubFolder)
	makeSign(hubFolder, Vector3.new(HUB_X, 3.75, HUB_Z - 12),
		"🏯 Bamboo Slasher", "Willkommen in der Overworld!",
		Color3.fromRGB(120, 230, 120))

	-- ── Wald-Portal (north, +Z) — leads to the forest layers ──
	local portalZ = HUB_Z + 60
	-- Bamboo gate: two thick green pillars + crossbar
	for side = -1, 1, 2 do
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(16, 2.6, 2.6),
			cframe = CFrame.new(HUB_X + side * 7, 9, portalZ) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.SmoothPlastic,
			color = Color3.fromRGB(72, 185, 62),
		}, hubFolder)
	end
	part({
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(18, 2.2, 2.2),
		cframe = CFrame.new(HUB_X, 16.5, portalZ) * CFrame.Angles(0, math.rad(90), math.rad(90)),
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(58, 150, 50),
	}, hubFolder)
	-- Glowing portal plane (color updated per player would need local parts;
	-- use layer-1 green as the shared base)
	local portalGlow = part({
		name = "PortalGlow",
		size = Vector3.new(12, 14, 0.5),
		pos = Vector3.new(HUB_X, 8, portalZ),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(95, 230, 110),
		transparency = 0.35, collide = false,
	}, hubFolder)
	-- Slow pulse
	task.spawn(function()
		while portalGlow.Parent do
			TweenService:Create(portalGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = 0.6 }):Play()
			task.wait(1.6)
			TweenService:Create(portalGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = 0.3 }):Play()
			task.wait(1.6)
		end
	end)
	makeSign(hubFolder, Vector3.new(HUB_X - 12, 3.75, portalZ - 4),
		"🌲 Wald-Portal", "E drücken: Schicht wählen",
		Color3.fromRGB(95, 230, 110))

	-- ProximityPrompt on the portal
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Schicht wählen"
	prompt.ObjectText = "Wald-Portal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalGlow

	prompt.Triggered:Connect(function(player)
		local pdata = dataService.get(player)
		if pdata then
			net.OpenLayerSelect:FireClient(player, pdata.highestLayer)
		end
	end)

	-- ── Arena entrance (south, -Z) — placeholder until Phase 5 ──
	local arenaZ = HUB_Z - 60
	for side = -1, 1, 2 do
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(12, 2.2, 2.2),
			cframe = CFrame.new(HUB_X + side * 6, 7, arenaZ) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.SmoothPlastic,
			color = Color3.fromRGB(160, 60, 50),
		}, hubFolder)
	end
	part({
		size = Vector3.new(14, 1.6, 1.8),
		pos = Vector3.new(HUB_X, 13.2, arenaZ),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(120, 50, 40),
	}, hubFolder)
	makeSign(hubFolder, Vector3.new(HUB_X + 10, 3.75, arenaZ + 5),
		"⚔ PVP-Arena", "Rot: 1v1 | Blau: Bot-Training",
		Color3.fromRGB(235, 90, 70))

	-- ── Schmiede (east, +X) — building shell, ForgeService in Phase 3 ──
	local forgeX = HUB_X + 58
	part({  -- walls
		size = Vector3.new(18, 10, 14),
		pos = Vector3.new(forgeX, 6, HUB_Z),
		material = Enum.Material.Brick,
		color = Color3.fromRGB(105, 78, 58),
	}, hubFolder)
	part({  -- roof
		shape = "Wedge",
		size = Vector3.new(18, 5, 8),
		cframe = CFrame.new(forgeX, 13.5, HUB_Z - 3.5),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(75, 52, 36),
	}, hubFolder)
	part({  -- roof (other half)
		shape = "Wedge",
		size = Vector3.new(18, 5, 8),
		cframe = CFrame.new(forgeX, 13.5, HUB_Z + 3.5) * CFrame.Angles(0, math.rad(180), 0),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(75, 52, 36),
	}, hubFolder)
	part({  -- glowing furnace mouth
		size = Vector3.new(3, 4, 0.5),
		pos = Vector3.new(forgeX - 9.2, 3.5, HUB_Z),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(255, 120, 30),
		collide = false,
	}, hubFolder)
	makeSign(hubFolder, Vector3.new(forgeX - 13, 3.75, HUB_Z + 9),
		"🔨 Schmiede", "E an der Tür: Betreten",
		Color3.fromRGB(255, 150, 60))

	-- ── Forge interior: a closed room high above the map. The door prompt
	-- teleports the player INSIDE; there the sword is leveled with Bamboos. ──
	local FORGE_INT = Vector3.new(HUB_X, 500, HUB_Z + 400)
	do
		local R = 26  -- room half-size
		-- Floor / ceiling / walls (enclosed — you never see outside)
		part({ size = Vector3.new(R * 2, 2, R * 2), pos = FORGE_INT + Vector3.new(0, -1, 0),
			material = Enum.Material.WoodPlanks, color = Color3.fromRGB(95, 68, 45) }, hubFolder)
		part({ size = Vector3.new(R * 2, 2, R * 2), pos = FORGE_INT + Vector3.new(0, 15, 0),
			material = Enum.Material.Wood, color = Color3.fromRGB(70, 50, 34) }, hubFolder)
		for _, w in ipairs({
			{ Vector3.new(R * 2, 16, 2), Vector3.new(0, 7, -R) },
			{ Vector3.new(R * 2, 16, 2), Vector3.new(0, 7, R) },
			{ Vector3.new(2, 16, R * 2), Vector3.new(-R, 7, 0) },
			{ Vector3.new(2, 16, R * 2), Vector3.new(R, 7, 0) },
		}) do
			part({ size = w[1], pos = FORGE_INT + w[2],
				material = Enum.Material.Brick, color = Color3.fromRGB(88, 64, 48) }, hubFolder)
		end
		-- Furnace (glowing) + anvil
		part({ size = Vector3.new(7, 8, 4), pos = FORGE_INT + Vector3.new(0, 4, -R + 4),
			material = Enum.Material.Slate, color = Color3.fromRGB(60, 58, 56) }, hubFolder)
		local fire = part({ size = Vector3.new(4, 3.5, 0.6), pos = FORGE_INT + Vector3.new(0, 2.5, -R + 5.9),
			material = Enum.Material.Neon, color = Color3.fromRGB(255, 120, 30), collide = false }, hubFolder)
		local fireLight = Instance.new("PointLight")
		fireLight.Color = Color3.fromRGB(255, 140, 50)
		fireLight.Range = 24
		fireLight.Brightness = 1.6
		fireLight.Parent = fire
		part({ size = Vector3.new(3.2, 1.2, 1.2), pos = FORGE_INT + Vector3.new(6, 2.6, -R + 6),
			material = Enum.Material.Metal, color = Color3.fromRGB(70, 72, 78) }, hubFolder)
		part({ size = Vector3.new(1.2, 2, 1.4), pos = FORGE_INT + Vector3.new(6, 1, -R + 6),
			material = Enum.Material.Wood, color = Color3.fromRGB(80, 56, 36) }, hubFolder)
		-- Warm ambient lamps
		for _, lx in ipairs({ -R + 4, R - 4 }) do
			local lamp = part({ size = Vector3.new(1, 1, 1), pos = FORGE_INT + Vector3.new(lx, 11, 0),
				material = Enum.Material.Neon, color = Color3.fromRGB(255, 200, 110), collide = false }, hubFolder)
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 200, 110)
			l.Range = 22
			l.Parent = lamp
		end

		-- Anvil prompt: opens the sword-leveling UI (currency: Bamboos)
		local anvilPrompt = Instance.new("ProximityPrompt")
		anvilPrompt.ActionText = "Schwert schmieden"
		anvilPrompt.ObjectText = "Amboss"
		anvilPrompt.HoldDuration = 0
		anvilPrompt.MaxActivationDistance = 20
		anvilPrompt.RequiresLineOfSight = false
		anvilPrompt.Parent = fire
		anvilPrompt.Triggered:Connect(function(player)
			net.OpenForge:FireClient(player)
		end)

		-- Exit door
		local door = part({ size = Vector3.new(4, 7, 1), pos = FORGE_INT + Vector3.new(0, 3.5, R - 1),
			material = Enum.Material.Wood, color = Color3.fromRGB(120, 85, 50) }, hubFolder)
		local exitPrompt = Instance.new("ProximityPrompt")
		exitPrompt.ActionText = "Zur Overworld"
		exitPrompt.ObjectText = "Tür"
		exitPrompt.HoldDuration = 0
		exitPrompt.MaxActivationDistance = 14
		exitPrompt.RequiresLineOfSight = false
		exitPrompt.Parent = door
		exitPrompt.Triggered:Connect(function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(forgeX - 14, 4, HUB_Z)
			end
		end)
	end

	-- Door prompt at the forge building → teleport INTO the forge room
	local forgeDoor = part({
		size = Vector3.new(3.5, 6, 1),
		pos = Vector3.new(forgeX - 9.5, 3.5, HUB_Z + 4),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(120, 85, 50),
	}, hubFolder)
	local forgePrompt = Instance.new("ProximityPrompt")
	forgePrompt.ActionText = "Schmiede betreten"
	forgePrompt.ObjectText = "Schmiede"
	forgePrompt.HoldDuration = 0
	forgePrompt.MaxActivationDistance = 16
	forgePrompt.RequiresLineOfSight = false
	forgePrompt.Parent = forgeDoor
	forgePrompt.Triggered:Connect(function(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(FORGE_INT + Vector3.new(0, 4, 10))
			net.OpenForge:FireClient(player)
		end
	end)

	-- ── Rebirth-Schrein (west, -X) — placeholder until Phase 4 ──
	local shrineX = HUB_X - 58
	for i = 0, 2 do
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.9, 12 - i * 3.2, 12 - i * 3.2),
			cframe = CFrame.new(shrineX, 1.5 + i * 0.9, HUB_Z) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Marble,
			color = Color3.fromRGB(165, 158, 175),
		}, hubFolder)
	end
	local crystal = part({
		size = Vector3.new(1.8, 3.4, 1.8),
		cframe = CFrame.new(shrineX, 6.2, HUB_Z) * CFrame.Angles(0, math.rad(45), 0),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(170, 110, 235),
		collide = false,
	}, hubFolder)
	task.spawn(function()  -- slow rotation
		while crystal.Parent do
			crystal.CFrame = crystal.CFrame * CFrame.Angles(0, math.rad(1.2), 0)
			task.wait(0.05)
		end
	end)
	makeSign(hubFolder, Vector3.new(shrineX, 3.75, HUB_Z + 9),
		"✨ Rebirth-Schrein", "E: Rebirth (ab Lv. 50)",
		Color3.fromRGB(190, 130, 245))

	-- Rebirth prompt
	local shrinePrompt = Instance.new("ProximityPrompt")
	shrinePrompt.ActionText = "Rebirth"
	shrinePrompt.ObjectText = "Rebirth-Schrein"
	shrinePrompt.HoldDuration = 1.5  -- hold to confirm — it resets progress!
	shrinePrompt.MaxActivationDistance = 12
	shrinePrompt.RequiresLineOfSight = false
	shrinePrompt.Parent = crystal
	shrinePrompt.Triggered:Connect(function(player)
		if HubService.rebirthHandler then
			HubService.rebirthHandler(player)
		end
	end)

	-- ── Daily-Reward chest (north-east of the fountain) ──
	local chestX, chestZ = HUB_X + 28, HUB_Z + 28
	part({  -- chest body
		size = Vector3.new(4, 2.6, 2.8),
		pos = Vector3.new(chestX, 2.3, chestZ),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(125, 88, 48),
	}, hubFolder)
	local chestLid = part({  -- lid
		size = Vector3.new(4.2, 1, 3),
		pos = Vector3.new(chestX, 4, chestZ),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(100, 70, 38),
	}, hubFolder)
	part({  -- gold glow seam
		size = Vector3.new(4.1, 0.25, 2.9),
		pos = Vector3.new(chestX, 3.5, chestZ),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(255, 215, 80),
		collide = false,
	}, hubFolder)
	makeSign(hubFolder, Vector3.new(chestX, 3.75, chestZ + 5),
		"🎁 Daily-Reward", "E: Täglich abholen",
		Color3.fromRGB(255, 215, 80))

	local chestPrompt = Instance.new("ProximityPrompt")
	chestPrompt.ActionText = "Abholen"
	chestPrompt.ObjectText = "Daily-Reward"
	chestPrompt.HoldDuration = 0
	chestPrompt.MaxActivationDistance = 10
	chestPrompt.RequiresLineOfSight = false
	chestPrompt.Parent = chestLid
	chestPrompt.Triggered:Connect(function(player)
		local pdata = dataService.get(player)
		if not pdata then return end
		local now = os.time()
		if now - (pdata.lastDaily or 0) < 20 * 3600 then
			local hoursLeft = math.ceil((20 * 3600 - (now - pdata.lastDaily)) / 3600)
			net.Notify:FireClient(player, "🎁 Schon abgeholt! Wieder in ~" .. hoursLeft .. "h")
			return
		end
		pdata.lastDaily = now
		local reward = 250 * (1 + (pdata.rebirths or 0))
		pdata.coins = pdata.coins + reward
		dataService.sendUpdate(player)
		net.Notify:FireClient(player, "🎁 +" .. reward .. " Bamboos!")
	end)

	-- Lantern posts around the plaza
	for a = 0, 7 do
		local ang = a / 8 * math.pi * 2
		local lx = HUB_X + math.cos(ang) * 38
		local lz = HUB_Z + math.sin(ang) * 38
		part({
			size = Vector3.new(0.5, 7, 0.5),
			pos = Vector3.new(lx, 4.5, lz),
			material = Enum.Material.Wood,
			color = Color3.fromRGB(70, 50, 32),
			collide = false,
		}, hubFolder)
		local lamp = part({
			size = Vector3.new(1.1, 1.1, 1.1),
			pos = Vector3.new(lx, 8.3, lz),
			material = Enum.Material.Neon,
			color = Color3.fromRGB(255, 205, 120),
			collide = false,
		}, hubFolder)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 120)
		light.Range = 16
		light.Brightness = 0.8
		light.Parent = lamp
	end
end

-- ── Public ────────────────────────────────────────────────────────────────────

-- Set by Server.server.lua after RebirthService is loaded
HubService.rebirthHandler = nil

function HubService.getSpawnPosition()
	return Vector3.new(HUB_X, 2.5, HUB_Z - 20)
end

function HubService.init(ds, netRef)
	dataService = ds
	net         = netRef

	local old = workspace:FindFirstChild("Hub")
	if old then old:Destroy() end

	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = workspace

	buildHub(hubFolder)

	-- Teleport request: validate unlock, move character, tell client to apply lighting
	net.TeleportToLayer.OnServerEvent:Connect(function(player, layerIdx)
		if type(layerIdx) ~= "number" then return end
		layerIdx = math.floor(layerIdx)
		local layer = Layers.DATA[layerIdx]
		if not layer then return end

		local pdata = dataService.get(player)
		if not pdata then return end
		if layerIdx > pdata.highestLayer then
			net.Notify:FireClient(player, "🔒 " .. layer.name .. " ist noch gesperrt!")
			return
		end

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Spawn point comes from the WorldGenerator (terrain height varies)
		local WorldService = require(script.Parent:WaitForChild("WorldService"))
		local spawn = WorldService.getLayerSpawn(layerIdx) or Vector3.new(layer.offsetX, 6, 0)
		root.CFrame = CFrame.new(spawn + Vector3.new(0, 3, 0))
		net.ApplyLayerLighting:FireClient(player, layerIdx)
	end)

	-- Teleport back to hub
	net.TeleportToHub.OnServerEvent:Connect(function(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		root.CFrame = CFrame.new(HubService.getSpawnPosition() + Vector3.new(0, 3, 0))
		net.ApplyLayerLighting:FireClient(player, 0)  -- 0 = hub lighting
	end)

	print("[HubService] Overworld-Hub gebaut.")
end

return HubService
