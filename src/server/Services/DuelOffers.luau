--!strict
--[[
	DuelOffers.luau -- turns an untrusted payload into wrappers on the table.

	Fourth and largest seam of splitting DuelService, and the one with a real
	decision in it: the cut is NOT "move submitOffer". It is the line between
	the RULES of an offer and the FLOW of the duel around it.

	  here          parse, validate in four layers, roll appearances, charge the
	                forgeries, escrow the genuine copies -- and RETURN the result
	  DuelService   find the duel, check the phase, store the offer, hand over
	                the turn, broadcast

	Nothing in this module knows what phase comes next or how a state reaches a
	client. It answers one question -- "is this a legal offer, and if so what is
	on the table?" -- and hands the answer back. That is what lets a bot build an
	offer through the SAME validation a human goes through (card D1) instead of a
	second path that has to be kept in agreement with this one.

	Refusals come back as a string rather than being logged here, so the caller
	stays the only place that decides what a rejected request costs.

	Failure is all-or-nothing. Every check that can refuse runs before anything
	is stored, and the one mutation that happens mid-way -- escrow -- rolls
	itself back on the spot. A half-built offer never exists.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

local EconomyService = require(script.Parent.EconomyService)

local DuelStakes = require(script.Parent.DuelStakes)
local DuelTypes = require(script.Parent.DuelTypes)

type DuelCopy = Types.DuelCopy
type WrapAppearance = Types.WrapAppearance
type WrappedItem = Types.WrappedItem
type WrapRequest = Types.WrapRequest
type Side = DuelTypes.Side
type Duel = DuelTypes.Duel

local DuelOffers = {}

local rng = Random.new()

--- Both genuine and forged wrappers get all three dimensions rolled. The only
--- difference is which band they are drawn from, so the payload shape can never
--- betray which is which.
local function rollAppearance(isFake: boolean): WrapAppearance
	local band = if isFake then DuelRules.appearanceBands.forged else DuelRules.appearanceBands.genuine
	return {
		colorTone = rng:NextNumber(band.min, band.max),
		seam = rng:NextNumber(band.min, band.max),
		label = rng:NextNumber(band.min, band.max),
	}
end

--- The requests an existing offer was built from, so its cost can be worked
--- out again without storing a price alongside it. A stored price is a second
--- source of truth that goes stale the moment Config changes.
local function toRequests(wrapped: { WrappedItem }): { WrapRequest }
	local requests: { WrapRequest } = {}
	for _, item in wrapped do
		table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
	end
	return requests
end

local function findCopy(side: Side, copyId: string): DuelCopy?
	for _, copy in side.hand do
		if copy.copyId == copyId then
			return copy
		end
	end
	return nil
end

--- Validation layer 1: shape. This is where values coming off a remote stop
--- being `unknown`. Nothing below this function ever sees an unchecked field.
--- Bails as soon as the entry count passes the limit, so a huge payload cannot
--- make the server walk it.
local function parseRequests(payload: unknown): { WrapRequest }?
	if type(payload) ~= "table" then
		return nil
	end

	local requests: { WrapRequest } = {}

	for _, entry in payload :: { [any]: any } do
		if #requests >= DuelRules.limits.maxItemsPerOffer + 1 then
			return nil
		end
		if type(entry) ~= "table" then
			return nil
		end

		local raw = entry :: { [string]: any }
		local copyId, isFake, claim = raw.copyId, raw.isFake, raw.claim

		if type(isFake) ~= "boolean" or type(claim) ~= "string" then
			return nil
		end
		if copyId ~= nil and type(copyId) ~= "string" then
			return nil
		end

		table.insert(requests, { copyId = copyId, isFake = isFake, claim = claim })
	end

	return requests
end

--- Builds one side's offer, or refuses it. Validates in the four layers of
--- docs/arquitectura.md §8: types, existence against Config, duel state, then
--- ownership and economy.
---
--- Returns the wrappers, or nil and the reason. The caller does the refusing;
--- returning the reason rather than logging it keeps this module free of any
--- opinion about what a bad request costs.
---
--- `amending` comes from the caller because it is a fact about the PHASE, and
--- phases are not this module's business.
---
--- Takes a `Side`, never a `Player`. That is what lets a bot build an offer
--- through this exact function: everything that needs a profile goes through
--- DuelStakes, which no-ops for a side that is nobody (card D1).
function DuelOffers.build(
	duel: Duel,
	side: Side,
	amending: boolean,
	payload: unknown
): ({ WrappedItem }?, string?)
	-- Layer 1: types.
	local requests = parseRequests(payload)
	if not requests then
		return nil, "malformed payload"
	end

	local limits = DuelRules.limits
	local previous = side.offer
	local alreadyWrapped = if previous then #previous else 0

	-- "Add or improve" is validated by COUNT, never by real value.
	--
	-- The server knows what every wrapper truly is, so judging whether an
	-- amendment is genuinely worth more would make the rejection itself leak
	-- that knowledge: a client could probe amendments and read the truth off
	-- which ones pass. Same family as the overlapping appearance bands -- the
	-- server never answers in a way that reveals what it knows.
	local minimum = if amending and previous then #previous + 1 else limits.minItemsPerOffer
	if #requests < minimum or #requests > limits.maxItemsPerOffer then
		local what = if amending then "amendment" else "offer"
		return nil, `{what} has {#requests} wrappers, needs {minimum}-{limits.maxItemsPerOffer}`
	end

	-- Layers 2 and 4: existence against Config, then ownership.
	local wrapped: { WrappedItem } = {}
	local usedCopies: { [string]: boolean } = {}
	local fakes = 0

	for _, request in requests do
		-- Model A consistency: a forgery consumes no copy, a genuine wrapper
		-- always names one. A client that says otherwise is malformed.
		if request.isFake ~= (request.copyId == nil) then
			return nil, "isFake disagrees with copyId"
		end

		-- Existence: a claim always names a real catalogue item, forged or not.
		-- Forging something that does not exist would have no imperfection
		-- template to imitate and no value to price the Clips cost against.
		if not Items.catalog[request.claim] then
			return nil, `unknown claim "{request.claim}"`
		end

		if request.isFake then
			fakes += 1
			if fakes > limits.fakesPerDuel then
				return nil, `more than {limits.fakesPerDuel} fakes`
			end
		else
			local copyId = request.copyId :: string
			if usedCopies[copyId] then
				return nil, "same copy wrapped twice"
			end

			local copy = findCopy(side, copyId)
			if not copy then
				return nil, `does not own copy {copyId}`
			end
			-- Model A: a genuine wrapper cannot lie about what it holds. Lying
			-- is what forging is for.
			if copy.itemId ~= request.claim then
				return nil, `genuine wrapper claims {request.claim} but holds {copy.itemId}`
			end

			usedCopies[copyId] = true
		end

		table.insert(wrapped, {
			wrappedId = HttpService:GenerateGUID(false),
			copyId = request.copyId,
			isFake = request.isFake,
			claim = request.claim,
			appearance = rollAppearance(request.isFake),
		})
	end

	-- Layer 4, the economic half: forging costs Clips, scaled to what is being
	-- imitated (docs/gdd.md §19). This is card B2 and it is the brake the
	-- balance was missing -- while forging was free, "forge everything" and
	-- then "accuse always" both dominated.
	--
	-- Charged on the DELTA, never on the whole offer. An amendment adds
	-- wrappers to one already paid for, and charging the total again would bill
	-- twice for the same forgeries.
	local alreadyPaid = if previous then EconomyService.offerCost(toRequests(previous)) else 0
	local owed = EconomyService.offerCost(requests) - alreadyPaid

	if owed > 0 then
		local paid, refusal = DuelStakes.charge(side, owed, "forgery")
		if not paid then
			-- Refused BEFORE anything is stored, so a rejected offer leaves the
			-- duel exactly as it was.
			return nil, `cannot pay {owed} Clips for the forgeries ({refusal})`
		end
	end

	-- ESCROW. The genuine copies leave the profile HERE, at the moment they go
	-- on the table -- not when the duel resolves (docs/decisiones.md).
	--
	-- That is what makes a mid-duel disconnect safe: once a copy is out, ending
	-- the duel writes nothing to the player who left, so there is no ordering
	-- problem between the transfer and their profile being released. The race
	-- stops existing instead of being sequenced.
	--
	-- Only the NEW wrappers are escrowed. An amendment adds to an offer whose
	-- copies already left; taking them again would charge the stake twice.
	local newlyStaked: { Types.ItemId } = {}
	for index = alreadyWrapped + 1, #wrapped do
		local item = wrapped[index]
		if not item.isFake then
			local claim = item.claim
			if not DuelStakes.take(side, claim, duel.id) then
				-- Put back whatever was already taken in this call, so a
				-- half-escrowed offer cannot exist.
				for _, back in newlyStaked do
					DuelStakes.giveBack(side, back, duel.id)
				end
				return nil, `no longer owns a copy of {claim}`
			end
			table.insert(newlyStaked, claim)
		end
	end

	return wrapped, nil
end

return DuelOffers
