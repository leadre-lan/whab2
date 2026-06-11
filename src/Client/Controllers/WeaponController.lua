-- WeaponController.lua — Schießen (Klick), Scope-Zoom (Rechtsklick), Cooldown-UI
local WeaponController = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RS               = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local net      = nil
local effects  = nil
local uiCtrl   = nil

local lastShot   = 0
local scoped     = false
local BASE_FOV   = 70
local SCOPE_FOV  = 22

-- ── Scope ─────────────────────────────────────────────────────────────────────
local function setScoped(state)
	if scoped == state then return end
	scoped = state
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			FieldOfView = state and SCOPE_FOV or BASE_FOV,
		}):Play()
	end
	if uiCtrl then uiCtrl.setScopeVisible(state) end

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

local function shoot()
	if not net or not hasWeaponEquipped() then return end
	local now = os.clock()
	if now - lastShot < Config.SHOT_COOLDOWN then return end
	lastShot = now

	net.Shoot:FireServer(mouse.Hit.Position)
	effects.shake(scoped and 0.5 or 0.9)
	if uiCtrl then uiCtrl.startCooldownBar(Config.SHOT_COOLDOWN) end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function WeaponController.init(netRef, effectsCtrl, uiController)
	net     = netRef
	effects = effectsCtrl
	uiCtrl  = uiController

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
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

	-- Scope beim Tod/Respawn zurücksetzen
	player.CharacterAdded:Connect(function()
		setScoped(false)
	end)
end

return WeaponController
