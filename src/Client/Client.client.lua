-- Client.client.lua (LocalScript in StarterPlayerScripts)
-- All client-side logic for Bamboo Slasher

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")

local player      = Players.LocalPlayer
local playerGui   = player:WaitForChild("PlayerGui")

-- Wait for server remotes and config
local Config        = require(ReplicatedStorage:WaitForChild("Config"))
local remotesFolder = ReplicatedStorage:WaitForChild("BambooRemotes")
local UpdateData    = remotesFolder:WaitForChild("UpdateData")
local BuyUpgrade    = remotesFolder:WaitForChild("BuyUpgrade")
local Notify        = remotesFolder:WaitForChild("Notify")

-- Local copy of player data
local localData = {
	coins        = 0,
	swordLevel   = 1,
	totalChopped = 0,
}

-- ─── Background Music ─────────────────────────────────────────────────────────
-- Most marketplace audio IDs are private since 2022; try several candidates and
-- play the first one that actually loads.
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

		-- Wait briefly for the asset to load
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

-- ─── Sword Tool ───────────────────────────────────────────────────────────────
local function buildSword(level)
	local sword = Config.SWORDS[level]
	if not sword then return end

	-- Remove any existing Sword from backpack and character
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

	-- Build new Tool
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = sword.name

	-- Handle (the visible blade)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.15, 2.5, 0.15)
	handle.Material = Enum.Material.Neon
	handle.Color = sword.color
	handle.CanCollide = false
	handle.Parent = tool

	-- Swing sound
	local swingSound = Instance.new("Sound")
	swingSound.Name = "SwingSound"
	swingSound.SoundId = "rbxasset://sounds/swordslash.wav"
	swingSound.Volume = 0.6
	swingSound.Parent = handle

	-- Animate on activation
	tool.Activated:Connect(function()
		swingSound:Play()
		local originalColor = handle.Color
		handle.Color = Color3.fromRGB(255, 255, 255)
		task.wait(0.1)
		-- Only restore if not destroyed between ticks
		if handle and handle.Parent then
			handle.Color = originalColor
		end
	end)

	-- Give to player
	if backpack then
		tool.Parent = backpack
	end
end

-- ─── HUD Setup ────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BambooHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Helper: create a rounded frame
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

-- Helper: create a text label
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

-- ─── Coin Popup ───────────────────────────────────────────────────────────────
local function showCoinPopup(amount)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 140, 0, 36)
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

	-- Upgrade panel
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

	-- Coin gain popup
	if data.coins > oldCoins then
		showCoinPopup(data.coins - oldCoins)
	end

	-- Sword changed
	if data.swordLevel ~= oldSwordLevel then
		buildSword(data.swordLevel)
	end
end)

-- ─── Notify (z.B. "Schwertlevel zu niedrig") ─────────────────────────────────
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
end)

-- ─── Initial Setup ────────────────────────────────────────────────────────────
task.wait(0.5)
buildSword(1)
refreshHUD()
