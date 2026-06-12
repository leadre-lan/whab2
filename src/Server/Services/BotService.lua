-- BotService.lua — Trainings-Bot für 1v1: R6-Rig, Sniper, simple Duell-KI.
-- Die KI ist bewusst fair lesbar: Sichtkontakt → Ziel-Zeit (Reaktion) → Schuss
-- mit fester Trefferchance; dazwischen Positionswechsel zwischen Deckungen.
local BotService = {}

local RS                = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local Config        = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins         = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))
local SniperBuilder = require(RS:WaitForChild("Shared"):WaitForChild("SniperBuilder"))

local net = nil
local rng = Random.new()

-- ── R6-Rig ────────────────────────────────────────────────────────────────────
local BODY  = Color3.fromRGB(38, 40, 56)
local VISOR = Color3.fromRGB(255, 70, 90)

local function bodyPart(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function motor(name, p0, p1, c0, c1, parent)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = parent
end

local function buildRig(spawnCF, name, visorColor)
	local model = Instance.new("Model")
	model.Name = name or Config.BOT_NAME

	local hrp = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), BODY, model)
	hrp.Transparency = 1
	hrp.CanCollide = false

	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), BODY, model)
	local head  = bodyPart("Head", Vector3.new(1.6, 1.2, 1.2), BODY:Lerp(Color3.new(1, 1, 1), 0.08), model)
	-- Neon-Visier (liest sich sofort als "Bot") — erst positionieren, DANN
	-- welden, sonst übernimmt der Weld den falschen Versatz
	local visor = bodyPart("Visor", Vector3.new(1.2, 0.32, 0.2), visorColor or VISOR, model)
	visor.Material = Enum.Material.Neon
	visor.CFrame = head.CFrame * CFrame.new(0, 0.05, -0.55)
	local visorWeld = Instance.new("WeldConstraint")
	visorWeld.Part0 = head
	visorWeld.Part1 = visor
	visorWeld.Parent = visor

	local lArm = bodyPart("Left Arm",  Vector3.new(1, 2, 1), BODY:Lerp(Color3.new(0, 0, 0), 0.2), model)
	local rArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), BODY:Lerp(Color3.new(0, 0, 0), 0.2), model)
	local lLeg = bodyPart("Left Leg",  Vector3.new(1, 2, 1), BODY:Lerp(Color3.new(0, 0, 0), 0.35), model)
	local rLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), BODY:Lerp(Color3.new(0, 0, 0), 0.35), model)
	lLeg.CanCollide = true
	rLeg.CanCollide = true
	torso.CanCollide = true

	motor("RootJoint", hrp, torso, CFrame.new(), CFrame.new(), hrp)
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0), torso)
	motor("Left Shoulder",  torso, lArm, CFrame.new(-1, 0.5, 0),  CFrame.new(0.5, 0.5, 0), torso)
	motor("Right Shoulder", torso, rArm, CFrame.new(1, 0.5, 0),   CFrame.new(-0.5, 0.5, 0), torso)
	motor("Left Hip",  torso, lLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0), torso)
	motor("Right Hip", torso, rLeg, CFrame.new(0.5, -1, 0),  CFrame.new(0, 1, 0), torso)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = 13
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	-- Name + HP-frei: eigener Tag über dem Kopf
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 130, 0, 26)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.MaxDistance = 200
	bb.Parent = head
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = visorColor or VISOR
	tl.TextStrokeTransparency = 0.2
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = name or Config.BOT_NAME
	tl.Parent = bb

	CollectionService:AddTag(model, "ArenaBot")
	model.PrimaryPart = hrp
	model:PivotTo(spawnCF)
	return model, hum, head
end

