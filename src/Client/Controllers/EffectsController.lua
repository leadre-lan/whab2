-- EffectsController.lua — All juice: shake, fragments, numbers, slice, sounds
local EffectsController = {}

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Debris       = game:GetService("Debris")

local camera   = workspace.CurrentCamera
local shakeAmt = 0

-- ── Camera Shake ──────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
	if shakeAmt <= 0 then return end
	shakeAmt = math.max(0, shakeAmt - dt * shakeAmt * 6)
	camera.CFrame = camera.CFrame * CFrame.new(
		(math.random() - 0.5) * 2 * shakeAmt,
		(math.random() - 0.5) * 2 * shakeAmt,
		(math.random() - 0.5) * 2 * shakeAmt)
end)

function EffectsController.shake(intensity)
	shakeAmt = math.max(shakeAmt, intensity)
end

-- ── Flying Fragments ──────────────────────────────────────────────────────────
function EffectsController.spawnFragments(position, color, count)
	count = count or 4
	for _ = 1, count do
		local frag = Instance.new("Part")
		frag.Size   = Vector3.new(0.28, 0.28, 0.28)
		frag.Material = Enum.Material.SmoothPlastic
		frag.Color    = color or Color3.fromRGB(100, 180, 80)
		frag.Anchored = false
		frag.CanCollide = false
		frag.CastShadow = false
		frag.Position = position + Vector3.new(
			(math.random() - 0.5) * 2,
			math.random() * 1.5,
			(math.random() - 0.5) * 2)
		frag.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 26,
			math.random() * 22 + 8,
			(math.random() - 0.5) * 26)
		frag.Parent = workspace

		TweenService:Create(frag,
			TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = 1 }):Play()
		Debris:AddItem(frag, 0.7)
	end
end

-- ── Floating Damage Numbers ───────────────────────────────────────────────────
function EffectsController.spawnDamageNum(position, damage, isCrit)
	local part = Instance.new("Part")
	part.Size   = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = position + Vector3.new((math.random() - 0.5) * 2.5, 3.5, 0)
	part.Parent   = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size  = UDim2.new(0, isCrit and 96 or 70, 0, isCrit and 58 or 44)
	bb.AlwaysOnTop = true
	bb.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text  = isCrit and ("💥 " .. damage .. "!") or tostring(damage)
	lbl.TextColor3 = isCrit and Color3.fromRGB(255, 148, 32) or Color3.fromRGB(255, 255, 255)
	lbl.TextSize = isCrit and 28 or 20
	lbl.Font  = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.4
	lbl.Parent = bb

	TweenService:Create(part,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = part.Position + Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(lbl,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
	Debris:AddItem(part, 1.2)
end

-- ── Slash Arc ─────────────────────────────────────────────────────────────────
function EffectsController.spawnSlashArc(rootCFrame, color)
	local arc = Instance.new("Part")
	arc.Size   = Vector3.new(3.8, 0.06, 0.9)
	arc.Material = Enum.Material.Neon
	arc.Color    = color or Color3.fromRGB(255, 255, 255)
	arc.Transparency = 0.15
	arc.Anchored = true
	arc.CanCollide = false
	arc.CastShadow = false
	arc.CFrame = rootCFrame * CFrame.new(0, 0.6, -3.2) * CFrame.Angles(0, 0, math.rad(-32))
	arc.Parent = workspace

	TweenService:Create(arc,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }):Play()
	Debris:AddItem(arc, 0.18)
end

-- ── Falling Cut-Top Pieces ────────────────────────────────────────────────────
-- The felled stalk breaks into ALL of its segments — every swing shows a real
-- multi-cut, like slicing through with a sharp knife.
function EffectsController.spawnFallingTops(sliceInfo)
	if not sliceInfo then return end
	local pos   = sliceInfo.slicePos
	local color = sliceInfo.color or Color3.fromRGB(100, 180, 80)
	local th    = sliceInfo.thickness or 1.5
	local topH  = sliceInfo.topHeight or 10

	-- White slice flash at the cut plane
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(th * 3.5, 0.08, th * 3.5)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 255, 255)
	flash.Transparency = 0.1
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi, math.rad(math.random(-12, 12)))
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.16, Enum.EasingStyle.Quad),
		{ Transparency = 1, Size = flash.Size * 1.6 }):Play()
	Debris:AddItem(flash, 0.2)

	-- The cut piece breaks into its segments (1 piece per ~3 studs cut)
	local pieces = math.clamp(math.floor(topH / 3 + 0.5), 1, 7)
	local segLen = topH / pieces
	local baseY  = pos.Y - topH / 2
	for i = 1, pieces do
		local piece = Instance.new("Part")
		piece.Shape = Enum.PartType.Cylinder
		piece.Size  = Vector3.new(math.max(1, segLen - 0.15), th, th)
		piece.Material = Enum.Material.SmoothPlastic
		piece.Color    = color
		piece.Anchored = false
		piece.CanCollide = false
		piece.CastShadow = false
		piece.CFrame = CFrame.new(
				pos.X + (math.random() - 0.5) * 0.8,
				baseY + (i - 0.5) * segLen,
				pos.Z + (math.random() - 0.5) * 0.8)
			* CFrame.Angles(0, math.random() * math.pi, math.rad(90))
		local ang  = math.random() * math.pi * 2
		local kick = 8 + i * 2.5   -- higher pieces fly harder
		piece.AssemblyLinearVelocity = Vector3.new(
			math.cos(ang) * kick,
			6 + i * 2 + math.random() * 4,
			math.sin(ang) * kick)
		piece.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 24,
			(math.random() - 0.5) * 24,
			(math.random() - 0.5) * 24)
		piece.Parent = workspace

		TweenService:Create(piece,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }):Play()
		Debris:AddItem(piece, 1.3)
	end
