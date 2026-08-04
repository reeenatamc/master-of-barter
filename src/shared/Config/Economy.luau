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
	@prop shop { buyMultiplier: number, sellMultiplier: number }
	@within Economy

	Shop prices are derived from baseValue, never stored per item, so a new
	object is priced automatically.
]=]
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
