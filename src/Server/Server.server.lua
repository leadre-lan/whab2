-- Server.server.lua — Hatch Snipers: Entry Point, Remotes, Service-Wiring
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Remotes ───────────────────────────────────────────────────────────────────
local old = ReplicatedStorage:FindFirstChild("Net")
if old then old:Destroy() end

local netFolder = Instance.new("Folder")
netFolder.Name = "Net"
netFolder.Parent = ReplicatedStorage

local REMOTE_NAMES = {
	-- Server → Client
	"UpdateData", "Notify", "PlaySFX",
	"HatchResult", "OpenEgg",
	"MatchState", "QueueState", "ShotFired", "ScreenFlash",
	"TradeUpdate",
	-- Client → Server
	"HatchEgg", "EquipSkin", "ClaimDaily", "BuyLuck",
	"Shoot", "QueueJoin",
	"TradeRequest", "TradeRespond", "TradeSetOffer", "TradeAccept", "TradeCancel",
}

local net = {}
for _, name in ipairs(REMOTE_NAMES) do
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = netFolder
	net[name] = re
end

-- ── Services laden ────────────────────────────────────────────────────────────
local Services = script.Parent:WaitForChild("Services")

local DataService   = require(Services:WaitForChild("DataService"))
local EggService    = require(Services:WaitForChild("EggService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local ArenaService  = require(Services:WaitForChild("ArenaService"))
local LobbyService  = require(Services:WaitForChild("LobbyService"))
local TradeService  = require(Services:WaitForChild("TradeService"))

-- Ein kaputter Service darf nie den ganzen Server killen
local function safeInit(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[HatchSnipers] " .. name .. ".init FEHLER: " .. tostring(err))
	end
end

safeInit("DataService",   DataService.init, net)
safeInit("WeaponService", WeaponService.init, DataService, net)
safeInit("ArenaService",  ArenaService.init, DataService, WeaponService, net)
safeInit("EggService",    EggService.init, DataService, net)
safeInit("LobbyService",  LobbyService.init, ArenaService, EggService, net)
safeInit("TradeService",  TradeService.init, DataService, WeaponService, net)

WeaponService.setArenaService(ArenaService)

-- ── Player-Lifecycle ──────────────────────────────────────────────────────────
local function onPlayerAdded(player)
	DataService.load(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		WeaponService.giveWeapon(player)
	end)
	if player.Character then
		task.wait(0.3)
		WeaponService.giveWeapon(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Spieler, die während des Server-Inits gejoint sind, nicht verpassen
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[HatchSnipers] Server bereit — GLHF!")
