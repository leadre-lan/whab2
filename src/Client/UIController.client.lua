-- UIController.client.lua
-- Place as a LocalScript in StarterPlayer > StarterPlayerScripts.
-- Builds and manages the HUD: coin counter, sword display, upgrade button.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Wait for shared resources
-- ============================================================
local Config      = require(ReplicatedStorage:WaitForChild("Config"))
local remotes     = ReplicatedStorage:WaitForChild("BambooRemotes")
local updateEvent = remotes:WaitForChild("UpdateData")
local buyEvent    = remotes:WaitForChild("BuyUpgrade")

local player      = Players.LocalPlayer
local playerGui   = player:WaitForChild("PlayerGui")

-- ============================================================
-- Local cached state
-- ============================================================
local localData = {
	coins        = 0,
	swordLevel   = 1,
	totalChopped = 0,
}

-- ============================================================
-- Number formatter  (e.g. 1500 → "1,500")
-- ============================================================
local function formatNumber(n)
	local s = tostring(math.floor(n))
	-- Insert commas every three digits from the right
	local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	-- Remove a leading comma if the length is a multiple of 3
	if result:sub(1,1) == "," then
		result = result:sub(2)
	end
	return result
end

-- ============================================================
-- Build the ScreenGui
-- ============================================================
local screenGui             = Instance.new("ScreenGui")
screenGui.Name              = "BambooHUD"
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.Parent            = playerGui

-- ============================================================
-- Coin display  (top-left)
-- ============================================================
local coinFrame                      = Instance.new("Frame")
coinFrame.Name                       = "CoinFrame"
coinFrame.Size                       = UDim2.new(0, 230, 0, 50)
coinFrame.Position                   = UDim2.new(0, 12, 0, 12)
coinFrame.BackgroundColor3           = Color3.fromRGB(20, 20, 20)
coinFrame.BackgroundTransparency     = 0.35
coinFrame.BorderSizePixel            = 0
coinFrame.Parent                     = screenGui

local coinCorner        = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0, 10)
coinCorner.Parent       = coinFrame

local coinLabel                   = Instance.new("TextLabel")
coinLabel.Name                    = "CoinLabel"
coinLabel.Size                    = UDim2.new(1, 0, 1, 0)
coinLabel.BackgroundTransparency  = 1
coinLabel.TextColor3              = Color3.fromRGB(255, 220, 50)
coinLabel.TextScaled              = true
coinLabel.Font                    = Enum.Font.GothamBold
coinLabel.Text                    = "💰 ROJO SYNC OK! 0"
coinLabel.Parent                  = coinFrame

-- ============================================================
-- Sword display  (top-center)
-- ============================================================
local swordFrame                     = Instance.new("Frame")
swordFrame.Name                      = "SwordFrame"
swordFrame.Size                      = UDim2.new(0, 280, 0, 50)
-- Anchor to top-center
swordFrame.AnchorPoint               = Vector2.new(0.5, 0)
swordFrame.Position                  = UDim2.new(0.5, 0, 0, 12)
swordFrame.BackgroundColor3          = Color3.fromRGB(20, 20, 60)
swordFrame.BackgroundTransparency    = 0.35
swordFrame.BorderSizePixel           = 0
swordFrame.Parent                    = screenGui

local swordCorner        = Instance.new("UICorner")
swordCorner.CornerRadius = UDim.new(0, 10)
swordCorner.Parent       = swordFrame

local swordLabel                  = Instance.new("TextLabel")
swordLabel.Name                   = "SwordLabel"
swordLabel.Size                   = UDim2.new(1, 0, 1, 0)
swordLabel.BackgroundTransparency = 1
swordLabel.TextColor3             = Color3.fromRGB(180, 220, 255)
swordLabel.TextScaled             = true
swordLabel.Font                   = Enum.Font.GothamBold
swordLabel.Text                   = "⚔ Holzschwert  (Lv. 1)"
swordLabel.Parent                 = swordFrame

-- ============================================================
-- Upgrade button  (bottom-right)
-- ============================================================
local upgradeFrame                    = Instance.new("Frame")
upgradeFrame.Name                     = "UpgradeFrame"
upgradeFrame.Size                     = UDim2.new(0, 260, 0, 80)
upgradeFrame.AnchorPoint              = Vector2.new(1, 1)
upgradeFrame.Position                 = UDim2.new(1, -16, 1, -16)
upgradeFrame.BackgroundColor3         = Color3.fromRGB(20, 20, 20)
upgradeFrame.BackgroundTransparency   = 0.3
upgradeFrame.BorderSizePixel          = 0
upgradeFrame.Parent                   = screenGui

local upgradeCorner        = Instance.new("UICorner")
upgradeCorner.CornerRadius = UDim.new(0, 12)
upgradeCorner.Parent       = upgradeFrame

