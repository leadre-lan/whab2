-- UIController.lua — HUD, Ei-/Inventar-UI (mit offengelegten Odds), Hatch-
-- Animation, Match-HUD, Trade-UI, Notify-Feed
local UIController = {}

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local RS           = game:GetService("ReplicatedStorage")

local Config  = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Skins   = require(RS:WaitForChild("Shared"):WaitForChild("Skins"))
local Assets  = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))
local Theme   = require(RS:WaitForChild("Shared"):WaitForChild("UITheme"))

local player = Players.LocalPlayer
local C = Theme.COLORS

local net       = nil
local effects   = nil
local inMatchUI = false   -- im Match sind Menüs gesperrt
local localData = {
	credits = 0, skins = { standard = 1 }, equipped = "standard",
	kills = 0, wins = 0, hatches = 0, luckUntil = 0,
	rating = 1000, pullsSinceLegendary = 0, prime = false,
}

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HatchSnipersUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

function UIController.getScreenGui()
	return screenGui
end

-- ── Kleine Helfer ─────────────────────────────────────────────────────────────
local function label(parent, text, size, pos, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = opts.color or C.text
	l.TextSize = opts.textSize or 16
	l.Font = opts.font or Theme.FONTS.body
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextStrokeTransparency = opts.stroke or 1
	if opts.scaled then l.TextScaled = true end
	l.Parent = parent
	return l
end

local function button(parent, text, size, pos, color, cb)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or C.panel2
	b.Text = text
	b.TextColor3 = C.text
	b.TextSize = 16
	b.Font = Theme.FONTS.header
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	Theme.applyCorner(b)
	b.Parent = parent
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

local function panel(size, pos)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = C.panel
	f.BorderSizePixel = 0
	Theme.applyCorner(f, Theme.CORNER_LG)
	Theme.applyStroke(f)
	f.Visible = false
	f.Parent = screenGui
	return f
end

-- ── Notify-Feed (oben rechts) ─────────────────────────────────────────────────
local notifyStack = {}
function UIController.showNotify(msg)
	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(0, 340, 0, 34)
	n.Position = UDim2.new(1, -352, 0, 70)
	n.BackgroundColor3 = C.panel
	n.BackgroundTransparency = 0.15
	n.Text = "  " .. msg
	n.TextColor3 = C.text
	n.TextSize = 15
	n.Font = Theme.FONTS.body
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextTruncate = Enum.TextTruncate.AtEnd
	n.BorderSizePixel = 0
	n.ZIndex = 30
	Theme.applyCorner(n)
	n.Parent = screenGui

	table.insert(notifyStack, 1, n)
	for i, item in ipairs(notifyStack) do
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.2),
				{ Position = UDim2.new(1, -352, 0, 70 + (i - 1) * 40) }):Play()
		end
	end
	task.delay(4, function()
		for i, item in ipairs(notifyStack) do
			if item == n then
				table.remove(notifyStack, i)
				break
			end
		end
		if n.Parent then
			TweenService:Create(n, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			Debris:AddItem(n, 0.35)
		end
	end)
end

-- ── HUD oben links: Credits, Stats, Luck ──────────────────────────────────────
local hud = Instance.new("Frame")
hud.Size = UDim2.new(0, 240, 0, 86)
hud.Position = UDim2.new(0, 12, 0, 12)
hud.BackgroundColor3 = C.panel
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
Theme.applyCorner(hud, Theme.CORNER_LG)
Theme.applyStroke(hud)
hud.Parent = screenGui

hud.Size = UDim2.new(0, 250, 0, 106)
local creditsLabel = label(hud, "⨀ 0", UDim2.new(1, -16, 0, 30), UDim2.new(0, 12, 0, 6),
	{ color = C.gold, textSize = 24, font = Theme.FONTS.display })
local statsLabel = label(hud, "Kills: 0  ·  Siege: 0", UDim2.new(1, -16, 0, 20), UDim2.new(0, 12, 0, 38),
	{ color = C.textDim, textSize = 14 })
local rankLabel = label(hud, "RANG: —", UDim2.new(1, -16, 0, 20), UDim2.new(0, 12, 0, 58),
	{ color = C.text, textSize = 14, font = Theme.FONTS.header })
local luckLabel = label(hud, "", UDim2.new(1, -16, 0, 20), UDim2.new(0, 12, 0, 78),
	{ color = C.green, textSize = 14 })

-- Build-Version (unten rechts) — zeigt sofort, ob der neueste Stand läuft
local versionLbl = label(screenGui, Config.VERSION, UDim2.new(0, 220, 0, 18), UDim2.new(1, -232, 1, -22),
	{ color = C.textDim, textSize = 12, align = Enum.TextXAlignment.Right, stroke = 0.6 })
versionLbl.ZIndex = 5

-- ── Crosshair + Scope + Cooldown-Bar ──────────────────────────────────────────
local crosshair = label(screenGui, "+", UDim2.new(0, 40, 0, 40), UDim2.new(0.5, -20, 0.5, -20),
	{ color = Color3.fromRGB(255, 255, 255), textSize = 26, align = Enum.TextXAlignment.Center, stroke = 0.4 })
crosshair.ZIndex = 20

-- ── CS:GO-Scope-Overlay: schwarzer Screen mit kreisrundem Ausschnitt ──────────
-- Trick: ein kreisrunder Frame (UICorner 50%) mit RIESIGEM schwarzen UIStroke —
-- der Stroke füllt alles außerhalb des Kreises, 4 Eckframes sichern den Rest.
local scopeOverlay = Instance.new("Frame")
scopeOverlay.Size = UDim2.new(1, 0, 1, 0)
scopeOverlay.BackgroundTransparency = 1
scopeOverlay.Visible = false
scopeOverlay.ZIndex = 18
scopeOverlay.Parent = screenGui

local scopeCircle = Instance.new("Frame")
scopeCircle.AnchorPoint = Vector2.new(0.5, 0.5)
scopeCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
scopeCircle.BackgroundTransparency = 1
scopeCircle.ZIndex = 19
scopeCircle.Parent = scopeOverlay
local circCorner = Instance.new("UICorner")
circCorner.CornerRadius = UDim.new(0.5, 0)
circCorner.Parent = scopeCircle
local circStroke = Instance.new("UIStroke")
circStroke.Color = Color3.fromRGB(0, 0, 0)
circStroke.Thickness = 1600
circStroke.Transparency = 0.02
circStroke.Parent = scopeCircle

-- Fadenkreuz im Scope (dünne Linien + Mil-Dots wie bei der AWP)
local function scopeLine(size, pos)
	local l = Instance.new("Frame")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = size
	l.Position = pos
	l.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	l.BorderSizePixel = 0
	l.ZIndex = 20
	l.Parent = scopeOverlay
	return l
end
scopeLine(UDim2.new(1, 0, 0, 2), UDim2.new(0.5, 0, 0.5, 0))
scopeLine(UDim2.new(0, 2, 1, 0), UDim2.new(0.5, 0, 0.5, 0))
for _, d in ipairs({ -120, -60, 60, 120 }) do
	scopeLine(UDim2.new(0, 2, 0, 10), UDim2.new(0.5, d, 0.5, 0))
	scopeLine(UDim2.new(0, 10, 0, 2), UDim2.new(0.5, 0, 0.5, d))
end

local function fitScopeCircle()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local d = math.min(v.X, v.Y) * 0.92
	scopeCircle.Size = UDim2.new(0, d, 0, d)
end

function UIController.setScopeVisible(state)
	if state then fitScopeCircle() end
	scopeOverlay.Visible = state
	crosshair.Visible = not state
end

local cdBar = Instance.new("Frame")
cdBar.Size = UDim2.new(0, 140, 0, 5)
cdBar.Position = UDim2.new(0.5, -70, 0.5, 32)
cdBar.BackgroundColor3 = C.panel2
cdBar.BorderSizePixel = 0
cdBar.ZIndex = 20
Theme.applyCorner(cdBar, UDim.new(0, 3))
cdBar.Parent = screenGui
local cdFill = Instance.new("Frame")
cdFill.Size = UDim2.new(1, 0, 1, 0)
cdFill.BackgroundColor3 = C.accent2
cdFill.BorderSizePixel = 0
cdFill.ZIndex = 21
Theme.applyCorner(cdFill, UDim.new(0, 3))
cdFill.Parent = cdBar

function UIController.startCooldownBar(duration)
	cdFill.Size = UDim2.new(0, 0, 1, 0)
	TweenService:Create(cdFill, TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(1, 0, 1, 0) }):Play()
