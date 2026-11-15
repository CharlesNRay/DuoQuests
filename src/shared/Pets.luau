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
	  Pets.LevelCost(level)                 -> gold to go from level to level+1
	  Pets.Describe(petId, level)           -> short text, e.g. "+5% Max Health"
	  Pets.GrantForClear(profile, stage)    -> list of pet ids newly received
	  Pets.Equip(profile, petId)            reasons: "UnknownPet", "NotOwned"
	  Pets.LevelUp(profile, petId)          reasons: "UnknownPet", "NotOwned",
	                                        "MaxLevel", "NotEnough"
	  Pets.List(profile)                    -> rows for the UI (owned or not)

	The equipped pet is Season.ActivePet when it is still owned; otherwise the
	first owned pet in Config order, so a new season never leaves you petless.
]]

local Config = require(script.Parent.Config.Pets)

local Pets = {}

Pets.MaxLevel = Config.MaxLevel
Pets.Defs = Config.Defs
Pets.Order = Config.Order

local STAT_LABELS = { MaxHealth = "Max Health", Attack = "Attack", Defense = "Defense", CritChance = "Crit Chance" }

function Pets.Level(profile, petId)
	local levels = profile.Season.PetLevels or {}
	return math.clamp(levels[petId] or 1, 1, Config.MaxLevel)
end

local function owned(profile, petId)
	return profile.Permanent.Pets ~= nil and profile.Permanent.Pets[petId] == true
end

function Pets.Active(profile)
	local active = profile.Season.ActivePet
	if type(active) == "string" and Config.Defs[active] and owned(profile, active) then
		return active, Pets.Level(profile, active)
	end
	for _, petId in ipairs(Config.Order) do
		if owned(profile, petId) then
			return petId, Pets.Level(profile, petId)
		end
	end
	return nil
end

local function valueAt(bonus, level)
	return bonus.Base + bonus.PerLevel * (level - 1)
end

function Pets.Mods(petId, level)
	local def = Config.Defs[petId]
	if def == nil then
		return {}
	end
	local bonus = def.Bonus
	return { { Stat = bonus.Stat, Mode = bonus.Mode, Value = valueAt(bonus, math.clamp(level or 1, 1, Config.MaxLevel)) } }
end

function Pets.LevelCost(level)
	return Config.LevelCostPerLevel * level
end

function Pets.Describe(petId, level)
	local def = Config.Defs[petId]
	if def == nil then
		return ""
	end
	local value = valueAt(def.Bonus, math.clamp(level or 1, 1, Config.MaxLevel))
	local label = STAT_LABELS[def.Bonus.Stat] or def.Bonus.Stat
	if def.Bonus.Mode == "Mul" or def.Bonus.Stat == "CritChance" then
		return ("+%d%% %s"):format(math.floor(value * 100 + 0.5), label)
	end
	return ("+%d %s"):format(math.floor(value + 0.5), label)
end

function Pets.GrantForClear(profile, stage)
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	local gained = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		if stage >= def.UnlockStage and not profile.Permanent.Pets[petId] then
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

function Pets.LevelUp(profile, petId)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	local level = Pets.Level(profile, petId)
	if level >= Config.MaxLevel then
		return false, "MaxLevel"
	end
	local cost = Pets.LevelCost(level)
	if profile.Season.Currencies.Gold < cost then
		return false, "NotEnough"
	end
	profile.Season.Currencies.Gold -= cost
	profile.Season.PetLevels = profile.Season.PetLevels or {}
	profile.Season.PetLevels[petId] = level + 1
	return true
end

function Pets.List(profile)
	local activeId = Pets.Active(profile)
	local rows = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		local level = Pets.Level(profile, petId)
		table.insert(rows, {
			Id = petId,
			Name = def.DisplayName,
			Rarity = def.Rarity,
			Owned = owned(profile, petId),
			UnlockStage = def.UnlockStage,
			Level = level,
			MaxLevel = Config.MaxLevel,
			Active = petId == activeId,
			Text = Pets.Describe(petId, level),
			Cost = if level < Config.MaxLevel then Pets.LevelCost(level) else nil,
		})
	end
	return rows
end

return Pets
