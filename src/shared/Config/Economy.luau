--!strict
--[[
	Economy.luau -- fake crafting costs, duel rewards, shop prices

	Pure data, no logic. EconomyService is the only thing allowed to move Clips,
	but every number it uses comes from here, so balancing never touches a
	service (docs/arquitectura.md §9).

	All values below are first guesses. docs/gdd.md §19 marks the whole economy
	as "calibrar en alfa" -- expect to rewrite these once real duels produce data.
]]

--[=[
	@class Economy

	Fake crafting costs, duel rewards and shop prices. Pure data, no logic:
	EconomyService is the only thing allowed to move Clips, but every number it
	uses comes from here, so balancing never touches a service.

	All values are first guesses. docs/gdd.md §19 marks the whole economy as
	"calibrar en alfa" -- expect to rewrite these once real duels produce data.
]=]

--[=[
	@prop startingClips number
	@within Economy

	Clips a brand new player starts with.
]=]
local startingClips = 250

--[=[
	@prop clipsMax number
	@within Economy

	Hard ceiling on a balance.

	Not paranoia about rich players: it is what stops one bad addition from
	parking a profile at a value that no longer round-trips through a DataStore
	cleanly. That kind of corruption never announces itself.
]=]
local clipsMax = 100000000

--[=[
	@prop fakeCost { valueShare: number, flatFee: number }
	@within Economy

	Crafting a fake costs a share of what it imitates, so lying about an
	expensive object is expensive. That scaling is the rule from docs/gdd.md
	§19; the exact numbers are not.

	`cost = baseValue * valueShare + flatFee`
]=]
local fakeCost = {
	valueShare = 0.45,
	flatFee = 15,
}

--[=[
	@prop duelReward { win: number, draw: number, loss: number, participation: number, perFakeSlipped: number, perFakeCaught: number }
	@within Economy

	Paid out when a duel ends. Losing still pays something: docs/gdd.md §19 says
	"ganar > perder, pero perder da algo".

	- `participation` is added on top, always, just for finishing a duel.
	- `perFakeSlipped` is per fake the rival accepted without spotting it.
	- `perFakeCaught` is per rival fake caught with the FakeCall token.
]=]
local duelReward = {
	win = 120,
	draw = 60,
	loss = 25,
	participation = 10,
	perFakeSlipped = 60,
	perFakeCaught = 80,
}

--[=[
	@prop shop { buyMultiplier: number }
	@within Economy

	Shop prices are derived from baseValue, never stored per item, so a new
	object is priced automatically.

	There is no sell multiplier, and its absence is deliberate. One existed here
	unused, written from the generic idea of a shop rather than from any line of
	the design, and it was removed as case (d): selling from the collection is
	forbidden by a locked gdd.md §21, selling copies would add a Clips source
	§19 never decided, and either way a lossy round trip proposes no decision to
	the player. If a sink or a source is ever needed, it gets designed into §19
	first and coded second (docs/decisiones.md).
]=]
local shop = {
	buyMultiplier = 1.35,
}

--[=[
	@prop kiosk { slots: number, rotationSeconds: number }
	@within Economy

	The kiosk's rotating stock.

	Rotation is on a clock and seeded from the window number, so every server
	shows the SAME objects at the same moment. Different kiosks per server would
	make the shop read as a slot machine, and gdd.md §34 rules out anything that
	does.

	Four slots out of twelve objects: enough that a rotation is worth checking,
	few enough that what is missing is felt.
]=]
--[=[
	@prop botEarningsCapPerDay number
	@within Economy

	How much VALUE one player may pull out of filler opponents in a day: Clips
	won plus the baseValue of the copies received, against this single number.

	Anti-farming, and shaped so that nothing changes below it (card D1). A duel
	against a bot pays exactly like a duel against a person until the cap is
	reached -- no reduced reward, because a different payout would be an obvious
	tell in the first duel, and docs/gdd.md §34 rules that out.

	Set around four generous duels' worth: enough that an ordinary session in an
	empty server never touches it, low enough that farming is not a living.
	[propuesta] -- it calibrates in alpha, like every other figure here.
]=]
local botEarningsCapPerDay = 900

local kiosk = {
	slots = 4,
	rotationSeconds = 900,
}

return {
	startingClips = startingClips,
	clipsMax = clipsMax,
	fakeCost = fakeCost,
	duelReward = duelReward,
	shop = shop,
	kiosk = kiosk,
	botEarningsCapPerDay = botEarningsCapPerDay,
}
