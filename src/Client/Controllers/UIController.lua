-- UIController.lua — All HUD elements: coins, level, stats panel, sword info
local UIController = {}

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local UITheme = require(RS:WaitForChild("Shared"):WaitForChild("UITheme"))
local Balance = require(RS:WaitForChild("Shared"):WaitForChild("Balance"))
local Layers  = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local T   = UITheme
local C   = T.COLORS

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name  = "BambooHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function frame(name, size, pos, bg, alpha)
	local f = Instance.new("Frame")
	f.Name  = name
	f.Size  = size
	f.Position = pos
	f.BackgroundColor3 = bg or C.panel
	f.BackgroundTransparency = alpha or 0.25
	f.BorderSizePixel = 0
	T.applyCorner(f)
	T.applyStroke(f)
	f.Parent = screenGui
	return f
end

local function label(parent, name, txt, sz, pos, color, tsize, font, align)
	local l = Instance.new("TextLabel")
	l.Name  = name
	l.Text  = txt
	l.Size  = sz
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = color or C.text
	l.TextSize = tsize or 18
	l.Font  = font or T.FONTS.body
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent, name, txt, sz, pos, bg)
	local b = Instance.new("TextButton")
	b.Name  = name
	b.Text  = txt
	b.Size  = sz
	b.Position = pos
	b.BackgroundColor3 = bg or C.accent
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = 15
	b.Font  = T.FONTS.header
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	T.applyCorner(b)
	b.Parent = parent
	return b
end

-- ── Top-Left: Coins + Level ───────────────────────────────────────────────────
local coinFrame = frame("CoinFrame",
	UDim2.new(0, 210, 0, 82),
	UDim2.new(0, 12, 0, 12))

local coinLabel = label(coinFrame, "CoinLabel", "🎋 0",
	UDim2.new(1, -12, 0, 36), UDim2.new(0, 10, 0, 4),
	C.gold, 24, T.FONTS.header)

local levelLabel = label(coinFrame, "LevelLabel", "Lv. 1  (0 XP)",
	UDim2.new(1, -12, 0, 22), UDim2.new(0, 10, 0, 38),
	C.text, 14, T.FONTS.body)

-- XP Bar
local xpBg = Instance.new("Frame")
xpBg.Name  = "XPBarBg"
xpBg.Size  = UDim2.new(1, -12, 0, 6)
xpBg.Position = UDim2.new(0, 6, 1, -10)
xpBg.BackgroundColor3 = C.panel2
xpBg.BorderSizePixel  = 0
T.applyCorner(xpBg, UDim.new(0, 3))
xpBg.Parent = coinFrame

local xpFill = Instance.new("Frame")
xpFill.Name  = "XPFill"
xpFill.Size  = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = C.xpBar
xpFill.BorderSizePixel  = 0
T.applyCorner(xpFill, UDim.new(0, 3))
xpFill.Parent = xpBg

-- ── Top-Left below coins: Stats mini-bar ─────────────────────────────────────
local felledLabel = label(screenGui, "FelledLabel", "🌿 0 gefällt",
	UDim2.new(0, 210, 0, 28),
	UDim2.new(0, 12, 0, 100),
	C.accent, 15, T.FONTS.body)

-- ── Top-Center: Sword info ────────────────────────────────────────────────────
local swordFrame = frame("SwordFrame",
	UDim2.new(0, 270, 0, 44),
	UDim2.new(0.5, -135, 0, 12))

local swordLabel = label(swordFrame, "SwordLabel", "⚔ Holzschwert — Tier 1",
	UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0),
	C.text, 16, T.FONTS.header, Enum.TextXAlignment.Center)

-- ── Right side: Stats panel ───────────────────────────────────────────────────
local STAT_NAMES = {
	{ id = "sharpness", label = "⚔ Schärfe",      color = Color3.fromRGB(255, 120, 80) },
	{ id = "speed",     label = "⚡ Geschwind.",   color = Color3.fromRGB(120, 220, 255) },
	{ id = "luck",      label = "🍀 Glück",         color = Color3.fromRGB(120, 255, 120) },
	{ id = "range",     label = "📏 Reichweite",   color = Color3.fromRGB(255, 220, 80) },
}

