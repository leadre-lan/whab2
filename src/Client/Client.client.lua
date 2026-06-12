-- Client.client.lua — Hatch Snipers: Entry Point, Musik, Lighting, Event-Routing
local RS           = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

-- ── Remotes (WaitForChild auf JEDES — Race gegen Server-Init vermeiden) ───────
local netFolder = RS:WaitForChild("Net")
local REMOTE_NAMES = {
	"UpdateData", "Notify", "PlaySFX",
	"HatchResult", "OpenEgg", "OpenWager", "OpenTrade",
	"MatchState", "QueueState", "ShotFired", "ScreenFlash",
	"TradeUpdate",
	"HatchEgg", "EquipSkin", "ClaimDaily", "BuyLuck",
	"Shoot", "DoSlide", "QueueJoin", "QueueBot",
	"TradeRequest", "TradeRespond", "TradeSetOffer", "TradeAccept", "TradeCancel",
	"BuyPrime", "ClaimWeekly",
}
local net = {}
for _, name in ipairs(REMOTE_NAMES) do
	net[name] = netFolder:WaitForChild(name)
end

-- ── Module / Controller ───────────────────────────────────────────────────────
local Assets = require(RS:WaitForChild("Shared"):WaitForChild("Assets"))

local Controllers      = script.Parent:WaitForChild("Controllers")
local EffectsCtrl      = require(Controllers:WaitForChild("EffectsController"))
local UICtrl           = require(Controllers:WaitForChild("UIController"))
local WeaponCtrl       = require(Controllers:WaitForChild("WeaponController"))

UICtrl.init(net, EffectsCtrl)
WeaponCtrl.init(net, EffectsCtrl, UICtrl)

-- ── Lighting 2.0: tiefes Schwarz + KNALLIGES Neon (Cyber-Punch) ───────────────
-- Wenig Ambient = Kontrast, fettes Bloom = Glow. Die Licht-Pylonen/Flutlichter
-- übernehmen die Lesbarkeit von Spielern und Waffen.
Lighting.ClockTime = 0
Lighting.Brightness = 2.2
Lighting.ExposureCompensation = 0.15
Lighting.ShadowSoftness = 0.25
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.OutdoorAmbient = Color3.fromRGB(82, 82, 110)
Lighting.Ambient = Color3.fromRGB(48, 48, 70)
Lighting.FogColor = Color3.fromRGB(16, 14, 28)
Lighting.FogStart = 180
Lighting.FogEnd = 750

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
-- Fettes Neon-Bloom: alles Leuchtende glüht satt (der "bloomy" Look)
ensureEffect("BloomEffect", "GameBloom", { Intensity = 1.1, Size = 48, Threshold = 0.85 })
-- Cinematic Grade: Kontrast + satte Farben
ensureEffect("ColorCorrectionEffect", "GameGrade", {
	Contrast = 0.12, Saturation = 0.24, Brightness = 0.01,
	TintColor = Color3.fromRGB(250, 244, 255),
})
-- Dezente Tiefenschärfe: Distanz weicht auf → wirkt sofort gerendert
ensureEffect("DepthOfFieldEffect", "GameDOF", {
	FarIntensity = 0.15, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 48,
})
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
atmosphere.Density = 0.3
atmosphere.Color = Color3.fromRGB(80, 60, 125)
atmosphere.Haze = 2

-- ── Musik (Lobby ↔ Arena, Crossfade; erste ladbare ID gewinnt) ────────────────
local MUSIC_VOLUME = 0.25
local currentMusic = nil
local currentList  = nil

local function playMusic(list)
	if list == currentList then return end
	currentList = list

	if currentMusic then
		local old = currentMusic
		currentMusic = nil
		TweenService:Create(old, TweenInfo.new(1.0), { Volume = 0 }):Play()
		task.delay(1.1, function() old:Destroy() end)
	end

	task.spawn(function()
		for _, id in ipairs(list) do
			local music = Instance.new("Sound")
			music.SoundId = id
			music.Looped = true
			music.Volume = 0
			music.Parent = SoundService

			local waited = 0
			while not music.IsLoaded and waited < 3 do
				task.wait(0.2)
				waited += 0.2
			end
			if music.IsLoaded and music.TimeLength > 0 then
				if list ~= currentList then
					music:Destroy()
					return
				end
				currentMusic = music
				music:Play()
				TweenService:Create(music, TweenInfo.new(1.0), { Volume = MUSIC_VOLUME }):Play()
				return
			end
			music:Destroy()
		end
	end)
end

playMusic(Assets.MUSIC.Lobby)

