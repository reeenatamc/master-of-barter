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
	top.Color = Theme.palette.wood
	-- Wood, not plastic. The grain is most of what says "desk" from the camera
	-- angle this is seen at, and a flat brown slab does not.
	top.Material = Enum.Material.Wood
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

--- A basket beside the table.
---
--- Built here rather than placed in the map, like everything else in this
--- scene: a duel can start anywhere and several can run at once, so a basket
--- somebody positioned by hand would belong to one table and no others.
---
--- Failing to build one is not worth failing a duel over, so a mesh that will
--- not load leaves a warning and no basket. The duel is still playable; it just
--- looks poorer.
local function buildBasket(origin: CFrame, side: number, parent: Instance)
	local spec = Theme.table.basket

	local basket = Instance.new("MeshPart")
	basket.Name = if side < 0 then "BasketLeft" else "BasketRight"
	basket.Size = spec.size
	basket.Color = spec.color
	basket.Material = Enum.Material.Glass
	basket.Transparency = spec.transparency
	basket.Reflectance = spec.reflectance
	basket.CastShadow = false
	basket.Anchored = true
	basket.CanCollide = false
	basket.CanQuery = true

	local ok, err = pcall(function()
		basket.MeshId = spec.meshId
	end)
	if not ok then
		warn(`[Scene] the basket mesh would not load: {err}`)
		basket:Destroy()
		return
	end

	-- Sitting ON the table, not floating over it: half its own height above the
	-- surface, out to the side by `offset`.
	basket.CFrame = origin * CFrame.new(side * spec.offset, Theme.table.height + spec.size.Y / 2, 0)
	basket.Parent = parent
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

		-- EMO, by request. Pale skin, black everything else.
		--
		-- Done with colours alone because hair, fringe and clothing are catalogue
		-- ASSET IDS, and ids written from memory are the mistake that already
		-- cost this project four invented font names. The silhouette reads; the
		-- fringe needs ids somebody looked up.
		--
		-- Varied only slightly, and from the seed rather than at random, so two
		-- bots at neighbouring tables are not identical and one bot keeps one
		-- look for its whole duel.
		local skins = {
			Color3.fromRGB(238, 226, 224),
			Color3.fromRGB(228, 212, 212),
			Color3.fromRGB(216, 200, 204),
			Color3.fromRGB(244, 234, 232),
		}
		local blacks = {
			Color3.fromRGB(24, 22, 28),
			Color3.fromRGB(32, 28, 36),
			Color3.fromRGB(18, 18, 22),
			Color3.fromRGB(38, 30, 40),
		}
		description.HeadColor = skins[(seed % #skins) + 1]
		description.LeftArmColor = description.HeadColor
		description.RightArmColor = description.HeadColor
		description.TorsoColor = blacks[(seed % #blacks) + 1]
		description.LeftLegColor = description.TorsoColor
		description.RightLegColor = description.TorsoColor

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

--- Sculpts a fringe onto the head, out of parts.
---
--- Hair in Roblox is normally a catalogue accessory, which is an asset id --
--- something that either exists or does not, and cannot be invented. Geometry
--- can: this is built the same way the table and the board are, which is the
--- project's habit anyway (docs/decisiones.md: the scene is code, not a model).
---
--- Deliberately asymmetric, heavier over one eye. A symmetric fringe reads as a
--- helmet; the whole point of this shape is that it is falling over half a face.
local function addFringe(body: Model, tint: Color3)
	local head = body:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	--- A slab across the brow, a long sweep over the left eye, two shorter locks
	--- on the right, and a back so it is not a bald head with a fringe glued on.
	type Lock = { offset: Vector3, size: Vector3, tilt: number }
	local locks: { Lock } = {
		{ offset = Vector3.new(0, 0.42, -0.06), size = Vector3.new(1.24, 0.36, 1.12), tilt = 0 },
		{ offset = Vector3.new(-0.30, 0.10, -0.50), size = Vector3.new(0.62, 0.86, 0.30), tilt = -0.35 },
		{ offset = Vector3.new(0.34, 0.20, -0.48), size = Vector3.new(0.44, 0.60, 0.28), tilt = 0.30 },
		{ offset = Vector3.new(0.52, 0.26, -0.30), size = Vector3.new(0.30, 0.52, 0.30), tilt = 0.55 },
		{ offset = Vector3.new(0, 0.24, 0.52), size = Vector3.new(1.16, 0.72, 0.26), tilt = 0 },
	}

	for index, lock in locks do
		local strand = Instance.new("Part")
		strand.Name = `Hair{index}`
		strand.Size = lock.size
		strand.Color = tint
		strand.Material = Enum.Material.SmoothPlastic
		strand.CanCollide = false
		strand.CanQuery = false
		strand.CanTouch = false
		strand.Massless = true
		strand.CFrame = head.CFrame * CFrame.new(lock.offset) * CFrame.Angles(0, 0, lock.tilt)
		strand.Parent = body

		-- Welded rather than positioned once: the body is anchored today, but a
		-- head that ever moves should not leave its hair behind.
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = strand
		weld.Parent = strand
	end
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

	-- After the pivot, so the strands are built against the head where it
	-- actually ended up rather than where the rig was assembled.
	addFringe(body, Color3.fromRGB(16, 14, 20))

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

	-- One each side. They belong to the duel's model, so they go with the table
	-- when it does.
	buildBasket(origin, -1, model)
	buildBasket(origin, 1, model)

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
