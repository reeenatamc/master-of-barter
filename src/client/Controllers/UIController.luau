--!strict
--[[
	UIController.luau -- mounts/unmounts screens according to state.

	Sits between the brain (DuelScreen, what to show) and whichever skin is
	active (how to draw it), and owns the one piece of state neither should: the
	offer the player is assembling but has not sent.

	That draft is client-only and deliberately unauthoritative. It exists so the
	screen has something to display while you decide; the server sees it once,
	as a finished offer, and validates it from scratch (docs/arquitectura.md §4).
	Nothing here decides anything the server will not re-decide.

	Two skins answer to the same contract: the paper board lying on the table
	(card E2) and the flat panel from E0, kept alive as a fallback until the
	mobile test approves pressing buttons in world space. `Theme.screen` picks
	between them, and nothing else in this file knows which is running -- that is
	what the contract bought.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelCamera = require(script.Parent.DuelCamera)
local DuelController = require(script.Parent.DuelController)
local DuelPaperSkin = require(script.Parent.DuelPaperSkin)
local DuelScreen = require(script.Parent.DuelScreen)
local DuelSkin = require(script.Parent.DuelSkin)
local DuelViewModel = require(script.Parent.DuelViewModel)
local HudScreen = require(script.Parent.HudScreen)

local UIController = {}

local draft: DuelScreen.Draft = {}
local handle: DuelViewModel.Handle? = nil
--- Everything the current duel's screen owns. Cleaned when the duel changes or
--- ends, by every route -- the same discipline as the server's per-duel trove.
local sceneTrove: Trove.Trove? = nil
local mountedDuelId: string? = nil

local function refresh()
	local screen = handle
	local state = DuelController.getState()
	if not screen or not state then
		return
	end
	screen.render(DuelScreen.build(state, draft))
end

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

--- Turns a button id into something that happens. Skins report ids and know
--- nothing beyond that; this is the only place an id means anything.
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
	elseif kind == "emote" and argument then
		DuelController.emote(argument)
		return
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

local function teardown()
	local screen = handle
	if screen then
		screen.destroy()
	end
	handle = nil

	local trove = sceneTrove
	if trove then
		trove:Clean()
	end
	sceneTrove = nil
	mountedDuelId = nil
end

--- The board lies flat and has one top face, so both players draw on the same
--- side of it -- each on their own local surface, seeing only theirs. Slot 2
--- reads the board upside down from where they stand, so their page is turned
--- around and "near" is near for both.
---
--- Derived from the same rule DuelSceneService uses to place them, which is why
--- neither has to tell the other.
local function flippedFor(slot: Types.Slot): boolean
	return slot ~= 1
end

local function mountFlat(playerGui: Instance)
	handle = DuelSkin.mount(playerGui, handleAction)
	refresh()
end

--- Puts the duel on the paper board lying on the table. Yields until the board
--- has replicated, which is why it runs in its own thread.
local function mountPaper(playerGui: Instance, state: Types.DuelState)
	local model = workspace:WaitForChild(`Duel_{state.duelId}`, 10)
	local sheet = if model then model:WaitForChild("Board", 5) else nil

	if not sheet or not sheet:IsA("BasePart") then
		-- Falling back rather than failing: a player with no screen at all
		-- cannot even tell you what went wrong.
		warn("[UI] the duel board never arrived; using the flat screen instead")
		mountFlat(playerGui)
		return
	end

	local trove = Trove.new()
	sceneTrove = trove

	handle = DuelPaperSkin.mount(playerGui, sheet, flippedFor(state.yourSlot), handleAction)
	DuelCamera.focus(sheet, state.yourSlot)
	trove:Add(DuelCamera.release)

	-- The server tears the table down when the duel ends, by any route. Handing
	-- the camera back has to follow it: a scriptable camera outliving its
	-- subject leaves the player staring at nothing.
	trove:Connect(sheet.Destroying, teardown)

	refresh()
end

--- Called whenever the server sends a new duel state.
local function onDuelState(state: Types.DuelState)
	if state.yourOffer then
		table.clear(draft)
	end

	if mountedDuelId ~= state.duelId then
		teardown()
		mountedDuelId = state.duelId
		table.clear(draft)

		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		if Theme.screen == "table" then
			task.spawn(mountPaper, playerGui, state)
			return
		end

		mountFlat(playerGui)
	end

	refresh()
end

function UIController.start()
	-- The HUD is mounted ONCE and never taken down: it is chrome, so it outlives
	-- every duel. That is why it is not in the per-duel trove -- putting it there
	-- would erase your Clips the moment a duel ended.
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hud = HudScreen.mount(playerGui)
	DuelController.onPlayerData(hud.render)

	DuelController.onStateChanged(onDuelState)

	DuelController.onEmote(function(slot: Types.Slot, emoteId: string)
		local screen = handle
		local state = DuelController.getState()
		if screen and state then
			screen.flashEmote(Strings.emoteSymbols[emoteId] or "?", slot == state.yourSlot)
		end
	end)

	if DuelRules.debugLogs then
		print(`[UI] ready, screen = {Theme.screen}`)
	end
end

return UIController
