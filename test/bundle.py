#!/usr/bin/env python3
"""Bundles the real game modules with a stubbed Roblox surface into one Luau file.

Called by ../selfplay.sh; not meant to be run by hand.

Everything in SHARED/CONFIG/UTIL/SERVICES is loaded VERBATIM from src/ -- this
file never edits game code, it only builds the world around it. What is faked is
listed in the prelude, and it is small: task, os.clock, Random, Instance, the
service locator and an instance tree.

NOT COVERED, and stated here so nobody reads a green run as more than it is:
ProfileStore (saving, session locking, migrations -- that is checkpoint 3),
DuelSceneService (Instance/CFrame work with nothing to assert headlessly), and
anything on the client.
"""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

SHARED = {
    "Types": "src/shared/Types.luau",
}
CONFIG = {
    "Items": "src/shared/Config/Items.luau",
    "Economy": "src/shared/Config/Economy.luau",
    "DuelRules": "src/shared/Config/DuelRules.luau",
    "Strings": "src/shared/Config/Strings.luau",
    "Bots": "src/shared/Config/Bots.luau",
    "Analytics": "src/shared/Config/Analytics.luau",
}
UTIL = {
    "Signal": "src/shared/Util/Signal.luau",
    "Trove": "src/shared/Util/Trove.luau",
    "Net": "src/shared/Util/Net.luau",
}
SERVICES = {
    "AnalyticsService": "src/server/Services/AnalyticsService.luau",
    "DuelTypes": "src/server/Services/DuelTypes.luau",
    "DuelView": "src/server/Services/DuelView.luau",
    "DuelReveal": "src/server/Services/DuelReveal.luau",
    "DuelOffers": "src/server/Services/DuelOffers.luau",
    "DuelStakes": "src/server/Services/DuelStakes.luau",
    "DuelService": "src/server/Services/DuelService.luau",
    "BotService": "src/server/Services/BotService.luau",
    "EconomyService": "src/server/Services/EconomyService.luau",
    "InventoryService": "src/server/Services/InventoryService.luau",
}

PRELUDE = r"""
-- ─────────────────────────────────────────────────────────────────────────────
-- Roblox surface, stubbed. Everything below this line is scaffolding; every
-- module ABOVE the runner is the real file from src/, unmodified.
-- ─────────────────────────────────────────────────────────────────────────────

local vnow = 0.0
local pending: { any } = {}
local byThread: { [thread]: any } = {}

function warn(...)
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	print("WARN " .. table.concat(parts, " "))
end

local realType = type
function typeof(x)
	return realType(x)
end

task = {
	delay = function(seconds: number, fn)
		local co = coroutine.create(fn)
		local entry = { at = vnow + seconds, co = co, cancelled = false, done = false }
		byThread[co] = entry
		table.insert(pending, entry)
		return co
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	cancel = function(co)
		local entry = byThread[co]
		if entry and entry.done then
			error("cannot cancel a thread that finished")
		end
		if entry then
			entry.cancelled = true
		end
	end,
}

--- Virtual time. Runs everything due, in order, and lets callbacks schedule more.
local function advance(dt: number)
	local target = vnow + dt
	while true do
		local best, bestIndex = nil, nil
		for index, entry in pending do
			if not entry.cancelled and (best == nil or entry.at < best.at) then
				best, bestIndex = entry, index
			end
		end
		if best == nil or best.at > target then
			break
		end
		vnow = best.at
		table.remove(pending, bestIndex)
		best.done = true
		local ok, err = coroutine.resume(best.co)
		if not ok then
			error(`scheduled callback failed: {err}`)
		end
	end
	vnow = target
end

task.wait = function(seconds: number?)
	advance(seconds or 0.016)
	return seconds or 0.016
end

local realClock = os.clock
os = setmetatable({
	clock = function()
		return vnow
	end,
	time = function()
		return 1785000000 + math.floor(vnow)
	end,
	date = function(fmt)
		return "2026-08-05"
	end,
	wallClock = realClock,
}, { __index = { difftime = function(a, b) return a - b end } })

Random = {}
Random.new = function(seed)
	local self = {}
	function self:NextNumber(a, b)
		if a == nil then
			return math.random()
		end
		return a + math.random() * (b - a)
	end
	function self:NextInteger(a, b)
		return math.random(a, b)
	end
	return self
end

Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, k2) return k2 end }) end })

-- ── the fake instance tree ───────────────────────────────────────────────────

local function node(name: string, parent: any?)
	local n = { Name = name, Parent = parent, _children = {} }
	function n:WaitForChild(child, _timeout)
		return self[child]
	end
	function n:FindFirstChild(child)
		return rawget(self, child)
	end
	function n:GetChildren()
		return self._children
	end
	if parent then
		parent[name] = n
		table.insert(parent._children, n)
	end
	return n
end

local registry: { [any]: any } = {}
local loaded: { [any]: any } = {}

function require(target)
	if loaded[target] ~= nil then
		return loaded[target]
	end
	local loader = registry[target]
	if not loader then
		error(`harness: nothing registered for {target and target.Name or "nil"}`)
	end
	local result = loader(target)
	loaded[target] = result
	return result
end

local ReplicatedStorage = node("ReplicatedStorage")
local Shared = node("Shared", ReplicatedStorage)
local Config = node("Config", Shared)
local Util = node("Util", Shared)
node("Remotes", Shared)
local ServerScriptService = node("ServerScriptService")
local Services = node("Services", ServerScriptService)

local guidCounter = 0
local fakePlayers: { any } = {}

local HttpService = {
	GenerateGUID = function(_self, _braces)
		guidCounter += 1
		return `id-{guidCounter}`
	end,
}
local RunService = { IsServer = function() return true end, IsStudio = function() return true end }
local PlayersService = { GetPlayers = function() return fakePlayers end }
PlayersService.PlayerRemoving = { Connect = function() return { Disconnect = function() end } end }
PlayersService.PlayerAdded = { Connect = function() return { Disconnect = function() end } end }

workspace = { GetServerTimeNow = function() return vnow end }

local SERVICES_BY_NAME = {
	ReplicatedStorage = ReplicatedStorage,
	HttpService = HttpService,
	RunService = RunService,
	Players = PlayersService,
	ServerScriptService = ServerScriptService,
	Workspace = workspace,
}

game = {
	GetService = function(_self, name)
		local s = SERVICES_BY_NAME[name]
		if not s then
			error(`harness: no stub for service {name}`)
		end
		return s
	end,
}

Instance = {
	new = function(className)
		if className == "RemoteEvent" then
			local remote = { Name = "", ClassName = "RemoteEvent" }
			remote.OnServerEvent = { Connect = function() return { Disconnect = function() end } end }
			function remote:FireClient() end
			function remote:FireAllClients() end
			function remote:Destroy() end
			return setmetatable(remote, {
				__newindex = function(t, k, v)
					rawset(t, k, v)
					if k == "Parent" and v then
						rawset(v, rawget(t, "Name"), t)
					end
				end,
			})
		end
		local inst = { ClassName = className }
		function inst:Destroy() end
		return inst
	end,
}
"""

