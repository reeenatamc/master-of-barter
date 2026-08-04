--!strict
--[[
	DuelService.luau -- duel state machine; owner of the real/fake truth.

	Card A1.1: a duel can start, both sides get their duel copies, and each
	client receives a DuelState. No offers, no negotiation, no timers yet --
	those are A1.2 and A2.

	The one rule this module exists to protect (docs/gdd.md §39): every table in
	here is server-only. Nothing leaves except through `stateFor`, which builds
	a per-recipient view. Today the only thing being censored is the rival's
	hand (they get a count, not the items); once forgeries exist, the same
	funnel is what keeps `isFake` from ever reaching the other client.

	No Trove yet on purpose: an A1.1 duel holds zero connections and zero
	timers, so there is nothing to leak. It arrives with A1.2, when phase
	watchdogs do.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Types = require(ReplicatedStorage.Shared.Types)

type Slot = Types.Slot
type DuelCopy = Types.DuelCopy
type DuelPhase = Types.DuelPhase
type DuelPlayerView = Types.DuelPlayerView
type DuelState = Types.DuelState

--- One side of a duel, as the server knows it. Never replicated as-is.
type Side = {
	slot: Slot,
	player: Player,
	hand: { DuelCopy },
	raisesLeft: number,
	fakeCallUsed: boolean,
}

type Duel = {
	id: string,
	phase: DuelPhase,
	round: number,
	turn: Slot,
	deadline: number,
	--- Indexed by slot: sides[1] and sides[2].
	sides: { Side },
}

local DuelService = {}

local duels: { [string]: Duel } = {}
--- Reverse index so a disconnect can find the duel without scanning.
local duelIdOf: { [Player]: string } = {}

-- ─────────────────────────────────────────────────────────────────────────────

--- Etapa 1 shortcut: every player starts with one copy of each prototype item.
--- Real duel inventories come from InventoryService (card B3, Etapa 2).
local function buildStarterHand(): { DuelCopy }
	local hand: { DuelCopy } = {}
	for _, itemId in Items.order do
		table.insert(hand, {
			copyId = HttpService:GenerateGUID(false),
			itemId = itemId,
		})
	end
	return hand
end

--- Builds the state as ONE recipient is allowed to see it.
local function stateFor(duel: Duel, slot: Slot): DuelState
	local views: { DuelPlayerView } = {}
	for _, side in duel.sides do
		views[side.slot] = {
			slot = side.slot,
			userId = side.player.UserId,
			displayName = side.player.DisplayName,
			isBot = false,
			handCount = #side.hand,
			raisesLeft = side.raisesLeft,
			fakeCallUsed = side.fakeCallUsed,
			offer = nil,
		}
	end

	return {
		duelId = duel.id,
		phase = duel.phase,
		round = duel.round,
		turn = duel.turn,
		deadline = duel.deadline,
		yourSlot = slot,
		yourHand = duel.sides[slot].hand,
		players = views,
	}
end

local function broadcast(duel: Duel)
	local remote = Net.get(Net.names.DuelState)
	for _, side in duel.sides do
		remote:FireClient(side.player, stateFor(duel, side.slot))
	end
end

-- ─────────────────────────────────────────────────────────────────────────────

function DuelService.isInDuel(player: Player): boolean
	return duelIdOf[player] ~= nil
end

--- Starts a duel between two players. Returns the duel id, or nil if either
--- player is already busy.
function DuelService.start(playerA: Player, playerB: Player): string?
	if playerA == playerB then
		return nil
	end
	if DuelService.isInDuel(playerA) or DuelService.isInDuel(playerB) then
		return nil
	end

	local duel: Duel = {
		id = HttpService:GenerateGUID(false),
		phase = "BuildingOffers",
		round = 1,
		turn = 1,
		deadline = workspace:GetServerTimeNow() + DuelRules.phaseSeconds.BuildingOffers,
		sides = {
			{ slot = 1, player = playerA, hand = buildStarterHand(), raisesLeft = DuelRules.limits.raiseOffersPerSide, fakeCallUsed = false },
			{ slot = 2, player = playerB, hand = buildStarterHand(), raisesLeft = DuelRules.limits.raiseOffersPerSide, fakeCallUsed = false },
		},
	}

	duels[duel.id] = duel
	duelIdOf[playerA] = duel.id
	duelIdOf[playerB] = duel.id

	broadcast(duel)
	return duel.id
end

--- Ends a duel and forgets it. `reason` is for the log only until A3 computes
--- real results.
function DuelService.finish(duelId: string, reason: string)
	local duel = duels[duelId]
	if not duel then
		return
	end

	for _, side in duel.sides do
		duelIdOf[side.player] = nil
	end
	duels[duelId] = nil

	print(`[DuelService] duel {duelId} ended: {reason}`)
end

--- Wires the service. Called by Main in boot order.
function DuelService.init()
	-- docs/gdd.md §32: leaving mid-duel is a loss. Scoring is A3; for now the
	-- duel simply ends so neither side is stuck in a dead duel.
	Players.PlayerRemoving:Connect(function(player: Player)
		local duelId = duelIdOf[player]
		if duelId then
			DuelService.finish(duelId, `{player.Name} disconnected`)
		end
	end)
end

return DuelService
