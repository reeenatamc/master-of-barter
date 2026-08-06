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

	**OFF, and deliberately.** The engine binding is written but its exact
	signature has NOT been checked against create.roblox.com/docs, and this
	project's rule 5 says an invented API costs hours. Flipping this on is a
	five-minute job for whoever verifies `LogCustomEvent` -- until then every
	event still reaches the console and the in-memory buffer, so nothing
	downstream is waiting on it.
]=]
local sendToRoblox = false

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
	bufferSize = bufferSize,
}
