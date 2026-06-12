-- WeaponService.lua — Server-autoritatives Schießen + Skin-Equip.
-- Schaden ist IMMER gleich (One-Shot, fixer Cooldown) — Skins sind reine Optik.
local WeaponService = {}

local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config        = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins         = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))
local SniperBuilder = require(RS:WaitForChild("Shared"):WaitForChild("SniperBuilder"))

local dataService  = nil
local arenaService = nil
local net          = nil

local lastShot = {}   -- [player] = os.clock()

function WeaponService.setArenaService(svc)
	arenaService = svc
end

-- ── Echtes AWP-Mesh: Template ODER Auto-Load aus dem Creator Store ────────────
-- 1) Studio-Template: Toolbox-Modell "AWP sniper" (13638913296) nach
--    ReplicatedStorage/Assets/Awp ziehen (bakt Mesh+Textur fest in den Platz).
-- 2) Auto-Load: freie Creator-Store-Assets sind via InsertService:LoadAsset
--    ladbar (in Studio immer) — wird beim Start automatisch versucht.
-- 3) Fallback: prozedurale Part-AWP.
-- Das gefundene MeshPart wird vermessen (MeshSize + Raycast-Probe für die
-- Mündung) — danach rendern ALLE Skins das echte texturierte AWP.
local AWP_TARGET_LEN = 5.2
local AWP_STORE_IDS  = { 13638913296, 504829517 }   -- "AWP sniper", "[L4D2] AWP"
local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

local function probeEndHits(meshPart, axis, sign, otherA, otherB)
	local s = meshPart.Size
	local center = meshPart.Position + axis * (axis:Dot(s) * 0.4 * sign)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { meshPart }
	local hits = 0
	for i = -2, 2 do
		for j = -2, 2 do
			local offset = otherA * (otherA:Dot(s) * 0.12 * i) + otherB * (otherB:Dot(s) * 0.12 * j)
			local origin = center + offset + Vector3.new(0, s.Magnitude, 0)
			if workspace:Raycast(origin, Vector3.new(0, -s.Magnitude * 2, 0), params) then
				hits += 1
			end
		end
	end
	return hits
end

-- Vermisst ein AWP-MeshPart und aktiviert den Mesh-Pfad im SniperBuilder
local function setupFromMeshPart(mp)
	if not mp or mp.MeshId == "" then return false end

	local probe = mp:Clone()
	probe:ClearAllChildren()
	local ms = probe.MeshSize
	if ms.Magnitude < 0.05 then
		probe:Destroy()
		return false
	end
	probe.Size = ms
	probe.Anchored = true
	probe.CanCollide = false
	probe.Transparency = 1
	probe.CFrame = CFrame.new(0, 2800, 0)
	probe.Parent = workspace

	local sorted = table.clone(AXES)
	table.sort(sorted, function(a, b) return a:Dot(ms) > b:Dot(ms) end)
	local barrelAxis, upAxis = sorted[1], sorted[2]

	local hitsPos = probeEndHits(probe, barrelAxis, 1, upAxis, sorted[3])
	local hitsNeg = probeEndHits(probe, barrelAxis, -1, upAxis, sorted[3])
	probe:Destroy()

	local muzzleSign = (hitsPos < hitsNeg) and 1 or -1
	local forward = barrelAxis * muzzleSign
	local rot = CFrame.fromMatrix(Vector3.zero, forward:Cross(upAxis), upAxis, -forward):Inverse()

	local nativeLen = barrelAxis:Dot(ms)
	local scale = AWP_TARGET_LEN / nativeLen

	-- Sauberer Template-Klon für den Builder (Skins klonen DIESEN MeshPart —
	-- nur so funktionieren die prozeduralen Skin-Texturen via TextureContent)
	local template = mp:Clone()
	template:ClearAllChildren()
	template.Anchored = false
	template.CanCollide = false
	template.Massless = true
	template.CastShadow = false
	template.Transparency = 0

	SniperBuilder.setAwpInfo({
		template   = template,
		nativeSize = ms,
		meshId     = mp.MeshId,
		textureId  = mp.TextureID,
		scale      = scale,
		rot        = rot,
		length     = AWP_TARGET_LEN,
		height     = upAxis:Dot(ms) * scale,
	})
	print(("[WeaponService] Echtes AWP aktiv (Mesh %s, %.1f Studs nativ)")
		:format(mp.MeshId, nativeLen))
	return true
