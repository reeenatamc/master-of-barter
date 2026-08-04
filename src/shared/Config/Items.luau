--!strict
--[[
	Items.luau -- squishy catalog: id, rarity, baseValue

	Pure data, no logic (docs/arquitectura.md §3). Display names are text the
	player reads, so by our own convention they live in Strings.luau, not here.

	These are the 6 prototype items docs/plan-etapas.md asks for in Etapa 1,
	with made-up values. They exist to answer one question -- is bluffing fun --
	so do not polish them; they get replaced by the real 12-15 set in Etapa 2.

	Adding a squishy = one entry here + one name in Strings.luau. No new code
	anywhere (backlog card C1).
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId
type ItemDef = Types.ItemDef

--[=[
	@class Items

	Squishy catalog: id, rarity and baseValue. Pure data, no logic. Display names
	are text the player reads, so by our own convention they live in Strings.

	These are the 6 prototype items docs/plan-etapas.md asks for in Etapa 1, with
	made-up values. They exist to answer one question -- is bluffing fun -- so do
	not polish them; they get replaced by the real 12-15 set in Etapa 2.

	Adding a squishy = one entry here + one name in Strings. No new code anywhere
	(backlog card C1).
]=]

--[=[
	@prop catalog { [ItemId]: ItemDef }
	@within Items

	Every squishy in the game, keyed by id.
]=]
local catalog: { [ItemId]: ItemDef } = {
	blue_octopus = { id = "blue_octopus", rarity = "Common", baseValue = 10 },
	sleepy_bread = { id = "sleepy_bread", rarity = "Common", baseValue = 15 },
	mint_turtle = { id = "mint_turtle", rarity = "Rare", baseValue = 40 },
	jelly_dragon = { id = "jelly_dragon", rarity = "Rare", baseValue = 60 },
	galaxy_fox = { id = "galaxy_fox", rarity = "Legendary", baseValue = 200 },
	rainbow_unicorn = { id = "rainbow_unicorn", rarity = "Legendary", baseValue = 300 },
}

--[=[
	@prop order { ItemId }
	@within Items

	Stable order for menus and for anything that has to look identical on every
	server. Iterating `catalog` with pairs() gives no ordering guarantee, so use
	this list whenever order is visible to the player.
]=]
local order: { ItemId } = {
	"blue_octopus",
	"sleepy_bread",
	"mint_turtle",
	"jelly_dragon",
	"galaxy_fox",
	"rainbow_unicorn",
}

return {
	catalog = catalog,
	order = order,
}
