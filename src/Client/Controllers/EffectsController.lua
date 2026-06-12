-- EffectsController.lua — Tracer, Screenflash, Godly-Puls, Ei-Schweben, Juice
local EffectsController = {}

local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local RS                = game:GetService("ReplicatedStorage")

local Skins  = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local shakeAmt = 0

-- ── Kamera-Shake ──────────────────────────────────────────────────────────────
-- CurrentCamera bei jedem Frame neu holen — die Instanz wechselt bei Respawns
RunService.RenderStepped:Connect(function(dt)
	if shakeAmt <= 0 then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	shakeAmt = math.max(0, shakeAmt - dt * shakeAmt * 6)
	camera.CFrame = camera.CFrame * CFrame.new(
		(math.random() - 0.5) * 2 * shakeAmt,
		(math.random() - 0.5) * 2 * shakeAmt,
		0)
end)

function EffectsController.shake(intensity)
	shakeAmt = math.max(shakeAmt, intensity)
end

-- ── Tracer (Beam zwischen Mündung und Einschlag, Skin-Farbe) ──────────────────
function EffectsController.spawnTracer(fromPos, toPos, skinId, didKill)
	-- Nur rendern, wenn es in der Nähe passiert
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - fromPos).Magnitude > 600 then return end

	local skin = Skins.BY_ID[skinId] or Skins.BY_ID.standard
	local fx = Skins.fxFor(skin.tier)

	local dist = (toPos - fromPos).Magnitude
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(fx.pulse and 0.22 or 0.1, fx.pulse and 0.22 or 0.1, dist)
	beam.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -dist / 2)
	beam.Material = Enum.Material.Neon
	beam.Color = fx.neon and skin.accent or Color3.fromRGB(255, 240, 200)
	beam.Transparency = 0.15
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.22), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.25)

	-- Einschlag-Funken
	local hitFx = Instance.new("Part")
	hitFx.Size = Vector3.new(0.4, 0.4, 0.4)
	hitFx.Position = toPos
	hitFx.Material = Enum.Material.Neon
	hitFx.Color = didKill and Color3.fromRGB(255, 70, 70) or beam.Color
	hitFx.Shape = Enum.PartType.Ball
	hitFx.Anchored = true
	hitFx.CanCollide = false
	hitFx.CanQuery = false
	hitFx.CastShadow = false
	hitFx.Parent = workspace
	TweenService:Create(hitFx, TweenInfo.new(0.3),
		{ Transparency = 1, Size = Vector3.new(2.4, 2.4, 2.4) }):Play()
	Debris:AddItem(hitFx, 0.35)
end

-- ── Schuss-Sound (AWP) ────────────────────────────────────────────────────────
-- Wenn ein echter CS-AWP-Sound geladen werden konnte (Assets.RESOLVED.Shot),
-- spielt er pur. Sonst wird der AWP-Knall aus garantierten Sounds GELAYERT:
-- Gewehr-Boom (Körper) + Deep-Boom (Bass-Wumms) + Whip-Crack (Knall-Tail).
-- Tier hebt Lautstärke/Pitch leicht an — Audio-Flex inklusive.
function EffectsController.playShotSound(fromPos, skinId)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - fromPos).Magnitude > 500 then return end

	local skin = Skins.BY_ID[skinId] or Skins.BY_ID.standard
	local order = Skins.TIERS[skin.tier].order

	if Assets.RESOLVED.Shot then
		Assets.playAt(fromPos, Assets.SFX.Shot,
			0.7 + order * 0.07,
			0.95 + order * 0.02, 1.0 + order * 0.02)
	else
		Assets.playAt(fromPos, Assets.SFX.GunBoom, 0.85 + order * 0.05, 0.8, 0.86)   -- Körper
		Assets.playAt(fromPos, Assets.SFX.Boom, 0.5 + order * 0.06, 1.2, 1.3)        -- Bass
		Assets.playAt(fromPos, Assets.SFX.Shot, 0.4, 1.0 + order * 0.04, 1.1)        -- Crack-Tail
	end

	-- Bolt-Zyklus kurz danach
	task.delay(0.45, function()
		Assets.playAt(fromPos, Assets.SFX.Bolt, 0.45, 0.95, 1.05)
	end)
end

-- ── Screenflash (Godly-Treffer "verändert den Bildschirm des Gegners") ────────
local flashGui = nil
function EffectsController.screenFlash(screenGui, color)
	if flashGui then flashGui:Destroy() end
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundColor3 = color or Color3.fromRGB(255, 60, 90)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = screenGui
	flashGui = f
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(f, 0.5)
	EffectsController.shake(1.6)
end

-- ── Godly/Mythical-Puls + Omega-Ei-Schweben (getaggte Parts, lokal animiert) ──
task.spawn(function()
	local t = 0
	local eggBase = {}   -- [part] = Y-Basis
	RunService.Heartbeat:Connect(function(dt)
		t += dt

		for _, p in ipairs(CollectionService:GetTagged("PulseFX")) do
			if p.Parent then
				local base = Color3.new(
					p:GetAttribute("PulseR") or 1,
					p:GetAttribute("PulseG") or 1,
					p:GetAttribute("PulseB") or 1)
				if p:GetAttribute("PulseRainbow") then
					p.Color = Color3.fromHSV((t * 0.25) % 1, 0.85, 1)
				else
					local pulse = 0.5 + 0.5 * math.sin(t * 4)
					p.Color = base:Lerp(Color3.fromRGB(255, 255, 255), pulse * 0.45)
				end
			end
		end

		for _, p in ipairs(CollectionService:GetTagged("EggFloat")) do
			if p.Parent and p.Anchored then
				if not eggBase[p] then eggBase[p] = p.Position.Y end
				local cf = p.CFrame
				p.CFrame = CFrame.new(cf.Position.X, eggBase[p] + math.sin(t * 1.2) * 0.6, cf.Position.Z)
					* CFrame.Angles(0, t * 0.35, 0)
			end
		end
	end)
end)

-- ── Hatch-Konfetti (beim Reveal seltener Skins) ───────────────────────────────
function EffectsController.confetti(screenGui, color, count)
	for _ = 1, count or 24 do
		local c = Instance.new("Frame")
		c.Size = UDim2.new(0, math.random(6, 12), 0, math.random(6, 12))
		c.Position = UDim2.new(math.random(), 0, -0.05, 0)
		c.BackgroundColor3 = (math.random() < 0.5) and color or Color3.fromHSV(math.random(), 0.8, 1)
		c.BorderSizePixel = 0
		c.Rotation = math.random(0, 360)
		c.ZIndex = 40
		c.Parent = screenGui
		TweenService:Create(c, TweenInfo.new(1.4 + math.random() * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = c.Rotation + math.random(-220, 220),
		}):Play()
		Debris:AddItem(c, 2.4)
	end
end

return EffectsController
