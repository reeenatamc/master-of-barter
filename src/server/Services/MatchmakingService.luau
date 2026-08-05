--!strict
--[[
	MatchmakingService.luau -- the queue, and the bot that ends the wait.

	Card D1. This was a TEMP block in Main.server.luau that paired the first two
	players who asked; it moves here and gains the one thing it was missing --
	what to do when there is nobody to pair with.

	The problem D1 exists to kill is the cold start: a player who joins an empty
	server and waits forever leaves, and every player who leaves makes the server
	emptier for the next one (docs/gdd.md §34). So the queue promises a duel
	within `DuelRules.secondsBeforeBot` and keeps that promise with a filler
	opponent when it has to.

	A HUMAN ALWAYS WINS THE RACE. The bot timer is armed per player and goes
	stale the moment a real rival appears, so a bot never takes a match a person
	was about to get -- the queue prefers people and only settles.

	No global matchmaking in the MVP (docs/gdd.md §32, marked 🔒): this queue is
	per server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local DuelRules = require(ReplicatedStorage.Shared.Config.DuelRules)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DuelService = require(script.Parent.DuelService)

local MatchmakingService = {}

local queue: { Player } = {}

--- One bot timer per waiting player, so leaving the queue cancels only your
--- own. Generation-counted like the phase watchdog: a timer whose generation is
--- stale does nothing, which is cheaper and safer than cancelling a live thread.
local waitGeneration: { [Player]: number } = {}

local function leave(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	-- Bumped, not cleared: a timer already in flight compares against this and
	-- finds itself stale.
	waitGeneration[player] = (waitGeneration[player] or 0) + 1
end

--- Pairs everyone who can be paired, oldest first.
local function tryPair()
	while #queue >= 2 do
		local a, b = queue[1], queue[2]
		leave(a)
		leave(b)

		-- A player can leave between joining the queue and being paired.
		if a.Parent and b.Parent then
			if DuelService.start(a, b) then
				print(`[Matchmaking] duel started: {a.Name} vs {b.Name}`)
			end
		end
	end
end

--- Arms this player's promise: a duel within `secondsBeforeBot`, with a filler
--- opponent if nobody has turned up by then.
local function armBotTimer(player: Player)
	waitGeneration[player] = (waitGeneration[player] or 0) + 1
	local generation = waitGeneration[player]

	task.delay(DuelRules.secondsBeforeBot, function()
		-- Stale: they were paired with a person, or they left. Either way this
		-- timer is answering a question nobody is asking any more.
		if waitGeneration[player] ~= generation then
			return
		end
		if not player.Parent or not table.find(queue, player) then
			return
		end

		leave(player)
		if DuelService.startAgainstBot(player) then
			print(`[Matchmaking] {player.Name} waited {DuelRules.secondsBeforeBot}s; filled with a bot`)
		end
	end)
end

function MatchmakingService.join(player: Player)
	if DuelService.isInDuel(player) or table.find(queue, player) then
		return
	end

	table.insert(queue, player)
	print(`[Matchmaking] {player.Name} joined the queue ({#queue} waiting)`)

	-- Pairing first: with somebody already waiting this resolves immediately and
	-- no timer gets armed for either of them.
	tryPair()

	if table.find(queue, player) then
		armBotTimer(player)
	end
end

function MatchmakingService.leave(player: Player)
	if table.find(queue, player) then
		leave(player)
		print(`[Matchmaking] {player.Name} left the queue ({#queue} waiting)`)
	end
end

function MatchmakingService.init()
	Net.get(Net.names.QueueJoin).OnServerEvent:Connect(function(player: Player)
		MatchmakingService.join(player)
	end)

	Net.get(Net.names.QueueLeave).OnServerEvent:Connect(function(player: Player)
		MatchmakingService.leave(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		leave(player)
		waitGeneration[player] = nil
	end)
end

return MatchmakingService
