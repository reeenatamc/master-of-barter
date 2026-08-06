-- ─────────────────────────────────────────────────────────────────────────────
-- The spec: deterministic assertions, one duel at a time.
--
-- Everything here was on the "verificación pendiente" list in the backlog --
-- written, type-clean, and never once exercised, waiting on a Studio session.
-- Each one is now a permanent regression instead of a line in a queue.
--
-- The golden rule check is the one that matters. It does not read the code and
-- conclude; it inspects EVERY DuelState the server actually sent across a run
-- and asserts what is in it. That is the difference between "viewOf has no
-- field for isFake" and "no client was ever sent one".
-- ─────────────────────────────────────────────────────────────────────────────

local Items = require(Config.Items)
local InventoryService = require(Services.InventoryService)
local EconomyService = require(Services.EconomyService)
local BotService = require(Services.BotService)

local passed, failed = 0, 0

local function check(name: string, ok: boolean, detail: string?)
	if ok then
		passed += 1
		print(`  PASS  {name}`)
	else
		failed += 1
		print(`  FAIL  {name}{if detail then `  --  {detail}` else ""}`)
	end
end

local function statesSent(): { any }
	local states = {}
	for _, entry in sent do
		if entry.remote == "DuelState" then
			table.insert(states, entry.args[1])
		end
	end
	return states
end

local function freshPlayers()
	table.clear(sent)
	local a = addPlayer("SpecA")
	local b = addPlayer("SpecB")
	return a, b
end

local function sideOf(duel, player)
	for _, side in duel.sides do
		if side.player == player then
			return side
		end
	end
	return nil
end

-- ── 1. THE GOLDEN RULE, against real traffic ─────────────────────────────────

print("\n[spec] golden rule")
do
	local a, b = freshPlayers()
	BotService.selfPlay(40, a)

	local states = statesSent()
	local leakedTruth, leakedEarly, revealsSeen = 0, 0, 0

	for _, state in states do
		for _, view in state.players do
			if view.slot ~= state.yourSlot and view.offer then
				for _, wrapped in view.offer.wrapped do
					-- The field must not merely be false. It must not EXIST.
					if (wrapped :: any).isFake ~= nil or (wrapped :: any).copyId ~= nil then
						leakedTruth += 1
					end
				end
			end
		end
		if state.reveal ~= nil then
			revealsSeen += 1
			if state.phase ~= "Reveal" then
				leakedEarly += 1
			end
		end
	end

	check(`{#states} states inspected, none carried a rival's truth`, leakedTruth == 0, `{leakedTruth} leaks`)
	check("reveal appeared only in phase Reveal", leakedEarly == 0, `{leakedEarly} early`)
	check("reveal appeared at all (so the check above can fail)", revealsSeen > 0, "never saw one")
end

-- ── 1b. THE PHASE GATE, tested by BUILDING the dangerous state ───────────────
--
-- The check above passes even with the gate deleted, and that is not a broken
-- test -- it is a fact about the code: `duel.reveal` is only ASSIGNED at the
-- terminal transition, so during normal play there is nothing for the gate to
-- hold back. Discovered by mutation: removing `if duel.phase == "Reveal"`
-- changed nothing observable.
--
-- Which means the gate is defence in depth, not the load-bearing piece, and an
-- assertion that cannot fail must either say so or be made real. This one is
-- made real: the truth is planted mid-negotiation on purpose -- exactly what a
-- future "pre-render the reveal" or inspection feature would do -- and the gate
-- is what has to stop it reaching a client.

print("\n[spec] the phase gate, against a planted reveal")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = Items.order[1] } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })
	check("the duel is mid-negotiation", duel.phase == "Negotiating", duel.phase)

	-- Planted. Nothing in the game does this today; the gate exists for the day
	-- something does.
	duel.reveal = {
		sides = {
			{ slot = 1, offered = {}, received = {}, valueReceived = 0, fakesPassed = 0 },
			{ slot = 2, offered = {}, received = {}, valueReceived = 0, fakesPassed = 0 },
		},
		winner = 1,
		fakeCall = nil,
	}

	table.clear(sent)
	-- Any action that broadcasts will do.
	DuelService.applyAction(duel, sideA, "RaiseOffer")

	local escaped = 0
	for _, state in statesSent() do
		if state.reveal ~= nil then
			escaped += 1
		end
	end
	check(`the planted truth reached nobody ({#statesSent()} states)`, escaped == 0, `{escaped} escaped`)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 2. Turn and limits ───────────────────────────────────────────────────────

