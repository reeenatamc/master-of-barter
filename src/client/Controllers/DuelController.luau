--!strict
--[[
	DuelController.luau -- mirrors duel state, sends actions.

	This is a mirror, not a second copy of the rules. It never decides anything:
	it holds whatever the server last sent and asks for actions. Any number it
	shows comes from DuelState or from Config, and the server recalculates
	everything regardless (docs/arquitectura.md §4).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelController = {}

local current: Types.DuelState? = nil

function DuelController.getState(): Types.DuelState?
	return current
end

--- TEMP: there is no duel UI yet (card E2), so the state goes to Output.
--- Replaced by real rendering once the screens exist.
local function dump(state: Types.DuelState)
	print(`[Duel] {state.duelId}`)
	print(`  phase={state.phase} round={state.round} turn=slot{state.turn} you=slot{state.yourSlot}`)

	for _, view in state.players do
		local marker = if view.slot == state.yourSlot then " (you)" else ""
		print(`  slot{view.slot}: {view.displayName}{marker} -- {view.handCount} copies, {view.raisesLeft} raises left`)
	end

	print("  your hand:")
	for _, copy in state.yourHand do
		-- Fall back to the id so an item missing from Strings is visible
		-- instead of printing nil.
		local name = Strings.itemNames[copy.itemId] or copy.itemId
		print(`    {name}  [{copy.itemId}]`)
	end
end

function DuelController.start()
	Net.get(Net.names.DuelState).OnClientEvent:Connect(function(state: Types.DuelState)
		current = state
		dump(state)
	end)

	-- Asking to queue happens AFTER the handler above is connected. Otherwise
	-- the first DuelState could arrive with nobody listening, and a
	-- RemoteEvent fired at a client with no handler is simply lost.
	Net.get(Net.names.QueueJoin):FireServer()
end

return DuelController
