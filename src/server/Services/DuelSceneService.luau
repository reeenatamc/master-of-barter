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

local InsertService = game:GetService("InsertService")
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
	-- Beyond the furthest the table reaches, which is the head extension and not
	-- the main top: the heads stick out towards the players, so a distance
	-- measured from the middle would stand somebody inside the wood.
	local reach = Theme.table.topSize.Z / 2 + Theme.table.head.reach
	return Vector3.new(0, 0, side * (reach + Theme.table.standClearance))
end

--- The model for one duel: a table, a sheet standing on it, and nothing else.
--- Named after the duel so each client can find its own without a remote.
local function buildModel(duelId: string, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Duel_{duelId}`

	local top = Instance.new("Part")
	top.Name = "TableTop"
	-- `height` is where the SURFACE goes, so the slab hangs below it. Every
	-- other placement in this file already read it that way; this one did not,
	-- and that is what buried the sheet inside the wood.
	local slabY = Theme.table.height - Theme.table.topSize.Y / 2

	top.Size = Theme.table.topSize
	top.CFrame = origin * CFrame.new(0, slabY, 0)
	top.Anchored = true
	top.Color = Theme.palette.wood
	-- Wood, not plastic. The grain is most of what says "desk" from the camera
	-- angle this is seen at, and a flat brown slab does not.
	top.Material = Enum.Material.Wood
	top.TopSurface = Enum.SurfaceType.Smooth
	top.BottomSurface = Enum.SurfaceType.Smooth
	top.Parent = model

	-- A tongue of table at each head end, one reaching towards each player,
	-- where that player's basket sits.
	--
	-- Flush with the top by construction, not by two numbers agreeing: same
	-- thickness, same centre height, so it cannot end up a step above or below
	-- the surface it is meant to continue.
	local head = Theme.table.head
	for _, side in { -1, 1 } do
		local ext = Instance.new("Part")
		ext.Name = `TableHead{if side < 0 then 1 else 2}`
		ext.Size = Vector3.new(head.width, Theme.table.topSize.Y, head.reach)
		ext.CFrame = origin
			* CFrame.new(0, slabY, side * (Theme.table.topSize.Z + head.reach) / 2)
		ext.Anchored = true
		ext.Color = Theme.palette.wood
		ext.Material = Enum.Material.Wood
		ext.TopSurface = Enum.SurfaceType.Smooth
		ext.BottomSurface = Enum.SurfaceType.Smooth
		ext.Parent = model
	end

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

--- Places a model so its MIDDLE lands on `target`, instead of its pivot.
---
--- `PivotTo` moves the PIVOT, and a model's pivot is wherever its exporter left
--- the origin -- which is very often not the middle of the thing. This butter's
--- box runs from 0 to 1 along one axis rather than -0.5 to 0.5, so pivoting it
--- into a tray put half of it outside the tray.
---
--- Nothing in a file listing shows that, and no error is raised. It shows up as
--- "it does not look like it is inside", which is a hard thing to search for.
--- Every arithmetic in this file assumes it is positioning a middle, so every
--- model goes through here.
local function placeCentred(model: Model, target: CFrame)
	local box: CFrame = model:GetBoundingBox()
	-- Where the middle sits relative to the pivot, in the pivot's own frame.
	local drift = model:GetPivot():ToObjectSpace(box)
	model:PivotTo(target * drift:Inverse())
end

--- Puts one squishy in a tray.
---
--- Its own function, and its own failure: a squishy that will not load leaves a
--- tray, and a tray is still a tray. Nothing here is allowed to cost a duel.
---
--- The squishy is SCALED TO ITS TRAY rather than given a size in studs. A model
--- that does not fit the thing it stands in is the one mistake this cannot look
--- right with, and the models are going to keep arriving at whatever size their
--- exporter felt like. Same reason the tray's own distance is computed.
local function fillTray(tray: Model, slot: Slot, origin: CFrame, insideLength: number, alongZ: number)
	local spec = Theme.table.basket.demo

	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(spec.assetId)
		end)
		if not ok then
			warn(`[Scene] tray {slot}: squishy {spec.assetId} would not load: {result}`)
			return
		end

		local wrapper = result :: Model
		local squishy = wrapper:FindFirstChildWhichIsA("Model") or wrapper
		if squishy ~= wrapper then
			squishy.Parent = nil
			wrapper:Destroy()
		end

		-- The tray is what it belongs to, so the tray going away is what decides
		-- whether there is anywhere to put it.
		if not tray:IsDescendantOf(game) then
			squishy:Destroy()
			print(`[Scene] tray {slot}: the duel ended before the squishy arrived`)
			return
		end

		squishy.Name = `Squishy{slot}`
		for _, piece in squishy:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = true
				-- Only when Config says to. A model that arrives with its own
				-- working texture keeps it -- that is the whole reason for
				-- loading models instead of bare meshes, and painting over one
				-- by reflex would throw it away.
				if spec.tint then
					piece.Color = spec.tint
					piece.Material = spec.material
				end
			end
		end

		local natural = squishy:GetExtentsSize()
		local longest = math.max(natural.X, natural.Y, natural.Z)
		if longest > 0 then
			squishy:ScaleTo(insideLength * spec.fill / longest)
		end

		local turn = CFrame.Angles(
			math.rad(spec.rotation.X),
			math.rad(spec.rotation.Y),
			math.rad(spec.rotation.Z)
		)

		-- Resting ON the tray's floor, which is the table surface the tray
		-- stands on. Measured AFTER scaling and turning, because both change
		-- which way up it is and therefore how far its middle is off the floor.
		local grown = turn:VectorToWorldSpace(squishy:GetExtentsSize())
		local rest = Theme.table.height + math.abs(grown.Y) / 2

		squishy.Parent = tray
		placeCentred(squishy, origin * CFrame.new(0, rest, alongZ) * turn)
		print(`[Scene] tray {slot}: squishy in, {math.abs(grown.X)} long`)
	end)
end

--- ONE PLAYER'S tray, standing on that player's head extension.
---
--- Not "the left one and the right one": a tray belongs to somebody, and the
--- tongue of table it stands on is what says so. It takes a slot for the same
--- reason `standOffset` does, and reuses that function's rule for which way
--- round the two sides are, so a tray and its owner cannot drift apart.
---
--- Built here rather than placed in the map, like everything else in this
--- scene: a duel can start anywhere and several can run at once, so a basket
--- somebody positioned by hand would belong to one table and no others.
---
--- Failing to build one is not worth failing a duel over, so a mesh that will
--- not load leaves a warning and no basket. The duel is still playable; it just
--- looks poorer.
---
--- ── TWO APIS THAT LOOK RIGHT AND ARE NOT ───────────────────────────────────
---
--- `Instance.new("MeshPart")` and then setting `MeshId` does not work, and it
--- does not work QUIETLY: `MeshId` is not assignable from a running script, so
--- the write neither applied nor raised. The pcall reported success, the
--- warning never fired, and two MeshParts with no mesh hung off the table --
--- invisible, and silent about being invisible.
---
--- `AssetService:CreateMeshPartAsync` was the fix for that, and it was right
--- until the asset changed. It takes a MESH; the upload tool posts to Open
--- Cloud, which creates a MODEL -- a container with MeshParts inside it. Same
--- shape of failure, second time: nothing on the table, nothing in the output.
---
--- `InsertService:LoadAsset` is the one that takes a model id. It also keeps
--- whatever the model brought with it -- materials, textures, several pieces --
--- which is what the squishies are going to need.
---
--- ── AND THE REASON BOTH WERE INVISIBLE ──────────────────────────────────────
---
--- A PCALL THAT RETURNS TRUE IS NOT PROOF THE WORK HAPPENED. It only proves
--- nothing threw. Both failures were diagnosed by looking at the table rather
--- than at the log, because the log had nothing to say -- and the one branch
--- that gave up on purpose (duel ended mid-fetch) said nothing either.
---
--- So this now reports EVERY outcome, success included. A function whose only
--- output is a warning is a function that cannot tell you it ran.
---
--- It YIELDS -- it fetches the asset -- so it runs off the duel-start path: a
--- slow asset server must not be able to delay the start of a duel, let alone
--- fail one.
local function buildBasket(origin: CFrame, slot: Slot, parent: Instance)
	local spec = Theme.table.basket
	local side = if slot == 1 then -1 else 1

	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(spec.assetId)
		end)

		if not ok then
			warn(`[Scene] basket {slot}: asset {spec.assetId} would not load: {result}`)
			return
		end

		-- LoadAsset hands back a wrapper Model with the uploaded model inside
		-- it. What we want is the thing itself, so the wrapper does not add a
		-- pivot of its own between us and the tray.
		local wrapper = result :: Model
		local basket = wrapper:FindFirstChildWhichIsA("Model") or wrapper
		if basket ~= wrapper then
			basket.Parent = nil
			wrapper:Destroy()
		end

		-- The duel can have ended while the asset was in flight. The Trove has
		-- already run by then, so parenting into the dead model would leak
		-- something with nothing left to clean it up. Said out loud, because a
		-- branch that gives up in silence is indistinguishable from a bug.
		if not parent:IsDescendantOf(game) then
			basket:Destroy()
			print(`[Scene] basket {slot}: the duel ended before the asset arrived`)
			return
		end

		basket.Name = `Basket{slot}`
		for _, piece in basket:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Color = spec.color
				piece.Material = Enum.Material.Glass
				piece.Transparency = spec.transparency
				piece.Reflectance = spec.reflectance
				piece.CastShadow = false
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = true
			end
		end

		-- The model is Z-up and Roblox is Y-up, so it has to be turned before it
		-- is placed. See Theme: the angle was measured off the mesh, not guessed.
		local turn = CFrame.Angles(
			math.rad(spec.rotation.X),
			math.rad(spec.rotation.Y),
			math.rad(spec.rotation.Z)
		)

		-- A model arrives at whatever size it was uploaded at, so it is scaled to
		-- what Config asked for rather than assigned it: `Size` is a part's
		-- property, not a model's. Uniform on purpose -- squashing a model to
		-- fit three independent numbers is how a tray becomes a puddle.
		local actual = basket:GetExtentsSize()
		local biggest = math.max(actual.X, actual.Y, actual.Z)
		if biggest > 0 then
			local wanted = math.max(spec.size.X, spec.size.Y, spec.size.Z)
			basket:ScaleTo(wanted / biggest)
		end

		-- What the basket MEASURES once turned, which is not `size` any more:
		-- turning swaps which of the three numbers points where. Both of the
		-- numbers below come from this, rather than being written down beside
		-- the angle, so changing the angle cannot leave a basket sunk into the
		-- wood or glued to its edge.
		local standing = turn:VectorToWorldSpace(spec.size)

		-- Standing ON its owner's head extension, centred, which is what the
		-- extension is there for. Both numbers come from the table itself, so a
		-- wider head or a longer reach carries the tray with it rather than
		-- leaving it hanging off the end.
		local lift = Theme.table.height + math.abs(standing.Y) / 2
		local along = (Theme.table.topSize.Z + Theme.table.head.reach) / 2

		-- Does it actually fit on the thing it is standing on? Cheap to ask, and
		-- the alternative is a future model that overhangs the wood in a way
		-- nobody notices until it is in a screenshot.
		local head = Theme.table.head
		if math.abs(standing.X) > head.width or math.abs(standing.Z) > head.reach then
			warn(
				`[Scene] basket {slot} is {math.abs(standing.X)} x {math.abs(standing.Z)} `
					.. `and the head it sits on is {head.width} x {head.reach}: it overhangs.`
			)
		end

		basket.Parent = parent
		placeCentred(basket, origin * CFrame.new(0, lift, side * along) * turn)

		-- Says it WORKED, not just that it did not crash. Two silent failures in
		-- a row got past a function that only spoke up when it broke.
		print(`[Scene] basket {slot} placed at {basket:GetPivot().Position}`)

		fillTray(basket, slot, origin, math.abs(standing.X), side * along)
	end)
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

	-- The numbers above are studs against a DEFAULT head, so they move with the
	-- rig. Without this a scaled-up bot wears a fringe sized for somebody else:
	-- too small, and floating where the old forehead used to be.
	local scale = Theme.avatar.scale

	for index, lock in locks do
		local strand = Instance.new("Part")
		strand.Name = `Hair{index}`
		strand.Size = lock.size * scale
		strand.Color = tint
		strand.Material = Enum.Material.SmoothPlastic
		strand.CanCollide = false
		strand.CanQuery = false
		strand.CanTouch = false
		strand.Massless = true
		strand.CFrame = head.CFrame * CFrame.new(lock.offset * scale) * CFrame.Angles(0, 0, lock.tilt)
		strand.Parent = body

		-- Welded rather than positioned once: the body is anchored today, but a
		-- head that ever moves should not leave its hair behind.
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = strand
		weld.Parent = strand
	end
end

--- Makes a rig bigger without making it a different shape.
---
--- All four scales move together on purpose -- see Theme.avatar for why, and
--- for the two that are deliberately left alone.
---
--- It reports what it GOT rather than what it asked for. A place caps avatar
--- scale in Game Settings, which lives outside this repo, and a request past the
--- cap is clamped with no error. Reading the value back is the whole difference
--- between "it did nothing" and "a setting nobody can see from here overrode
--- it" -- two failures that look identical from a screenshot.
local function scaleBody(body: Model, label: string)
	local wanted = Theme.avatar.scale

	local humanoid = body:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		warn(`[Scene] {label}: no Humanoid, so nothing to scale`)
		return
	end

	for _, knobName in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" } do
		local knob = humanoid:FindFirstChild(knobName)
		if knob and knob:IsA("NumberValue") then
			knob.Value = wanted
			if math.abs(knob.Value - wanted) > 0.001 then
				warn(
					`[Scene] {label}: asked {knobName} for {wanted}, got {knob.Value}. `
						.. `The place's avatar scale range in Game Settings is capping it.`
				)
			end
		end
	end
