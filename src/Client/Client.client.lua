-- Client.client.lua (LocalScript in StarterPlayerScripts)
-- All client-side logic for Bamboo Slasher

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local player      = Players.LocalPlayer
local playerGui   = player:WaitForChild("PlayerGui")
local camera      = workspace.CurrentCamera

-- Wait for server remotes and config
local Config        = require(ReplicatedStorage:WaitForChild("Config"))
local remotesFolder = ReplicatedStorage:WaitForChild("BambooRemotes")
local UpdateData    = remotesFolder:WaitForChild("UpdateData")
local BuyUpgrade    = remotesFolder:WaitForChild("BuyUpgrade")
local Notify        = remotesFolder:WaitForChild("Notify")
local ChopBamboo    = remotesFolder:WaitForChild("ChopBamboo")
local HitEffect     = remotesFolder:WaitForChild("HitEffect")
local SlamAttack    = remotesFolder:WaitForChild("SlamAttack")

local mouse = player:GetMouse()

-- Local copy of player data
local localData = {
	coins        = 0,
	swordLevel   = 1,
	totalChopped = 0,
}

-- ─── Background Music ─────────────────────────────────────────────────────────
local MUSIC_IDS = {
	"rbxassetid://1841647093",
	"rbxassetid://1843463175",
	"rbxassetid://9046897116",
	"rbxassetid://1837879082",
}

task.spawn(function()
	for _, id in ipairs(MUSIC_IDS) do
		local music = Instance.new("Sound")
		music.Name = "BambooMusic"
		music.SoundId = id
		music.Looped = true
		music.Volume = 0.35
		music.Parent = SoundService

		local waited = 0
		while not music.IsLoaded and waited < 3 do
			task.wait(0.2)
			waited += 0.2
		end

		if music.IsLoaded and music.TimeLength > 0 then
			music:Play()
			return
		end
		music:Destroy()
	end
	warn("[BambooSlasher] Keine Musik-ID konnte geladen werden.")
end)

-- ─── Camera Shake ────────────────────────────────────────────────────────────
local shakeIntensity = 0
local shakeDecayRate = 0.2  -- seconds to decay to zero

RunService.RenderStepped:Connect(function(dt)
	if shakeIntensity <= 0 then return end
	shakeIntensity = math.max(0, shakeIntensity - dt / shakeDecayRate * shakeIntensity * 5)
	local ox = (math.random() - 0.5) * 2 * shakeIntensity
	local oy = (math.random() - 0.5) * 2 * shakeIntensity
	local oz = (math.random() - 0.5) * 2 * shakeIntensity
	camera.CFrame = camera.CFrame * CFrame.new(ox, oy, oz)
end)

local function shakeCam(intensity)
	shakeIntensity = math.max(shakeIntensity, intensity)
end

-- ─── Flying Fragments ────────────────────────────────────────────────────────
local function spawnFragment(position, color)
	local frag = Instance.new("Part")
	frag.Size = Vector3.new(0.3, 0.3, 0.3)
	frag.Material = Enum.Material.SmoothPlastic
	frag.Color = color or Color3.fromRGB(100, 180, 80)
	frag.Anchored = false
	frag.CanCollide = false
	frag.CastShadow = false
	frag.Position = position + Vector3.new(
		(math.random() - 0.5) * 2,
		math.random() * 1.5,
		(math.random() - 0.5) * 2
	)
	frag.AssemblyLinearVelocity = Vector3.new(
		(math.random() - 0.5) * 24,
		math.random() * 20 + 8,
		(math.random() - 0.5) * 24
	)
	frag.Parent = workspace

	local tween = TweenService:Create(frag,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		frag:Destroy()
	end)
end

-- ─── Floating Damage Numbers ─────────────────────────────────────────────────
local function spawnDamageNum(position, damage, isCrit)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = position + Vector3.new((math.random() - 0.5) * 2, 3, 0)
	part.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, isCrit and 80 or 60, 0, isCrit and 50 or 40)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = isCrit and ("CRIT " .. tostring(damage) .. "!") or tostring(damage)
	label.TextColor3 = isCrit and Color3.fromRGB(255, 220, 0) or Color3.fromRGB(255, 255, 255)
	label.TextSize = isCrit and 26 or 20
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	local targetPos = part.Position + Vector3.new(0, 4, 0)
	local tween = TweenService:Create(part,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = targetPos }
	)
	local tweenFade = TweenService:Create(label,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)
	tween:Play()
	tweenFade:Play()
	tween.Completed:Connect(function()
		part:Destroy()
	end)