end

-- Kampf-HUD (Fadenkreuz + Cooldown-Bar) nur im Match zeigen — in der Lobby
-- wird nicht gesnipet
function UIController.setCombatVisible(state)
	crosshair.Visible = state
	cdBar.Visible = state
end
crosshair.Visible = false   -- Start in der Lobby
cdBar.Visible = false

-- ── Match-HUD (oben Mitte) ────────────────────────────────────────────────────
local matchHud = Instance.new("Frame")
matchHud.Size = UDim2.new(0, 320, 0, 64)
matchHud.Position = UDim2.new(0.5, -160, 0, 10)
matchHud.BackgroundColor3 = C.panel
matchHud.BackgroundTransparency = 0.15
matchHud.BorderSizePixel = 0
matchHud.Visible = false
Theme.applyCorner(matchHud, Theme.CORNER_LG)
Theme.applyStroke(matchHud, C.red)
matchHud.Parent = screenGui

local matchScore = label(matchHud, "0 : 0", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 4),
	{ textSize = 28, font = Theme.FONTS.display, align = Enum.TextXAlignment.Center })
local matchInfo = label(matchHud, "", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 40),
	{ color = C.textDim, textSize = 14, align = Enum.TextXAlignment.Center })

local bigCenter = label(screenGui, "", UDim2.new(0, 600, 0, 110), UDim2.new(0.5, -300, 0.32, 0),
	{ textSize = 72, font = Theme.FONTS.display, align = Enum.TextXAlignment.Center, stroke = 0.3 })
bigCenter.ZIndex = 25