end

local function trySetupAwpTemplate()
	local assets = RS:FindFirstChild("Assets")
	local tpl = assets and assets:FindFirstChild("Awp")
	if not tpl then return false end
	local mp = tpl:IsA("MeshPart") and tpl or tpl:FindFirstChildWhichIsA("MeshPart", true)
	return setupFromMeshPart(mp)
end

local function trySetupAwpFromStore()
	local InsertService = game:GetService("InsertService")
	for _, assetId in ipairs(AWP_STORE_IDS) do
		local ok, asset = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and asset then
			local mp = asset:FindFirstChildWhichIsA("MeshPart", true)
			local done = mp and setupFromMeshPart(mp)
			asset:Destroy()
			if done then return true end
		end
	end
	return false
end

-- Reihenfolge: Template (falls vorhanden) → Auto-Load aus dem Store →
-- weiter beobachten (Template darf auch WÄHREND einer Session reingezogen
-- werden). Sobald aktiv: alle Waffen neu bauen.
local function watchForAwpTemplate()
	task.spawn(function()
		local hinted = false
		local storeTried = false
		while not SniperBuilder.hasAwpMesh() do
			pcall(trySetupAwpTemplate)

			if not SniperBuilder.hasAwpMesh() and not storeTried then
				storeTried = true
				pcall(trySetupAwpFromStore)
			end

			if SniperBuilder.hasAwpMesh() then
				for _, p in ipairs(Players:GetPlayers()) do
					if dataService.get(p) then
						WeaponService.giveWeapon(p)
					end
				end
				for _, p in ipairs(Players:GetPlayers()) do
					net.Notify:FireClient(p, "🔫 Echtes AWP-Modell aktiv!")
				end
				return
			end

			if not hinted then
				hinted = true
				task.delay(8, function()
					if SniperBuilder.hasAwpMesh() then return end
					for _, p in ipairs(Players:GetPlayers()) do
						net.Notify:FireClient(p,
							"💡 Echte AWP fehlt! Einzeiler aus SETUP.md in die Studio-Befehlsleiste kopieren")
					end
				end)
			end
			task.wait(5)
		end
	end)
end

-- ── Waffe geben (Lobby + Arena: der Skin ist immer sichtbar) ──────────────────
function WeaponService.giveWeapon(player)
	local data = dataService.get(player)
	if not data then return end
	local skin = Skins.BY_ID[data.equipped] or Skins.BY_ID.standard

	local char = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ char, bp }) do
		if container then
			local old = container:FindFirstChild("Sniper")
			if old then old:Destroy() end
		end
	end
	if not bp then return end

	local tool = SniperBuilder.buildTool(skin)
	tool.Parent = bp

	-- Charakter-Aura: Godly+ bekommt eine wirbelnde Skin-Aura, Prime goldenen
	-- Glanz dazu — der Status-Flex ist in der Lobby sofort sichtbar
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local old = root:FindFirstChild("FlexAura")
		if old then old:Destroy() end
		local att = Instance.new("Attachment")
		att.Name = "FlexAura"
		att.Position = Vector3.new(0, -1.5, 0)
		att.Parent = root

		local fx = Skins.fxFor(skin.tier)
		if fx.pulse then
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 14
			pe.Lifetime = NumberRange.new(0.8, 1.6)
			pe.Speed = NumberRange.new(1.5, 3)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.Size = NumberSequence.new(0.3)
			pe.Color = ColorSequence.new(skin.accent)
			pe.LightEmission = 1
			pe.Parent = att
		end
		if data.prime then
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 6
			pe.Lifetime = NumberRange.new(1, 2)
			pe.Speed = NumberRange.new(0.8, 1.6)
			pe.SpreadAngle = Vector2.new(20, 20)
			pe.Size = NumberSequence.new(0.22)
			pe.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90))
			pe.LightEmission = 1
			pe.Parent = att
		end
	end

	-- Auto-Equip
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		task.defer(function()
			if tool.Parent == bp then hum:EquipTool(tool) end
		end)
	end
