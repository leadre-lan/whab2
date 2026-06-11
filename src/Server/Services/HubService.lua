-- HubService.lua — Overworld hub: spawn plaza, forest portal, layer teleports,
-- placeholder buildings for forge/arena/shrine (full features come in later phases)
local HubService = {}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layers = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

-- Hub is far west of the forest layers (layers start at x=5000)
local HUB_X = -320
local HUB_Z = 0

local dataService = nil
local net         = nil

-- With StreamingEnabled the target region may not exist on the client yet:
-- a plain CFrame teleport lets the character fall through the unloaded world
-- and die (= "teleport doesn't work"). Anchor while the area streams in.
local function safeTeleport(player, targetCFrame)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.Anchored = true
	root.CFrame = targetCFrame
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(targetCFrame.Position, 5)
		end)
		task.wait(0.2)
		if root.Parent then root.Anchored = false end
	end)
end

-- Teleport into a forest layer (nil layerIdx = highest unlocked).
-- Used by the layer-select UI AND by walking through the portal.
local function teleportToLayer(player, layerIdx)
	local pdata = dataService.getOrLoad(player)
	if not pdata then return end

	layerIdx = layerIdx or pdata.highestLayer or 1
	local layer = Layers.DATA[layerIdx]
	if not layer then return end
	if layerIdx > (pdata.highestLayer or 1) then
		net.Notify:FireClient(player, "🔒 " .. layer.name .. " ist noch gesperrt!")
		return
	end

	-- Spawn point comes from the WorldGenerator (terrain height varies)
	local WorldService = require(script.Parent:WaitForChild("WorldService"))
	local spawn = WorldService.getLayerSpawn(layerIdx) or Vector3.new(layer.offsetX, 6, 0)
	safeTeleport(player, CFrame.new(spawn + Vector3.new(0, 3, 0)))
	net.PlaySFX:FireClient(player, "Teleport")
	net.ApplyLayerLighting:FireClient(player, layerIdx)
	net.Notify:FireClient(player, "🌲 " .. layer.name)
