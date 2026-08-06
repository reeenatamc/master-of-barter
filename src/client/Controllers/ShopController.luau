--!strict
--[[
	ShopController.luau -- opens the kiosk and keeps it fed.

	Thin on purpose. `ShopScreen` owns the look, `DuelController.onPlayerData`
	owns the data, and the server owns every decision -- this only decides WHEN
	the kiosk is on screen.
]]

local Players = game:GetService("Players")

local DuelController = require(script.Parent.DuelController)
local ShopScreen = require(script.Parent.ShopScreen)

local ShopController = {}

local handle: ShopScreen.Handle? = nil
local open = false

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

function ShopController.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = ShopScreen.mount(playerGui)
	handle = screen

	-- Fed by the same push the HUD listens to. One source, two readers: the
	-- kiosk cannot show a balance the HUD disagrees with, because there is only
	-- one balance.
	DuelController.onPlayerData(screen.render)
	screen.setVisible(open)
end

return ShopController