end

-- ─── Combo System ─────────────────────────────────────────────────────────────
local comboCount    = 1
local lastHitTime   = 0
local comboFadeTask = nil

-- ─── HUD Setup ────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BambooHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function makeFrame(name, size, position, bgColor, bgTransparency)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = bgColor or Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = bgTransparency or 0.35
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	return frame
end

local function makeLabel(name, text, size, position, textColor, fontSize, font, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextSize = fontSize or 18
	label.Font = font or Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Coin frame (top-left)
local coinFrame = makeFrame("CoinFrame",
	UDim2.new(0, 200, 0, 44),
	UDim2.new(0, 12, 0, 12),
	Color3.fromRGB(20, 20, 20), 0.3)
coinFrame.Parent = screenGui

local coinLabel = makeLabel("CoinLabel", "💰 0",
	UDim2.new(1, -10, 1, 0),
	UDim2.new(0, 10, 0, 0),
	Color3.fromRGB(255, 215, 50), 22, Enum.Font.GothamBold, coinFrame)

-- Chop counter (below coins)
local chopFrame = makeFrame("ChopFrame",
	UDim2.new(0, 200, 0, 38),
	UDim2.new(0, 12, 0, 62),
	Color3.fromRGB(20, 20, 20), 0.3)
chopFrame.Parent = screenGui

local chopLabel = makeLabel("ChopLabel", "🌿 Gefaellt: 0",
	UDim2.new(1, -10, 1, 0),
	UDim2.new(0, 10, 0, 0),
	Color3.fromRGB(160, 230, 100), 18, Enum.Font.Gotham, chopFrame)

-- Sword info (top-center)
local swordFrame = makeFrame("SwordFrame",
	UDim2.new(0, 260, 0, 44),
	UDim2.new(0.5, -130, 0, 12),
	Color3.fromRGB(20, 20, 20), 0.3)
swordFrame.Parent = screenGui

local swordLabel = makeLabel("SwordLabel", "⚔ Holzschwert (Lv. 1)",
	UDim2.new(1, -10, 1, 0),
	UDim2.new(0, 10, 0, 0),
	Color3.fromRGB(200, 200, 255), 18, Enum.Font.GothamBold, swordFrame)
swordLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Upgrade panel (bottom-right)
local upgradeFrame = makeFrame("UpgradeFrame",
	UDim2.new(0, 220, 0, 90),
	UDim2.new(1, -232, 1, -102),
	Color3.fromRGB(20, 20, 20), 0.25)
upgradeFrame.Parent = screenGui

local upgradeTitle = Instance.new("TextLabel")
upgradeTitle.Name = "UpgradeTitle"
upgradeTitle.Size = UDim2.new(1, -10, 0, 30)
upgradeTitle.Position = UDim2.new(0, 5, 0, 5)
upgradeTitle.BackgroundTransparency = 1
upgradeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeTitle.TextSize = 15
upgradeTitle.Font = Enum.Font.Gotham
upgradeTitle.Text = "Naechstes Schwert"
upgradeTitle.TextXAlignment = Enum.TextXAlignment.Center
upgradeTitle.Parent = upgradeFrame

local upgradeButton = Instance.new("TextButton")
upgradeButton.Name = "UpgradeButton"
upgradeButton.Size = UDim2.new(1, -16, 0, 40)
upgradeButton.Position = UDim2.new(0, 8, 0, 42)
upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
upgradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeButton.TextSize = 16
upgradeButton.Font = Enum.Font.GothamBold
upgradeButton.Text = "UPGRADE"
upgradeButton.BorderSizePixel = 0
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = upgradeButton
upgradeButton.Parent = upgradeFrame

-- ─── Combo Label (center screen) ─────────────────────────────────────────────
local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "ComboLabel"
comboLabel.Size = UDim2.new(0, 400, 0, 70)
comboLabel.Position = UDim2.new(0.5, -200, 0.38, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
comboLabel.TextSize = 52
comboLabel.Font = Enum.Font.GothamBold
comboLabel.TextStrokeTransparency = 0.3
comboLabel.Text = ""
comboLabel.TextXAlignment = Enum.TextXAlignment.Center
comboLabel.ZIndex = 15
comboLabel.Parent = screenGui

local function showCombo(count)
	if count < 2 then
		comboLabel.Text = ""
		comboLabel.TextTransparency = 1
		return
	end
	comboLabel.Text = tostring(count) .. "x COMBO!"
	comboLabel.TextTransparency = 0
	comboLabel.TextSize = 52 + math.min(count * 2, 20)

	if comboFadeTask then
		task.cancel(comboFadeTask)
	end
	comboFadeTask = task.delay(2, function()
		local tween = TweenService:Create(comboLabel,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Connect(function()
			comboLabel.Text = ""
		end)
	end)
end

-- ─── Slam text popup ─────────────────────────────────────────────────────────
local function showSlamText()
	local slamLabel = Instance.new("TextLabel")
	slamLabel.Name = "SlamLabel"
	slamLabel.Size = UDim2.new(0, 500, 0, 100)
	slamLabel.Position = UDim2.new(0.5, -250, 0.3, 0)
	slamLabel.BackgroundTransparency = 1
	slamLabel.TextColor3 = Color3.fromRGB(255, 80, 30)
	slamLabel.TextSize = 72
	slamLabel.Font = Enum.Font.GothamBold
	slamLabel.TextStrokeTransparency = 0.2
	slamLabel.Text = "SLAM!"
	slamLabel.TextXAlignment = Enum.TextXAlignment.Center
	slamLabel.ZIndex = 20
	slamLabel.Parent = screenGui

	local tween = TweenService:Create(slamLabel,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1, Position = UDim2.new(0.5, -250, 0.22, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		slamLabel:Destroy()
	end)
end

-- ─── Coin Popup ───────────────────────────────────────────────────────────────
local function showCoinPopup(amount)
	local displayAmount = math.floor(amount * (comboCount >= 2 and comboCount or 1))
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 160, 0, 36)
	popup.Position = UDim2.new(0, 12, 0, 108)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = Color3.fromRGB(255, 230, 60)
	popup.TextSize = 22
	popup.Font = Enum.Font.GothamBold
	popup.Text = "+" .. amount .. " 💰"
	popup.TextXAlignment = Enum.TextXAlignment.Left
	popup.ZIndex = 10
	popup.Parent = screenGui

	local tween = TweenService:Create(popup,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0, 12, 0, 70),
			TextTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

-- ─── HUD Refresh ─────────────────────────────────────────────────────────────
local prevCoins     = 0
local prevSwordLevel = 1

local function refreshHUD()
	local data = localData
	coinLabel.Text = "💰 " .. data.coins
	chopLabel.Text = "🌿 Gefaellt: " .. data.totalChopped

	local currentSword = Config.SWORDS[data.swordLevel]
	if currentSword then
		swordLabel.Text = "⚔ " .. currentSword.name .. " (Lv. " .. data.swordLevel .. ")"
	end

	local nextLevel = data.swordLevel + 1
	local nextSword = Config.SWORDS[nextLevel]
	if nextSword then
		upgradeFrame.Visible = true
		upgradeTitle.Text = nextSword.name .. " — " .. nextSword.cost .. " 💰"
		if data.coins >= nextSword.cost then
			upgradeButton.BackgroundColor3 = Color3.fromRGB(50, 190, 50)
			upgradeButton.Text = "UPGRADE (" .. nextSword.cost .. " 💰)"
		else
			upgradeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			upgradeButton.Text = "Zu wenig Muenzen"
		end
	else
		upgradeFrame.Visible = false
	end
end

-- ─── Sword Tool ───────────────────────────────────────────────────────────────
local currentTool = nil
local swinging    = false

local function attachPart(handle, part, offsetCFrame)
	part.CFrame = handle.CFrame * offsetCFrame
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = handle.Parent
end

local function buildSword(level)
	local sword = Config.SWORDS[level]
	if not sword then return end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local old = backpack:FindFirstChild("Sword")
		if old then old:Destroy() end
	end
	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("Sword")
		if equipped then equipped:Destroy() end
	end

	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = sword.name
	tool.GripPos     = Vector3.new(0, -0.3, 0)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 1.1, 0.3)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(90, 60, 35)
	handle.CanCollide = false
	handle.Parent = tool

	local pommel = Instance.new("Part")
	pommel.Name = "Pommel"
	pommel.Shape = Enum.PartType.Ball
	pommel.Size = Vector3.new(0.4, 0.4, 0.4)
	pommel.Material = Enum.Material.Metal
	pommel.Color = Color3.fromRGB(120, 120, 130)
	attachPart(handle, pommel, CFrame.new(0, -0.6, 0))

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(1.1, 0.18, 0.4)
	guard.Material = Enum.Material.Metal
	guard.Color = Color3.fromRGB(110, 110, 120)
	attachPart(handle, guard, CFrame.new(0, 0.62, 0))

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.18, 2.6, 0.55)
	blade.Material = Enum.Material.Metal
	blade.Color = sword.color
	attachPart(handle, blade, CFrame.new(0, 2.0, 0))

	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.18, 0.5, 0.55)
	tip.Material = Enum.Material.Metal
	tip.Color = sword.color
	attachPart(handle, tip, CFrame.new(0, 3.55, 0))

	if level >= 5 then
		blade.Material = Enum.Material.Neon
		tip.Material = Enum.Material.Neon
	end

	local swingSound = Instance.new("Sound")
	swingSound.Name = "SwingSound"
	swingSound.SoundId = "rbxasset://sounds/swordslash.wav"
	swingSound.Volume = 0.6
	swingSound.Parent = handle

	-- Slam sound (lower pitch whoosh)
	local slamSound = Instance.new("Sound")
	slamSound.Name = "SlamSound"
	slamSound.SoundId = "rbxasset://sounds/swordslash.wav"
	slamSound.Volume = 1.0
	slamSound.PlaybackSpeed = 0.5
	slamSound.Parent = handle

	currentTool = tool

	if backpack then
		tool.Parent = backpack
	end