end

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
	part({
		size = Vector3.new(1.4, 7, 1.4),
		pos = Vector3.new(HUB_X, 5, HUB_Z),
		material = Enum.Material.Marble,
		color = Color3.fromRGB(205, 200, 192),
	}, hubFolder)
	-- Katana-Monument: das klassische Roblox-Katana steckt mit der Spitze
	-- nach unten im Marmorsockel (Mesh + Textur, siehe Shared/Assets.lua)
	do
		local katana = Assets.MESHES.Katana
		local monument = Instance.new("Part")
		monument.Size = Vector3.new(1, 1, 1)
		monument.Transparency = 1   -- nur das Mesh ist sichtbar
		monument.Anchored = true
		monument.CanCollide = false
		-- Mesh-Klinge zeigt +Z → um +90° um X gedreht zeigt sie nach unten
		monument.CFrame = CFrame.new(HUB_X, 11.6, HUB_Z)
			* CFrame.Angles(math.rad(90), math.rad(35), 0)
		monument.Parent = hubFolder

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = katana.meshId
		mesh.TextureId = katana.textureId
		mesh.Scale = Vector3.new(2.6, 2.6, 2.6)
		mesh.Parent = monument

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 215, 120)
		glow.Range = 16
		glow.Brightness = 0.9
		glow.Parent = monument
	end
	makeSign(hubFolder, Vector3.new(HUB_X, 3.75, HUB_Z - 12),
		"🏯 Bamboo Slasher", "Willkommen in der Overworld!",
		Color3.fromRGB(120, 230, 120))

	-- ── Wald-Portal (north, +Z) — ein rotes Torii-Tor zu den Wald-Schichten ──
	local portalZ = HUB_Z + 60
	local TORII_RED  = Color3.fromRGB(186, 48, 38)
	local TORII_DARK = Color3.fromRGB(40, 34, 32)
	for side = -1, 1, 2 do
		-- Steinsockel + roter Pfeiler
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.2, 3.6, 3.6),
			cframe = CFrame.new(HUB_X + side * 7, 1.6, portalZ) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(95, 92, 88),
		}, hubFolder)
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(14.5, 2.2, 2.2),
			cframe = CFrame.new(HUB_X + side * 7, 9, portalZ) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.SmoothPlastic,
			color = TORII_RED,
		}, hubFolder)
	end
	-- Nuki (unterer Querbalken, steckt durch die Pfeiler)
	part({
		size = Vector3.new(19, 1.4, 1.1),
		pos = Vector3.new(HUB_X, 13.2, portalZ),
		material = Enum.Material.SmoothPlastic,
		color = TORII_RED,
	}, hubFolder)
	-- Shimaki + Kasagi (Doppel-Dachbalken, der obere dunkel und überstehend)
	part({
		size = Vector3.new(21, 1.2, 1.6),
		pos = Vector3.new(HUB_X, 16, portalZ),
		material = Enum.Material.SmoothPlastic,
		color = TORII_RED,
	}, hubFolder)
	part({
		size = Vector3.new(24, 1.1, 2.2),
		pos = Vector3.new(HUB_X, 17.1, portalZ),
		material = Enum.Material.Slate,
		color = TORII_DARK,
	}, hubFolder)
	-- Geschwungene Dach-Enden (leicht nach oben gekippt)
	for side = -1, 1, 2 do
		part({
			size = Vector3.new(3.4, 1.1, 2.2),
			cframe = CFrame.new(HUB_X + side * 13.1, 17.55, portalZ)
				* CFrame.Angles(0, 0, side * math.rad(14)),
			material = Enum.Material.Slate,
			color = TORII_DARK,
		}, hubFolder)
	end
	-- Gakuzuka (Mittelstrebe) mit goldener Plakette
	part({
		size = Vector3.new(1.2, 2.0, 0.9),
		pos = Vector3.new(HUB_X, 14.8, portalZ),
		material = Enum.Material.SmoothPlastic,
		color = TORII_RED,
	}, hubFolder)
	part({
		size = Vector3.new(1.6, 1.2, 0.3),
		pos = Vector3.new(HUB_X, 14.8, portalZ - 0.5),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(212, 175, 55),
		collide = false,
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
		"🌲 Wald-Portal", "Durchlaufen: Wald | E: Schicht wählen",
		Color3.fromRGB(95, 230, 110))

	-- Walking through the glow teleports to the highest unlocked layer —
	-- pressing E next to it opens the layer-select instead.
	portalGlow.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		local last = player:GetAttribute("PortalCooldown") or 0
		if os.clock() - last < 4 then return end
		player:SetAttribute("PortalCooldown", os.clock())
		teleportToLayer(player, nil)
	end)

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
		local pdata = dataService.getOrLoad(player)
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
			safeTeleport(player, CFrame.new(forgeX - 14, 4, HUB_Z))
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
			safeTeleport(player, CFrame.new(FORGE_INT + Vector3.new(0, 4, 10)))
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
		net.PlaySFX:FireClient(player, "Coin")
		net.Notify:FireClient(player, "🎁 +" .. reward .. " Bamboos!")
	end)

	-- Japanische Laternen rund um den Platz (Sockel, Pfosten, Lichtkasten, Dach)
	for a = 0, 7 do
		local ang = a / 8 * math.pi * 2
		local lx = HUB_X + math.cos(ang) * 38
		local lz = HUB_Z + math.sin(ang) * 38
		part({  -- Steinsockel
			size = Vector3.new(1.6, 1, 1.6),
			pos = Vector3.new(lx, 1.5, lz),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(98, 95, 90),
		}, hubFolder)
		part({  -- Holzpfosten
			size = Vector3.new(0.5, 5.5, 0.5),
			pos = Vector3.new(lx, 4.5, lz),
			material = Enum.Material.Wood,
			color = Color3.fromRGB(70, 50, 32),
			collide = false,
		}, hubFolder)
		part({  -- dunkler Rahmen des Lichtkastens
			size = Vector3.new(1.5, 1.7, 1.5),
			pos = Vector3.new(lx, 8.1, lz),
			material = Enum.Material.Wood,
			color = Color3.fromRGB(45, 36, 28),
			collide = false,
		}, hubFolder)
		local lamp = part({  -- warmes Licht, leicht aus dem Rahmen tretend
			size = Vector3.new(1.15, 1.3, 1.15),
			pos = Vector3.new(lx, 8.1, lz),
			material = Enum.Material.Neon,
			color = Color3.fromRGB(255, 205, 120),
			collide = false,
		}, hubFolder)
		part({  -- geschwungenes Dach (zwei Ebenen)
			size = Vector3.new(2.2, 0.35, 2.2),
			pos = Vector3.new(lx, 9.15, lz),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(40, 34, 32),
			collide = false,
		}, hubFolder)
		part({
			size = Vector3.new(1.1, 0.3, 1.1),
			pos = Vector3.new(lx, 9.5, lz),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(40, 34, 32),
			collide = false,
		}, hubFolder)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 120)
		light.Range = 16
		light.Brightness = 0.8
		light.Parent = lamp
	end

	-- ── Kirschblütenbaum am Platzrand (mit fallenden Blütenblättern) ──
	do
		local tx, tz = HUB_X + 30, HUB_Z - 32
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(11, 1.6, 1.6),
			cframe = CFrame.new(tx, 6.5, tz) * CFrame.Angles(0, 0, math.rad(86)),
			material = Enum.Material.Wood,
			color = Color3.fromRGB(122, 102, 96),
		}, hubFolder)
		local petalColor = Color3.fromRGB(248, 198, 222)
		for c = 1, 3 do
			local w = 9 - c * 1.8
			local blob = part({
				size = Vector3.new(w, w * 0.6, w),
				pos = Vector3.new(tx + rng:NextNumber(-1.5, 1.5), 11 + c * 1.4, tz + rng:NextNumber(-1.5, 1.5)),
				material = Enum.Material.Grass,
				color = petalColor:Lerp(Color3.fromRGB(255, 246, 250), rng:NextNumber(0, 0.45)),
				collide = false,
			}, hubFolder)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = blob
			if c == 1 then
				local pe = Instance.new("ParticleEmitter")
				pe.Texture = Assets.PARTICLES.Sparkles
				pe.Rate = 2.5
				pe.Lifetime = NumberRange.new(3.5, 5.5)
				pe.Speed = NumberRange.new(0.5, 1.2)
				pe.SpreadAngle = Vector2.new(40, 40)
				pe.Acceleration = Vector3.new(0.5, -1.6, 0.2)
				pe.Size = NumberSequence.new(0.24)
				pe.Color = ColorSequence.new(petalColor)
				pe.LightEmission = 0.3
				pe.Parent = blob
			end
		end
	end

	-- ── Koi-Teich (Nordwesten): Steinring, Wasser, Seerosen-Lichter ──
	do
		local px, pz = HUB_X - 32, HUB_Z + 30
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.0, 17, 17),
			cframe = CFrame.new(px, 1.4, pz) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(105, 102, 96),
		}, hubFolder)
		part({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.7, 14.5, 14.5),
			cframe = CFrame.new(px, 1.65, pz) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Glass,
			color = Color3.fromRGB(72, 160, 205),
			transparency = 0.4, collide = false,
		}, hubFolder)
		for _ = 1, 4 do
			local lily = part({
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.12, rng:NextNumber(1.2, 2.0), rng:NextNumber(1.2, 2.0)),
				cframe = CFrame.new(px + rng:NextNumber(-5, 5), 2.05, pz + rng:NextNumber(-5, 5))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)),
				material = Enum.Material.Grass,
				color = Color3.fromRGB(70, 150, 70),
				collide = false,
			}, hubFolder)
			if rng:NextNumber() < 0.6 then
				local bloom = part({
					shape = Enum.PartType.Ball,
					size = Vector3.new(0.5, 0.5, 0.5),
					pos = lily.Position + Vector3.new(0, 0.3, 0),
					material = Enum.Material.Neon,
					color = Color3.fromRGB(255, 170, 200),
					collide = false,
				}, hubFolder)
				bloom.CastShadow = false
			end
		end
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
		teleportToLayer(player, math.floor(layerIdx))
	end)

	-- Teleport back to hub
	net.TeleportToHub.OnServerEvent:Connect(function(player)
		safeTeleport(player, CFrame.new(HubService.getSpawnPosition() + Vector3.new(0, 3, 0)))
		net.PlaySFX:FireClient(player, "Teleport")
		net.ApplyLayerLighting:FireClient(player, 0)  -- 0 = hub lighting
	end)

	print("[HubService] Overworld-Hub gebaut.")
end

return HubService
