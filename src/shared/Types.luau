--!strict
--[[
	Types.luau -- shared Luau types (ItemId, OfferView, DuelState...)

	Ground rule from docs/arquitectura.md §4 and docs/gdd.md §39: the server is
	the only side that knows whether a wrapped item is real or fake. That is why
	the same thing has two types:

	  WrappedItem      -- the truth. Lives only inside DuelService tables.
	  WrappedItemView  -- what gets replicated. Has no isFake field at all.

	Keeping `isFake` off the view type is not a style choice: if it ever reaches
	the rival's client before the reveal, anyone can read it and win every duel.
	The type system is the cheapest place to enforce that.

	First cut, covering Etapa 1 (the duel prototype). Profile and economy types
	arrive with card B1, so they are deliberately missing here.
]]

local Types = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Items
-- ─────────────────────────────────────────────────────────────────────────────

export type ItemId = string

--- Three tiers, per docs/gdd.md §18. Display labels live in Config/Strings.
export type Rarity = "Common" | "Rare" | "Legendary"

export type ItemDef = {
	id: ItemId,
	rarity: Rarity,
	baseValue: number,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Wrapped items
-- ─────────────────────────────────────────────────────────────────────────────

--- The imperfection a fake carries. docs/gdd.md §37 requires clues to never be
--- distinguishable by colour alone, so every variant also changes shape or text.
export type VisualClue = "ColorTone" | "Seam" | "Typo"

--- Server-side truth for one wrapped item on the table. Never replicated.
export type WrappedItem = {
	wrappedId: string,
	itemId: ItemId,
	isFake: boolean,
	--- What the owner declares it to be. May be a lie.
	claim: ItemId,
	--- Precalculated by the server, so the client never derives them from isFake.
	visualClues: { VisualClue },
}

--- Safe to replicate: everything the rival is allowed to see.
export type WrappedItemView = {
	wrappedId: string,
	claim: ItemId,
	visualClues: { VisualClue },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Duel
-- ─────────────────────────────────────────────────────────────────────────────

--- Always 1 or 2. Luau has no numeric literal types, so this is a plain number
--- with the convention documented here.
export type Slot = number

--- docs/arquitectura.md §5.
export type DuelPhase = "Matchmaking" | "BuildingOffers" | "Negotiating" | "Reveal" | "Results" | "Cancelled"

--- The three negotiation buttons plus the accusation token.
export type DuelAction = "Accept" | "Decline" | "RaiseOffer" | "FakeCall"

export type OfferView = {
	from: Slot,
	wrapped: { WrappedItemView },
}

export type DuelPlayerView = {
	slot: Slot,
	userId: number,
	displayName: string,
	isBot: boolean,
	raisesLeft: number,
	fakeCallUsed: boolean,
	offer: OfferView?,
}

--- Built once per recipient: `yourSlot` differs, and so will the views once
--- inspection reveals things to one side only.
export type DuelState = {
	duelId: string,
	phase: DuelPhase,
	turn: Slot,
	--- Deadline in server time (workspace:GetServerTimeNow()), so clients can
	--- count down locally instead of needing a remote every second.
	deadline: number,
	yourSlot: Slot,
	--- Indexed by slot: players[1] and players[2].
	players: { DuelPlayerView },
}

return Types
