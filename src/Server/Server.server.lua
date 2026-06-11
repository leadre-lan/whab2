-- Server.server.lua (Script in ServerScriptService)
-- All server-side logic for Bamboo Slasher

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ─── Cleanup leftovers from older versions ───────────────────────────────────
for _, name in ipairs({ "BambooRemotes" }) do
	local old = ReplicatedStorage:FindFirstChild(name)
	if old then old:Destroy() end
end
local oldZones = workspace:FindFirstChild("Zones")
if oldZones then oldZones:Destroy() end

-- ─── RemoteEvents Setup ───────────────────────────────────────────────────────
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "BambooRemotes"
remotesFolder.Parent = ReplicatedStorage

local UpdateData = Instance.new("RemoteEvent")
UpdateData.Name = "UpdateData"
UpdateData.Parent = remotesFolder

local BuyUpgrade = Instance.new("RemoteEvent")
BuyUpgrade.Name = "BuyUpgrade"
BuyUpgrade.Parent = remotesFolder

local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotesFolder

-- Client fires this with the bamboo hitbox it aimed at.
-- (ClickDetectors do not receive clicks while a Tool is equipped,
-- so chopping goes through this remote instead.)
local ChopBamboo = Instance.new("RemoteEvent")
ChopBamboo.Name = "ChopBamboo"
ChopBamboo.Parent = remotesFolder

-- Server fires this to all nearby clients when a bamboo/rock is hit.
local HitEffect = Instance.new("RemoteEvent")
HitEffect.Name = "HitEffect"
HitEffect.Parent = remotesFolder

-- Client fires this when performing an aerial slam.
local SlamAttack = Instance.new("RemoteEvent")
SlamAttack.Name = "SlamAttack"
SlamAttack.Parent = remotesFolder

-- ─── World Setup ──────────────────────────────────────────────────────────────
workspace.Terrain:Clear()

local existingBase = workspace:FindFirstChild("Baseplate")
if existingBase then
	existingBase:Destroy()
end

local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = Vector3.new(2048, 20, 2048)
baseplate.Position = Vector3.new(260, -10, 0)
baseplate.Material = Enum.Material.Grass
baseplate.Color = Color3.fromRGB(106, 127, 63)
baseplate.Anchored = true
baseplate.CanCollide = true
baseplate.Parent = workspace

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "SpawnLocation"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = Vector3.new(0, 1.5, 0)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Color = Color3.fromRGB(163, 162, 165)
spawnLocation.Parent = workspace

-- ─── DataStore ────────────────────────────────────────────────────────────────
-- GetDataStore throws in Studio when the place isn't published; fall back to
-- session-only data so the game still runs.
local dataStoreOk, dataStore = pcall(function()
	return DataStoreService:GetDataStore("BambooSlasher_v2")
end)
if not dataStoreOk then
	warn("[BambooSlasher] DataStore nicht verfuegbar (Spiel nicht veroeffentlicht) - Fortschritt wird nur in dieser Session gespeichert.")
	dataStore = nil
end
local playerData = {}

local function defaultData()
	return {
		coins        = 0,
		swordLevel   = 1,
		totalChopped = 0,
	}
end

local function mergeWithDefault(data)
	local def = defaultData()
	if type(data) ~= "table" then return def end
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

local function loadData(player)
	if not dataStore then
		playerData[player] = defaultData()
		return
	end
	local success, result = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)
	if success and result then
		playerData[player] = mergeWithDefault(result)
	else
		playerData[player] = defaultData()
	end
end

local function saveData(player)
	if not dataStore then return end
	local data = playerData[player]
	if not data then return end
	pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, data)
	end)
end

local function sendUpdate(player)
	local data = playerData[player]
	if data then
		UpdateData:FireClient(player, data)
	end
end

-- ─── Player Events ────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	loadData(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		sendUpdate(player)
	end)
	if player.Character then
		task.wait(0.5)
		sendUpdate(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
end)

