--!strict
--[[
	Main.server.luau -- bootstrap: loads config, starts services in order.

	Services from `Services/` get wired in here one at a time, following the
	staged plan. Right now the only boot step is creating the remotes, which
	every service will depend on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WaitForChild first so this yields until Rojo/replication has delivered the
-- folder; then index directly, which is the form luau-lsp can resolve types for.
ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)

Net.createAll()

-- TEMP smoke test: proves client -> server -> client works end to end.
-- Delete along with Net.names.Ping when A1 lands.
local ping = Net.get(Net.names.Ping)
ping.OnServerEvent:Connect(function(player: Player)
	print(`[MasterOfBarter] ping received from {player.Name}`)
	ping:FireClient(player, "pong")
end)

print("[MasterOfBarter] server ready")
