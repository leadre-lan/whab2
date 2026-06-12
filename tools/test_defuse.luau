-- Test-Harness: führt LobbyService.init mit Stubs aus, um Build-Crashes zu finden
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local Instance = roblox.Instance

-- ── Stubs ─────────────────────────────────────────────────────────────────────
local workspaceStub = Instance.new("Model")
workspaceStub.Name = "Workspace"

local servicesStub = {}

local function makeRemote(name)
	return setmetatable({}, { __index = function(_, k)
		if k == "FireClient" or k == "FireAllClients" then
			return function() end
		end
		if k == "OnServerEvent" then
			return { Connect = function() return { Disconnect = function() end } end }
		end
		error("remote field " .. tostring(k))
	end })
end
local netStub = setmetatable({}, { __index = function(_, k) return makeRemote(k) end })

local loaded = {}
local function loadModule(path, name)
	if loaded[name] then return loaded[name] end
	local src = fs.readFile(path)
	local env
	local fn = luau.load(src, { debugName = name, environment = nil })
	-- environment: Lune injiziert Roblox-Datentypen via load-Options nicht automatisch;
	-- wir bauen ein Env-Table:
	local result = fn()
	loaded[name] = result
	return result
end

-- Wir brauchen ein gemeinsames Environment mit Roblox-Globals:
local sharedModules = {}

local function gameGetService(_, svc)
	if svc == "ReplicatedStorage" then
		return {
			WaitForChild = function(_, name)
				if name == "Shared" then
					return {
						WaitForChild = function(_, mod)
							return { __module = mod }
						end,
					}
				end
				error("RS child " .. name)
			end,
			FindFirstChild = function() return nil end,
		}
	elseif svc == "Players" then
		return { GetPlayers = function() return {} end, PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function() end } }
	elseif svc == "CollectionService" then
		return setmetatable({}, { __index = function(_, k)
			if k == "AddTag" then return function(_, inst, tag) inst:AddTag(tag) end end
			if k == "HasTag" then return function(_, inst, tag) return inst:HasTag(tag) end end
			error("CollectionService." .. k)
		end })
	elseif svc == "SoundService" or svc == "Debris" or svc == "TweenService" then
		return setmetatable({}, { __index = function() return function() end end })
	end
	error("service " .. svc)
end

local function makeEnv()
	local env
	env = {
		game = setmetatable({}, { __index = function(_, k)
			if k == "GetService" then return gameGetService end
			error("game." .. k)
		end }),
		workspace = workspaceStub,
		Instance = Instance,
		Vector3 = roblox.Vector3 or Vector3,
		CFrame = roblox.CFrame or CFrame,
		Color3 = roblox.Color3 or Color3,
		UDim2 = roblox.UDim2 or UDim2,
		UDim = roblox.UDim or UDim,
		Enum = roblox.Enum or Enum,
		Vector2 = roblox.Vector2 or Vector2,
		Random = roblox.Random or {
			new = function(seed)
				local state = seed or 0
				local function nxt()
					state = (state * 1103515245 + 12345) % 2147483648
					return state / 2147483648
				end
				return {
					NextNumber = function(_, a, b)
						if a then return a + nxt() * (b - a) end
						return nxt()
					end,
					NextInteger = function(_, a, b)
						return a + math.floor(nxt() * (b - a + 1))
					end,
				}
			end,
		},
		NumberRange = roblox.NumberRange or NumberRange,
		NumberSequence = roblox.NumberSequence or NumberSequence,
		ColorSequence = roblox.ColorSequence or ColorSequence,
		math = math, table = table, string = string, ipairs = ipairs, pairs = pairs,
		print = print, warn = warn, error = error, tostring = tostring, tonumber = tonumber,
		setmetatable = setmetatable, getmetatable = getmetatable, type = type, typeof = typeof,
		pcall = pcall, select = select, os = os, unpack = unpack,
		noop = function() end,
		task = { spawn = function() end, wait = function() end, delay = function() end, defer = function() end },
		require = nil,   -- unten gesetzt
		script = nil,
	}
	env.require = function(target)
		local mod = target.__module
		if not sharedModules[mod] then
			local src = fs.readFile("src/Shared/" .. mod .. ".lua")
			local f = luau.load(src, { debugName = mod, environment = makeEnv() })
			sharedModules[mod] = f()
		end
		return sharedModules[mod]
	end
	return env
end

-- ── LobbyService laden + init ausführen ──────────────────────────────────────
local src = fs.readFile("src/Server/Services/DefuseService.lua")
-- Lune kennt keine Instanz-Events: .Triggered/.Touched-Connects zu No-Ops machen
src = string.gsub(src, "[%w_]+%.Triggered:Connect%(", "noop(")
-- Lune kann .Position nicht aus CFrame ableiten: im part()-Helper beides setzen
src = string.gsub(src,
	"if props%.cframe then p%.CFrame = props%.cframe else p%.Position = props%.pos end",
	"if props.cframe then p.CFrame = props.cframe p.Position = props.cframe.Position else p.Position = props.pos end")
src = string.gsub(src, "[%w_]+%.Touched:Connect%(", "noop(")
local f = luau.load(src, { debugName = "DefuseService", environment = makeEnv() })
local DefuseService = f()

local arenaStub = {
	toggleQueue = function() end,
	startBotMatch = function() end,
	isQueued = function() return false end,
	getActiveDuelCount = function() return 0 end,
}
local eggStub = { claimDaily = function() end }
local dataStub = { eachPlayer = function() return pairs({}) end, get = function() return nil end }

local botStub = { spawn = function() return { model = Instance.new("Model"), alive = true, kill = function() end, destroy = function() end, setRoute = function() end } end }
local ok, err = pcall(function()
	DefuseService.init(dataStub, botStub, netStub)
end)
print("RESULT:", ok, err)
print("DefuseMap children:", #workspaceStub:FindFirstChild("DefuseMap"):GetChildren())