end

-- ─── Auto-Equip Sword ────────────────────────────────────────────────────────
local function autoEquipSword()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- If sword not currently equipped (not in character)
	if character:FindFirstChild("Sword") then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local sword = backpack:FindFirstChild("Sword")
		if sword then
			humanoid:EquipTool(sword)
		end
	end
end

-- ─── Swing Animation ─────────────────────────────────────────────────────────
local function swingSword(isSlam)
	if swinging then return end
	local tool = currentTool
	local character = player.Character
	if not tool or not character or tool.Parent ~= character then return end

	swinging = true
	local handle = tool:FindFirstChild("Handle")
	local blade = handle and handle.Parent:FindFirstChild("Blade") -- blade is sibling
	-- Blade is parented to handle.Parent (the tool) via attachPart
	-- Let's find it in the tool
	local toolBlade = tool:FindFirstChild("Blade")

	if isSlam then
		-- Slam sound
		local slamSound = handle and handle:FindFirstChild("SlamSound")
		if slamSound then slamSound:Play() end
	else
		local swingSound = handle and handle:FindFirstChild("SwingSound")
		if swingSound then swingSound:Play() end
	end

	-- Find the bamboo/rock to chop
	local targetHitbox = nil
	local mouseTarget = mouse.Target
	if mouseTarget and (mouseTarget:GetAttribute("IsBamboo") or mouseTarget:GetAttribute("IsRock")) then
		targetHitbox = mouseTarget
	else
		local root = character:FindFirstChild("HumanoidRootPart")
		local zonesFolder = workspace:FindFirstChild("Zones")
		if root and zonesFolder then
			local closestDist = isSlam and 10 or 14
			for _, desc in ipairs(zonesFolder:GetDescendants()) do
				if desc:IsA("BasePart")
					and (desc:GetAttribute("IsBamboo") or desc:GetAttribute("IsRock"))
					and not desc:GetAttribute("IsDead") then
					local dist = (desc.Position - root.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						targetHitbox = desc
					end
				end
			end
		end
	end

	if isSlam then
		SlamAttack:FireServer()
		shakeCam(2.5)
		showSlamText()
	else
		if targetHitbox then
			ChopBamboo:FireServer(targetHitbox)
		end
	end

	local originalGrip = tool.Grip

	if isSlam then
		-- Slam: fast downward smash
		for s = 1, 6 do
			tool.Grip = originalGrip * CFrame.Angles(math.rad(-150 * s / 6), 0, 0)
			task.wait(0.012)
		end
		task.wait(0.05) -- impact pause
		-- Flash blade white
		if toolBlade then
			local origColor = toolBlade.Color
			toolBlade.Color = Color3.fromRGB(255, 255, 255)
			task.wait(0.016)
			toolBlade.Color = origColor
		end
		for s = 5, 0, -1 do
			tool.Grip = originalGrip * CFrame.Angles(math.rad(-150 * s / 6), 0, 0)
			task.wait(0.022)
		end
	else
		-- Normal swing: punchy forward slash
		-- Step 1: 4 frames x 8ms, rotate -130 degrees (fast forward slash)
		for s = 1, 4 do
			tool.Grip = originalGrip * CFrame.Angles(math.rad(-130 * s / 4), 0, 0)
			task.wait(0.008)
		end
		-- Step 2: 1 frame impact pause
		task.wait(0.016)
		-- Flash blade white at impact
		if toolBlade then
			local origColor = toolBlade.Color
			toolBlade.Color = Color3.fromRGB(255, 255, 255)
			task.wait(0.016)
			toolBlade.Color = origColor
		end
		-- Step 3: 5 frames x 18ms, return to 0 degrees
		for s = 3, 0, -1 do
			tool.Grip = originalGrip * CFrame.Angles(math.rad(-130 * s / 4), 0, 0)
			task.wait(0.018)
		end
	end

	tool.Grip = originalGrip
	swinging = false
end

-- ─── Input: Left Click ────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		-- Check if in air for slam
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.AssemblyLinearVelocity.Y < -5 then
			swingSword(true)
		else
			swingSword(false)
		end
	end
end)

