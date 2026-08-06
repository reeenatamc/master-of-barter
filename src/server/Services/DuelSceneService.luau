--!strict
--[[
	DuelSceneService.luau -- the physical table a duel happens at.

	Card E2 needs the canonical scene of docs/gdd.md §11: two avatars standing
	FACING EACH OTHER with the paper sheet between them. That framing is not
	decoration -- it is what makes a thumbnail recognisable, and seeing the rival
	is part of the information you read them with.

	This service owns only the geometry and where the players stand. It draws
	nothing: each client renders its own surface onto the sheet, on the face
	pointing at them, so no player's view is ever assembled anywhere the other
	could reach it.

	Built in code rather than modelled in Studio, and that is a deliberate call
	recorded in docs/decisiones.md: it is a table and a sheet of paper, every
	dimension comes from Config, and card E1 replaces the whole thing with the
	real lobby. Hand-placing parts for it would be effort with a known expiry.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

type Slot = Types.Slot

local DuelSceneService = {}

--- Where each duel's table sits. Duels are laid out along a line so two running
--- at once never share a spot; E1's lobby replaces this with real placed tables.
local SPACING = 60
local nextIndex = 0

--- Which side each slot stands on. Slot 1 takes the negative side of the board
--- and looks towards positive Z, slot 2 the opposite. The client derives which
--- way round to draw its page from the same rule, which is why neither has to
--- tell the other.
local function standOffset(slot: Slot): Vector3
	local side = if slot == 1 then -1 else 1
	return Vector3.new(0, 0, side * Theme.table.standDistance)
end

--- The model for one duel: a table, a sheet standing on it, and nothing else.
--- Named after the duel so each client can find its own without a remote.
local function buildModel(duelId: string, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Duel_{duelId}`

	local top = Instance.new("Part")
	top.Name = "TableTop"
	top.Size = Theme.table.topSize
	top.CFrame = origin * CFrame.new(0, Theme.table.height, 0)
	top.Anchored = true
	top.Color = Theme.palette.tape
	top.Material = Enum.Material.SmoothPlastic
	top.TopSurface = Enum.SurfaceType.Smooth
	top.BottomSurface = Enum.SurfaceType.Smooth
	top.Parent = model

	-- The board lies FLAT on the table, between the two players, and both act
	-- on this one object -- which is what makes mirrored rows mean anything
	-- (docs/gdd.md §25). A pad of paper, not a lectern.
	--
	-- One face, two readers: each client draws its own local SurfaceGui on the
	-- top of it and sees only that one, with slot 2's rotated 180 so that
	-- "near" is near for both. The rival's view is never assembled here.
	local sheet = Instance.new("Part")
	sheet.Name = "Board"
	sheet.Size = Theme.table.boardSize
	-- Turned by Theme.table.boardYaw so the layout's near row lands near the
	-- player. See that value for why it is a knob and not a constant.
	sheet.CFrame = origin
		* CFrame.new(0, Theme.table.height + Theme.table.boardSize.Y / 2, 0)
		* CFrame.Angles(0, math.rad(Theme.table.boardYaw), 0)
	sheet.Anchored = true
	sheet.Color = Theme.palette.paper
	sheet.Material = Enum.Material.SmoothPlastic
	sheet.CanCollide = false
	sheet.Parent = model

	model.PrimaryPart = sheet
	model.Parent = workspace
	return model
end

--- Gives a filler opponent a body.
---
--- A bot has no Roblox account, so nothing hands it an avatar -- and an empty
--- chair across the table is the most obvious "this is not a person" signal
--- there is, which is precisely what docs/gdd.md §34 rules out.
---
--- Built from a HumanoidDescription rather than loaded from a real user id.
--- `CreateHumanoidModelFromUserId` would work and would mean wearing an actual
--- person's likeness, which is not ours to borrow for an opponent that lies to
--- people for a living.
---
--- Only body colours are set: no accessories, no clothing asset ids. Those ids
--- would be written from memory, and this project has a rule about that. The
--- result is a plain avatar in the right proportions, which is all the framing
--- needs (§11: you read the rival, so the rival has to be there).
local function buildBotBody(displayName: string, seed: number): Model?
	local ok: boolean, model: any = pcall(function()
		local description = Instance.new("HumanoidDescription")

		-- Varied so two bots at neighbouring tables are not twins. Drawn from
		-- the seed rather than at random so one bot keeps one look.
		local shirts = {
			Color3.fromRGB(64, 108, 176),
			Color3.fromRGB(196, 86, 96),
			Color3.fromRGB(88, 152, 108),
			Color3.fromRGB(148, 104, 176),
		}
		local skins = {
			Color3.fromRGB(234, 194, 160),
			Color3.fromRGB(198, 148, 110),
			Color3.fromRGB(142, 100, 72),
			Color3.fromRGB(246, 216, 190),
		}
		description.TorsoColor = shirts[(seed % #shirts) + 1]
		description.LeftArmColor = skins[(seed % #skins) + 1]
		description.RightArmColor = description.LeftArmColor
		description.HeadColor = description.LeftArmColor
		description.LeftLegColor = Color3.fromRGB(58, 62, 76)
		description.RightLegColor = description.LeftLegColor

		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)

	if not ok or typeof(model) ~= "Instance" then
		warn(`[Scene] could not build a body for {displayName}: {model}`)
		return nil
	end

	local body = model :: Model
	body.Name = displayName
	return body
end

--- Stands a filler opponent at its side of the table, facing the sheet.
local function seatBot(displayName: string, origin: CFrame, slot: Slot, parent: Instance): Model?
	local body = buildBotBody(displayName, slot + #displayName)
	if not body then
		return nil
	end

	local spot = origin * CFrame.new(standOffset(slot))
	local lookAt = origin.Position + Vector3.new(0, Theme.table.height, 0)

	body.Parent = parent
	body:PivotTo(CFrame.lookAt(spot.Position + Vector3.new(0, 3, 0), lookAt))

	-- Anchored like a player's, and for the same reason: nothing wanders off
	-- mid-duel. A bot's body has no controller anyway, but an unanchored rig
	-- falls over, and a rival lying face down is its own kind of tell.
	local root = body:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end

	return body
end

--- Stands a player at their side of the table, facing the sheet.
---
--- Anchored on purpose: docs/gdd.md §12 has no character movement during a
--- duel, and an avatar that can wander off breaks the one framing the whole
--- card exists to produce.
local function seat(player: Player, origin: CFrame, slot: Slot)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local spot = origin * CFrame.new(standOffset(slot))
	local lookAt = origin.Position + Vector3.new(0, Theme.table.height, 0)

	character:PivotTo(CFrame.lookAt(spot.Position + Vector3.new(0, 3, 0), lookAt))
	root.Anchored = true
end

local function release(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
	end
end

--- Builds the table for a duel and stands both players at it. Returns a
--- cleanup function; the caller registers it in the duel's Trove, so the scene
--- goes away by every route the duel can end, disconnects included.
--- One seat. `player` is nil for a filler opponent, which is the whole reason
--- this type is not just a Player: the scene has to seat somebody either way.
export type Participant = {
	player: Player?,
	displayName: string,
	slot: Slot,
}

function DuelSceneService.open(duelId: string, participants: { Participant }): () -> ()
	nextIndex += 1
	local origin = CFrame.new(nextIndex * SPACING, 0, 0)

	local model = buildModel(duelId, origin)

	for _, entry in participants do
		local player = entry.player
		if player then
			seat(player, origin, entry.slot)
		else
			-- A bot's body belongs to the duel's model, so it is destroyed with
			-- the table by the same cleanup. Nothing to release afterwards:
			-- there is no player to give movement back to.
			seatBot(entry.displayName, origin, entry.slot, model)
		end
	end

	return function()
		model:Destroy()
		for _, entry in participants do
			local player = entry.player
			if player then
				release(player)
			end
		end
	end
end

return DuelSceneService
