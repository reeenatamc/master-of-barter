--!strict
--[[
	InventoryService.luau -- permanent collection and duel copies.

	Card B3. Two inventories, and the difference between them is the game's
	anti-frustration pillar (docs/gdd.md §21):

	  collection  what you have WON. Permanent. Never lost.
	  duelCopies  what you can STAKE. The only thing a duel can move.

	THE COLLECTION CANNOT SHRINK, AND NOT BY CONVENTION. There is no function in
	this module that subtracts from it. None. A code path that shrank somebody's
	collection would have to write that function first, which is a deliberate
	act visible in a diff -- not a slip.

	That is deliberately stronger than "remember not to" and stronger than
	locking the door: you cannot call what does not exist.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

local InventoryService = {}

--- How many copies of this object the player can stake. Zero if there is no
--- profile, which is a normal state, not an error.
function InventoryService.copiesOf(player: Player, itemId: Types.ItemId): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	return profile.duelCopies[itemId] or 0
end

--- Everything stakeable, as a flat list of ids with one entry per copy. Easier
--- for a duel to work with than counts, and built fresh each time so nobody can
--- hold onto it and drift.
function InventoryService.stakeableList(player: Player): { Types.ItemId }
	local profile = DataService.get(player)
	if not profile then
		return {}
	end

	local list: { Types.ItemId } = {}
	-- Iterated through Items.order rather than through the profile, so the hand
	-- comes out in catalogue order on every server instead of in whatever order
	-- the table happens to hash to.
	for _, itemId in Items.order do
		for _ = 1, profile.duelCopies[itemId] or 0 do
			table.insert(list, itemId)
		end
	end
	return list
end

--- Takes one copy out of the profile and hands responsibility for it to the
--- caller. Returns false if there was none to take.
---
--- This is the escrow half of docs/decisiones.md's staking decision: a copy put
--- on the table LEAVES the profile at that moment. Once it is out, resolving
--- the duel writes nothing to this player -- which is what makes a disconnect
--- mid-duel free of any ordering problem between transfer and profile release.
function InventoryService.takeCopy(player: Player, itemId: Types.ItemId): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	local held = profile.duelCopies[itemId] or 0
	if held <= 0 then
		return false
	end

	-- Cleared rather than left at zero: a profile full of zeroes is a profile
	-- that grows forever and serialises more on every save.
	local left = held - 1
	if left > 0 then
		profile.duelCopies[itemId] = left
	else
		profile.duelCopies[itemId] = nil
	end
	return true
end

--- Puts a copy into the profile: a stake coming back, a stake won, or something
--- bought from the shop.
function InventoryService.giveCopy(player: Player, itemId: Types.ItemId, count: number?)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local amount = count or 1
	profile.duelCopies[itemId] = (profile.duelCopies[itemId] or 0) + amount
end

--- Adds to the PERMANENT collection. The only thing in this module that touches
--- it, and it only ever adds.
---
--- Winning a duel does not call this: a duel moves copies. What earns a place in
--- the collection is a separate question (docs/gdd.md §18 and §23), and B3 does
--- not answer it.
function InventoryService.collect(player: Player, itemId: Types.ItemId)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.collection[itemId] = (profile.collection[itemId] or 0) + 1
end

--- Gives a brand new player something to duel with. Copies, not collection: the
--- collection is what you have won, and handing one over before the first duel
--- makes the first win worth nothing.
local function grantStarter(player: Player, profile: Types.Profile)
	if next(profile.duelCopies) ~= nil then
		return
	end
	for _, itemId in Items.starterCopies do
		profile.duelCopies[itemId] = (profile.duelCopies[itemId] or 0) + 1
	end
end

--- Wires the service. Called by Main after DataService, whose signal it needs.
function InventoryService.init()
	DataService.profileLoaded:connect(function(player: Player, profile: Types.Profile)
		grantStarter(player, profile)
	end)
end

return InventoryService
