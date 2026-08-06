--!strict
--[[
	Analytics.luau -- event names and where they go.

	Card F3. Pure data, no logic (docs/arquitectura.md §3).

	The event NAMES live here rather than as string literals at each call site,
	for the same reason remote names live in Net: a typo produces a second event
	that looks like a third of your traffic vanished, and it fails silently.
]]

--[=[
	@class Analytics

	Event names and delivery settings for AnalyticsService. Pure data.
]=]

--[=[
	@prop events { [string]: string }
	@within Analytics

	Every event the MVP records. docs/arquitectura.md §10 names the minimum set:
	the onboarding funnel, a duel started and finished, and purchases.

	The rest are not decoration -- each one exists because a specific decision
	needs it:

	  duelFinished     the bluff balance. §8 marks the accusation token as the
	                   one mechanic to keep or cut with DATA, and this is that
	                   data: raises spent, forgeries offered, who accused and
	                   whether they were right.
	  escrowOrphaned   copies lost to a server that died mid-duel. Rare and
	                   invisible; without this, compensating anybody by hand is
	                   impossible.
	  requestRejected  refused remotes. Spam patterns are exploit candidates
	                   (docs/arquitectura.md §8).
	  botFallback      the bot's liveness net firing. A player who works out how
	                   to corner a bot into refusals gets a forced Accept every
	                   time; this is what says somebody is milking it.
]=]
local events = {
	duelStarted = "duel_started",
	duelFinished = "duel_finished",
	escrowOrphaned = "escrow_orphaned",
	requestRejected = "request_rejected",
	botFallback = "bot_fallback",
	shopPurchase = "shop_purchase",
}

--[=[
	@prop sendToRoblox boolean
	@within Analytics

	Whether to forward events to Roblox's own AnalyticsService.

	**ON**, since the API was verified against create.roblox.com/docs on
	2026-08-05. What that verification changed is in `AnalyticsService`: Roblox
	keeps only three custom fields and only as breakdown dimensions, so what
	goes out is a PROJECTION of each event, not the event.
]=]
local sendToRoblox = true

--[=[
	@prop uniqueCombinationBudget number
	@within Analytics

	How many distinct three-field combinations this server will send before it
	stops attaching custom fields at all.

	Roblox caps an experience at **8,000 unique combinations across the three
	fields**, and that ceiling is shared by every event and never resets. One
	bug that puts an unbounded value in a field -- a copy id, a player name, a
	Clips amount -- burns the whole budget permanently and takes the useful
	breakdowns down with it.

	So this sits well under the real cap and is a circuit breaker, not a target:
	crossing it means something is wrong, and the right failure is to keep
	counting events with no breakdown rather than to poison the account.
]=]
local uniqueCombinationBudget = 2000

--[=[
	@prop bufferSize number
	@within Analytics

	How many recent events to keep in memory for tests and the Developer
	Console. A ring buffer, not a log: this must never grow without bound on a
	server that stays up for days.
]=]
local bufferSize = 200

return {
	events = events,
	sendToRoblox = sendToRoblox,
	uniqueCombinationBudget = uniqueCombinationBudget,
	bufferSize = bufferSize,
}