local function flashCenter(text, color, dur)
	bigCenter.Text = text
	bigCenter.TextColor3 = color or C.text
	bigCenter.TextTransparency = 0
	TweenService:Create(bigCenter, TweenInfo.new(dur or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
end

function UIController.onMatchState(payload)
	-- ── Defuse-Mode: eigenes HUD-Format ──
	if payload.mode == "defuse" then
		if payload.state == "countdown" then
			matchHud.Visible = true
			matchScore.Text = "💣 RUNDE " .. (payload.round or 1)
			matchInfo.Text = (payload.yourTeam == "T")
				and "Du greifst AN — leg die Bombe am Platz A!"
				or "Du VERTEIDIGST — halte Platz A!"
			flashCenter(tostring(payload.countdown), C.accent2, 0.9)
			Assets.play2D(Assets.SFX.ChimeSoft, 0.5, 1.3)
		elseif payload.state == "live" then
			matchHud.Visible = true
			matchScore.Text = ("🟠 %d : %d 🔵  ·  R%d"):format(payload.tScore or 0, payload.ctScore or 0, payload.round or 1)
			local roleText = (payload.yourTeam == "T") and "Angreifer 💣" or "Verteidiger 🛡"
			local bombText = payload.bombPlanted
				and ("💣 GELEGT! " .. (payload.timeLeft or 0) .. "s")
				or ((payload.timeLeft or 0) .. "s")
			matchInfo.Text = roleText .. "  ·  " .. bombText
			if payload.youDied then
				flashCenter("💀 Tot bis Rundenende", C.red, 1.6)
			end
		elseif payload.state == "ended" then
			matchHud.Visible = false
			if payload.youWon then
				flashCenter("🏆 DEFUSE GEWONNEN!", C.gold, 2.4)
			else
				flashCenter("Bot-Team gewinnt", C.red, 2.2)
			end
		end
		return
	end

	if payload.state == "countdown" then
		matchHud.Visible = true
		matchScore.Text = "VS " .. (payload.opponent or "?")
		matchInfo.Text = "Match startet…"
		flashCenter(tostring(payload.countdown), C.accent2, 0.9)
		Assets.play2D(Assets.SFX.ChimeSoft, 0.5, 1.2 + (3 - (payload.countdown or 1)) * 0.2)
	elseif payload.state == "live" then
		matchHud.Visible = true
		matchScore.Text = (payload.score and payload.score.you or 0) .. " : " .. (payload.score and payload.score.enemy or 0)
		matchInfo.Text = (payload.opponent or "?") .. "  ·  " .. (payload.timeLeft or 0) .. "s  ·  Erster auf " .. Config.KILLS_TO_WIN
	elseif payload.state == "ended" then
		matchHud.Visible = false
		if payload.youWon then
			flashCenter("🏆 SIEG!", C.gold, 2.2)
		else
			flashCenter(payload.winner ~= "—" and (payload.winner .. " gewinnt") or "Unentschieden", C.red, 2.2)
		end
	end
end

local queueLabel = label(screenGui, "⚔ In der Queue — Pad erneut berühren zum Verlassen",
	UDim2.new(0, 460, 0, 24), UDim2.new(0.5, -230, 0, 78),
	{ color = C.red, textSize = 15, align = Enum.TextXAlignment.Center, stroke = 0.5 })
queueLabel.Visible = false

function UIController.onQueueState(inQueue)
	queueLabel.Visible = inQueue
end

-- ── Ei / Inventar / Index (ein Fenster für alles) ─────────────────────────────
local eggWin = panel(UDim2.new(0, 560, 0, 430), UDim2.new(0.5, -280, 0.5, -215))

label(eggWin, "🥚 " .. Config.EGGS.omega.name .. " — Skins & Index",
	UDim2.new(1, -120, 0, 30), UDim2.new(0, 16, 0, 10),
	{ textSize = 20, font = Theme.FONTS.header })
local oddsNote = label(eggWin, "", UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 0, 40),
	{ color = C.textDim, textSize = 13 })

button(eggWin, "✕", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 8), C.panel2, function()
	eggWin.Visible = false
end)

local hatchBtn = button(eggWin, "ÖFFNEN — " .. Config.EGGS.omega.cost .. " ⨀",
	UDim2.new(0, 230, 0, 42), UDim2.new(0.5, -115, 1, -54), C.accent, function()
		net.HatchEgg:FireServer("omega")
	end)
hatchBtn.TextSize = 18

local luckBtn = button(eggWin, "⚗ Luck Potion (2x Chance)", UDim2.new(0, 180, 0, 30),
	UDim2.new(1, -196, 1, -48), C.panel2, function()
		net.BuyLuck:FireServer()
	end)
luckBtn.TextSize = 13

local grid = Instance.new("ScrollingFrame")
grid.Size = UDim2.new(1, -24, 1, -130)
grid.Position = UDim2.new(0, 12, 0, 62)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.Parent = eggWin
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 125, 0, 64)
gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local skinTiles = {}   -- [skinId] = { frame, owned, equipped }

