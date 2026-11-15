--[[
	Pets (ModuleScript)
	Location: ReplicatedStorage > Shared > Pets

	Rules for owning, equipping, levelling and applying pets. Pure functions.
	The data lives in Config/Pets. Each action returns true, or false plus a
	reason, and changes NOTHING when it fails.

	  Pets.MaxLevel
	  Pets.Level(profile, petId)            -> level (1 if never levelled)
	  Pets.Active(profile)                  -> petId, level   or nil
	  Pets.Mods(petId, level)               -> list of { Stat, Mode, Value } for StatCalc
	  Pets.Describe(petId, level)           -> short text, e.g. "+5% Max Health"
	  Pets.GrantForClear(profile, stage)    -> list of pet ids newly received
	  Pets.Equip(profile, petId)            reasons: "UnknownPet", "NotOwned"
	  Pets.Rank(profile, petId) / Pets.AddDuplicate(profile, petId)   duplicates rank a pet up
	  Pets.SkillId(petId)                   the pet's own skill (cast by its owner; level = rank)
	  Pets.List(profile)                    -> rows for the UI (owned or not)

	The equipped pet is Season.ActivePet when it is still owned; otherwise the
	first owned pet in Config order, so a new season never leaves you petless.
]]

local Config = require(script.Parent.Config.Pets)

local Pets = {}

Pets.MaxLevel = Config.MaxLevel
Pets.Defs = Config.Defs
Pets.Order = Config.Order

local STAT_LABELS = { MaxHealth = "Max Health", Attack = "Attack", Defense = "Defense", CritChance = "Crit Chance", AttackSpeed = "Attack Speed", CritMultiplier = "Crit Damage" }

function Pets.Level(profile, petId)
	local levels = profile.Season.PetLevels or {}
	return math.clamp(levels[petId] or 1, 1, Config.MaxLevel)
end

local function owned(profile, petId)
	return profile.Permanent.Pets ~= nil and profile.Permanent.Pets[petId] == true
end

-- Rank comes from duplicate pulls (permanent). Owning a pet is rank 1.
function Pets.Rank(profile, petId)
	local ranks = profile.Permanent.PetRanks or {}
	return math.clamp(ranks[petId] or 1, 1, Config.MaxRank)
end

function Pets.Active(profile)
	local active = profile.Season.ActivePet
	if type(active) == "string" and Config.Defs[active] and owned(profile, active) then
		return active, Pets.Level(profile, active), Pets.Rank(profile, active)
	end
	for _, petId in ipairs(Config.Order) do
		if owned(profile, petId) then
			return petId, Pets.Level(profile, petId), Pets.Rank(profile, petId)
		end
	end
	return nil
end

-- One stat line of a pet at a level and rank: { Stat, Mode, Value }
local function statValue(def, entry, level, rank)
	local unit = Config.StatUnits[entry.Stat]
	local scale = (Config.RarityMult[def.Rarity] or 1) * entry.Share * (1 + Config.RankBonus * (math.clamp(rank or 1, 1, Config.MaxRank) - 1))
	return unit.Base * scale + unit.PerLevel * scale * (math.clamp(level or 1, 1, Config.MaxLevel) - 1)
end

function Pets.Mods(petId, level, rank)
	local def = Config.Defs[petId]
	if def == nil then
		return {}
	end
	local mods = {}
	for _, entry in ipairs(def.Stats) do
		table.insert(mods, { Stat = entry.Stat, Mode = Config.StatUnits[entry.Stat].Mode, Value = statValue(def, entry, level, rank) })
	end
	return mods
end

-- The id of the pet's own skill (an ability in Config/Abilities), or nil
function Pets.SkillId(petId)
	local def = Config.Defs[petId]
	return if def and def.Skill then "Pet_" .. petId else nil
end

function Pets.Describe(petId, level, rank)
	local def = Config.Defs[petId]
	if def == nil then
		return ""
	end
	local parts = {}
	for _, mod in ipairs(Pets.Mods(petId, level, rank)) do
		local label = STAT_LABELS[mod.Stat] or mod.Stat
		if mod.Mode == "Mul" or mod.Stat == "CritChance" or mod.Stat == "CritMultiplier" then
			table.insert(parts, ("+%.1f%% %s"):format(mod.Value * 100, label))
		else
			table.insert(parts, ("+%d %s"):format(math.floor(mod.Value + 0.5), label))
		end
	end
	return table.concat(parts, ", ")
end

-- A duplicate pull of a pet you own: +1 rank, or pet XP once it is at max rank.
-- Returns "Rank", newRank  or  "XP", amount.
function Pets.AddDuplicate(profile, petId)
	profile.Permanent.PetRanks = profile.Permanent.PetRanks or {}
	local rank = Pets.Rank(profile, petId)
	if rank < Config.MaxRank then
		profile.Permanent.PetRanks[petId] = rank + 1
		return "Rank", rank + 1
	end
	Pets.AddXP(profile, petId, Config.DupFallbackXP)
	return "XP", Config.DupFallbackXP
end

function Pets.GrantForClear(profile, stage)
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	local gained = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		if def.UnlockStage ~= nil and stage >= def.UnlockStage and not profile.Permanent.Pets[petId] then
			profile.Permanent.Pets[petId] = true
			table.insert(gained, petId)
		end
	end
	return gained
end

function Pets.Equip(profile, petId)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	profile.Season.ActivePet = petId
	return true
end

-- Pet XP: pets level up from pet food and from fighting (see Progression). XP to go from level L to L+1
-- is Config.XPPerLevel * L. XP is kept in Season.PetXP[petId], the level in Season.PetLevels[petId].
function Pets.XPToNext(level)
	return Config.XPPerLevel * level
end

function Pets.AddXP(profile, petId, amount)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	local season = profile.Season
	season.PetLevels = season.PetLevels or {}
	season.PetXP = season.PetXP or {}
	local level = Pets.Level(profile, petId)
	if level >= Config.MaxLevel then
		return false, "MaxLevel"
	end
	local xp = (season.PetXP[petId] or 0) + math.max(0, amount or 0)
	local gained = 0
	while level < Config.MaxLevel and xp >= Pets.XPToNext(level) do
		xp -= Pets.XPToNext(level)
		level += 1
		gained += 1
	end
	if level >= Config.MaxLevel then
		xp = 0
	end
	season.PetXP[petId] = xp
	season.PetLevels[petId] = level
	return true, gained
end

function Pets.List(profile)
	local activeId = Pets.Active(profile)
	local rows = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		local level = Pets.Level(profile, petId)
		local rank = Pets.Rank(profile, petId)
		table.insert(rows, {
			Id = petId,
			Name = def.DisplayName,
			Rarity = def.Rarity,
			Owned = owned(profile, petId),
			UnlockStage = def.UnlockStage,
			Wish = def.Wish == true,
			Look = def.Look,
			Level = level,
			MaxLevel = Config.MaxLevel,
			Active = petId == activeId,
			Text = Pets.Describe(petId, level, rank),
			Rank = rank,
			MaxRank = Config.MaxRank,
			Skill = def.Skill and { Id = Pets.SkillId(petId), Name = def.Skill.Name, Text = def.Skill.Text } or nil,
		})
	end
	return rows
end

return Pets
