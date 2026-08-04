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

--[=[
	@class Strings

	Player-facing text, in Spanish, centralized for future localization. Every
	string the player can read lives here and only here: the code stays in
	English, so translating the game later means adding a sibling table instead
	of hunting through services and controllers for hardcoded text.

	Rule of thumb: if a player can see it, it belongs here. If only a developer
	sees it (warns, prints, error messages), it stays inline and in English.
]=]

--[=[
	@prop itemNames { [ItemId]: string }
	@within Strings

	Display name for each squishy in the Items catalog.
]=]
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

--[=[
	@prop duelButtons { accept: string, decline: string, raiseOffer: string, fakeCall: string }
	@within Strings

	The three negotiation buttons are the visual signature of the game
	(docs/gdd.md §25), so their wording is design, not decoration.
]=]
local duelButtons = {
	accept = "Aceptar",
	decline = "Rechazar",
	raiseOffer = "Pedir más",
	fakeCall = "¡ES FAKE!",
}

--[=[
	@prop duelScreen { [string]: string }
	@within Strings

	Everything else the duel screen puts on the player's screen.
]=]
local duelScreen = {
	waitingForRival = "Esperando al rival…",
	--- %s se reemplaza con la tecla real que abre el chat, leída del engine.
	talkHint = "Apretá %s para hablarle al rival y venderle tu oferta",
	emotes = "Reacciones",
	buildYourOffer = "Armá tu oferta",
	yourTurn = "Te toca",
	theirTurn = "Turno del rival",
	yourHand = "Tu colección",
	yourOffer = "Tu oferta",
	theirOffer = "Lo que ofrece el rival",
	nothingYet = "Todavía no ofreció nada",
	emptyDraft = "No elegiste nada todavía",
	offerReal = "Real",
	offerFake = "Falso",
	genuineMark = "auténtico",
	fakeMark = "FALSIFICADO",
	send = "OFERTAR",
	clear = "Limpiar",
	reveal = "LA REVELACIÓN",
	wasReal = "era auténtico",
	wasFake = "era FALSO",
	youWin = "GANASTE",
	youLose = "Perdiste",
	tie = "Empate",
	calledRight = "acusó y ACERTÓ",
	calledWrong = "acusó y FALLÓ",
	duelOver = "Duelo terminado",
	valueLine = "Se lleva %d de valor",
	fakesSlipped = "coló %d falsificación(es)",
	tokenSpent = "Ficha usada",
	raisesLeft = "Pedidos restantes: %d",
	owesBigger = "Debe mejorar su oferta",
}

--- What each reaction of DuelRules.emotes looks like. Symbols rather than
--- words: they cross languages, they read at a glance, and they fit a button
--- a thumb can hit.
local emoteSymbols: { [string]: string } = {
	hype = "🤩",
	doubt = "🤨",
	laugh = "😂",
	beg = "🙏",
	dead = "💀",
	fire = "🔥",
}

local currencyName = "Clips"

return {
	itemNames = itemNames,
	rarityNames = rarityNames,
	duelButtons = duelButtons,
	duelScreen = duelScreen,
	emoteSymbols = emoteSymbols,
	currencyName = currencyName,
}