end

-- ── Slice Sound ───────────────────────────────────────────────────────────────
function EffectsController.playSliceSound(position)
	local p = Instance.new("Part")
	p.Size  = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Position = position
	p.Parent   = workspace

	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/swordlunge.wav"
	s.Volume  = 1.0
	s.PlaybackSpeed = 1 + math.random() * 0.2
	s.Parent  = p
	s:Play()
	Debris:AddItem(p, 2)
end

-- ── Coin Magnet Popup ─────────────────────────────────────────────────────────
function EffectsController.spawnCoinPopup(screenGui, amount)
	if amount <= 0 then return end
	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(0, 180, 0, 38)
	lbl.Position = UDim2.new(0, 12, 0, 110)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 228, 55)
	lbl.TextSize = 24
	lbl.Font  = Enum.Font.GothamBold
	lbl.Text  = "+" .. amount .. " 🎋"
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 12
	lbl.Parent = screenGui

	TweenService:Create(lbl,
		TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 12, 0, 68), TextTransparency = 1 }):Play()
	Debris:AddItem(lbl, 1.4)
end

-- ── Level-Up Flash ────────────────────────────────────────────────────────────
function EffectsController.showLevelUp(screenGui, newLevel)
	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(0, 500, 0, 90)
	lbl.Position = UDim2.new(0.5, -250, 0.4, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 228, 55)
	lbl.TextSize = 62
	lbl.Font  = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.2
	lbl.Text  = "LEVEL " .. newLevel .. "! ⭐"
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.ZIndex = 25
	lbl.Parent = screenGui

	TweenService:Create(lbl,
		TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1, Position = UDim2.new(0.5, -250, 0.3, 0) }):Play()
	Debris:AddItem(lbl, 2)
end

-- ── Layer Unlock Flash ────────────────────────────────────────────────────────
function EffectsController.showLayerUnlocked(screenGui, layerName, layerColor)
	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(0, 560, 0, 80)
	lbl.Position = UDim2.new(0.5, -280, 0.35, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = layerColor or Color3.fromRGB(100, 210, 100)
	lbl.TextSize = 44
	lbl.Font  = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.25
	lbl.Text  = "🔓 " .. layerName .. " freigeschaltet!"
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.ZIndex = 25
	lbl.Parent = screenGui

	TweenService:Create(lbl,
		TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1, Position = UDim2.new(0.5, -280, 0.25, 0) }):Play()
	Debris:AddItem(lbl, 2.5)
end

return EffectsController