local statsPanel = frame("StatsPanel",
	UDim2.new(0, 210, 0, #STAT_NAMES * 48 + 14),
	UDim2.new(1, -222, 0.5, -( (#STAT_NAMES * 48 + 14) / 2 )))

local statButtons = {}   -- [statId] = { frame, levelLabel, costLabel, button }

for i, stat in ipairs(STAT_NAMES) do
	local rowY = 8 + (i - 1) * 48
	local row  = Instance.new("Frame")
	row.Size   = UDim2.new(1, -10, 0, 42)
	row.Position = UDim2.new(0, 5, 0, rowY)
	row.BackgroundTransparency = 1
	row.Parent = statsPanel

	local nameLbl = label(row, "Name", stat.label,
		UDim2.new(0.55, 0, 0.5, 0), UDim2.new(0, 2, 0, 0),
		stat.color, 14, T.FONTS.body)

	local lvlLbl = label(row, "LvlLabel", "Lv.0",
		UDim2.new(0.22, 0, 0.5, 0), UDim2.new(0.55, 2, 0, 0),
		C.textDim, 12, T.FONTS.body)

	local btn = button(row, "UpBtn", "+",
		UDim2.new(0, 36, 0.95, 0), UDim2.new(1, -40, 0, 1),
		C.accentDim)
	btn.TextSize = 18

	statButtons[stat.id] = { nameLbl = nameLbl, lvlLbl = lvlLbl, btn = btn, def = stat }
end

-- ── Bottom-right: Hub-Teleport + info ─────────────────────────────────────────
local hubPanel = frame("HubPanel",
	UDim2.new(0, 210, 0, 96),
	UDim2.new(1, -222, 1, -108))

local infoLabel = label(hubPanel, "Info", "✨ Rebirths: 0  |  🏅 ELO 1000",
	UDim2.new(1, -8, 0, 22), UDim2.new(0, 6, 0, 4),
	C.textDim, 12, T.FONTS.body, Enum.TextXAlignment.Center)

local fameLabel = label(hubPanel, "Fame", "⭐ Ruhm: 0",
	UDim2.new(1, -8, 0, 20), UDim2.new(0, 6, 0, 26),
	C.gold, 13, T.FONTS.body, Enum.TextXAlignment.Center)

local hubBtn = button(hubPanel, "HubBtn", "🏯 Zur Overworld",
	UDim2.new(1, -12, 0, 32), UDim2.new(0, 6, 0, 52),
	C.accentDim)

-- ── Layer-Select panel (opened at the forest portal) ─────────────────────────
local layerPanel = frame("LayerPanel",
	UDim2.new(0, 320, 0, 460),
	UDim2.new(0.5, -160, 0.5, -230))
layerPanel.Visible = false
layerPanel.BackgroundTransparency = 0.08

label(layerPanel, "Title", "🌲 Schicht wählen",
	UDim2.new(1, -16, 0, 34), UDim2.new(0, 12, 0, 8),
	C.text, 20, T.FONTS.header, Enum.TextXAlignment.Center)

local layerScroll = Instance.new("ScrollingFrame")
layerScroll.Size = UDim2.new(1, -16, 1, -94)
layerScroll.Position = UDim2.new(0, 8, 0, 46)
layerScroll.BackgroundTransparency = 1
layerScroll.BorderSizePixel = 0
layerScroll.ScrollBarThickness = 5
layerScroll.CanvasSize = UDim2.new(0, 0, 0, #Layers.DATA * 50)
layerScroll.Parent = layerPanel

local layerButtons = {}
for li, ld in ipairs(Layers.DATA) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -10, 0, 44)
	b.Position = UDim2.new(0, 2, 0, (li - 1) * 50)
	b.BackgroundColor3 = C.panel2
	b.TextColor3 = ld.glowColor
	b.TextSize = 15
	b.Font = T.FONTS.header
	b.Text = li .. ". " .. ld.name .. "  (Lv. " .. ld.requiredLevel .. ")"
	b.BorderSizePixel = 0
	T.applyCorner(b)
	b.Parent = layerScroll
	layerButtons[li] = b
end

local layerCloseBtn = button(layerPanel, "Close", "Schließen",
	UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 1, -40),
	Color3.fromRGB(90, 90, 110))

-- ── Forge panel ───────────────────────────────────────────────────────────────
local forgePanel = frame("ForgePanel",
	UDim2.new(0, 340, 0, 230),
	UDim2.new(0.5, -170, 0.5, -115))
forgePanel.Visible = false
forgePanel.BackgroundTransparency = 0.08

label(forgePanel, "Title", "🔨 Schmiede",
	UDim2.new(1, -16, 0, 34), UDim2.new(0, 12, 0, 8),
	Color3.fromRGB(255, 160, 70), 20, T.FONTS.header, Enum.TextXAlignment.Center)

local forgeInfo = label(forgePanel, "Info", "",
	UDim2.new(1, -24, 0, 100), UDim2.new(0, 12, 0, 46),
	C.text, 15, T.FONTS.body)
forgeInfo.TextWrapped = true
forgeInfo.TextYAlignment = Enum.TextYAlignment.Top

local craftBtn = button(forgePanel, "Craft", "SCHMIEDEN",
	UDim2.new(1, -80, 0, 36), UDim2.new(0, 40, 1, -82),
	Color3.fromRGB(220, 120, 40))

local forgeCloseBtn = button(forgePanel, "Close", "Schließen",
	UDim2.new(1, -80, 0, 30), UDim2.new(0, 40, 1, -40),
	Color3.fromRGB(90, 90, 110))

-- ── Combo label (center) ──────────────────────────────────────────────────────
local comboLabel = Instance.new("TextLabel")
comboLabel.Name  = "ComboLabel"
comboLabel.Size  = UDim2.new(0, 400, 0, 72)
comboLabel.Position = UDim2.new(0.5, -200, 0.38, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.TextColor3 = C.combo
comboLabel.TextSize = 54
comboLabel.Font   = T.FONTS.display
comboLabel.TextStrokeTransparency = 0.25
comboLabel.Text   = ""
comboLabel.TextXAlignment = Enum.TextXAlignment.Center
comboLabel.ZIndex = 16
comboLabel.Parent = screenGui

local comboFadeTask = nil
function UIController.showCombo(count)
	if count < 2 then
		comboLabel.Text = ""
		return
	end
	comboLabel.Text = tostring(count) .. "x COMBO!"
	comboLabel.TextTransparency = 0
	comboLabel.TextSize = math.min(82, 54 + count * 1.5)
	if comboFadeTask then task.cancel(comboFadeTask) end
	comboFadeTask = task.delay(2.2, function()
		TweenService:Create(comboLabel,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad),
			{ TextTransparency = 1 }):Play()
	end)
end

-- ── Slam text ─────────────────────────────────────────────────────────────────
function UIController.showSlamText()
	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(0, 500, 0, 100)
	lbl.Position = UDim2.new(0.5, -250, 0.3, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 78, 28)
	lbl.TextSize = 76
	lbl.Font  = T.FONTS.display
	lbl.TextStrokeTransparency = 0.2
	lbl.Text  = "SLAM!"
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.ZIndex = 22
	lbl.Parent = screenGui

	TweenService:Create(lbl,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad),
		{ TextTransparency = 1, Position = UDim2.new(0.5, -250, 0.22, 0) }):Play()
	game:GetService("Debris"):AddItem(lbl, 0.8)
end

-- ── Notify popup ──────────────────────────────────────────────────────────────
function UIController.showNotify(message)
	local note = Instance.new("TextLabel")
	note.Size  = UDim2.new(0, 340, 0, 42)
	note.Position = UDim2.new(0.5, -170, 0.22, 0)
	note.BackgroundColor3 = C.red
	note.BackgroundTransparency = 0.15
	note.TextColor3 = Color3.fromRGB(255, 255, 255)
	note.TextSize = 17
	note.Font  = T.FONTS.header
	note.Text  = message
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.ZIndex = 22
	T.applyCorner(note)
	note.Parent = screenGui

	TweenService:Create(note,
		TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(note, 1.8)
end

-- ── Main Refresh ──────────────────────────────────────────────────────────────
local SWORD_NAMES = {
	"Holzschwert", "Steinschwert", "Eisenschwert", "Goldschwert", "Diamantschwert",
	"Rubin Klinge", "Smaragdklinge", "Mondklinge", "Sonnenklinge", "Legendäre Klinge",
}

local prevCoins = -1
local prevLevel = -1

function UIController.refresh(data, effects)
	-- Coins
	coinLabel.Text = "🎋 " .. (data.coins or 0)

	-- Level + XP
	local lvl  = data.level or 1
	local xp   = data.xp or 0
	local nextLvlXP = math.floor(50 * lvl * lvl)  -- XP for next level
	levelLabel.Text = "Lv. " .. lvl .. "  (" .. xp .. " / " .. nextLvlXP .. " XP)"

	-- XP bar fill (approximate pct through current level)
	local prevLvlXP = lvl > 1 and math.floor(50 * (lvl - 1) * (lvl - 1)) or 0
	local pct = (nextLvlXP > prevLvlXP)
		and math.clamp((xp - prevLvlXP) / (nextLvlXP - prevLvlXP), 0, 1)
		or 1
	TweenService:Create(xpFill,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad),
		{ Size = UDim2.new(pct, 0, 1, 0) }):Play()

	-- Felled
	felledLabel.Text = "🌿 " .. (data.totalFelled or 0) .. " gefällt  |  ⛏ " .. (data.totalMined or 0)

	-- Sword
	local tier = data.swordTier or 1
	swordLabel.Text = "⚔ " .. (SWORD_NAMES[tier] or "Schwert") .. " — Tier " .. tier

	-- Stats panel
	local stats = data.stats or {}
	for statId, entry in pairs(statButtons) do
		local lvl2   = stats[statId] or 0
		local cost   = Balance.statCost(lvl2)
		entry.lvlLbl.Text = "Lv." .. lvl2
		if (data.coins or 0) >= cost then
			entry.btn.BackgroundColor3 = Color3.fromRGB(55, 185, 75)
			entry.btn.Text = "+"
		else
			entry.btn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
			entry.btn.Text = "+"
		end
		entry.btn.Active = true
	end

	-- Hub panel info
	infoLabel.Text = "✨ Rebirths: " .. (data.rebirths or 0) .. "  |  🏅 ELO " .. (data.elo or 1000)
	fameLabel.Text = "⭐ Ruhm: " .. (data.fame or 0)
		.. "  |  ⚔ " .. (data.pvpWins or 0) .. "W/" .. (data.pvpLosses or 0) .. "L"

	-- Layer-select buttons: unlocked vs locked styling
	local highest = data.highestLayer or 1
	for li, b in ipairs(layerButtons) do
		local ld = Layers.DATA[li]
		if li <= highest then
			b.BackgroundColor3 = C.panel2
			b.TextColor3 = ld.glowColor
			b.Text = li .. ". " .. ld.name .. "  ✓"
		else
			b.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
			b.TextColor3 = C.textDim
			b.Text = "🔒 " .. li .. ". " .. ld.name .. "  (Lv. " .. ld.requiredLevel .. ")"
		end
	end

	-- Forge panel content
	local recipe = Balance.FORGE_RECIPES[tier + 1]
	if recipe then
		local matKey = "mat" .. recipe.matLayer
		local have = (data.materials and data.materials[matKey]) or 0
		forgeInfo.Text = "Nächstes Schwert: " .. recipe.name
			.. "\n\n🎋 " .. recipe.coins .. " Bamboos (du: " .. (data.coins or 0) .. ")"
			.. "\n⛏ " .. recipe.matCount .. "x Material aus Schicht " .. recipe.matLayer
			.. " (du: " .. have .. ")"
		local canCraft = (data.coins or 0) >= recipe.coins and have >= recipe.matCount
		craftBtn.BackgroundColor3 = canCraft
			and Color3.fromRGB(220, 120, 40)
			or Color3.fromRGB(90, 90, 110)
	else
		forgeInfo.Text = "⚔ Du besitzt bereits das beste Schwert!"
	end

	-- Coin gain popup
	if effects and data.coins > prevCoins and prevCoins >= 0 then
		effects.spawnCoinPopup(screenGui, data.coins - prevCoins)
	end

	-- Level-up popup
	if effects and data.level > prevLevel and prevLevel >= 0 then
		effects.showLevelUp(screenGui, data.level)
	end

	prevCoins = data.coins or 0
	prevLevel = data.level or 1
end

-- ── Panel open/close ──────────────────────────────────────────────────────────
function UIController.openLayerSelect()
	layerPanel.Visible = true
end

function UIController.openForge()
	forgePanel.Visible = true
end

-- ── Expose remote-event wiring ────────────────────────────────────────────────
function UIController.wireButtons(net)
	-- Stat upgrade buttons
	for statId, entry in pairs(statButtons) do
		entry.btn.MouseButton1Click:Connect(function()
			net.UpgradeStat:FireServer(statId)
		end)
	end

	-- Hub teleport
	hubBtn.MouseButton1Click:Connect(function()
		net.TeleportToHub:FireServer()
	end)

	-- Layer select
	for li, b in ipairs(layerButtons) do
		b.MouseButton1Click:Connect(function()
			net.TeleportToLayer:FireServer(li)
			layerPanel.Visible = false
		end)
	end
	layerCloseBtn.MouseButton1Click:Connect(function()
		layerPanel.Visible = false
	end)

	-- Forge
	craftBtn.MouseButton1Click:Connect(function()
		net.CraftSword:FireServer()
	end)
	forgeCloseBtn.MouseButton1Click:Connect(function()
		forgePanel.Visible = false
	end)
end

function UIController.getScreenGui()
	return screenGui
end

return UIController