local function buildSkinGrid()
	-- Katalog sortiert nach Tier-Order, dann Name
	local sorted = table.clone(Skins.CATALOG)
	table.sort(sorted, function(a, b)
		local oa, ob = Skins.TIERS[a.tier].order, Skins.TIERS[b.tier].order
		if oa ~= ob then return oa < ob end
		return a.name < b.name
	end)

	for i, skin in ipairs(sorted) do
		local tile = Instance.new("TextButton")
		tile.LayoutOrder = i
		tile.BackgroundColor3 = C.panel2
		tile.Text = ""
		tile.BorderSizePixel = 0
		tile.AutoButtonColor = true
		Theme.applyCorner(tile)
		local stroke = Theme.applyStroke(tile, Skins.TIERS[skin.tier].color, 1.5)
		tile.Parent = grid

		label(tile, skin.name, UDim2.new(1, -10, 0, 18), UDim2.new(0, 6, 0, 4),
			{ textSize = 13, font = Theme.FONTS.header })
		label(tile, Skins.TIERS[skin.tier].label, UDim2.new(1, -10, 0, 14), UDim2.new(0, 6, 0, 22),
			{ color = Skins.TIERS[skin.tier].color, textSize = 11 })
		local oddsLbl = label(tile, "", UDim2.new(0, 70, 0, 14), UDim2.new(0, 6, 1, -19),
			{ color = C.textDim, textSize = 11 })
		local ownLbl = label(tile, "", UDim2.new(0, 48, 0, 14), UDim2.new(1, -52, 1, -19),
			{ color = C.text, textSize = 11, align = Enum.TextXAlignment.Right })

		tile.MouseButton1Click:Connect(function()
			if (localData.skins[skin.id] or 0) > 0 then
				net.EquipSkin:FireServer(skin.id)
			elseif skin.obtain == "prime" then
				UIController.showNotify("👑 Prime-exklusiv — über das Prime-Menü freischalten!")
			else
				UIController.showNotify("Noch nicht gezogen — Chance: "
					.. string.format("%.2f", Skins.chanceOf(skin.id, false, Config.LUCK_MULTIPLIER)) .. "%")
			end
		end)

		skinTiles[skin.id] = { tile = tile, odds = oddsLbl, own = ownLbl, stroke = stroke }
	end
	grid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#sorted / 4) * 70 + 10)
end
buildSkinGrid()

local function refreshEggWindow()
	local luckOn = os.time() < (localData.luckUntil or 0)
	local pityLeft = math.max(0, Config.PITY_LEGENDARY - (localData.pullsSinceLegendary or 0))
	oddsNote.Text = (luckOn
		and "⚗ LUCK AKTIV — Chancen auf seltene Skins verdoppelt!"
		or "Odds pro Skin sichtbar. Skins sind rein kosmetisch — Schaden ist immer gleich.")
		.. "  ·  Pulls bis garantierte LEGENDE: " .. pityLeft
	for skinId, t in pairs(skinTiles) do
		local count = localData.skins[skinId] or 0
		local chance = Skins.chanceOf(skinId, luckOn, Config.LUCK_MULTIPLIER)
		t.odds.Text = chance > 0 and string.format("%.2f%%", chance) or "PRIME"
		t.own.Text = count > 0 and ("x" .. count) or "—"
		t.own.TextColor3 = count > 0 and C.green or C.textDim
		t.tile.BackgroundColor3 = (localData.equipped == skinId) and Color3.fromRGB(45, 50, 75) or C.panel2
		t.stroke.Thickness = (localData.equipped == skinId) and 3 or 1.5
	end
end

function UIController.openEgg()
	if inMatchUI then
		UIController.showNotify("📦 Nicht im Match — erst das Duell beenden!")
		return
	end
	refreshEggWindow()
	eggWin.Visible = true
end

-- ── Ei-Hatch-Animation (Wackeln → Cracks → Reveal) ───────────────────────────
local hatchOverlay = Instance.new("Frame")
hatchOverlay.Size = UDim2.new(1, 0, 1, 0)
hatchOverlay.BackgroundColor3 = Color3.fromRGB(4, 4, 10)
hatchOverlay.BackgroundTransparency = 0.2
hatchOverlay.BorderSizePixel = 0
hatchOverlay.Visible = false
hatchOverlay.ZIndex = 35
hatchOverlay.Parent = screenGui

label(hatchOverlay, "🥚 " .. Config.EGGS.omega.name, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.12, 0),
	{ textSize = 30, font = Theme.FONTS.display, align = Enum.TextXAlignment.Center, stroke = 0.3 }).ZIndex = 36

local hatchEgg = label(hatchOverlay, "🥚", UDim2.new(0, 220, 0, 220), UDim2.new(0.5, -110, 0.38, -110),
	{ textSize = 150, align = Enum.TextXAlignment.Center })
hatchEgg.ZIndex = 36

local hatchText = label(hatchOverlay, "", UDim2.new(1, 0, 0, 140), UDim2.new(0, 0, 0.6, 0),
	{ textSize = 38, font = Theme.FONTS.display, align = Enum.TextXAlignment.Center, stroke = 0.3 })
hatchText.ZIndex = 36
hatchText.TextWrapped = true

local pityLabel = label(hatchOverlay, "", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.82, 0),
	{ color = C.textDim, textSize = 16, align = Enum.TextXAlignment.Center, stroke = 0.5 })
pityLabel.ZIndex = 36