-- Sub-label: next sword name
local upgradeTitle                  = Instance.new("TextLabel")
upgradeTitle.Name                   = "UpgradeTitle"
upgradeTitle.Size                   = UDim2.new(1, 0, 0.45, 0)
upgradeTitle.BackgroundTransparency = 1
upgradeTitle.TextColor3             = Color3.fromRGB(255, 255, 255)
upgradeTitle.TextScaled             = true
upgradeTitle.Font                   = Enum.Font.Gotham
upgradeTitle.Text                   = "Nächstes Schwert"
upgradeTitle.Parent                 = upgradeFrame

-- Main clickable button
local upgradeButton                      = Instance.new("TextButton")
upgradeButton.Name                       = "UpgradeButton"
upgradeButton.Size                       = UDim2.new(1, -16, 0.52, 0)
upgradeButton.Position                   = UDim2.new(0, 8, 0.48, 0)
upgradeButton.BackgroundColor3           = Color3.fromRGB(50, 180, 80)
upgradeButton.BorderSizePixel            = 0
upgradeButton.TextColor3                 = Color3.fromRGB(255, 255, 255)
upgradeButton.TextScaled                 = true
upgradeButton.Font                       = Enum.Font.GothamBold
upgradeButton.Text                       = "UPGRADE"
upgradeButton.AutoButtonColor            = true
upgradeButton.Parent                     = upgradeFrame

local btnCorner        = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent       = upgradeButton

-- ============================================================
-- Chop counter  (below coin display)
-- ============================================================
local chopFrame                       = Instance.new("Frame")
chopFrame.Name                        = "ChopFrame"
chopFrame.Size                        = UDim2.new(0, 230, 0, 36)
chopFrame.Position                    = UDim2.new(0, 12, 0, 68)
chopFrame.BackgroundColor3            = Color3.fromRGB(20, 20, 20)
chopFrame.BackgroundTransparency      = 0.45
chopFrame.BorderSizePixel             = 0
chopFrame.Parent                      = screenGui

local chopCorner        = Instance.new("UICorner")
chopCorner.CornerRadius = UDim.new(0, 8)
chopCorner.Parent       = chopFrame

local chopLabel                   = Instance.new("TextLabel")
chopLabel.Name                    = "ChopLabel"
chopLabel.Size                    = UDim2.new(1, 0, 1, 0)
chopLabel.BackgroundTransparency  = 1
chopLabel.TextColor3              = Color3.fromRGB(200, 255, 200)
chopLabel.TextScaled              = true
chopLabel.Font                    = Enum.Font.Gotham
chopLabel.Text                    = "🌿 Gefällt: 0"
chopLabel.Parent                  = chopFrame

-- ============================================================
-- Refresh all HUD elements from localData
-- ============================================================
local function refreshHUD()
	local coins      = localData.coins
	local swordLv    = localData.swordLevel
	local chopped    = localData.totalChopped

	-- Coin display
	coinLabel.Text = "💰 Münzen: " .. formatNumber(coins)

	-- Chop counter
	chopLabel.Text = "🌿 Gefällt: " .. formatNumber(chopped)

	-- Sword display
	local sword = Config.SWORDS[swordLv] or Config.SWORDS[1]
	swordLabel.Text = "⚔ " .. sword.name .. "  (Lv. " .. swordLv .. ")"

	-- Upgrade button
	local nextLevel = swordLv + 1
	local nextSword = Config.SWORDS[nextLevel]

	if not nextSword then
		-- Max level
		upgradeTitle.Text      = "Maximales Schwert erreicht!"
		upgradeButton.Text     = "MAX LEVEL"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		upgradeButton.Active   = false
	else
		local canAfford = coins >= nextSword.cost
		upgradeTitle.Text  = nextSword.name
		upgradeButton.Text = "UPGRADE  💰 " .. formatNumber(nextSword.cost)

		if canAfford then
			upgradeButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
			upgradeButton.TextColor3       = Color3.fromRGB(255, 255, 255)
			upgradeButton.Active           = true
		else
			upgradeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			upgradeButton.TextColor3       = Color3.fromRGB(160, 160, 160)
			upgradeButton.Active           = false
		end
	end
end

-- ============================================================
-- UpdateData listener
-- ============================================================
updateEvent.OnClientEvent:Connect(function(data)
	localData.coins        = data.coins
	localData.swordLevel   = data.swordLevel
	localData.totalChopped = data.totalChopped
	refreshHUD()
end)

-- ============================================================
-- Upgrade button click
-- ============================================================
upgradeButton.MouseButton1Click:Connect(function()
	local swordLv   = localData.swordLevel
	local nextLevel = swordLv + 1
	local nextSword = Config.SWORDS[nextLevel]
	if not nextSword then return end
	if localData.coins < nextSword.cost then return end

	-- Optimistic UI flicker
	upgradeButton.Text = "..."
	buyEvent:FireServer()
end)

-- ============================================================
-- Initial render
-- ============================================================
refreshHUD()
