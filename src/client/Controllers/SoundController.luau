--!strict
--[[
	SoundController.luau -- sound bank from Theme.luau.

	The theme decides WHAT sounds; this decides WHEN (docs/arquitectura.md §10).
	Nothing here names an asset: every id comes from `Theme.sounds`, so a new
	theme brings its own foley and this file does not change.

	Unfilled slots are silent rather than broken. `Theme.sounds` ships empty on
	purpose -- an invented rbxassetid points at somebody else's sound or at
	nothing -- so every call here has to survive the id being "", and does.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

ReplicatedStorage:WaitForChild("Shared")
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local SoundController = {}

--- Fires a one-shot. Named after the moment rather than the file, so the call
--- sites read as intent: `play("fakeCall")`, not `play("stamp_03")`.
---
--- Returns silently when the slot is empty. That is the normal state today and
--- must never be an error: the game has to be playable before it is audible.
function SoundController.play(name: string)
	local assetId = (Theme.sounds :: { [string]: string })[name]
	if not assetId or assetId == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Parent = SoundService
	sound:Play()

	-- Cleans itself up. A one-shot that lingers is a leak that accumulates one
	-- instance per action for the length of a session.
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return SoundController
