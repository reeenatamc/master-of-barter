--!strict
--[[
	UIController.luau -- mounts/unmounts screens according to state.

	Sits between the brain (DuelScreen, what to show) and the skin (DuelSkin,
	how to draw it), and owns the one piece of state neither of them should:
	the offer the player is assembling but has not sent.

	That draft is client-only and deliberately unauthoritative. It exists so the
	screen has something to display while you decide; the server sees it once,
	as a finished offer, and validates it from scratch (docs/arquitectura.md §4).
	Nothing here decides anything the server will not re-decide.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelController = require(script.Parent.DuelController)
local DuelScreen = require(script.Parent.DuelScreen)
local DuelSkin = require(script.Parent.DuelSkin)

local UIController = {}

local draft: DuelScreen.Draft = {}
local handle: DuelSkin.Handle? = nil

--- Repaints from whatever the controller last received. Called after a state
--- arrives and after any local edit to the draft, so both kinds of change take
--- the same single path.
local function refresh()
	local screen = handle
	local state = DuelController.getState()
	if not screen or not state then
		return
	end
	screen.render(DuelScreen.build(state, draft))
end

--- Adds a genuine wrapper holding a copy the player actually owns and has not
--- already committed to this draft.
local function addGenuine(itemId: Types.ItemId)
	local state = DuelController.getState()
	if not state then
		return
	end

	local used: { [string]: boolean } = {}
	for _, wrap in draft do
		if wrap.copyId then
			used[wrap.copyId] = true
		end
	end

	for _, copy in state.yourHand do
		if copy.itemId == itemId and not used[copy.copyId] then
			table.insert(draft, { copyId = copy.copyId, isFake = false, claim = itemId })
			return
		end
	end
end

--- Adds a forgery imitating an item. Consumes nothing from the hand: that is
--- the whole point of forging (docs/gdd.md §8, model A).
local function addForgery(itemId: Types.ItemId)
	table.insert(draft, { isFake = true, claim = itemId })
end

--- Turns a button id into something that happens. The skin reports ids and
--- knows nothing beyond that; this is the only place an id means anything.
local function handleAction(id: string)
	local kind, argument = string.match(id, "^(%a+):(.+)$")

	if kind == "real" and argument then
		addGenuine(argument)
	elseif kind == "fake" and argument then
		addForgery(argument)
	elseif kind == "drop" and argument then
		local index = tonumber(argument)
		if index then
			table.remove(draft, index)
		end
	elseif id == "clear" then
		table.clear(draft)
	elseif id == "send" then
		DuelController.offer(draft)
		-- Deliberately not cleared here. The draft clears when the server
		-- confirms by sending back a state that carries the offer, so a
		-- rejected offer stays on screen instead of vanishing silently.
		return
	elseif id == "accept" then
		DuelController.accept()
		return
	elseif id == "decline" then
		DuelController.decline()
		return
	elseif id == "raise" then
		DuelController.raise()
		return
	elseif id == "fakecall" then
		DuelController.fakeCall()
		return
	end

	refresh()
end

--- Called whenever the server sends a new duel state.
local function onDuelState(state: Types.DuelState)
	-- Once the offer is committed, the draft has served its purpose.
	if state.yourOffer then
		table.clear(draft)
	end
	refresh()
end

function UIController.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	handle = DuelSkin.mount(playerGui, handleAction)
	DuelController.onStateChanged(onDuelState)

	-- The debug keys stay while diagnostics are on, but every one of them maps
	-- to a button that also exists on screen. Nothing is reachable by keyboard
	-- alone, so removing the keys in E2 cannot orphan an action.
	if DuelRules.debugLogs then
		print("[UI] duel screen mounted (ugly skin, card E0)")
	end
end

return UIController
