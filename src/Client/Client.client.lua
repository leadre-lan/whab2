-- Client.client.lua — Main client entry point
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- ── Wait for server to create remotes ────────────────────────────────────────
-- WaitForChild on EVERY remote: GetChildren() right after the folder appears
-- races against the server still adding remotes — a missing one killed the
-- whole client script (everything after the nil-index never ran).
local netFolder = RS:WaitForChild("BambooNet")
local REMOTE_NAMES = {
	"UpdateData", "HitEffect", "Notify", "LayerUnlocked",
	"OpenLayerSelect", "ApplyLayerLighting", "OpenForge", "RebirthDone",
	"ChopTarget", "SlamAttack", "UpgradeStat",
	"AttackEntity", "SetBlocking",
	"TeleportToLayer", "TeleportToHub",
	"CraftSword", "DoRebirth",
}
local net = {}
for _, name in ipairs(REMOTE_NAMES) do
	net[name] = netFolder:WaitForChild(name)
end

-- ── Load shared modules ───────────────────────────────────────────────────────
local Layers = require(RS:WaitForChild("Shared"):WaitForChild("Layers"))

-- ── Load client controllers ───────────────────────────────────────────────────
local Controllers     = script.Parent:WaitForChild("Controllers")
local EffectsCtrl     = require(Controllers:WaitForChild("EffectsController"))
local UICtrl          = require(Controllers:WaitForChild("UIController"))
local InputCtrl       = require(Controllers:WaitForChild("InputController"))

-- Wire UI buttons to remotes
UICtrl.wireButtons(net)

-- Wire input to remotes + other controllers
InputCtrl.init(net, EffectsCtrl, UICtrl)

-- ── Background Music (per biome) ─────────────────────────────────────────────
-- Each candidate list is tried in order until one loads; the last entries are
-- known-good ids so every zone always ends up with music.
local TweenService = game:GetService("TweenService")

local TRACK_HUB    = { "rbxassetid://1841647093" }                          -- ruhig
local TRACK_FOREST = { "rbxassetid://1843463175", "rbxassetid://1841647093" } -- Grün/Gold
local TRACK_MYSTIC = { "rbxassetid://9046897116", "rbxassetid://1843463175" } -- Kristall/Schatten
local TRACK_EPIC   = { "rbxassetid://1837879082", "rbxassetid://9046897116" } -- Vulkan/Himmel

local function zoneTracks(layerIdx)
	if not layerIdx or layerIdx == 0 then return TRACK_HUB end
	if layerIdx <= 2 then return TRACK_FOREST end
	if layerIdx <= 4 then return TRACK_MYSTIC end
	if layerIdx <= 6 then return TRACK_EPIC end
	return ({ TRACK_FOREST, TRACK_MYSTIC, TRACK_EPIC })[(layerIdx % 3) + 1]
end

local currentMusic     = nil
local currentTrackList = nil

local function playZoneMusic(layerIdx)
	local list = zoneTracks(layerIdx)
	if list == currentTrackList then return end  -- same biome group → keep playing
	currentTrackList = list

	-- Crossfade: fade the old track out…
	if currentMusic then
		local old = currentMusic
		currentMusic = nil
		TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 }):Play()
		task.delay(1.3, function() old:Destroy() end)
	end

	-- …and the new one in (skipping ids that fail to load)
	task.spawn(function()
		for _, id in ipairs(list) do
			local music = Instance.new("Sound")
			music.SoundId = id
			music.Looped  = true
			music.Volume  = 0
			music.Parent  = SoundService

			local waited = 0
			while not music.IsLoaded and waited < 3 do
				task.wait(0.2)
				waited += 0.2
			end

			if music.IsLoaded and music.TimeLength > 0 then
				if list ~= currentTrackList then  -- zone changed while loading
					music:Destroy()
					return
				end
				currentMusic = music
				music:Play()
				TweenService:Create(music, TweenInfo.new(1.2), { Volume = 0.35 }):Play()
				return
			end
			music:Destroy()
		end
	end)
end

playZoneMusic(0)  -- start with hub music

-- ── Local data cache ──────────────────────────────────────────────────────────
local localData = { coins = 0, xp = 0, level = 1, totalFelled = 0, totalMined = 0,
	stats = {}, swordTier = 1, highestLayer = 1 }

-- ── Server → Client events ────────────────────────────────────────────────────
net.UpdateData.OnClientEvent:Connect(function(data)
	local oldTier  = localData.swordTier
	localData      = data

	UICtrl.refresh(data, EffectsCtrl)
	InputCtrl.setDodgeLevel(data.stats and data.stats.dodge or 0)

	if data.swordTier ~= oldTier then
		InputCtrl.buildSword(data.swordTier)
		task.wait(0.2)
		InputCtrl.autoEquip()
	end
end)

