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

local Players = game:GetService("Players")
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
function InventoryService.takeCopy(player: Player, itemId: Types.ItemId, duelId: string, copyId: string): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	-- IDENTITY, NOT POSITION. A copy already on a table cannot be staked a
	-- second time, whatever order a client sends its wrappers in.
	--
	-- This is the structural half of the amendment fix. DuelOffers also checks
	-- that an amendment begins with the offer it amends -- that check gives a
	-- clear refusal message and keeps the cost delta honest -- but if it were
	-- ever removed, or if some future path made the same assumption about
	-- ordering, THIS is what still makes duplication impossible. The difference
	-- is between "the current path does not duplicate" and "no path does".
	for _, entry in profile.escrow do
		if entry.copyId == copyId then
			warn(`[Inventory] {player.Name}: copy {copyId} is already staked; refused`)
			return false
		end
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

	-- Written down, so that losing it to a crash is DISTINGUISHABLE from never
	-- having had it. The copy is gone from duelCopies either way; this is what
	-- makes the difference reportable later.
	table.insert(profile.escrow, { itemId = itemId, duelId = duelId, copyId = copyId })
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

--- The exact inverse of `takeCopy`: removes THIS copy's escrow entry and gives
--- the copy back.
---
--- Matched by copyId, so it returns the copy that was actually staked rather
--- than any copy of the same kind. And the return happens ONLY if the entry was
--- there: giving back something that was never taken is how a fix for a loss
--- becomes a duplication.
function InventoryService.returnCopy(player: Player, itemId: Types.ItemId, duelId: string, copyId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	for index = #profile.escrow, 1, -1 do
		local entry = profile.escrow[index]
		if entry.copyId == copyId then
			table.remove(profile.escrow, index)
			profile.duelCopies[itemId] = (profile.duelCopies[itemId] or 0) + 1
			return
		end
	end

	-- Nothing to return means somebody asked to un-stake a copy that was never
	-- staked. That is a bug in the caller, and it is loud rather than silently
	-- generous: the silent version invents a copy.
	warn(`[Inventory] {player.Name}: copy {copyId} was not in escrow for duel {duelId}; nothing returned`)
end

--- Forgets this duel's escrow entries WITHOUT returning anything.
---
--- For a duel that REACHED A REVEAL, where the copies changed hands rather than
--- coming back: whatever was owed has already been handed over through
--- `giveCopy`, so the records are stale and returning here would double it.
---
--- A duel that ends without a reveal uses `returnCopy` instead, which is a
--- return and a record removal together.
function InventoryService.clearEscrow(player: Player, duelId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	-- Backwards, so removing does not shift entries still to be looked at.
	for index = #profile.escrow, 1, -1 do
		if profile.escrow[index].duelId == duelId then
			table.remove(profile.escrow, index)
		end
	end
end

--- How many escrow entries any loaded profile still holds for this duel.
---
--- Zero is the invariant a finished duel must leave behind: either every stake
--- came back (`returnCopy` removes its record) or it was handed over
--- (`clearEscrow` forgets it). Anything else is a copy stuck in limbo, which is
--- exactly the failure the escrow list exists to make detectable.
---
--- Asked across every loaded profile rather than one player's, because a duel
--- has two sides and a leak on either is the same bug.
function InventoryService.escrowCountFor(duelId: string): number
	local total = 0
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			for _, entry in profile.escrow do
				if entry.duelId == duelId then
					total += 1
				end
			end
		end
	end
	return total
end

--- Reports and clears escrow entries left over from a session that ended
--- badly, and returns NOTHING.
---
--- Any entry present when a profile loads is an orphan by definition: a live
--- duel cannot outlive the session holding it. Returning them would be the
--- obvious kindness and is exactly the wrong move -- a crash between paying the
--- winner and clearing the loser would turn a return into a duplication, and a
--- duplication is the failure that spreads.
---
--- So: the loss stands, and it is written down instead of vanishing. With
--- enough players, this log is what makes compensating somebody by hand
--- possible at all.
local function reportOrphanedEscrow(player: Player, profile: Types.Profile)
	if #profile.escrow == 0 then
		return
	end

	for _, entry in profile.escrow do
		-- TODO(F3): this belongs in AnalyticsService, which does not exist yet.
		-- Until then it is at least visible rather than silent.
		warn(
			`[Inventory] {player.Name} lost a staked copy to an unfinished duel:`
				.. ` {entry.itemId} (duel {entry.duelId}).`
				.. ` Not returned on purpose -- returning could duplicate.`
		)
	end

	table.clear(profile.escrow)
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
		reportOrphanedEscrow(player, profile)
		grantStarter(player, profile)
	end)
end

return InventoryService