local hatching = false
function UIController.playHatch(skinId, _count, pityLeft)
	local skin = Skins.BY_ID[skinId]
	if not skin or hatching then
		if skin then
			UIController.showNotify("GEWONNEN: " .. skin.name .. " [" .. Skins.TIERS[skin.tier].label .. "]")
		end
		return
	end
	hatching = true
	local tierColor = Skins.TIERS[skin.tier].color
	local order = Skins.TIERS[skin.tier].order

	hatchOverlay.Visible = true
	hatchText.Text = ""
	pityLabel.Text = ""
	hatchEgg.TextTransparency = 0
	hatchEgg.Rotation = 0
	Assets.play2D(Assets.SFX.DrumRoll, 0.5)

	task.spawn(function()
		-- Wackeln + Cracks — je seltener, desto länger die Spannung
		local shakes = 16 + order * 7
		for i = 1, shakes do
			hatchEgg.Rotation = math.sin(i * 1.7) * (6 + i * 0.7)
			if i % 7 == 0 then
				Assets.play2D((i % 14 == 0) and Assets.SFX.EggCrack2 or Assets.SFX.EggCrack, 0.8)
				effects.shake(0.5)
			end
			task.wait(0.07)
		end

		-- Reveal: "GEWONNEN!"
		Assets.play2D(Assets.SFX.EggCrack2, 1)
		Assets.play2D(Assets.SFX.Chime, order >= 3 and 0.95 or 0.55, 0.9 + order * 0.1)
		hatchEgg.TextTransparency = 1
		hatchText.Text = "GEWONNEN!\n" .. skin.name .. "\nSELTENHEIT: " .. Skins.TIERS[skin.tier].label
			.. (skin.flavor and ("\n\"" .. skin.flavor .. "\"") or "")
		hatchText.TextColor3 = tierColor
		pityLabel.Text = "Pulls bis garantierte LEGENDE: " .. tostring(pityLeft or "—")
		effects.shake(0.6 + order * 0.4)
		if order >= 3 then
			effects.confetti(screenGui, tierColor, 14 + order * 10)
		end

		task.wait(order >= 4 and 3.4 or 2.2)
		hatchOverlay.Visible = false
		hatching = false
		refreshEggWindow()
	end)
end

-- ── Trade-UI ──────────────────────────────────────────────────────────────────
local tradeWin = panel(UDim2.new(0, 520, 0, 420), UDim2.new(0.5, -260, 0.5, -210))
label(tradeWin, "🤝 Trading", UDim2.new(0, 200, 0, 30), UDim2.new(0, 16, 0, 10),
	{ textSize = 20, font = Theme.FONTS.header })
button(tradeWin, "✕", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 8), C.panel2, function()
	tradeWin.Visible = false
	net.TradeCancel:FireServer()
end)

-- Spielerliste (wenn keine Session aktiv)
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, -32, 1, -60)
playerList.Position = UDim2.new(0, 16, 0, 48)
playerList.BackgroundTransparency = 1
playerList.BorderSizePixel = 0
playerList.ScrollBarThickness = 6
playerList.Parent = tradeWin
local plLayout = Instance.new("UIListLayout")
plLayout.Padding = UDim.new(0, 6)
plLayout.Parent = playerList

local function refreshPlayerList()
	for _, c in ipairs(playerList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			count += 1
			local b = button(playerList, "📨 " .. p.Name, UDim2.new(1, -8, 0, 36), UDim2.new(0, 0, 0, 0),
				C.panel2, function()
					net.TradeRequest:FireServer(p)
				end)
			b.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	if count == 0 then
		local empty = label(playerList, "Niemand sonst auf dem Server…", UDim2.new(1, 0, 0, 30),
			UDim2.new(0, 0, 0, 0), { color = C.textDim })
		Debris:AddItem(empty, 10)
	end
	playerList.CanvasSize = UDim2.new(0, 0, 0, count * 42 + 40)
end

-- Session-Ansicht
local sessionFrame = Instance.new("Frame")
sessionFrame.Size = UDim2.new(1, -32, 1, -60)
sessionFrame.Position = UDim2.new(0, 16, 0, 48)
sessionFrame.BackgroundTransparency = 1
sessionFrame.Visible = false
sessionFrame.Parent = tradeWin

local yourOfferLbl  = label(sessionFrame, "Dein Angebot:", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 0), { textSize = 14, font = Theme.FONTS.header })
local yourOfferVal  = label(sessionFrame, "—", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 18), { color = C.accent2, textSize = 14 })
local theirOfferLbl = label(sessionFrame, "Ihr Angebot:", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 42), { textSize = 14, font = Theme.FONTS.header })
local theirOfferVal = label(sessionFrame, "—", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 60), { color = C.gold, textSize = 14 })
local tradeStatus   = label(sessionFrame, "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 84), { color = C.textDim, textSize = 13 })

local invGrid = Instance.new("ScrollingFrame")
invGrid.Size = UDim2.new(1, 0, 1, -160)
invGrid.Position = UDim2.new(0, 0, 0, 108)
invGrid.BackgroundColor3 = C.bg
invGrid.BackgroundTransparency = 0.4
invGrid.BorderSizePixel = 0
invGrid.ScrollBarThickness = 6
Theme.applyCorner(invGrid)
invGrid.Parent = sessionFrame
local invLayout = Instance.new("UIGridLayout")
invLayout.CellSize = UDim2.new(0, 115, 0, 32)
invLayout.CellPadding = UDim2.new(0, 5, 0, 5)
invLayout.Parent = invGrid

local acceptBtn = button(sessionFrame, "✔ Bestätigen", UDim2.new(0, 150, 0, 36), UDim2.new(0, 0, 1, -42),
	C.green, function()
		net.TradeAccept:FireServer()
	end)
button(sessionFrame, "Abbrechen", UDim2.new(0, 120, 0, 36), UDim2.new(0, 160, 1, -42), C.red, function()
	net.TradeCancel:FireServer()
end)

local myOffer = {}   -- Array von skinIds

local function offerText(offer)
	if not offer or #offer == 0 then return "—" end
	local names = {}
	for _, id in ipairs(offer) do
		local s = Skins.BY_ID[id]
		table.insert(names, s and s.name or id)
	end
	return table.concat(names, ", ")
end

local function refreshInvGrid(maxSlots)
	for _, c in ipairs(invGrid:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local n = 0
	for skinId, count in pairs(localData.skins) do
		if skinId ~= "standard" and count > 0 then
			local skin = Skins.BY_ID[skinId]
			if skin then
				n += 1
				local inOffer = 0
				for _, id in ipairs(myOffer) do
					if id == skinId then inOffer += 1 end
				end
				local b = button(invGrid, skin.name .. " x" .. count .. (inOffer > 0 and (" [" .. inOffer .. "]") or ""),
					UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0),
					inOffer > 0 and Color3.fromRGB(40, 70, 50) or C.panel2, function()
						-- Klick: zum Angebot hinzufügen; ist schon alles drin → rausnehmen
						local inOfferNow = 0
						for _, id in ipairs(myOffer) do
							if id == skinId then inOfferNow += 1 end
						end
						if inOfferNow < count and #myOffer < (maxSlots or Config.TRADE_SLOTS) then
							table.insert(myOffer, skinId)
						else
							for i = #myOffer, 1, -1 do
								if myOffer[i] == skinId then table.remove(myOffer, i) end
							end
						end
						net.TradeSetOffer:FireServer(myOffer)
					end)
				b.TextSize = 12
				Theme.applyStroke(b, Skins.TIERS[skin.tier].color, 1)
			end
		end
	end
	invGrid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(n / 4) * 37 + 10)
