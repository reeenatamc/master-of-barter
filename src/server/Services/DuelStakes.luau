--!strict
--[[
	DuelStakes.luau -- everything a duel writes to a profile, and the ONLY place
	that knows a bot does not have one.

	Card D1, condition 1. A bot plays through the same validated surface a human
	does: same turn checks, same phases, same limits, same fake cap, same model A
	consistency. There is exactly one thing a bot genuinely cannot do, and it is
	not a rule -- it is that there is no profile to charge, stake from, or pay.

	So the divergence lives HERE, in the persistence layer, and nowhere else.
	Every function takes a `Side` and does nothing when that side is a bot. Above
	this module, no code asks whether it is playing a person.

	That is the difference between a fact and a shortcut. If a bot ever cannot do
	something through the public surface, that is a gap in the surface and gets
	fixed there -- never by letting the bot reach into duel state directly.

	WHAT THIS MEANS FOR THE ECONOMY, stated plainly because it is a real hole and
	not an oversight:

	  a bot's genuine wrappers are MINTED. `take` succeeds with nothing behind
	  it, so a copy a human wins off a bot enters their profile from nowhere.
	  This is a source docs/gdd.md §19 does not list, and it is bounded by the
	  daily bot-earnings cap rather than closed -- see docs/decisiones.md.

	  copies a bot WINS vanish. `grant` does nothing, so they leave the human's
	  escrow and go nowhere. That direction is a SINK and needs no cap: it
	  shrinks the supply, and the failure that spreads is the one that grows it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Types = require(ReplicatedStorage.Shared.Types)

local DuelTypes = require(script.Parent.DuelTypes)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

type Side = DuelTypes.Side

local isBot = DuelTypes.isBot

local DuelStakes = {}

--- Charges the Clips an offer's forgeries cost. A bot forges for free because
--- it has no balance -- not because forging is free for bots as a rule.
function DuelStakes.charge(side: Side, amount: number, reason: string): (boolean, string?)
	local player = side.player
	if not player then
		return true, nil
	end
	local paid, refusal = EconomyService.charge(player, amount, reason)
	return paid, if refusal then tostring(refusal) else nil
end

--- Escrow: a genuine copy leaves the profile as it goes on the table.
---
--- Returns true for a bot with nothing behind it. That is the minting noted
--- above, and it is deliberate: the alternative is giving bots profiles, which
--- means real DataStore keys for players who do not exist.
function DuelStakes.take(side: Side, itemId: Types.ItemId, duelId: string): boolean
	local player = side.player
	if not player then
		return true
	end
	return InventoryService.takeCopy(player, itemId, duelId)
end

--- The exact inverse of `take`: a stake coming back, with its escrow record.
function DuelStakes.giveBack(side: Side, itemId: Types.ItemId, duelId: string)
	local player = side.player
	if player then
		InventoryService.returnCopy(player, itemId, duelId)
	end
end

--- A copy won, into the profile. Nothing for a bot: the copy vanishes, which is
--- a sink and is fine.
function DuelStakes.grant(side: Side, itemId: Types.ItemId)
	local player = side.player
	if player then
		InventoryService.giveCopy(player, itemId)
	end
end

--- Forgets this duel's escrow records without returning anything, for a duel
--- that reached a reveal and already handed the copies over.
function DuelStakes.clearEscrow(side: Side, duelId: string)
	local player = side.player
	if player then
		InventoryService.clearEscrow(player, duelId)
	end
end

--- Pays out the end of a duel. A bot earns nothing: there is no balance to
--- credit, and inventing one would put a fake player in the economy's ledger.
function DuelStakes.pay(side: Side, payout: Types.DuelPayout)
	local player = side.player
	if player then
		EconomyService.payDuel(player, payout)
	end
end

--- Re-exported so callers that genuinely need the question -- payouts capped
--- against bot farming, for one -- ask it in one vocabulary.
DuelStakes.isBot = isBot

return DuelStakes
