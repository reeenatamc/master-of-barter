--!strict
--[[
	DuelRules.luau -- phases, timers, limits (raiseOffer=3, fakes=2, fakeCall=1)

	Pure data, no logic. DuelService reads these; it never hardcodes a number.

	The three limits are load-bearing, not arbitrary:
	  - fakesPerDuel = 2 is the anti-pay-to-win ceiling. docs/gdd.md §34 allows
	    selling Clips for Robux ONLY because this cap exists. Raising it means
	    revisiting monetization.
	  - raiseOffersPerSide = 3 keeps a duel inside the 2-3 min target (§7).
	  - fakeCallsPerDuel = 1 makes the accusation a real decision (§8).

	Timers are first guesses. Etapa 1 explicitly asks to time real duels and
	tune these until a duel fits in 2-3 minutes.
]]

local limits = {
	raiseOffersPerSide = 3,
	fakesPerDuel = 2,
	fakeCallsPerDuel = 1,
	--- Backlog A1: "selecciono 1-4 objetos de mi inventario de duelo".
	minItemsPerOffer = 1,
	maxItemsPerOffer = 4,
}

--- Seconds each phase is allowed to last. Keys match Types.DuelPhase.
--- Every phase needs a value: the watchdog in docs/arquitectura.md §5 uses
--- these to guarantee no duel can hang forever.
local phaseSeconds = {
	BuildingOffers = 45,
	Negotiating = 30,
	Reveal = 8,
	Results = 12,
}

--- How long the queue waits for a human before a bot steps in (backlog D1).
local secondsBeforeBot = 15

--- Diagnostics, not balance. Turn on to trace the duel lifecycle in Output,
--- including the Trove live-object count when a duel ends and duplicate
--- finish() calls being ignored.
---
--- Off by default. Note that leaks are NOT gated by this: a non-zero live count
--- always warns. A flag can hide a confirmation, never a failure.
local debugLogs = false

return {
	limits = limits,
	phaseSeconds = phaseSeconds,
	secondsBeforeBot = secondsBeforeBot,
	debugLogs = debugLogs,
}