end

function UIController.onTradeUpdate(payload)
	if payload.state == "request" then
		tradeWin.Visible = true
		playerList.Visible = false
		sessionFrame.Visible = false
		-- Anfrage-Popup
		local pop = Instance.new("Frame")
		pop.Size = UDim2.new(0, 300, 0, 110)
		pop.Position = UDim2.new(0.5, -150, 0, 130)
		pop.BackgroundColor3 = C.panel
		pop.BorderSizePixel = 0
		pop.ZIndex = 38
		Theme.applyCorner(pop, Theme.CORNER_LG)
		Theme.applyStroke(pop, C.accent)
		pop.Parent = screenGui
		local t = label(pop, "📨 Trade-Anfrage von " .. payload.from, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 8),
			{ textSize = 15, font = Theme.FONTS.header })
		t.ZIndex = 39
		t.TextWrapped = true
		local acceptB = button(pop, "Annehmen", UDim2.new(0, 125, 0, 34), UDim2.new(0, 12, 1, -46), C.green, function()
			net.TradeRespond:FireServer(true)
			pop:Destroy()
		end)
		acceptB.ZIndex = 39
		local declineB = button(pop, "Ablehnen", UDim2.new(0, 125, 0, 34), UDim2.new(1, -137, 1, -46), C.red, function()
			net.TradeRespond:FireServer(false)
			pop:Destroy()
		end)
		declineB.ZIndex = 39
		Debris:AddItem(pop, 30)
		Assets.play2D(Assets.SFX.ChimeSoft, 0.6)
	elseif payload.state == "open" then
		tradeWin.Visible = true
		playerList.Visible = false
		sessionFrame.Visible = true
		yourOfferLbl.Text = "Dein Angebot (max. " .. (payload.maxSlots or 3) .. "):"
		yourOfferVal.Text = offerText(payload.yourOffer)
		theirOfferLbl.Text = "Angebot von " .. (payload.partner or "?") .. ":"
		theirOfferVal.Text = offerText(payload.theirOffer)
		tradeStatus.Text = (payload.youAccepted and "✔ Du hast bestätigt" or "⌛ Du: offen")
			.. "   ·   " .. (payload.theyAccepted and "✔ Partner hat bestätigt" or "⌛ Partner: offen")
		acceptBtn.BackgroundColor3 = payload.youAccepted and C.panel2 or C.green
		refreshInvGrid(payload.maxSlots)
	elseif payload.state == "done" or payload.state == "closed" then
		myOffer = {}
		sessionFrame.Visible = false
		tradeWin.Visible = false
		if payload.reason then UIController.showNotify("Trade: " .. payload.reason) end
	end
end

