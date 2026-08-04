--!strict
--[[
	DuelService.luau -- duel state machine; owner of the real/fake truth.

	Card A1.1: a duel can start, both sides get their duel copies, and each
	client receives a DuelState. No offers, no negotiation, no timers yet --
	those are A1.2 and A2.

	Card A1.2 adds the phase watchdog and the per-duel Trove, together: the
	moment a timer exists, its cleanup exists too.

	The one rule this module exists to protect (docs/gdd.md §39): every table in
	here is server-only. Nothing leaves except through `stateFor`, which builds
	a per-recipient view. Today the only thing being censored is the rival's
	hand (they get a count, not the items); once forgeries exist, the same
	funnel is what keeps `isFake` from ever reaching the other client.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

type Slot = Types.Slot
type DuelCopy = Types.DuelCopy
type DuelPhase = Types.DuelPhase
type DuelPlayerView = Types.DuelPlayerView
type DuelState = Types.DuelState
type ItemId = Types.ItemId
type WrapAppearance = Types.WrapAppearance
type WrappedItem = Types.WrappedItem
type WrappedItemView = Types.WrappedItemView
type WrapRequest = Types.WrapRequest

--- One side of a duel, as the server knows it. Never replicated as-is.
type Side = {
	slot: Slot,
	player: Player,
	hand: { DuelCopy },
	--- nil until this side has offered. Holds the truth, including isFake.
	offer: { WrappedItem }?,
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
	--- Owns every connection and timer this duel creates. Cleaned on finish,
	--- whichever way the duel ends.
	trove: Trove.Trove,
	--- Set by the first terminal path to claim the duel. See `resolve`.
	resolving: boolean,
}

local DuelService = {}

local duels: { [string]: Duel } = {}
--- Reverse index so a disconnect can find the duel without scanning.
local duelIdOf: { [Player]: string } = {}

--- Debug-only tallies, so tests can state facts instead of hopes. Same
--- principle as the Trove live count: "1 real, 1 blocked" is a result,
--- "nothing exploded" is not. Only written when DuelRules.debugLogs is on.
local counters = {
	--- Terminal transitions that actually took effect.
	resolved = 0,
	--- Terminal paths that arrived second and were turned away.
	blocked = 0,
	--- Phase broadcasts sent by a terminal transition.
	terminalBroadcasts = 0,
	--- finish() calls that did the work, and calls that hit the no-op.
	finished = 0,
	finishIgnored = 0,
}

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

--- Strips a wrapper down to what anyone is allowed to see. This function is the
--- reason gdd.md §39 is code and not a promise: WrappedItemView has no isFake
--- field, so forgetting to remove it here is impossible -- the copy is
--- field-by-field and explicit, never a table clone.
local function viewOf(wrapped: WrappedItem): WrappedItemView
	return {
		wrappedId = wrapped.wrappedId,
		claim = wrapped.claim,
		appearance = wrapped.appearance,
	}
end

--- Builds the state as ONE recipient is allowed to see it.
local function stateFor(duel: Duel, slot: Slot): DuelState
	local views: { DuelPlayerView } = {}
	for _, side in duel.sides do
		local offerView = nil
		if side.offer then
			local wrapped: { WrappedItemView } = {}
			for _, item in side.offer do
				table.insert(wrapped, viewOf(item))
			end
			offerView = { from = side.slot, wrapped = wrapped }
		end

		views[side.slot] = {
			slot = side.slot,
			userId = side.player.UserId,
			displayName = side.player.DisplayName,
			isBot = false,
			handCount = #side.hand,
			raisesLeft = side.raisesLeft,
			fakeCallUsed = side.fakeCallUsed,
			-- Censored for everyone, including the owner: the owner gets the
			-- truth through `yourOffer` below instead.
			offer = offerView,
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
		yourOffer = duel.sides[slot].offer,
		players = views,
	}
end

local function broadcast(duel: Duel)
	local remote = Net.get(Net.names.DuelState)
	for _, side in duel.sides do
		remote:FireClient(side.player, stateFor(duel, side.slot))
	end
end

--- Arms the watchdog for whatever phase the duel is in now, and sets the
--- matching deadline. Terminal phases have no entry in Config and get no timer.
---
--- Timers from a previous phase are NOT cancelled here -- Trove is
--- clean-everything-at-once by design. Instead each timer remembers the phase
--- it was armed for and does nothing if the duel has moved on. A stale timer
--- that fires into a no-op costs nothing; a Trove that could remove single
--- items would cost a whole capability nobody else needs.
local function armPhaseWatchdog(duel: Duel)
	local seconds = DuelRules.phaseSeconds[duel.phase]
	if not seconds then
		return
	end

	local armedFor = duel.phase
	duel.deadline = workspace:GetServerTimeNow() + seconds

	-- Created and registered in the same statement: no timer ever exists
	-- without its cleanup (backlog card A1.2).
	duel.trove:Delay(seconds, function()
		local current = duels[duel.id]
		if current and current.phase == armedFor then
			DuelService.expirePhase(duel.id)
		end
	end)
end

--- The single exit for a duel, whichever way it ends: accept, decline, a phase
--- watchdog or a disconnect. All four can fire in the same instant.
---
--- The registry no-op inside finish() stops the CLEANUP from running twice, but
--- it does nothing for the broadcast that happens before it: two winners would
--- push two contradictory phase changes at the clients, and whichever arrived
--- last would win on screen. So the first path here claims the duel and every
--- other one backs off without emitting anything.
---
--- Nothing yields between the check and the write, so the claim is atomic.
local function resolve(duel: Duel, phase: DuelPhase, reason: string)
	if duel.resolving then
		if DuelRules.debugLogs then
			counters.blocked += 1
			print(`[DuelService] duel {duel.id}: second terminal path blocked ({reason})`)
		end
		return
	end
	duel.resolving = true

	duel.phase = phase
	broadcast(duel)

	if DuelRules.debugLogs then
		counters.resolved += 1
		counters.terminalBroadcasts += 1
	end

	DuelService.finish(duel.id, reason)
end

--- Both sides have committed an offer, so negotiation can begin.
local function beginNegotiating(duel: Duel)
	duel.phase = "Negotiating"
	-- docs/arquitectura.md §5: the offerer moves first. Slot 1 opens for now;
	-- alternating turns belong to A2.
	duel.turn = 1
	armPhaseWatchdog(duel)
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

	local raises = DuelRules.limits.raiseOffersPerSide

	local duel: Duel = {
		id = HttpService:GenerateGUID(false),
		phase = "BuildingOffers",
		round = 1,
		turn = 1,
		deadline = 0,
		sides = {
			{ slot = 1, player = playerA, hand = buildStarterHand(), offer = nil, raisesLeft = raises, fakeCallUsed = false },
			{ slot = 2, player = playerB, hand = buildStarterHand(), offer = nil, raisesLeft = raises, fakeCallUsed = false },
		},
		trove = Trove.new(),
		resolving = false,
	}

	duels[duel.id] = duel
	duelIdOf[playerA] = duel.id
	duelIdOf[playerB] = duel.id

	armPhaseWatchdog(duel)
	broadcast(duel)
	return duel.id
end

--- Phase watchdog: no phase may hang forever (docs/arquitectura.md §5).
--- Any phase that runs out of time cancels the duel. §5 used to say "timeout
--- doble"; that was premature sophistication and the doc has been corrected.
--- If cancelling on the first timeout turns out to punish honest lag, that is a
--- number to recalibrate, not a state machine to redesign.
function DuelService.expirePhase(duelId: string)
	local duel = duels[duelId]
	if not duel then
		if DuelRules.debugLogs then
			counters.blocked += 1
			print(`[DuelService] expirePhase({duelId}) blocked: duel already gone`)
		end
		return
	end

	resolve(duel, "Cancelled", `{duel.phase} timed out`)
end

--- Ends a duel, releases everything it owned, and forgets it. `reason` is for
--- the log only until A3 computes real results.
---
--- Idempotent by design. Two paths race towards this: a disconnect and the
--- phase watchdog can fire for the same duel at nearly the same moment. The
--- second call must do nothing, because in Etapa 2 a profile save will hang off
--- the end of a duel and running it twice would corrupt data.
function DuelService.finish(duelId: string, reason: string)
	local duel = duels[duelId]
	if not duel then
		if DuelRules.debugLogs then
			counters.finishIgnored += 1
			print(`[DuelService] finish({duelId}) ignored: already finished`)
		end
		return
	end

	if DuelRules.debugLogs then
		counters.finished += 1
	end

	-- Forget the duel BEFORE cleaning up, so anything that cleanup triggers and
	-- that calls back in here takes the no-op path above.
	duels[duelId] = nil
	for _, side in duel.sides do
		duelIdOf[side.player] = nil
	end

	duel.trove:Clean()

	local live = duel.trove:Live()
	if live ~= 0 then
		-- Never gated behind debugLogs: a leak is not something a config flag
		-- gets to hide.
		warn(`[DuelService] duel {duelId} LEAK: expected 0 live objects, got {live}`)
	elseif DuelRules.debugLogs then
		print(`[DuelService] duel {duelId} ended ({reason}): expected 0 live objects, got 0`)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Offers (card A1.3)

local rng = Random.new()

--- Both genuine and forged wrappers get all three dimensions rolled. The only
--- difference is which band they are drawn from, so the payload shape can never
--- betray which is which.
local function rollAppearance(isFake: boolean): WrapAppearance
	local band = if isFake then DuelRules.appearanceBands.forged else DuelRules.appearanceBands.genuine
	return {
		colorTone = rng:NextNumber(band.min, band.max),
		seam = rng:NextNumber(band.min, band.max),
		label = rng:NextNumber(band.min, band.max),
	}
end

--- A rejected remote is either a bug in our own client or somebody probing.
--- Either way it has to be visible and cheap (docs/arquitectura.md §8).
--- Feeding these to analytics, so spam patterns become exploit candidates, is
--- card F3.
local function reject(player: Player, why: string)
	warn(`[DuelService] request from {player.Name} rejected: {why}`)
end

local function sideOf(duel: Duel, player: Player): Side?
	for _, side in duel.sides do
		if side.player == player then
			return side
		end
	end
	return nil
end

local function findCopy(side: Side, copyId: string): DuelCopy?
	for _, copy in side.hand do
		if copy.copyId == copyId then
			return copy
		end
	end
	return nil
end

--- Validation layer 1: shape. This is where values coming off a remote stop
--- being `unknown`. Nothing below this function ever sees an unchecked field.
--- Bails as soon as the entry count passes the limit, so a huge payload cannot
--- make the server walk it.
local function parseRequests(payload: unknown): { WrapRequest }?
	if type(payload) ~= "table" then
		return nil
	end

	local requests: { WrapRequest } = {}

	for _, entry in payload :: { [any]: any } do
		if #requests >= DuelRules.limits.maxItemsPerOffer + 1 then
			return nil
		end
		if type(entry) ~= "table" then
			return nil
		end

		local raw = entry :: { [string]: any }
		local copyId, isFake, claim = raw.copyId, raw.isFake, raw.claim

		if type(isFake) ~= "boolean" or type(claim) ~= "string" then
			return nil
		end
		if copyId ~= nil and type(copyId) ~= "string" then
			return nil
		end

		table.insert(requests, { copyId = copyId, isFake = isFake, claim = claim })
	end

	return requests
end

--- Commits one side's offer. Validates in the four layers of
--- docs/arquitectura.md §8: types, existence against Config, duel state, then
--- ownership. Any failure means "ignore and log", never a partial offer.
---
--- NOT rate limited yet. Repeat calls are cheap (the "already offered" check
--- rejects them immediately), but per-player rate limiting on every remote is
--- still outstanding and belongs in one place for all of them, not here.
function DuelService.submitOffer(player: Player, payload: unknown)
	-- Layer 3: state.
	local duelId = duelIdOf[player]
	local duel = if duelId then duels[duelId] else nil
	if not duel then
		return reject(player, "not in a duel")
	end
	if duel.phase ~= "BuildingOffers" then
		return reject(player, `wrong phase ({duel.phase})`)
	end

	local side = sideOf(duel, player)
	if not side then
		return reject(player, "not a participant")
	end
	if side.offer then
		return reject(player, "already offered")
	end

	-- Layer 1: types.
	local requests = parseRequests(payload)
	if not requests then
		return reject(player, "malformed payload")
	end

	local limits = DuelRules.limits
	if #requests < limits.minItemsPerOffer or #requests > limits.maxItemsPerOffer then
		return reject(player, `{#requests} wrappers, allowed {limits.minItemsPerOffer}-{limits.maxItemsPerOffer}`)
	end

	-- Layers 2 and 4: existence against Config, then ownership.
	local wrapped: { WrappedItem } = {}
	local usedCopies: { [string]: boolean } = {}
	local fakes = 0

	for _, request in requests do
		-- Model A consistency: a forgery consumes no copy, a genuine wrapper
		-- always names one. A client that says otherwise is malformed.
		if request.isFake ~= (request.copyId == nil) then
			return reject(player, "isFake disagrees with copyId")
		end

		-- Existence: a claim always names a real catalogue item, forged or not.
		-- Forging something that does not exist would have no imperfection
		-- template to imitate and no value to price the Clips cost against.
		if not Items.catalog[request.claim] then
			return reject(player, `unknown claim "{request.claim}"`)
		end

		if request.isFake then
			fakes += 1
			if fakes > limits.fakesPerDuel then
				return reject(player, `more than {limits.fakesPerDuel} fakes`)
			end
		else
			local copyId = request.copyId :: string
			if usedCopies[copyId] then
				return reject(player, "same copy wrapped twice")
			end

			local copy = findCopy(side, copyId)
			if not copy then
				return reject(player, `does not own copy {copyId}`)
			end
			-- Model A: a genuine wrapper cannot lie about what it holds. Lying
			-- is what forging is for.
			if copy.itemId ~= request.claim then
				return reject(player, `genuine wrapper claims {request.claim} but holds {copy.itemId}`)
			end

			usedCopies[copyId] = true
		end

		table.insert(wrapped, {
			wrappedId = HttpService:GenerateGUID(false),
			copyId = request.copyId,
			isFake = request.isFake,
			claim = request.claim,
			appearance = rollAppearance(request.isFake),
		})
	end

	side.offer = wrapped

	if duel.sides[1].offer and duel.sides[2].offer then
		beginNegotiating(duel)
	end

	broadcast(duel)
end

-- ─────────────────────────────────────────────────────────────────────────────

--- Wires the service. Called by Main in boot order.
function DuelService.init()
	Net.get(Net.names.DuelOffer).OnServerEvent:Connect(function(player: Player, payload: unknown)
		DuelService.submitOffer(player, payload)
	end)

	-- docs/gdd.md §32: leaving mid-duel is a loss. Scoring is A3; for now the
	-- duel simply ends so neither side is stuck in a dead duel.
	--
	-- Goes through `resolve` like every other ending, so the player who stayed
	-- is actually told the duel is over instead of being left staring at a
	-- state that will never change again.
	Players.PlayerRemoving:Connect(function(player: Player)
		local duelId = duelIdOf[player]
		local duel = if duelId then duels[duelId] else nil
		if duel then
			resolve(duel, "Cancelled", `{player.Name} disconnected`)
		end
	end)
end

return DuelService
