--!strict
--[[
	Main.server.luau -- bootstrap: loads config, starts services in order.

	Boot order matters and lives here on purpose: services may require other
	services, so the wiring is explicit in one place instead of hidden in
	module-level side effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.Services.DataService)
local DuelService = require(script.Parent.Services.DuelService)
local EconomyService = require(script.Parent.Services.EconomyService)
local InventoryService = require(script.Parent.Services.InventoryService)
local ShopService = require(script.Parent.Services.ShopService)

Net.createAll()

-- DataService first, always. Everything else may read a profile, and a service
-- that reads one before it exists is a service that invents one.
DataService.init()
-- Inventory before duels: it listens for profiles loading, and a profile that
-- loads before it is listening never gets its starter copies.
InventoryService.init()
DuelService.init()
ShopService.init()

-- EconomyService has nothing to wire: it is a gate, not a listener. Required
-- here anyway so a missing module fails at boot rather than mid-duel.
local _ = EconomyService

-- ─────────────────────────────────────────────────────────────────────────────
-- TEMP: MatchmakingService (card D1) does not exist yet, so the queue is this
-- list. It pairs the first two players who ask. When D1 lands, this block moves
-- into MatchmakingService verbatim and gains the bot timeout.

local queue: { Player } = {}

local function tryPair()
	while #queue >= 2 do
		local a, b = queue[1], queue[2]
		table.remove(queue, 2)
		table.remove(queue, 1)

		-- A player can leave between joining the queue and being paired.
		if a.Parent and b.Parent then
			if DuelService.start(a, b) then
				print(`[Main] duel started: {a.Name} vs {b.Name}`)
			end
		end
	end
end

Net.get(Net.names.QueueJoin).OnServerEvent:Connect(function(player: Player)
	if DuelService.isInDuel(player) or table.find(queue, player) then
		return
	end
	table.insert(queue, player)
	print(`[Main] {player.Name} joined the queue ({#queue} waiting)`)
	tryPair()
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────

print("[MasterOfBarter] server ready")
