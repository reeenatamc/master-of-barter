--!strict
--[[
	Strings.luau -- player-facing text (Spanish), centralized for future localization

	Every string the player can read lives here, and only here. The code stays in
	English; this file is the single place holding Spanish copy, so translating
	the game later means adding a sibling table instead of hunting through
	services and controllers for hardcoded text.

	Rule of thumb: if a player can see it, it belongs here. If only a developer
	sees it (warns, prints, error messages), it stays inline and in English.
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId
type Rarity = Types.Rarity

local itemNames: { [ItemId]: string } = {
	blue_octopus = "Pulpito Azul",
	sleepy_bread = "Pan Dormilón",
	mint_turtle = "Tortuga Menta",
	jelly_dragon = "Dragón Gelatina",
	galaxy_fox = "Zorro Galaxia",
	rainbow_unicorn = "Unicornio Arcoíris",
}

local rarityNames: { [Rarity]: string } = {
	Common = "Común",
	Rare = "Raro",
	Legendary = "Legendario",
}

--- The three negotiation buttons are the visual signature of the game
--- (docs/gdd.md §25), so their wording is design, not decoration.
local duelButtons = {
	accept = "Aceptar",
	decline = "Rechazar",
	raiseOffer = "Pedir más",
	fakeCall = "¡ES FAKE!",
}

local currencyName = "Clips"

return {
	itemNames = itemNames,
	rarityNames = rarityNames,
	duelButtons = duelButtons,
	currencyName = currencyName,
}
