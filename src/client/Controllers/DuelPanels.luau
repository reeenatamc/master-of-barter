--!strict
--[[
	DuelPanels.luau -- builds each panel of the duel screen as plain data.

	Split out of DuelScreen to keep both under the 300-line rule. Same nature as
	its parent: pure functions, no Instances, no side effects. Every function
	here takes state and returns a Panel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelViewModel = require(script.Parent.DuelViewModel)

type Panel = DuelViewModel.Panel
type Row = DuelViewModel.Row
type Tone = DuelViewModel.Tone

--- What the player is assembling but has not sent. Client-only and
--- unauthoritative: the server sees it once, finished, and validates it fresh.
export type Draft = { Types.WrapRequest }

local DuelPanels = {}

local UI = Strings.duelScreen
local button = DuelViewModel.button

local function nameOf(itemId: Types.ItemId): string
	return Strings.itemNames[itemId] or itemId
end

local function valueOf(itemId: Types.ItemId): number
	local def = Items.catalog[itemId]
	return if def then def.baseValue else 0
end

--- Copies already committed to the draft, so the same one cannot be offered
--- twice. The server enforces this as well; here it only keeps a button honest.
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

local function freeCopy(state: Types.DuelState, itemId: Types.ItemId, used: { [string]: boolean }): string?
	for _, copy in state.yourHand do
		if copy.itemId == itemId and not used[copy.copyId] then
			return copy.copyId
		end
	end
	return nil
end

--- The catalogue, with a Real and a Fake button per item.
---
--- Forging consumes no copy, so the Fake button does not require owning one.
--- That asymmetry IS the mechanic (docs/gdd.md §8), so the screen states it
--- plainly rather than hiding it behind a rule the player has to infer.
function DuelPanels.picker(state: Types.DuelState, draft: Draft): Panel
	local used = claimedCopies(draft)
	local full = #draft >= DuelRules.limits.maxItemsPerOffer
	local fakesLeft = DuelRules.limits.fakesPerDuel - countFakes(draft)

	local rows: { Row } = {}
	for _, itemId in Items.order do
		local copyId = freeCopy(state, itemId, used)
		table.insert(rows, {
			label = nameOf(itemId),
			detail = `{valueOf(itemId)}`,
			tone = "plain" :: Tone,
			buttons = {
				button(`real:{itemId}`, UI.offerReal, copyId ~= nil and not full, "plain"),
				button(`fake:{itemId}`, UI.offerFake, fakesLeft > 0 and not full, "danger"),
			},
		})
	end

	return { title = UI.yourHand, rows = rows }
end

--- What has been picked but not yet sent.
function DuelPanels.draft(draft: Draft): Panel
	local rows: { Row } = {}

	if #draft == 0 then
		table.insert(rows, { label = UI.emptyDraft, tone = "plain" :: Tone, buttons = {} })
	else
		for index, wrap in draft do
			table.insert(rows, {
				label = nameOf(wrap.claim),
				detail = if wrap.isFake then UI.fakeMark else UI.genuineMark,
				tone = (if wrap.isFake then "danger" else "plain") :: Tone,
				buttons = { button(`drop:{index}`, "X", true, "plain") },
			})
		end
	end

	table.insert(rows, {
		label = "",
		tone = "plain" :: Tone,
		buttons = {
			button("clear", UI.clear, #draft > 0, "plain"),
			button("send", UI.send, #draft >= DuelRules.limits.minItemsPerOffer, "primary"),
		},
	})

	return { title = UI.yourOffer, rows = rows }
end

--- Your own committed offer, with the truth on it: you know what you wrapped.
function DuelPanels.ownOffer(state: Types.DuelState): Panel
	local rows: { Row } = {}
	local committed: { Types.WrappedItem } = state.yourOffer or {}

	for _, wrapped in committed do
		table.insert(rows, {
			label = nameOf(wrapped.claim),
			detail = if wrapped.isFake then UI.fakeMark else UI.genuineMark,
			tone = (if wrapped.isFake then "danger" else "plain") :: Tone,
			buttons = {},
		})
	end

	return { title = UI.yourOffer, rows = rows }
end

--- The rival's side: only what the server chose to send, a claim and how the
--- wrapper looks. Nothing here separates a forgery from a real item except
--- judgement, which is the game.
function DuelPanels.rival(state: Types.DuelState): Panel
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
						tone = "plain" :: Tone,
						buttons = {},
					})
				end
			else
				table.insert(rows, { label = UI.nothingYet, tone = "plain" :: Tone, buttons = {} })
			end
		end
	end

	return { title = UI.theirOffer, rows = rows }
end

--- The reaction bar. Ordinary buttons carrying ordinary ids, so the skin needs
--- no new concept to draw them and UIController no new branch to route them.
function DuelPanels.emotes(): Panel
	local buttons = {}
	for _, id in DuelRules.emotes do
		table.insert(buttons, button(`emote:{id}`, Strings.emoteSymbols[id] or "?", true, "plain"))
	end

	return {
		title = UI.emotes,
		rows = { { label = "", tone = "plain" :: Tone, buttons = buttons } },
	}
end

function DuelPanels.reveal(reveal: Types.RevealResult, yourSlot: Types.Slot): Panel
	local rows: { Row } = {}

	local call = reveal.fakeCall
	if call then
		local mark = if call.by == yourSlot then "→ " else ""
		local what = if call.correct then UI.calledRight else UI.calledWrong
		table.insert(rows, {
			label = `{mark}slot {call.by} {what}`,
			tone = (if call.correct then "good" else "bad") :: Tone,
			buttons = {},
		})
	end

	for _, side in reveal.sides do
		local mark = if side.slot == yourSlot then "→ " else ""
		for _, wrapped in side.offered do
			table.insert(rows, {
				label = `{mark}{nameOf(wrapped.claim)}`,
				detail = if wrapped.isFake then UI.wasFake else UI.wasReal,
				tone = (if wrapped.isFake then "danger" else "plain") :: Tone,
				buttons = {},
			})
		end
		table.insert(rows, {
			label = string.format(UI.valueLine, side.valueReceived),
			detail = string.format(UI.fakesSlipped, side.fakesPassed),
			tone = "plain" :: Tone,
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

return DuelPanels
