--!strict
--[[
	DuelTypes.luau -- the server's private shape of a duel.

	Moved out of DuelService as the first seam of its split, and it is the right
	first cut because everything else depends on it and it depends on nothing.

	These types are SERVER-ONLY and deliberately not in Shared/Types. A `Side`
	holds `offer`, which holds `isFake` -- the truth. Shared/Types is reachable
	from the client, and a truth-bearing type living there would be an invitation
	nobody should have to decline (docs/gdd.md §39).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelTypes = {}

--- One side of a duel, as the server knows it. Never replicated as-is.
export type Side = {
	slot: Types.Slot,
	player: Player,
	hand: { Types.DuelCopy },
	--- nil until this side has offered. Holds the truth, including isFake.
	offer: { Types.WrappedItem }?,
	--- The rival spent a raise on you: you owe a bigger offer before play can
	--- continue. Cleared when the amendment lands.
	amendRequested: boolean,
	raisesLeft: number,
	fakeCallsLeft: number,
}

export type Duel = {
	id: string,
	phase: Types.DuelPhase,
	round: number,
	turn: Types.Slot,
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
function DuelTypes.otherSlot(slot: Types.Slot): Types.Slot
	return 3 - slot
end

return DuelTypes
