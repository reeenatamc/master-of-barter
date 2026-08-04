--!strict
--[[
	Trove.luau -- cleanup of connections and timers.

	Deliberately small. It knows exactly three things: RBXScriptConnections,
	threads (from task.delay / task.spawn), and plain cleanup functions. That is
	everything the project uses today.

	No reparenting, no promises, no instance management -- on purpose. Every
	extra capability is more surface for a silent bug to hide in, and a leak in
	the cleanup layer is the kind that shows up months later. When something new
	needs cleaning up, it gets added here together with its test.

	It also counts. Every registration adds one, every release subtracts one,
	and `Live()` reports what is left over. "Expected 0, got 3" is a bug you can
	fix; a leak you assumed was not there is one you find in production.
]]

export type Cleanable = RBXScriptConnection | thread | (() -> ())

local Trove = {}
Trove.__index = Trove

type Fields = {
	_items: { Cleanable },
	_registered: number,
	_released: number,
}

function Trove.new(): Trove
	return setmetatable({
		_items = {},
		_registered = 0,
		_released = 0,
	} :: Fields, Trove)
end

--- Registers something for later cleanup and returns it, so registration can
--- wrap creation in one statement instead of trailing it:
---     trove:Add(someSignal:Connect(handler))
function Trove.Add(self: Trove, item: Cleanable): Cleanable
	table.insert(self._items, item)
	self._registered += 1
	return item
end

function Trove.Connect(self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(handler)
	self:Add(connection)
	return connection
end

--- task.delay whose thread is registered in the same statement, so a timer can
--- never exist without its cleanup.
function Trove.Delay(self: Trove, seconds: number, callback: () -> ()): thread
	local thread = task.delay(seconds, callback)
	self:Add(thread)
	return thread
end

--- Releases everything. Safe to call more than once; the second call has
--- nothing left to release.
function Trove.Clean(self: Trove)
	-- Swap the list out first: a cleanup function that registers something new
	-- should not be cleaned by this same pass.
	local items = self._items
	self._items = {}

	local running = coroutine.running()

	for _, item in items do
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "thread" then
			-- Cancelling the thread we are currently inside would kill this
			-- very loop. It is already finishing, so drop it instead.
			if item ~= running then
				-- task.cancel throws on a thread that already ran to completion,
				-- which is the normal case for a timer that fired.
				pcall(task.cancel, item)
			end
		else
			item()
		end
		self._released += 1
	end
end

--- How many registered objects have not been released yet. Should be 0 after
--- Clean(). Anything else is a leak.
function Trove.Live(self: Trove): number
	return self._registered - self._released
end

export type Trove = typeof(setmetatable({} :: Fields, Trove))

return Trove