end

--- How high the root has to sit for the feet to reach the ground.
---
--- Derived, where a flat 3 used to be written. 3 is what a DEFAULT R15 works out
--- to, which is why it looked like a constant -- and a scaled rig does not work
--- out to 3, so the number and the scale would have had to be kept in step by
--- hand. Getting it wrong buries a character to the knees or floats it.
local function standHeight(body: Model): number
	local humanoid = body:FindFirstChildWhichIsA("Humanoid")
	local root = body:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
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
	-- Scaled BEFORE it is placed: how high the root goes depends on how big the
	-- rig is, so the order is not cosmetic.
	scaleBody(body, displayName)
	body:PivotTo(CFrame.lookAt(spot.Position + Vector3.new(0, standHeight(body), 0), lookAt))

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

	-- Scaled to match the bot, and before being placed: the root's height
	-- depends on the rig's size.
	--
	-- The scale is NOT put back on the way out, and that is on purpose while
	-- there is nowhere else to be: a duel is the whole game right now. When E1's
	-- lobby lands, `release` is where it goes back to 1.
	scaleBody(character, player.Name)
	character:PivotTo(CFrame.lookAt(spot.Position + Vector3.new(0, standHeight(character), 0), lookAt))
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

	-- One per seat, whether or not anybody is sitting in it yet. They belong to
	-- the duel's model, so they go with the table when it does.
	buildBasket(origin, 1, model)
	buildBasket(origin, 2, model)

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