-- ── Layer-Select / Forge / Rebirth / Lighting ────────────────────────────────
net.OpenLayerSelect.OnClientEvent:Connect(function()
	UICtrl.openLayerSelect()
end)

net.OpenForge.OnClientEvent:Connect(function()
	UICtrl.openForge()
end)

net.RebirthDone.OnClientEvent:Connect(function(rebirths, mult)
	UICtrl.showNotify("✨ REBIRTH " .. rebirths .. "! Multiplikator: x" .. mult)
	EffectsCtrl.shake(3)
end)

-- Per-player layer lighting (0 = hub)
local Lighting = game:GetService("Lighting")

-- Atmosphere instance: density per layer so the view ends BEFORE the world
-- border — the player must never see the edge.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end

local function applyZone(layerIdx)
	local ld = Layers.DATA[layerIdx]
	local fog, ambient, preset
	if ld then
		fog, ambient = ld.fog, ld.ambient
		preset = ld.lighting
	else
		-- Hub: neutral warm lighting
		fog = { color = Color3.fromRGB(168, 185, 168), start = 120, finish = 400 }
		ambient = Color3.fromRGB(140, 150, 135)
	end
	TweenService:Create(Lighting, TweenInfo.new(1.2), {
		FogColor = fog.color,
		FogStart = fog.start,
		FogEnd   = fog.finish,
		OutdoorAmbient = ambient,
		ClockTime = (preset and preset.clockTime) or 14,
	}):Play()
	TweenService:Create(atmosphere, TweenInfo.new(1.2), {
		Density = (preset and preset.atmoDensity) or 0.3,
		Color   = (preset and preset.atmoColor) or fog.color,
		Haze    = 2,
	}):Play()

	-- Music follows the biome
	playZoneMusic(layerIdx)
end

net.ApplyLayerLighting.OnClientEvent:Connect(applyZone)

net.HitEffect.OnClientEvent:Connect(function(hitPos, color, died, combo, damage, sliceInfo)
	EffectsCtrl.shake(died and 1.25 or 0.38)
	EffectsCtrl.spawnFragments(hitPos, color, died and 9 or 3)

	if died then
		EffectsCtrl.spawnFallingTops(sliceInfo)
		EffectsCtrl.playSliceSound((sliceInfo and sliceInfo.slicePos) or hitPos)
	end

	if combo then UICtrl.showCombo(combo) end
	if damage then
		local isCrit = combo and combo >= 5
		EffectsCtrl.spawnDamageNum(hitPos, damage, isCrit)
	end
end)

net.Notify.OnClientEvent:Connect(function(msg)
	UICtrl.showNotify(msg)
end)

net.LayerUnlocked.OnClientEvent:Connect(function(layerIdx)
	local ld = Layers.DATA[layerIdx]
	if ld then
		UICtrl.showNotify("🔓 " .. ld.name .. " freigeschaltet!")
		EffectsCtrl.showLayerUnlocked(UICtrl.getScreenGui(), ld.name, ld.glowColor)
	end
end)

-- ── Character lifecycle ───────────────────────────────────────────────────────
player.CharacterAdded:Connect(function()
	-- Respawn always happens at the hub → reset fog + music (previously the
	-- layer lighting/music stuck around after dying in a layer)
	applyZone(0)
	task.wait(0.5)
	InputCtrl.buildSword(localData.swordTier or 1)
	task.wait(0.2)
	InputCtrl.autoEquip()
end)

-- Auto-equip loop
task.spawn(function()
	while true do
		task.wait(1.5)
		InputCtrl.autoEquip()
	end
end)

-- ── Controls hint (bottom-left) ───────────────────────────────────────────────
do
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 340, 0, 24)
	hint.Position = UDim2.new(0, 12, 1, -32)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(200, 205, 220)
	hint.TextStrokeTransparency = 0.5
	hint.TextSize = 13
	hint.Font = Enum.Font.Gotham
	hint.Text = "🖱 Klick: Schlagen  |  Q: Dash  |  F: Block  |  E: Interagieren"
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = UICtrl.getScreenGui()
end

-- ── Init: build sword and show HUD ───────────────────────────────────────────
task.wait(0.5)
InputCtrl.buildSword(1)
UICtrl.refresh(localData, nil)
task.wait(0.3)
InputCtrl.autoEquip()
