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

	Display name for each object in the Items catalog.
]=]
local itemNames: { [ItemId]: string } = {
	golden_maruchan = "Sopa Maruchan Dorada",
	potato_rock = "Piedra que Parece Papa",
	grandma_remote = "Control de la Abuela",
	chewed_pencil = "Lápiz Mordido",
	sock_one = "La Media Que Falta",
	expired_yogurt = "Yogur Vencido en 2011",
	first_tooth = "Tu Primer Diente",
	frozen_pizza = "Pizza del Fondo",
	wifi_router = "Módem Que Sí Andaba",
	dad_screwdriver = "Destornillador de Papá",
	lost_charger = "El Cargador Perdido",
	last_empanada = "La Última Empanada",
}

--- [propuesta] Una línea por objeto, para la inspección. El chiste es que son
--- cosas de tu casa tratadas como reliquias: el absurdo cotidiano elevado, que
--- es el tono de gdd.md §22 sin tomar prestado el personaje de nadie.
local itemFlavour: { [ItemId]: string } = {
	golden_maruchan = "Sabor camarón. Nunca la vas a cocinar.",
	potato_rock = "O una papa que parece piedra. Nadie mordió.",
	grandma_remote = "Forrado en plástico desde 1994. Impecable.",
	chewed_pencil = "Mordido por alguien famoso. Eso dicen.",
	sock_one = "La otra está en la secadora. Desde siempre.",
	expired_yogurt = "Sin abrir. Técnicamente sigue siendo yogur.",
	first_tooth = "El ratón nunca vino. Vos te lo quedaste.",
	frozen_pizza = "Del fondo del freezer. Tiene escarcha propia.",
	wifi_router = "Lo desenchufaste una vez y nunca más fue igual.",
	dad_screwdriver = "No es para tornillos. Es para todo lo demás.",
	lost_charger = "Nadie sabe de quién es. Todos lo reclaman.",
	last_empanada = "Estaba en la bandeja. Ahora es tuya. Ganaste.",
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
	raisesLeft = "Pedidos restantes: %d",
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

--- Avisos que el servidor manda por el remoto `Notice`.
local notices = {
	--- Por qué no podés entrar a un duelo sin perfil. Dice la causa, no solo el
	--- "no": un "no podés" sin motivo se lee como que el juego está roto.
	spectatorNoDuel = "No pudimos cargar tu progreso, así que no podés apostar todavía. Salí y volvé a entrar para reintentar.",
	shopNotStocked = "Eso ya no está en el kiosco. Don Trueque rota lo que ofrece cada tanto.",
	shopCannotAfford = "No te alcanzan los Clips para eso.",
	--- Llegó al tope diario contra rivales de relleno. Dice qué pasa ahora
	--- ("seguís en la cola"), no solo qué no pasa: un aviso que solo niega deja
	--- al jugador sin saber si tiene que hacer algo.
	botCapReached = "Por hoy ya no hay rivales de relleno. Seguís en la cola esperando a alguien de verdad.",
}

local currencyName = "Clips"

return {
	itemNames = itemNames,
	itemFlavour = itemFlavour,
	rarityNames = rarityNames,
	duelButtons = duelButtons,
	duelScreen = duelScreen,
	notices = notices,
	emoteSymbols = emoteSymbols,
	currencyName = currencyName,
}
