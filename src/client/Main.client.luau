--!strict
--[[
	Main.client.luau -- client bootstrap.

	Controllers from `Controllers/` get wired in here one at a time. For now it
	only opens the channel to the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WaitForChild first so this yields until replication has delivered the folder;
-- then index directly, which is the form luau-lsp can resolve types for.
ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)

print("[MasterOfBarter] client ready")

-- TEMP smoke test: fire once and print whatever comes back.
-- Delete along with Net.names.Ping when A1 lands.
local ping = Net.get(Net.names.Ping)
ping.OnClientEvent:Connect(function(message: string)
	print(`[MasterOfBarter] server answered: {message}`)
end)
ping:FireServer()
