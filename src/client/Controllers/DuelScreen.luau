--!strict
--[[
	DuelScreen.luau -- the duel screen's brain. Knows WHAT to show and WHICH
	actions are legal right now. Knows nothing about how any of it looks.

	This module never touches an Instance. It takes the last DuelState plus the
	offer the player is drafting, and returns a plain description of the screen
	(see DuelViewModel): panels, rows, buttons, and whether each is enabled.

	That boundary is the whole point of the card. E0 is an ugly, throwaway skin;
	E2 replaces it with the paper table. What E2 must NOT have to rewrite is the
	reasoning here -- when Accept lights up, when the token is spent, what the
	rival is allowed to see. Same idea as Theme.luau applied to the interface:
	evergreen logic, swappable skin.

	Being pure also makes it the one part of the UI verifiable by reading, with
	no Studio involved.

	Panel construction lives in DuelPanels; this file assembles them and owns
	the header and the action bar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelPanels = require(script.Parent.DuelPanels)
local DuelViewModel = require(script.Parent.DuelViewModel)

local DuelScreen = {}

export type Draft = DuelPanels.Draft
export type ViewModel = DuelViewModel.ViewModel

local UI = Strings.duelScreen
local button = DuelViewModel.button

--- Every action always appears, enabled or not, so its place is learned once.
---
--- Enabling here is only about what to grey out. The server re-validates every
--- one of these, so a client that lies to itself gains nothing
--- (docs/arquitectura.md §4).
local function buildActions(state: Types.DuelState): { DuelViewModel.Button }
	local you = state.players[state.yourSlot]
	local yourTurn = state.phase == "Negotiating" and state.turn == state.yourSlot
	local labels = Strings.duelButtons

	local actions = {
		button("accept", labels.accept, yourTurn, "primary"),
		button("decline", labels.decline, yourTurn, "plain"),
		button("raise", labels.raiseOffer, yourTurn and you ~= nil and you.raisesLeft > 0, "plain"),
	}

	-- With the token configured to zero the mechanic does not exist, so the
	-- button is absent rather than permanently greyed. A disabled button says
	-- "not now"; this needs to say "not in this game". Etapa 1 play-tests both
	-- configurations, and a leftover grey button would prompt questions about a
	-- rule the testers were never given.
	if DuelRules.limits.fakeCallsPerDuel > 0 then
		local left = if you ~= nil then you.fakeCallsLeft else 0
		table.insert(actions, button("fakecall", labels.fakeCall, yourTurn and left > 0, "danger"))
	end

	return actions
end

local function buildHeader(state: Types.DuelState): (string, string)
	local you = state.players[state.yourSlot]

	if state.phase == "BuildingOffers" then
		local committed = you ~= nil and you.offer ~= nil
		return UI.buildYourOffer, if committed then UI.waitingForRival else ""
	end

	if state.phase == "Reveal" then
		return UI.reveal, UI.duelOver
	end

	if state.phase == "Cancelled" or state.phase == "Results" then
		return UI.duelOver, ""
	end

	local yourTurn = state.turn == state.yourSlot
	local detail = if you ~= nil then string.format(UI.raisesLeft, you.raisesLeft) else ""
	return (if yourTurn then UI.yourTurn else UI.theirTurn), detail
end

--- The whole screen, as data. Pure: same inputs, same output, no side effects.
function DuelScreen.build(state: Types.DuelState, draft: Draft): ViewModel
	local header, subheader = buildHeader(state)
	local panels: { DuelViewModel.Panel } = {}

	if state.reveal then
		table.insert(panels, DuelPanels.reveal(state.reveal, state.yourSlot))
	end

	table.insert(panels, DuelPanels.rival(state))

	-- Reactions stay available the whole duel, including while waiting for the
	-- rival: the selling starts before the offer does.
	if state.phase ~= "Reveal" and state.phase ~= "Cancelled" then
		table.insert(panels, DuelPanels.emotes())
	end

	-- Before committing, the picker and the draft. Afterwards, the offer as it
	-- actually went out.
	if state.phase == "BuildingOffers" and not state.yourOffer then
		table.insert(panels, DuelPanels.draft(draft))
		table.insert(panels, DuelPanels.picker(state, draft))
	elseif state.yourOffer then
		table.insert(panels, DuelPanels.ownOffer(state))
	end

	return {
		header = header,
		subheader = subheader,
		panels = panels,
		actions = buildActions(state),
	}
end

return DuelScreen
