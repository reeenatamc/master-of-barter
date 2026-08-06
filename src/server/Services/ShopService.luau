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
local Kiosk = require(ReplicatedStorage.Shared.Util.Kiosk)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local ShopService = {}

--- Re-exported so nothing has to reach past this service for a price. The
--- derivation lives in Shared/Util/Kiosk because the CLIENT needs the same
--- answer to draw the kiosk, and two implementations of "what is for sale" is
--- how a greyed-out button gets a reason nobody can explain.
function ShopService.priceOf(itemId: Types.ItemId): number?
	return Kiosk.priceOf(itemId)
end

function ShopService.stockNow(): { Types.ItemId }
	return Kiosk.stock()
end

function ShopService.secondsUntilRotation(): number
	return Kiosk.secondsUntilRotation()
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
	if not Kiosk.inStock(itemId) then
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
