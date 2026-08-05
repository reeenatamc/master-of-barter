--!strict
--[[
	Main.server.luau -- bootstrap: loads config, starts services in order.

	Boot order matters and lives here on purpose: services may require other
	services, so the wiring is explicit in one place instead of hidden in
	module-level side effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)

local BotService = require(script.Parent.Services.BotService)
local DataService = require(script.Parent.Services.DataService)
local DuelService = require(script.Parent.Services.DuelService)
local EconomyService = require(script.Parent.Services.EconomyService)
local InventoryService = require(script.Parent.Services.InventoryService)
local MatchmakingService = require(script.Parent.Services.MatchmakingService)
local ShopService = require(script.Parent.Services.ShopService)

Net.createAll()

-- DataService first, always. Everything else may read a profile, and a service
-- that reads one before it exists is a service that invents one.
DataService.init()
-- Inventory before duels: it listens for profiles loading, and a profile that
-- loads before it is listening never gets its starter copies.
InventoryService.init()
DuelService.init()
-- Bots before matchmaking: matchmaking can start a bot duel on its first tick,
-- and a bot whose brain is not listening yet sits still for the whole duel.
BotService.init()
MatchmakingService.init()
ShopService.init()

-- EconomyService has nothing to wire: it is a gate, not a listener. Required
-- here anyway so a missing module fails at boot rather than mid-duel.
local _ = EconomyService

print("[MasterOfBarter] server ready")
