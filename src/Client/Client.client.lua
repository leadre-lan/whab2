-- Client.client.lua — Main client entry point
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- ── Wait for server to create remotes ────────────────────────────────────────
local netFolder = RS:WaitForChild("BambooNet", 15)
local net = {}
for _, re in ipairs(netFolder:GetChildren()) do
	net[re.Name] = re
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

-- ── Background Music ──────────────────────────────────────────────────────────
local MUSIC_IDS = {
	"rbxassetid://1841647093",
	"rbxassetid://1843463175",
	"rbxassetid://9046897116",
	"rbxassetid://1837879082",
}

task.spawn(function()
	for _, id in ipairs(MUSIC_IDS) do
		local music = Instance.new("Sound")
		music.SoundId = id
		music.Looped  = true
		music.Volume  = 0.35
		music.Parent  = SoundService

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
end)

-- ── Local data cache ──────────────────────────────────────────────────────────
local localData = { coins = 0, xp = 0, level = 1, totalFelled = 0, totalMined = 0,
	stats = {}, swordTier = 1, highestLayer = 1 }

-- ── Server → Client events ────────────────────────────────────────────────────
net.UpdateData.OnClientEvent:Connect(function(data)
	local oldTier  = localData.swordTier
	localData      = data

	UICtrl.refresh(data, EffectsCtrl)

	if data.swordTier ~= oldTier then
		InputCtrl.buildSword(data.swordTier)
		task.wait(0.2)
		InputCtrl.autoEquip()
	end
end)

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

-- ── Init: build sword and show HUD ───────────────────────────────────────────
task.wait(0.5)
InputCtrl.buildSword(1)
UICtrl.refresh(localData, nil)
task.wait(0.3)
InputCtrl.autoEquip()