end

-- ── Schuss ────────────────────────────────────────────────────────────────────
local function getEquippedTool(player)
	local char = player.Character
	return char and char:FindFirstChild("Sniper")
end

local function handleShoot(player, targetPos)
	if typeof(targetPos) ~= "Vector3" then return end

	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not head or not hum or hum.Health <= 0 then return end

	local tool = getEquippedTool(player)
	if not tool then return end

	-- Cooldown (server-seitig — Exploits zwecklos)
	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < Config.SHOT_COOLDOWN then return end
	lastShot[player] = now

	-- In der Lobby nur Show, in der Arena tödlich
	local inMatch = arenaService and arenaService.isInLiveMatch(player)
	if not inMatch and not Config.LOBBY_SHOOTING then return end

	local origin = head.Position
	local dir = targetPos - origin
	if dir.Magnitude < 0.5 then return end
	dir = dir.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(origin, dir * Config.SHOT_RANGE, params)
	local hitPos = result and result.Position or (origin + dir * Config.SHOT_RANGE)

	-- Treffer-Auswertung (nur im Live-Match, nur gegen den Gegner)
	local victim = nil
	local killed = false
	local hitModel = nil
	if result then
		hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		victim = hitModel and Players:GetPlayerFromCharacter(hitModel)
	end

	-- Trainings-Bot getroffen?
	if hitModel and not victim and inMatch and CollectionService:HasTag(hitModel, "ArenaBot") then
		if arenaService.tryHitBot(player, hitModel) then
			killed = true
			local pdata = dataService.get(player)
			if pdata then pdata.kills += 1 end
			dataService.addCredits(player, Config.BOT_KILL_REWARD)
			net.PlaySFX:FireClient(player, "ChimeSoft", 0.5, 1.6)
		end
	end

	if victim and inMatch and arenaService.canDamage(player, victim) then
		local vChar = victim.Character
		local vHum  = vChar and vChar:FindFirstChildOfClass("Humanoid")
		if vHum and vHum.Health > 0 then
			vHum.Health = 0   -- One-Shot: 100% skill-basiert, kein Skin-Vorteil
			killed = true

			local pdata = dataService.get(player)
			if pdata then pdata.kills += 1 end
			dataService.addCredits(player, Config.KILL_REWARD)
			arenaService.onKill(player, victim)

			net.PlaySFX:FireClient(player, "ChimeSoft", 0.5, 1.6)  -- Hit-Bestätigung

			-- Godly+: der Schuss "verändert den Bildschirm des Gegners"
			local skin = Skins.BY_ID[tool:GetAttribute("SkinId")]
			if skin and Skins.fxFor(skin.tier).flash then
				net.ScreenFlash:FireClient(victim, skin.accent)
			end
		end
	end

	-- Tracer + Sound rendern die CLIENTS über ShotFired (AWP-Sound mit
	-- Fallback-Kette, Tier-Pitch, Distanz-Filter)
	local muzzle = tool:FindFirstChild("Muzzle")
	local beamFrom = muzzle and muzzle.Position or origin
	net.ShotFired:FireAllClients(beamFrom, hitPos, tool:GetAttribute("SkinId"), killed)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function WeaponService.init(ds, netRef)
	dataService = ds
	net         = netRef

	watchForAwpTemplate()

	net.Shoot.OnServerEvent:Connect(handleShoot)

	net.EquipSkin.OnServerEvent:Connect(function(player, skinId)
		if type(skinId) ~= "string" then return end
		local data = dataService.get(player)
		if not data then return end
		if not Skins.BY_ID[skinId] then return end
		if (data.skins[skinId] or 0) < 1 then
			net.Notify:FireClient(player, "Du besitzt diesen Skin nicht!")
			return
		end
		data.equipped = skinId
		dataService.sendUpdate(player)
		WeaponService.giveWeapon(player)
		net.PlaySFX:FireClient(player, "Magazine", 0.6)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)

	print("[WeaponService] bereit.")
end

return WeaponService
