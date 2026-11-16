--[[
	ProfileTemplate (ModuleScript)
	Location: ReplicatedStorage > Shared > ProfileTemplate

	Defines the shape of a player profile. The profile has two clearly
	separated sections:

	  Permanent  - survives season resets (classes, pets, cosmetics, titles,
	               achievements, Legacy Points and upgrades, season history)
	  Season     - wiped at the start of every new season

	Skills live in the Season section (skills are class-locked, and ownership,
	loadouts and levels all reset each season):
	  OwnedAbilities { [abilityId] = true }  skills the player has unlocked
	  Loadouts       { [classId] = { id, id, id, id } }  equipped skills per
	                 class, in priority order (validate with Skills.ValidateLoadout)
	  SlotLevels     { [classId] = { n, n, n, n } }  level of each slot. LEVELS
	                 BELONG TO THE SLOT, so swapping the skill in a slot keeps it.
	  PassiveLoadouts / PassiveSlotLevels  the same idea for passives (up to 3
	                 slots, unlocked by reaching stages; see Shared/Passives)

	Rules:
	  * Bump CURRENT_VERSION whenever you change the shape in a way that needs
	    converting old data, and add a migration in DataService.
	  * Adding a brand-new field with a default needs no migration: loading
	    fills missing fields from Defaults() automatically.
	  * DataStores cannot store nil, so optional fields (Permanent.PartyId,
	    Season.SubclassId) are simply absent until they are set.
	  * New() = Defaults() plus the starter skills. Only Defaults() is used to
	    fill in missing fields on load, so starter skills are never re-granted.

	Version history
	  1  first schema
	  2  skills: OwnedAbilities, per-class Loadouts and SlotLevels replace
	     AbilityLevels/EquippedAbilities; every unlocked class owns and equips
	     its starter skills
	  3  passives: PassiveLoadouts and PassiveSlotLevels per class; every
	     unlocked class starts with its first passive equipped
]]

local Seasons = require(script.Parent.Config.Seasons)
local Skills = require(script.Parent.Skills)
local Passives = require(script.Parent.Passives)

local ProfileTemplate = {}

ProfileTemplate.CURRENT_VERSION = 3

-- A fresh seasonal section. Also used by the season reset later.
function ProfileTemplate.NewSeasonData(seasonId)
	return {
		SeasonId = seasonId,

		ClassId = "Warrior", -- SubclassId is added here once subclasses exist
		Level = 1,
		XP = 0,

		Currencies = {
			Gold = 0, -- levels skill slots
			Shards = 0, -- Skill Shards: unlock skills of your choice
			Wishstones = 0, -- the Wishing Tree currency (pets and skills), earned from clearing stages
			SkillPicks = 0, -- free skill unlocks from first-clearing boss stages
		},

		Equipment = {
			Equipped = {}, -- [slotName] = item
			Inventory = {}, -- list of items
		},
		Stash = {}, -- [consumableId] = count (see Consumables)
		Buffs = {}, -- [consumableId] = os.time() the boost ends
		PetXP = {}, -- [petId] = xp towards the next pet level
		OwnedAbilities = {}, -- [abilityId] = true
		SkillState = {}, -- [abilityId] = { Tier, Rank, XP, Pending? } (see SkillProgress; no entry = rank 1 at base rarity)
		Loadouts = {}, -- [classId] = equipped ability ids, priority order
		SlotLevels = {}, -- [classId] = level per slot position
		PassiveLoadouts = {}, -- [classId] = equipped passive ids (see Passives)
		PassiveSlotLevels = {}, -- [classId] = level per passive slot
		PetLevels = {}, -- [petId] = level (pet OWNERSHIP is permanent)
		Subclasses = {}, -- [classId] = chosen subclass id (see Subclasses)

		HighestStage = 1, -- the frontier: furthest stage unlocked, never lowered
		StageRewardsClaimed = {}, -- [stage] = true, one-time milestone ledger
	}
end

-- Gives one class its starter skills and equips them in level 1 slots.
-- Skills already owned stay owned, and an existing loadout or slot levels are
-- left alone.
function ProfileTemplate.GrantClassStarters(season, classId)
	season.OwnedAbilities = season.OwnedAbilities or {}
	season.Loadouts = season.Loadouts or {}
	season.SlotLevels = season.SlotLevels or {}
	season.PassiveLoadouts = season.PassiveLoadouts or {}
	season.PassiveSlotLevels = season.PassiveSlotLevels or {}

	-- Passives: the class's first passive starts equipped in a level 1 slot.
	if season.PassiveLoadouts[classId] == nil then
		season.PassiveLoadouts[classId] = { Passives.Pool(classId)[1] }
	end
	if season.PassiveSlotLevels[classId] == nil then
		local passiveLevels = {}
		for index = 1, Passives.SLOTS do
			passiveLevels[index] = 1
		end
		season.PassiveSlotLevels[classId] = passiveLevels
	end

	local starters = Skills.StarterAbilities(classId)
	for _, abilityId in ipairs(starters) do
		season.OwnedAbilities[abilityId] = true
	end
	if season.Loadouts[classId] == nil then
		season.Loadouts[classId] = starters
	end
	if season.SlotLevels[classId] == nil then
		local levels = {}
		for index = 1, Skills.SLOTS do
			levels[index] = 1
		end
		season.SlotLevels[classId] = levels
	end
end

-- Starter skills for every class the player has unlocked.
function ProfileTemplate.GrantStarterAbilities(profile)
	for classId, unlocked in pairs(profile.Permanent.UnlockedClasses) do
		if unlocked then
			ProfileTemplate.GrantClassStarters(profile.Season, classId)
		end
	end
end

-- Structure with default values and NO starter skills. DataService uses this
-- to fill in fields that older saved profiles are missing.
function ProfileTemplate.Defaults()
	return {
		SchemaVersion = ProfileTemplate.CURRENT_VERSION,

		Meta = {
			CreatedAt = os.time(),
			LastSaveAt = 0,
			LastLogoutAt = 0, -- used for offline idle rewards
		},

		Permanent = {
			UnlockedClasses = { Warrior = true, Cleric = true },
			Pets = {}, -- [petId] = true
			Cosmetics = {}, -- [cosmeticId] = true (see Config/Cosmetics)
			CosmeticsEquipped = {}, -- [slot] = cosmetic id, or the title text for Title
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

-- A brand-new player's profile.
function ProfileTemplate.New()
	local profile = ProfileTemplate.Defaults()
	ProfileTemplate.GrantStarterAbilities(profile)
	return profile
end

return ProfileTemplate
