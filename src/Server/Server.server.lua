-- Server.server.lua — Main entry point; wires services together
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Remote Events Setup ───────────────────────────────────────────────────────
-- Destroy old folders from previous versions
for _, name in ipairs({ "BambooRemotes", "BambooNet" }) do
	local old = ReplicatedStorage:FindFirstChild(name)
	if old then old:Destroy() end
end

local remFolder = Instance.new("Folder")
remFolder.Name  = "BambooNet"
remFolder.Parent = ReplicatedStorage

local REMOTE_NAMES = {
	"UpdateData",    -- server → client
	"HitEffect",     -- server → client
	"Notify",        -- server → client
	"LayerUnlocked", -- server → client
	"ChopTarget",    -- client → server
	"SlamAttack",    -- client → server
	"UpgradeStat",   -- client → server (statName)
	"BuySword",      -- client → server (buy next tier)
}

local net = {}
for _, name in ipairs(REMOTE_NAMES) do
	local re = Instance.new("RemoteEvent")
	re.Name  = name
	re.Parent = remFolder
	net[name] = re
end

-- ── Load Services ─────────────────────────────────────────────────────────────
local Services = script.Parent:WaitForChild("Services")

local DataService  = require(Services:WaitForChild("DataService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local StatService  = require(Services:WaitForChild("StatService"))

-- Init order matters: Data first, then World (needs Data), then Stat
DataService.init(net)
WorldService.init(DataService, net)
StatService.init(DataService, net)

-- ── Player Lifecycle ──────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	DataService.load(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		DataService.sendUpdate(player)
	end)

	if player.Character then
		task.wait(0.5)
		DataService.sendUpdate(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	DataService.flush(player)
end)

-- ── Chop / Slam Remotes ───────────────────────────────────────────────────────
net.ChopTarget.OnServerEvent:Connect(function(player, part)
	WorldService.handleChop(player, part)
end)

net.SlamAttack.OnServerEvent:Connect(function(player)
	WorldService.handleSlam(player)
end)

print("[BambooSlasher] Server bereit.")
