-- WeaponController.lua — Schießen, Scope-Zoom, Slide, Mobile-Buttons
--
-- Regeln:
--  • Geschossen/gescoped wird NUR im Match (Lobby = Showroom für die Skins)
--  • Im Match herrscht Ego-Perspektive (kein 3rd-Person-Peeken um Deckungen)
--  • Slide: Ctrl/C im Lauf (Mobile: 🏃-Button) — Boost + geduckte Kamera
--
-- Desktop: Linksklick = Schuss (Hüfte: Cursor), Rechtsklick halten = Scope
-- Mobile:  FEUER-/SCOPE-/SLIDE-Buttons (nur im Match sichtbar); gezielt wird
--          über die Bildmitte
local WeaponController = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local RS               = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- Echtes Touch-Gerät (Tablet/Handy) — nicht nur Touchscreen-Laptop
local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local net      = nil
local effects  = nil
local uiCtrl   = nil

local inMatch    = false
local lastShot   = 0
local scoped     = false
local touchGui   = nil
local BASE_FOV   = 70
local SCOPE_FOV  = isTouch and 24 or 16   -- Mobile etwas weniger Zoom (Touch-Look skaliert nicht mit)

-- Waffe im Scope lokal ausblenden (CS-Style: man sieht nur das Scope-Bild)
local function setWeaponHidden(hidden)
	local char = player.Character
	local tool = char and char:FindFirstChild("Sniper")
	if not tool then return end
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- Kamera-Modus: im Match IMMER Ego (kein 3rd-Person-Peek um Deckungen)
local function applyCameraMode()
	pcall(function()
		player.CameraMode = (inMatch or scoped)
			and Enum.CameraMode.LockFirstPerson
			or Enum.CameraMode.Classic
	end)
end

-- ── Scope ─────────────────────────────────────────────────────────────────────
local function setScoped(state)
	if scoped == state then return end
	if state and not inMatch then return end   -- Scopen nur im Match
	scoped = state
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			FieldOfView = state and SCOPE_FOV or BASE_FOV,
		}):Play()
	end
	if uiCtrl then uiCtrl.setScopeVisible(state) end
	setWeaponHidden(state)
	applyCameraMode()

	-- Anti-Zappeln: Maus-Empfindlichkeit auf das FOV runterskalieren
	pcall(function()
		UserInputService.MouseDeltaSensitivity = state and (SCOPE_FOV / BASE_FOV) or 1
	end)

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = state and 8 or 16   -- im Scope langsamer (Skill-Tradeoff)
	end
end

-- ── Schuss ────────────────────────────────────────────────────────────────────
local function hasWeaponEquipped()
	local char = player.Character
	return char and char:FindFirstChild("Sniper") ~= nil
end

-- Zielpunkt: im Scope/auf Mobile durch die Bildmitte (Fadenkreuz), sonst Cursor
local function getTargetPos()
	local camera = workspace.CurrentCamera
	if (scoped or isTouch) and camera then
		local origin = camera.CFrame.Position
		local dir = camera.CFrame.LookVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local hit = workspace:Raycast(origin, dir * Config.SHOT_RANGE, params)
		return hit and hit.Position or (origin + dir * Config.SHOT_RANGE)
	end
	return mouse.Hit.Position
end

local function shoot()
	if not inMatch then return end   -- in der Overworld wird nicht gesnipet
	if not net or not hasWeaponEquipped() then return end
	local now = os.clock()
	if now - lastShot < Config.SHOT_COOLDOWN then return end
	lastShot = now

	net.Shoot:FireServer(getTargetPos())
	effects.shake(scoped and 0.2 or 0.45)
	if uiCtrl then uiCtrl.startCooldownBar(Config.SHOT_COOLDOWN) end
end

-- ── Slide (Ctrl/C im Lauf — Movement-Skill, überall erlaubt) ──────────────────
local lastSlide = 0

