--!strict
--[[
	AnalyticsService.luau -- one door for every event worth counting.

	Card F3, and its own card says why it lands now rather than later:
	"instrumentar tarde = alfa a ciegas". The alpha decides whether the
	accusation token survives (docs/gdd.md §8), and that decision needs numbers
	collected while people played, not reconstructed afterwards.

	ONE DOOR, same reasoning as EconomyService being the only gate for Clips: one
	place that names events, one place that shapes them, one place to change when
	the destination changes. Events fired from four call sites with four string
	literals become four different events the first time somebody mistypes one,
	and it fails silently.

	NOTHING HERE MAY THROW. Analytics is the least important thing in any code
	path it sits in -- a duel that ends must end even if the event describing it
	could not be sent. The engine sink is wrapped, and a sink that fails is
	DISABLED rather than retried, so a broken destination cannot become a warning
	per duel forever.

	It also never sees `isFake` before a reveal. It records what a duel DID --
	counts, results, whether an accusation was right -- and every truth it
	reports is one that has already become public (docs/gdd.md §39).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Analytics = require(ReplicatedStorage.Shared.Config.Analytics)
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)

local AnalyticsService = {}

export type Fields = { [string]: any }
export type Entry = { event: string, fields: Fields, player: string? }

--- Recent events, oldest first. A RING, not a log: a server that stays up for
--- days must not accumulate one table per duel forever.
local buffer: { Entry } = {}

--- Set when the engine sink errors. A destination that is broken now is broken
--- for the next event too, and a warning per duel is how a small failure
--- becomes the reason nobody reads the output any more.
local engineDisabled = false

--- Roblox's own AnalyticsService, fetched lazily. Held this way so the module
--- loads in a plain Luau runtime: the self-play harness runs the real duel code
--- with no engine behind it, and a `GetService` at require time would break it.
local engine: any = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- The projection
--
-- Roblox custom events are AGGREGATIONS, not stored rows. An event carries a
-- name, a numeric value, and **three** custom fields that exist only as
-- breakdown dimensions -- and only the keys CustomField01/02/03 are honoured.
-- Any other key is IGNORED IN SILENCE, which means `{raises = 3, fakes = 2}`
-- would have compiled, run, and thrown the data away.
--
-- So the internal event stays the source of truth -- the full row, with the
-- accusation as a field, is still the right shape and is what the buffer holds
-- -- and what goes OUT is a projection of it: which dimensions are worth asking
-- a breakdown about.
--
-- Every field value must be a STRING, and the whole experience is capped at
-- 8,000 unique combinations across the three, shared and permanent. That cap is
-- why the projections below are deliberately coarse.
-- ─────────────────────────────────────────────────────────────────────────────

--- Strips the variable parts out of one of our own refusal messages, so a
--- bounded set of message TEMPLATES comes out the other side.
---
--- This is why it is a normalisation and not a lookup table of known reasons: a
--- table has to be maintained, and the day somebody edits a message the bucket
--- silently stops matching -- the same false green, one level up. Stripping is
--- mechanical, needs no maintenance, and a new message buckets itself.
---
--- The cardinality risk here is real and specific. `does not own copy
--- {copyId}` and `cannot stake copy {copyId} of {itemId}` carry GUIDs; sending
--- those raw would burn the account's 8,000 combinations in one busy afternoon
--- and take every useful breakdown with them, permanently.
local function templateOf(reason: string): string
	-- Ids first: a GUID would otherwise be eaten piecemeal by the digit rule.
	--
	-- Eight hex characters before the dash, not "%x+", so an ordinary range like
	-- "needs 1-4" is left for the digit rule below. Loose enough and it swallows
	-- real distinctions into one bucket, which costs nothing in cardinality and
	-- everything in being able to read the breakdown.
	local out = string.gsub(reason, "%x%x%x%x%x%x%x%x%-[%x%-]+", "<id>")
	out = string.gsub(out, '"[^"]*"', "<x>")
	out = string.gsub(out, "%d+", "<n>")
	return out
end

--- Distinct combinations produced, so the circuit breaker can count them.
local seenCombinations: { [string]: boolean } = {}
local combinationCount = 0
local breakdownsDisabled = false

--- Folds one event's fields into at most three breakdown dimensions.
type Projection = (fields: Fields) -> { string }

--- One entry per event, and the combination arithmetic written down beside it.
--- Adding a dimension without doing this arithmetic is how the 8,000 gets spent
--- by accident.
local PROJECTIONS: { [string]: Projection } = {
	-- 5 x 3 x 7 = 105 combinations. This is the one docs/gdd.md §8 needs: does
	-- the accusation token earn its place? Asked as a breakdown of outcome by
	-- how many forgeries were on the table.
	[Analytics.events.duelFinished] = function(fields)
		local accusation = if fields.accusedBy == nil
			then "acusacion-no_hubo"
			elseif fields.accusationCorrect then "acusacion-acerto"
			else "acusacion-fallo"
		return {
			`fakes-{fields.fakesOffered}`,
			accusation,
			`raises-{fields.raisesUsed}`,
		}
	end,

	-- 2 combinations.
	[Analytics.events.duelStarted] = function(fields)
		return { if fields.againstBot then "rival-bot" else "rival-humano" }
	end,

	-- One per message template in the codebase; a few dozen, bounded by the
	-- source rather than by anything a client sends.
	[Analytics.events.requestRejected] = function(fields)
		return { templateOf(tostring(fields.reason)) }
	end,

	-- 5 actions x a few dozen templates.
	[Analytics.events.botFallback] = function(fields)
		return { tostring(fields.wanted), templateOf(tostring(fields.refusal)) }
	end,

	-- One per catalogue item.
	[Analytics.events.shopPurchase] = function(fields)
		return { tostring(fields.itemId) }
	end,
	[Analytics.events.escrowOrphaned] = function(fields)
		return { tostring(fields.itemId) }
	end,
}

--- Forwards one event to Roblox Analytics.
---
--- Verified against create.roblox.com/docs on 2026-08-05:
--- `LogCustomEvent(player, eventName, value, customFields)`, value defaulting
--- to 1 and used for aggregation.
local function sendToEngine(event: string, fields: Fields, player: Player?)
	if engineDisabled or not Analytics.sendToRoblox or not player then
		return
	end

	if engine == nil then
		local ok, service = pcall(function()
			return game:GetService("AnalyticsService")
		end)
		engine = if ok then service else false
	end
	if not engine then
		engineDisabled = true
		return
	end

	local custom: { [string]: string } = {}

	if not breakdownsDisabled then
		local keys = Enum.AnalyticsCustomFieldKeys
		local names = { keys.CustomField01.Name, keys.CustomField02.Name, keys.CustomField03.Name }
		for index, value in AnalyticsService.projectionOf(event, fields) do
			if index > 3 then
				break
			end
			custom[names[index]] = value
		end
	end

	local ok, err = pcall(function()
		engine:LogCustomEvent(player, event, 1, custom)
	end)
	if not ok then
		engineDisabled = true
		warn(`[Analytics] engine sink disabled after: {err}`)
	end
end

--- What the projection would send for this event. Exposed so a test can assert
--- on the dimensions without an engine behind it.
function AnalyticsService.projectionOf(event: string, fields: Fields): { string }
	local projection = PROJECTIONS[event]
	return if projection then projection(fields) else {}
end

--- How many distinct three-field combinations this server has PRODUCED.
---
--- Counted in `record`, not in the sink, and that distinction is the point: the
--- 8,000 is spent by what we would send, so the number has to be knowable with
--- the sink off -- which is how the self-play harness can prove the arithmetic
--- written beside each projection instead of trusting it.
function AnalyticsService.combinationCount(): number
	return combinationCount
end

--- Records one event. The only way anything gets counted.
---
--- `player` is optional because not every event belongs to somebody: a duel
--- between two bots has nobody in it, and an event about the SERVER is still
--- worth having.
function AnalyticsService.record(event: string, fields: Fields, player: Player?)
	table.insert(buffer, { event = event, fields = fields, player = if player then player.Name else nil })

	-- The breakdown dimensions this event would occupy, counted whether or not
	-- anything is listening. See `combinationCount`.
	local values = AnalyticsService.projectionOf(event, fields)
	if #values > 0 and not breakdownsDisabled then
		local combination = `{event}\u{1F}{table.concat(values, "\u{1F}")}`
		if not seenCombinations[combination] then
			seenCombinations[combination] = true
			combinationCount += 1
			if combinationCount > Analytics.uniqueCombinationBudget then
				-- Events keep flowing WITHOUT breakdowns from here on. Losing the
				-- dimensions on one server is recoverable; spending the
				-- experience's permanent 8,000 is not.
				breakdownsDisabled = true
				warn(
					`[Analytics] {combinationCount} unique field combinations -- past the budget.`
						.. ` Breakdowns are off for this server; something is putting an`
						.. ` unbounded value in a custom field.`
				)
			end
		end
	end
	if #buffer > Analytics.bufferSize then
		table.remove(buffer, 1)
	end

	if DuelRules.debugLogs then
		local keys: { string } = {}
		for key in fields do
			table.insert(keys, key)
		end
		-- Sorted, so one event always prints its fields in the same order and
		-- two lines can be compared by eye.
		table.sort(keys)

		local parts: { string } = {}
		for _, key in keys do
			table.insert(parts, `{key}={tostring(fields[key])}`)
		end
		print(`[Analytics] {event} {table.concat(parts, " ")}`)
	end

	sendToEngine(event, fields, player)
end

--- Everything recorded so far, oldest first. For tests and the Developer
--- Console. A copy, so nobody can hold the ring and mutate it.
function AnalyticsService.recent(): { Entry }
	return table.clone(buffer)
end

--- How many of one event are in the buffer. What a test asserts on.
function AnalyticsService.countOf(event: string): number
	local total = 0
	for _, entry in buffer do
		if entry.event == event then
			total += 1
		end
	end
	return total
end

--- Empties the ring, so a test can count from a known point.
function AnalyticsService.reset()
	table.clear(buffer)
	table.clear(seenCombinations)
	combinationCount = 0
	breakdownsDisabled = false
end

return AnalyticsService
