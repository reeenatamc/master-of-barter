--!strict
--[[
	DataService.luau -- ProfileStore: load/release profiles, read/write API.

	The only door to persistent data. Card B1, and the one part of the project
	where a bug does not announce itself: a broken duel is visible in a second,
	a broken save is visible next week when somebody's collection is gone.

	Three rules from docs/arquitectura.md §7 shape everything here:

	  1. Session locking is the point. Two servers must never hold the same
	     profile, which ProfileStore guarantees and this service never bypasses.
	  2. Never save on a small change. Auto-save covers it, and a save per
	     mutation burns the request budget for nothing.
	  3. If a profile does not load, the player becomes a SPECTATOR with a
	     retry -- never a default profile. Default data that later overwrites
	     real data is how a collection disappears, and it does it without
	     raising a single error.

	The schema is §7's, with the glossary's translations: Coleccion -> collection,
	CopiasDuelo -> duelCopies, Recibos -> receipts. Adding a field with a
	migration is ordinary work; changing the SHAPE of what is already saved is
	not something to do without asking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local ProfileStore = require(script.Parent.Parent.ProfileStore)

type Profile = Types.Profile

local DataService = {}

--- Fired once a player's profile is loaded and safe to read. Other services
--- wait for this rather than polling: a service that reads a profile before it
--- exists is a service that invents one.
DataService.profileLoaded = Signal.new()
--- Fired as a profile is released, while it can still be read one last time.
DataService.profileReleased = Signal.new()

--- The starting profile. Every field of docs/arquitectura.md §7 is here,
--- including the ones nothing reads yet.
---
--- ADDING a field needs no version bump: `profile:Reconcile()` runs before
--- `migrate` on every load and fills missing keys from this template. The
--- version and the migration chain are for CHANGING a shape -- a rename, a
--- restructure, a field that means something different than it used to --
--- which Reconcile cannot guess at. Bumping for a plain addition would add a
--- migration step that does nothing and a gap in the chain to explain later.
local TEMPLATE: Profile = {
	dataVersion = DataConfig.version,
	clips = Economy.startingClips,
	level = 1,
	xp = 0,
	collection = {},
	duelCopies = {},
	cosmetics = { owned = {}, equipped = {} },
	stats = { duels = 0, wins = 0, fakesSlipped = 0, fakesCaught = 0 },
	quests = { date = "", progress = {} },
	receipts = {},
	escrow = {},
	botEarnings = { date = "", value = 0 },
	showcase = { name = "", items = {} },
}

local realStore = ProfileStore.New(DataConfig.storeName, TEMPLATE)

--- In Studio, talk to ProfileStore's own mock DataStore unless told otherwise.
---
--- Without this nothing works in Studio until the place is published with API
--- access enabled, and every play-test writes to the live store. With it, the
--- mock still enforces session locking, so the interesting failure -- two
--- sessions fighting over one profile -- stays testable.
---
--- The real store has to be exercised before release regardless: a mock that
--- behaves cannot prove a DataStore does. See docs/checkpoint-3.md.
local useMock = RunService:IsStudio() and DataConfig.useMockInStudio
local store = if useMock then realStore.Mock else realStore

local profiles: { [Player]: Profile } = {}
--- Handles kept apart from the data, so nothing that reads a profile can reach
--- the session object and end it by accident.
local sessions: { [Player]: any } = {}
--- Players who are in the game with no profile behind them. They must not be
--- able to change anything, because there is nowhere to write it down.
local spectators: { [Player]: boolean } = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Migrations
-- ─────────────────────────────────────────────────────────────────────────────

--- Applied in order, each taking a profile from one version to the next.
--- Chained, per §7: a profile saved three versions ago walks forward through
--- every step rather than jumping, so no migration ever needs to know about
--- more than the shape immediately before it.
---
--- Empty today, because version 1 is the first. The machinery exists from day
--- one on purpose -- retrofitting migrations onto live data is how saves get
--- corrupted.
local migrations: { [number]: (Profile) -> () } = {}

local function migrate(profile: Profile, who: string)
	local from = profile.dataVersion or 1

	while from < DataConfig.version do
		local step = migrations[from]
		if not step then
			-- A gap means someone bumped the version without writing the
			-- migration. Warned rather than guessed at: the alternative is
			-- silently handing back a profile of the wrong shape.
			warn(`[DataService] {who}: no migration from version {from}; leaving the profile as it is`)
			return
		end
		step(profile)
		from += 1
		profile.dataVersion = from
	end
end

-- ─────────────────────────────────────────────────────────────────────────────

--- The profile, or nil while it loads or if it never loaded. Callers must
--- handle nil: "there is no profile" is a normal state, not an error.
function DataService.get(player: Player): Profile?
	return profiles[player]
end

--- True when this player is in the game with nothing behind them. Nothing they
--- do may be written down, so nothing they do may change anything.
function DataService.isSpectator(player: Player): boolean
	return spectators[player] == true
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`{DataConfig.keyPrefix}{player.UserId}`, {
		-- Stop trying the moment the player is gone. Without this, someone who
		-- leaves mid-retry leaves a session open behind them.
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		-- Either the DataStore is unreachable or another session holds the
		-- lock. Spectator with a retry, never defaults (§7): default data that
		-- later overwrites real data is how a collection disappears, and it
		-- does it without raising anything.
		spectators[player] = true

		-- WHY it failed, not just that it did. Without this line, "the API is
		-- switched off in Studio" and "the save logic is broken" produce the
		-- identical message, and somebody spends an afternoon debugging a
		-- checkbox. ProfileStore reports its own access as NotReady,
		-- NoInternet, NoAccess or Access.
		warn(
			`[DataService] {player.Name} has no profile; spectator mode.`
				.. ` DataStore access: {ProfileStore.DataStoreState}.`
				.. ` (NoAccess = Studio API access is off, or the place is unpublished.`
				.. ` Access = reachable, so the profile is genuinely locked elsewhere.)`
		)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data, player.Name)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		sessions[player] = nil
		-- The lock is gone, so another server may already be writing this
		-- profile. Staying in the game would mean playing against data nobody
		-- owns any more.
		if player.Parent == Players then
			player:Kick(DataConfig.sessionEndedMessage)
		end
	end)

	if player.Parent ~= Players then
		-- They left while it was loading.
		profile:EndSession()
		return
	end

	sessions[player] = profile
	profiles[player] = profile.Data
	DataService.profileLoaded:fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	spectators[player] = nil

	local data = profiles[player]
	if data then
		-- Announced BEFORE the release, so listeners get one last chance to
		-- write something down while there is still somewhere to write it.
		DataService.profileReleased:fire(player, data)
	end
	profiles[player] = nil

	local session = sessions[player]
	sessions[player] = nil
	if session then
		session:EndSession()
	end
end

--- Wires the service. Called by Main in boot order, before anything that reads
--- a profile.
---
--- There is deliberately no BindToClose here: ProfileStore already holds the
--- server open until every session is written, and a second one would just race
--- the first.
function DataService.init()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return DataService
