--!strict
--[[
	DuelSkin.luau -- draws a DuelViewModel.ViewModel. Knows nothing about duels.

	This is the throwaway half of card E0, and it is meant to be thrown away.
	It has no idea what a forgery is, whose turn it is, or why a button is
	disabled -- it renders panels, rows and buttons, and reports which id was
	pressed. Card E2 replaces this file with the paper table and does not touch
	DuelScreen.luau at all.

	Built in code rather than in the Studio editor on purpose: for a skin that
	exists to be deleted, hand-placing frames is effort spent on something with
	a known expiry date. E2 goes through the editor, because there the look is
	the point (docs/arquitectura.md §10).

	Ugly, but not sloppy about layout: everything is UDim2 scale plus layout
	constraints, never absolute pixels. Mobile is the primary platform
	(docs/gdd.md §5), and a play-test that hits layout bugs measures the layout
	instead of the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

ReplicatedStorage:WaitForChild("Shared")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local DuelViewModel = require(script.Parent.DuelViewModel)

local DuelSkin = {}

-- Placeholder palette. Card C2 moves anything worth keeping into Theme.luau;
-- none of this is worth keeping.
local COLORS: { [DuelViewModel.Tone]: Color3 } = {
	plain = Color3.fromRGB(70, 70, 78),
	primary = Color3.fromRGB(58, 108, 190),
	danger = Color3.fromRGB(168, 62, 62),
	good = Color3.fromRGB(52, 130, 78),
	bad = Color3.fromRGB(120, 52, 52),
}

local TEXT = Color3.fromRGB(238, 238, 238)
local DIM = Color3.fromRGB(150, 150, 156)

local function corner(parent: Instance, scale: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(scale, 0)
	ui.Parent = parent
end

--- Symbols for the keys likely to open the chat. Anything else falls back to
--- the enum name, which is ugly but always true.
local KEY_SYMBOLS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Slash] = "/",
	[Enum.KeyCode.Quote] = "'",
	[Enum.KeyCode.Semicolon] = ";",
	[Enum.KeyCode.Backquote] = "`",
}

--- Which key actually opens the chat, asked to the engine rather than assumed.
---
--- The chat input bar auto-hides and nothing exposed lets us pin it open, so
--- the only honest affordance is telling the player the exact key. Reading
--- KeyboardKeyCode means the hint stays true if Roblox changes the default or
--- if this place reconfigures it -- a hardcoded "/" would silently start lying.
local function chatKeyLabel(): string
	local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if not config then
		return "/"
	end

	local code = config.KeyboardKeyCode
	return KEY_SYMBOLS[code] or code.Name
end

local function label(text: string, size: UDim2, color: Color3, align: Enum.TextXAlignment): TextLabel
	local element = Instance.new("TextLabel")
	element.Size = size
	element.BackgroundTransparency = 1
	element.Text = text
	element.TextColor3 = color
	element.TextScaled = true
	element.TextXAlignment = align
	element.Font = Enum.Font.GothamMedium
	return element
end

--- Mounts the screen and returns the two things a caller needs: a way to draw a
--- view model, and a way to take it all down again.
---
--- `onAction` receives the id of whatever was pressed. The skin never decides
--- what an id means.
function DuelSkin.mount(parent: Instance, onAction: (id: string) -> ()): DuelViewModel.Handle
	local trove = Trove.new()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DuelScreenUgly"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	-- Sibling ordering, so ZIndex means what it looks like it means instead of
	-- being resolved per ancestor chain.
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parent
	trove:Add(function()
		screenGui:Destroy()
	end)

	-- Card E0.1: the top of the screen belongs to Roblox's chat, not to us.
	--
	-- The chat was never missing -- it renders above this ScreenGui and works
	-- fine. It just auto-hides, and a panel covering the whole screen meant
	-- nobody noticed they could talk. Both testers in the first session asked
	-- for exactly the thing that was already there.
	--
	-- No chat features of our own: the window, the filter and the moderation
	-- are Roblox's (TextChatService). This card is layout, nothing else.
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(0.94, 0.7)
	root.Position = UDim2.fromScale(0.5, 0.98)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	root.BorderSizePixel = 0
	root.Parent = screenGui
	corner(root, 0.02)

	local header = label("", UDim2.fromScale(1, 0.07), TEXT, Enum.TextXAlignment.Center)
	header.Position = UDim2.fromScale(0, 0.01)
	header.Parent = root

	local subheader = label("", UDim2.fromScale(1, 0.05), DIM, Enum.TextXAlignment.Center)
	subheader.Position = UDim2.fromScale(0, 0.09)
	subheader.Parent = root

	-- Pointing up at the chat, which lives above this panel now. The hint names
	-- the real key because the bar itself is invisible until it is opened, and
	-- an arrow pointing at empty sky helps nobody.
	local hintText = string.format(Strings.duelScreen.talkHint, chatKeyLabel())
	local talkHint = label(hintText, UDim2.fromScale(1, 0.045), DIM, Enum.TextXAlignment.Center)
	talkHint.Position = UDim2.fromScale(0, 0.145)
	talkHint.TextTransparency = 0.35
	talkHint.Parent = root

	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.fromScale(0.96, 0.62)
	body.Position = UDim2.fromScale(0.02, 0.2)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = root

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0.008, 0)
	bodyLayout.Parent = body

	local actionBar = Instance.new("Frame")
	actionBar.Size = UDim2.fromScale(0.96, 0.14)
	actionBar.Position = UDim2.fromScale(0.02, 0.84)
	actionBar.BackgroundTransparency = 1
	actionBar.Parent = root

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Padding = UDim.new(0.01, 0)
	actionLayout.Parent = actionBar

	local function makeButton(spec: DuelViewModel.Button, size: UDim2): TextButton
		local element = Instance.new("TextButton")
		element.Size = size
		element.BackgroundColor3 = COLORS[spec.tone]
		element.BackgroundTransparency = if spec.enabled then 0 else 0.65
		element.TextColor3 = if spec.enabled then TEXT else DIM
		element.Text = spec.label
		element.TextScaled = true
		element.Font = Enum.Font.GothamBold
		element.AutoButtonColor = spec.enabled
		element.Active = spec.enabled
		element.BorderSizePixel = 0
		corner(element, 0.2)

		if spec.enabled then
			-- Registered on the same trove as everything else, so a re-render
			-- cannot leave a connection behind on a destroyed button.
			trove:Connect(element.Activated, function()
				onAction(spec.id)
			end)
		end

		return element
	end

	local function clearChildren(container: Instance)
		for _, child in container:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	--- Everything lands as a flat list of rows directly under the scrolling
	--- frame, panels included.
	---
	--- The first attempt nested each panel in its own AutomaticSize frame and
	--- gave rows a scale height. That cannot work: a scale height inside a
	--- parent whose height is automatic is circular, the row collapses, and an
	--- aspect ratio constraint then shrinks its width to match. The result was
	--- a readable-in-theory screen rendered as a postage stamp.
	---
	--- Flat rows measure against the scrolling frame, which has a real
	--- scale-based height, so 6% of it is 6% of something. Still no absolute
	--- pixels anywhere.
	local function addRow(order: number, height: number): Frame
		local line = Instance.new("Frame")
		line.Size = UDim2.fromScale(1, height)
		line.BackgroundTransparency = 1
		line.LayoutOrder = order
		line.Parent = body
		return line
	end

	local function render(viewModel: DuelViewModel.ViewModel)
		header.Text = viewModel.header
		subheader.Text = viewModel.subheader

		clearChildren(body)
		clearChildren(actionBar)

		local order = 0
		for _, panel in viewModel.panels do
			order += 1
			local titleRow = addRow(order, 0.07)
			local title = label(panel.title, UDim2.fromScale(1, 1), DIM, Enum.TextXAlignment.Left)
			title.Font = Enum.Font.GothamBold
			title.Parent = titleRow

			for _, row in panel.rows do
				order += 1
				local line = addRow(order, 0.115)

				local strip = Instance.new("Frame")
				strip.Size = UDim2.fromScale(1, 1)
				strip.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
				strip.BorderSizePixel = 0
				strip.Parent = line
				corner(strip, 0.15)

				-- Card E0.2: when a row is about an object, draw the object.
				--
				-- The colour and the silhouette come from Theme, not from the
				-- view model: the brain said WHICH item, and how an item looks
				-- is the skin's business. Card E2 swaps the art without the
				-- logic noticing.
				local textLeft = 0.02
				if row.itemId then
					local swatch = Theme.items[row.itemId] or Theme.defaultItem

					local blob = Instance.new("Frame")
					blob.Size = UDim2.fromScale(0.06, 0.66)
					blob.Position = UDim2.fromScale(0.02, 0.17)
					blob.BackgroundColor3 = swatch.color
					blob.BorderSizePixel = 0
					blob.Parent = strip
					corner(blob, swatch.corner)

					-- Square regardless of how wide the screen is, so the
					-- silhouette stays a silhouette on a phone.
					local square = Instance.new("UIAspectRatioConstraint")
					square.AspectRatio = 1
					square.Parent = blob

					textLeft = 0.1
				end

				local name = label(row.label, UDim2.fromScale(0.42, 0.78), TEXT, Enum.TextXAlignment.Left)
				name.Position = UDim2.fromScale(textLeft, 0.11)
				name.TextColor3 = if row.tone == "plain" then TEXT else COLORS[row.tone]
				name.Parent = strip

				local detail = label(row.detail or "", UDim2.fromScale(0.18, 0.55), DIM, Enum.TextXAlignment.Left)
				detail.Position = UDim2.fromScale(0.53, 0.22)
				detail.Parent = strip

				-- Two buttons sit on the right of a labelled row; more than two
				-- means the row IS the buttons (the reaction bar), so they
				-- spread across the whole width instead of piling up off-screen.
				local count = #row.buttons
				local spread = count > 2
				local width = if spread then 0.94 / count else 0.15
				local origin = if spread then 0.03 else 0.68
				local gap = if spread then width else 0.16

				for index, spec in row.buttons do
					local element = makeButton(spec, UDim2.fromScale(width * 0.92, 0.72))
					element.Position = UDim2.fromScale(origin + (index - 1) * gap, 0.14)
					element.Parent = strip
				end
			end
		end

		for index, spec in viewModel.actions do
			local element = makeButton(spec, UDim2.fromScale(0.24, 0.9))
			element.LayoutOrder = index
			element.Parent = actionBar
		end
	end

	-- Two labels rather than one, so both sides can react at the same time
	-- without one reaction swallowing the other.
	local flashes = {
		[true] = label("", UDim2.fromScale(0.2, 0.09), TEXT, Enum.TextXAlignment.Center),
		[false] = label("", UDim2.fromScale(0.2, 0.09), TEXT, Enum.TextXAlignment.Center),
	}
	flashes[true].Position = UDim2.fromScale(0.55, 0.02)
	flashes[false].Position = UDim2.fromScale(0.25, 0.02)
	flashes[true].Parent = root
	flashes[false].Parent = root

	local flashGeneration = 0

	local function flashEmote(symbol: string, mine: boolean)
		local element = flashes[mine]
		element.Text = symbol

		flashGeneration += 1
		local generation = flashGeneration

		-- Registered in the trove like every other timer. A later reaction
		-- bumps the generation, so an older timer cannot blank out a newer
		-- emote (same trick as the phase watchdog).
		trove:Delay(2, function()
			if flashGeneration == generation then
				element.Text = ""
			end
		end)
	end

	return {
		render = render,
		flashEmote = flashEmote,
		destroy = function()
			trove:Clean()
		end,
	}
end

return DuelSkin
