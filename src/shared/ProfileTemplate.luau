--[[
	ProfileTemplate (ModuleScript)
	Location: ReplicatedStorage > Shared > ProfileTemplate

	Defines the shape of a player profile. The profile has two clearly
	separated sections:

	  Permanent  - survives season resets (classes, pets, cosmetics, titles,
	               achievements, Legacy Points and upgrades, season history)
	  Season     - wiped at the start of every new season

	Rules:
	  * Bump CURRENT_VERSION whenever you change the shape in a way that needs
	    converting old data, and add a migration in DataService.
	  * Adding a brand-new field with a default needs no migration: loading
	    fills missing fields from this template automatically.
	  * DataStores cannot store nil, so optional fields (Permanent.PartyId,
	    Season.SubclassId) are simply absent until they are set.
]]

local Shared = script.Parent
local Seasons = require(Shared.Config.Seasons)

local ProfileTemplate = {}

ProfileTemplate.CURRENT_VERSION = 1

-- A fresh seasonal section. Also used by the season reset later.
function ProfileTemplate.NewSeasonData(seasonId)
	return {
		SeasonId = seasonId,

		ClassId = "Warrior", -- SubclassId is added here once subclasses exist
		Level = 1,
		XP = 0,

		Currencies = {
			Gold = 0,
		},

		Equipment = {
			Equipped = {}, -- [slotName] = item
			Inventory = {}, -- list of items
		},
		AbilityLevels = {}, -- [abilityId] = level
		EquippedAbilities = {}, -- up to four ability IDs
		PetLevels = {}, -- [petId] = level (pet OWNERSHIP is permanent)

		HighestStage = 1, -- personal seasonal record, never lowered
		StageRewardsClaimed = {}, -- [stage] = true, anti-duplication ledger
	}
end

function ProfileTemplate.New()
	return {
		SchemaVersion = ProfileTemplate.CURRENT_VERSION,

		Meta = {
			CreatedAt = os.time(),
			LastSaveAt = 0,
			LastLogoutAt = 0, -- used for offline idle rewards
		},

		Permanent = {
			UnlockedClasses = { Warrior = true, Mage = true },
			Pets = {}, -- [petId] = true
			Cosmetics = {},
			Titles = {},
			Achievements = {},
			LegacyPoints = 0,
			LegacyUpgrades = {}, -- [upgradeId] = rank
			SeasonHistory = {}, -- archived summaries of finished seasons
			-- PartyId is added when the player joins a party
		},

		Season = ProfileTemplate.NewSeasonData(Seasons.CurrentSeasonId),
	}
end

return ProfileTemplate
