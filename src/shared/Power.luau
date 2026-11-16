--[[
	Power (ModuleScript)
	Location: ReplicatedStorage > Shared > Power

	IP ("Item Power") is one number for how strong a hero is. Everything that makes the hero stronger adds to it:
	level, equipped gear (Gear.ItemPower, which already counts rarity, stage and Blacksmith upgrades), equipped skills
	(tier + level), passives, the active pet (rarity, level, rank), the pet collection, the subclass, owned titles and guild
	upgrades. IP never changes combat, it only reports it. Pure functions.

	  Power.Skill(tier, level)           -> IP of one skill at a tier and level
	  Power.Passive(level)               -> IP of one passive at a level
	  Power.Pet(petId, level, rank)      -> IP of one pet
	  Power.Hero(profile)                -> { Total, Level, Gear, Skills, Passives, Pet, Collection, Subclass, Titles, Guild }
]]

local Gear = require(script.Parent.Gear)
local Pets = require(script.Parent.Pets)
local PetConfig = require(script.Parent.Config.Pets)
local SkillProgress = require(script.Parent.SkillProgress)
local Subclasses = require(script.Parent.Subclasses)

local Power = {}

local LEVEL_IP = 5
local SKILL_BASE = { Common = 8, Rare = 14, Epic = 24, Legendary = 40 }
local SKILL_PER_LEVEL = 0.2
local PASSIVE_BASE, PASSIVE_PER_LEVEL = 6, 0.25
local PET_BASE, PET_PER_LEVEL = 12, 0.06
local COLLECTION_IP = 3 -- per collection point
local SUBCLASS_IP = 40
local TITLE_IP = 15
local GUILD_IP = 100 -- per +100% of a guild stat bonus

function Power.Skill(tier, level)
	return math.floor((SKILL_BASE[tier] or SKILL_BASE.Common) * (1 + SKILL_PER_LEVEL * (math.max(level or 1, 1) - 1)) + 0.5)
end

function Power.Passive(level)
	return math.floor(PASSIVE_BASE * (1 + PASSIVE_PER_LEVEL * (math.max(level or 1, 1) - 1)) + 0.5)
end

function Power.Pet(petId, level, rank)
	local def = PetConfig.Defs[petId]
	if def == nil then
		return 0
	end
	local mult = (PetConfig.RarityMult[def.Rarity] or 1) * (def.Power or 1)
	local value = PET_BASE * mult * (1 + PET_PER_LEVEL * (math.max(level or 1, 1) - 1)) * (1 + PetConfig.RankBonus * (math.max(rank or 1, 1) - 1))
	return math.floor(value + 0.5)
end

function Power.Hero(profile)
	local season = profile.Season
	local classId = season.ClassId
	local out = { Level = season.Level * LEVEL_IP, Gear = 0, Skills = 0, Passives = 0, Pet = 0, Collection = 0, Subclass = 0, Titles = 0, Guild = 0 }

	local equipment = season.Equipment and season.Equipment.Equipped or {}
	for _, item in pairs(equipment) do
		out.Gear += Gear.ItemPower(item)
	end

	for _, id in pairs(season.Loadouts[classId] or {}) do
		if id and season.OwnedAbilities[id] then
			local info = SkillProgress.Get(season, id)
			out.Skills += Power.Skill(info.Tier, info.Level)
		end
	end

	local levels = season.PassiveSlotLevels[classId] or {}
	for slot, id in pairs(season.PassiveLoadouts[classId] or {}) do
		if id then
			out.Passives += Power.Passive(levels[slot] or 1)
		end
	end

	local petId, petLevel, petRank = Pets.Active(profile)
	if petId then
		out.Pet = Power.Pet(petId, petLevel, petRank)
	end
	out.Collection = Pets.Collection(profile).Points * COLLECTION_IP

	if Subclasses.Current(profile, classId) then
		out.Subclass = SUBCLASS_IP
	end

	local titles = 0
	for _ in pairs(profile.Permanent.Titles or {}) do
		titles += 1
	end
	out.Titles = titles * TITLE_IP

	local guild = profile.Permanent.GuildBuffs
	if guild and guild.Mods then
		local sum = 0
		for _, mod in ipairs(guild.Mods) do
			sum += math.abs(mod.Value or 0)
		end
		out.Guild = math.floor(sum * GUILD_IP + 0.5)
	end

	local total = 0
	for key, value in pairs(out) do
		out[key] = math.floor(value)
		total += out[key]
	end
	out.Total = total
	return out
end

return Power
