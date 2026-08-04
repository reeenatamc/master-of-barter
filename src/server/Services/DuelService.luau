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
	--- The rival spent a raise on you: you owe a bigger offer before play can
	--- continue. Cleared when the amendment lands.
	amendRequested: boolean,
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
	--- Bumped every time the phase deadline is re-armed, so timers from an
	--- earlier arming can tell they are stale. See `armPhaseWatchdog`.
	watchdogGeneration: number,
	--- nil until the duel enters Reveal. See `buildReveal`.
	reveal: Types.RevealResult?,
}

--- 1 <-> 2. Duels are always two-sided (docs/gdd.md §32).
local function otherSlot(slot: Slot): Slot
	return 3 - slot
end

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
			mustAmend = side.amendRequested,
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
		-- Gated on the phase, not just on the field being set. Even if some
		-- future change filled duel.reveal early, this is where it would still
		-- be stopped from leaving the server. Both recipients get the exact
		-- same object: a reveal that differed per player would not be a reveal.
		reveal = if duel.phase == "Reveal" then duel.reveal else nil,
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
--- Old timers are NOT cancelled here -- Trove is clean-everything-at-once by
--- design. Instead every arming bumps a generation, each timer captures the one
--- it was armed under, and a timer whose generation is stale does nothing.
---
--- Generation rather than "has the phase changed": a Negotiating deadline gets
--- re-armed while STAYING in Negotiating every time a raise or an amendment
--- lands, so comparing phases would leave the old timer looking valid and
--- cancelling the duel early. A stale timer firing into a no-op costs nothing;
--- teaching Trove to remove single items would cost a whole capability nothing
--- else needs.
local function armPhaseWatchdog(duel: Duel)
	local seconds = DuelRules.phaseSeconds[duel.phase]
	if not seconds then
		return
	end

	duel.watchdogGeneration += 1
	local generation = duel.watchdogGeneration
	duel.deadline = workspace:GetServerTimeNow() + seconds

	-- Created and registered in the same statement: no timer ever exists
	-- without its cleanup (backlog card A1.2).
	duel.trove:Delay(seconds, function()
		local current = duels[duel.id]
		if current and current.watchdogGeneration == generation then
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
			{ slot = 1, player = playerA, hand = buildStarterHand(), offer = nil, amendRequested = false, raisesLeft = raises, fakeCallUsed = false },
			{ slot = 2, player = playerB, hand = buildStarterHand(), offer = nil, amendRequested = false, raisesLeft = raises, fakeCallUsed = false },
		},
		trove = Trove.new(),
		resolving = false,
		watchdogGeneration = 0,
		reveal = nil,
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
	local side = sideOf(duel, player)
	if not side then
		return reject(player, "not a participant")
	end

	-- An offer is legal twice: once when building it, and again when the rival
	-- has spent a raise demanding a bigger one.
	local amending: boolean
	if duel.phase == "BuildingOffers" then
		if side.offer then
			return reject(player, "already offered")
		end
		amending = false
	elseif duel.phase == "Negotiating" then
		if not side.amendRequested then
			return reject(player, "no raise is pending on you")
		end
		amending = true
	else
		return reject(player, `wrong phase ({duel.phase})`)
	end

	-- Layer 1: types.
	local requests = parseRequests(payload)
	if not requests then
		return reject(player, "malformed payload")
	end

	local limits = DuelRules.limits
	local previous = side.offer

	-- "Add or improve" is validated by COUNT, never by real value.
	--
	-- The server knows what every wrapper truly is, so judging whether an
	-- amendment is genuinely worth more would make the rejection itself leak
	-- that knowledge: a client could probe amendments and read the truth off
	-- which ones pass. Same family as the overlapping appearance bands -- the
	-- server never answers in a way that reveals what it knows.
	local minimum = if amending and previous then #previous + 1 else limits.minItemsPerOffer
	if #requests < minimum or #requests > limits.maxItemsPerOffer then
		local what = if amending then "amendment" else "offer"
		return reject(player, `{what} has {#requests} wrappers, needs {minimum}-{limits.maxItemsPerOffer}`)
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

	if amending then
		-- The demand is satisfied; the turn goes back to whoever made it, who
		-- now gets to accept, decline or raise again. The deadline restarts:
		-- they are looking at a different offer than the one they were given.
		side.amendRequested = false
		duel.turn = otherSlot(side.slot)
		armPhaseWatchdog(duel)
	elseif duel.sides[1].offer and duel.sides[2].offer then
		beginNegotiating(duel)
	end

	broadcast(duel)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Negotiation (card A2.1)

--- Every action in Types.DuelAction is now implemented. The table stays because
--- it is what turns an unknown string from a client into a clean refusal rather
--- than a lookup miss further down.
local IMPLEMENTED: { [string]: boolean } = {
	Accept = true,
	Decline = true,
	RaiseOffer = true,
	FakeCall = true,
}

