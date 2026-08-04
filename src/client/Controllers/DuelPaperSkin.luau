--!strict
--[[
	DuelPaperSkin.luau -- draws the duel onto the paper sheet standing on the
	table. Card E2, and the replacement for DuelSkin.

	Same contract as the ugly skin it replaces (DuelViewModel.Handle): it takes a
	view model and reports which button id was pressed. It knows nothing about
	forgeries, turns or why anything is disabled -- which is why swapping the
	whole look costs one file and leaves DuelScreen, DuelPanels and UIController
	untouched. That was the entire point of building E0 in two halves.

	Drawn with a SurfaceGui rather than a ScreenGui, and that is the difference
	between this and E0: the interface IS the sheet on the table, seen in the
	world, with the rival's avatar visible past it. docs/gdd.md §11 wants that
	framing for two reasons, and only one of them is thumbnails -- the other is
	that reading your opponent is part of the game.

	Each client draws only its OWN face of the sheet, chosen from its slot. The
	rival's view is never assembled here, so the golden rule holds in 3D the same
	way it holds in the payload: not by discipline, but because the other view
	does not exist on this machine.

	Layout follows the sheet, not a scroll: the rival's things at the far edge,
	yours at the near one, mirrored -- which is how a sheet between two people
	works when both are reading it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedStorage:WaitForChild("Shared")
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local DuelViewModel = require(script.Parent.DuelViewModel)
local SoundController = require(script.Parent.SoundController)

local DuelPaperSkin = {}

local TONE_COLORS: { [DuelViewModel.Tone]: Color3 } = {
	plain = Theme.palette.ink,
	primary = Theme.palette.accept,
	danger = Theme.palette.fakeCall,
	good = Theme.palette.good,
	bad = Theme.palette.bad,
}

--- Which sound each action makes. plan-etapas.md Etapa 2 raised juice to
--- required and applied it to EVERY meaningful action, not only the reveal: a
--- duel where only the ending moves is silent for ninety percent of its length.
local SOUND_FOR: { [string]: string } = {
	send = "offerSent",
	clear = "offerCleared",
	accept = "accept",
	decline = "decline",
	raise = "raise",
	fakecall = "fakeCall",
}

--- Every cut-out is rotated a little, and never all by the same amount.
--- docs/gdd.md §28: the imperfection is the aesthetic, not a defect. A grid of
--- perfectly aligned paper cards stops reading as paper immediately.
local function tiltFor(seed: number): number
	return ((seed % 5) - 2) * (Theme.tiltDegrees / 2)
end

local function corner(parent: Instance, scale: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(scale, 0)
	ui.Parent = parent
end

local function marker(text: string, size: UDim2, color: Color3): TextLabel
	local element = Instance.new("TextLabel")
	element.Size = size
	element.BackgroundTransparency = 1
	element.Text = text
	element.TextColor3 = color
	element.TextScaled = true
	element.Font = Theme.fonts.marker
	element.TextXAlignment = Enum.TextXAlignment.Center
	return element
end

local function handwriting(text: string, size: UDim2, color: Color3): TextLabel
	local element = marker(text, size, color)
	element.Font = Theme.fonts.hand
	element.TextXAlignment = Enum.TextXAlignment.Left
	return element
end

--- Faint squared ruling across the page. Drawn once and never touched again.
local function drawGrid(page: Frame)
	for index = 1, 11 do
		local line = Instance.new("Frame")
		line.Size = UDim2.fromScale(1, 0.002)
		line.Position = UDim2.fromScale(0, index / 12)
		line.BackgroundColor3 = Theme.palette.grid
		line.BorderSizePixel = 0
		line.ZIndex = 0
		line.Parent = page
	end
	for index = 1, 15 do
		local line = Instance.new("Frame")
		line.Size = UDim2.fromScale(0.0015, 1)
		line.Position = UDim2.fromScale(index / 16, 0)
		line.BackgroundColor3 = Theme.palette.grid
		line.BorderSizePixel = 0
		line.ZIndex = 0
		line.Parent = page
	end
end

--- Mounts onto a sheet part. `face` decides which side of the paper this client
--- reads, which is what makes the two views mirror each other.
function DuelPaperSkin.mount(
	parent: Instance,
	sheet: BasePart,
	face: Enum.NormalId,
	onAction: (id: string) -> ()
): DuelViewModel.Handle
	local trove = Trove.new()

	local surface = Instance.new("SurfaceGui")
	surface.Name = "DuelSheet"
	surface.Adornee = sheet
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = Theme.table.pixelsPerStud
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Lit like paper rather than like a screen: a glowing sheet is the fastest
	-- way to lose the whole aesthetic.
	surface.LightInfluence = 1
	surface.Parent = parent
	trove:Add(function()
		surface:Destroy()
	end)

	local page = Instance.new("Frame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundColor3 = Theme.palette.paper
	page.BorderSizePixel = 0
	page.Parent = surface
	drawGrid(page)

	--- Far edge of the sheet: whatever belongs to the rival.
	local farZone = Instance.new("Frame")
	farZone.Size = UDim2.fromScale(0.94, 0.3)
	farZone.Position = UDim2.fromScale(0.03, 0.03)
	farZone.BackgroundTransparency = 1
	farZone.Parent = page

	--- The middle: whose turn it is, and the reveal when it comes.
	local midZone = Instance.new("Frame")
	midZone.Size = UDim2.fromScale(0.94, 0.22)
	midZone.Position = UDim2.fromScale(0.03, 0.35)
	midZone.BackgroundTransparency = 1
	midZone.Parent = page

	--- Near edge: yours, within reach.
	local nearZone = Instance.new("Frame")
	nearZone.Size = UDim2.fromScale(0.94, 0.3)
	nearZone.Position = UDim2.fromScale(0.03, 0.58)
	nearZone.BackgroundTransparency = 1
	nearZone.Parent = page

	--- The three buttons, along the bottom edge. They are the visual signature
	--- of the game (§25), so they get the widest, closest strip of the page.
	local actionZone = Instance.new("Frame")
	actionZone.Size = UDim2.fromScale(0.94, 0.1)
	actionZone.Position = UDim2.fromScale(0.03, 0.89)
	actionZone.BackgroundTransparency = 1
	actionZone.Parent = page

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Padding = UDim.new(0.012, 0)
	actionLayout.Parent = actionZone

	local header = marker("", UDim2.fromScale(1, 0.4), Theme.palette.ink)
	header.Parent = midZone

	local subheader = marker("", UDim2.fromScale(1, 0.22), Theme.palette.inkSoft)
	subheader.Position = UDim2.fromScale(0, 0.42)
	subheader.Font = Theme.fonts.hand
	subheader.Parent = midZone

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	--- A taped cut-out. Everything on the page is one of these.
	local function cutout(spec: DuelViewModel.Button, size: UDim2, seed: number): TextButton
		local element = Instance.new("TextButton")
		element.Size = size
		element.BackgroundColor3 = if spec.enabled then Theme.palette.paper else Theme.palette.grid
		element.TextColor3 = if spec.enabled then TONE_COLORS[spec.tone] else Theme.palette.inkSoft
		element.Text = spec.label
		element.TextScaled = true
		element.Font = Theme.fonts.marker
		element.Rotation = tiltFor(seed)
		element.AutoButtonColor = spec.enabled
		element.Active = spec.enabled
		element.BorderSizePixel = 0
		corner(element, 0.12)

		local edge = Instance.new("UIStroke")
		edge.Color = TONE_COLORS[spec.tone]
		edge.Thickness = 2
		edge.Transparency = if spec.enabled then 0 else 0.6
		edge.Parent = element

		if spec.enabled then
			trove:Connect(element.Activated, function()
				-- The press itself answers, before the server has said anything.
				-- plan-etapas.md Etapa 2: every action reports immediately.
				TweenService:Create(element, TweenInfo.new(Theme.motion.snap), {
					Rotation = tiltFor(seed) + 4,
				}):Play()
				SoundController.play(SOUND_FOR[spec.id] or "offerPlaced")
				onAction(spec.id)
			end)
		end

		return element
	end

	--- One line of a panel: an object with its shape, or plain text.
	local function drawRow(container: Instance, row: DuelViewModel.Row, index: number, height: number): Frame
		local line = Instance.new("Frame")
		line.Size = UDim2.fromScale(1, height)
		line.Position = UDim2.fromScale(0, (index - 1) * height)
		line.BackgroundTransparency = 1
		line.Parent = container

		local textLeft = 0.01
		if row.itemId then
			local look = Theme.items[row.itemId] or Theme.defaultItem

			local blob = Instance.new("Frame")
			blob.Size = UDim2.fromScale(0.05, 0.72)
			blob.Position = UDim2.fromScale(0.01, 0.14)
			blob.BackgroundColor3 = look.color
			blob.BorderSizePixel = 0
			blob.Rotation = tiltFor(index * 3)
			blob.Parent = line
			corner(blob, look.corner)

			local square = Instance.new("UIAspectRatioConstraint")
			square.AspectRatio = 1
			square.Parent = blob

			local outline = Instance.new("UIStroke")
			outline.Color = Theme.palette.ink
			outline.Thickness = 2
			outline.Parent = blob

			textLeft = 0.08
		end

		local name = handwriting(row.label, UDim2.fromScale(0.42, 0.8), TONE_COLORS[row.tone])
		name.Position = UDim2.fromScale(textLeft, 0.1)
		name.Parent = line

		local detail = handwriting(row.detail or "", UDim2.fromScale(0.18, 0.6), Theme.palette.inkSoft)
		detail.Position = UDim2.fromScale(0.52, 0.2)
		detail.Parent = line

		local count = #row.buttons
		if count > 0 then
			local spread = count > 2
			local width = if spread then 0.96 / count else 0.14
			local origin = if spread then 0.02 else 0.7
			for slot, spec in row.buttons do
				local element = cutout(spec, UDim2.fromScale(width * 0.9, 0.74), index * 7 + slot)
				element.Position = UDim2.fromScale(origin + (slot - 1) * width, 0.13)
				element.Parent = line
			end
		end

		return line
	end

	--- The Revelación™ (docs/gdd.md §29, plan-etapas.md Etapa 4). One wrapper
	--- comes off at a time, because everything arriving at once is a list and
	--- everything arriving in order is a reveal.
	---
	--- Each row starts invisible and slightly off, then snaps into place on its
	--- own delay. Timings come from Theme: how fast a thing lands is part of how
	--- the game feels, and another theme may want another rhythm.
	local function revealRow(line: Frame, index: number)
		local target = line.Position
		line.Position = target + UDim2.fromScale(0, 0.04)

		for _, element in line:GetDescendants() do
			if element:IsA("TextLabel") or element:IsA("Frame") then
				(element :: any).Visible = false
			end
		end

		-- Registered in the trove, like every other timer this file starts: a
		-- duel that ends mid-reveal must not leave animations running.
		trove:Delay((index - 1) * Theme.motion.revealStagger, function()
			for _, element in line:GetDescendants() do
				if element:IsA("TextLabel") or element:IsA("Frame") then
					(element :: any).Visible = true
				end
			end
			TweenService:Create(line, TweenInfo.new(Theme.motion.place, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = target,
			}):Play()
			SoundController.play("revealTear")
		end)
	end

	local function drawPanel(container: Frame, panel: DuelViewModel.Panel)
		local title = handwriting(panel.title, UDim2.fromScale(1, 0.16), Theme.palette.inkSoft)
		title.Parent = container

		local rowHeight = 0.2
		for index, row in panel.rows do
			local line = drawRow(container, row, index + 1, rowHeight)
			if panel.kind == "reveal" then
				revealRow(line, index)
			end
		end
	end

	local function render(viewModel: DuelViewModel.ViewModel)
		header.Text = viewModel.header
		subheader.Text = viewModel.subheader

		clear(farZone)
		clear(midZone)
		clear(nearZone)
		clear(actionZone)

		-- Rebuilt because clear() removed them along with everything else.
		header.Parent = midZone
		subheader.Parent = midZone

		for _, panel in viewModel.panels do
			if panel.kind == "rival" then
				drawPanel(farZone, panel)
			elseif panel.kind == "reveal" then
				clear(midZone)
				drawPanel(midZone, panel)
			elseif panel.kind ~= "emotes" then
				drawPanel(nearZone, panel)
			end
		end

		for index, spec in viewModel.actions do
			local element = cutout(spec, UDim2.fromScale(0.22, 0.92), index * 11)
			element.LayoutOrder = index
			element.Parent = actionZone
		end
	end

	--- Reactions land big in the middle of the page: they are meant to be seen
	--- from the other side of the table.
	local flash = marker("", UDim2.fromScale(0.25, 0.18), Theme.palette.ink)
	flash.Position = UDim2.fromScale(0.375, 0.4)
	flash.Parent = page

	local flashGeneration = 0

	local function flashEmote(symbol: string, mine: boolean)
		SoundController.play("emote")
		flash.Text = symbol
		flash.Position = UDim2.fromScale(if mine then 0.55 else 0.2, 0.4)

		flashGeneration += 1
		local generation = flashGeneration
		trove:Delay(Theme.motion.emote, function()
			if flashGeneration == generation then
				flash.Text = ""
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

return DuelPaperSkin