-- ─── HitEffect Event (from server) ───────────────────────────────────────────
HitEffect.OnClientEvent:Connect(function(hitPos, bambooColor, died, serverCombo, damage)
	-- Camera shake
	if died then
		shakeCam(1.2)
	else
		shakeCam(0.4)
	end

	-- Fragments
	local fragCount = died and 8 or 3
	local fragColor = bambooColor or Color3.fromRGB(100, 180, 80)
	for _ = 1, fragCount do
		spawnFragment(hitPos, fragColor)
	end

	-- Update combo from server
	if serverCombo then
		comboCount = serverCombo
		showCombo(comboCount)
	end

	-- Damage number
	if damage then
		local isCrit = (serverCombo and serverCombo >= 5)
		spawnDamageNum(hitPos, damage, isCrit)
	end
end)

-- ─── Upgrade Button Click ─────────────────────────────────────────────────────
upgradeButton.MouseButton1Click:Connect(function()
	local nextLevel = localData.swordLevel + 1
	local nextSword = Config.SWORDS[nextLevel]
	if nextSword and localData.coins >= nextSword.cost then
		BuyUpgrade:FireServer()
	end
end)

-- ─── UpdateData Event ─────────────────────────────────────────────────────────
UpdateData.OnClientEvent:Connect(function(data)
	local oldCoins      = localData.coins
	local oldSwordLevel = localData.swordLevel

	localData.coins        = data.coins
	localData.swordLevel   = data.swordLevel
	localData.totalChopped = data.totalChopped

	refreshHUD()

	if data.coins > oldCoins then
		showCoinPopup(data.coins - oldCoins)
	end

	if data.swordLevel ~= oldSwordLevel then
		buildSword(data.swordLevel)
	end
end)

-- ─── Notify ───────────────────────────────────────────────────────────────────
Notify.OnClientEvent:Connect(function(message)
	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(0, 320, 0, 40)
	note.Position = UDim2.new(0.5, -160, 0.25, 0)
	note.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
	note.BackgroundTransparency = 0.2
	note.TextColor3 = Color3.fromRGB(255, 255, 255)
	note.TextSize = 18
	note.Font = Enum.Font.GothamBold
	note.Text = message
	note.ZIndex = 20
	local noteCorner = Instance.new("UICorner")
	noteCorner.CornerRadius = UDim.new(0, 8)
	noteCorner.Parent = note
	note.Parent = screenGui

	local tween = TweenService:Create(note,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		note:Destroy()
	end)
end)

-- ─── Character Respawn ────────────────────────────────────────────────────────
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	buildSword(localData.swordLevel)
	task.wait(0.2)
	autoEquipSword()
end)

-- ─── Auto-Equip loop: watch for sword in backpack ────────────────────────────
task.spawn(function()
	while true do
		task.wait(1)
		autoEquipSword()
	end
end)

-- ─── Initial Setup ────────────────────────────────────────────────────────────
task.wait(0.5)
buildSword(1)
refreshHUD()
task.wait(0.2)
autoEquipSword()
