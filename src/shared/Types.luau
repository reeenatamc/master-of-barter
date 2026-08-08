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

--[=[
	@class Types

	Shared Luau types. The rule from docs/arquitectura.md §4 and docs/gdd.md §39
	is that the server is the only side that knows whether a wrapped item is real
	or fake, which is why the same thing has two types:

	- `WrappedItem` -- the truth. Lives only inside DuelService tables.
	- `WrappedItemView` -- what gets replicated. Has no `isFake` field at all.

	Keeping `isFake` off the view type is not a style choice: if it ever reaches
	the rival's client before the reveal, anyone can read it and win every duel.
	The type system is the cheapest place to enforce that.
]=]
local Types = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Items
-- ─────────────────────────────────────────────────────────────────────────────

export type ItemId = string

--[=[
	@type Rarity "Common" | "Rare" | "Legendary"
	@within Types

	Three tiers, per docs/gdd.md §18. Display labels live in Config/Strings.
]=]
export type Rarity = "Common" | "Rare" | "Legendary"

export type ItemDef = {
	id: ItemId,
	rarity: Rarity,
	baseValue: number,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Wrapped items
-- ─────────────────────────────────────────────────────────────────────────────

--[=[
	@interface DuelCopy
	@within Types
	.copyId string
	.itemId ItemId

	One object in a player's duel inventory: what they can put on the table.
	Copies are what gets bet; the permanent collection is never touched
	(docs/gdd.md §21, option A). A copy is always genuine -- forgeries do not
	exist until someone wraps one at offer time.
]=]
export type DuelCopy = {
	copyId: string,
	itemId: ItemId,
}

--[=[
	@interface WrapAppearance
	@within Types
	.colorTone number
	.seam number
	.label number

	How a wrapper looks, on the three dimensions docs/gdd.md §8 names: colour
	tone, seam regularity and label printing. 0 = flawless, 1 = obviously off.

	EVERY wrapper carries all three, genuine ones included. That is not
	decoration: if a genuine wrapper had an empty or absent appearance, the shape
	of the payload itself would announce which wrappers are forged, and `isFake`
	would have leaked through the back door. Forgeries are drawn from a higher
	band that overlaps the genuine one, so doubt is possible.

	docs/gdd.md §37: never distinguishable by colour alone, hence three
	dimensions and not one. Calibrating the bands is card A6.
]=]
export type WrapAppearance = {
	colorTone: number,
	seam: number,
	label: number,
}

--[=[
	@interface WrappedItem
	@within Types
	.wrappedId string
	.copyId string?
	.isFake boolean
	.claim ItemId
	.appearance WrapAppearance

	Server-side truth for one wrapped item on the table.

	Only ever replicated back to its OWN owner (they already know what they
	wrapped). The rival always receives [WrappedItemView] instead, which has no
	`isFake` field to leak in the first place.
]=]
export type WrappedItem = {
	wrappedId: string,
	--- The copy being risked, or nil when this is a forgery: forgeries are
	--- fabricated and consume nothing from the hand (model A, docs/gdd.md §8).
	copyId: string?,
	isFake: boolean,
	--- What the wrapper says it holds. For a genuine wrapper this equals the
	--- copy's own item; for a forgery it is the item being imitated.
	claim: ItemId,
	appearance: WrapAppearance,
}

--[=[
	@interface WrappedItemView
	@within Types
	.wrappedId string
	.claim ItemId
	.appearance WrapAppearance

	Safe to replicate to anyone: what the rival is allowed to see. Note what is
	absent -- there is nowhere here to put `isFake`, which is the point.
]=]
export type WrappedItemView = {
	wrappedId: string,
	claim: ItemId,
	appearance: WrapAppearance,
}

--[=[
	@interface WrapRequest
	@within Types
	.copyId string?
	.isFake boolean
	.claim ItemId

	What a client asks for when building an offer. Untrusted input: every field
	is validated server-side before anything is created from it.
]=]
export type WrapRequest = {
	--- nil means "forge it". Must agree with isFake; the server rejects a
	--- request where the two disagree.
	copyId: string?,
	isFake: boolean,
	claim: ItemId,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Duel
-- ─────────────────────────────────────────────────────────────────────────────

--[=[
	@type Slot number
	@within Types

	Always 1 or 2. Luau has no numeric literal types, so this is a plain number
	with the convention documented here.
]=]
export type Slot = number

--[=[
	@type DuelPhase "Matchmaking" | "BuildingOffers" | "Negotiating" | "Reveal" | "Results" | "Cancelled"
	@within Types

	The duel state machine, drawn in docs/arquitectura.md §5.
]=]
export type DuelPhase = "Matchmaking" | "BuildingOffers" | "Negotiating" | "Reveal" | "Results" | "Cancelled"

--[=[
	@type DuelAction "Accept" | "Decline" | "RaiseOffer" | "FakeCall"
	@within Types

	The three negotiation buttons plus the accusation token.
]=]
export type DuelAction = "Accept" | "Decline" | "RaiseOffer" | "FakeCall"

export type OfferView = {
	from: Slot,
	wrapped: { WrappedItemView },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Reveal
--
-- These are the only replicated types in the project that carry `isFake`, and
-- they exist for exactly one instant: when a duel enters Reveal. They are never
-- produced by the code that builds DuelPlayerView or OfferView -- those types
-- have nowhere to put the truth, which is precisely the point.
-- ─────────────────────────────────────────────────────────────────────────────

--[=[
	@interface RevealedWrap
	@within Types
	.wrappedId string
	.claim ItemId
	.isFake boolean

	What was really inside one wrapper. Along with [FakeCall], one of the only
	replicated shapes that carries `isFake`, and only from the Reveal phase on.
]=]
export type RevealedWrap = {
	wrappedId: string,
	claim: ItemId,
	isFake: boolean,
}

export type RevealSide = {
	slot: Slot,
	--- What this side put on the table, uncovered.
	offered: { RevealedWrap },
	--- What this side walks away with: the rival's wrappers.
	received: { RevealedWrap },
	--- Sum of baseValue over the genuine wrappers received. Forgeries count 0.
	valueReceived: number,
	--- Forgeries this side managed to pass to the rival.
	fakesPassed: number,
}

--[=[
	@interface FakeCall
	@within Types
	.by Slot
	.correct boolean

	An accusation, once per duel per side (docs/gdd.md §8).
]=]
export type FakeCall = {
	by: Slot,
	--- True when the accused offer really did contain at least one forgery.
	correct: boolean,
}

export type RevealResult = {
	--- Indexed by slot.
	sides: { RevealSide },
	--- nil means a tie.
	winner: Slot?,
	--- nil when the duel ended on a plain Accept, with nobody accusing.
	fakeCall: FakeCall?,
}

export type DuelPlayerView = {
	slot: Slot,
	--- What this side is CALLED. A human's account name; for a bot, the
	--- plausible name it was given (docs/gdd.md §34).
	---
	--- THERE IS NO `isBot` FIELD, AND THERE IS NO `userId`, ON PURPOSE. §34
	--- says a player gets no obvious signal that their rival is a bot, and a
	--- replicated boolean named `isBot` is the most obvious signal there is --
	--- one line of client inspection. `userId` is the same leak wearing a
	--- disguise: a bot has no account, so whatever went in that field (0, -1, a
	--- borrowed id) would be the tell.
	---
	--- Both existed here, `isBot` hardcoded to false and `userId` read by
	--- nobody, waiting for D1 to fill them in. Filling them in is the natural
	--- move and it is the wrong one. If the tutorial needs to announce Don
	--- Trueque, that is a fact about the TUTORIAL and travels with it -- not a
	--- general "your rival is fake" flag on every duel.
	displayName: string,
	--- Only how many copies the rival holds, never which ones. Knowing their
	--- hand would give away what they can honestly claim.
	handCount: number,
	raisesLeft: number,
	--- The rival spent a raise on this side, so it owes a bigger offer. Public
	--- to both players: everyone saw the raise happen.
	mustAmend: boolean,
	--- Accusations this side has left. A counter rather than a "used" flag so
	--- that DuelRules.limits.fakeCallsPerDuel actually governs it -- including
	--- the value 0, which turns the mechanic off entirely for a play-test.
	fakeCallsLeft: number,
	offer: OfferView?,
}

--[=[
	@interface DuelState
	@within Types
	.duelId string
	.phase DuelPhase
	.round number
	.turn Slot
	.deadline number
	.yourSlot Slot
	.yourHand { DuelCopy }
	.yourOffer { WrappedItem }?
	.players { DuelPlayerView }
	.reveal RevealResult?

	The whole duel as one recipient sees it. Built once per recipient:
	`yourSlot` differs, and so will the views once inspection reveals things to
	one side only.

	`reveal` is nil until the duel reaches the Reveal phase, which is what keeps
	the golden rule from lifting one instant early.
]=]
export type DuelState = {
	duelId: string,
	phase: DuelPhase,
	round: number,
	turn: Slot,
	--- Deadline in server time (workspace:GetServerTimeNow()), so clients can
	--- count down locally instead of needing a remote every second.
	deadline: number,
	yourSlot: Slot,
	--- Your own copies, in full. The rival's equivalent is only a count in
	--- their DuelPlayerView.
	yourHand: { DuelCopy },
	--- Your own offer, with the truth in it: you know which of your wrappers
	--- you forged. The rival's offer arrives as OfferView on their
	--- DuelPlayerView, and that type has nowhere to put `isFake`.
	yourOffer: { WrappedItem }?,
	--- Indexed by slot: players[1] and players[2].
	players: { DuelPlayerView },
	--- Only ever present once the duel has reached Reveal, and identical for
	--- both recipients. Until then it is nil, which is what keeps the golden
	--- rule from lifting one instant early.
	reveal: RevealResult?,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Profile
--
-- The saved shape, from docs/arquitectura.md §7, with the glossary's
-- translations. This is the ONLY table in the project that outlives a server,
-- so its fields are the ones that cannot be renamed casually: a field renamed
-- is a field that reads as missing on every existing save.
-- ─────────────────────────────────────────────────────────────────────────────

-- One copy sitting on a table. `duelId` is what makes an entry identifiable
-- later, which is the difference between a report and a shrug.
export type EscrowEntry = {
	itemId: ItemId,
	duelId: string,
	--- WHICH copy is on the table, not just which kind.
	---
	--- Not bookkeeping: `InventoryService.takeCopy` refuses a copyId that is
	--- already in here, which is what makes staking the same copy twice
	--- IMPOSSIBLE rather than merely absent from the current call path. The
	--- duplication exploit that motivated this got in by controlling the ORDER
	--- of a list; identity cannot be reordered.
	---
	--- Ephemeral by nature -- copyIds are minted per duel -- and that is fine:
	--- every escrow entry present when a profile loads is an orphan by
	--- definition and gets cleared. Entries saved before this field existed
	--- have no copyId, are never read for one, and are cleared the same way.
	copyId: string,
}

export type Stats = {
	duels: number,
	wins: number,
	fakesSlipped: number,
	fakesCaught: number,
}

--- Both inventories are counts per item, not lists of instances. Copies of one
--- object are interchangeable, so a count says everything a list would and
--- survives a DataStore round trip more cheaply.
--[=[
	@interface PlayerDataView
	@within Types
	.clips number
	.collection { [ItemId]: number }
	.duelCopies { [ItemId]: number }

	Your own profile, as your own client sees it. Sent to ONE recipient ever --
	its owner -- and never to a rival.

	NOTE WHAT IS ABSENT, because in this project that is where the design lives:

	- **`escrow`** is bookkeeping. Showing "3 copies in limbo" invites a support
	  question about a state that resolves itself a second later.
	- **`receipts`** is idempotency machinery for purchases. Nothing to draw.
	- **`botEarnings`** is the anti-farming counter, and replicating it would be
	  the `isBot` mistake again: a client that can read its daily bot-earnings
	  total can work out that filler opponents exist and exactly how much they
	  are worth. docs/gdd.md §34 says no obvious signals, and a number that only
	  moves against bots is as obvious as a label.

	Like `WrappedItemView`, this type is built field by field and never cloned
	from the profile -- so a field added to `Profile` cannot arrive here by
	accident, which is the whole point of it being a separate type.
]=]
export type PlayerDataView = {
	clips: number,
	collection: { [ItemId]: number },
	duelCopies: { [ItemId]: number },
	--- Already filtered, like everything about a showcase that leaves the
	--- server. Your own included: the raw string is never sent back, not even
	--- to whoever typed it.
	showcase: {
		name: string,
		items: { ItemId },
	},
}

export type Profile = {
	dataVersion: number,
	clips: number,
	level: number,
	xp: number,
	--- Permanent. Never decreases because of a duel (docs/gdd.md §21).
	collection: { [ItemId]: number },
	--- What can be staked, and the only thing a duel can take.
	duelCopies: { [ItemId]: number },
	cosmetics: {
		owned: { [string]: boolean },
		equipped: { [string]: string },
	},
	stats: Stats,
	quests: {
		date: string,
		progress: { [string]: number },
	},
	--- The public showcase in the lobby (docs/gdd.md §22, §32).
	---
	--- `name` is ALREADY FILTERED. What is stored is the output of
	--- TextService, never what the player typed -- so there is no raw
	--- user-written text anywhere in this profile, and no display path that
	--- could reach it by mistake. See ShowcaseService.
	---
	--- `items` are ids from the permanent collection. Ids, not copies: showing
	--- something off never risks it (§21).
	showcase: {
		name: string,
		items: { ItemId },
	},
	--- Total VALUE pulled out of filler opponents today: Clips won plus the
	--- baseValue of the copies received (card D1).
	---
	--- One number for both currencies, because a bot mints both. Its genuine
	--- wrappers come from nowhere (see DuelStakes), so capping only the Clips
	--- would leave the copies farmable by the same trick.
	---
	--- `date` is a UTC day string. A different day means the counter is stale,
	--- which is how it resets without a scheduled job anywhere.
	botEarnings: {
		date: string,
		value: number,
	},
	--- Ids of purchases already granted, for ProcessReceipt idempotency
	--- (docs/arquitectura.md §8). Written before the grant is acknowledged.
	receipts: { [string]: boolean },
	--- Copies currently ON A TABLE: taken out of `duelCopies` when the offer was
	--- made, not yet returned or handed over.
	---
	--- Recorded so that a loss is DETECTABLE rather than silent. If a server
	--- dies mid-duel these copies are gone -- that is the accepted failure,
	--- because returning them could duplicate instead -- but without this list,
	--- "lost to a crash" and "never had it" look identical, and two different
	--- failures must never share a symptom.
	---
	--- Entries found when a profile LOADS are orphans by definition: a live duel
	--- cannot outlive the session that held it. They are reported and cleared,
	--- never returned.
	escrow: { EscrowEntry },
}

-- What one side earned from a duel, handed to EconomyService as a single
-- payout rather than four separate credits that could half-apply.
export type DuelPayout = {
	result: "win" | "draw" | "loss",
	fakesSlipped: number,
	fakesCaught: number,
}

return Types
