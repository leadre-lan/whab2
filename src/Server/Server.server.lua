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

-- One failing service must never take down the whole game: every init is
-- isolated, errors land in the output instead of killing the script.
local function safeInit(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[BambooSlasher] " .. name .. ".init FEHLER: " .. tostring(err))
	end
end

safeInit("DataService",    DataService.init, net)
safeInit("WorldService",   WorldService.init, DataService, net)
safeInit("HubService",     HubService.init, DataService, net)
safeInit("MonsterService", MonsterService.init, DataService, net)
safeInit("CombatService",  CombatService.init, DataService, MonsterService, net)
safeInit("StatService",    StatService.init, DataService, net)
safeInit("ForgeService",   ForgeService.init, DataService, net)
safeInit("RebirthService", RebirthService.init, DataService, net)
safeInit("ArenaService",   ArenaService.init, DataService, MonsterService, net)

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
