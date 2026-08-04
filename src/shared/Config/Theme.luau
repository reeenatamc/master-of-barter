--!strict
--[[
	Theme.luau -- SWAPPABLE SKIN: visual/audio assets of the active theme.

	The evergreen bet of docs/arquitectura.md §3: every asset with a flavour --
	wrapper images, table textures, sounds, season names -- is reached through
	the active theme, so changing trend means writing a new theme and touching
	no logic at all.

	WHAT IS HERE IS A PLACEHOLDER, and only what card E0.2 needed: a colour and a
	corner radius per item, so an object reads as an object instead of a row of
	text. It is not the paper theme. That is card C2, and it replaces all of
	this: real hand-drawn art, sounds, fonts, the lot.

	Kept as pure data, like every other Config module: the lookup and its
	fallback happen at the call site, not here.
]]

local Types = require(script.Parent.Parent.Types)

type ItemId = Types.ItemId

--- How one object is drawn while there is no art. `corner` is a fraction of the
--- shape, so 0 is a square and 0.5 is a circle -- silhouette carries as much
--- recognition as colour, and docs/gdd.md §37 requires that nothing be
--- distinguishable by colour alone.
export type Swatch = {
	color: Color3,
	corner: number,
}

local itemSwatches: { [ItemId]: Swatch } = {
	blue_octopus = { color = Color3.fromRGB(64, 132, 214), corner = 0.5 },
	sleepy_bread = { color = Color3.fromRGB(206, 164, 100), corner = 0.15 },
	mint_turtle = { color = Color3.fromRGB(96, 190, 150), corner = 0.35 },
	jelly_dragon = { color = Color3.fromRGB(198, 88, 152), corner = 0.1 },
	galaxy_fox = { color = Color3.fromRGB(126, 88, 204), corner = 0.28 },
	rainbow_unicorn = { color = Color3.fromRGB(226, 168, 62), corner = 0.45 },
}

--- For any item without its own entry. A new item shows up as a grey blob
--- rather than as nothing, which is visible enough to notice and fix.
local defaultSwatch: Swatch = {
	color = Color3.fromRGB(120, 120, 128),
	corner = 0.2,
}

return {
	itemSwatches = itemSwatches,
	defaultSwatch = defaultSwatch,
}
