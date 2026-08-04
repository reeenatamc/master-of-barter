--!strict
--[[
	Economy.luau -- fake crafting costs, duel rewards, shop prices

	Pure data, no logic. EconomyService is the only thing allowed to move Clips,
	but every number it uses comes from here, so balancing never touches a
	service (docs/arquitectura.md §9).

	All values below are first guesses. docs/gdd.md §19 marks the whole economy
	as "calibrar en alfa" -- expect to rewrite these once real duels produce data.
]]

--- Clips a brand new player starts with.
local startingClips = 250

--- Crafting a fake costs a share of what it imitates, so lying about an
--- expensive squishy is expensive. That scaling is the rule from docs/gdd.md
--- §19; the exact numbers are not.
--- cost = baseValue * valueShare + flatFee
local fakeCost = {
	valueShare = 0.45,
	flatFee = 15,
}

--- Paid out when a duel ends. Losing still pays something: docs/gdd.md §19
--- says "ganar > perder, pero perder da algo".
local duelReward = {
	win = 120,
	draw = 60,
	loss = 25,
	--- Added on top, always, just for finishing a duel.
	participation = 10,
	--- Per fake the rival accepted without spotting it.
	perFakeSlipped = 60,
	--- Per rival fake caught with the FakeCall token.
	perFakeCaught = 80,
}

--- Shop prices are derived from baseValue, never stored per item, so a new
--- squishy is priced automatically.
local shop = {
	buyMultiplier = 1.35,
	sellMultiplier = 0.40,
}

return {
	startingClips = startingClips,
	fakeCost = fakeCost,
	duelReward = duelReward,
	shop = shop,
}
