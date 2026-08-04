--!strict
--[[
	Main.client.luau -- client bootstrap.

	Controllers get started here in explicit order, mirroring what Main.server
	does with services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")

local DuelController = require(script.Parent.Controllers.DuelController)

print("[MasterOfBarter] client ready")

DuelController.start()
