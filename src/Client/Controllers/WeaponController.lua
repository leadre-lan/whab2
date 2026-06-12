-- WeaponController.lua — Schießen, Scope-Zoom, Mobile-Buttons, Cooldown-UI
--
-- Desktop: Linksklick = Schuss (Hüfte: auf den Cursor), Rechtsklick halten = Scope
-- Mobile:  eigene FEUER-/SCOPE-Buttons (ein Tap aufs Display schießt NICHT —
--          sonst feuert jede Kamera-Drehung); gezielt wird über die Bildmitte
local WeaponController = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RS               = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- Echtes Touch-Gerät (Tablet/Handy) — nicht nur Touchscreen-Laptop
local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local net      = nil
local effects  = nil
local uiCtrl   = nil

local lastShot   = 0
local scoped     = false
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

-- ── Scope ─────────────────────────────────────────────────────────────────────
local function setScoped(state)
	if scoped == state then return end
	scoped = state
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			FieldOfView = state and SCOPE_FOV or BASE_FOV,
		}):Play()
	end
	if uiCtrl then uiCtrl.setScopeVisible(state) end
	setWeaponHidden(state)

	-- Anti-Zappeln: im Scope in die Ego-Sicht wechseln und die Maus-
	-- Empfindlichkeit auf das FOV runterskalieren — sonst ist 16° FOV bei
	-- voller Sensitivität unkontrollierbar
	pcall(function()
		player.CameraMode = state and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
	end)
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
	if not net or not hasWeaponEquipped() then return end
	local now = os.clock()
	if now - lastShot < Config.SHOT_COOLDOWN then return end
	lastShot = now

	net.Shoot:FireServer(getTargetPos())
	effects.shake(scoped and 0.2 or 0.45)
	if uiCtrl then uiCtrl.startCooldownBar(Config.SHOT_COOLDOWN) end
end

-- ── Mobile-Buttons (FEUER + SCOPE) ────────────────────────────────────────────
local function buildTouchControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchWeaponControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
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

	-- Scope beim Tod/Respawn zurücksetzen
	player.CharacterAdded:Connect(function()
		setScoped(false)
	end)
end

return WeaponController
