--!strict
--[[
	DataConfig.luau -- the names and numbers of persistence.

	Separate from Economy because these are not balance: changing a store name
	or a key prefix does not tune the game, it points at DIFFERENT SAVED DATA.
	Mixing them into a file people edit to rebalance is how somebody tunes a
	number and orphans every profile in the game.

	Nothing here should change after launch without a plan.
]]

local DataConfig = {}

-- The DataStore name. Changing it after launch abandons every existing
-- profile: same players, empty collections, no error anywhere.
DataConfig.storeName = "PlayerProfiles"

-- Prefixes the key, so keys read as what they are when inspected in the Data
-- Stores Manager instead of as bare user ids.
DataConfig.keyPrefix = "Player_"

-- Schema version, per docs/arquitectura.md §7. Bumping it REQUIRES adding the
-- matching migration in DataService; the code warns loudly if the chain has a
-- hole rather than guessing at the shape.
DataConfig.version = 1

-- Use ProfileStore's mock DataStore while in Studio.
--
-- On: Studio works without publishing and play-tests never touch live data.
-- Session locking still applies, so two sessions fighting over one profile is
-- still testable.
-- Off: Studio talks to the real DataStore, which needs a published place with
-- Game Settings -> Security -> Enable Studio Access to API Services.
--
-- Checkpoint 3 runs BOTH: the mock proves the logic, only the real store
-- proves the DataStore.
DataConfig.useMockInStudio = true

-- Shown when a profile's session ends underneath a player -- almost always
-- because they opened the game somewhere else.
DataConfig.sessionEndedMessage = "Abriste el juego en otro lado. Volvé a entrar acá cuando cierres la otra ventana."

return DataConfig
