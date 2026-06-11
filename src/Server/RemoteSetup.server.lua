-- RemoteSetup.server.lua
-- Place as a Script in ServerScriptService.
-- This script MUST run before BambooWorld and GameManager so that
-- RemoteEvents exist when the other scripts require them.
-- Set its RunContext to "Server" and give it a low load order
-- (e.g. name it "01_RemoteSetup" or rely on alphabetical order).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create a container folder so clients can find remotes easily
local remotesFolder = Instance.new("Folder")
remotesFolder.Name  = "BambooRemotes"
remotesFolder.Parent = ReplicatedStorage

-- Helper: create a named RemoteEvent inside the folder
local function makeEvent(name)
	local re      = Instance.new("RemoteEvent")
	re.Name       = name
	re.Parent     = remotesFolder
	return re
end

-- ChopBamboo  : Client → Server  (part reference)
makeEvent("ChopBamboo")

-- BuyUpgrade  : Client → Server  (no arguments needed)
makeEvent("BuyUpgrade")

-- UpdateData  : Server → Client  (table: coins, swordLevel, totalChopped)
makeEvent("UpdateData")

print("[RemoteSetup] BambooRemotes folder created with 3 RemoteEvents.")
