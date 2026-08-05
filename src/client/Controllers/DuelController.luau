--!strict
--[[
	DuelController.luau -- mirrors duel state, sends actions.

	This is a mirror, not a second copy of the rules. It never decides anything:
	it holds whatever the server last sent and asks for actions. Any number it
	shows comes from DuelState or from Config, and the server recalculates
	everything regardless (docs/arquitectura.md §4).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelController = {}

local current: Types.DuelState? = nil
local listeners: { (Types.DuelState) -> () } = {}
local emoteListeners: { (Types.Slot, string) -> () } = {}

function DuelController.getState(): Types.DuelState?
	return current
end

--- Subscribes to server state. Kept as a plain list rather than a Signal
--- because the client side has exactly one subscriber (the UI) and no need for
--- disconnection: the controller lives as long as the client does.
function DuelController.onStateChanged(listener: (Types.DuelState) -> ())
	table.insert(listeners, listener)
end

local function nameOf(itemId: Types.ItemId): string
	return Strings.itemNames[itemId] or itemId
end

local function describe(appearance: Types.WrapAppearance): string
	return string.format("tone %.2f seam %.2f label %.2f", appearance.colorTone, appearance.seam, appearance.label)
end

--- TEMP: prints the keys the server actually sent for a rival wrapper.
---
--- This is the payload-level check of docs/gdd.md §39, not a UI check: if
--- `isFake` or `copyId` ever shows up in this list, the golden rule is broken
--- no matter what the interface chooses to draw.
local function dumpRivalFields(wrapped: Types.WrappedItemView)
	local fields = (wrapped :: any) :: { [string]: any }
	local keys: { string } = {}
	for key in fields do
		table.insert(keys, key)
	end
	table.sort(keys)
	print(`      server sent fields: {table.concat(keys, ", ")}`)
end

--- TEMP: there is no duel UI yet (card E2), so the state goes to Output.
local function dump(state: Types.DuelState)
	print(`[Duel] {state.duelId}`)
	print(`  phase={state.phase} round={state.round} turn=slot{state.turn} you=slot{state.yourSlot}`)

	for _, view in state.players do
		local marker = if view.slot == state.yourSlot then " (you)" else ""
		local owes = if view.mustAmend then ", OWES A BIGGER OFFER" else ""
		print(`  slot{view.slot}: {view.displayName}{marker} -- {view.handCount} copies, {view.raisesLeft} raises left{owes}`)

		if view.offer and view.slot ~= state.yourSlot then
			print("    their offer:")
			for _, wrapped in view.offer.wrapped do
				print(`      "{nameOf(wrapped.claim)}" -- {describe(wrapped.appearance)}`)
				dumpRivalFields(wrapped)
			end
		end
	end

	if state.reveal then
		print("  ── THE REVEAL ──")
		local call = state.reveal.fakeCall
		if call then
			local who = if call.by == state.yourSlot then "you" else `slot{call.by}`
			local outcome = if call.correct then "and was RIGHT" else "and was WRONG"
			print(`  {who} shouted ES FAKE {outcome}`)
		end
		for _, side in state.reveal.sides do
			local marker = if side.slot == state.yourSlot then " (you)" else ""
			print(`  slot{side.slot}{marker} offered:`)
			for _, wrapped in side.offered do
				local truth = if wrapped.isFake then "FAKE" else "real"
				print(`    "{nameOf(wrapped.claim)}" was {truth}`)
			end
			print(`    walks away with {side.valueReceived} in value, slipped {side.fakesPassed} fake(s)`)
		end
		if state.reveal.winner then
			local who = if state.reveal.winner == state.yourSlot then "YOU WIN" else "you lose"
			print(`  {who}`)
		else
			print("  a tie")
		end
	end

	if state.yourOffer then
		print("  your offer (with the truth, because it is yours):")
		for _, wrapped in state.yourOffer do
			local kind = if wrapped.isFake then "FORGED" else "genuine"
			print(`    "{nameOf(wrapped.claim)}" -- {kind} -- {describe(wrapped.appearance)}`)
		end
	else
		print("  your hand:")
		for _, copy in state.yourHand do
			print(`    {nameOf(copy.itemId)}  [{copy.itemId}]  copyId={copy.copyId}`)
		end
	end
end

--- Sends a raw offer. Exposed so invalid payloads can be fired from the
--- Command Bar to exercise server validation. The real UI is card E2.
function DuelController.offer(requests: { Types.WrapRequest })
	Net.get(Net.names.DuelOffer):FireServer(requests)
end

--- TEMP convenience: one genuine wrapper holding your first copy, plus one
--- forgery of the most valuable item in the catalogue.
function DuelController.offerDemo()
	local state = current
	if not state then
		warn("[Duel] no state yet -- is there a duel running?")
		return
	end

	local first = state.yourHand[1]
	if not first then
		warn("[Duel] your hand is empty")
		return
	end

	DuelController.offer({
		{ copyId = first.copyId, isFake = false, claim = first.itemId },
		{ isFake = true, claim = Items.order[#Items.order] },
	})
end

--- Sends a negotiation action. Takes the raw value so an invalid one can be
--- fired from the Command Bar to exercise server validation.
function DuelController.negotiate(action: string)
	Net.get(Net.names.DuelNegotiate):FireServer(action)
end

function DuelController.accept()
	DuelController.negotiate("Accept")
end

function DuelController.decline()
	DuelController.negotiate("Decline")
end

function DuelController.raise()
	DuelController.negotiate("RaiseOffer")
end

function DuelController.fakeCall()
	DuelController.negotiate("FakeCall")
end

--- Sends a reaction. The server validates the id, the cooldown and that you are
--- actually in a duel, so nothing here needs to check anything.
function DuelController.emote(emoteId: string)
	Net.get(Net.names.DuelEmote):FireServer(emoteId)
end

--- Reactions arriving from the server. Separate from state on purpose: an emote
--- is an event that happened, not a fact about the duel, so it never touches
--- DuelState and never goes through the view model.
function DuelController.onEmote(listener: (slot: Types.Slot, emoteId: string) -> ())
	table.insert(emoteListeners, listener)
end

--- TEMP: an entirely honest offer -- your cheapest copy plus your best one.
--- The counterpart to offerDemo, so two clients can play cheat vs honest.
function DuelController.offerHonest()
	local state = current
	if not state then
		warn("[Duel] no state yet -- is there a duel running?")
		return
	end

	local cheap, best = state.yourHand[1], state.yourHand[#state.yourHand - 1]
	if not cheap or not best then
		warn("[Duel] not enough copies in hand")
		return
	end

	DuelController.offer({
		{ copyId = cheap.copyId, isFake = false, claim = cheap.itemId },
		{ copyId = best.copyId, isFake = false, claim = best.itemId },
	})
end

--- ATTACK, on purpose: the duplication exploit, as a permanent regression case.
---
--- Amends with the NEW wrapper first and the previous offer after it. The server
--- used to escrow "everything past index #previous", trusting that the first
--- entries were the offer being amended -- so this ordering made it stake the
--- old copy a second time while the new one went on the table WITHOUT ever
--- leaving the profile. Win or lose, the rival received a copy the sender still
--- had. Duplication.
---
--- Two independent things must refuse this now, and BOTH are the point:
---   DuelOffers   an amendment must begin with the offer it amends
---   takeCopy     a copyId already in escrow cannot be staked again
--- The first gives the clear message; the second is why no future path can
--- reintroduce the hole by assuming an order again.
---
--- Kept in the client rather than a test script because there is no other way
--- to send a hand-built payload: Studio's Command Bar has its own module cache
--- and its own globals, so it cannot reach this controller (see bindDebugKeys).
function DuelController.dupeAttempt()
	local state = current
	if not state or not state.yourOffer then
		warn("[Duel] no offer of yours to amend -- offer first, then have the rival raise")
		return
	end

	local spare: Types.DuelCopy? = nil
	for _, copy in state.yourHand do
		local staked = false
		for _, wrapped in state.yourOffer do
			if wrapped.copyId == copy.copyId then
				staked = true
				break
			end
		end
		if not staked then
			spare = copy
			break
		end
	end

	if not spare then
		warn("[Duel] every copy is already on the table; the attack needs a spare one")
		return
	end

	-- The new wrapper FIRST. That is the whole attack.
	local requests: { Types.WrapRequest } = {
		{ copyId = spare.copyId, isFake = false, claim = spare.itemId },
	}
	for _, wrapped in state.yourOffer do
		table.insert(requests, { copyId = wrapped.copyId, isFake = wrapped.isFake, claim = wrapped.claim })
	end

	print("[Duel] sending the dupe payload: new wrapper first, previous offer after")
	DuelController.offer(requests)
end

--- TEMP: re-sends your offer with one extra forgery, which is the cheapest way
--- to satisfy a raise. Real amendment UI is card E2.
function DuelController.amendDemo()
	local state = current
	if not state or not state.yourOffer then
		warn("[Duel] no offer of yours to amend")
		return
	end

	local requests: { Types.WrapRequest } = {}
	for _, wrapped in state.yourOffer do
		table.insert(requests, { copyId = wrapped.copyId, isFake = wrapped.isFake, claim = wrapped.claim })
	end
	table.insert(requests, { isFake = true, claim = Items.order[1] })

	DuelController.offer(requests)
end

--- TEMP: drives the prototype from the keyboard until the real UI exists (E2).
---
--- Why keys and not the command bar: Studio's command bar runs in its own Lua
--- environment, with its own module cache AND its own globals. `require` there
--- hands back a second, empty copy of this module, and `_G` set here is not the
--- `_G` the bar sees. There is no way to reach the live controller from that
--- console. A key binding runs inside the client itself, so it just works.
local function bindDebugKeys()
	local UserInputService = game:GetService("UserInputService")

	-- Letters, not digits: 1-9 are the backpack hotbar, so Roblox consumes them
	-- before anything here sees them. WASD is movement, so those are out too.
	local actions: { [Enum.KeyCode]: { label: string, run: () -> () } } = {
		[Enum.KeyCode.Q] = { label = "offer 1 real + 1 FAKE", run = DuelController.offerDemo },
		[Enum.KeyCode.E] = { label = "offer 2 real", run = DuelController.offerHonest },
		[Enum.KeyCode.R] = { label = "accept", run = DuelController.accept },
		[Enum.KeyCode.T] = { label = "decline", run = DuelController.decline },
		[Enum.KeyCode.Z] = { label = "raise", run = DuelController.raise },
		[Enum.KeyCode.X] = { label = "amend", run = DuelController.amendDemo },
		[Enum.KeyCode.C] = { label = "ES FAKE", run = DuelController.fakeCall },
		[Enum.KeyCode.V] = { label = "DUPE ATTACK (must be refused)", run = DuelController.dupeAttempt },
	}

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local action = actions[input.KeyCode]
		if not action then
			return
		end
		-- `processed` is true when Roblox already used the key, for chat or a
		-- text box, so typing a message never fires a duel action. Reported
		-- rather than swallowed: a key that seems dead is otherwise impossible
		-- to tell apart from one that never arrived.
		if processed then
			print(`[Duel] key {input.KeyCode.Name} ignored: the game used it (chat open?)`)
			return
		end
		print(`[Duel] key {input.KeyCode.Name} -> {action.label}`)
		action.run()
	end)

	print("[Duel] KEYS: Q offer 1real+1FAKE · E offer 2real · R accept · T decline · Z raise · X amend · C ES FAKE")
end

function DuelController.start()
	Net.get(Net.names.DuelState).OnClientEvent:Connect(function(state: Types.DuelState)
		current = state
		if DuelRules.debugLogs then
			dump(state)
		end
		for _, listener in listeners do
			listener(state)
		end
	end)

	if DuelRules.debugLogs then
		bindDebugKeys()
	end

	Net.get(Net.names.DuelEmote).OnClientEvent:Connect(function(slot: Types.Slot, emoteId: string)
		for _, listener in emoteListeners do
			listener(slot, emoteId)
		end
	end)

	-- Asking to queue happens AFTER the handler above is connected. Otherwise
	-- the first DuelState could arrive with nobody listening, and a
	-- RemoteEvent fired at a client with no handler is simply lost.
	Net.get(Net.names.QueueJoin):FireServer()
end

return DuelController
