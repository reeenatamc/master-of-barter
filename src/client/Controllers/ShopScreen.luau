--!strict
--[[
	ShopScreen.luau -- Don Trueque's kiosk.

	Card E3's other half. Four slots, a price on each, and a countdown to the
	next rotation.

	── THE PLACEMENT TEST (docs/decisiones.md) ─────────────────────────────────

	  1. juego o cromo?      CHROME. Buying is not the game; the duel is.
	  2. fuera del duelo?    YES, and only there -- the kiosk lives in the lobby
	                         and there is no paper board to draw it on.
	  3. tapa al rival?      NO. There is no rival while you shop.
	  4. se toca?            YES, and this is the one that made it a decision
	                         rather than a lookup.

	Answer: a `ScreenGui`, like the HUD -- but unlike the HUD it IS pressed, so
	it inherits the mobile accuracy problem that sent the negotiation buttons
	into world space. It does not follow them there, because the lobby has no
	board; it pays the debt instead with big targets and generous padding
	(`Theme.touchPadding`), which is what world space was buying in the first
	place.

	── THE COLOUR MONOPOLY ─────────────────────────────────────────────────────

	The three negotiation buttons are the game's only colour fills, and that is
	capital: it tells the player where you press without saying so. So BUY is
	not green. It earns its place with hierarchy instead -- the biggest thing on
	its slip, marker font, a heavier pen line -- and the whole kiosk stays
	ballpoint on paper (docs/gdd.md §28).

	── THE ANTI-SLOT-MACHINE, MADE VISIBLE ─────────────────────────────────────

	`gdd.md` §34 rules out anything that reads as gambling, and B4 answered it by
	seeding the rotation from the clock so every player everywhere sees the same
	four objects. That was true and INVISIBLE. Here it gets its face: the header
	says it out loud and a countdown shows when the stock turns over. A fairness
	property nobody can perceive does not do the work it was built for.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Kiosk = require(ReplicatedStorage.Shared.Util.Kiosk)
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local ShopScreen = {}

export type Handle = {
	render: (data: Types.PlayerDataView) -> (),
	--- Shown and hidden rather than rebuilt: the kiosk is chrome and belongs to
	--- the session, not to a visit.
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local function stroke(parent: Instance, thickness: number)
	local line = Instance.new("UIStroke")
	line.Color = Theme.palette.ink
	line.Thickness = thickness
	line.Parent = parent
end

local function label(content: string, font: Enum.Font): TextLabel
	local element = Instance.new("TextLabel")
	element.BackgroundTransparency = 1
	element.Text = content
	element.TextColor3 = Theme.palette.ink
	element.TextScaled = true
	element.Font = font
	return element
end

local function nameOf(itemId: Types.ItemId): string
	return Strings.itemNames[itemId] or itemId
end

--- mm:ss. The countdown is the whole point of §34 being visible, so it reads
--- like a clock and not like a number of seconds.
local function clockText(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

--- One slot: what it is, what it costs, and whether you can pay for it.
type Slot = {
	frame: Frame,
	title: TextLabel,
	price: TextLabel,
	reason: TextLabel,
	button: TextButton,
	itemId: Types.ItemId?,
}

local function buildSlot(index: number, parent: Instance): Slot
	local sheet = Instance.new("Frame")
	sheet.Size = UDim2.fromScale(0.22, 0.62)
	sheet.Position = UDim2.fromScale(0.03 + (index - 1) * 0.245, 0.24)
	sheet.BackgroundColor3 = Theme.palette.paper
	sheet.BorderSizePixel = 0
	-- Each slip sits a little crooked, and by a different amount. Nothing in
	-- this world was placed with a ruler (§28).
	sheet.Rotation = ((index % 3) - 1) * Theme.tiltDegrees
	sheet.Parent = parent

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.04, 0)
	round.Parent = sheet
	stroke(sheet, 2)

	local title = label("", Theme.fonts.hand)
	title.Size = UDim2.fromScale(0.86, 0.16)
	title.Position = UDim2.fromScale(0.07, 0.06)
	title.Parent = sheet

	local price = label("", Theme.fonts.marker)
	price.Size = UDim2.fromScale(0.86, 0.2)
	price.Position = UDim2.fromScale(0.07, 0.44)
	price.Parent = sheet

	-- WHY you cannot buy it, not merely that you cannot. A greyed button with
	-- no reason reads as a broken game; "te faltan 40" reads as a price.
	local reason = label("", Theme.fonts.hand)
	reason.Size = UDim2.fromScale(0.86, 0.1)
	reason.Position = UDim2.fromScale(0.07, 0.64)
	reason.Parent = sheet

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(0.8, 0.16)
	button.Position = UDim2.fromScale(0.1, 0.76)
	button.BackgroundColor3 = Theme.palette.paper
	button.BorderSizePixel = 0
	button.Text = Strings.kiosk.buy
	button.TextColor3 = Theme.palette.ink
	button.TextScaled = true
	button.Font = Theme.fonts.marker
	button.AutoButtonColor = false
	button.Parent = sheet

	local buttonRound = Instance.new("UICorner")
	buttonRound.CornerRadius = UDim.new(0.25, 0)
	buttonRound.Parent = button
	-- A heavier line than the slip's. This is the hierarchy that replaces the
	-- colour fill the three negotiation buttons have a monopoly on.
	stroke(button, 3)

	-- Finger room. The negotiation buttons bought their accuracy by living in
	-- world space, where the target can be bigger than the drawing; a flat
	-- button has no such trick, so it gets a floor instead. Scale-based sizing
	-- alone would shrink this to a smudge on a small phone.
	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(0, Theme.minTouchPixels)
	floor.Parent = button

	return {
		frame = sheet,
		title = title,
		price = price,
		reason = reason,
		button = button,
		itemId = nil,
	}
end

--- Builds the kiosk. `parent` is a PlayerGui.
function ShopScreen.mount(parent: Instance): Handle
	local trove = Trove.new()

	local gui = Instance.new("ScreenGui")
	gui.Name = "Kiosk"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = parent
	trove:Add(function()
		gui:Destroy()
	end)

	local board = Instance.new("Frame")
	board.Size = UDim2.fromScale(0.86, 0.6)
	board.Position = UDim2.fromScale(0.07, 0.2)
	board.BackgroundColor3 = Theme.palette.paper
	board.BorderSizePixel = 0
	board.Parent = gui
	stroke(board, 3)

	local title = label(Strings.kiosk.title, Theme.fonts.marker)
	title.Size = UDim2.fromScale(0.5, 0.1)
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = board

	-- §34 said out loud. The property was already true; this is what makes it
	-- perceivable, which is the half that was missing.
	local fairness = label(Strings.kiosk.sameForEveryone, Theme.fonts.hand)
	fairness.Size = UDim2.fromScale(0.5, 0.06)
	fairness.Position = UDim2.fromScale(0.04, 0.14)
	fairness.TextXAlignment = Enum.TextXAlignment.Left
	fairness.TextTransparency = 0.25
	fairness.Parent = board

	local countdown = label("", Theme.fonts.hand)
	countdown.Size = UDim2.fromScale(0.36, 0.08)
	countdown.Position = UDim2.fromScale(0.6, 0.06)
	countdown.TextXAlignment = Enum.TextXAlignment.Right
	countdown.Parent = board

	local slots: { Slot } = {}
	for index = 1, #Kiosk.stock() do
		slots[index] = buildSlot(index, board)
	end

	local latest: Types.PlayerDataView? = nil

	local function paint()
		local data = latest
		local stock = Kiosk.stock()

		for index, slot in slots do
			local itemId = stock[index]
			slot.itemId = itemId
			if not itemId then
				slot.frame.Visible = false
				continue
			end

			slot.frame.Visible = true
			slot.title.Text = nameOf(itemId)

			local price = Kiosk.priceOf(itemId) or 0
			slot.price.Text = `{price} {Strings.currencyName}`

			local clips = if data then data.clips else 0
			local owned = if data then data.duelCopies[itemId] or 0 else 0
			local short = price - clips

			if short > 0 then
				-- Disabled WITH a reason, the same rule the duel buttons follow
				-- for raisesLeft = 0 and a spent token. The server validates
				-- regardless; this only means the refusal is never the first
				-- news the player gets.
				slot.button.Active = false
				slot.button.TextTransparency = 0.55
				slot.reason.Text = (Strings.kiosk.shortBy :: string):gsub("{n}", tostring(short))
			else
				slot.button.Active = true
				slot.button.TextTransparency = 0
				slot.reason.Text = (Strings.kiosk.owned :: string):gsub("{n}", tostring(owned))
			end
		end
	end

	for _, slot in slots do
		trove:Add(slot.button.Activated:Connect(function()
			local itemId = slot.itemId
			-- `Active` is a hint, not a gate: the server re-checks stock, price
			-- and balance from scratch.
			if itemId and slot.button.Active then
				Net.get(Net.names.ShopBuy):FireServer(itemId)
			end
		end))
	end

	-- One second is plenty for a fifteen-minute countdown, and it keeps this off
	-- the per-frame budget entirely.
	trove:Add(task.spawn(function()
		while true do
			countdown.Text = (Strings.kiosk.rotatesIn :: string):gsub("{t}", clockText(Kiosk.secondsUntilRotation()))
			-- Repainted on the tick as well, so the stock turning over is seen
			-- rather than discovered on the next purchase attempt.
			paint()
			task.wait(1)
		end
	end))

	return {
		render = function(data: Types.PlayerDataView)
			latest = data
			paint()
		end,
		setVisible = function(visible: boolean)
			gui.Enabled = visible
		end,
		destroy = function()
			trove:Clean()
		end,
	}
end

return ShopScreen