--- The whole truth of the duel, built at the instant it enters Reveal and not
--- one moment earlier. This is the ONLY place `isFake` becomes public, and it
--- deliberately does not go anywhere near `stateFor`: the view types that
--- function produces have nowhere to put the truth, and that is what makes the
--- golden rule structural instead of a habit.
---
--- Scoring is crude on purpose. A genuine wrapper is worth its baseValue, a
--- forgery is worth nothing, and whoever received more wins.
---
--- `takenBy[slot]` says which side walks away with the wrappers that `slot` put
--- on the table. A plain accept swaps them; an accusation redirects them (see
--- `settleFakeCall`). Keeping the outcome as data rather than branching inside
--- here means the reveal is built the same way no matter how the duel ended.
local function buildReveal(duel: Duel, takenBy: { Slot }, fakeCall: Types.FakeCall?): Types.RevealResult
	local function uncover(wrapped: WrappedItem): Types.RevealedWrap
		return {
			wrappedId = wrapped.wrappedId,
			claim = wrapped.claim,
			isFake = wrapped.isFake,
		}
	end

	local sides: { Types.RevealSide } = {}

	for _, side in duel.sides do
		-- Annotated because `x or {}` infers a union with the empty-table type,
		-- which is not iterable.
		local own: { WrappedItem } = side.offer or {}

		-- Was this side the target of an accusation that landed?
		local caught = fakeCall ~= nil and fakeCall.correct and fakeCall.by == otherSlot(side.slot)

		local offered: { Types.RevealedWrap } = {}
		local fakesPassed = 0
		for _, wrapped in own do
			table.insert(offered, uncover(wrapped))
			-- A forgery counts as slipped past only if it changed hands AND was
			-- not exposed. Handing your fakes over because the rival caught you
			-- is the opposite of getting away with it, even though the wrappers
			-- do end up on their side of the table.
			if wrapped.isFake and takenBy[side.slot] ~= side.slot and not caught then
				fakesPassed += 1
			end
		end

		-- Everything that ended up on this side, whoever originally offered it.
		local received: { Types.RevealedWrap } = {}
		local valueReceived = 0
		for _, source in duel.sides do
			if takenBy[source.slot] == side.slot then
				local wrappers: { WrappedItem } = source.offer or {}
				for _, wrapped in wrappers do
					table.insert(received, uncover(wrapped))
					if not wrapped.isFake then
						local def = Items.catalog[wrapped.claim]
						valueReceived += if def then def.baseValue else 0
					end
				end
			end
		end

		sides[side.slot] = {
			slot = side.slot,
			offered = offered,
			received = received,
			valueReceived = valueReceived,
			fakesPassed = fakesPassed,
		}
	end

	local winner: Slot? = nil
	if sides[1].valueReceived > sides[2].valueReceived then
		winner = 1
	elseif sides[2].valueReceived > sides[1].valueReceived then
		winner = 2
	end

	return { sides = sides, winner = winner, fakeCall = fakeCall }
end

--- Who ends up holding what after a plain accepted trade: each side takes the
--- other's wrappers.
local function swapAll(): { Slot }
	return { 2, 1 }
end

--- The accusation, resolved (docs/gdd.md §8).
---
--- Right: you take the cheat's offer and keep your own -- they walk away with
--- nothing. Wrong: your stake goes to them and you keep nothing.
---
--- Note what is NOT checked here: whether the accusation was "reasonable". The
--- server knows the truth and answers only with the outcome, never with a hint
--- about how close the call was.
local function settleFakeCall(duel: Duel, accuser: Slot): (boolean, { Slot })
	local accused = otherSlot(accuser)
	local wrappers: { WrappedItem } = duel.sides[accused].offer or {}

	local correct = false
	for _, wrapped in wrappers do
		if wrapped.isFake then
			correct = true
			break
		end
	end

	local takenBy: { Slot } = {}
	if correct then
		takenBy[accused] = accuser
		takenBy[accuser] = accuser
	else
		takenBy[accuser] = accused
		takenBy[accused] = accused
	end

	return correct, takenBy
end

