--!strict
--[[
	DuelView.luau -- the ONE way duel state becomes something a client can see.

	Second seam of splitting DuelService, and the delicate one. `stateFor` was
	already the single funnel through which anything left that module; the split
	had to keep that true, not merely move it.

	It came out STRONGER than before. `viewOf` and `stateFor` are local to this
	file and nothing else can reach them, so no other module can even obtain a
	DuelState -- the only way duel state reaches a client is `broadcast`, which
	censors on the way out. Before the split, `stateFor` was at least callable
	from anywhere inside a 1000-line file.

	The rule this protects (docs/gdd.md §39): a rival never learns `isFake`
	before the reveal. `viewOf` copies field by field into a type that has
	nowhere to put it, and never clones a table -- so forgetting is impossible
	rather than merely unlikely.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelTypes = require(script.Parent.DuelTypes)

type Slot = Types.Slot
type DuelPlayerView = Types.DuelPlayerView
type DuelState = Types.DuelState
type WrappedItem = Types.WrappedItem
type WrappedItemView = Types.WrappedItemView
type Duel = DuelTypes.Duel

local DuelView = {}

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
			displayName = side.displayName,
			handCount = #side.hand,
			raisesLeft = side.raisesLeft,
			mustAmend = side.amendRequested,
			fakeCallsLeft = side.fakeCallsLeft,
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

function DuelView.broadcast(duel: Duel)
	local remote = Net.get(Net.names.DuelState)
	for _, side in duel.sides do
		-- A bot has no client. Skipped here rather than at the call site, so
		-- nothing above this module has to know a side might not be a person.
		local player = side.player
		if player then
			remote:FireClient(player, stateFor(duel, side.slot))
		end
	end
end

return DuelView