local function doSlide()
	local now = os.clock()
	if now - lastSlide < Config.SLIDE_COOLDOWN then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	if hum.FloorMaterial == Enum.Material.Air then return end   -- nur am Boden
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.2 then return end                      -- nur im Lauf
	lastSlide = now

	-- Boost in Bewegungsrichtung
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = dir.Unit * Config.SLIDE_SPEED
	lv.Parent = root
	Debris:AddItem(lv, Config.SLIDE_TIME)
	Debris:AddItem(att, Config.SLIDE_TIME + 0.1)

	-- Geduckte Kamera + kleiner FOV-Punch = Speed-Gefühl
	TweenService:Create(hum, TweenInfo.new(0.1), { CameraOffset = Vector3.new(0, -1.6, 0) }):Play()
	local camera = workspace.CurrentCamera
	if camera and not scoped then
		TweenService:Create(camera, TweenInfo.new(0.12), { FieldOfView = BASE_FOV + 8 }):Play()
	end
	Assets.play2D(Assets.SFX.Whoosh, 0.55, 0.85)

	task.delay(Config.SLIDE_TIME, function()
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			TweenService:Create(h, TweenInfo.new(0.18), { CameraOffset = Vector3.new(0, 0, 0) }):Play()
		end
		local cam = workspace.CurrentCamera
		if cam and not scoped then
			TweenService:Create(cam, TweenInfo.new(0.18), { FieldOfView = BASE_FOV }):Play()
		end
	end)
end

-- ── Mobile-Buttons (FEUER + SCOPE + SLIDE) ────────────────────────────────────
local function buildTouchControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchWeaponControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false   -- nur im Match sichtbar
	gui.Parent = player:WaitForChild("PlayerGui")

	local function roundButton(text, size, pos)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, size, 0, size)
		b.Position = pos
		b.AnchorPoint = Vector2.new(1, 1)
		b.BackgroundColor3 = Color3.fromRGB(25, 27, 42)
		b.BackgroundTransparency = 0.25
		b.Text = text
		b.TextSize = math.floor(size * 0.45)
		b.TextColor3 = Color3.fromRGB(235, 238, 250)
		b.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(150, 80, 255)
		s.Thickness = 2
		s.Parent = b
		b.Parent = gui
		return b
	end

	-- FEUER: groß, da wo der Daumen liegt (über dem Sprung-Button)
	local fireBtn = roundButton("🔫", 96, UDim2.new(1, -24, 1, -150))
	fireBtn.Activated:Connect(shoot)

	-- SCOPE: Toggle daneben
	local scopeBtn = roundButton("⊕", 72, UDim2.new(1, -136, 1, -180))
	scopeBtn.Activated:Connect(function()
		setScoped(not scoped)
		scopeBtn.BackgroundColor3 = scoped and Color3.fromRGB(150, 80, 255) or Color3.fromRGB(25, 27, 42)
	end)

	-- SLIDE
	local slideBtn = roundButton("🏃", 64, UDim2.new(1, -222, 1, -130))
	slideBtn.Activated:Connect(doSlide)

	touchGui = gui
end

-- ── Match-Status (vom Client-Entry bei MatchState gesetzt) ────────────────────
function WeaponController.setInMatch(state)
	if inMatch == state then return end
	inMatch = state
	if not state then
		setScoped(false)
	end
	applyCameraMode()
	if touchGui then
		touchGui.Enabled = state
	end
	if uiCtrl and uiCtrl.setCombatVisible then
		uiCtrl.setCombatVisible(state)
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function WeaponController.init(netRef, effectsCtrl, uiController)
	net     = netRef
	effects = effectsCtrl
	uiCtrl  = uiController

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not isTouch then
			shoot()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setScoped(true)
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			doSlide()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setScoped(false)
		end
	end)

	if isTouch then
		buildTouchControls()
	end

	-- Scope/Kamera beim Tod/Respawn zurücksetzen (Match-Status bleibt)
	player.CharacterAdded:Connect(function()
		scoped = false
		pcall(function()
			UserInputService.MouseDeltaSensitivity = 1
		end)
		if uiCtrl then uiCtrl.setScopeVisible(false) end
		applyCameraMode()
	end)
end

return WeaponController