-- ── Public: Kampf-Bot spawnen ─────────────────────────────────────────────────
-- opts = {
--   spawnCF     = CFrame,
--   name        = string?,            -- Anzeigename ("[T] Bot 2", …)
--   visorColor  = Color3?,            -- Team-Farbe des Visiers
--   shouldAct   = function() -> bool, -- Runde live?
--   acquire     = function() -> { head = BasePart, applyHit = function() } | nil,
--                                     -- nächstes FEINDziel (Spieler ODER Bot)
--   route       = { Vector3, ... }?,  -- wird einmal abgelaufen (Objective)
--   loiter      = { Vector3, ... }?,  -- danach/sonst: Patrouille
--   onRouteDone = function(bot)?,     -- z.B. Bombe legen/entschärfen
-- }
-- bot = { model, alive, kill(), destroy(), setRoute(route, onDone) }
function BotService.spawn(opts)
	local model, hum, head = buildRig(opts.spawnCF, opts.name, opts.visorColor)
	model.Parent = workspace

	-- Sniper in die Hand (Standard-Skin — der Bot flext nicht)
	local tool = SniperBuilder.buildTool(Skins.BY_ID.standard)
	tool.Parent = model
	hum:EquipTool(tool)

	local bot = { model = model, alive = true }

	local route = opts.route and table.clone(opts.route) or nil
	local routeIdx = 1
	local routeDone = opts.onRouteDone
	local routeFinished = (route == nil)

	-- Neues Ziel/neue Route von außen (z.B. CT-Bot → Bombe entschärfen)
	function bot.setRoute(newRoute, onDone)
		route = table.clone(newRoute)
		routeIdx = 1
		routeDone = onDone
		routeFinished = false
	end

	-- Tod: Joints lösen, Teile verstreuen, Modell entsorgen
	function bot.kill()
		if not bot.alive then return end
		bot.alive = false
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") or d:IsA("WeldConstraint") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = true
				d.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(8, 20), rng:NextNumber(-12, 12))
				TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(model, 1.4)
	end

	function bot.destroy()
		bot.alive = false
		model:Destroy()
	end

	-- ── KI-Loop ──
	task.spawn(function()
		local aimTime   = 0
		local reaction  = rng:NextNumber(Config.BOT_REACTION[1], Config.BOT_REACTION[2])
		local lastShot  = 0
		local nextMove  = 0
		local TICK      = 0.15

		local losParams = RaycastParams.new()
		losParams.FilterType = Enum.RaycastFilterType.Exclude

		while bot.alive and model.Parent do
			task.wait(TICK)
			if not opts.shouldAct() then
				aimTime = 0
				continue
			end
			if not head.Parent then continue end

			-- Ziel suchen (Spieler oder feindlicher Bot)
			local target = opts.acquire and opts.acquire() or nil
			local tHead = target and target.head
			if tHead and not tHead.Parent then
				target, tHead = nil, nil
			end

			-- Sichtkontakt?
			local sees = false
			if tHead then
				losParams.FilterDescendantsInstances = { model }
				local toTarget = tHead.Position - head.Position
				local hit = workspace:Raycast(head.Position, toTarget, losParams)
				sees = hit ~= nil and hit.Instance:IsDescendantOf(tHead.Parent)
			end

			-- ── Bewegung ──
			local now = os.clock()
			if sees then
				-- Stehen bleiben + zum Ziel drehen (Duell-Stellung)
				local hrp = model.PrimaryPart
				if hrp then
					hum:MoveTo(hrp.Position)
					local toTarget = tHead.Position - head.Position
					local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
					if flat.Magnitude > 0.5 then
						hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
					end
				end
				aimTime += TICK
			else
				aimTime = math.max(0, aimTime - TICK * 2)

				if not routeFinished and route then
					-- Objective-Route ablaufen
					local point = route[routeIdx]
					if point then
						local hrp = model.PrimaryPart
						if hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude < 5 then
							routeIdx += 1
							if routeIdx > #route then
								routeFinished = true
								if routeDone then
									task.spawn(routeDone, bot)
								end
							end
						else
							hum:MoveTo(point)
						end
					else
						routeFinished = true
					end
				elseif opts.loiter and #opts.loiter > 0 and now >= nextMove then
					nextMove = now + rng:NextNumber(Config.BOT_MOVE_EVERY[1], Config.BOT_MOVE_EVERY[2])
					hum:MoveTo(opts.loiter[rng:NextInteger(1, #opts.loiter)])
				end
			end

			-- ── Schuss ──
			if sees and aimTime >= reaction and now - lastShot >= Config.BOT_SHOT_CD then
				lastShot = now
				reaction = rng:NextNumber(Config.BOT_REACTION[1], Config.BOT_REACTION[2])
				aimTime = 0

				local hits = rng:NextNumber() < Config.BOT_ACCURACY
				local muzzle = tool:FindFirstChild("Muzzle")
				local fromPos = muzzle and muzzle.Position or head.Position
				local toPos
				if hits then
					toPos = tHead.Position
				else
					toPos = tHead.Position + Vector3.new(
						rng:NextNumber(-4, 4), rng:NextNumber(-1, 3), rng:NextNumber(-4, 4))
				end

				net.ShotFired:FireAllClients(fromPos, toPos, "standard", hits)
				if hits then
					task.spawn(target.applyHit)
				end
			end
		end
	end)

	return bot
end

function BotService.init(netRef)
	net = netRef
	print("[BotService] bereit.")
end

return BotService
