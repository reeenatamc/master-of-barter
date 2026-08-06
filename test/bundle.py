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
-- Enum.Whatever.Member.Name resolves to "Member", which is what the analytics
-- custom-field keys are.
Enum = setmetatable({}, {
	__index = function()
		return setmetatable({}, {
			__index = function(_, member)
				return { Name = member }
			end,
		})
	end,
})

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
local sent: { any } = {}

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
			-- RECORDED, not discarded. Everything the server sends a client goes
			-- into `sent`, which is what lets the spec assert the golden rule
			-- against real traffic instead of against a reading of the code.
			function remote:FireClient(player, ...)
				table.insert(sent, { remote = rawget(self, "Name"), player = player, args = { ... } })
			end
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

if mode == "spec-setup" then
	-- The spec drives everything itself; this only wires the services.
elseif mode == "bots" then
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


SPEC_RUNNER = r"""
-- ─────────────────────────────────────────────────────────────────────────────
-- The spec: deterministic assertions, one duel at a time.
--
-- Everything here was on the "verificación pendiente" list in the backlog --
-- written, type-clean, and never once exercised, waiting on a Studio session.
-- Each one is now a permanent regression instead of a line in a queue.
--
-- The golden rule check is the one that matters. It does not read the code and
-- conclude; it inspects EVERY DuelState the server actually sent across a run
-- and asserts what is in it. That is the difference between "viewOf has no
-- field for isFake" and "no client was ever sent one".
-- ─────────────────────────────────────────────────────────────────────────────

local Items = require(Config.Items)
local BotService = require(Services.BotService)

local passed, failed = 0, 0

local function check(name: string, ok: boolean, detail: string?)
	if ok then
		passed += 1
		print(`  PASS  {name}`)
	else
		failed += 1
		print(`  FAIL  {name}{if detail then `  --  {detail}` else ""}`)
	end
end

local function statesSent(): { any }
	local states = {}
	for _, entry in sent do
		if entry.remote == "DuelState" then
			table.insert(states, entry.args[1])
		end
	end
	return states
end

local function freshPlayers()
	table.clear(sent)
	local a = addPlayer("SpecA")
	local b = addPlayer("SpecB")
	return a, b
end

local function sideOf(duel, player)
	for _, side in duel.sides do
		if side.player == player then
			return side
		end
	end
	return nil
end

-- ── 1. THE GOLDEN RULE, against real traffic ─────────────────────────────────

print("\n[spec] golden rule")
do
	local a, b = freshPlayers()
	BotService.selfPlay(40, a)

	local states = statesSent()
	local leakedTruth, leakedEarly, revealsSeen = 0, 0, 0

	for _, state in states do
		for _, view in state.players do
			if view.slot ~= state.yourSlot and view.offer then
				for _, wrapped in view.offer.wrapped do
					-- The field must not merely be false. It must not EXIST.
					if (wrapped :: any).isFake ~= nil or (wrapped :: any).copyId ~= nil then
						leakedTruth += 1
					end
				end
			end
		end
		if state.reveal ~= nil then
			revealsSeen += 1
			if state.phase ~= "Reveal" then
				leakedEarly += 1
			end
		end
	end

	check(`{#states} states inspected, none carried a rival's truth`, leakedTruth == 0, `{leakedTruth} leaks`)
	check("reveal appeared only in phase Reveal", leakedEarly == 0, `{leakedEarly} early`)
	check("reveal appeared at all (so the check above can fail)", revealsSeen > 0, "never saw one")
end

-- ── 1b. THE PHASE GATE, tested by BUILDING the dangerous state ───────────────
--
-- The check above passes even with the gate deleted, and that is not a broken
-- test -- it is a fact about the code: `duel.reveal` is only ASSIGNED at the
-- terminal transition, so during normal play there is nothing for the gate to
-- hold back. Discovered by mutation: removing `if duel.phase == "Reveal"`
-- changed nothing observable.
--
-- Which means the gate is defence in depth, not the load-bearing piece, and an
-- assertion that cannot fail must either say so or be made real. This one is
-- made real: the truth is planted mid-negotiation on purpose -- exactly what a
-- future "pre-render the reveal" or inspection feature would do -- and the gate
-- is what has to stop it reaching a client.

print("\n[spec] the phase gate, against a planted reveal")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = Items.order[1] } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })
	check("the duel is mid-negotiation", duel.phase == "Negotiating", duel.phase)

	-- Planted. Nothing in the game does this today; the gate exists for the day
	-- something does.
	duel.reveal = {
		sides = {
			{ slot = 1, offered = {}, received = {}, valueReceived = 0, fakesPassed = 0 },
			{ slot = 2, offered = {}, received = {}, valueReceived = 0, fakesPassed = 0 },
		},
		winner = 1,
		fakeCall = nil,
	}

	table.clear(sent)
	-- Any action that broadcasts will do.
	DuelService.applyAction(duel, sideA, "RaiseOffer")

	local escaped = 0
	for _, state in statesSent() do
		if state.reveal ~= nil then
			escaped += 1
		end
	end
	check(`the planted truth reached nobody ({#statesSent()} states)`, escaped == 0, `{escaped} escaped`)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 2. Turn and limits ───────────────────────────────────────────────────────

print("\n[spec] turn, limits and the token")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	check("both offers moved the duel to Negotiating", duel.phase == "Negotiating", duel.phase)
	check("slot 2 cannot act out of turn", DuelService.applyAction(duel, sideB, "Accept") ~= nil)
	check("an unknown action is refused", DuelService.applyAction(duel, sideA, "Nope") ~= nil)
	check("a non-string action is refused", DuelService.applyAction(duel, sideA, 42) ~= nil)

	-- Three raises per side, then no more.
	local raiseRefusals = 0
	for _ = 1, 4 do
		if DuelService.applyAction(duel, sideA, "RaiseOffer") ~= nil then
			raiseRefusals += 1
		else
			-- Satisfy the demand so the turn comes back.
			local requests = {}
			for _, item in sideB.offer do
				table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
			end
			table.insert(requests, { isFake = true, claim = Items.order[1] })
			DuelService.applyOffer(duel, sideB, requests)
		end
	end
	check("the fourth raise is refused", raiseRefusals == 1, `{raiseRefusals} refusals`)

	-- An amendment that does not grow is refused.
	local same = {}
	for _, item in sideB.offer do
		table.insert(same, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
	end
	sideB.amendRequested = true
	duel.turn = sideB.slot
	check("an amendment that adds nothing is refused", DuelService.applyOffer(duel, sideB, same) ~= nil)

	DuelService.finish(duelId :: string, "spec cleanup")
end

-- ── 3. The watchdog generation ───────────────────────────────────────────────

print("\n[spec] watchdog generation")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { copyId = sideA.hand[1].copyId, isFake = false, claim = sideA.hand[1].itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	local firstDeadline = duel.deadline
	advance(DuelRules.phaseSeconds.Negotiating * 0.5)
	DuelService.applyAction(duel, sideA, "RaiseOffer")

	local requests = {}
	for _, item in sideB.offer do
		table.insert(requests, { copyId = item.copyId, isFake = item.isFake, claim = item.claim })
	end
	table.insert(requests, { isFake = true, claim = Items.order[1] })
	DuelService.applyOffer(duel, sideB, requests)

	-- Past the ORIGINAL deadline. The stale timer must do nothing.
	advance((firstDeadline - vnow) + 1)
	check("a re-armed phase survives its old deadline", DuelService.debugDuel(duelId :: string) ~= nil)

	-- Past the new one. Now it must die.
	advance(DuelRules.phaseSeconds.Negotiating + 1)
	check("the current deadline still cancels it", DuelService.debugDuel(duelId :: string) == nil)
	check("the trove released everything", duel.trove:Live() == 0, `{duel.trove:Live()} live`)
end

-- ── 4. Scoring ───────────────────────────────────────────────────────────────

print("\n[spec] scoring: a forgery is worth nothing")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	local honest = sideB.hand[1]
	-- A forges; B is honest with a real copy.
	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = honest.itemId } })
	DuelService.applyOffer(duel, sideB, { { copyId = honest.copyId, isFake = false, claim = honest.itemId } })
	DuelService.applyAction(duel, sideA, "Accept")

	local reveal = duel.reveal
	local liar = reveal.sides[sideB.slot]
	local cheat = reveal.sides[sideA.slot]
	check("the honest side received nothing of value", liar.valueReceived == 0, `{liar.valueReceived}`)
	check(
		"the cheat received the real baseValue",
		cheat.valueReceived == Items.catalog[honest.itemId].baseValue,
		`{cheat.valueReceived}`
	)
	check("the cheat is recorded as having slipped one", cheat.fakesPassed == 1, `{cheat.fakesPassed}`)
	check("lying won", reveal.winner == sideA.slot)
end

-- ── 5. The accusation token ──────────────────────────────────────────────────

print("\n[spec] the ES FAKE token")
do
	local a, b = freshPlayers()
	local duelId = DuelService.start(a, b)
	local duel = DuelService.debugDuel(duelId :: string)
	local sideA, sideB = sideOf(duel, a), sideOf(duel, b)

	DuelService.applyOffer(duel, sideA, { { isFake = true, claim = Items.order[1] } })
	DuelService.applyOffer(duel, sideB, { { copyId = sideB.hand[1].copyId, isFake = false, claim = sideB.hand[1].itemId } })

	check("a side starts with its token", sideA.fakeCallsLeft == DuelRules.limits.fakeCallsPerDuel)
	DuelService.applyAction(duel, sideA, "FakeCall")
	check("accusing an honest offer is WRONG", duel.reveal.fakeCall.correct == false)
	check("the token is spent", sideA.fakeCallsLeft == 0)
	check("a second accusation is refused", DuelService.applyAction(duel, sideA, "FakeCall") ~= nil)
end

print(`\n[spec] {passed} passed, {failed} failed`)
print(if failed == 0 then "RESULT: PASS" else "RESULT: FAIL")
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
    if mode == "spec":
        out.append(RUNNER.replace("ARGV_MODE", '"spec-setup"').replace("ARGV_COUNT", "0"))
        out.append(SPEC_RUNNER)
    else:
        out.append(RUNNER.replace("ARGV_MODE", f'"{mode}"').replace("ARGV_COUNT", count))

    dest = ROOT / (sys.argv[3] if len(sys.argv) > 3 else ".tools/harness.luau")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("".join(out), encoding="utf-8")
    print(dest)


main()