-- Auto-save every 60 seconds
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- ─── BuyUpgrade Handler ───────────────────────────────────────────────────────
BuyUpgrade.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local nextLevel = data.swordLevel + 1
	local nextSword = Config.SWORDS[nextLevel]
	if not nextSword then return end -- already max level

	if data.coins < nextSword.cost then return end -- can't afford

	data.coins     = data.coins - nextSword.cost
	data.swordLevel = nextLevel
	sendUpdate(player)
end)

-- ─── World Generation ─────────────────────────────────────────────────────────
local rng             = Random.new(42)
local bambooHealth    = {}   -- [part] = currentHealth number
local playerCooldowns = {}   -- ["userId_partInstance"] = lastSwingTime (os.clock)
local chopHandlers    = {}   -- [hitboxPart] = function(player) chop logic
local playerCombo     = {}   -- [player] = { count=N, lastHitTime=os.clock() }

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = workspace

for _, zone in ipairs(Config.ZONES) do
	local bambooType = Config.BAMBOO_TYPES[zone.bambooTypeId]
	local zoneX      = zone.offsetX

	-- Zone folder
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.name
	zoneFolder.Parent = zonesFolder

	-- Grass platform (110x2x110)
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	-- Top surface at Y = 1 (one stud above the baseplate, prevents Z-fighting)
	platform.Size = Vector3.new(110, 2, 110)
	platform.Position = Vector3.new(zoneX, 0, 0)
	platform.Material = Enum.Material.Grass
	platform.Color = Color3.fromRGB(106, 127, 63)
	platform.Anchored = true
	platform.CanCollide = true
	platform.Parent = zoneFolder

	-- Zone sign post
	local signPart = Instance.new("Part")
	signPart.Name = "ZoneSign"
	signPart.Size = Vector3.new(0.4, 5, 0.4)
	signPart.Position = Vector3.new(zoneX - 50, 3.5, 0)
	signPart.Material = Enum.Material.Wood
	signPart.Color = Color3.fromRGB(106, 74, 40)
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.Parent = zoneFolder

	-- BillboardGui on sign post
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 240, 0, 90)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = signPart

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = zone.name
	titleLabel.Parent = billboard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(1, 0, 0.45, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.55, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	levelLabel.TextStrokeTransparency = 0
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Text = "⚔ Level " .. zone.requiredLevel .. " erforderlich"
	levelLabel.Parent = billboard

	-- Spawn bamboo stalks (each is a Model: invisible hitbox + segmented visuals)
	for i = 1, zone.count do
		local rx = rng:NextNumber(-48, 48)
		local rz = rng:NextNumber(-48, 48)
		local h  = bambooType.height
		local th = bambooType.thickness
		local baseX, baseZ = zoneX + rx, rz

		local model = Instance.new("Model")
		model.Name = "Bamboo"

		-- Invisible hitbox covering the whole stalk (this is what gets clicked)
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = Vector3.new(th * 2.5, h, th * 2.5)
		hitbox.Position = Vector3.new(baseX, 1 + h / 2, baseZ)
		hitbox.Transparency = 1
		hitbox.Anchored = true
		hitbox.CanCollide = true
		hitbox:SetAttribute("IsBamboo", true)
		hitbox:SetAttribute("IsDead", false)
		hitbox.Parent = model
		model.PrimaryPart = hitbox

		-- Visual segments: stacked cylinders with darker node rings between them
		-- (cylinder Parts lie along the X axis, so rotate 90° around Z to stand up)
		local visuals = {}   -- { {part=Part, color=Color3}, ... } bottom to top
		local segCount = math.max(3, math.floor(h / 3))
		local segH = h / segCount
		local nodeColor = Color3.new(
			bambooType.color.R * 0.55,
			bambooType.color.G * 0.55,
			bambooType.color.B * 0.55)

		for s = 1, segCount do
			local segY = 1 + (s - 0.5) * segH
			local seg = Instance.new("Part")
			seg.Name = "Segment"
			seg.Shape = Enum.PartType.Cylinder
			seg.Size = Vector3.new(segH - 0.1, th, th)
			seg.CFrame = CFrame.new(baseX, segY, baseZ) * CFrame.Angles(0, 0, math.rad(90))
			seg.Material = Enum.Material.SmoothPlastic
			seg.Color = bambooType.color
			seg.Anchored = true
			seg.CanCollide = false
			seg.Parent = model
			table.insert(visuals, { part = seg, color = bambooType.color })

			-- Node ring on top of each segment (except the last)
			if s < segCount then
				local ring = Instance.new("Part")
				ring.Name = "Node"
				ring.Shape = Enum.PartType.Cylinder
				ring.Size = Vector3.new(0.2, th * 1.18, th * 1.18)
				ring.CFrame = CFrame.new(baseX, 1 + s * segH, baseZ) * CFrame.Angles(0, 0, math.rad(90))
				ring.Material = Enum.Material.SmoothPlastic
				ring.Color = nodeColor
				ring.Anchored = true
				ring.CanCollide = false
				ring.Parent = model
				table.insert(visuals, { part = ring, color = nodeColor })
			end
		end

		-- Leaves at the top (thin angled slabs)
		local leafColor = Color3.fromRGB(70, 150, 50)
		for l = 1, 3 do
			local angle = (l / 3) * math.pi * 2 + rng:NextNumber(0, 1)
			local leaf = Instance.new("Part")
			leaf.Name = "Leaf"
			leaf.Size = Vector3.new(2.4, 0.1, 0.8)
			leaf.CFrame = CFrame.new(baseX, 1 + h - 0.5, baseZ)
				* CFrame.Angles(0, angle, math.rad(-35))
				* CFrame.new(1.2, 0, 0)
			leaf.Material = Enum.Material.Grass
			leaf.Color = leafColor
			leaf.Anchored = true
			leaf.CanCollide = false
			leaf.Parent = model
			table.insert(visuals, { part = leaf, color = leafColor })
		end

		model.Parent = zoneFolder
		bambooHealth[hitbox] = bambooType.health

		-- Hit + break sounds (rbxasset builtins always load, unlike marketplace IDs)
		local hitSound = Instance.new("Sound")
		hitSound.Name = "HitSound"
		hitSound.SoundId = "rbxasset://sounds/snap.mp3"
		hitSound.Volume = 0.8
		hitSound.Parent = hitbox

		local breakSound = Instance.new("Sound")
		breakSound.Name = "BreakSound"
		breakSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		breakSound.Volume = 1
		breakSound.Parent = hitbox

		-- ClickDetector so client doesn't need raycasts
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = hitbox

		-- Capture loop variables explicitly
		local capturedBambooType = bambooType
		local capturedZone       = zone

		local function setAllTransparency(value)
			for _, v in ipairs(visuals) do
				v.part.Transparency = value
			end
		end

		local function resetColors()
			for _, v in ipairs(visuals) do
				v.part.Color = v.color
			end
		end

		-- Grow animation: segments appear bottom-to-top
		local function growBamboo()
			setAllTransparency(1)
			for _, v in ipairs(visuals) do
				v.part.Transparency = 0
				task.wait(0.05)
			end
		end

		local function respawnThis()
			task.wait(capturedBambooType.respawnTime)
			if not hitbox.Parent then return end
			bambooHealth[hitbox] = capturedBambooType.health
			hitbox:SetAttribute("IsDead", false)
			hitbox.CanCollide = true
			resetColors()
			growBamboo()
		end

		local function tryChop(player)
			local data = playerData[player]
			if not data then return end

			-- Must be alive
			if hitbox:GetAttribute("IsDead") then return end

			-- Zone level requirement
			if data.swordLevel < capturedZone.requiredLevel then
				Notify:FireClient(player, "⚔ Schwertlevel " .. capturedZone.requiredLevel .. " benoetigt!")
				return
			end

			-- Per-player per-bamboo cooldown
			local cdKey = tostring(player.UserId) .. "_" .. tostring(hitbox)
			local now   = os.clock()
			local last  = playerCooldowns[cdKey]
			if last and (now - last) < Config.SWING_DELAY then return end
			playerCooldowns[cdKey] = now

			-- Deal damage
			local sword  = Config.SWORDS[data.swordLevel]
			local damage = sword and sword.damage or 1
			bambooHealth[hitbox] = bambooHealth[hitbox] - damage
			hitSound:Play()

			-- Lerp all visuals toward orange as health drops
			local maxHealth  = capturedBambooType.health
			local healthFrac = math.max(0, bambooHealth[hitbox]) / maxHealth
			for _, v in ipairs(visuals) do
				v.part.Color = v.color:Lerp(Color3.fromRGB(255, 80, 0), 1 - healthFrac)
			end

			-- Check if destroyed
			if bambooHealth[hitbox] <= 0 then
				hitbox:SetAttribute("IsDead", true)
				hitbox.CanCollide = false
				setAllTransparency(1)
				breakSound:Play()

				data.coins        = data.coins + capturedBambooType.coins
				data.totalChopped = data.totalChopped + 1
				sendUpdate(player)

				-- Schedule respawn (with grow animation)
				task.spawn(respawnThis)
			end
		end

		chopHandlers[hitbox] = tryChop
		clickDetector.MouseClick:Connect(tryChop)
	end
end

-- Remote chop entry point (validated server-side)
ChopBamboo.OnServerEvent:Connect(function(player, part)
	if typeof(part) ~= "Instance" then return end
	local handler = chopHandlers[part]
	if not handler then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (root.Position - part.Position).Magnitude > 30 then return end

	handler(player)
end)

-- ─── Decorative Forest + Atmosphere ──────────────────────────────────────────
-- Surround the play area with simple trees so nothing looks empty,
-- and add fog so the horizon disappears into green.
local Lighting = game:GetService("Lighting")
Lighting.FogStart = 90
Lighting.FogEnd = 280
Lighting.FogColor = Color3.fromRGB(150, 180, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 150, 120)

local forestFolder = Instance.new("Folder")
forestFolder.Name = "Forest"
forestFolder.Parent = workspace

local function makeTree(x, z)
	local scale = rng:NextNumber(0.8, 1.6)
	local trunkH = 9 * scale

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(trunkH, 1.6 * scale, 1.6 * scale)
	trunk.CFrame = CFrame.new(x, trunkH / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(95, 65, 40)
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.Parent = forestFolder

	for c = 1, 2 do
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Shape = Enum.PartType.Ball
		local size = (7 - c * 1.5) * scale
		canopy.Size = Vector3.new(size, size, size)
		canopy.Position = Vector3.new(
			x + rng:NextNumber(-1, 1),
			trunkH + (c - 1) * 2.2 * scale,
			z + rng:NextNumber(-1, 1))
		canopy.Material = Enum.Material.Grass
		canopy.Color = Color3.fromRGB(46 + rng:NextInteger(0, 25), 110 + rng:NextInteger(0, 30), 40)
		canopy.Anchored = true
		canopy.CanCollide = false
		canopy.Parent = forestFolder
	end
end

-- Scatter trees everywhere EXCEPT on the zone platforms
-- (platforms occupy x in [-55, 575], z in [-55, 55])
local treeCount = 0
while treeCount < 220 do
	local x = rng:NextNumber(-250, 770)
	local z = rng:NextNumber(-300, 300)
	local onPlatforms = (x > -65 and x < 585 and z > -65 and z < 65)
	if not onPlatforms then
		makeTree(x, z)
		treeCount += 1
	end
end

print("[BambooSlasher] Server ready - " .. #Config.ZONES .. " Zonen generiert.")
