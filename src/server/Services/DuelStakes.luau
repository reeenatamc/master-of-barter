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
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)
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
function DuelStakes.take(side: Side, itemId: Types.ItemId, duelId: string, copyId: string): boolean
	local player = side.player
	if not player then
		return true
	end
	return InventoryService.takeCopy(player, itemId, duelId, copyId)
end

--- The exact inverse of `take`: a stake coming back, with its escrow record.
function DuelStakes.giveBack(side: Side, itemId: Types.ItemId, duelId: string, copyId: string)
	local player = side.player
	if player then
		InventoryService.returnCopy(player, itemId, duelId, copyId)
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

-- ─────────────────────────────────────────────────────────────────────────────
-- The daily bot-earnings cap (card D1, condition 3)
--
-- The problem: filler opponents mint. A bot's genuine wrappers come from
-- nowhere and its Clips cost nobody anything, so beating bots is a source with
-- no sink behind it. With simple personalities somebody finds the trick fast,
-- Clips inflate, forging goes back to being free, and the brake card B2 just
-- installed comes off. By rule 5 that is the failure that spreads.
--
-- Why a cap and not a smaller reward: a different payout against a bot is an
-- obvious tell in the very first duel, and docs/gdd.md §34 rules that out.
-- Below the cap a bot duel pays exactly like a duel against a person.
--
-- ONE number for both currencies, because a bot mints both. Capping the Clips
-- alone would leave the copies farmable by the same trick.
-- ─────────────────────────────────────────────────────────────────────────────

--- UTC, so the reset does not move with the player's timezone -- or with a
--- client clock, which is not ours to trust.
local function today(): string
	return os.date("!%Y-%m-%d")
end

--- Value pulled out of bots today. Zero for a bot, and zero for anyone whose
--- counter is from another day: a stale date IS the reset, which is why nothing
--- schedules one.
function DuelStakes.botEarningsToday(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	if profile.botEarnings.date ~= today() then
		return 0
	end
	return profile.botEarnings.value
end

--- Whether this player may still take value out of filler opponents today.
function DuelStakes.mayEarnFromBots(player: Player): boolean
	return DuelStakes.botEarningsToday(player) < Economy.botEarningsCapPerDay
end

--- Adds to the day's total, resetting it first if it belongs to another day.
---
--- A single duel may carry the total PAST the cap, and that is on purpose: the
--- alternative is paying half a duel's reward, which is a rule the player would
--- have to deduce from a number that came out wrong. The overshoot is bounded
--- by one duel; a partial payout is a permanent confusion.
function DuelStakes.recordBotEarnings(side: Side, value: number)
	local player = side.player
	if not player or value <= 0 then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local stamp = today()
	if profile.botEarnings.date ~= stamp then
		profile.botEarnings.date = stamp
		profile.botEarnings.value = 0
	end
	profile.botEarnings.value += value
end

return DuelStakes
