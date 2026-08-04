--!strict
--[[
	DuelCamera.luau -- puts the camera over your own shoulder for a duel.

	docs/gdd.md §11 asks for a fixed camera on the table, not an orbiting one: a
	camera the player has to manage is one more thing between them and the game,
	and a duel where both people frame the shot differently stops being the same
	scene.

	Over the shoulder rather than straight down, because the rival's avatar has
	to be in frame. Seeing them is part of reading them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedStorage:WaitForChild("Shared")
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local DuelCamera = {}

--- Takes over the camera and glides it to the table. Sliding in rather than
--- cutting: a cut is jarring, a glide reads as sitting down.
function DuelCamera.focus(sheet: BasePart, slot: Types.Slot)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local side = if slot == 1 then -1 else 1
	local eye = sheet.Position + Vector3.new(0, Theme.camera.height, side * Theme.camera.distance)
	local aim = sheet.Position + Vector3.new(0, Theme.camera.aimHeight - sheet.Size.Y / 2, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(Theme.camera.settle, Enum.EasingStyle.Quad), {
		CFrame = CFrame.lookAt(eye, aim),
	}):Play()
end

--- Hands the camera back. Called when the duel ends by any route, including a
--- disconnect that destroys the table underneath it -- a scriptable camera left
--- behind is a player stuck staring at nothing.
function DuelCamera.release()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return DuelCamera
