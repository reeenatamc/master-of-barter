--!strict
--[[
	EconomyService.luau -- Clips: ALWAYS add/subtract through here (single gate).

	Card B2, and the brake the balance has been missing. Until now forging was
	free, which is why the first play-test's own notes predicted that "forge
	everything" would dominate, and then that "accuse always" would dominate the
	thing that beat it.

	ONE GATE, and not for tidiness. Every Clip entering or leaving a profile goes
	through `credit` and `charge`, so there is exactly one place that validates
	an amount, one place that can refuse, and one place for the transaction log
	card F3 will want. A second path into the same number is a second place for
	a balance to go wrong, and the two will disagree eventually.

	Every figure comes from Config. Nothing here decides what something costs;
	it decides whether the player can pay it (docs/arquitectura.md §9).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

--- Fired after any change, with the new balance. Fired AFTER the profile is
--- written and never before, so nothing can render a number that did not
--- actually happen.
EconomyService.balanceChanged = Signal.new()

--- Why a request was refused. Returned rather than thrown: declining to spend
--- money somebody does not have is an ordinary outcome, not an exception.
export type Refusal = "NoProfile" | "BadAmount" | "NotEnough" | "AtCeiling"

--- Rejects anything that is not a whole, positive, finite number of Clips.
--- NaN and infinity are checked explicitly, because both slip through the
--- ordinary comparisons underneath.
local function sane(amount: number): boolean
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return false
	end
	return amount > 0 and amount == math.floor(amount) and amount <= Economy.clipsMax
end

--- nil means there is no profile behind this player, which is a normal state
--- and not an error (see DataService).
function EconomyService.balanceOf(player: Player): number?
	local profile = DataService.get(player)
	return if profile then profile.clips else nil
end

function EconomyService.canAfford(player: Player, amount: number): boolean
	local balance = EconomyService.balanceOf(player)
	return balance ~= nil and sane(amount) and balance >= amount
end

--- Adds Clips. `reason` is not decoration: it is what makes the log readable
--- when a balance turns out wrong, and card F3 sends it to analytics.
function EconomyService.credit(player: Player, amount: number, reason: string): (boolean, Refusal?)
	local profile = DataService.get(player)
	if not profile then
		-- A spectator has nowhere to write this down, and quietly doing nothing
		-- would look exactly like success (docs/arquitectura.md §7).
		return false, "NoProfile"
	end
	if not sane(amount) then
		return false, "BadAmount"
	end
	if profile.clips >= Economy.clipsMax then
		return false, "AtCeiling"
	end

	-- Clamped rather than refused: somebody at the ceiling who wins a duel
	-- should still win it, they just stop accumulating.
	profile.clips = math.min(profile.clips + amount, Economy.clipsMax)

	EconomyService.balanceChanged:fire(player, profile.clips, reason)
	return true
end

--- Removes Clips. Refuses rather than going negative, and refuses BEFORE
--- touching the profile, so a rejected charge leaves nothing half-done.
function EconomyService.charge(player: Player, amount: number, reason: string): (boolean, Refusal?)
	local profile = DataService.get(player)
	if not profile then
		return false, "NoProfile"
	end
	if not sane(amount) then
		return false, "BadAmount"
	end
	if profile.clips < amount then
		return false, "NotEnough"
	end

	profile.clips -= amount
	EconomyService.balanceChanged:fire(player, profile.clips, reason)
	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Prices
--
-- Asked here rather than worked out at call sites, so nobody ends up carrying
-- their own copy of a formula. The numbers stay in Config, which is pure data
-- by rule (docs/arquitectura.md §3).
-- ─────────────────────────────────────────────────────────────────────────────

--- What forging a copy of this object costs.
---
--- Scales with what is being imitated, which is the rule of docs/gdd.md §19:
--- lying about something expensive should cost accordingly, so a forgery is a
--- bet rather than a free option. That scaling is the design; the figures
--- behind it are [propuesta] and calibrate in alpha.
function EconomyService.forgeryCost(itemId: Types.ItemId): number?
	local def = Items.catalog[itemId]
	if not def then
		return nil
	end
	local cost = Economy.fakeCost
	return math.max(1, math.floor(def.baseValue * cost.valueShare + cost.flatFee))
end

--- What an offer costs to assemble: the sum of its forgeries.
---
--- Genuine wrappers cost nothing. You already own what is inside one, and what
--- you put at risk is the object itself -- which is the whole tension of §8.
function EconomyService.offerCost(wraps: { Types.WrapRequest }): number
	local total = 0
	for _, wrap in wraps do
		if wrap.isFake then
			total += EconomyService.forgeryCost(wrap.claim) or 0
		end
	end
	return total
end

--- What a duel's end is worth, without paying it.
---
--- Split out from `payDuel` so the bot-earnings cap can ask the price before
--- deciding (card D1). Two copies of this arithmetic would be two answers to
--- one question, and the cap would drift from what was actually paid.
function EconomyService.duelPayoutValue(payout: Types.DuelPayout): number
	local rewards = Economy.duelReward
	local total = rewards.participation

	if payout.result == "win" then
		total += rewards.win
	elseif payout.result == "draw" then
		total += rewards.draw
	else
		total += rewards.loss
	end

	total += payout.fakesSlipped * rewards.perFakeSlipped
	total += payout.fakesCaught * rewards.perFakeCaught

	return total
end

--- Pays out the end of a duel: one call, one log line, one balance change,
--- rather than four credits that could half-apply if something failed between
--- them.
function EconomyService.payDuel(player: Player, payout: Types.DuelPayout): boolean
	local total = EconomyService.duelPayoutValue(payout)
	return (EconomyService.credit(player, total, `duel:{payout.result}`))
end

return EconomyService
