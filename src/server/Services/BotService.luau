--!strict
--[[
	BotService.luau -- the filler opponent's brain.

	Card D1. It plays badly and that is fine: D1's question is "can a player who
	joins an empty server start a duel", not "is the opponent good". Measurably
	different personalities are card D2.

	WHAT MAKES THIS SAFE IS WHAT IT DOES NOT DO. It never touches duel state. It
	never sets a phase, moves a turn, or writes an offer. Every move goes through
	`DuelService.applyOffer` / `applyAction` -- the exact functions a remote
	reaches one identity check later: same four layers, same order, same
	refusals.

	So a bug in here produces a REFUSED action, logged, rather than a corrupt
	duel. And if a bot ever cannot do something through those functions, that is
	a gap in the public surface and gets fixed there, never worked around here.

	IT ALSO CANNOT SEE THROUGH A WRAPPER. The bot reads its own `side.hand` and
	nothing about what the rival is holding. `isFake` on the rival's wrappers is
	never consulted -- a bot that peeked would be an unbeatable accuser, and it
	would poison the very play-test the token's survival depends on
	(docs/prueba-diversion-2.md). Its accusations are blind rolls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelService = require(script.Parent.DuelService)
local DuelTypes = require(script.Parent.DuelTypes)

type Side = DuelTypes.Side
type Duel = DuelTypes.Duel

local isBot = DuelTypes.isBot

local BotService = {}

local rng = Random.new()

--- Duels with a move already scheduled, so a burst of state changes cannot
--- queue up several. Keyed by duel id, cleared when the move runs.
local thinking: { [string]: boolean } = {}

--- Duels whose entry in `thinking` already has a cleanup registered. Without
--- this, a duel that ends with a move in flight leaves its id behind forever:
--- the trove cancels the thread, so the line that would have cleared it never
--- runs. One stale key per duel is small and permanent, which is the shape of a
--- leak on a server that stays up for days.
local watched: { [string]: boolean } = {}

local function thinkTime(): number
	return rng:NextNumber(Bots.thinkSeconds.min, Bots.thinkSeconds.max)
end

--- Builds the payload a client would have sent. A genuine wrapper names a copy
--- the bot actually holds; a forgery names any catalogue item and holds nothing.
---
--- `taken` comes in from the caller so an amendment cannot wrap a copy already
--- on the table -- the same "same copy wrapped twice" rule the server would
--- refuse it with anyway.
local function buildRequests(side: Side, count: number, taken: { [string]: boolean }): { Types.WrapRequest }
	local requests: { Types.WrapRequest } = {}

	for _ = 1, count do
		local wantsFake = rng:NextNumber() < Bots.fakeChance

		if not wantsFake then
			local free: { Types.DuelCopy } = {}
			for _, copy in side.hand do
				if not taken[copy.copyId] then
					table.insert(free, copy)
				end
			end

			-- If nothing is left, fall through to a forgery rather than offer
			-- fewer wrappers than asked: a short offer gets refused and the bot
			-- would sit still, which the player experiences as a frozen duel.
			if #free > 0 then
				local copy = free[rng:NextInteger(1, #free)]
				taken[copy.copyId] = true
				table.insert(requests, { copyId = copy.copyId, isFake = false, claim = copy.itemId })
				continue
			end
		end

		local claim = Items.order[rng:NextInteger(1, #Items.order)]
		table.insert(requests, { copyId = nil, isFake = true, claim = claim })
	end

	return requests
end

--- Everything already on the table, as requests, plus the copies it uses. An
--- amendment must begin with the offer it amends unchanged (see DuelOffers), so
--- this is exactly the required prefix.
local function currentRequests(side: Side): ({ Types.WrapRequest }, { [string]: boolean })
	local requests: { Types.WrapRequest } = {}
	local taken: { [string]: boolean } = {}

	-- Annotated: `x or {}` infers a union with the empty-table type, which is
	-- not iterable.
	local onTable: { Types.WrappedItem } = side.offer or {}
	for _, item in onTable do
		table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
		local copyId = item.copyId
		if copyId then
			taken[copyId] = true
		end
	end

	return requests, taken
end

local function makeOffer(duel: Duel, side: Side)
	local size = rng:NextInteger(Bots.offerSize.min, Bots.offerSize.max)
	local refusal = DuelService.applyOffer(duel, side, buildRequests(side, size, {}))
	if refusal then
		warn(`[BotService] {side.displayName} could not offer: {refusal}`)
	end
end

local function makeAmendment(duel: Duel, side: Side)
	local requests, taken = currentRequests(side)
	-- Exactly one more than what is there: what "Pedir más" asked for.
	for _, extra in buildRequests(side, 1, taken) do
		table.insert(requests, extra)
	end

	local refusal = DuelService.applyOffer(duel, side, requests)
	if refusal then
		warn(`[BotService] {side.displayName} could not amend: {refusal}`)
	end
end

--- Answers the rival's offer. The rolls are blind, which is the point.
local function decide(duel: Duel, side: Side)
	local action: Types.DuelAction

	if side.fakeCallsLeft > 0 and rng:NextNumber() < Bots.fakeCallChance then
		action = "FakeCall"
	elseif side.raisesLeft > 0 and rng:NextNumber() < Bots.raiseChance then
		action = "RaiseOffer"
	elseif rng:NextNumber() < Bots.declineChance then
		action = "Decline"
	else
		action = "Accept"
	end

	local refusal = DuelService.applyAction(duel, side, action)
	if refusal then
		warn(`[BotService] {side.displayName} could not {action}: {refusal}`)
	end
end

--- What this bot owes the duel right now, or nil if it is not its move.
local function pendingMove(duel: Duel, side: Side): ((Duel, Side) -> ())?
	if duel.phase == "BuildingOffers" then
		return if side.offer == nil then makeOffer else nil
	end

	if duel.phase == "Negotiating" and duel.turn == side.slot then
		return if side.amendRequested then makeAmendment else decide
	end

	return nil
end

--- Reacts to a state change. Every bot side in every duel gets asked, so a duel
--- between two bots plays itself -- which is what card D2's 200-duel stress run
--- will need.
local function onStateChanged(duel: Duel)
	if thinking[duel.id] then
		return
	end

	for _, side in duel.sides do
		if not isBot(side) then
			continue
		end

		local move = pendingMove(duel, side)
		if not move then
			continue
		end

		thinking[duel.id] = true

		if not watched[duel.id] then
			watched[duel.id] = true
			duel.trove:Add(function()
				thinking[duel.id] = nil
				watched[duel.id] = nil
			end)
		end

		-- Registered in the DUEL's trove, so a duel that ends by any route --
		-- reveal, decline, timeout, the human disconnecting -- takes its bot's
		-- pending move with it. Nothing is left to fire into a finished duel.
		duel.trove:Delay(thinkTime(), function()
			thinking[duel.id] = nil

			-- Asked again rather than trusted: seconds passed, and the human may
			-- have raised, amended or walked away. applyOffer/applyAction would
			-- refuse a stale move anyway; this only keeps an ordinary change of
			-- circumstances out of the warning log.
			if pendingMove(duel, side) == move then
				move(duel, side)
			end
		end)

		return
	end
end

--- Wires the service. Called by Main after DuelService, whose signal it needs.
function BotService.init()
	DuelService.stateChanged:connect(onStateChanged)
end

return BotService
