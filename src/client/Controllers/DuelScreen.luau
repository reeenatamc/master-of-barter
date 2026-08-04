--!strict
--[[
	DuelScreen.luau -- the duel screen's brain. Knows WHAT to show and WHICH
	actions are legal right now. Knows nothing about how any of it looks.

	This module never touches an Instance. It takes the last DuelState plus the
	offer the player is drafting, and returns a plain table describing the
	screen: panels, rows, buttons, and whether each button is enabled.

	That boundary is the whole point of the card. E0 is an ugly, throwaway skin;
	E2 replaces it with the paper table. What E2 must NOT have to rewrite is the
	reasoning below -- when the accept button lights up, when the token is spent,
	what the rival is allowed to see. Same idea as Theme.luau, applied to the
	interface: evergreen logic, swappable skin. If a future skin needs a
	different shape of data, it changes ViewModel here once, not the rules.

	Being a pure function also means it is the one part of the UI that can be
	checked by reading, with no Studio involved.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelScreen = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- The contract between brain and skin
-- ─────────────────────────────────────────────────────────────────────────────

--- A hint about weight, not a colour. The skin decides what "primary" looks
--- like; naming a colour here would leak styling into the logic.
export type Tone = "plain" | "primary" | "danger" | "good" | "bad"

export type Button = {
	--- What gets reported back when it is pressed. See UIController.
	id: string,
	label: string,
	enabled: boolean,
	tone: Tone,
}

export type Row = {
	label: string,
	detail: string?,
	tone: Tone,
	buttons: { Button },
}

export type Panel = {
	title: string,
	rows: { Row },
}

export type ViewModel = {
	header: string,
	subheader: string,
	panels: { Panel },
	--- The negotiation bar. Always the same four, enabled or not, so the player
	--- learns where they live instead of watching buttons appear and vanish.
	actions: { Button },
}

--- What the player is assembling but has not sent yet. Lives on the client
--- only: the server sees it once, as a finished offer, and validates it there.
export type Draft = { Types.WrapRequest }

-- ─────────────────────────────────────────────────────────────────────────────

local UI = Strings.duelScreen

local function button(id: string, label: string, enabled: boolean, tone: Tone): Button
	return { id = id, label = label, enabled = enabled, tone = tone }
end

local function nameOf(itemId: Types.ItemId): string
	return Strings.itemNames[itemId] or itemId
end

local function valueOf(itemId: Types.ItemId): number
	local def = Items.catalog[itemId]
	return if def then def.baseValue else 0
end

--- Copies already committed to the draft, so the same one cannot be offered
--- twice. The server enforces this too; here it just keeps the button honest.
local function claimedCopies(draft: Draft): { [string]: boolean }
	local used: { [string]: boolean } = {}
	for _, wrap in draft do
		if wrap.copyId then
			used[wrap.copyId] = true
		end
	end
	return used
end

local function countFakes(draft: Draft): number
	local fakes = 0
	for _, wrap in draft do
		if wrap.isFake then
			fakes += 1
		end
	end
	return fakes
end

--- First copy of this item the player still has free, if any.
local function freeCopy(state: Types.DuelState, itemId: Types.ItemId, used: { [string]: boolean }): string?
	for _, copy in state.yourHand do
		if copy.itemId == itemId and not used[copy.copyId] then
			return copy.copyId
		end
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Panels
-- ─────────────────────────────────────────────────────────────────────────────

--- The catalogue, with a Real and a Fake button per item. Forging does not
--- consume a copy, so the Fake button does not need you to own one -- that
--- asymmetry IS the mechanic (docs/gdd.md §8), so the screen shows it plainly.
local function buildPickerPanel(state: Types.DuelState, draft: Draft): Panel
	local used = claimedCopies(draft)
	local fakes = countFakes(draft)
	local full = #draft >= DuelRules.limits.maxItemsPerOffer
	local fakesLeft = DuelRules.limits.fakesPerDuel - fakes

	local rows: { Row } = {}
	for _, itemId in Items.order do
		local copyId = freeCopy(state, itemId, used)

		table.insert(rows, {
			label = nameOf(itemId),
			detail = `{valueOf(itemId)}`,
			tone = "plain",
			buttons = {
				button(`real:{itemId}`, UI.offerReal, copyId ~= nil and not full, "plain"),
				button(`fake:{itemId}`, UI.offerFake, fakesLeft > 0 and not full, "danger"),
			},
		})
	end

	return { title = UI.yourHand, rows = rows }
end

--- What you have picked but not yet sent.
local function buildDraftPanel(draft: Draft): Panel
	local rows: { Row } = {}

	if #draft == 0 then
		table.insert(rows, { label = UI.emptyDraft, tone = "plain", buttons = {} })
	else
		for index, wrap in draft do
			table.insert(rows, {
				label = nameOf(wrap.claim),
				detail = if wrap.isFake then UI.fakeMark else UI.genuineMark,
				tone = if wrap.isFake then "danger" else "plain",
				buttons = { button(`drop:{index}`, "X", true, "plain") },
			})
		end
	end

	table.insert(rows, {
		label = "",
		tone = "plain",
		buttons = {
			button("clear", UI.clear, #draft > 0, "plain"),
			button("send", UI.send, #draft >= DuelRules.limits.minItemsPerOffer, "primary"),
		},
	})

	return { title = UI.yourOffer, rows = rows }
end

--- Your own offer once it is committed -- with the truth on it, because you
--- know what you wrapped.
local function buildOwnOfferPanel(state: Types.DuelState): Panel
	local rows: { Row } = {}
	-- Annotated: `x or {}` infers a union with the empty-table type, which is
	-- not iterable.
	local committed: { Types.WrappedItem } = state.yourOffer or {}
	for _, wrapped in committed do
		table.insert(rows, {
			label = nameOf(wrapped.claim),
			detail = if wrapped.isFake then UI.fakeMark else UI.genuineMark,
			tone = if wrapped.isFake then "danger" else "plain",
			buttons = {},
		})
	end
	return { title = UI.yourOffer, rows = rows }
end

--- The rival's side. Only what the server chose to send: a claim and how the
--- wrapper looks. There is nothing here to tell a forgery from a real item
--- except judgement, which is the game.
local function buildRivalPanel(state: Types.DuelState): Panel
	local rows: { Row } = {}

	for _, view in state.players do
		if view.slot ~= state.yourSlot then
			if view.offer then
				for _, wrapped in view.offer.wrapped do
					table.insert(rows, {
						label = nameOf(wrapped.claim),
						detail = string.format(
							"%.0f / %.0f / %.0f",
							wrapped.appearance.colorTone * 100,
							wrapped.appearance.seam * 100,
							wrapped.appearance.label * 100
						),
						tone = "plain",
						buttons = {},
					})
				end
			else
				table.insert(rows, { label = UI.nothingYet, tone = "plain", buttons = {} })
			end
		end
	end

	return { title = UI.theirOffer, rows = rows }
end

local function buildRevealPanel(reveal: Types.RevealResult, yourSlot: Types.Slot): Panel
	local rows: { Row } = {}

	local call = reveal.fakeCall
	if call then
		local who = if call.by == yourSlot then "→ " else ""
		local what = if call.correct then UI.calledRight else UI.calledWrong
		table.insert(rows, {
			label = `{who}slot {call.by} {what}`,
			tone = if call.correct then "good" else "bad",
			buttons = {},
		})
	end

	for _, side in reveal.sides do
		local mine = side.slot == yourSlot
		for _, wrapped in side.offered do
			table.insert(rows, {
				label = `{if mine then "→ " else ""}{nameOf(wrapped.claim)}`,
				detail = if wrapped.isFake then UI.wasFake else UI.wasReal,
				tone = if wrapped.isFake then "danger" else "plain",
				buttons = {},
			})
		end
		table.insert(rows, {
			label = string.format(UI.valueLine, side.valueReceived),
			detail = string.format(UI.fakesSlipped, side.fakesPassed),
			tone = "plain",
			buttons = {},
		})
	end

	local verdict = if reveal.winner == nil
		then UI.tie
		elseif reveal.winner == yourSlot then UI.youWin
		else UI.youLose
	local verdictTone: Tone = if reveal.winner == nil
		then "plain"
		elseif reveal.winner == yourSlot then "good"
		else "bad"

	table.insert(rows, { label = verdict, tone = verdictTone, buttons = {} })

	return { title = UI.reveal, rows = rows }
end

-- ─────────────────────────────────────────────────────────────────────────────

--- Every action always appears, enabled or not, so its place on screen is
--- learned once. A button that vanishes teaches nothing.
---
--- Enabling here is only about what to grey out. The server re-validates every
--- one of these, so a client that lies to itself gains nothing
--- (docs/arquitectura.md §4).
local function buildActions(state: Types.DuelState): { Button }
	local you = state.players[state.yourSlot]
	local negotiating = state.phase == "Negotiating"
	local yourTurn = negotiating and state.turn == state.yourSlot

	local labels = Strings.duelButtons
	return {
		button("accept", labels.accept, yourTurn, "primary"),
		button("decline", labels.decline, yourTurn, "plain"),
		button("raise", labels.raiseOffer, yourTurn and you ~= nil and you.raisesLeft > 0, "plain"),
		button("fakecall", labels.fakeCall, yourTurn and you ~= nil and not you.fakeCallUsed, "danger"),
	}
end

local function buildHeader(state: Types.DuelState): (string, string)
	if state.phase == "BuildingOffers" then
		local you = state.players[state.yourSlot]
		local waiting = you ~= nil and you.offer ~= nil
		return UI.buildYourOffer, if waiting then UI.waitingForRival else UI.buildYourOffer
	end

	if state.phase == "Reveal" then
		return UI.reveal, UI.duelOver
	end

	if state.phase == "Cancelled" or state.phase == "Results" then
		return UI.duelOver, ""
	end

	local yourTurn = state.turn == state.yourSlot
	local you = state.players[state.yourSlot]
	local detail = if you ~= nil then string.format(UI.raisesLeft, you.raisesLeft) else ""
	return (if yourTurn then UI.yourTurn else UI.theirTurn), detail
end

--- The whole screen, as data. Pure: same inputs, same output, no side effects.
function DuelScreen.build(state: Types.DuelState, draft: Draft): ViewModel
	local header, subheader = buildHeader(state)
	local panels: { Panel } = {}

	if state.reveal then
		table.insert(panels, buildRevealPanel(state.reveal, state.yourSlot))
	end

	table.insert(panels, buildRivalPanel(state))

	-- Before committing, the picker and the draft. After, the offer as it went.
	if state.phase == "BuildingOffers" and not state.yourOffer then
		table.insert(panels, buildDraftPanel(draft))
		table.insert(panels, buildPickerPanel(state, draft))
	elseif state.yourOffer then
		table.insert(panels, buildOwnOfferPanel(state))
	end

	return {
		header = header,
		subheader = subheader,
		panels = panels,
		actions = buildActions(state),
	}
end

return DuelScreen
