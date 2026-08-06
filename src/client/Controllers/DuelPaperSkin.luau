--!strict
--[[
	DuelPaperSkin.luau -- draws the duel onto the paper board lying on the table.
	Card E2, and the replacement for DuelSkin.

	Same contract as the ugly skin it replaces (DuelViewModel.Handle): it takes a
	view model and reports which button id was pressed. It knows nothing about
	forgeries, turns or why anything is disabled -- which is why the entire look
	could be rebuilt twice, once for the paper theme and once again when the
	board turned out to lie flat, without DuelScreen or DuelPanels changing.

	Laid out against the reference images (mockups/), far edge to near:

	    rival's three buttons     small, outline only, not yours to press
	    rival's slots             dashed boxes with whatever they offered
	    the dashed net            the middle of the board
	    your slots                dashed boxes, or the catalogue while choosing
	    your three buttons        large and filled -- red, green, blue

	ONE BOARD, TWO READERS. The board has a single top face, and each client
	draws its own local SurfaceGui on it, seeing only that one. Slot 2's page is
	rotated 180 so "near" is near for both. The rival's view is never assembled
	on this machine, so the golden rule holds in 3D the way it holds in the
	payload: not by discipline, but by absence.

	docs/gdd.md §28: one ballpoint pen drew this world. Every line here is
	Theme.palette.ink; the only colour fills are the three negotiation buttons,
	which are the exception because they matter most.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedStorage:WaitForChild("Shared")
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local DuelViewModel = require(script.Parent.DuelViewModel)
local SoundController = require(script.Parent.SoundController)

local DuelPaperSkin = {}

--- Which sound each action makes. plan-etapas.md Etapa 2 applied juice to EVERY
--- meaningful action, not only the reveal: a duel where only the ending moves
--- is silent for ninety percent of its length.
local SOUND_FOR: { [string]: string } = {
	send = "offerSent",
	clear = "offerCleared",
	accept = "accept",
	decline = "decline",
	raise = "raise",
	fakecall = "fakeCall",
}

--- The three negotiation buttons are the only filled colour on the board.
local FILL_FOR: { [string]: { line: Color3, fill: Color3 } } = {
	accept = { line = Theme.palette.accept, fill = Theme.palette.acceptFill },
	decline = { line = Theme.palette.decline, fill = Theme.palette.declineFill },
	raise = { line = Theme.palette.raise, fill = Theme.palette.raiseFill },
	fakecall = { line = Theme.palette.fakeCall, fill = Theme.palette.fakeCallFill },
}

--- Nothing on this board is perfectly straight. docs/gdd.md §28: the
--- imperfection is the aesthetic, not a defect.
local function tiltFor(seed: number): number
	return ((seed % 5) - 2) * (Theme.tiltDegrees / 2)
end

local function corner(parent: Instance, scale: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(scale, 0)
	ui.Parent = parent
end

--- A pen line. Everything drawn on this board goes through here, which is how
--- the one-pen rule stays true by construction rather than by memory.
local function stroke(parent: Instance, thickness: number, transparency: number?)
	local line = Instance.new("UIStroke")
	line.Color = Theme.palette.ink
	line.Thickness = thickness
	line.Transparency = transparency or 0
	line.Parent = parent
end

local function text(content: string, size: UDim2, color: Color3, font: Enum.Font): TextLabel
	local element = Instance.new("TextLabel")
	element.Size = size
	element.BackgroundTransparency = 1
	element.Text = content
	element.TextColor3 = color
	element.TextScaled = true
	element.Font = font
	element.Parent = nil
	return element
end

--- Mounts onto the board. `flip` turns the whole page around for the player on
--- the far side, so each reads their own half as the near one.
function DuelPaperSkin.mount(
	parent: Instance,
	board: BasePart,
	flip: boolean,
	onAction: (id: string) -> ()
): DuelViewModel.Handle
	local trove = Trove.new()

	local surface = Instance.new("SurfaceGui")
	surface.Name = "DuelBoard"
	surface.Adornee = board
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = Theme.table.pixelsPerStud
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Lit like paper, not like a screen. A glowing board is the fastest way to
	-- lose the whole aesthetic.
	surface.LightInfluence = 1
	surface.Parent = parent
	trove:Add(function()
		surface:Destroy()
	end)

	local page = Instance.new("Frame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundColor3 = Theme.palette.paper
	page.BorderSizePixel = 0
	page.Rotation = if flip then 180 else 0
	page.Parent = surface

	-- BARE ON PURPOSE (2026-08-05). The grid, the drawn border and the net came
	-- out, leaving a plain pad with the buttons on it -- Renata's reference, and
	-- an explicit "for now": the board is being redesigned and decoration added
	-- before the design exists is decoration thrown away twice.
	--
	-- The ruling helper went with them. This project deletes what has no
	-- consumer rather than keeping it warm -- git remembers, and a function
	-- nobody calls is a decision nobody made.

	local function zone(y: number, height: number): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.9, height)
		frame.Position = UDim2.fromScale(0.05, y)
		frame.BackgroundTransparency = 1
		frame.Parent = page
		return frame
	end

	local farActions = zone(0.06, 0.09)
	local farSlots = zone(0.18, 0.22)
	local nearSlots = zone(0.5, 0.22)
	local nearActions = zone(0.79, 0.13)
	local emoteStrip = zone(0.94, 0.05)

	local banner = text("", UDim2.fromScale(0.5, 0.05), Theme.palette.ink, Theme.fonts.marker)
	banner.Position = UDim2.fromScale(0.25, 0.4)
	banner.Parent = page

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	--- A pressable cut-out.
	---
	--- Returns a container the caller places as it would a plain button. Inside,
	--- the DRAWING is the size the composition wants and an invisible TOUCH
	--- TARGET sits over it, `Theme.touchPadding` times larger. These buttons
	--- live in world space, seen at an angle, pressed with a thumb on the
	--- primary platform: a target the size of the drawing demands aim a thumb
	--- does not have, and a button that looks right and misses is worse than one
	--- that looks slightly wrong.
	local function cutout(spec: DuelViewModel.Button, size: UDim2, seed: number, big: boolean): Frame
		local pad = Theme.touchPadding
		local scheme = FILL_FOR[spec.id]

		local container = Instance.new("Frame")
		container.Size = size
		container.BackgroundTransparency = 1

		local face = Instance.new("TextLabel")
		face.Size = UDim2.fromScale(1, 1)
		face.Text = spec.label
		face.TextScaled = true
		face.Font = Theme.fonts.marker
		face.Rotation = tiltFor(seed)
		face.BorderSizePixel = 0
		face.Parent = container

		if big and scheme then
			-- Yours: filled, and the colour says what it does before the icon
			-- gets read.
			face.BackgroundColor3 = scheme.fill
			face.TextColor3 = scheme.line
			face.BackgroundTransparency = if spec.enabled then 0 else 0.55
		else
			-- Theirs, and everything else: outline only, on bare paper.
			face.BackgroundTransparency = 1
			face.TextColor3 = if spec.enabled then Theme.palette.ink else Theme.palette.inkSoft
		end

		face.TextTransparency = if spec.enabled then 0 else 0.45
		corner(face, 0.18)
		stroke(face, if big then 3 else 2, if spec.enabled then 0 else 0.6)

		local target = Instance.new("TextButton")
		target.Size = UDim2.fromScale(pad, pad)
		target.Position = UDim2.fromScale((1 - pad) / 2, (1 - pad) / 2)
		target.BackgroundTransparency = 1
		target.Text = ""
		target.Active = spec.enabled
		target.AutoButtonColor = false
		target.ZIndex = face.ZIndex + 1
		target.Parent = container

		if spec.enabled then
			trove:Connect(target.Activated, function()
				-- The press answers before the server has said anything.
				TweenService:Create(face, TweenInfo.new(Theme.motion.snap), {
					Rotation = tiltFor(seed) + 5,
				}):Play()
				SoundController.play(SOUND_FOR[spec.id] or "offerPlaced")
				onAction(spec.id)
			end)
		end

		return container
	end

	--- A standing paper cut-out of an object: the shape with a scissor-cut white
	--- border, and a soft shadow at its foot so it reads as standing on the
	--- board rather than printed on it.
	---
	--- Phase one of two. Card A6 replaces these one at a time with real folded
	--- paper models, highest rarity first, so the board can look right now
	--- instead of waiting for twelve of them.
	local function paperFigure(itemId: string, parent: Frame)
		local look = Theme.items[itemId] or Theme.defaultItem

		local shadow = Instance.new("Frame")
		shadow.Size = UDim2.fromScale(0.5, 0.1)
		shadow.Position = UDim2.fromScale(0.25, 0.82)
		shadow.BackgroundColor3 = Theme.palette.shadow
		shadow.BackgroundTransparency = 0.35
		shadow.BorderSizePixel = 0
		shadow.Parent = parent
		corner(shadow, 0.5)

		local figure = Instance.new("Frame")
		figure.Size = UDim2.fromScale(0.52, 0.62)
		figure.Position = UDim2.fromScale(0.24, 0.16)
		figure.BackgroundColor3 = look.color
		figure.BorderSizePixel = 0
		figure.Rotation = tiltFor(#itemId)
		figure.Parent = parent
		corner(figure, look.corner)

		-- The white margin left by the scissors, then the pen line around it.
		local cut = Instance.new("UIStroke")
		cut.Color = Color3.fromRGB(252, 250, 244)
		cut.Thickness = 5
		cut.Parent = figure

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 0.85
		aspect.Parent = figure
	end

	--- One dashed slot, with whatever is standing in it.
	local function drawSlot(container: Frame, row: DuelViewModel.Row, index: number, count: number)
		local width = 1 / math.max(count, 3)

		local slot = Instance.new("Frame")
		slot.Size = UDim2.fromScale(width * 0.86, 0.92)
		slot.Position = UDim2.fromScale((index - 1) * width + width * 0.07, 0.04)
		slot.BackgroundTransparency = 1
		slot.Parent = container
		stroke(slot, 2, 0.45)
		corner(slot, 0.06)

		if row.itemId then
			paperFigure(row.itemId, slot)
		end

		local caption = text(row.label, UDim2.fromScale(1, 0.16), Theme.palette.ink, Theme.fonts.hand)
		caption.Position = UDim2.fromScale(0, 0.84)
		caption.Parent = slot

		if row.detail and row.detail ~= "" then
			local note = text(row.detail, UDim2.fromScale(1, 0.12), Theme.palette.inkSoft, Theme.fonts.hand)
			note.Position = UDim2.fromScale(0, 0.02)
			note.Parent = slot
		end

		local buttons = #row.buttons
		for slotIndex, spec in row.buttons do
			local element = cutout(spec, UDim2.fromScale(0.9 / buttons, 0.2), index * 7 + slotIndex, false)
			element.Position = UDim2.fromScale(0.05 + (slotIndex - 1) * (0.9 / buttons), 0.66)
			element.Parent = slot
		end
	end

	local function drawStrip(container: Frame, panel: DuelViewModel.Panel)
		clear(container)
		local count = math.max(#panel.rows, 3)
		for index, row in panel.rows do
			drawSlot(container, row, index, count)
		end
	end

	local function render(viewModel: DuelViewModel.ViewModel)
		banner.Text = viewModel.header
		clear(farActions)
		clear(farSlots)
		clear(nearSlots)
		clear(nearActions)
		clear(emoteStrip)

		for _, panel in viewModel.panels do
			if panel.kind == "rival" then
				drawStrip(farSlots, panel)
			elseif panel.kind == "emotes" then
				local row = panel.rows[1]
				if row then
					local count = #row.buttons
					for index, spec in row.buttons do
						local element = cutout(spec, UDim2.fromScale(0.9 / count, 1), index * 3, false)
						element.Position = UDim2.fromScale((index - 1) * (0.95 / count), 0)
						element.Parent = emoteStrip
					end
				end
			elseif panel.kind == "reveal" then
				drawStrip(nearSlots, panel)
			else
				drawStrip(nearSlots, panel)
			end
		end

		-- Yours: large, filled, along the near edge. Theirs: the same three in
		-- outline at the far edge, so you can see what they are looking at
		-- without being able to touch it.
		local count = #viewModel.actions
		for index, spec in viewModel.actions do
			local mine = cutout(spec, UDim2.fromScale(0.9 / count, 1), index * 11, true)
			mine.Position = UDim2.fromScale((index - 1) * (0.95 / count), 0)
			mine.Parent = nearActions

			local theirs = cutout(
				{ id = `mirror:{spec.id}`, label = spec.label, enabled = false, tone = spec.tone },
				UDim2.fromScale(0.6 / count, 1),
				index * 5,
				false
			)
			theirs.Position = UDim2.fromScale(0.2 + (index - 1) * (0.62 / count), 0)
			theirs.Parent = farActions
		end
	end

	local flashGeneration = 0

	local function flashEmote(symbol: string, mine: boolean)
		SoundController.play("emote")

		local mark = text(symbol, UDim2.fromScale(0.12, 0.1), Theme.palette.ink, Theme.fonts.marker)
		mark.Position = UDim2.fromScale(0.44, if mine then 0.62 else 0.3)
		mark.Parent = page

		flashGeneration += 1
		local generation = flashGeneration
		trove:Delay(Theme.motion.emote, function()
			if flashGeneration == generation then
				mark:Destroy()
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
