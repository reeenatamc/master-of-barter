--!strict
--[[
	Signal.luau -- a minimal event, for talking between services without
	wiring them to each other.

	docs/arquitectura.md §9: `DuelService` announces that a duel ended and
	`AnalyticsService` and `EconomyService` listen, without any of the three
	knowing the others exist. That is the whole job.

	Deliberately small, like Trove: connect, fire, disconnect. No once, no wait,
	no priorities. Every capability added here is surface that has to keep
	working forever, and nothing in the project needs those yet.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	connected: boolean,
	disconnect: (self: Connection) -> (),
}

--- Returns `...any` rather than `()` so that pcall's own return type carries
--- the error message. With a handler typed as returning nothing, `pcall` types
--- as returning only the boolean and the message is unreachable.
type Handler = (...any) -> ...any

type Fields = {
	_handlers: { Connection },
}

function Signal.new(): Signal
	return setmetatable({ _handlers = {} } :: Fields, Signal)
end

function Signal.connect(self: Signal, handler: Handler): Connection
	local list = self._handlers
	local connection

	connection = {
		connected = true,
		disconnect = function(link)
			if not link.connected then
				return
			end
			link.connected = false
			local index = table.find(list, connection)
			if index then
				table.remove(list, index)
			end
		end,
	}

	;(connection :: any)._handler = handler
	table.insert(list, connection)
	return connection
end

--- Calls every listener. A listener that errors is reported and skipped rather
--- than taking the rest down with it: one broken subscriber must not stop a
--- duel from ending.
---
--- Iterates a copy, so a handler that disconnects itself -- or connects another
--- -- cannot corrupt the loop it is running inside.
function Signal.fire(self: Signal, ...: any)
	for _, connection in table.clone(self._handlers) do
		if connection.connected then
			local handler = (connection :: any)._handler :: Handler
			local ok, err = pcall(handler, ...)
			if not ok then
				warn(`[Signal] a listener errored: {err}`)
			end
		end
	end
end

function Signal.disconnectAll(self: Signal)
	for _, connection in table.clone(self._handlers) do
		connection:disconnect()
	end
end

export type Signal = typeof(setmetatable({} :: Fields, Signal))

return Signal
