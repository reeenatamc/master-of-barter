--!strict
--[[
	Items.luau -- object catalog: id, rarity, baseValue

	Pure data, no logic (docs/arquitectura.md §3). Display names are text the
	player reads, so by our own convention they live in Strings.luau, not here.

	These are the 6 prototype items docs/plan-etapas.md asks for in Etapa 1,
	with made-up values. They exist to answer one question -- is bluffing fun --
	so do not polish them; they get replaced by the real 12-15 set in Etapa 2.

	Adding an object = one entry here + one name in Strings.luau. No new code
	anywhere (backlog card C1).
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId
type ItemDef = Types.ItemDef

--[=[
	@class Items

	Object catalog: id, rarity and baseValue. Pure data, no logic. Display names
	are text the player reads, so by our own convention they live in Strings.

	These are the 6 prototype items docs/plan-etapas.md asks for in Etapa 1, with
	made-up values. They exist to answer one question -- is bluffing fun -- so do
	not polish them; they get replaced by the real 12-15 set in Etapa 2.

	Adding an object = one entry here + one name in Strings. No new code anywhere
	(backlog card C1).
]=]

--[=[
	@prop catalog { [ItemId]: ItemDef }
	@within Items

	Every object in the game, keyed by id.
]=]
-- [propuesta] Twelve originals, awaiting approval at checkpoint 2.
--
-- The joke is household objects treated as relics: gdd.md §22's brainrot
-- register with nobody else's characters in it. Three rarities, because §18
-- fixes three -- a fourth was drafted and removed, since adding one is
-- altering a GDD mechanic rather than adding detail to it.
local catalog: { [ItemId]: ItemDef } = {
	golden_maruchan = { id = "golden_maruchan", rarity = "Common", baseValue = 12 },
	potato_rock = { id = "potato_rock", rarity = "Common", baseValue = 15 },
	grandma_remote = { id = "grandma_remote", rarity = "Common", baseValue = 18 },
	chewed_pencil = { id = "chewed_pencil", rarity = "Common", baseValue = 22 },
	sock_one = { id = "sock_one", rarity = "Common", baseValue = 26 },
	expired_yogurt = { id = "expired_yogurt", rarity = "Rare", baseValue = 48 },
	first_tooth = { id = "first_tooth", rarity = "Rare", baseValue = 62 },
	frozen_pizza = { id = "frozen_pizza", rarity = "Rare", baseValue = 78 },
	wifi_router = { id = "wifi_router", rarity = "Rare", baseValue = 96 },
	dad_screwdriver = { id = "dad_screwdriver", rarity = "Legendary", baseValue = 210 },
	lost_charger = { id = "lost_charger", rarity = "Legendary", baseValue = 270 },
	last_empanada = { id = "last_empanada", rarity = "Legendary", baseValue = 340 },
}

--[=[
	@prop order { ItemId }
	@within Items

	Stable order for menus and for anything that has to look identical on every
	server. Iterating `catalog` with pairs() gives no ordering guarantee, so use
	this list whenever order is visible to the player.
]=]
-- [propuesta] What a brand new player has to duel with.
--
-- Duel copies, not collection: the collection is what you have WON, and
-- handing somebody a collection before they play makes the first win worth
-- nothing (docs/gdd.md §21).
--
-- Three commons and one rare: enough to make an offer, not enough to make a
-- convincing one. The first duel should feel like scraping something
-- together.
local starterCopies: { ItemId } = {
	"golden_maruchan",
	"potato_rock",
	"grandma_remote",
	"expired_yogurt",
}

local order: { ItemId } = {
	"golden_maruchan",
	"potato_rock",
	"grandma_remote",
	"chewed_pencil",
	"sock_one",
	"expired_yogurt",
	"first_tooth",
	"frozen_pizza",
	"wifi_router",
	"dad_screwdriver",
	"lost_charger",
	"last_empanada",
}

return {
	catalog = catalog,
	order = order,
	starterCopies = starterCopies,
}
