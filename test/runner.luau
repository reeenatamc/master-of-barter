-- ─────────────────────────────────────────────────────────────────────────────
-- Stubs for the two services this harness deliberately does NOT exercise.
-- ─────────────────────────────────────────────────────────────────────────────

local Signal = require(Util.Signal)
local Types = require(Shared.Types)
local Economy = require(Config.Economy)

--- The scene is Instance/CFrame work with nothing to assert headlessly.
registry[node("DuelSceneService", Services)] = function()
	return {
		open = function()
			return function() end
		end,
	}
end

--- In-memory profiles. This is NOT ProfileStore: saving, session locking and
--- migrations are checkpoint 3's job and are not claimed here. What it does give
--- is a real profile SHAPE, so InventoryService, EconomyService and the escrow
--- ledger run against something that can actually hold state.
local profiles: { [any]: any } = {}
local DataStub = {
	profileLoaded = Signal.new(),
	profileReleased = Signal.new(),
	get = function(player)
		return profiles[player]
	end,
	isSpectator = function(player)
		return profiles[player] == nil
	end,
}
registry[node("DataService", Services)] = function()
	return DataStub
end

-- ─────────────────────────────────────────────────────────────────────────────

local Net = require(Util.Net)
local DuelRules = require(Config.DuelRules)
local DuelService = require(Services.DuelService)
local BotService = require(Services.BotService)
local InventoryService = require(Services.InventoryService)

Net.createAll()
DuelRules.debugLogs = true

InventoryService.init()
DuelService.init()
BotService.init()

--- A player with a profile, the way DataService would hand one over.
local function addPlayer(name: string)
	local player = { Name = name, DisplayName = name, UserId = 1, Parent = PlayersService }
	table.insert(fakePlayers, player)
	profiles[player] = {
		dataVersion = 1,
		clips = Economy.startingClips,
		level = 1,
		xp = 0,
		collection = {},
		duelCopies = {},
		cosmetics = { owned = {}, equipped = {} },
		stats = { duels = 0, wins = 0, fakesSlipped = 0, fakesCaught = 0 },
		quests = { date = "", progress = {} },
		receipts = {},
		escrow = {},
		botEarnings = { date = "", value = 0 },
	}
	DataStub.profileLoaded:fire(player, profiles[player])
	return player
end

local mode = ARGV_MODE
local count = ARGV_COUNT

if mode == "spec-setup" then
	-- The spec drives everything itself; this only wires the services.
elseif mode == "bots" then
	BotService.selfPlay(count)
else
	local player = addPlayer("HarnessPlayer")
	local before = 0
	for _, n in profiles[player].duelCopies do
		before += n
	end
	print(`[harness] starter copies: {before}, clips: {profiles[player].clips}`)
	BotService.selfPlay(count, player)

	local after = 0
	for _, n in profiles[player].duelCopies do
		after += n
	end
	print(`[harness] after: {after} copies, {profiles[player].clips} clips, {#profiles[player].escrow} escrow entries`)
	print(`[harness] bot earnings recorded: {profiles[player].botEarnings.value}`)
	local collected = 0
	for _, n in profiles[player].collection do
		collected += n
	end
	print(`[harness] collection size: {collected}   (must be 0 -- duels move copies, never collection)`)
end
