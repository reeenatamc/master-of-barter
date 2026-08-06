--!strict
--[[
	PlayerDataService.luau -- pushes your own profile to your own client.

	Card E3's server half. The HUD has to show Clips and the collection "always
	coherent with the server", and until now the client had NO WAY to learn its
	own balance: `Net.names.PlayerData` was declared and never fired, and
	`EconomyService.balanceChanged` had not one subscriber.

	Two things without a consumer, which by rule 6 are two decisions nobody
	made. Unlike the DuelReveal remote, the answer here is not to delete them --
	they are not a second exit for anything, they are a missing feature whose
	name was already reserved. So they get their consumer.

	ONE RECIPIENT, ALWAYS. This is the one payload in the game that is nobody
	else's business: it goes to its owner and to no one else, ever. The send is
	in a single function for the same reason DuelView has a single funnel -- so
	"who can receive this" is a question with one place to look.

	COALESCED. A duel that ends hands over four copies and pays out, which is
	five separate changes to the same profile in the same instant. Sending five
	payloads would be five times the traffic to draw one number, so a change
	marks the player dirty and one push goes out on the next tick.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local PlayerDataService = {}

--- Players with a change waiting to go out.
local dirty: { [Player]: boolean } = {}
local flushScheduled = false

--- Builds the view field by field, never by cloning the profile.
---
--- That is not style. A clone would carry `escrow`, `receipts` and
--- `botEarnings` to the client the moment somebody added them to the template,
--- silently -- and `botEarnings` in particular would hand over the fact that
--- filler opponents exist (see Types.PlayerDataView).
local function viewOf(profile: Types.Profile): Types.PlayerDataView
	return {
		clips = profile.clips,
		collection = table.clone(profile.collection),
		duelCopies = table.clone(profile.duelCopies),
		-- Already filtered when it was stored, so this is a copy of safe text
		-- rather than a filtering step that could be forgotten.
		showcase = {
			name = profile.showcase.name,
			items = table.clone(profile.showcase.items),
		},
	}
end

--- The only send. One recipient: the owner.
local function push(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	Net.get(Net.names.PlayerData):FireClient(player, viewOf(profile))
end

local function flush()
	flushScheduled = false
	local pending = dirty
	dirty = {}

	for player in pending do
		-- They may have left between the change and this tick.
		if player.Parent then
			push(player)
		end
	end
end

--- Marks a player as needing an update. Cheap and idempotent: call it from
--- anywhere that moves Clips or copies.
function PlayerDataService.markDirty(player: Player)
	dirty[player] = true
	if flushScheduled then
		return
	end
	flushScheduled = true
	-- `defer` rather than `delay(0)`: it runs after the current resumption
	-- finishes, so a duel that ends mid-payout gets ONE push with the final
	-- numbers instead of one per credit.
	task.defer(flush)
end

--- Wires the service. Called by Main after the services whose signals it needs.
function PlayerDataService.init()
	-- Sent as soon as the profile is there, so a client that just joined draws
	-- real numbers instead of zeroes it has to correct a moment later.
	DataService.profileLoaded:connect(function(player: Player)
		PlayerDataService.markDirty(player)
	end)

	EconomyService.balanceChanged:connect(function(player: Player)
		PlayerDataService.markDirty(player)
	end)

	InventoryService.changed:connect(function(player: Player)
		PlayerDataService.markDirty(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		dirty[player] = nil
	end)
end

return PlayerDataService
