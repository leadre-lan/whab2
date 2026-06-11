-- Server.server.lua — Main entry point; wires all services together
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Remote Events Setup ───────────────────────────────────────────────────────
for _, name in ipairs({ "BambooRemotes", "BambooNet" }) do
	local old = ReplicatedStorage:FindFirstChild(name)
	if old then old:Destroy() end
end

local remFolder = Instance.new("Folder")
remFolder.Name  = "BambooNet"
remFolder.Parent = ReplicatedStorage

local REMOTE_NAMES = {
	-- server → client
	"UpdateData", "HitEffect", "Notify", "LayerUnlocked",
	"OpenLayerSelect", "ApplyLayerLighting", "OpenForge", "RebirthDone",
	-- client → server
	"ChopTarget", "SlamAttack", "UpgradeStat",
	"AttackEntity", "SetBlocking",
	"TeleportToLayer", "TeleportToHub",
	"CraftSword", "DoRebirth",
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

local DataService    = require(Services:WaitForChild("DataService"))
local WorldService   = require(Services:WaitForChild("WorldService"))
local StatService    = require(Services:WaitForChild("StatService"))
local HubService     = require(Services:WaitForChild("HubService"))
local MonsterService = require(Services:WaitForChild("MonsterService"))
local CombatService  = require(Services:WaitForChild("CombatService"))
local ForgeService   = require(Services:WaitForChild("ForgeService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))
local ArenaService   = require(Services:WaitForChild("ArenaService"))

DataService.init(net)
WorldService.init(DataService, net)
HubService.init(DataService, net)
MonsterService.init(DataService, net)
CombatService.init(DataService, MonsterService, net)
StatService.init(DataService, net)
ForgeService.init(DataService, net)
RebirthService.init(DataService, net)
ArenaService.init(DataService, net)

-- Cross-service wiring
CombatService.setArenaService(ArenaService)
HubService.rebirthHandler = RebirthService.tryRebirth

-- ── Player Lifecycle ──────────────────────────────────────────────────────────
local Balance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Balance"))

Players.PlayerAdded:Connect(function(player)
	DataService.load(player)

	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		-- Apply stamina HP bonus
		local pdata = DataService.get(player)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if pdata and hum then
			hum.MaxHealth = 100 + (pdata.stats.stamina or 0) * Balance.STAMINA_HP_BONUS
			hum.Health = hum.MaxHealth
		end
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

-- ── World interaction remotes ─────────────────────────────────────────────────
net.ChopTarget.OnServerEvent:Connect(function(player, part)
	WorldService.handleChop(player, part)
end)

net.SlamAttack.OnServerEvent:Connect(function(player)
	WorldService.handleSlam(player)
end)

print("[BambooSlasher] Server bereit — alle Systeme online.")
