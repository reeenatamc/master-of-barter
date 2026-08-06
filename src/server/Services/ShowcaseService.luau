--!strict
--[[
	ShowcaseService.luau -- the public showcase, and the only user-written text
	in the game.

	Card E3's last piece (P2). Everything else a player can put on screen is
	chosen from a catalogue we wrote. This is the one surface where somebody
	types, so it carries the whole moderation burden of the project.

	── THE RULE, AND IT HAS NO EXCEPTIONS ──────────────────────────────────────

	Text goes through TextService before it is stored, and ONLY the filtered
	result is ever stored or shown -- including back to whoever typed it. The raw
	string exists inside this function and nowhere else: not in the profile, not
	in a log, not in the view.

	That is stricter than Roblox requires (the API can return a per-viewer
	string, which would let an author see their own text less filtered), and it
	is stricter on purpose. A filtered-per-viewer design needs the raw text kept
	so it can be filtered again later, and "raw user text in the datastore" is a
	liability that buys nothing this game needs.

	── FAIL CLOSED ─────────────────────────────────────────────────────────────

	`FilterStringAsync` is a network call and can throw. When it does, the name
	is NOT set. Nothing is stored, nothing is shown, and the player is told to
	try again.

	This is the one place in the project where the safe direction is refusing.
	Everywhere else a failed side path degrades (analytics disables its sink, the
	cap drops breakdowns) because the cost of stopping is worse than the cost of
	continuing. Here the cost of continuing is unfiltered text on a public wall.

	── API, VERIFIED 2026-08-05 ────────────────────────────────────────────────

	`TextService:FilterStringAsync(text, fromUserId)` returns a TextFilterResult,
	and `GetNonChatStringForBroadcastAsync()` is the method for showing it on a
	public wall. Both confirmed against the docs.

	ONE THING CHANGED, and the reason matters more than the change: the first
	draft also passed a third argument, `Enum.TextFilterContext.PublicChat`.
	THAT ENUM IS REAL -- it was not invented, and the verification did not
	contradict it. It simply did not COVER it, and the default is already the
	context this needs.

	So it was removed for economy of confirmation, not for being wrong: passing
	an argument that buys no behaviour costs verification surface for free. Do
	not pass what you cannot confirm when the default gives you what you want.
	Quarantine is for guesses that earn their keep; a guess that changes nothing
	is just a guess.

	Both calls still live in ONE wrapped function, because that is what makes a
	wrong answer here cost a refused rename instead of a leak.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Showcase = require(ReplicatedStorage.Shared.Config.Showcase)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShowcaseService = {}

--- Last rename per player. A cooldown here is not politeness: every attempt is
--- a call to a rate-limited moderation API, so without one a single client can
--- spend the whole experience's filter budget.
local lastSetAt: { [Player]: number } = {}

--- Runs the text through Roblox's filter and returns what may be shown, or nil.
---
--- The ONLY place a raw player string exists. Everything downstream receives the
--- return value, so there is no path where the unfiltered text could be stored
--- or drawn -- not by discipline, but because nothing else is ever handed it.
local function filtered(text: string, author: Player): string?
	local ok, result = pcall(function()
		local filter = TextService:FilterStringAsync(text, author.UserId)
		return filter:GetNonChatStringForBroadcastAsync()
	end)

	if not ok then
		-- Fail CLOSED. A filter that did not answer is not permission.
		warn(`[Showcase] filtering failed for {author.Name}: {result}`)
		return nil
	end
	return result :: string
end

--- Sets the showcase name. Validated in the four layers of
--- docs/arquitectura.md §8, and the order matters: everything cheap runs before
--- the network call, so a malformed request never reaches the filter API.
function ShowcaseService.setName(player: Player, raw: unknown)
	local notice = Net.get(Net.names.Notice)

	-- Layer 1: type.
	if type(raw) ~= "string" then
		warn(`[Showcase] {player.Name}: name is not a string`)
		return
	end

	-- Layer 2: range. Checked on the RAW string, before the filter, because a
	-- twelve-thousand-character payload should cost us nothing at all.
	local trimmed = (raw:gsub("^%s+", ""):gsub("%s+$", ""))
	if #trimmed < Showcase.nameLength.min or #trimmed > Showcase.nameLength.max then
		notice:FireClient(player, Strings.notices.showcaseNameLength)
		return
	end

	-- Layer 3: state. A spectator has no profile to write to.
	local profile = DataService.get(player)
	if not profile then
		notice:FireClient(player, Strings.notices.spectatorNoDuel)
		return
	end

	-- Layer 4: rate. Before the network call, so the cooldown actually protects
	-- the filter budget rather than merely reporting on it afterwards.
	local now = os.clock()
	local previous = lastSetAt[player]
	if previous and now - previous < Showcase.renameCooldownSeconds then
		notice:FireClient(player, Strings.notices.showcaseTooSoon)
		return
	end
	lastSetAt[player] = now

	local safe = filtered(trimmed, player)
	if not safe then
		notice:FireClient(player, Strings.notices.showcaseFilterFailed)
		return
	end

	profile.showcase.name = safe
	PlayerDataService.markDirty(player)
end

--- Sets which collected objects are on display.
---
--- No filtering needed and none done: these are ids from a catalogue we wrote.
--- The check that matters is ownership -- you cannot show off something you
--- have not won.
function ShowcaseService.setItems(player: Player, raw: unknown)
	if type(raw) ~= "table" then
		warn(`[Showcase] {player.Name}: items is not a table`)
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local chosen: { Types.ItemId } = {}
	local seen: { [string]: boolean } = {}

	for _, entry in raw :: { [any]: any } do
		if #chosen >= Showcase.slots then
			break
		end
		if type(entry) ~= "string" then
			warn(`[Showcase] {player.Name}: an item id is not a string`)
			return
		end
		-- Existence, then ownership, then uniqueness. A shelf that shows the
		-- same object four times is a client bug, not a display choice.
		if not Items.catalog[entry] then
			warn(`[Showcase] {player.Name}: unknown item "{entry}"`)
			return
		end
		if (profile.collection[entry] or 0) <= 0 then
			warn(`[Showcase] {player.Name}: does not own "{entry}"`)
			return
		end
		if not seen[entry] then
			seen[entry] = true
			table.insert(chosen, entry)
		end
	end

	profile.showcase.items = chosen
	PlayerDataService.markDirty(player)
end

function ShowcaseService.init()
	Net.get(Net.names.ShowcaseSet).OnServerEvent:Connect(function(player: Player, name: unknown, items: unknown)
		-- Two requests in one remote because they arrive together from one
		-- screen. Each is validated on its own; neither depends on the other
		-- having succeeded.
		if name ~= nil then
			ShowcaseService.setName(player, name)
		end
		if items ~= nil then
			ShowcaseService.setItems(player, items)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSetAt[player] = nil
	end)
end

return ShowcaseService
