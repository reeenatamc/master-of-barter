--!strict
--[[
	Bots.luau -- filler opponents: names, timing and how they play.

	Card D1. Pure data, no logic (docs/arquitectura.md §3). Every number a bot's
	behaviour depends on is here, so tuning one never means reading the brain.

	The whole point of these numbers is that a bot should be indistinguishable
	from a slow human (docs/gdd.md §34). That is why the delays are ranges rather
	than constants: a rival who always answers in exactly 2.0 seconds is a
	machine after the second duel, no matter how well it plays.

	Personalities -- aggressive and timid, measurably different -- are card D2.
	This is the one middling personality they will both be measured against.
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId

--[=[
	@class Bots

	Filler opponents: names, timing and play knobs. Pure data, no logic.
]=]

--[=[
	@prop names { string }
	@within Bots

	Plausible display names. Deliberately ordinary -- a name that sounds like a
	bot is the same tell as a field named `isBot` in the payload.

	NONE of these may collide with a real Roblox account style that suggests a
	specific person: they are invented, generic, and stay that way.
]=]
local names: { string } = {
	"pau_trades",
	"ElBaruch",
	"mica.exe",
	"tomi_2011",
	"NachoOOO",
	"la_flor",
	"juanpi_77",
	"Sofi Bardo",
	"Rulo",
	"kevs",
}

--[=[
	@prop thinkSeconds { min: number, max: number }
	@within Bots

	How long a bot "thinks" before any action. Drawn fresh each time.

	The floor is not politeness: an instant answer reads as a script even when
	the decision is right. The ceiling is bounded well under
	DuelRules.phaseSeconds so a bot never times its own duel out -- a bot that
	loses to the watchdog is a bug the player experiences as the game freezing.
]=]
local thinkSeconds = { min = 1.2, max = 4.5 }

--[=[
	@prop handSize number
	@within Bots

	How many duel copies a bot brings. Matches what a starting human has, so its
	offers look like theirs.
]=]
local handSize = 4

--[=[
	@prop offerSize { min: number, max: number }
	@within Bots

	How many wrappers a bot puts on the table.
]=]
local offerSize = { min = 1, max = 2 }

--[=[
	@prop fakeChance number
	@within Bots

	Probability that any one wrapper a bot builds is a forgery.

	Middling on purpose. A bot that never lies makes accusing worthless; a bot
	that always lies makes accusing free. Both would poison the play-test that
	decides whether the token survives at all (docs/prueba-diversion-2.md).
]=]
local fakeChance = 0.35

--[=[
	@prop raiseChance number
	@within Bots

	Probability of answering an offer with "Pedir más" rather than settling.
	Only consulted while the bot still has raises left.
]=]
local raiseChance = 0.3

--[=[
	@prop fakeCallChance number
	@within Bots

	Probability of spending the token on a rival's offer, per decision.

	Low, and low on purpose: a bot that accuses often would teach players that
	accusations are cheap, which is exactly the habit the play-test is trying to
	measure honestly in humans.
]=]
local fakeCallChance = 0.12

--[=[
	@prop declineChance number
	@within Bots

	Probability of walking away instead of accepting, once it has decided not to
	raise or accuse. Kept low: a filler opponent that cancels duels leaves the
	player exactly where they started, which is the problem D1 exists to fix.
]=]
local declineChance = 0.08

--[=[
	@prop handPool { ItemId }
	@within Bots

	What a bot's hand is drawn from. The cheap end of the catalogue on purpose:
	a bot's genuine wrappers are minted from nothing (see DuelStakes), so this
	list is the size of the leak before the daily cap even applies.
]=]
local handPool: { ItemId } = {
	"golden_maruchan",
	"potato_rock",
	"grandma_remote",
	"chewed_pencil",
	"sock_one",
	"expired_yogurt",
}

return {
	names = names,
	thinkSeconds = thinkSeconds,
	handSize = handSize,
	offerSize = offerSize,
	fakeChance = fakeChance,
	raiseChance = raiseChance,
	fakeCallChance = fakeCallChance,
	declineChance = declineChance,
	handPool = handPool,
}
