--!strict
--[[
	ShowcaseScreen.luau -- your shelf in the lobby, and the one place a player types.

	Card E3's last piece (P2).

	── THE PLACEMENT TEST (docs/decisiones.md) ─────────────────────────────────

	  1. juego o cromo?      CHROME.
	  2. fuera del duelo?    YES, and only there.
	  3. tapa al rival?      NO -- there is no rival in the lobby.
	  4. se toca?            YES, and it is TYPED IN, which no other screen is.

	Answer: a `ScreenGui`, same as the kiosk, with the same pixel floor on its
	targets. Question 4 came back stronger here than anywhere else, and that is
	what the whole moderation half of this card is about.

	── WHAT THIS SCREEN DOES NOT DO ────────────────────────────────────────────

	IT NEVER DISPLAYS WHAT YOU TYPED. The TextBox is an input, and the moment it
	is submitted the field is cleared and the shelf keeps showing whatever the
	SERVER last said the name is. So the text on screen has always been through
	TextService -- there is no frame, not even a single one, where raw text is
	rendered back to its author.

	That is not paranoia about one's own client. It is that "the name shown is
	always the filtered name" is a property worth having with no exceptions,
	because an exception is a code path, and a code path is something somebody
	can reach.

	── COLOUR ─────────────────────────────────────────────────────────────────

	None. The three negotiation buttons keep the monopoly (§28), so the shelf is
	ballpoint on paper and the item slips get their identity from the same
	`Theme.items` looks the duel board uses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Net = require(ReplicatedStorage.Shared.Util.Net)
local Showcase = require(ReplicatedStorage.Shared.Config.Showcase)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local ShowcaseScreen = {}

export type Handle = {
	render: (data: Types.PlayerDataView) -> (),
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

--- One shelf slot. Empty ones stay drawn, as a dashed outline: a shelf with
--- gaps says "there is more to win", and a shelf that shrinks to fit says
--- nothing at all.
local function buildSlot(index: number, parent: Instance): (Frame, TextLabel)
	local sheet = Instance.new("Frame")
	sheet.Size = UDim2.fromScale(0.2, 0.34)
	sheet.Position = UDim2.fromScale(0.06 + (index - 1) * 0.22, 0.42)
	sheet.BackgroundColor3 = Theme.palette.paper
	sheet.BorderSizePixel = 0
	sheet.Rotation = ((index % 3) - 1) * Theme.tiltDegrees
	sheet.Parent = parent

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.06, 0)
	round.Parent = sheet
	stroke(sheet, 2)

	local name = label("", Theme.fonts.hand)
	name.Size = UDim2.fromScale(0.86, 0.7)
	name.Position = UDim2.fromScale(0.07, 0.15)
	name.TextWrapped = true
	name.Parent = sheet

	return sheet, name
end

function ShowcaseScreen.mount(parent: Instance): Handle
	local trove = Trove.new()

	local gui = Instance.new("ScreenGui")
	gui.Name = "Showcase"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = parent
	trove:Add(function()
		gui:Destroy()
	end)

	local board = Instance.new("Frame")
	board.Size = UDim2.fromScale(0.8, 0.56)
	board.Position = UDim2.fromScale(0.1, 0.22)
	board.BackgroundColor3 = Theme.palette.paper
	board.BorderSizePixel = 0
	board.Parent = gui
	stroke(board, 3)

	--- The name the SERVER says is yours. Never what is in the box.
	local shownName = label("", Theme.fonts.marker)
	shownName.Size = UDim2.fromScale(0.88, 0.14)
	shownName.Position = UDim2.fromScale(0.06, 0.06)
	shownName.Parent = board

	local box = Instance.new("TextBox")
	box.Size = UDim2.fromScale(0.6, 0.11)
	box.Position = UDim2.fromScale(0.06, 0.24)
	box.BackgroundColor3 = Theme.palette.paper
	box.BorderSizePixel = 0
	box.Text = ""
	box.PlaceholderText = Strings.showcase.namePlaceholder
	box.TextColor3 = Theme.palette.ink
	box.TextScaled = true
	box.Font = Theme.fonts.hand
	box.ClearTextOnFocus = false
	-- The client's own bound, so an obviously-too-long name is stopped before it
	-- costs anybody a round trip. The SERVER checks the same bound and its
	-- answer is the one that counts -- this only means the refusal is not the
	-- first thing the player learns.
	box.Parent = board
	stroke(box, 2)

	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(0, Theme.minTouchPixels)
	floor.Parent = box

	local send = Instance.new("TextButton")
	send.Size = UDim2.fromScale(0.26, 0.11)
	send.Position = UDim2.fromScale(0.68, 0.24)
	send.BackgroundColor3 = Theme.palette.paper
	send.BorderSizePixel = 0
	send.Text = Strings.showcase.rename
	send.TextColor3 = Theme.palette.ink
	send.TextScaled = true
	send.Font = Theme.fonts.marker
	send.AutoButtonColor = false
	send.Parent = board
	stroke(send, 3)

	local sendRound = Instance.new("UICorner")
	sendRound.CornerRadius = UDim.new(0.25, 0)
	sendRound.Parent = send

	local sendFloor = Instance.new("UISizeConstraint")
	sendFloor.MinSize = Vector2.new(0, Theme.minTouchPixels)
	sendFloor.Parent = send

	local names: { TextLabel } = {}
	for index = 1, Showcase.slots do
		local _, name = buildSlot(index, board)
		names[index] = name
	end

	trove:Add(send.Activated:Connect(function()
		local typed = box.Text
		if #typed == 0 then
			return
		end
		Net.get(Net.names.ShowcaseSet):FireServer(typed, nil)
		-- Cleared IMMEDIATELY. What the player typed leaves the screen the
		-- instant it is sent, so the only name on display is the one the server
		-- sends back -- which has been through the filter.
		box.Text = ""
	end))

	return {
		render = function(data: Types.PlayerDataView)
			shownName.Text = if #data.showcase.name > 0
				then data.showcase.name
				else Strings.showcase.unnamed

			for index, name in names do
				local itemId = data.showcase.items[index]
				name.Text = if itemId then Strings.itemNames[itemId] or itemId else "—"
				name.TextTransparency = if itemId then 0 else 0.6
			end
		end,
		setVisible = function(visible: boolean)
			gui.Enabled = visible
			if not visible then
				box.Text = ""
			end
		end,
		destroy = function()
			trove:Clean()
		end,
	}
end

return ShowcaseScreen
