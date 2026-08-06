--!strict
--[[
	HudScreen.luau -- the always-on chrome: your Clips and your collection.

	Card E3's client half. The server pushes `PlayerDataView` (PlayerDataService)
	and this draws it. Nothing here computes a balance, a price or a count -- it
	shows the last thing the server said, and the server says it again after
	every change (docs/arquitectura.md §4).

	A SCREENGUI, UNLIKE THE DUEL. `decisiones.md` fixed that the negotiation
	buttons live ON the paper board rather than on a layer over the world,
	because a UI that fills the screen hides the rival and seeing the rival is
	mechanical (§11). The HUD is a different animal and gets the opposite answer:

	  it is chrome, not play      it must exist in the lobby too, where there is
	                              no board to draw on
	  it hides nothing            a torn slip in one corner, and the rival is
	                              in the middle of the screen
	  it is never pressed         nothing here is a control, so the mobile
	                              accuracy problem that motivated the world-space
	                              decision does not apply

	docs/gdd.md §28: one ballpoint pen drew this world. Every line goes through
	`stroke`, the paper is `Theme.palette.paper`, and there are NO colour fills
	-- the three negotiation buttons are the game's only ones, and a HUD that
	competed with them for attention would be taking the exception for itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedStorage:WaitForChild("Shared")
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

local HudScreen = {}

export type Handle = {
	render: (data: Types.PlayerDataView) -> (),
	destroy: () -> (),
}

--- A pen line. Same helper as the board's, for the same reason: the one-pen
--- rule holds by construction instead of by memory.
local function stroke(parent: Instance, thickness: number)
	local line = Instance.new("UIStroke")
	line.Color = Theme.palette.ink
	line.Thickness = thickness
	line.Parent = parent
end

--- A torn slip of paper, tilted a hair. The tilt is what keeps two slips from
--- looking like a table: nothing in this world was placed with a ruler.
local function slip(seed: number): Frame
	local sheet = Instance.new("Frame")
	sheet.BackgroundColor3 = Theme.palette.paper
	sheet.BorderSizePixel = 0
	sheet.Rotation = ((seed % 3) - 1) * (Theme.tiltDegrees / 2)

	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0.08, 0)
	ui.Parent = sheet

	stroke(sheet, 2)
	return sheet
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

--- Builds the HUD and returns the handle that drives it.
---
--- Everything it creates is registered in one trove, so a HUD that is taken
--- down leaves nothing behind -- the same discipline the duel scene uses, and
--- for the same reason: a tween still running against a destroyed frame is a
--- warning per frame forever.
function HudScreen.mount(parent: Instance): Handle
	local trove = Trove.new()

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	-- Sibling, so a frame's ZIndex is read against its siblings rather than
	-- globally. Without it, a child of the slip can draw over a whole screen.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	trove:Add(function()
		gui:Destroy()
	end)

	-- ── Clips, top left ──────────────────────────────────────────────────────
	local clipsSlip = slip(1)
	clipsSlip.Size = UDim2.fromScale(0.20, 0.075)
	clipsSlip.Position = UDim2.fromScale(0.02, 0.03)
	clipsSlip.Parent = gui

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 2.8
	ratio.Parent = clipsSlip

	local clipsValue = label("0", Theme.fonts.marker)
	clipsValue.Size = UDim2.fromScale(0.62, 0.6)
	clipsValue.Position = UDim2.fromScale(0.06, 0.2)
	clipsValue.TextXAlignment = Enum.TextXAlignment.Left
	clipsValue.Parent = clipsSlip

	local clipsName = label(Strings.currencyName, Theme.fonts.hand)
	clipsName.Size = UDim2.fromScale(0.28, 0.34)
	clipsName.Position = UDim2.fromScale(0.68, 0.34)
	clipsName.Parent = clipsSlip

	-- ── Collection, under it ─────────────────────────────────────────────────
	local shelfSlip = slip(2)
	shelfSlip.Size = UDim2.fromScale(0.20, 0.055)
	shelfSlip.Position = UDim2.fromScale(0.02, 0.115)
	shelfSlip.Parent = gui

	local shelfRatio = Instance.new("UIAspectRatioConstraint")
	shelfRatio.AspectRatio = 3.8
	shelfRatio.Parent = shelfSlip

	local shelfValue = label("0 / 0", Theme.fonts.hand)
	shelfValue.Size = UDim2.fromScale(0.9, 0.62)
	shelfValue.Position = UDim2.fromScale(0.05, 0.19)
	shelfValue.Parent = shelfSlip

	--- The last balance drawn, so a change can be animated rather than swapped.
	--- A number that jumps is a number nobody notices, and Clips arriving is one
	--- of the two rewards a duel pays (docs/plan-etapas.md: juice after EVERY
	--- meaningful action, not only the reveal).
	local shown = -1

	local function render(data: Types.PlayerDataView)
		local collected = 0
		for _, count in data.collection do
			collected += count
		end
		shelfValue.Text = `{collected} / {#Items.order}`

		if data.clips == shown then
			return
		end

		local first = shown < 0
		shown = data.clips
		clipsValue.Text = tostring(data.clips)

		if first then
			return
		end

		-- A short bump: the number grows and settles. Cancelled by the trove,
		-- because a tween still running against a destroyed frame is a warning
		-- per frame, forever.
		clipsValue.Size = UDim2.fromScale(0.62, 0.72)
		local bump = TweenService:Create(clipsValue, TweenInfo.new(Theme.motion.place), {
			Size = UDim2.fromScale(0.62, 0.6),
		})
		trove:Add(function()
			bump:Cancel()
		end)
		bump:Play()
	end

	return {
		render = render,
		destroy = function()
			trove:Clean()
		end,
	}
end

return HudScreen
