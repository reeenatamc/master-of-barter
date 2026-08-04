--!strict
--[[
	DuelViewModel.luau -- the contract between the duel screen's brain and skin.

	Nothing but types and one constructor. It lives in its own file because it
	is the thing card E2 has to honour: the brain (DuelScreen) produces this
	shape, the skin (DuelSkin, and later the paper table) consumes it, and
	neither knows anything else about the other.

	If a future skin genuinely needs a different shape, it changes here, once,
	and both sides are forced by the type checker to agree again.
]]

local DuelViewModel = {}

--- A hint about weight, never a colour. The skin decides what "primary" looks
--- like; naming a colour here would leak styling into the logic.
export type Tone = "plain" | "primary" | "danger" | "good" | "bad"

export type Button = {
	--- Reported back verbatim when pressed. Only UIController assigns meaning.
	id: string,
	label: string,
	enabled: boolean,
	tone: Tone,
}

export type Row = {
	label: string,
	detail: string?,
	tone: Tone,
	--- Which catalogue item this row is about, when it is about one.
	---
	--- Semantic, not visual: the brain says WHICH object, the skin decides how
	--- an object looks by asking Theme. Putting a colour here instead would put
	--- styling in the logic, and card E2 would have to rewrite the logic to
	--- restyle the game -- which is the exact thing this split exists to avoid.
	itemId: string?,
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
	--- The negotiation bar. Always the same four, enabled or not, so a player
	--- learns where they live. A button that vanishes teaches nothing.
	actions: { Button },
}

function DuelViewModel.button(id: string, label: string, enabled: boolean, tone: Tone): Button
	return { id = id, label = label, enabled = enabled, tone = tone }
end

return DuelViewModel
