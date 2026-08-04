--!strict
--[[
	Theme.luau -- SWAPPABLE SKIN: visual and audio assets of the active theme.

	The evergreen bet of docs/arquitectura.md §3: every asset with a flavour --
	wrapper art, table textures, sounds, fonts, season names -- is reached
	through the active theme, so changing trend means writing a new theme and
	touching no logic at all. Card C2.

	THE PALETTE IS [propuesta]. docs/mockups is empty, so everything visual here
	was derived from the GDD's written description rather than from Renata's
	reference images:

	  §25 "todo parece dibujado con marcador en hojas cuadriculadas, botones
	       como recortes pegados con cinta"
	  §28 "colores planos, la imperfección del trazo es estética, no defecto"
	  §26 "foley casero: papel arrugándose, cinta adhesiva, marcador escribiendo"

	The STRUCTURE is not provisional. What E2 reads -- which keys exist and what
	they mean -- is built to survive the palette being replaced wholesale once
	the reference images land. See docs/decisiones.md.
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId

-- ─────────────────────────────────────────────────────────────────────────────
-- Colour
-- ─────────────────────────────────────────────────────────────────────────────

--- [propuesta] A notebook page seen in warm light, drawn on with a few marker
--- colours. Deliberately few: §28 asks for flat colour, and a paper aesthetic
--- falls apart the moment it gains gradients and a dozen hues.
local palette = {
	--- The page itself. Off-white and warm, never pure white -- pure white
	--- reads as "screen", and the whole point is that this reads as "paper".
	paper = Color3.fromRGB(247, 243, 232),
	--- Squared-paper ruling. Barely there; it should be felt, not read.
	grid = Color3.fromRGB(206, 216, 228),
	--- Marker ink for text and outlines.
	ink = Color3.fromRGB(38, 36, 34),
	--- Pencil grey for anything secondary.
	inkSoft = Color3.fromRGB(126, 120, 112),
	--- Masking tape holding the cut-outs down.
	tape = Color3.fromRGB(233, 219, 186),

	--- The three negotiation buttons, in marker colours. They are the visual
	--- signature of the game (§25), so they get the three strongest hues and
	--- nothing else competes with them.
	accept = Color3.fromRGB(74, 143, 88),
	decline = Color3.fromRGB(126, 120, 112),
	raise = Color3.fromRGB(62, 106, 170),
	--- Red marker, reserved. Nothing else in the interface may use it, so that
	--- red always means the accusation.
	fakeCall = Color3.fromRGB(198, 62, 54),

	good = Color3.fromRGB(74, 143, 88),
	bad = Color3.fromRGB(198, 62, 54),
	--- Soft pencil shadow under a taped cut-out.
	shadow = Color3.fromRGB(198, 190, 176),
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Type
-- ─────────────────────────────────────────────────────────────────────────────

--- Both fonts were checked against the real API before being used here: a
--- handful of plausible handwriting fonts (Caveat, Amatic, ArchitectsDaughter,
--- Schoolbell) do NOT exist in Roblox and would have failed only in Studio.
local fonts = {
	--- Headlines and the three buttons. It is literally a marker.
	marker = Enum.Font.PermanentMarker,
	--- Everything read at length. Handwritten but legible, which matters more
	--- than character once there is a paragraph of it.
	hand = Enum.Font.PatrickHand,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Sound
-- ─────────────────────────────────────────────────────────────────────────────

--- Empty means "not chosen yet", and SoundController skips it rather than
--- erroring. Deliberately NOT filled with plausible-looking asset ids: a made
--- up rbxassetid points at somebody else's sound or at nothing, and both are
--- worse than silence.
---
--- §26 asks for deliberate homemade foley -- paper crumpling, tape, a marker
--- squeaking, kids going "ohhh" at the reveal. The names below describe what
--- each slot needs so filling them is shopping, not designing.
local SILENT = ""

local sounds = {
	--- Marker on paper: something was written into the offer.
	offerPlaced = SILENT,
	--- Paper crumpling: the offer was withdrawn or cleared.
	offerCleared = SILENT,
	--- Tape tearing: the offer is committed to the table.
	offerSent = SILENT,
	--- A demanding tap on the table.
	raise = SILENT,
	--- A handshake, or tape smoothed flat.
	accept = SILENT,
	--- Paper pushed away.
	decline = SILENT,
	--- A rubber stamp coming down. The loudest thing in the game.
	fakeCall = SILENT,
	--- Rising tension while the wrappers come off. The Revelación™ (§29).
	revealBuild = SILENT,
	--- The tear itself, per wrapper.
	revealTear = SILENT,
	--- Kids going "ohhh" (§26).
	revealCrowd = SILENT,
	win = SILENT,
	lose = SILENT,
	emote = SILENT,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Texture
-- ─────────────────────────────────────────────────────────────────────────────

--- Same rule as sounds: empty means unchosen, and whoever renders falls back to
--- flat colour. A paper texture is nice; an invented asset id is a bug.
local textures = {
	paper = SILENT,
	tape = SILENT,
	wrapper = SILENT,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Objects
-- ─────────────────────────────────────────────────────────────────────────────

--- [propuesta] How one object is drawn while there is no art.
---
--- `corner` is a fraction of the shape: 0 is a square, 0.5 a circle. Silhouette
--- matters as much as colour, because docs/gdd.md §37 forbids anything being
--- distinguishable by colour alone -- and because six coloured squares are six
--- squares, while six different shapes are six things.
export type ItemLook = {
	color: Color3,
	corner: number,
}

local items: { [ItemId]: ItemLook } = {
	golden_maruchan = { color = Color3.fromRGB(226, 176, 70), corner = 0.12 },
	potato_rock = { color = Color3.fromRGB(150, 132, 112), corner = 0.42 },
	grandma_remote = { color = Color3.fromRGB(96, 104, 118), corner = 0.1 },
	chewed_pencil = { color = Color3.fromRGB(216, 164, 64), corner = 0.08 },
	sock_one = { color = Color3.fromRGB(198, 110, 140), corner = 0.3 },
	expired_yogurt = { color = Color3.fromRGB(232, 220, 196), corner = 0.16 },
	first_tooth = { color = Color3.fromRGB(240, 236, 222), corner = 0.34 },
	frozen_pizza = { color = Color3.fromRGB(206, 96, 72), corner = 0.2 },
	wifi_router = { color = Color3.fromRGB(72, 132, 180), corner = 0.06 },
	dad_screwdriver = { color = Color3.fromRGB(198, 72, 60), corner = 0.05 },
	lost_charger = { color = Color3.fromRGB(58, 60, 66), corner = 0.14 },
	last_empanada = { color = Color3.fromRGB(212, 158, 92), corner = 0.38 },
}

--- Anything without its own entry shows up as a grey blob: visible enough to
--- notice and fix, rather than invisible.
local defaultItem: ItemLook = {
	color = Color3.fromRGB(150, 144, 136),
	corner = 0.2,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Motion
-- ─────────────────────────────────────────────────────────────────────────────

--- [propuesta] Timings for the juice. They live in the theme rather than in the
--- code because how fast a thing snaps is part of how it feels, and a different
--- theme may well want a different rhythm.
---
--- The first play-test asked for feedback on every action, not only the reveal
--- (plan-etapas.md, Etapa 2): a duel where only the ending moves is a duel
--- that is silent for ninety percent of its length.
local motion = {
	--- A cut-out being taped down. Short and slightly overshooting.
	place = 0.18,
	--- The rival's demand landing. A shove, not a slide.
	raise = 0.12,
	--- Between one wrapper coming off and the next, during the reveal. Long
	--- enough to be watched, short enough not to be waited through.
	revealStagger = 0.45,
	--- The pause before the verdict. The only deliberately slow thing here.
	revealHold = 0.9,
	--- How long a reaction stays on screen.
	emote = 2,
	--- Default for anything not named above.
	snap = 0.15,
}

--- [propuesta] The duel table, in studs. Dimensions live in the theme because
--- the scene is part of the look: a different theme may want a school desk, a
--- market stall or a cardboard box, and none of them should need code changes.
---
--- The sheet stands VERTICALLY on the table so both players read the same
--- object from opposite sides (docs/gdd.md §11), which is also what lets each
--- client draw its own face of it and never assemble the rival's view anywhere
--- the rival could reach.
local tableSpec = {
	--- Width and depth of the surface. Wide enough to frame two avatars.
	topSize = Vector3.new(12, 0.4, 7),
	--- Height of the surface off the floor.
	height = 3,
	--- The sheet. Deliberately thin: at this thickness it reads as paper rather
	--- than as a board.
	sheetSize = Vector3.new(9, 5.5, 0.08),
	--- How far back each player stands from the sheet.
	standDistance = 4.5,
	--- Resolution of the surface drawn on the sheet. Higher looks sharper and
	--- costs more; this is the knob for docs/gdd.md §38's low-end budget.
	pixelsPerStud = 96,
}

--- [propuesta] Where the camera sits during a duel. Over your own shoulder,
--- looking at the sheet with the rival's avatar visible past it -- the framing
--- of docs/gdd.md §11. Fixed, not orbiting: §11 says fija, and a camera the
--- player has to manage is one more thing between them and the game.
local camera = {
	--- Behind your own side of the sheet.
	distance = 11,
	--- Eye height above the table.
	height = 7.5,
	--- What it aims at: the middle of the sheet, so the rival's head sits just
	--- above the far edge.
	aimHeight = 4.5,
	--- Seconds to glide in when the duel opens. Cutting is jarring; sliding in
	--- reads as sitting down at the table.
	settle = 0.8,
}

--- How much a taped cut-out is rotated, in degrees. Nothing is ever perfectly
--- straight: §28 says the imperfection is the aesthetic, not a defect, and a
--- perfectly aligned grid of paper cards stops reading as paper immediately.
local tiltDegrees = 2.5

return {
	name = "Papelito",
	palette = palette,
	fonts = fonts,
	sounds = sounds,
	textures = textures,
	items = items,
	defaultItem = defaultItem,
	motion = motion,
	tiltDegrees = tiltDegrees,
	table = tableSpec,
	camera = camera,
	--- Which duel screen is used. "table" is the card E2 scene: a paper sheet
	--- standing on a table in the world. "flat" is the E0 panel, kept working so
	--- there is always something to fall back to if the new one misbehaves
	--- during a play-test.
	screen = "table",
}
