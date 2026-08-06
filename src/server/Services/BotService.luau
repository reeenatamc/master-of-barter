--!strict
--[[
	BotService.luau -- the filler opponent's brain.

	Card D1. It plays badly and that is fine: D1's question is "can a player who
	joins an empty server start a duel", not "is the opponent good". Measurably
	different personalities are card D2.

	WHAT MAKES THIS SAFE IS WHAT IT DOES NOT DO. It never touches duel state. It
	never sets a phase, moves a turn, or writes an offer. Every move goes through
	`DuelService.applyOffer` / `applyAction` -- the exact functions a remote
	reaches one identity check later: same four layers, same order, same
	refusals.

	So a bug in here produces a REFUSED action, logged, rather than a corrupt
	duel. And if a bot ever cannot do something through those functions, that is
	a gap in the public surface and gets fixed there, never worked around here.

	IT ALSO CANNOT SEE THROUGH A WRAPPER. The bot reads its own `side.hand` and
	nothing about what the rival is holding. `isFake` on the rival's wrappers is
	never consulted -- a bot that peeked would be an unbeatable accuser, and it
	would poison the very play-test the token's survival depends on
	(docs/prueba-diversion-2.md). Its accusations are blind rolls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelService = require(script.Parent.DuelService)
local DuelTypes = require(script.Parent.DuelTypes)
local InventoryService = require(script.Parent.InventoryService)

type Side = DuelTypes.Side
type Duel = DuelTypes.Duel

local isBot = DuelTypes.isBot
local otherSlot = DuelTypes.otherSlot

local BotService = {}

local rng = Random.new()

--- Duels with a move already scheduled, so a burst of state changes cannot
--- queue up several. Keyed by duel id, cleared when the move runs.
local thinking: { [string]: boolean } = {}

--- Duels whose entry in `thinking` already has a cleanup registered. Without
--- this, a duel that ends with a move in flight leaves its id behind forever:
--- the trove cancels the thread, so the line that would have cleared it never
--- runs. One stale key per duel is small and permanent, which is the shape of a
--- leak on a server that stays up for days.
local watched: { [string]: boolean } = {}

--- Set while a self-play run is going (see the bottom of this file). Without
--- it, 200 duels at a human's pace is half an hour of waiting.
local fastThinking = false

--- While a puppet run is going, this player's side is played by the brain too.
---
--- Only reason it exists: in a pure bot-vs-bot duel NOTHING touches a profile,
--- so "escrow ended at zero" is true because escrow was never written -- a
--- vacuous green. Driving one side that HAS a profile makes the charge, the
--- stake, the payout and the cap accounting real, and only then does the escrow
--- assertion certify anything.
local puppet: Player? = nil

--- How many times the liveness net had to catch a move the brain did not expect
--- to be refused.
---
--- INSTRUMENTED BECAUSE IT IS A NET, NOT A STRATEGY. The fallback exists so a
--- refused action can never leave a bot holding the turn with nothing to do --
--- but every activation is the brain meeting a state it did not predict, and
--- that is information, not a shrug.
---
--- Two readings, both wanted:
---   in self-play  it must sit at 0. Anything else is a new hole in the brain,
---                 and the run fails on it.
---   against people TODO(F3): this goes to analytics. A player who works out how
---                 to corner a bot into refusals gets a FORCED ACCEPT every
---                 time, which is a way to farm good trades out of a rival that
---                 has run out of legal moves. The net stops the freeze; this
---                 counter is what would tell us somebody is milking it.
---
--- The deliberate decline in `makeAmendment` -- "I cannot meet your demand, so I
--- walk away" -- is NOT counted. That is a legal move the brain chose on
--- purpose, and folding it in here would bury the signal under normal play.
local fallbacks = 0

--- Reads the counter. TODO(F3): AnalyticsService reports this per server rather
--- than leaving it for whoever thinks to look.
function BotService.fallbackCount(): number
	return fallbacks
end

local function thinkTime(): number
	if fastThinking then
		return 0.03
	end
	return rng:NextNumber(Bots.thinkSeconds.min, Bots.thinkSeconds.max)
end

--- Builds the payload a client would have sent. A genuine wrapper names a copy
--- the bot actually holds; a forgery names any catalogue item and holds nothing.
---
--- `taken` comes in from the caller so an amendment cannot wrap a copy already
--- on the table -- the same "same copy wrapped twice" rule the server would
--- refuse it with anyway.
---
--- `fakesAlready` is the same story for the forgery cap. An amendment resends an
--- offer that may already hold the maximum, and a bot that appended one more got
--- refused and then sat there owing an amendment it could never make -- a duel
--- frozen until the watchdog killed it. Found by self-play at duel 106 of 200.
---
--- Returns FEWER than `count` when nothing legal is left to add. The caller has
--- to handle that rather than send a short offer and be refused.
local function buildRequests(
	side: Side,
	count: number,
	taken: { [string]: boolean },
	fakesAlready: number
): { Types.WrapRequest }
	local requests: { Types.WrapRequest } = {}
	local fakes = fakesAlready
	local limit = DuelRules.limits.fakesPerDuel

	for _ = 1, count do
		local free: { Types.DuelCopy } = {}
		for _, copy in side.hand do
			if not taken[copy.copyId] then
				table.insert(free, copy)
			end
		end

		local mayForge = fakes < limit
		local wantsFake = mayForge and rng:NextNumber() < Bots.fakeChance
		-- Out of copies: forge instead of offering less, as long as forging is
		-- still allowed.
		if not wantsFake and #free == 0 and mayForge then
			wantsFake = true
		end

		if wantsFake then
			local claim = Items.order[rng:NextInteger(1, #Items.order)]
			table.insert(requests, { copyId = nil, isFake = true, claim = claim })
			fakes += 1
		elseif #free > 0 then
			local copy = free[rng:NextInteger(1, #free)]
			taken[copy.copyId] = true
			table.insert(requests, { copyId = copy.copyId, isFake = false, claim = copy.itemId })
		else
			-- No copy left and the forgery cap is spent. Nothing legal to add.
			break
		end
	end

	return requests
end

--- Everything already on the table, as requests, plus the copies it uses. An
--- amendment must begin with the offer it amends unchanged (see DuelOffers), so
--- this is exactly the required prefix.
local function currentRequests(side: Side): ({ Types.WrapRequest }, { [string]: boolean })
	local requests: { Types.WrapRequest } = {}
	local taken: { [string]: boolean } = {}

	-- Annotated: `x or {}` infers a union with the empty-table type, which is
	-- not iterable.
	local onTable: { Types.WrappedItem } = side.offer or {}
	for _, item in onTable do
		table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
		local copyId = item.copyId
		if copyId then
			taken[copyId] = true
		end
	end

	return requests, taken
end

local function makeOffer(duel: Duel, side: Side)
	local size = rng:NextInteger(Bots.offerSize.min, Bots.offerSize.max)
	local refusal = DuelService.applyOffer(duel, side, buildRequests(side, size, {}, 0))
	if refusal then
		warn(`[BotService] {side.displayName} could not offer: {refusal}`)
	end
end

local function makeAmendment(duel: Duel, side: Side)
	local requests, taken = currentRequests(side)

	local fakes = 0
	for _, request in requests do
		if request.isFake then
			fakes += 1
		end
	end

	-- Exactly one more than what is there: what "Pedir más" asked for.
	local extra = buildRequests(side, 1, taken, fakes)

	--- Walking away is legal, immediate, and what a person would do. It is the
	--- difference between a rival who says no and a rival who goes silent for
	--- thirty seconds until the watchdog ends the duel.
	local function giveUp(why: string)
		warn(`[BotService] {side.displayName} declines: cannot amend ({why})`)
		local refusal = DuelService.applyAction(duel, side, "Decline")
		if refusal then
			warn(`[BotService] {side.displayName} could not even decline: {refusal}`)
		end
	end

	if #extra == 0 then
		-- Expected and legal: not a fallback activation.
		return giveUp("no copy left to wrap and no forgery left to make")
	end

	for _, request in extra do
		table.insert(requests, request)
	end

	local refusal = DuelService.applyOffer(duel, side, requests)
	if refusal then
		-- Declining on ANY refusal, not just the ones predicted above. A bot that
		-- owes an amendment and does nothing is a frozen duel, and the reason it
		-- froze does not change what the player sees.
		fallbacks += 1
		return giveUp(refusal)
	end
end

--- Answers the rival's offer. The rolls are blind, which is the point.
---
--- NEVER ENDS ITS TURN WITHOUT HAVING ACTED. This is the rule the whole brain
--- hangs on, and self-play found both places it was broken: a bot whose chosen
--- action is refused still HOLDS THE TURN, so if it does nothing the duel sits
--- there until the phase watchdog kills it. The player's experience is a rival
--- that freezes and a duel that dies for no visible reason.
---
--- So every refusal falls back to Accept, which is always legal for whoever
--- holds the turn in Negotiating. Accepting a bad trade is a worse move than
--- raising; freezing is not a move at all.
local function decide(duel: Duel, side: Side)
	local action: Types.DuelAction

	-- A raise against an offer already at the maximum is refused by the server
	-- (nothing could be added to answer it), so it is not offered as a choice
	-- here either. Checked rather than left to the fallback: choosing an action
	-- known to be illegal and recovering from it would hide the next real bug in
	-- a warning that is normal.
	local rival = duel.sides[otherSlot(side.slot)]
	local rivalOffer = rival.offer
	local rivalAtMax = rivalOffer ~= nil and #rivalOffer >= DuelRules.limits.maxItemsPerOffer

	if side.fakeCallsLeft > 0 and rng:NextNumber() < Bots.fakeCallChance then
		action = "FakeCall"
	elseif side.raisesLeft > 0 and not rivalAtMax and rng:NextNumber() < Bots.raiseChance then
		action = "RaiseOffer"
	elseif rng:NextNumber() < Bots.declineChance then
		action = "Decline"
	else
		action = "Accept"
	end

	local refusal = DuelService.applyAction(duel, side, action)
	if not refusal then
		return
	end

	fallbacks += 1
	warn(`[BotService] {side.displayName} could not {action}: {refusal}; accepting instead`)
	local fallback = DuelService.applyAction(duel, side, "Accept")
	if fallback then
		-- Nothing legal left at all. Loud, because it means this bot is about to
		-- let a duel die and the reason is not one of the two already known.
		warn(`[BotService] {side.displayName} CANNOT ACT AT ALL: {fallback}`)
	end
end

--- What this bot owes the duel right now, or nil if it is not its move.
local function pendingMove(duel: Duel, side: Side): ((Duel, Side) -> ())?
	if duel.phase == "BuildingOffers" then
		return if side.offer == nil then makeOffer else nil
	end

	if duel.phase == "Negotiating" and duel.turn == side.slot then
		return if side.amendRequested then makeAmendment else decide
	end

	return nil
end

--- Reacts to a state change. Every bot side in every duel gets asked, so a duel
--- between two bots plays itself -- which is what card D2's 200-duel stress run
--- will need.
local function onStateChanged(duel: Duel)
	if thinking[duel.id] then
		return
	end

	for _, side in duel.sides do
		if not isBot(side) and side.player ~= puppet then
			continue
		end

		local move = pendingMove(duel, side)
		if not move then
			continue
		end

		thinking[duel.id] = true

		if not watched[duel.id] then
			watched[duel.id] = true
			duel.trove:Add(function()
				thinking[duel.id] = nil
				watched[duel.id] = nil
			end)
		end

		-- Registered in the DUEL's trove, so a duel that ends by any route --
		-- reveal, decline, timeout, the human disconnecting -- takes its bot's
		-- pending move with it. Nothing is left to fire into a finished duel.
		duel.trove:Delay(thinkTime(), function()
			thinking[duel.id] = nil

			-- Asked again rather than trusted: seconds passed, and the human may
			-- have raised, amended or walked away. applyOffer/applyAction would
			-- refuse a stale move anyway; this only keeps an ordinary change of
			-- circumstances out of the warning log.
			if pendingMove(duel, side) == move then
				move(duel, side)
			end
		end)

		return
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Self-play (card D2's stress run, brought forward)
--
-- Bot against bot, hundreds of duels, nobody watching. Card D2 lists this under
-- its tests and docs/arquitectura.md §11 calls it out as a whole testing
-- strategy, for a good reason: it exercises leaks, hung phases and lopsided
-- balance without costing a person an evening.
--
-- It is here BEFORE the personalities D2 is really about, because the
-- personalities are not worth writing yet -- until A2 alternates turns, slot 2
-- can only ever answer a raise, so a "timid" and an "aggressive" bot would be
-- indistinguishable against a human. The harness has no such dependency and
-- pays off today: every duel it runs is a full pass through the split, the
-- offer validation, the escrow and the reveal.
--
-- What it CANNOT check is the thing bots are worst at: whether any of this is
-- fun. That is still a room with two people in it.
-- ─────────────────────────────────────────────────────────────────────────────

--- Runs `count` duels back to back and reports numbers rather than impressions.
---
--- With `opponent`, one side is that player's REAL side -- their profile, their
--- copies, their Clips -- played by this same brain. That is the only way the
--- escrow assertion means anything: without a profile, escrow is never written,
--- so "ended at zero" would be true of a system that had no escrow at all.
---
--- DEBUG ONLY: leans on DuelService.startBotDuel / startAgainstBot, and the
--- first refuses unless DuelRules.debugLogs is on.
function BotService.selfPlay(count: number, opponent: Player?)
	if fastThinking then
		warn("[BotService] a self-play run is already going")
		return
	end

	local outcomes: { [string]: number } = {}
	local leaks = 0
	local stuckEscrow = 0
	local done = 0

	local connection
	connection = DuelService.duelFinished:connect(function(duelId: string, reason: string, live: number)
		-- Grouped by the shape of the reason, not the whole string: it carries a
		-- slot number, so counting raw strings would produce one bucket each.
		local kind = if string.find(reason, "accepted", 1, true)
			then "accepted"
			elseif string.find(reason, "called fake", 1, true) then "fake called"
			elseif string.find(reason, "declined", 1, true) then "declined"
			elseif string.find(reason, "timed out", 1, true) then "TIMED OUT"
			else reason

		outcomes[kind] = (outcomes[kind] or 0) + 1
		if live ~= 0 then
			leaks += 1
		end

		-- Asked AFTER finish has run, which is when the invariant is due: every
		-- stake either came back or was handed over, and either way its record
		-- is gone.
		local left = InventoryService.escrowCountFor(duelId)
		if left ~= 0 then
			stuckEscrow += left
			warn(`[BotService] duel {duelId} left {left} copies stuck in escrow`)
		end

		done += 1
	end)

	fastThinking = true
	puppet = opponent
	local fallbacksBefore = fallbacks
	local startedAt = os.clock()

	for index = 1, count do
		local started = if opponent
			then DuelService.startAgainstBot(opponent)
			else DuelService.startBotDuel()

		if not started then
			warn(`[BotService] self-play stopped at duel {index}: could not start`)
			break
		end

		-- Waited for one at a time on purpose. Overlapping duels would make a
		-- hang look like slowness, and a hang is exactly what this is hunting.
		local waitedFrom = done
		-- Comfortably past the longest phase timeout, so a duel the WATCHDOG
		-- cancels still arrives here as a finished duel with reason "timed out"
		-- -- a loud outcome. If this deadline raced the watchdog they would be
		-- indistinguishable, and a cancelled duel would be reported as a hang.
		local deadline = os.clock() + 120
		while done == waitedFrom and os.clock() < deadline do
			task.wait(0.05)
		end

		if done == waitedFrom then
			warn(`[BotService] duel {index} NEVER FINISHED -- a phase is hung. Stopping.`)
			break
		end
	end

	fastThinking = false
	puppet = nil
	connection:disconnect()

	local mode = if opponent then `vs {opponent.Name} (real profile)` else "bot vs bot"
	print(`[BotService] self-play {mode}: {done}/{count} duels in {string.format("%.1f", os.clock() - startedAt)}s`)
	for kind, n in outcomes do
		print(`  {kind}: {n}`)
	end
	print(`  duels that leaked a live object : {leaks}   (expected 0)`)

	if opponent then
		print(`  copies stuck in escrow          : {stuckEscrow}   (expected 0)`)
	else
		print(`  copies stuck in escrow          : {stuckEscrow}   (VACUOUS -- no profile in play)`)
	end

	-- A timed-out duel counts as a FAILURE, not an outcome. With bots acting in
	-- hundredths of a second a watchdog should never have to rescue anything, so
	-- every timeout means a side could not act. Reporting PASS beside a
	-- "TIMED OUT: 2" line is exactly the false green this project keeps finding.
	local timeouts = outcomes["TIMED OUT"] or 0
	-- The liveness net firing at all means the brain met a refusal it did not
	-- predict. It is a net, not a strategy, so a run where it was needed is a run
	-- that found something.
	local netFired = fallbacks - fallbacksBefore
	local ok = leaks == 0 and stuckEscrow == 0 and done == count and timeouts == 0 and netFired == 0
	if timeouts > 0 then
		print(`  duels a watchdog had to rescue  : {timeouts}   (expected 0 -- a side could not act)`)
	end
	print(`  liveness fallbacks fired        : {netFired}   (expected 0 -- a hole in the brain)`)
	print(if ok then "  RESULT: PASS" else "  RESULT: FAIL")
end

--- Wires the service. Called by Main after DuelService, whose signal it needs.
function BotService.init()
	DuelService.stateChanged:connect(onStateChanged)
end

return BotService
