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

function DuelController.getState(): Types.DuelState?
	return current
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

	local actions: { [Enum.KeyCode]: () -> () } = {
		[Enum.KeyCode.One] = DuelController.offerDemo,
		[Enum.KeyCode.Two] = DuelController.offerHonest,
		[Enum.KeyCode.Three] = DuelController.accept,
		[Enum.KeyCode.Four] = DuelController.decline,
		[Enum.KeyCode.Five] = DuelController.raise,
		[Enum.KeyCode.Six] = DuelController.amendDemo,
		[Enum.KeyCode.Seven] = DuelController.fakeCall,
	}

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- `processed` is true when Roblox already used the key for chat or a
		-- text box, so typing a message never fires a duel action.
		if processed then
			return
		end
		local action = actions[input.KeyCode]
		if action then
			action()
		end
	end)

	print("[Duel] keys: 1 offer 1real+1fake · 2 offer 2real · 3 accept · 4 decline · 5 raise · 6 amend · 7 ES FAKE")
end

function DuelController.start()
	Net.get(Net.names.DuelState).OnClientEvent:Connect(function(state: Types.DuelState)
		current = state
		dump(state)
	end)

	if DuelRules.debugLogs then
		bindDebugKeys()
	end

	-- Asking to queue happens AFTER the handler above is connected. Otherwise
	-- the first DuelState could arrive with nobody listening, and a
	-- RemoteEvent fired at a client with no handler is simply lost.
	Net.get(Net.names.QueueJoin):FireServer()
end

return DuelController