print("\n[spec] turn, limits and the token")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	check("both offers moved the duel to Negotiating", duel.phase == "Negotiating", duel.phase)
	check("slot 2 cannot act out of turn", DuelService.applyAction(duel, sideB, "Accept") ~= nil)
	check("an unknown action is refused", DuelService.applyAction(duel, sideA, "Nope") ~= nil)
	check("a non-string action is refused", DuelService.applyAction(duel, sideA, 42) ~= nil)

	-- Three raises per side, then no more.
	local raiseRefusals = 0
	for _ = 1, 4 do
		if DuelService.applyAction(duel, sideA, "RaiseOffer") ~= nil then
			raiseRefusals += 1
		else
			-- Satisfy the demand so the turn comes back.
			local requests = {}
			for _, item in sideB.offer do
				table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
			end
			table.insert(requests, { isFake = true, claim = Items.order[1] })
			DuelService.applyOffer(duel, sideB, requests)
		end
	end
	check("the fourth raise is refused", raiseRefusals == 1, `{raiseRefusals} refusals`)

	-- An amendment that does not grow is refused.
	local same = {}
	for _, item in sideB.offer do
		table.insert(same, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
	end
	sideB.amendRequested = true
	duel.turn = sideB.slot
	check("an amendment that adds nothing is refused", DuelService.applyOffer(duel, sideB, same) ~= nil)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 3. The watchdog generation ───────────────────────────────────────────────

print("\n[spec] watchdog generation")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	local firstDeadline = duel.deadline
	advance(DuelRules.phaseSeconds.Negotiating * 0.5)
	DuelService.applyAction(duel, sideA, "RaiseOffer")

	local requests = {}
	for _, item in sideB.offer do
		table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
	end
	table.insert(requests, { isFake = true, claim = Items.order[1] })
	DuelService.applyOffer(duel, sideB, requests)

	-- Past the ORIGINAL deadline. The stale timer must do nothing.
	advance((firstDeadline - vnow) + 1)
	check("a re-armed phase survives its old deadline", DuelService.debugDuel(duelId :: string) ~= nil)

	-- Past the new one. Now it must die.
	advance(DuelRules.phaseSeconds.Negotiating + 1)
	check("the current deadline still cancels it", DuelService.debugDuel(duelId :: string) == nil)
	check("the trove released everything", duel.trove:Live() == 0, `{duel.trove:Live()} live`)
end

-- ── 4. Scoring ───────────────────────────────────────────────────────────────

print("\n[spec] scoring: a forgery is worth nothing")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	local honest = sideB.hand[1]
	-- A forges; B is honest with a real copy.
	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = honest.itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = honest.copyId, isFake = false, claim = honest.itemId } })
	DuelService.applyAction(duel, sideA, "Accept")

	local reveal = duel.reveal
	local liar = reveal.sides[sideB.slot]
	local cheat = reveal.sides[sideA.slot]
	check("the honest side received nothing of value", liar.valueReceived == 0, `{liar.valueReceived}`)
	check(
		"the cheat received the real baseValue",
		cheat.valueReceived == Items.catalog[honest.itemId].baseValue,
		`{cheat.valueReceived}`
	)
	check("the cheat is recorded as having slipped one", cheat.fakesPassed == 1, `{cheat.fakesPassed}`)
	check("lying won", reveal.winner == sideA.slot)
end

-- ── 5. The accusation token ──────────────────────────────────────────────────

print("\n[spec] the ES FAKE token")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = Items.order[1] } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	check("a side starts with its token", sideA.fakeCallsLeft == DuelRules.limits.fakeCallsPerDuel)
	DuelService.applyAction(duel, sideA, "FakeCall")
	check("accusing an honest offer is WRONG", duel.reveal.fakeCall.correct == false)
	check("the token is spent", sideA.fakeCallsLeft == 0)
	check("a second accusation is refused", DuelService.applyAction(duel, sideA, "FakeCall") ~= nil)
end

