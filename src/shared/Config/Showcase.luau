--!strict
--[[
	Showcase.luau -- the public shelf in the lobby.

	Card E3 (P2). Pure data, no logic (docs/arquitectura.md §3).
]]

--[=[
	@class Showcase

	Numbers for the lobby showcase. Pure data.
]=]

--[=[
	@prop slots number
	@within Showcase

	How many collected objects fit on the shelf.

	Four, not "all of them": a showcase that shows everything is an inventory,
	and an inventory says nothing about its owner. Choosing four is the message.
	docs/gdd.md §102 unlocks more with level; that is a later card and this is
	the floor.
]=]
local slots = 4

--[=[
	@prop nameLength { min: number, max: number }
	@within Showcase

	Bounds on the RAW string, checked before it reaches the filter -- a huge
	payload should cost nothing at all, and a moderation API call is not
	"nothing".
]=]
local nameLength = { min = 3, max = 24 }

--[=[
	@prop renameCooldownSeconds number
	@within Showcase

	Seconds between renames, per player.

	Not politeness: every attempt is a call to a rate-limited moderation API, so
	without this one client can spend the whole experience's filter budget.
	Generous enough that nobody deciding on a name will ever feel it.
]=]
local renameCooldownSeconds = 10

return {
	slots = slots,
	nameLength = nameLength,
	renameCooldownSeconds = renameCooldownSeconds,
}
