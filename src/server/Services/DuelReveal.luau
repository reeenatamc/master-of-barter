--!strict
--[[
	DuelReveal.luau -- builds the whole truth of a duel, and settles the token.

	Third seam of splitting DuelService. This module produces the only replicated
	object that carries `isFake`, so where its output GOES matters as much as
	what is in it.

	It goes nowhere on its own. `build` returns a value; the caller assigns it to
	`duel.reveal`, and it reaches a client only inside a DuelState, gated on the
	phase actually being Reveal, through DuelView's single funnel. This module
	fires no remote and holds no state, which is what keeps the sanctioned-exit
	count at ONE rather than two.

	Every function here is pure: state in, value out, nothing mutated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelTypes = require(script.Parent.DuelTypes)

type Slot = Types.Slot
type WrappedItem = Types.WrappedItem
type Duel = DuelTypes.Duel

local otherSlot = DuelTypes.otherSlot

local DuelReveal = {}

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
function DuelReveal.build(duel: Duel, takenBy: { Slot }, fakeCall: Types.FakeCall?): Types.RevealResult
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
function DuelReveal.swapAll(): { Slot }
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
function DuelReveal.settleFakeCall(duel: Duel, accuser: Slot): (boolean, { Slot })
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

return DuelReveal