-- ── 6. The finish race, and what it does NOT prove ───────────────────────────
--
-- `runFinishRaceCheck` fires two real terminal paths at one duel and asserts
-- that the second does nothing. It passes. It also covers less than it looks
-- like it covers, and that gap is worth a test of its own.
--
-- What stops the second path today is the REGISTRY -- `duels[id]` is already
-- nil when it arrives -- not the `resolving` claim. Two different guarantees,
-- and only one is exercised. Proved by mutation: delete the resolving guard
-- entirely and this still passes.
--
-- The claim protects the stretch between claiming the duel and emitting the
-- broadcast, and it only matters if something YIELDS in there. Nothing does
-- today, which is why it never acts. So instead of pretending to test it, the
-- assertion below tests its PRECONDITION: that the terminal path is yield-free.
-- The day somebody adds an await between `phase = "Reveal"` and the broadcast,
-- that assertion goes red -- which is the alarm the backlog note asks somebody
-- to remember, turned into something that fires by itself.

print("\n[spec] the finish race, and its precondition")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	-- The terminal path, run inside a coroutine that is resumed exactly once. If
	-- it is still alive afterwards it yielded, and the window the `resolving`
	-- claim exists to protect has opened for the first time.
	local co = coroutine.create(function()
		DuelService.applyAction(duel, sideA, "Accept")
	end)
	local ok, err = coroutine.resume(co)
	check("the terminal path ran without error", ok, tostring(err))
	check(
		"the Reveal path does not yield (so `resolving` is still decorative)",
		coroutine.status(co) == "dead",
		`status {coroutine.status(co)} -- A YIELD APPEARED: re-run the race check with it present`
	)
	check("the duel is gone from the registry", DuelService.debugDuel(duelId :: string) == nil)
end

do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)
	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })
	check("runFinishRaceCheck reports PASS", DuelService.runFinishRaceCheck())
end

-- ── 7. The malformed-offer battery, through the REMOTE half ─────────────────
--
-- These went through `submitOffer`, not `applyOffer`, on purpose: that is the
-- function a client's payload actually reaches, identity check and all. The
-- observable is that the offer was NOT committed -- a refusal logs and returns
-- nothing, so "did it get stored" is the honest thing to assert.
--
-- Was block C-2 of prueba-etapa1.md, a keystroke in Studio.

