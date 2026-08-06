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
	-- Genuinely deferred, not immediate: coalescing is a real behaviour (see
	-- PlayerDataService) and a stub that runs the callback inline would make a
	-- coalescing test pass for the wrong reason. Flushed by `advance(0)`.
	defer = function(fn, ...)
		local args = { ... }
		local co = coroutine.create(function()
			fn(table.unpack(args))
		end)
		table.insert(pending, { at = vnow, co = co, cancelled = false, done = false })
		return co
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

--- Roblox's moderation filter. The stub REFUSES by default -- see the spec: a
--- test environment that silently approves everything would make "fail closed"
--- pass without the code doing anything.
local filterBehaviour = "refuse"
local TextService = {
	FilterStringAsync = function(_self, text, _userId, _context)
		if filterBehaviour == "refuse" then
			error("harness: TextService refused")
		end
		return {
			GetNonChatStringForBroadcastAsync = function()
				return `[filtrado]{text}`
			end,
		}
	end,
}

local SERVICES_BY_NAME = {
	TextService = TextService,
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
