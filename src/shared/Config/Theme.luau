--!strict
--[[
	Theme.luau -- SWAPPABLE SKIN: visual and audio assets of the active theme.

	The evergreen bet of docs/arquitectura.md §3: every asset with a flavour --
	wrapper art, table textures, sounds, fonts, season names -- is reached
	through the active theme, so changing trend means writing a new theme and
	touching no logic at all. Card C2.

	RE-DERIVED FROM THE REFERENCE IMAGES (mockups/, 2026-08-04). The first pass
	guessed from the GDD's written description; these values come from the
	images themselves, and they differ in ways guessing would never have found:

	  - The ink is BLUE BALLPOINT, not dark marker. Everything is drawn in the
	    same biro blue: borders, grid, icons, the world.
	  - The paper is warm KRAFT, tanner and browner than the cream first
	    guessed, and visibly crumpled.
	  - The three buttons are pale FILLED panels -- red, green, blue -- with a
	    sketchy double-stroke outline, not outlined cut-outs.
	  - The whole world is papercraft, not just the interface.

	That the structure survived the change is the point of C2: the palette was
	replaced wholesale and nothing that reads it needed touching.
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
	--- The board itself: warm kraft paper, visibly crumpled. Browner than the
	--- first guess -- the references are lit by afternoon sun, and pure white
	--- would read as "screen" where this reads as "a thing on a table".
	--- WHITE. The reference sheet is white card on an amber table, not kraft.
	paper = Color3.fromRGB(248, 246, 242),
	--- Squared ruling. Blue like everything else, and barely there: felt, not
	--- read.
	grid = Color3.fromRGB(178, 188, 204),
	--- BALLPOINT BLUE. The single most defining choice in the references: every
	--- line in that world -- borders, icons, trees, houses -- is the same biro.
	--- Not marker, not black.
	ink = Color3.fromRGB(42, 78, 158),
	--- The same pen pressed lighter, for anything secondary.
	inkSoft = Color3.fromRGB(112, 140, 192),
	--- Masking tape, and the strip a cut-out sits on.
	tape = Color3.fromRGB(226, 206, 164),

	--- The three negotiation buttons. In the references they are pale FILLED
	--- panels with a sketchy outline, not outlined cut-outs, and their colours
	--- carry the meaning before the icon does: red refuses, green agrees, amber
	--- asks for more.
	---
	--- SATURATED, since 2026-08-05. The first pass used muted, chalky versions
	--- to sit politely on paper, and on a real board seen in perspective they
	--- read as grey. These are the loudest thing in the game on purpose: they
	--- are its visual signature (§25), and a signature that has to be looked for
	--- is not one.
	---
	--- "Pedir más" moved from blue to AMBER, which is what both reference
	--- images show. Amber also reads as the middle answer between yes and no,
	--- which blue never did.
	--- The FILL is the whole button; the outline is a hairline around it. A
	--- first pass raised only the outline and the board still read washed out,
	--- because the pale rectangle is what the eye actually sees. These are the
	--- colours now, and the symbol sits on them in white.
	accept = Color3.fromRGB(10, 150, 46),
	acceptFill = Color3.fromRGB(24, 214, 76),
	--- RED. The reference photo happens to have a purple marker, but the three
	--- colours of this game are green, yellow and red -- that is the decision,
	--- not the pen somebody had on the desk that day.
	decline = Color3.fromRGB(196, 12, 20),
	declineFill = Color3.fromRGB(240, 32, 34),
	--- BLUE. The + on the reference is drawn in blue marker, the same pen as
	--- the near player's dividing lines.
	raise = Color3.fromRGB(20, 78, 214),
	raiseFill = Color3.fromRGB(28, 98, 240),

	--- The accusation. Deliberately NOT the same red as Rechazar: they are
	--- opposite moves and sharing a colour would make the loudest button in the
	--- game look like the mildest.
	---
	--- docs/gdd.md §29 wants this stamped rather than pressed, so this colour is
	--- ink for a rubber stamp, and the shape it belongs on is still open.
	--- AMBER, and small: on the reference it is a circled "!" in the bottom
	--- right corner, the size of a stamp. It is a once-per-duel token, not a
	--- fourth button, and the drawing says so before any rule does.
	fakeCall = Color3.fromRGB(232, 152, 16),
	fakeCallFill = Color3.fromRGB(232, 152, 16),

	good = Color3.fromRGB(58, 132, 62),
	bad = Color3.fromRGB(196, 60, 52),
	--- Soft shadow under something resting on the board.
	shadow = Color3.fromRGB(186, 168, 138),

	--- The two pens the sheet is ruled with. Each side's lines are a different
	--- colour on the reference -- blue near, pink far -- which is what tells
	--- you at a glance which half of the sheet is yours, before you read a
	--- single symbol.
	ruleNear = Color3.fromRGB(28, 98, 240),
	ruleFar = Color3.fromRGB(236, 40, 138),

	--- A button that cannot be pressed yet.
	---
	--- GREY, not a faded version of its own colour. Fading kept the hue and made
	--- the game look washed out -- "no se puede todavía" and "este verde es feo"
	--- are indistinguishable at 55% transparency, and the second reading is the
	--- one people make. Off is a different colour, not a weaker one.
	off = Color3.fromRGB(196, 190, 178),
	offInk = Color3.fromRGB(148, 142, 132),
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
	--- The table the board rests on.
	topSize = Vector3.new(16, 0.6, 12),
	height = 3,
	--- The board itself: a thick pad of graph paper, lying FLAT. Wider than it
	--- is deep, like the references, so the two strips of slots and the two
	--- button rows all fit without crowding.
	--- LOCAL to the board, not world. With `boardYaw` at 90 the part is turned a
	--- quarter turn, so local X ends up running near-far and local Z left-right:
	--- the board a player sees is still 13 wide by 9.5 deep.
	---
	--- The numbers are swapped from the obvious ones on purpose, and that is the
	--- half of the fix that is easy to miss. Turning the part alone put the rows
	--- the right way round but left the canvas PORTRAIT -- a layout of wide
	--- button rows squeezed into a tall page. The canvas takes its shape from the
	--- face, so the face has to be landscape in the same axes the layout is.
	boardSize = Vector3.new(9.5, 0.35, 13),
	--- How far back each player stands from the near edge.
	--- Measured against the board, not guessed. With `boardSize` turned by
	--- `boardYaw` the pad reaches 4.75 studs each way, and a standing character
	--- is about two deep -- so at 6 both avatars had their chest INSIDE the
	--- table. 8 leaves a bit over three studs of clearance: close enough to
	--- read as sitting at it, far enough not to be growing out of it.
	standDistance = 8,
	--- Resolution of the surface drawn on the board. The knob for §38's low-end
	--- budget: higher is sharper and costs more.
	pixelsPerStud = 110,
	--- How the board is turned on the table, in degrees.
	---
	--- A SurfaceGui on a horizontal face maps its own up/down onto one of the
	--- part's horizontal axes, and WHICH one is not something to reason about
	--- from a document -- the first build put the three buttons along the left
	--- and right edges, written sideways, which is unreadable and was invisible
	--- until somebody looked.
	---
	--- MEASURED, not derived. The first build put the three buttons along the
	--- left and right edges written sideways, which is unreadable -- and that
	--- screenshot is the evidence that the page's vertical axis lands on the
	--- part's X. Players stand apart along Z (see `standDistance`), so the part
	--- gets a quarter turn to bring those two into line.
	---
	--- It stays a number rather than becoming a constant because the thing it
	--- encodes is a fact about the engine that a document cannot settle. If it
	--- ever comes out sideways again, try 0, 180, 270 -- looking costs ten
	--- seconds against an afternoon of deriving it wrong.
	boardYaw = 90,
	--- How much the scene's lighting tints the board, 0 to 1.
	---
	--- At 1 the surface is lit like real paper -- which is what it wanted to be
	--- -- and the grey ambient light of an empty baseplate DRAINS every colour
	--- on it. The buttons were mixed at full strength and arriving on screen
	--- grey, and no amount of saturating the values fixes that: the problem is
	--- downstream of the colour.
	---
	--- Low enough that the buttons carry their own colour, high enough that the
	--- board is not a glowing screen lying on a table. If the lobby's lighting
	--- turns out warm and generous (card E1), this can go back up.
	boardLight = 0.2,

	--- Two things that are OFF the sheet until somebody decides where they go.
	---
	--- Neither is deleted and neither is a mechanic being removed: the emotes
	--- and the accusation both still exist server-side, and the token is still
	--- reachable from the keyboard. What is paused is only WHERE they are
	--- drawn -- the reference sheet has neither on it, and guessing a spot on a
	--- board that just found its look is how a clean drawing gets cluttered
	--- again.
	---
	--- Flip either to true and it comes back where it was.
	showEmotes = false,
	showToken = false,
}

--- [propuesta] Where the camera sits during a duel. Over your own shoulder,
--- looking at the sheet with the rival's avatar visible past it -- the framing
--- of docs/gdd.md §11. Fixed, not orbiting: §11 says fija, and a camera the
--- player has to manage is one more thing between them and the game.
local camera = {
	--- Behind your own edge of the board.
	distance = 9,
	--- Eye height. High enough to read the whole board at a glance, low enough
	--- that the rival's avatar still stands above the far edge -- seeing them is
	--- part of reading them (§11).
	height = 9.5,
	--- Where it aims: just past the middle of the board, so your own half sits
	--- comfortably in the lower screen and theirs in the upper.
	aimOffset = 1.5,
	--- Seconds to glide in. Cutting is jarring; sliding in reads as sitting down
	--- at the table.
	settle = 0.8,
}

--- How much bigger the invisible touch target is than the drawn button.
---
--- 1.5 means the hit area is half again as wide and tall as what you can see.
--- Buttons live in world space on the sheet, where a thumb is less precise than
--- a mouse and the surface is seen at an angle; the drawing can stay the size
--- the composition wants while the target stays the size a thumb needs.
---
--- Nothing about this is visible, which is the point: a button that looks right
--- and misses is worse than one that looks slightly wrong.
local touchPadding = 1.5

--- Smallest a SCREEN-SPACE button may ever get, in pixels.
---
--- A different thing from `touchPadding`, and deliberately not the same number:
--- that one is a MULTIPLIER for world-space targets, where the drawing and the
--- target are separate objects. This is a FLOOR for flat UI, where they are the
--- same object and scale-based sizing shrinks with the screen -- a slip that
--- reads fine on a tablet becoming a smudge on a small phone.
---
--- 44 is the figure both platform guidelines land on for a fingertip.
local minTouchPixels = 44

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
	touchPadding = touchPadding,
	minTouchPixels = minTouchPixels,
	table = tableSpec,
	camera = camera,
	--- Which duel screen is used. "table" is the card E2 scene: a paper sheet
	--- standing on a table in the world. "flat" is the E0 panel, kept working so
	--- there is always something to fall back to if the new one misbehaves
	--- during a play-test.
	screen = "table",
}
