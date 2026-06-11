-- Client.client.lua — Hatch Snipers: Entry Point, Musik, Lighting, Event-Routing
local RS           = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

-- ── Remotes (WaitForChild auf JEDES — Race gegen Server-Init vermeiden) ───────
local netFolder = RS:WaitForChild("Net")
local REMOTE_NAMES = {
	"UpdateData", "Notify", "PlaySFX",
	"HatchResult", "OpenEgg",
	"MatchState", "QueueState", "ShotFired", "ScreenFlash",
	"TradeUpdate",
	"HatchEgg", "EquipSkin", "ClaimDaily", "BuyLuck",
	"Shoot", "QueueJoin",
	"TradeRequest", "TradeRespond", "TradeSetOffer", "TradeAccept", "TradeCancel",
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

-- ── Lighting: Nacht + Neon (Cyber-Lobby-Look) ─────────────────────────────────
Lighting.ClockTime = 0
Lighting.Brightness = 1.6
Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 95)
Lighting.FogColor = Color3.fromRGB(18, 16, 30)
Lighting.FogStart = 150
Lighting.FogEnd = 650

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
ensureEffect("BloomEffect", "GameBloom", { Intensity = 0.65, Size = 40, Threshold = 0.95 })
ensureEffect("ColorCorrectionEffect", "GameGrade", {
	Contrast = 0.1, Saturation = 0.22, TintColor = Color3.fromRGB(245, 242, 255),
})
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
atmosphere.Density = 0.35
atmosphere.Color = Color3.fromRGB(80, 60, 120)
atmosphere.Haze = 2.2

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

-- ── Preload (kein Ruckeln beim ersten Schuss/Hatch) ───────────────────────────
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	pcall(function()
		ContentProvider:PreloadAsync(Assets.preloadList())
	end)
end)

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

net.HatchResult.OnClientEvent:Connect(function(skinId)
	UICtrl.playHatch(skinId)
end)

net.ShotFired.OnClientEvent:Connect(function(fromPos, toPos, skinId, didKill)
	EffectsCtrl.spawnTracer(fromPos, toPos, skinId, didKill)
end)

net.ScreenFlash.OnClientEvent:Connect(function(color)
	EffectsCtrl.screenFlash(UICtrl.getScreenGui(), color)
end)

net.MatchState.OnClientEvent:Connect(function(payload)
	UICtrl.onMatchState(payload)
	if payload.state == "countdown" or payload.state == "live" then
		playMusic(Assets.MUSIC.Arena)
	elseif payload.state == "ended" then
		playMusic(Assets.MUSIC.Lobby)
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
	hint.Text = "🖱 Klick: Schießen  |  Rechtsklick: Scope  |  E: Interagieren  |  Rotes Pad: 1v1"
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = UICtrl.getScreenGui()
end

print("[HatchSnipers] Client bereit.")
