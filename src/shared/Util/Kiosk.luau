--!strict
--[[
	Kiosk.luau -- what the kiosk is offering, derived from the clock.

	SHARED ON PURPOSE, and it is the interesting part of card B4's UI. The client
	has to draw the stock and the server has to validate against it, and those
	two answers must be the same answer -- not two implementations that agree
	today. So there is one function, and both sides call it.

	That is the same cure the project already uses for prices: a stored price is
	a second source of truth that goes stale the moment Config changes, so
	`priceOf` derives instead. A second stock function would go stale the moment
	somebody edited the draw.

	This does NOT weaken the rule that the client only reads Config to DISPLAY.
	The client derives the stock to draw it; `ShopService` derives it again
	before charging anybody, and the server's answer is the only one that counts
	(docs/arquitectura.md §4). Them agreeing is not the check -- it is the point
	of sharing the function.

	WHAT SIDE OF THE BORDER THIS CARRIES: none. It derives PUBLIC stock from a
	clock and a catalogue, and there is no truth inside it -- no profile, no
	`isFake`, nothing a rival should not know. That is why it may live in Shared
	at all, and the next person who wants to add a parameter here inherits the
	question: does the new input carry anything one side knows and the other
	should not? If yes, it does not belong in this file.

	THE CLOCK IS THE SERVER'S, NOT THE MACHINE'S. `workspace:GetServerTimeNow()`
	is synchronised; `os.time()` is whatever the device believes. A player whose
	clock is an hour off would have seen a different kiosk than the one the
	server would sell them -- items greyed out for no visible reason, and a
	refusal as the first explanation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class Kiosk

	What the kiosk offers right now, derived from a synchronised clock. Shared so
	the client draws exactly what the server will validate against.
]=]
local Kiosk = {}

--- The synchronised clock, in seconds. One place, so a test can reason about
--- rotation without waiting fifteen minutes.
function Kiosk.now(): number
	return workspace:GetServerTimeNow()
end

--- Which rotation window we are in. Whole numbers, increasing.
function Kiosk.window(now: number?): number
	return math.floor((now or Kiosk.now()) / Economy.kiosk.rotationSeconds)
end

--- What one copy of this object costs. Derived from its value, never stored per
--- item, so a new object in the catalogue is priced the moment it exists and
--- nobody has to remember to add a price.
function Kiosk.priceOf(itemId: Types.ItemId): number?
	local def = Items.catalog[itemId]
	if not def then
		return nil
	end
	return math.max(1, math.floor(def.baseValue * Economy.shop.buyMultiplier))
end

--- Which objects the kiosk is offering in this window.
---
--- Seeded from the window number rather than random, so every server -- and
--- every client -- shows the SAME stock at the same moment. Two players in
--- different servers seeing different kiosks would make the shop feel like a
--- slot machine, and docs/gdd.md §34 rules out anything that reads as one.
function Kiosk.stock(now: number?): { Types.ItemId }
	local rng = Random.new(Kiosk.window(now))

	-- Drawn without replacement from a copy of the catalogue order, so one
	-- rotation never offers the same object twice.
	local pool = table.clone(Items.order)
	local stock: { Types.ItemId } = {}

	for _ = 1, math.min(Economy.kiosk.slots, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(stock, pool[index])
		table.remove(pool, index)
	end

	return stock
end

--- Whether this object is for sale right now. Being in the catalogue is not the
--- same as being in stock, and a client is free to ask for anything.
function Kiosk.inStock(itemId: Types.ItemId, now: number?): boolean
	for _, offered in Kiosk.stock(now) do
		if offered == itemId then
			return true
		end
	end
	return false
end

--- Seconds until the kiosk rotates. The UI counts down locally from this rather
--- than asking repeatedly.
function Kiosk.secondsUntilRotation(now: number?): number
	local period = Economy.kiosk.rotationSeconds
	return period - ((now or Kiosk.now()) % period)
end

return Kiosk