-- ── Skin-Texturen (CS-Style: Fade, Galaxie, Flammen …) ────────────────────────
-- Der Server taggt jeden AWP-Mesh-Körper mit "SkinBody" + SkinId; jeder Client
-- generiert die Textur deterministisch (EditableImage) und legt sie lokal
-- drauf → alle sehen denselben Skin, ganz ohne Asset-Uploads.
do
	local CollectionService = game:GetService("CollectionService")
	local SkinTextures = require(RS:WaitForChild("Shared"):WaitForChild("SkinTextures"))

	local function applySkinTexture(part)
		if not part:IsA("MeshPart") then return end
		task.spawn(function()
			local content = SkinTextures.get(part:GetAttribute("SkinId"))
			if content and part.Parent then
				pcall(function()
					part.TextureContent = content
				end)
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal("SkinBody"):Connect(applySkinTexture)
	for _, part in ipairs(CollectionService:GetTagged("SkinBody")) do
		applySkinTexture(part)
	end

	-- Umgebungs-Texturen: getaggte Parts ("EnvTexture") bekommen kachelnde
	-- Oberflächen (Tech-Panels, gravierter Stein) statt flacher Farben
	local function applyEnvTexture(part)
		if not part:IsA("BasePart") then return end
		task.spawn(function()
			local content = SkinTextures.getEnv(part:GetAttribute("EnvKind") or "panels")
			if not content or not part.Parent then return end
			local studs = part:GetAttribute("EnvStuds") or 16
			for face in string.gmatch(part:GetAttribute("EnvFaces") or "Top", "[^,]+") do
				pcall(function()
					local tex = Instance.new("Texture")
					tex.Face = Enum.NormalId[face]
					tex.StudsPerTileU = studs
					tex.StudsPerTileV = studs
					tex.TextureContent = content
					tex.Transparency = part:GetAttribute("EnvAlpha") or 0.25
					tex.Parent = part
				end)
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal("EnvTexture"):Connect(applyEnvTexture)
	for _, part in ipairs(CollectionService:GetTagged("EnvTexture")) do
		applyEnvTexture(part)
	end
end

-- ── Preload (kein Ruckeln beim ersten Schuss/Hatch) ───────────────────────────
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	pcall(function()
		ContentProvider:PreloadAsync(Assets.preloadList())
	end)
end)

-- AWP-Sounds testen: erste ladbare ID gewinnt, sonst verifizierter Fallback
Assets.resolveSfx()

-- ── Server → Client Events ────────────────────────────────────────────────────
net.UpdateData.OnClientEvent:Connect(function(data)
	UICtrl.refresh(data)
end)

net.Notify.OnClientEvent:Connect(function(msg)
	UICtrl.showNotify(msg)
end)

net.PlaySFX.OnClientEvent:Connect(function(key, volume, pitch)
	local id = Assets.SFX[key]
	if id then
		Assets.play2D(id, volume or 0.7, pitch)
	end
end)

net.OpenEgg.OnClientEvent:Connect(function()
	UICtrl.openEgg()
end)

net.OpenWager.OnClientEvent:Connect(function()
	UICtrl.openWager()
end)

net.OpenTrade.OnClientEvent:Connect(function()
	UICtrl.openTradeList()
end)

net.HatchResult.OnClientEvent:Connect(function(skinId, count, pityLeft)
	UICtrl.playHatch(skinId, count, pityLeft)
end)

net.ShotFired.OnClientEvent:Connect(function(fromPos, toPos, skinId, didKill)
	EffectsCtrl.spawnTracer(fromPos, toPos, skinId, didKill)
	EffectsCtrl.playShotSound(fromPos, skinId)
end)

net.ScreenFlash.OnClientEvent:Connect(function(color)
	EffectsCtrl.screenFlash(UICtrl.getScreenGui(), color)
end)

net.MatchState.OnClientEvent:Connect(function(payload)
	UICtrl.onMatchState(payload)
	if payload.state == "countdown" or payload.state == "live" then
		playMusic(Assets.MUSIC.Arena)
		WeaponCtrl.setInMatch(true)   -- Ego-Zwang + Waffe scharf
	elseif payload.state == "ended" then
		playMusic(Assets.MUSIC.Lobby)
		WeaponCtrl.setInMatch(false)
	end
end)

net.QueueState.OnClientEvent:Connect(function(inQueue)
	UICtrl.onQueueState(inQueue)
end)

net.TradeUpdate.OnClientEvent:Connect(function(payload)
	UICtrl.onTradeUpdate(payload)
end)

-- ── Steuerungs-Hinweis ────────────────────────────────────────────────────────
do
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 460, 0, 22)
	hint.Position = UDim2.new(0, 12, 1, -30)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(190, 195, 215)
	hint.TextStrokeTransparency = 0.5
	hint.TextSize = 13
	hint.Font = Enum.Font.Gotham
	hint.Text = "⚔ Snipen nur in der Arena  |  Rechtsklick: Scope  |  Ctrl/C: Slide  |  E: Interagieren"
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = UICtrl.getScreenGui()
end

print("[HatchSnipers] Client bereit.")
