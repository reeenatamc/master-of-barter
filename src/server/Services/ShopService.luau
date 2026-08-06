--!strict
--[[
	ShopService.luau -- the kiosk: buying duel copies with Clips.

	Card B4, buying half. Selling does not exist and its absence is deliberate --
	see docs/decisiones.md, case (d) on sellMultiplier.

	Robux purchases and ProcessReceipt are card B5 and are NOT here. That card
	touches money and idempotency, which is a conversation to have on purpose
	rather than a thing to slip into a card about a shop.

	Prices are never sent by the client and never trusted from it: the client
	reads Config to DISPLAY a price, the server works it out again from the same
	Config before charging (docs/arquitectura.md §4). Those two agreeing is not
	the check -- the server's answer is simply the only one that counts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Analytics = require(ReplicatedStorage.Shared.Config.Analytics)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local ShopService = {}

--- What one copy of this object costs. Derived from its value, never stored
--- per item, so a new object in the catalogue is priced the moment it exists
--- and nobody has to remember to add a price.
function ShopService.priceOf(itemId: Types.ItemId): number?
	local def = Items.catalog[itemId]
	if not def then
		return nil
	end
	return math.max(1, math.floor(def.baseValue * Economy.shop.buyMultiplier))
end

--- Which objects the kiosk is offering right now.
---
--- Rotates on a clock rather than at random, and seeded from the window number
--- so every server shows the SAME stock at the same moment. Two players in
--- different servers seeing different kiosks would make the shop feel like a
--- slot machine, and docs/gdd.md §34 rules out anything that reads as one.
function ShopService.stockNow(): { Types.ItemId }
	local window = math.floor(os.time() / Economy.kiosk.rotationSeconds)
	local rng = Random.new(window)

	-- Drawn without replacement from a copy of the catalogue order, so a
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

--- Seconds until the kiosk rotates. The UI counts down locally from this rather
--- than asking repeatedly.
function ShopService.secondsUntilRotation(): number
	local period = Economy.kiosk.rotationSeconds
	return period - (os.time() % period)
end

local function inStock(itemId: Types.ItemId): boolean
	for _, offered in ShopService.stockNow() do
		if offered == itemId then
			return true
		end
	end
	return false
end

--- Buys one copy. Validated in the four layers of docs/arquitectura.md §8, and
--- the order matters: everything that can refuse runs BEFORE anything that
--- changes, so a rejected purchase leaves no half-finished state.
function ShopService.buy(player: Player, itemId: unknown)
	local notice = Net.get(Net.names.Notice)

	-- Layer 1: type.
	if type(itemId) ~= "string" then
		warn(`[ShopService] {player.Name}: item id is not a string`)
		return
	end

	-- Layer 2: existence, against the catalogue.
	local price = ShopService.priceOf(itemId)
	if not price then
		warn(`[ShopService] {player.Name}: unknown item "{itemId}"`)
		return
	end

	-- Layer 3: state. Being in the catalogue is not the same as being for sale
	-- today, and a client is free to ask for anything.
	if not inStock(itemId) then
		warn(`[ShopService] {player.Name}: "{itemId}" is not in stock this rotation`)
		notice:FireClient(player, Strings.notices.shopNotStocked)
		return
	end

	-- Layer 4: economy. A spectator has no profile, so there is nothing to
	-- charge and nowhere to put what they bought.
	if not DataService.get(player) then
		notice:FireClient(player, Strings.notices.spectatorNoDuel)
		return
	end

	local paid, refusal = EconomyService.charge(player, price, `shop:{itemId}`)
	if not paid then
		notice:FireClient(player, Strings.notices.shopCannotAfford)
		warn(`[ShopService] {player.Name} could not buy "{itemId}" for {price} ({refusal})`)
		return
	end

	-- Charged first, granted second, and never the other way round. If the
	-- order were reversed, a failure between them would hand over something
	-- nobody paid for -- and that failure inflates the economy, which is the
	-- kind that spreads.
	InventoryService.giveCopy(player, itemId)

	-- Recorded after the grant, so what is counted is what actually happened
	-- rather than what was attempted.
	AnalyticsService.record(Analytics.events.shopPurchase, {
		itemId = itemId,
		price = price,
		balanceAfter = EconomyService.balanceOf(player),
	}, player)
end

function ShopService.init()
	Net.get(Net.names.ShopBuy).OnServerEvent:Connect(function(player: Player, itemId: unknown)
		ShopService.buy(player, itemId)
	end)
end

return ShopService