-- ── Wager-Wahl (vor dem 1v1-Queue-Beitritt) ───────────────────────────────────
local wagerWin = panel(UDim2.new(0, 340, 0, 96 + #Config.WAGER_OPTIONS * 0), UDim2.new(0.5, -170, 0.5, -120))
wagerWin.Size = UDim2.new(0, 340, 0, 230)
label(wagerWin, "⚔ NÄCHSTER WAGER: WÄHLEN.", UDim2.new(1, -20, 0, 28), UDim2.new(0, 12, 0, 10),
	{ textSize = 18, font = Theme.FONTS.header })
label(wagerWin, "Sieger nimmt den ganzen Pot. Gleicher Einsatz wird gematcht.",
	UDim2.new(1, -20, 0, 30), UDim2.new(0, 12, 0, 38), { color = C.textDim, textSize = 13 }).TextWrapped = true
button(wagerWin, "✕", UDim2.new(0, 28, 0, 28), UDim2.new(1, -36, 0, 8), C.panel2, function()
	wagerWin.Visible = false
end)
for i, w in ipairs(Config.WAGER_OPTIONS) do
	local col = (i - 1) % 3
	local row = math.floor((i - 1) / 3)
	button(wagerWin,
		w == 0 and "CASUAL (0)" or (w .. " ⨀"),
		UDim2.new(0, 100, 0, 38),
		UDim2.new(0, 12 + col * 106, 0, 76 + row * 46),
		w == 0 and C.panel2 or (w >= 250 and C.red or C.accent2),
		function()
			wagerWin.Visible = false
			net.QueueJoin:FireServer(w)
		end)
end

function UIController.openWager()
	if inMatchUI then return end
	wagerWin.Visible = true
end

-- ── Prime-Status-Menü ─────────────────────────────────────────────────────────
local primeWin = panel(UDim2.new(0, 420, 0, 360), UDim2.new(0.5, -210, 0.5, -180))
Theme.applyStroke(primeWin, C.gold, 2)
label(primeWin, "👑 PRIME STATUS AKTIVIEREN", UDim2.new(1, -60, 0, 32), UDim2.new(0, 16, 0, 12),
	{ color = C.gold, textSize = 21, font = Theme.FONTS.display })
button(primeWin, "✕", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 8), C.panel2, function()
	primeWin.Visible = false
end)
local PRIME_BULLETS = {
	"•  Prime-Matchmaking (nur Prime Spieler)",
	"•  Prime-Exklusive Waffenskins und Auren",
	"•  Verbesserter Rangfortschritt (+25% ELO)",
	"•  Wöchentliche Prime-Belohnungen (" .. Config.PRIME_WEEKLY .. " " .. Config.CURRENCY_NAME .. ")",
}
for i, b in ipairs(PRIME_BULLETS) do
	label(primeWin, b, UDim2.new(1, -32, 0, 26), UDim2.new(0, 20, 0, 48 + (i - 1) * 30),
		{ textSize = 15 })
end
label(primeWin, "Fair bleibt fair: Prime gibt NIEMALS stärkere Waffen.",
	UDim2.new(1, -32, 0, 22), UDim2.new(0, 20, 0, 178), { color = C.textDim, textSize = 12 })
local primeBuyBtn = button(primeWin, "Kaufen für " .. Config.PRIME_PRICE_TEXT,
	UDim2.new(0, 230, 0, 44), UDim2.new(0.5, -115, 0, 216), C.gold, function()
		net.BuyPrime:FireServer()
	end)
primeBuyBtn.TextColor3 = Color3.fromRGB(30, 26, 10)
primeBuyBtn.TextSize = 17
local weeklyBtn = button(primeWin, "👑 Weekly abholen", UDim2.new(0, 230, 0, 36),
	UDim2.new(0.5, -115, 0, 272), C.panel2, function()
		net.ClaimWeekly:FireServer()
	end)
local primeStateLbl = label(primeWin, "", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, -30),
	{ color = C.textDim, textSize = 13, align = Enum.TextXAlignment.Center })

local function refreshPrimeWindow()
	if localData.prime then
		primeBuyBtn.Text = "✔ PRIME AKTIV"
		primeStateLbl.Text = "Danke für deinen Support — viel Spaß mit der Ägis!"
		weeklyBtn.BackgroundColor3 = C.gold
		weeklyBtn.TextColor3 = Color3.fromRGB(30, 26, 10)
	else
		primeBuyBtn.Text = "Kaufen für " .. Config.PRIME_PRICE_TEXT
		primeStateLbl.Text = "Gamepass-ID in Config.lua eintragen, um Prime live zu schalten."
		weeklyBtn.BackgroundColor3 = C.panel2
		weeklyBtn.TextColor3 = C.text
	end
end

-- ── Rangschild am 5v5-Portal (client-seitig — jeder sieht SEINEN Rang) ────────
local rankShieldGui = nil
local function ensureRankShield()
	if rankShieldGui and rankShieldGui.Parent then return rankShieldGui end
	local anchor = workspace:FindFirstChild("RankShieldAnchor", true)
	if not anchor then return nil end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 260, 0, 110)
	bb.MaxDistance = 130
	bb.Parent = anchor

	local shield = Instance.new("Frame")
	shield.Size = UDim2.new(1, 0, 1, 0)
	shield.BackgroundColor3 = C.panel
	shield.BackgroundTransparency = 0.25
	shield.BorderSizePixel = 0
	Theme.applyCorner(shield, Theme.CORNER_LG)
	Theme.applyStroke(shield, C.gold, 2)
	shield.Parent = bb

	local t1 = label(shield, "DEIN RANG:", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 12),
		{ color = C.textDim, textSize = 16, align = Enum.TextXAlignment.Center })
	t1.Name = "RankTitle"
	local t2 = label(shield, "—", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 44),
		{ textSize = 28, font = Theme.FONTS.display, align = Enum.TextXAlignment.Center })
	t2.Name = "RankName"

	rankShieldGui = bb
	return bb
end

local function refreshRankShield()
	local bb = ensureRankShield()
	if not bb then return end
	local rank = Config.rankFor(localData.rating or Config.ELO_START)
	local nameLbl = bb:FindFirstChild("RankName", true)
	if nameLbl then
		nameLbl.Text = rank.name
		nameLbl.TextColor3 = rank.color
	end
