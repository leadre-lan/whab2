-- WeaponService.lua — Server-autoritatives Schießen + Skin-Equip.
-- Schaden ist IMMER gleich (One-Shot, fixer Cooldown) — Skins sind reine Optik.
local WeaponService = {}

local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local InsertService     = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")

local Config        = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins         = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))
local SniperBuilder = require(RS:WaitForChild("Shared"):WaitForChild("SniperBuilder"))

-- ── AWP-Mesh laden + vermessen ────────────────────────────────────────────────
-- Das Creator-Store-Asset wird einmal geladen; danach wird die Lauf-Achse
-- bestimmt: längste Achse = Lauf, und per Raycast-Probe (Trefferdichte an
-- beiden Enden) die Mündungsrichtung — der Schaft ist massiv, der Lauf dünn.
local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

local function probeEndHits(meshPart, axis, sign, otherA, otherB)
	local s = meshPart.Size
	local center = meshPart.Position + axis * ((axis:Dot(s) * 0.4) * sign)
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

local function loadWeaponMesh()
	for _, assetId in ipairs({ Config.WEAPON_MESH_ASSET, Config.WEAPON_ALT_ASSET }) do
		local ok, asset = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and asset then
			local mp = asset:FindFirstChildWhichIsA("MeshPart", true)
			if mp then
				mp.Parent = nil
				asset:Destroy()

				-- Achsen nach Größe sortieren: längste = Lauf, zweite = Höhe
				local s = mp.Size
				local sorted = table.clone(AXES)
				table.sort(sorted, function(a, b) return a:Dot(s) > b:Dot(s) end)
				local barrelAxis, upAxis = sorted[1], sorted[2]

				-- Probe: Modell hoch über der Map platzieren und beide
				-- Lauf-Enden von oben abtasten — das dünne Ende ist die Mündung
				mp.Anchored = true
				mp.CanCollide = false
				mp.CFrame = CFrame.new(0, 2800, 0)
				mp.Parent = workspace
				local hitsPos = probeEndHits(mp, barrelAxis, 1, upAxis, sorted[3])
				local hitsNeg = probeEndHits(mp, barrelAxis, -1, upAxis, sorted[3])
				mp.Parent = nil

				local muzzleSign = (hitsPos < hitsNeg) and 1 or -1
				if Config.WEAPON_FLIP then muzzleSign = -muzzleSign end
				local forward = barrelAxis * muzzleSign
				local up = Config.WEAPON_UPSIDE and -upAxis or upAxis

				-- Rotation, die Mesh-Achsen auf Handle-Achsen abbildet
				-- (Mündung → -Z, Oberseite → +Y)
				local rot = CFrame.fromMatrix(Vector3.zero, forward:Cross(up), up, -forward):Inverse()

				local length = barrelAxis:Dot(s)
				local scale = Config.WEAPON_LENGTH / length

				mp.Anchored = false
				mp.Massless = true
				mp.CastShadow = false

				SniperBuilder.setMeshInfo({
					template = mp,
					rot      = rot,
					scale    = scale,
					length   = Config.WEAPON_LENGTH,
				})
				print(("[WeaponService] AWP-Mesh %d geladen (%.1f Studs nativ, Mündung %s%s)")
					:format(assetId, length, muzzleSign > 0 and "+" or "-",
						barrelAxis.X > 0.5 and "X" or (barrelAxis.Y > 0.5 and "Y" or "Z")))
				return
			end
			asset:Destroy()
		end
	end
	warn("[WeaponService] AWP-Asset nicht ladbar — nutze prozedurales Modell.")
end

local dataService  = nil
local arenaService = nil
local net          = nil

local lastShot = {}   -- [player] = os.clock()

function WeaponService.setArenaService(svc)
	arenaService = svc
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

	-- AWP-Mesh asynchron laden; danach bekommen alle ihre Waffe neu (upgraded)
	task.spawn(function()
		loadWeaponMesh()
		if SniperBuilder.hasMesh() then
			for _, p in ipairs(Players:GetPlayers()) do
				if dataService.get(p) then
					WeaponService.giveWeapon(p)
				end
			end
		end
	end)

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
