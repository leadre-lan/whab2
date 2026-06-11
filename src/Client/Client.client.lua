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
	"PlaySFX",
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
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

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

-- Musik-IDs leben in Shared/Assets.lua (alle verifiziert; erste ladbare gewinnt)
local TRACK_HUB    = Assets.MUSIC.Hub
local TRACK_FOREST = Assets.MUSIC.Forest
local TRACK_MYSTIC = Assets.MUSIC.Mystic
local TRACK_EPIC   = Assets.MUSIC.Epic
local MUSIC_VOLUME = 0.27

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
				TweenService:Create(music, TweenInfo.new(1.2), { Volume = MUSIC_VOLUME }):Play()
				return
			end
			music:Destroy()
		end
	end)
end

playZoneMusic(0)  -- start with hub music

-- Meshes, Texturen und SFX im Hintergrund vorladen (kein Ruckeln beim ersten
-- Schwerthieb / Treffer)
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	pcall(function()
		ContentProvider:PreloadAsync(Assets.preloadList())
	end)
end)

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

-- ── Post-processing: warm grade + bloom + sun rays ───────────────────────────
-- Cheap, big visual win — softens the blocky look considerably.
local function ensureEffect(class, name, props)
	local e = Lighting:FindFirstChild(name)
	if not e or e.ClassName ~= class then
		if e then e:Destroy() end
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	for k, v in pairs(props) do e[k] = v end
end
ensureEffect("BloomEffect", "GameBloom", { Intensity = 0.4, Size = 32, Threshold = 1.05 })
ensureEffect("ColorCorrectionEffect", "GameGrade", {
	Contrast = 0.06, Saturation = 0.16, TintColor = Color3.fromRGB(255, 252, 244),
})
ensureEffect("SunRaysEffect", "GameSunRays", { Intensity = 0.06, Spread = 0.7 })

-- ── Ambient particles around the player (color follows the biome) ────────────
local ambientEmitter = nil

local function setupAmbientParticles(char)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not root then return end
	local att = Instance.new("Attachment")
	att.Name = "AmbientFX"
	att.Position = Vector3.new(0, 2, 0)
	att.Parent = root

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 1.5
	pe.Lifetime = NumberRange.new(3, 5)
	pe.Speed = NumberRange.new(0.4, 1.2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.18)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.LightEmission = 0.7
	pe.Acceleration = Vector3.new(0, 0.4, 0)
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 244, 200))
	pe.Parent = att
	ambientEmitter = pe
end

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

	-- Music + ambient particles follow the biome
	playZoneMusic(layerIdx)
	if ambientEmitter then
		local c = ld and ld.glowColor or Color3.fromRGB(255, 244, 200)
		ambientEmitter.Color = ColorSequence.new(c)
		ambientEmitter.Rate = ld and 3 or 1
	end
end

net.ApplyLayerLighting.OnClientEvent:Connect(applyZone)

net.HitEffect.OnClientEvent:Connect(function(hitPos, color, died, combo, damage, sliceInfo, kind)
	EffectsCtrl.shake(died and 1.25 or 0.38)
	EffectsCtrl.spawnFragments(hitPos, color, died and 9 or 3)

	-- Every cut (not just the final fell) shows flying pieces + slice sound
	if sliceInfo then
		EffectsCtrl.spawnFallingTops(sliceInfo)
		EffectsCtrl.playSliceSound(sliceInfo.slicePos or hitPos)
	end

	-- Treffer-Sound je nach Ziel (Stein, Monster, Spieler-Schaden)
	if kind and kind ~= "bamboo" then
		EffectsCtrl.playHitSound(kind, hitPos, died)
	end

	if combo then UICtrl.showCombo(combo) end
	if damage then
		local isCrit = combo and combo >= 5
		EffectsCtrl.spawnDamageNum(hitPos, damage, isCrit)
	end
end)

-- Server-seitig ausgelöste UI-/Welt-Sounds (Schmiede, Portal, Rebirth, Daily)
net.PlaySFX.OnClientEvent:Connect(function(key, volume, pitch)
	local id = Assets.SFX[key]
	if id then
		Assets.play2D(id, volume or 0.7, pitch)
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
player.CharacterAdded:Connect(function(char)
	-- Respawn always happens at the hub → reset fog + music (previously the
	-- layer lighting/music stuck around after dying in a layer)
	applyZone(0)
	task.spawn(setupAmbientParticles, char)
	task.wait(0.5)
	InputCtrl.buildSword(localData.swordTier or 1)
	task.wait(0.2)
	InputCtrl.autoEquip()
end)
if player.Character then
	task.spawn(setupAmbientParticles, player.Character)
end

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
