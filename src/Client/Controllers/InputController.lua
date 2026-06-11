-- InputController.lua — Sword building, input, swing animation, slam detection
local InputController = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RS               = game:GetService("ReplicatedStorage")

local Layers = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- Sword tier visual configs (name, bladeColor, gripColor, handleColor, neon on tier>=5, trail on tier>=8)
local TIER_SWORD = {
	[1]  = { name = "Holzschwert",       blade = Color3.fromRGB(180, 130, 70),  grip = Color3.fromRGB(35, 28, 18) },
	[2]  = { name = "Steinschwert",      blade = Color3.fromRGB(155, 158, 162), grip = Color3.fromRGB(45, 42, 42) },
	[3]  = { name = "Eisenschwert",      blade = Color3.fromRGB(200, 212, 222), grip = Color3.fromRGB(38, 40, 50) },
	[4]  = { name = "Goldschwert",       blade = Color3.fromRGB(240, 198, 48),  grip = Color3.fromRGB(50, 40, 15) },
	[5]  = { name = "Diamantschwert",    blade = Color3.fromRGB(80, 222, 232),  grip = Color3.fromRGB(22, 42, 50) },
	[6]  = { name = "Rubin Klinge",      blade = Color3.fromRGB(222, 48, 68),   grip = Color3.fromRGB(50, 15, 20) },
	[7]  = { name = "Smaragdklinge",     blade = Color3.fromRGB(48, 202, 98),   grip = Color3.fromRGB(15, 45, 22) },
	[8]  = { name = "Mondklinge",        blade = Color3.fromRGB(180, 158, 242), grip = Color3.fromRGB(30, 22, 50) },
	[9]  = { name = "Sonnenklinge",      blade = Color3.fromRGB(255, 178, 48),  grip = Color3.fromRGB(50, 38, 10) },
	[10] = { name = "Legendäre Klinge",  blade = Color3.fromRGB(255, 78, 202),  grip = Color3.fromRGB(50, 15, 42) },
}

local currentTool = nil
local swinging    = false
local net         = nil
local effects     = nil
local uiCtrl      = nil

-- ── Sword Builder ─────────────────────────────────────────────────────────────
local function attachPart(handle, part, offset)
	part.Anchored  = false
	part.CanCollide = false
	part.Massless  = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = part
	part.CFrame = handle.CFrame * offset
	part.Parent = handle.Parent
end

function InputController.buildSword(tier)
	local def = TIER_SWORD[tier] or TIER_SWORD[1]

	-- Clear existing sword
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		local old = bp:FindFirstChild("Sword")
		if old then old:Destroy() end
	end
	local char = player.Character
	if char then
		local old = char:FindFirstChild("Sword")
		if old then old:Destroy() end
	end

	local tool = Instance.new("Tool")
	tool.Name  = "Sword"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false
	tool.ToolTip        = def.name
	tool.GripPos     = Vector3.new(0, -0.3, 0)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)

	-- Handle / grip
	local handle = Instance.new("Part")
	handle.Name  = "Handle"
	handle.Size  = Vector3.new(0.25, 1.35, 0.25)
	handle.Material = Enum.Material.Fabric
	handle.Color = def.grip
	handle.CanCollide = false
	handle.Parent = tool

	-- Grip accent rings
	for i = 1, 2 do
		local ring = Instance.new("Part")
		ring.Size  = Vector3.new(0.29, 0.09, 0.29)
		ring.Material = Enum.Material.Fabric
		ring.Color = def.blade
		attachPart(handle, ring,
			CFrame.new(0, -0.44 + (i - 1) * 0.56, 0) * CFrame.Angles(0, 0, math.rad(18)))
	end

	-- Tsuba (guard)
	local tsuba = Instance.new("Part")
	tsuba.Shape  = Enum.PartType.Cylinder
	tsuba.Size   = Vector3.new(0.16, 0.92, 0.92)
	tsuba.Material = Enum.Material.Metal
	tsuba.Color  = Color3.fromRGB(210, 172, 52)
	attachPart(handle, tsuba, CFrame.new(0, 0.74, 0) * CFrame.Angles(0, 0, math.rad(90)))

	-- Blade
	local bladeColor = Color3.fromRGB(218, 224, 235):Lerp(def.blade, 0.35)
	local blade = Instance.new("Part")
	blade.Name  = "Blade"
	blade.Size  = Vector3.new(0.12, 3.2, 0.48)
	blade.Material = Enum.Material.Metal
	blade.Color = bladeColor
	attachPart(handle, blade, CFrame.new(0, 2.46, 0) * CFrame.Angles(0, 0, math.rad(4)))

	local edge = Instance.new("Part")
	edge.Size  = Vector3.new(0.13, 3.2, 0.11)
	edge.Material = Enum.Material.Metal
	edge.Color = Color3.fromRGB(248, 250, 255)
	attachPart(handle, edge, CFrame.new(0, 2.46, -0.22) * CFrame.Angles(0, 0, math.rad(4)))

	local tip = Instance.new("WedgePart")
	tip.Name  = "Tip"
	tip.Size  = Vector3.new(0.12, 0.52, 0.48)
	tip.Material = Enum.Material.Metal
	tip.Color = bladeColor
	attachPart(handle, tip, CFrame.new(-0.28, 4.19, 0) * CFrame.Angles(0, 0, math.rad(4)))

	-- Tier >= 5: neon + glow
	if tier >= 5 then
		blade.Material = Enum.Material.Neon
		blade.Color    = def.blade
		edge.Material  = Enum.Material.Neon
		edge.Color     = def.blade
		tip.Material   = Enum.Material.Neon
		tip.Color      = def.blade
		local light = Instance.new("PointLight")
		light.Color  = def.blade
		light.Range  = 9
		light.Brightness = 1.5
		light.Parent = blade
	end

	-- Tier >= 8: trail
	if tier >= 8 then
		local a0 = Instance.new("Attachment")
		a0.Name  = "TrailBottom"
		a0.Position = Vector3.new(0, -1.6, 0)
		a0.Parent = blade

		local a1 = Instance.new("Attachment")
		a1.Name  = "TrailTop"
		a1.Position = Vector3.new(0, 1.6, 0)
		a1.Parent = blade

		local trail = Instance.new("Trail")
		trail.Attachment0    = a0
		trail.Attachment1    = a1
		trail.Color          = ColorSequence.new(def.blade)
		trail.Lifetime       = 0.26
		trail.LightEmission  = 0.85
		trail.Transparency   = NumberSequence.new(0.2, 1)
		trail.Enabled        = false
		trail.Parent         = blade
	end

	-- Swing sound
	local swingSnd = Instance.new("Sound")
	swingSnd.Name  = "SwingSound"
	swingSnd.SoundId = "rbxasset://sounds/swordslash.wav"
	swingSnd.Volume  = 0.65
	swingSnd.Parent  = handle

	local slamSnd = Instance.new("Sound")
	slamSnd.Name  = "SlamSound"
	slamSnd.SoundId = "rbxasset://sounds/swordslash.wav"
	slamSnd.Volume  = 1.1
	slamSnd.PlaybackSpeed = 0.5
	slamSnd.Parent  = handle

	currentTool = tool
	if bp then tool.Parent = bp end