end

-- ── Trade-Fenster von außen öffnen (Handelskiosk) ─────────────────────────────
function UIController.openTradeList()
	if inMatchUI then
		UIController.showNotify("🤝 Nicht im Match — erst das Duell beenden!")
		return
	end
	if sessionFrame.Visible then
		tradeWin.Visible = true
		return
	end
	refreshPlayerList()
	playerList.Visible = true
	sessionFrame.Visible = false
	tradeWin.Visible = true
end

-- ── Bottom-Right Buttons ──────────────────────────────────────────────────────
local btnBar = Instance.new("Frame")
btnBar.Size = UDim2.new(0, 64, 0, 372)
btnBar.Position = UDim2.new(1, -76, 1, -384)
btnBar.BackgroundTransparency = 1
btnBar.Parent = screenGui

local function barButton(emoji, tip, yOrder, cb)
	local b = button(btnBar, emoji, UDim2.new(0, 56, 0, 56), UDim2.new(0, 0, 0, (yOrder - 1) * 62), C.panel, cb)
	b.TextSize = 26
	Theme.applyStroke(b, C.accent, 1.5)
	-- Tooltip als kleines Label links daneben (nur bei Hover sichtbar)
	local tipLbl = label(b, tip, UDim2.new(0, 200, 1, 0), UDim2.new(0, -208, 0, 0),
		{ color = C.textDim, textSize = 13, align = Enum.TextXAlignment.Right })
	tipLbl.Visible = false
	b.MouseEnter:Connect(function() tipLbl.Visible = true end)
	b.MouseLeave:Connect(function() tipLbl.Visible = false end)
	return b
end

barButton("🥚", "Omega-Ei & Skins", 1, function()
	refreshEggWindow()
	eggWin.Visible = not eggWin.Visible
end)
barButton("🤝", "Handelsplatz", 2, function()
	if tradeWin.Visible then
		tradeWin.Visible = false
	else
		UIController.openTradeList()
	end
end)
barButton("🎁", "Daily Reward", 3, function()
	net.ClaimDaily:FireServer()
end)
barButton("⚔", "1v1 PvP — Wager wählen (oder rotes Pad)", 4, function()
	UIController.openWager()
end)
barButton("🤖", "1v1 gegen den Bot (oder blaues Pad)", 5, function()
	net.QueueBot:FireServer()
end)
barButton("👑", "Prime Status", 6, function()
	refreshPrimeWindow()
	primeWin.Visible = not primeWin.Visible
end)

-- ── Refresh ───────────────────────────────────────────────────────────────────
local prevCredits = nil
function UIController.refresh(data)
	localData = data
	creditsLabel.Text = "⨀ " .. tostring(data.credits)
	statsLabel.Text = "Kills: " .. (data.kills or 0) .. "  ·  Siege: " .. (data.wins or 0)
		.. "  ·  Pulls: " .. (data.hatches or 0)

	local rank = Config.rankFor(data.rating or Config.ELO_START)
	rankLabel.Text = (data.prime and "👑 " or "") .. "RANG: " .. rank.name
	rankLabel.TextColor3 = rank.color
	refreshRankShield()
	if primeWin.Visible then refreshPrimeWindow() end

	local luckOn = os.time() < (data.luckUntil or 0)
	luckLabel.Text = luckOn
		and ("⚗ Luck aktiv (" .. math.ceil(((data.luckUntil or 0) - os.time()) / 60) .. " min)")
		or ""

	-- Coin-Sound nur bei nennenswerten Gewinnen (nicht beim 5er-Spielzeit-Drip)
	if prevCredits and data.credits - prevCredits >= Config.KILL_REWARD then
		Assets.play2D(Assets.SFX.Coin, 0.25, 1.2)
	end
	prevCredits = data.credits

	if eggWin.Visible then refreshEggWindow() end
end

-- ── Maus-Freigabe für Menüs ───────────────────────────────────────────────────
-- In First Person lockt Roblox die Maus in die Bildmitte → Menü-Buttons sind
-- nicht klickbar und man kommt nicht mehr raus. Solange eines unserer Fenster
-- offen ist, erzwingen wir pro Frame die freie Maus.
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local function anyWindowOpen()
	return eggWin.Visible or tradeWin.Visible or primeWin.Visible
		or wagerWin.Visible or hatchOverlay.Visible
end

RunService.RenderStepped:Connect(function()
	if anyWindowOpen() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

-- Esc-Ersatz: X schließt alle Fenster (zusätzlich zu den ✕-Buttons)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.X and anyWindowOpen() then
		eggWin.Visible = false
		primeWin.Visible = false
		wagerWin.Visible = false
		if tradeWin.Visible then
			tradeWin.Visible = false
			net.TradeCancel:FireServer()
		end
	end
end)

-- Im Match: Menüs zu und gesperrt (kein Case-Opening mitten im Duell)
function UIController.setInMatch(state)
	inMatchUI = state
	if state then
		eggWin.Visible = false
		primeWin.Visible = false
		wagerWin.Visible = false
		tradeWin.Visible = false
	end
end

function UIController.isInMatch()
	return inMatchUI
end

function UIController.init(netRef, effectsCtrl)
	net     = netRef
	effects = effectsCtrl
end

return UIController
