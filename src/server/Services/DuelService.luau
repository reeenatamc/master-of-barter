--!strict
--[[
	DuelService.luau -- duel state machine; owner of the real/fake truth.

	Card A1.1: a duel can start, both sides get their duel copies, and each
	client receives a DuelState. No offers, no negotiation, no timers yet --
	those are A1.2 and A2.

	Card A1.2 adds the phase watchdog and the per-duel Trove, together: the
	moment a timer exists, its cleanup exists too.

	What is left here after the split is the duel's LIFE: who is in one, what
	phase it is in, whose turn, when it ends and how. The parts that answer a
	question rather than run the clock live next door:

	  DuelTypes   the shapes
	  DuelView    the only way a state reaches a client
	  DuelReveal  the whole truth, built as a value
	  DuelOffers  whether an offer is legal, and what it puts on the table

	The one rule all four exist to protect (docs/gdd.md §39): every table in
	here is server-only, and the ONLY sanctioned exit for duel state is
	`DuelView.broadcast`. This module cannot build a DuelState even if it wanted
	to -- `stateFor` and `viewOf` are local to DuelView. Censorship is the
	default there, and the truth is unlocked by PHASE, not by caller.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelSceneService = require(script.Parent.DuelSceneService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local DuelTypes = require(script.Parent.DuelTypes)
local DuelOffers = require(script.Parent.DuelOffers)
local DuelStakes = require(script.Parent.DuelStakes)
local DuelReveal = require(script.Parent.DuelReveal)
local DuelView = require(script.Parent.DuelView)

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
type Side = DuelTypes.Side
type Duel = DuelTypes.Duel

local otherSlot = DuelTypes.otherSlot
local buildReveal = DuelReveal.build
local swapAll = DuelReveal.swapAll
local settleFakeCall = DuelReveal.settleFakeCall

local DuelService = {}

--- Fired after every state change, with the duel. This is how a bot learns it
--- is its turn (card D1) without polling.
---
--- Wrapped around DuelView.broadcast rather than fired at each call site: there
--- are six of those and forgetting one would leave a bot sitting still, which
--- looks exactly like a hung duel.
DuelService.stateChanged = Signal.new()

--- Fired once a duel is over and fully released, with its id, why it ended, and
--- how many objects its Trove still had alive (0 unless something leaked).
---
--- docs/arquitectura.md §9 names this listener list: AnalyticsService (card F3)
--- and the bot self-play harness. Fired at the very END of `finish`, inside the
--- idempotency guard, so it cannot fire twice for one duel.
DuelService.duelFinished = Signal.new()

local function broadcast(duel: Duel)
	DuelView.broadcast(duel)
	DuelService.stateChanged:fire(duel)
end

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

--- The hand comes from the player's own stakeable copies now (card B3), not
--- from thin air.
---
--- The profile stores counts per item; a duel needs individual things it can
--- point at, so the counts are expanded into copies with ids that live only for
--- this duel. Those ids are never saved: what persists is how many you have,
--- and which particular one crossed the table is not a fact worth keeping.
local botRng = Random.new()

--- Read fresh each time a side is built, never cached in an upvalue: these are
--- balance knobs, and a cached one would keep an old value alive for the life
--- of the server after a Config change.
local function raises(): number
	return DuelRules.limits.raiseOffersPerSide
end

local function tokens(): number
	return DuelRules.limits.fakeCallsPerDuel
end

local function buildHand(player: Player): { DuelCopy }
	local hand: { DuelCopy } = {}
	for _, itemId in InventoryService.stakeableList(player) do
		table.insert(hand, {
			copyId = HttpService:GenerateGUID(false),
			itemId = itemId,
		})
	end
	return hand
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

--- A bot's hand, minted rather than drawn from a profile.
---
--- This is the source docs/gdd.md §19 does not list, and it is the reason the
--- daily bot-earnings cap exists: everything genuine in here can end up in a
--- human's collection having come from nowhere. Kept to the cheap end of the
--- catalogue (Bots.handPool) so the leak is small before the cap even applies.
local function buildBotHand(): { DuelCopy }
	local hand: { DuelCopy } = {}
	for _ = 1, Bots.handSize do
		local itemId = Bots.handPool[botRng:NextInteger(1, #Bots.handPool)]
		table.insert(hand, {
			copyId = HttpService:GenerateGUID(false),
			itemId = itemId,
		})
	end
	return hand
end

--- One side belonging to nobody. Same shape as a person's, which is the whole
--- of card D1's condition 1: every rule above this point treats them alike.
local function sideOfBot(slot: Slot, raises: number, tokens: number): Side
	return {
		slot = slot,
		player = nil,
		displayName = Bots.names[botRng:NextInteger(1, #Bots.names)],
		hand = buildBotHand(),
		offer = nil,
		amendRequested = false,
		raisesLeft = raises,
		fakeCallsLeft = tokens,
	}
end

--- One side belonging to a real person. The bot equivalent is in
--- MatchmakingService, and both go through this shape so a field added to
--- `Side` cannot be filled in for humans and forgotten for bots.
local function sideOfPlayer(slot: Slot, player: Player, raises: number, tokens: number): Side
	return {
		slot = slot,
		player = player,
		displayName = player.DisplayName,
		hand = buildHand(player),
		offer = nil,
		amendRequested = false,
		raisesLeft = raises,
		fakeCallsLeft = tokens,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────

function DuelService.isInDuel(player: Player): boolean
	return duelIdOf[player] ~= nil
end

--- The shared tail of both starts: registry, scene, watchdog, first broadcast.
--- One body, so a duel against a bot can never drift from a duel against a
--- person in anything except who is sitting there.
local function openDuel(sideA: Side, sideB: Side): string?
	local duel: Duel = {
		id = HttpService:GenerateGUID(false),
		phase = "BuildingOffers",
		round = 1,
		turn = 1,
		deadline = 0,
		sides = { sideA, sideB },
		trove = Trove.new(),
		resolving = false,
		watchdogGeneration = 0,
		reveal = nil,
	}

	duels[duel.id] = duel
	for _, side in duel.sides do
		local person = side.player
		if person then
			duelIdOf[person] = duel.id
		end
	end

	-- The table, and both players standing at it. Registered in the trove in
	-- the same statement that creates it, like every other resource a duel
	-- owns: the scene disappears by every route the duel can end, disconnects
	-- included (card E2, docs/gdd.md §11).
	local seated: { { player: Player, slot: Slot } } = {}
	for _, side in duel.sides do
		local person = side.player
		if person then
			table.insert(seated, { player = person, slot = side.slot })
		end
	end
	duel.trove:Add(DuelSceneService.open(duel.id, seated))

	armPhaseWatchdog(duel)
	broadcast(duel)
	return duel.id
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

	-- A spectator has no profile (see DataService), so they cannot stake a copy
	-- and cannot be paid. Letting them duel would mean a duel whose stakes and
	-- rewards silently go nowhere -- which looks exactly like a working duel
	-- until somebody notices their collection never changed.
	-- Told to the player, not only to the log. "You cannot duel" with no reason
	-- reads as a broken game; "we could not load your progress" reads as a
	-- problem with a cause, and one they can retry.
	local notice = Net.get(Net.names.Notice)
	for _, player in { playerA, playerB } do
		if DataService.isSpectator(player) then
			warn(`[DuelService] refused to start a duel: {player.Name} has no profile to stake from`)
			notice:FireClient(player, Strings.notices.spectatorNoDuel)
		end
	end
	if DataService.isSpectator(playerA) or DataService.isSpectator(playerB) then
		return nil
	end

	return openDuel(
		sideOfPlayer(1, playerA, raises(), tokens()),
		sideOfPlayer(2, playerB, raises(), tokens())
	)
end

--- Starts a duel against a filler opponent (card D1). Same duel, same rules,
--- same watchdog: the only difference is that one side is nobody.
---
--- THE DAILY BOT-EARNINGS CAP IS NOT CHECKED HERE, and that is a convention
--- rather than a guarantee -- worth naming, because this project's own doctrine
--- says a convention is a hole waiting for its second caller.
---
--- Mechanism lives here; policy lives in MatchmakingService, which asks
--- `DuelStakes.mayEarnFromBots` before calling this. Today it is the only
--- caller, so the cap holds. The moment a second one appears -- the Don Trueque
--- tutorial (§34), a "play a bot" button, anything -- whoever adds it either
--- checks the cap or has a stated reason not to. The tutorial probably IS
--- exempt, which is exactly why the check is not unconditional in here.
function DuelService.startAgainstBot(player: Player): string?
	if DuelService.isInDuel(player) then
		return nil
	end
	if DataService.isSpectator(player) then
		warn(`[DuelService] refused a bot duel: {player.Name} has no profile to stake from`)
		Net.get(Net.names.Notice):FireClient(player, Strings.notices.spectatorNoDuel)
		return nil
	end

	-- The human always gets slot 1, so the bot is never the side that acts
	-- first in BuildingOffers. Not a rule, a courtesy: a rival whose offer is
	-- already on the table before yours reads as suspiciously quick.
	return openDuel(
		sideOfPlayer(1, player, raises(), tokens()),
		sideOfBot(2, raises(), tokens())
	)
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
		local player = side.player
		if player then
			duelIdOf[player] = nil
		end
	end

	-- Paying happens HERE, inside the idempotency guard, and that is the whole
	-- reason the guard was written. A duel that ended twice would pay twice, and
	-- from B2 onward "pay" means writing to a profile.
	--
	-- Only a duel that reached a reveal pays: a declined or timed-out duel had
	-- no trade, so there is nothing to reward. docs/gdd.md §19 says losing still
	-- pays something, and losing is not the same as never finishing.
	-- The stakes come out of escrow. Everything each side ends up holding is
	-- written into their profile as duel copies; nothing is written to whoever
	-- is no longer here, because their copies left at offer time.
	--
	-- Only genuine wrappers are worth anything: a forgery held nothing, so
	-- receiving one gives you nothing. That is the mechanic, not an oversight.
	local reveal = duel.reveal
	if reveal then
		for _, side in duel.sides do
			local won = reveal.sides[side.slot]
			if won then
				for _, wrapped in won.received do
					if not wrapped.isFake then
						DuelStakes.grant(side, wrapped.claim)
					end
				end
			end
			-- Whatever was owed has just been handed over, so the escrow record
			-- has done its job. Cleared rather than returned: returning here
			-- would double what resolution already gave back.
			DuelStakes.clearEscrow(side, duelId)
		end
	end

	-- A duel that never reached a reveal returns every stake untouched: nobody
	-- agreed to anything, so nobody loses anything.
	if not reveal then
		for _, side in duel.sides do
			-- Annotated: `x or {}` infers a union with the empty-table type,
			-- which is not iterable.
			local staked: { WrappedItem } = side.offer or {}
			for _, wrapped in staked do
				local copyId = wrapped.copyId
				if not wrapped.isFake and copyId then
					-- giveBack rather than grant: this is a stake coming back,
					-- so its escrow record goes with it -- matched by copyId, so
					-- exactly the copy that was staked is the copy returned.
					DuelStakes.giveBack(side, wrapped.claim, duelId, copyId)
				end
			end
		end
	end

	if reveal then
		for _, side in duel.sides do
			local mine = reveal.sides[side.slot]
			local theirs = reveal.sides[otherSlot(side.slot)]
			if mine and theirs then
				local result: "win" | "draw" | "loss" = if reveal.winner == nil
					then "draw"
					elseif reveal.winner == side.slot then "win"
					else "loss"

				local payout: Types.DuelPayout = {
					result = result,
					fakesSlipped = mine.fakesPassed,
					fakesCaught = if reveal.fakeCall ~= nil
							and reveal.fakeCall.by == side.slot
							and reveal.fakeCall.correct
						then 1
						else 0,
				}
				DuelStakes.pay(side, payout)

				-- Everything that came out of a filler opponent, against the
				-- day's total: the Clips just paid plus the value of the copies
				-- received. Both are minted (see DuelStakes), so both count.
				--
				-- Recorded AFTER the fact rather than checked before it. The
				-- cap decides whether the next bot duel is offered at all; it
				-- never docks a duel that already happened, because by the time
				-- we are here the stake has already crossed the table.
				if DuelStakes.isBot(duel.sides[otherSlot(side.slot)]) then
					local extracted = EconomyService.duelPayoutValue(payout) + mine.valueReceived
					DuelStakes.recordBotEarnings(side, extracted)
				end
			end
		end
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

	DuelService.duelFinished:fire(duelId, reason, live)
end

--- Starts a duel between two filler opponents, with nobody watching.
---
--- DEBUG ONLY, and gated on the same flag as the race check: this creates
--- duels on demand, which is not something any client gets to ask for. It
--- exists for the self-play harness (card D2), whose whole value is running
--- thousands of sequences no human would type.
---
--- Nothing is written to any profile: both sides are bots, so every DuelStakes
--- call is a no-op. A self-play run cannot touch anybody's data.
function DuelService.startBotDuel(): string?
	if not DuelRules.debugLogs then
		warn("[DuelService] startBotDuel needs DuelRules.debugLogs = true")
		return nil
	end
	return openDuel(sideOfBot(1, raises(), tokens()), sideOfBot(2, raises(), tokens()))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Offers (card A1.3)

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

--- Commits one side's offer, on a side that MAY BE A BOT.
---
--- The inner half of card D1's split: this is the action itself, and it knows
--- nothing about who asked for it. The outer half (`submitOffer`) exists only
--- to answer "who are you" for a remote. A bot calls straight in here, so it
--- runs the same phase checks, the same four layers and the same order a person
--- does -- one implementation, not two kept in agreement by hand.
---
--- Returns nil on success, or the reason it was refused. Refusing is the
--- caller's job: a bot has no client to warn about and no name in a log line.
---
--- The PHASE half of an offer: which duel, whose turn, and what happens to the
--- turn afterwards. Whether the offer itself is legal -- types, catalogue,
--- ownership, Clips, escrow -- is DuelOffers' question.
function DuelService.applyOffer(duel: Duel, side: Side, payload: unknown): string?
	-- An offer is legal twice: once when building it, and again when the rival
	-- has spent a raise demanding a bigger one.
	local amending: boolean
	if duel.phase == "BuildingOffers" then
		if side.offer then
			return "already offered"
		end
		amending = false
	elseif duel.phase == "Negotiating" then
		if not side.amendRequested then
			return "no raise is pending on you"
		end
		amending = true
	else
		return `wrong phase ({duel.phase})`
	end

	local wrapped, refusal = DuelOffers.build(duel, side, amending, payload)
	if not wrapped then
		return refusal or "offer refused"
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
	return nil
end

--- The remote's half: turns a Player into a duel and a side, then hands over.
--- This is the ONLY thing in an offer that a bot does not do.
---
--- NOT rate limited yet. Repeat calls are cheap (the "already offered" check
--- rejects them immediately), but per-player rate limiting on every remote is
--- still outstanding and belongs in one place for all of them, not here.
function DuelService.submitOffer(player: Player, payload: unknown)
	local duelId = duelIdOf[player]
	local duel = if duelId then duels[duelId] else nil
	if not duel then
		return reject(player, "not in a duel")
	end
	local side = sideOf(duel, player)
	if not side then
		return reject(player, "not a participant")
	end

	local refusal = DuelService.applyOffer(duel, side, payload)
	if refusal then
		reject(player, refusal)
	end
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

--- One of the three negotiation buttons, on a side that MAY BE A BOT.
---
--- The inner half, exactly like `applyOffer`. Layers 1 and 2 are in here rather
--- than in the remote's half on purpose: a bot with a bug can produce a
--- nonsense action just as a hostile client can, and "the bot goes through the
--- same validation" has to mean ALL of it, not the convenient part.
---
--- Returns nil on success, or the reason it was refused.
function DuelService.applyAction(duel: Duel, side: Side, action: unknown): string?
	-- Layer 1: type.
	if type(action) ~= "string" then
		return "action is not a string"
	end

	-- Layer 2: existence.
	if not IMPLEMENTED[action] then
		return `action "{action}" is not available yet`
	end

	-- Layer 3: state.
	if duel.phase ~= "Negotiating" then
		return `wrong phase ({duel.phase})`
	end

	-- Layer 4: permission. Only whoever holds the turn may act on it.
	if duel.turn ~= side.slot then
		return `not your turn (slot {duel.turn} is up)`
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
		-- Governed entirely by DuelRules.limits.fakeCallsPerDuel, including the
		-- value 0: the play-test in Etapa 1 runs one configuration with the
		-- token and one without, and "without" has to mean the server refuses
		-- it, not just that the button is hidden.
		if side.fakeCallsLeft <= 0 then
			return "no FakeCall tokens left"
		end
		side.fakeCallsLeft -= 1

		local correct, takenBy = settleFakeCall(duel, side.slot)
		duel.reveal = buildReveal(duel, takenBy, { by = side.slot, correct = correct })

		-- TODO(F3): this is the single most uncertain mechanic in the GDD (§8
		-- marks it as one to keep or cut with data), so every call needs to
		-- reach analytics with its outcome. AnalyticsService does not exist yet.
		resolve(duel, "Reveal", `slot {side.slot} called fake ({if correct then "hit" else "miss"})`)
	else
		-- RaiseOffer: hand the turn to the rival, who now owes a bigger offer.
		if side.raisesLeft <= 0 then
			return `no raises left (limit is {DuelRules.limits.raiseOffersPerSide} per side)`
		end

		local rival = duel.sides[otherSlot(side.slot)]
		if rival.amendRequested then
			return "a raise is already pending on the rival"
		end

		-- A DEMAND NOBODY COULD MEET IS REFUSED HERE, not answered and then
		-- refused forever after.
		--
		-- An amendment must hold at least one wrapper more than the offer it
		-- amends, and never more than maxItemsPerOffer. Against an offer already
		-- at that maximum those two rules contradict: the rival needed 5 with a
		-- ceiling of 4. Every possible answer was rejected, so the side owing it
		-- could not act, and the duel sat until the phase watchdog killed it.
		--
		-- Found by the self-play harness on the very first run against a real
		-- profile -- one duel in fifty, which is roughly never in a play-test and
		-- constantly once there are players.
		local rivalOffer = rival.offer
		if rivalOffer and #rivalOffer >= DuelRules.limits.maxItemsPerOffer then
			return `rival already offered the maximum of {DuelRules.limits.maxItemsPerOffer} wrappers`
		end

		side.raisesLeft -= 1
		rival.amendRequested = true
		duel.turn = rival.slot
		-- The rival gets a fresh deadline to answer the demand.
		armPhaseWatchdog(duel)
		broadcast(duel)
	end

	return nil
end

--- The remote's half. Same shape as `submitOffer`: identity, then hand over.
---
--- Like submitOffer, this is NOT rate limited yet.
function DuelService.negotiate(player: Player, action: unknown)
	local duelId = duelIdOf[player]
	local duel = if duelId then duels[duelId] else nil
	if not duel then
		return reject(player, "not in a duel")
	end
	local side = sideOf(duel, player)
	if not side then
		return reject(player, "not a participant")
	end

	local refusal = DuelService.applyAction(duel, side, action)
	if refusal then
		reject(player, refusal)
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
	-- The check drives a real remote handler, which needs a real player. A duel
	-- whose turn belongs to a bot has nobody to speak for it.
	local actor = duel.sides[duel.turn].player
	if not actor then
		warn("[DuelService] race check: it is a bot's turn; needs a human-vs-human duel")
		return false
	end

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
-- Emotes (card A7)

--- Last time each player reacted, for the cooldown. Cleared on disconnect so a
--- long-lived server does not accumulate an entry per player who ever joined.
local lastEmoteAt: { [Player]: number } = {}

local emoteExists: { [string]: boolean } = {}
for _, id in DuelRules.emotes do
	emoteExists[id] = true
end

--- A reaction. Validated in the same four layers as everything else, because a
--- remote that only carries a smiley is still a remote.
---
--- Reactions are broadcast, not stored: nothing about the duel changes, so this
--- deliberately does NOT go through `stateFor`. An emote is an event that
--- happened, not a fact about the game.
function DuelService.emote(player: Player, emoteId: unknown)
	-- Layer 1: type.
	if type(emoteId) ~= "string" then
		return reject(player, "emote id is not a string")
	end

	-- Layer 2: existence, against Config.
	if not emoteExists[emoteId] then
		return reject(player, `unknown emote "{emoteId}"`)
	end

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

	-- Layer 4: the cooldown. This is the only rate limit in the project so far,
	-- and it exists here because an emote is the one action a player can repeat
	-- as fast as they can tap. The general per-remote limiting is still
	-- outstanding (Etapa 2).
	local now = os.clock()
	local previous = lastEmoteAt[player]
	if previous and now - previous < DuelRules.emoteCooldownSeconds then
		return
	end
	lastEmoteAt[player] = now

	local remote = Net.get(Net.names.DuelEmote)
	for _, target in duel.sides do
		-- A bot has no client to react in front of.
		local watcher = target.player
		if watcher then
			remote:FireClient(watcher, side.slot, emoteId)
		end
	end
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

	Net.get(Net.names.DuelEmote).OnServerEvent:Connect(function(player: Player, emoteId: unknown)
		DuelService.emote(player, emoteId)
	end)

	-- docs/gdd.md §32: leaving mid-duel is a loss. Scoring is A3; for now the
	-- duel simply ends so neither side is stuck in a dead duel.
	--
	-- Goes through `resolve` like every other ending, so the player who stayed
	-- is actually told the duel is over instead of being left staring at a
	-- state that will never change again.
	Players.PlayerRemoving:Connect(function(player: Player)
		lastEmoteAt[player] = nil

		local duelId = duelIdOf[player]
		local duel = if duelId then duels[duelId] else nil
		if duel then
			resolve(duel, "Cancelled", `{player.Name} disconnected`)
		end
	end)
end

return DuelService