end

-- ── Auto-Equip ────────────────────────────────────────────────────────────────
function InputController.autoEquip()
	local char = player.Character
	if not char then return end
	if char:FindFirstChild("Sword") then return end
	local bp  = player:FindFirstChildOfClass("Backpack")
	local sw  = bp and bp:FindFirstChild("Sword")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if sw and hum then hum:EquipTool(sw) end
end

-- ── Find nearest bamboo/rock hitbox ──────────────────────────────────────────
local function findNearestHitbox(maxDist)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local zones = workspace:FindFirstChild("Zones")
	if not zones then return nil end

	local best, bestDist = nil, maxDist
	for _, desc in ipairs(zones:GetDescendants()) do
		if desc:IsA("BasePart")
			and (desc:GetAttribute("IsBamboo") or desc:GetAttribute("IsRock"))
			and not desc:GetAttribute("IsDead") then
			local d = (desc.Position - root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = desc
			end
		end
	end
	return best
end

-- ── Swing Animation ───────────────────────────────────────────────────────────
local function swingSword(isSlam)
	if swinging or not net then return end
	local tool = currentTool
	local char = player.Character
	if not tool or not char or tool.Parent ~= char then return end

	swinging = true

	local toolBlade  = tool:FindFirstChild("Blade")
	local swingTrail = toolBlade and toolBlade:FindFirstChild("SwingTrail")
	if swingTrail then swingTrail.Enabled = true end

	local handle = tool:FindFirstChild("Handle")
	if isSlam then
		local snd = handle and handle:FindFirstChild("SlamSound")
		if snd then snd:Play() end
	else
		local snd = handle and handle:FindFirstChild("SwingSound")
		if snd then
			snd.PlaybackSpeed = 1.28 + math.random() * 0.32
			snd:Play()
		end
	end

	-- Slash arc
	if effects then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local bladeColor = toolBlade and toolBlade.Color or Color3.fromRGB(255, 255, 255)
			effects.spawnSlashArc(root.CFrame, bladeColor)
		end
	end

	-- Target priority: monster/player under mouse → bamboo/rock under mouse → nearest
	local target = nil
	local entityTarget = nil   -- monster Model or player Character
	local mt = mouse.Target
	if mt then
		if mt:GetAttribute("IsBamboo") or mt:GetAttribute("IsRock") then
			target = mt
		else
			-- Monster? (Body part carries IsMonster attribute)
			local model = mt:FindFirstAncestorOfClass("Model")
			if model then
				local prim = model.PrimaryPart
				if prim and prim:GetAttribute("IsMonster") then
					entityTarget = model
				elseif Players:GetPlayerFromCharacter(model) and model ~= char then
					entityTarget = model
				end
			end
		end
	end
	if not target and not entityTarget then
		-- Nearest monster within melee range, else nearest bamboo/rock
		local root = char:FindFirstChild("HumanoidRootPart")
		local monstersF = workspace:FindFirstChild("Monsters")
		if root and monstersF then
			local bestD = 12
			for _, m in ipairs(monstersF:GetDescendants()) do
				if m:IsA("Model") and m.PrimaryPart and m.PrimaryPart:GetAttribute("IsMonster") then
					local d = (m.PrimaryPart.Position - root.Position).Magnitude
					if d < bestD then
						bestD = d
						entityTarget = m
					end
				end
			end
		end
		if not entityTarget then
			target = findNearestHitbox(isSlam and 10 or 15)
		end
	end

	if isSlam then
		net.SlamAttack:FireServer()
		if effects then effects.shake(2.6) end
		if uiCtrl then uiCtrl.showSlamText() end
	elseif entityTarget then
		net.AttackEntity:FireServer(entityTarget)
	elseif target then
		net.ChopTarget:FireServer(target)
	end

	-- Animate
	local origGrip = tool.Grip
	if isSlam then
		for s = 1, 6 do
			tool.Grip = origGrip * CFrame.Angles(math.rad(-155 * s / 6), 0, 0)
			task.wait(0.012)
		end
		task.wait(0.055)
		if toolBlade then
			local oc = toolBlade.Color
			toolBlade.Color = Color3.fromRGB(255, 255, 255)
			task.wait(0.016)
			toolBlade.Color = oc
		end
		for s = 5, 0, -1 do
			tool.Grip = origGrip * CFrame.Angles(math.rad(-155 * s / 6), 0, 0)
			task.wait(0.024)
		end
	else
		for s = 1, 4 do
			tool.Grip = origGrip * CFrame.Angles(math.rad(-132 * s / 4), 0, 0)
			task.wait(0.008)
		end
		task.wait(0.015)
		if toolBlade then
			local oc = toolBlade.Color
			toolBlade.Color = Color3.fromRGB(255, 255, 255)
			task.wait(0.016)
			toolBlade.Color = oc
		end
		for s = 3, 0, -1 do
			tool.Grip = origGrip * CFrame.Angles(math.rad(-132 * s / 4), 0, 0)
			task.wait(0.018)
		end
	end

	tool.Grip = origGrip
	if swingTrail then swingTrail.Enabled = false end
	swinging = false
end

-- ── Dash (Q) ─────────────────────────────────────────────────────────────────
local lastDash = 0
local dashCooldown = 3.0   -- reduced by Ausweichen stat (updated via setDodgeLevel)

function InputController.setDodgeLevel(lvl)
	dashCooldown = math.max(0.8, 3.0 - (lvl or 0) * 0.25)
end

local function doDash()
	local now = os.clock()
	if now - lastDash < dashCooldown then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	lastDash = now

	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit

	-- Velocity burst + afterimages
	local bv = Instance.new("LinearVelocity")
	local att = Instance.new("Attachment")
	att.Parent = root
	bv.Attachment0 = att
	bv.MaxForce = 1e6
	bv.VectorVelocity = dir * 70
	bv.Parent = root
	game:GetService("Debris"):AddItem(bv, 0.22)
	game:GetService("Debris"):AddItem(att, 0.25)

	-- Afterimage ghosts
	task.spawn(function()
		for _ = 1, 4 do
			local ghost = Instance.new("Part")
			ghost.Size = Vector3.new(2, 5, 1)
			ghost.CFrame = root.CFrame
			ghost.Material = Enum.Material.Neon
			ghost.Color = Color3.fromRGB(160, 220, 255)
			ghost.Transparency = 0.55
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.Parent = workspace
			TweenService:Create(ghost, TweenInfo.new(0.3),
				{ Transparency = 1 }):Play()
			game:GetService("Debris"):AddItem(ghost, 0.35)
			task.wait(0.05)
		end
	end)
end

-- ── Block (hold F) ────────────────────────────────────────────────────────────
local blocking = false
local blockGui = nil

local function setBlocking(state)
	if blocking == state then return end
	blocking = state
	net.SetBlocking:FireServer(state)

	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = state and 6 or 16
	end

	-- Blue shield tint indicator
	if state then
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			blockGui = Instance.new("Part")
			blockGui.Shape = Enum.PartType.Ball
			blockGui.Size = Vector3.new(7, 7, 7)
			blockGui.Material = Enum.Material.ForceField
			blockGui.Color = Color3.fromRGB(90, 160, 255)
			blockGui.Anchored = false
			blockGui.CanCollide = false
			blockGui.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = blockGui
			w.Parent = blockGui
			blockGui.CFrame = root.CFrame
			blockGui.Parent = char
		end
	elseif blockGui then
		blockGui:Destroy()
		blockGui = nil
	end
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function InputController.init(netRef, effectsCtrl, uiController)
	net     = netRef
	effects = effectsCtrl
	uiCtrl  = uiController

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root.AssemblyLinearVelocity.Y < -5 then
				swingSword(true)
			else
				swingSword(false)
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			doDash()
		elseif input.KeyCode == Enum.KeyCode.F then
			setBlocking(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			setBlocking(false)
		end
	end)
end

return InputController
