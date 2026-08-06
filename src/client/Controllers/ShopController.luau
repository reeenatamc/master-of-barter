--!strict
--[[
	ShopController.luau -- opens the kiosk and keeps it fed.

	Thin on purpose. `ShopScreen` owns the look, `DuelController.onPlayerData`
	owns the data, and the server owns every decision -- this only decides WHEN
	the kiosk is on screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local DuelController = require(script.Parent.DuelController)
local ShopScreen = require(script.Parent.ShopScreen)
local ShowcaseScreen = require(script.Parent.ShowcaseScreen)

local ShopController = {}

local handle: ShopScreen.Handle? = nil
local shelf: ShowcaseScreen.Handle? = nil
local open = false
local shelfOpen = false

--- Shows or hides the kiosk.
function ShopController.setOpen(visible: boolean)
	open = visible
	local screen = handle
	if screen then
		screen.setVisible(visible)
	end
end

function ShopController.isOpen(): boolean
	return open
end

--- Shows or hides the showcase.
function ShopController.setShowcaseOpen(visible: boolean)
	shelfOpen = visible
	local screen = shelf
	if screen then
		screen.setVisible(visible)
	end
end

--- TEMP: two paper tabs that open the kiosk and the showcase by touch.
---
--- Same death date as the keys below: card E1 builds the lobby where you walk
--- up to Don Trueque's stall and the shelf wall, and both of these go with it.
---
--- They exist because a phone has no keyboard, and half the visual package was
--- unreachable there -- which made the one review that matters most (does this
--- work under a thumb?) impossible for two of the four screens.
---
--- No colour fill: the three negotiation buttons keep their monopoly (§28).
--- These are the least important thing on any screen they share, and they look
--- it.
local function buildTabs(parent: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugTabs"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent

	local function tab(index: number, text: string, onTap: () -> ())
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(0.16, 0.06)
		button.Position = UDim2.fromScale(0.82, 0.04 + (index - 1) * 0.08)
		button.BackgroundColor3 = Theme.palette.paper
		button.BorderSizePixel = 0
		button.Text = text
		button.TextColor3 = Theme.palette.ink
		button.TextScaled = true
		button.Font = Theme.fonts.hand
		button.AutoButtonColor = false
		button.Rotation = ((index % 2) * 2 - 1) * (Theme.tiltDegrees / 2)
		button.Parent = gui

		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.25, 0)
		round.Parent = button

		local line = Instance.new("UIStroke")
		line.Color = Theme.palette.ink
		line.Thickness = 2
		line.Parent = button

		-- The same floor the kiosk's own buttons get: scale alone shrinks to a
		-- smudge on a small phone, and these are meant to be pressed there.
		local floor = Instance.new("UISizeConstraint")
		floor.MinSize = Vector2.new(0, Theme.minTouchPixels)
		floor.Parent = button

		button.Activated:Connect(onTap)
	end

	tab(1, Strings.kiosk.title, function()
		ShopController.setOpen(not open)
	end)
	tab(2, Strings.showcase.tab, function()
		ShopController.setShowcaseOpen(not shelfOpen)
	end)
end

--- TEMP: opens the kiosk and the showcase from the keyboard.
---
--- Card E1 builds the lobby, and in the lobby you walk up to Don Trueque's
--- stall and to the wall of shelves -- those are what will open these screens.
--- Until then they are mounted and hidden with nothing to reveal them, which
--- would make them impossible to review.
---
--- Letters, not digits: 1-9 are Roblox's backpack hotbar and never reach here.
local function bindDebugKeys()
	local UserInputService = game:GetService("UserInputService")

	UserInputService.InputBegan:Connect(function(input: InputObject, busy: boolean)
		if busy or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			ShopController.setOpen(not open)
			print(`[Shop] kiosk {if open then "open" else "closed"}`)
		elseif input.KeyCode == Enum.KeyCode.L then
			ShopController.setShowcaseOpen(not shelfOpen)
			print(`[Shop] showcase {if shelfOpen then "open" else "closed"}`)
		end
	end)
end

function ShopController.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = ShopScreen.mount(playerGui)
	handle = screen

	-- Fed by the same push the HUD listens to. One source, two readers: the
	-- kiosk cannot show a balance the HUD disagrees with, because there is only
	-- one balance.
	local showcase = ShowcaseScreen.mount(playerGui)
	shelf = showcase

	-- Fed by the same push the HUD listens to. One source, three readers: no
	-- screen can show a balance or a collection another disagrees with, because
	-- there is only one of each.
	DuelController.onPlayerData(screen.render)
	DuelController.onPlayerData(showcase.render)
	screen.setVisible(open)
	showcase.setVisible(shelfOpen)

	bindDebugKeys()
	buildTabs(playerGui)
end

return ShopController
