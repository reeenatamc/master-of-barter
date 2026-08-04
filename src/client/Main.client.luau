--!strict
--[[
	Main.client.luau -- client bootstrap.

	Controllers get started here in explicit order, mirroring what Main.server
	does with services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")

local DuelController = require(script.Parent.Controllers.DuelController)
local UIController = require(script.Parent.Controllers.UIController)

print("[MasterOfBarter] client ready")

-- UI first: it subscribes to duel state, and DuelController.start() is what
-- asks to be queued. Starting them the other way round risks the first state
-- landing before anything is listening for it.
UIController.start()
DuelController.start()