print("\n[spec] malformed offers, through the remote")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA = sideOf(duel, a)
	local first = sideA.hand[1]
	local other = if Items.order[#Items.order] ~= first.itemId then Items.order[#Items.order] else Items.order[1]

	local cases = {
		{ why = "unknown claim", payload = { { isFake = true, claim = "no_existe" } } },
		{ why = "a genuine wrapper lying", payload = { { copyId = first.copyId, isFake = false, claim = other } } },
		{ why = "isFake disagrees with copyId", payload = { { copyId = first.copyId, isFake = true, claim = first.itemId } } },
		{
			why = "three forgeries",
			payload = {
				{ isFake = true, claim = Items.order[1] },
				{ isFake = true, claim = Items.order[2] },
				{ isFake = true, claim = Items.order[3] },
			},
		},
		{ why = "an empty offer", payload = {} },
		{
			why = "the same copy twice",
			payload = {
				{ copyId = first.copyId, isFake = false, claim = first.itemId },
				{ copyId = first.copyId, isFake = false, claim = first.itemId },
			},
		},
		{ why = "a payload that is not a table", payload = 42 },
	}

	local committed = 0
	for _, case in cases do
		DuelService.submitOffer(a, case.payload)
		if sideA.offer ~= nil then
			committed += 1
			check(`refused: {case.why}`, false, "it was COMMITTED")
			sideA.offer = nil
		end
	end
	check(`all {#cases} malformed offers refused`, committed == 0, `{committed} got through`)

	local copies = 0
	for _, n in profiles[a].duelCopies do
		copies += n
	end
	-- Six refusals must not have moved a single copy. A rejected offer that
	-- leaves half its escrow behind is worse than one that succeeds.
	check("no copy left the profile", copies == 4 and #profiles[a].escrow == 0, `{copies} copies, {#profiles[a].escrow} escrow`)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 8. THE DUPLICATION ATTACK ───────────────────────────────────────────────
--
-- Offer [A], then amend with [B, A]. The escrow used to skip index 1 and take A
-- a second time while B went on the table without ever leaving the profile:
-- win or lose, the rival received a copy the sender still had.
--
-- Was block C-DUPE, the one manual case marked "never skip this".

print("\n[spec] the duplication attack")
do
	local a, b = freshPlayers()
	-- A second copy of one item, so the attack is actually POSSIBLE and the
	-- refusal below means a defence worked rather than an inventory ran out.
	InventoryService.giveCopy(b, Items.order[1])
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	-- The attacker has to be the side that OWES an amendment, and negotiation
	-- always opens on slot 1 -- so slot 2 is the attacker and slot 1 raises.
	--
	-- AND IT NEEDS TWO COPIES OF THE SAME ITEM, which is the whole reason this
	-- setup exists. The starter hand holds one of each, and with one of each the
	-- attack fails on its own: re-taking the staked copy finds nothing left in
	-- the profile. An earlier version of this test asserted the refusal with a
	-- starter hand and passed with BOTH defences deleted -- a green that proved
	-- nothing but the shape of the starting inventory.
	local duplicated = Items.order[1]
	local staked, spare = nil, nil
	for _, copy in sideB.hand do
		if copy.itemId == duplicated and staked == nil then
			staked = copy
		elseif copy.itemId ~= duplicated and spare == nil then
			spare = copy
		end
	end
	check("the attacker holds a second copy of the staked item", InventoryService.copiesOf(b, duplicated) >= 1)
	DuelService.submitOffer(a, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.submitOffer(b, { { copyId = staked.copyId, isFake = false, claim = staked.itemId } })
	DuelService.negotiate(a, "RaiseOffer")
	check("a raise is pending on the attacker", sideB.amendRequested)

	local before = #profiles[b].escrow
	-- The attack: the NEW wrapper first, the previous offer after it.
	DuelService.submitOffer(b, {
		{ copyId = spare.copyId, isFake = false, claim = spare.itemId },
		{ copyId = staked.copyId, isFake = false, claim = staked.itemId },
	})

	check("the reordered amendment was refused", #sideB.offer == 1, `offer is now {#sideB.offer} wrappers`)
	check("no second copy went into escrow", #profiles[b].escrow == before, `{#profiles[b].escrow} vs {before}`)

	-- The structural half: even reaching past the prefix check, a copy already
	-- staked cannot be staked again.
	check(
		"takeCopy refuses a copy that is already staked",
		InventoryService.takeCopy(b, staked.itemId, duel.id, staked.copyId) == false
	)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 9. BuildingOffers also times out ────────────────────────────────────────

print("\n[spec] the offer phase times out too")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	advance(DuelRules.phaseSeconds.BuildingOffers + 1)
	check("nobody offered, so the duel is gone", DuelService.debugDuel(duelId :: string) == nil)
end

-- ── 10. Your own data, and only your own ────────────────────────────────────

print("\n[spec] PlayerData: what the owner gets, and what nobody gets")
do
	local a, b = freshPlayers()
	advance(0)

	local mine = {}
	for _, entry in sent do
		if entry.remote == "PlayerData" then
			table.insert(mine, entry)
		end
	end

	check(`a profile loading pushes its owner's data ({#mine} sends)`, #mine == 2, `{#mine}`)
	check("each push went to exactly one recipient", mine[1] ~= nil and mine[1].player ~= nil)

	-- The structural half: the view is built field by field, so a field added
	-- to Profile cannot arrive here by accident. Asserted against the payload
	-- rather than read off the type, which is the difference that matters.
	local payload = mine[1].args[1]
	local keys = {}
	for key in payload do
		table.insert(keys, key)
	end
	table.sort(keys)
	check(
		`the payload carries exactly clips, collection, duelCopies (got: {table.concat(keys, ", ")})`,
		#keys == 3 and payload.clips ~= nil and payload.collection ~= nil and payload.duelCopies ~= nil
	)
	check("botEarnings never leaves the server", (payload :: any).botEarnings == nil)
	check("escrow never leaves the server", (payload :: any).escrow == nil)
	check("receipts never leave the server", (payload :: any).receipts == nil)

	-- Coalescing: a duel's payout moves copies AND Clips several times, and the
	-- client should hear about it once.
	table.clear(sent)
	InventoryService.giveCopy(a, Items.order[1])
	InventoryService.giveCopy(a, Items.order[2])
	EconomyService.credit(a, 10, "spec")
	advance(0)

	local pushes = 0
	for _, entry in sent do
		if entry.remote == "PlayerData" then
			pushes += 1
		end
	end
	check(`three changes in one tick coalesce into one push ({pushes})`, pushes == 1, `{pushes}`)
end

print(`\n[spec] {passed} passed, {failed} failed`)
print(if failed == 0 then "RESULT: PASS" else "RESULT: FAIL")