--- One of the three negotiation buttons. Validated in the four layers of
--- docs/arquitectura.md §8, same as offers.
---
--- Like submitOffer, this is NOT rate limited yet.
function DuelService.negotiate(player: Player, action: unknown)
	-- Layer 1: type.
	if type(action) ~= "string" then
		return reject(player, "action is not a string")
	end

	-- Layer 2: existence.
	if not IMPLEMENTED[action] then
		return reject(player, `action "{action}" is not available yet`)
	end

	-- Layer 3: state.
	local duelId = duelIdOf[player]
	local duel = if duelId then duels[duelId] else nil
	if not duel then
		return reject(player, "not in a duel")
	end
	if duel.phase ~= "Negotiating" then
		return reject(player, `wrong phase ({duel.phase})`)
	end

	local side = sideOf(duel, player)
	if not side then
		return reject(player, "not a participant")
	end

	-- Layer 4: permission. Only whoever holds the turn may act on it.
	if duel.turn ~= side.slot then
		return reject(player, `not your turn (slot {duel.turn} is up)`)
	end

	if action == "Accept" then
		-- The trade is agreed, so the truth becomes public. Built here, at the
		-- transition itself, from the duel's own tables.
		--
		-- The server does not hold the duel open through a dramatic pause: the
		-- reveal travels inside the final DuelState, and the client owns the
		-- timing of the unwrapping animation. Nothing is waiting on the server,
		-- so nothing can hang there. Holding Reveal and Results open for their
		-- configured seconds is Etapa 4 polish, if it is ever needed at all.
		--
		-- Transfers are still in-memory only: the permanent collection is B3
		-- and Clips are B2, both Etapa 2.
		duel.reveal = buildReveal(duel, swapAll(), nil)
		resolve(duel, "Reveal", `slot {side.slot} accepted`)
	elseif action == "Decline" then
		resolve(duel, "Cancelled", `slot {side.slot} declined`)
	elseif action == "FakeCall" then
		-- One token per side per duel (DuelRules.limits.fakeCallsPerDuel).
		if side.fakeCallUsed then
			return reject(player, "your FakeCall token is already spent")
		end
		side.fakeCallUsed = true

		local correct, takenBy = settleFakeCall(duel, side.slot)
		duel.reveal = buildReveal(duel, takenBy, { by = side.slot, correct = correct })

		-- TODO(F3): this is the single most uncertain mechanic in the GDD (§8
		-- marks it as one to keep or cut with data), so every call needs to
		-- reach analytics with its outcome. AnalyticsService does not exist yet.
		resolve(duel, "Reveal", `slot {side.slot} called fake ({if correct then "hit" else "miss"})`)
	else
		-- RaiseOffer: hand the turn to the rival, who now owes a bigger offer.
		if side.raisesLeft <= 0 then
			return reject(player, `no raises left (limit is {DuelRules.limits.raiseOffersPerSide} per side)`)
		end

		local rival = duel.sides[otherSlot(side.slot)]
		if rival.amendRequested then
			return reject(player, "a raise is already pending on the rival")
		end

		side.raisesLeft -= 1
		rival.amendRequested = true
		duel.turn = rival.slot
		-- The rival gets a fresh deadline to answer the demand.
		armPhaseWatchdog(duel)
		broadcast(duel)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────

--- Fires two real terminal paths at the same duel, back to back with no yield
--- between them, and reports numbers instead of impressions.
---
--- Debug only, and deliberately NOT reachable from a client. A remote that ends
--- duels on demand is exactly the kind of thing this project refuses to ship,
--- so this runs from the Server context of the Command Bar.
function DuelService.runFinishRaceCheck(): boolean
	if not DuelRules.debugLogs then
		warn("[DuelService] race check needs DuelRules.debugLogs = true")
		return false
	end

	local target: Duel? = nil
	for _, candidate in duels do
		if candidate.phase == "Negotiating" then
			target = candidate
			break
		end
	end

	local duel = target
	if not duel then
		warn("[DuelService] race check: no duel is in Negotiating right now")
		return false
	end

	local before = table.clone(counters)
	local trove = duel.trove
	local duelId = duel.id
	local actor = duel.sides[duel.turn].player

	DuelService.negotiate(actor, "Accept")
	DuelService.expirePhase(duelId)

	local resolved = counters.resolved - before.resolved
	local blocked = counters.blocked - before.blocked
	local broadcasts = counters.terminalBroadcasts - before.terminalBroadcasts
	local finished = counters.finished - before.finished
	local live = trove:Live()
	local gone = duels[duelId] == nil

	local ok = resolved == 1 and blocked == 1 and broadcasts == 1 and finished == 1 and live == 0 and gone

	print("[DuelService] finish race check")
	print(`  terminal transitions applied : {resolved}   (expected 1)`)
	print(`  second path turned away      : {blocked}   (expected 1)`)
	print(`  phase broadcasts to clients  : {broadcasts}   (expected 1)`)
	print(`  finish() calls that did work : {finished}   (expected 1)`)
	print(`  trove live objects           : {live}   (expected 0)`)
	print(`  duel removed from registry   : {gone}   (expected true)`)
	print(if ok then "  RESULT: PASS" else "  RESULT: FAIL")

	return ok
end

-- ─────────────────────────────────────────────────────────────────────────────

--- Wires the service. Called by Main in boot order.
function DuelService.init()
	Net.get(Net.names.DuelOffer).OnServerEvent:Connect(function(player: Player, payload: unknown)
		DuelService.submitOffer(player, payload)
	end)

	Net.get(Net.names.DuelNegotiate).OnServerEvent:Connect(function(player: Player, action: unknown)
		DuelService.negotiate(player, action)
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
