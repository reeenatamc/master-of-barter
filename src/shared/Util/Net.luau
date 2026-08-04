--!strict
--[[
	Net.luau -- single source of truth for RemoteEvent names.

	Why this file exists: the server creates the remotes and the client looks
	them up by name. If those two names live in two places, one typo makes the
	client wait forever on a remote that was never created -- and it fails
	silently, which is the worst kind of bug to chase. Declaring them once here
	removes the possibility.

	docs/arquitectura.md §6 lists the MVP catalog and rules out RemoteFunctions:
	a RemoteFunction invoked toward a client lets that client hang a server
	thread by simply never answering. Everything here is a RemoteEvent, and any
	reply comes back as another event.

	The doc writes names as `Duel/Ofertar`. That slash is grouping notation, not
	a folder: the remotes live flat in Shared/Remotes with a prefix, which keeps
	lookups one level deep.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Keys and values match on purpose: the key gives autocomplete at the call
-- site, the value is the actual instance name.
local NAMES = {
	-- Client -> server. Every one of these is an untrusted request.
	DuelOffer = "DuelOffer",
	DuelNegotiate = "DuelNegotiate", -- Accept | Decline | RaiseOffer | FakeCall
	DuelEmote = "DuelEmote",
	QueueJoin = "QueueJoin",
	QueueLeave = "QueueLeave",
	ShopBuy = "ShopBuy",

	-- Server -> client. These carry already-censored views, never raw truth.
	DuelState = "DuelState",
	DuelReveal = "DuelReveal",
	PlayerData = "PlayerData",
	Notice = "Notice",
}

--[=[
	@class Net

	Single source of truth for RemoteEvent names. The server creates the whole
	catalog once with `createAll()`; both sides then look each remote up by name
	with `get()`, so a typo cannot silently split them into two different names.
]=]
local Net = {
	names = NAMES,
}

-- Waits for Shared/Remotes. Instant on the server; on the client it blocks
-- until replication catches up, which is why nothing else here yields.
local function remotesFolder(): Instance
	local shared = ReplicatedStorage:WaitForChild("Shared")
	return shared:WaitForChild("Remotes")
end

--- Server-side boot step: creates every remote in the catalog.
--- Safe to call twice; it will not duplicate anything.
function Net.createAll()
	assert(RunService:IsServer(), "Net.createAll can only run on the server")

	local folder = remotesFolder()
	-- The cast is only for the loop: NAMES keeps its literal type so that
	-- `Net.names.Typo` is a type error instead of a silent nil.
	for _, name in (NAMES :: { [string]: string }) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

--- Looks up a remote by name. Errors loudly after 10s instead of hanging
--- forever, so a missing remote shows up as a red line in Output.
function Net.get(name: string): RemoteEvent
	local remote = remotesFolder():WaitForChild(name, 10)
	assert(remote, `Net: remote "{name}" never appeared. Did the server run Net.createAll()?`)
	return remote :: RemoteEvent
end

return Net
