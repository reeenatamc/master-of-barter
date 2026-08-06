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

--- Forwards one event to Roblox Analytics.
---
--- ⚠️ UNVERIFIED API. `LogCustomEvent(player, eventName, value, customFields)`
--- is written from memory and has NOT been checked against
--- create.roblox.com/docs. That is exactly why `Analytics.sendToRoblox` ships
--- OFF: rule 5 of this project says an invented API costs hours, and the honest
--- move is to isolate the guess in one function nothing depends on rather than
--- to assert it and find out in Studio.
---
--- Everything downstream already works without it -- events reach the console
--- and the buffer regardless. Whoever verifies the signature flips the flag; if
--- it is wrong, this function is the only thing that changes.
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

	local ok, err = pcall(function()
		engine:LogCustomEvent(player, event, 1, fields)
	end)
	if not ok then
		engineDisabled = true
		warn(`[Analytics] engine sink disabled after: {err}`)
	end
end

--- Records one event. The only way anything gets counted.
---
--- `player` is optional because not every event belongs to somebody: a duel
--- between two bots has nobody in it, and an event about the SERVER is still
--- worth having.
function AnalyticsService.record(event: string, fields: Fields, player: Player?)
	table.insert(buffer, { event = event, fields = fields, player = if player then player.Name else nil })
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
end

return AnalyticsService
