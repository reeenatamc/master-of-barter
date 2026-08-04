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

--- Which way each slot faces. Slot 1 stands on the negative side of the sheet
--- and looks towards positive Z, slot 2 does the opposite. The client derives
--- which face of the sheet to draw on from the same rule.
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

	-- The sheet stands vertically ON the table, so both players read the same
	-- object from opposite sides. Thin enough to read as paper rather than as a
	-- board.
	local sheet = Instance.new("Part")
	sheet.Name = "Sheet"
	sheet.Size = Theme.table.sheetSize
	sheet.CFrame = origin * CFrame.new(0, Theme.table.height + Theme.table.sheetSize.Y / 2, 0)
	sheet.Anchored = true
	sheet.Color = Theme.palette.paper
	sheet.Material = Enum.Material.SmoothPlastic
	sheet.CanCollide = false
	sheet.Parent = model

	model.PrimaryPart = sheet
	model.Parent = workspace
	return model
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
function DuelSceneService.open(duelId: string, participants: { { player: Player, slot: Slot } }): () -> ()
	nextIndex += 1
	local origin = CFrame.new(nextIndex * SPACING, 0, 0)

	local model = buildModel(duelId, origin)

	for _, entry in participants do
		seat(entry.player, origin, entry.slot)
	end

	return function()
		model:Destroy()
		for _, entry in participants do
			release(entry.player)
		end
	end
end

return DuelSceneService
