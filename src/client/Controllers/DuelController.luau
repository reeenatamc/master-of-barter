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
		print(`  slot{view.slot}: {view.displayName}{marker} -- {view.handCount} copies, {view.raisesLeft} raises left`)

		if view.offer and view.slot ~= state.yourSlot then
			print("    their offer:")
			for _, wrapped in view.offer.wrapped do
				print(`      "{nameOf(wrapped.claim)}" -- {describe(wrapped.appearance)}`)
				dumpRivalFields(wrapped)
			end
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

function DuelController.start()
	Net.get(Net.names.DuelState).OnClientEvent:Connect(function(state: Types.DuelState)
		current = state
		dump(state)
	end)

	-- Asking to queue happens AFTER the handler above is connected. Otherwise
	-- the first DuelState could arrive with nobody listening, and a
	-- RemoteEvent fired at a client with no handler is simply lost.
	Net.get(Net.names.QueueJoin):FireServer()
end

return DuelController