RUNNER = r"""
-- ─────────────────────────────────────────────────────────────────────────────
-- Stubs for the two services this harness deliberately does NOT exercise.
-- ─────────────────────────────────────────────────────────────────────────────

local Signal = require(Util.Signal)
local Types = require(Shared.Types)
local Economy = require(Config.Economy)

--- The scene is Instance/CFrame work with nothing to assert headlessly.
registry[node("DuelSceneService", Services)] = function()
	return {
		open = function()
			return function() end
		end,
	}
end

--- In-memory profiles. This is NOT ProfileStore: saving, session locking and
--- migrations are checkpoint 3's job and are not claimed here. What it does give
--- is a real profile SHAPE, so InventoryService, EconomyService and the escrow
--- ledger run against something that can actually hold state.
local profiles: { [any]: any } = {}
local DataStub = {
	profileLoaded = Signal.new(),
	profileReleased = Signal.new(),
	get = function(player)
		return profiles[player]
	end,
	isSpectator = function(player)
		return profiles[player] == nil
	end,
}
registry[node("DataService", Services)] = function()
	return DataStub
end

-- ─────────────────────────────────────────────────────────────────────────────

local Net = require(Util.Net)
local DuelRules = require(Config.DuelRules)
local DuelService = require(Services.DuelService)
local BotService = require(Services.BotService)
local InventoryService = require(Services.InventoryService)

Net.createAll()
DuelRules.debugLogs = true

InventoryService.init()
DuelService.init()
BotService.init()

--- A player with a profile, the way DataService would hand one over.
local function addPlayer(name: string)
	local player = { Name = name, DisplayName = name, UserId = 1, Parent = PlayersService }
	table.insert(fakePlayers, player)
	profiles[player] = {
		dataVersion = 1,
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
	}
	DataStub.profileLoaded:fire(player, profiles[player])
	return player
end

local mode = ARGV_MODE
local count = ARGV_COUNT

if mode == "bots" then
	BotService.selfPlay(count)
else
	local player = addPlayer("HarnessPlayer")
	local before = 0
	for _, n in profiles[player].duelCopies do
		before += n
	end
	print(`[harness] starter copies: {before}, clips: {profiles[player].clips}`)
	BotService.selfPlay(count, player)

	local after = 0
	for _, n in profiles[player].duelCopies do
		after += n
	end
	print(`[harness] after: {after} copies, {profiles[player].clips} clips, {#profiles[player].escrow} escrow entries`)
	print(`[harness] bot earnings recorded: {profiles[player].botEarnings.value}`)
	local collected = 0
	for _, n in profiles[player].collection do
		collected += n
	end
	print(`[harness] collection size: {collected}   (must be 0 -- duels move copies, never collection)`)
end
"""


def wrap(name, path):
    src = (ROOT / path).read_text(encoding="utf-8")
    return f"\n-- ════ {path} ════\nregistry[MODULE_{name}] = function(script)\n{src}\nend\n"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "bots"
    count = sys.argv[2] if len(sys.argv) > 2 else "200"

    out = [PRELUDE]
    decls = []
    body = []
    for group, parent in ((SHARED, "Shared"), (CONFIG, "Config"), (UTIL, "Util"), (SERVICES, "Services")):
        for name, path in group.items():
            decls.append(f'local MODULE_{name} = node("{name}", {parent})')
            body.append(wrap(name, path))
    out.append("\n".join(decls))
    out.extend(body)
    out.append(RUNNER.replace("ARGV_MODE", f'"{mode}"').replace("ARGV_COUNT", count))

    dest = ROOT / (sys.argv[3] if len(sys.argv) > 3 else ".tools/harness.luau")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("".join(out), encoding="utf-8")
    print(dest)


main()
