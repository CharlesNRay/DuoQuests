--[[
	StatCalc (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > StatCalc

	Builds combatants from config. Equipment, pets, Legacy bonuses and season
	modifiers will add their contributions here later, so the rest of combat
	never needs to know where a stat came from.
]]

local Classes = require(script.Parent.Parent.Config.Classes)
local Enemies = require(script.Parent.Parent.Config.Enemies)
local Skills = require(script.Parent.Parent.Skills)
local Passives = require(script.Parent.Parent.Passives)
local Pets = require(script.Parent.Parent.Pets)
local Gear = require(script.Parent.Parent.Gear)
local Subclasses = require(script.Parent.Parent.Subclasses)
local SubclassConfig = require(script.Parent.Parent.Config.Subclasses)
local Minions = require(script.Parent.Parent.Config.Minions)
local Entity = require(script.Parent.Entity)
local EconomyConfig = require(script.Parent.Parent.Config.Economy)

local StatCalc = {}

-- Base class stats plus per-level growth.
function StatCalc.ClassStats(classId, level, subclassId)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))

	local stats = {}
	for statName, baseValue in pairs(class.BaseStats) do
		local growth = class.GrowthPerLevel[statName] or 0
		stats[statName] = baseValue + growth * (level - 1) * (EconomyConfig.LevelGrowth or 1)
	end
	-- a path changes what each level after choosing it gives (offence paths: more Attack, less Health and Defense, and so on)
	for _, def in ipairs(Subclasses.Chain(subclassId)) do
		local mults = SubclassConfig.Growth[def.Id]
		if mults then
			local levels = math.max(0, level - def.UnlockLevel)
			for statName, mult in pairs(mults) do
				local growth = class.GrowthPerLevel[statName] or 0
				stats[statName] = (stats[statName] or 0) + growth * (mult - 1) * levels * (EconomyConfig.LevelGrowth or 1)
			end
		end
	end
	-- low-level heroes are weaker (see Economy.EarlyWeak)
	local weak = EconomyConfig.EarlyWeak
	if weak then
		local factor = weak.Start + (1 - weak.Start) * math.clamp((level - 1) / math.max(weak.FullLevel - 1, 1), 0, 1)
		for _, statName in ipairs({ "MaxHealth", "Attack", "Defense" }) do
			if stats[statName] then
				stats[statName] *= factor
			end
		end
	end
	return stats
end

-- The skill slots a combatant fights with, in priority order.
--   abilityIds     ordered list of up to four ability ids; defaults to the
--                  class's DefaultLoadout. The server passes the player's
--                  validated Season.Loadouts[classId].
--   slotLevels     optional list of levels BY SLOT POSITION (the player's
--                  Season.SlotLevels[classId]); clamped to 1..MAX_SLOT_LEVEL.
--                  Levels belong to the slot, not the skill in it.
function StatCalc.ClassAbilities(classId, abilityIds, slotLevels)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))

	local slots = {}
	for index, abilityId in ipairs(abilityIds or class.DefaultLoadout) do
		local level = if slotLevels then slotLevels[index] else nil
		table.insert(slots, { Id = abilityId, Level = Skills.ClampSkillLevel(level or 1) })
	end
	return slots
end

-- A pet's own skill is cast by its owner as one more ability (after the equipped skills, so it never
-- takes priority); its level is the pet's rank.
function StatCalc.WithPetSkill(slots, petId, rank)
	local skillId = petId and Pets.SkillId(petId)
	if skillId then
		table.insert(slots, { Id = skillId, Level = Skills.ClampSkillLevel(rank or 1) })
	end
	local def = petId and Pets.Defs[petId]
	if def then -- every pet also fights: a steady strike scaled by its rarity and rank
		table.insert(slots, { Id = "Pet_Strike_" .. def.Rarity, Level = Skills.ClampSkillLevel(rank or 1), Timer = 1.5 })
	end
	return slots
end

-- Stats that default to 1 when a class does not list them (see Simulation).
local MULTIPLIER_STATS = { PetDamage = true, DamageDealt = true, HealingDealt = true, DamageTaken = true }

-- Folds modifiers (passives, pets) into base stats before the fight starts.
local function applyMods(stats, mods)
	for _, mod in ipairs(mods) do
		local current = stats[mod.Stat]
		if current == nil then
			current = if MULTIPLIER_STATS[mod.Stat] then 1 elseif mod.Stat == "CritMultiplier" then 1.5 else 0
		end
		if mod.Mode == "Add" then
			stats[mod.Stat] = current + mod.Value
		else
			stats[mod.Stat] = current * (1 + mod.Value)
		end
	end
end

local function applyPassives(stats, classId, passiveIds, passiveLevels)
	applyMods(stats, Passives.Resolve(classId, passiveIds, passiveLevels).Combat)
end

-- options (all optional): AbilityIds, SlotLevels, PassiveIds, PassiveLevels, PetId, PetLevel,
-- Equipped (gear: { [slot] = item }), SubclassId, ExtraMods (list of { Stat, Mode, Value })
function StatCalc.NewPartyMember(id, name, classId, level, options)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))
	options = options or {}

	local stats = StatCalc.ClassStats(classId, level, options.SubclassId)
	applyPassives(stats, classId, options.PassiveIds, options.PassiveLevels)
	if options.SubclassId then
		applyMods(stats, Subclasses.Mods(options.SubclassId))
	end
	if options.Equipped then
		applyMods(stats, Gear.Mods(options.Equipped))
	end
	if options.PetId then
		applyMods(stats, Pets.Mods(options.PetId, options.PetLevel, options.PetRank))
		local boost = if options.SubclassId then Subclasses.PetBoost(options.SubclassId) else nil
		if boost and boost.Stats > 0 then -- Beastmaster: the pet's stat bonuses are worth more
			local extra = {}
			for _, mod in ipairs(Pets.Mods(options.PetId, options.PetLevel, options.PetRank)) do
				table.insert(extra, { Stat = mod.Stat, Mode = mod.Mode, Value = mod.Value * boost.Stats })
			end
			applyMods(stats, extra)
		end
	end
	if options.ExtraMods then
		applyMods(stats, options.ExtraMods) -- timed boosts from consumables
	end

	return Entity.new({
		Id = id,
		Name = name,
		Team = "Party",
		DefId = classId,
		PetId = options.PetId,
		DamageType = class.DamageType,
		BasicAttack = class.BasicAttack,
		Stats = stats,
		Abilities = StatCalc.WithPetSkill(StatCalc.ClassAbilities(classId, options.AbilityIds, options.SlotLevels), options.PetId, (options.PetRank or 1) + (if options.SubclassId then Subclasses.PetBoost(options.SubclassId).SkillLevels else 0)),
	})
end

-- `scale` multiplies MaxHealth and Attack (stage difficulty comes later).
function StatCalc.NewEnemy(id, enemyId, scale, healthMult, attackMult)
	local enemy = Enemies[enemyId]
	assert(enemy ~= nil, "Unknown enemy: " .. tostring(enemyId))
	scale = scale or 1

	local stats = table.clone(enemy.BaseStats)
	stats.MaxHealth = math.floor(stats.MaxHealth * scale * (healthMult or 1))
	stats.Attack = stats.Attack * scale * (attackMult or 1)

	local entity = Entity.new({
		Id = id,
		Name = enemy.DisplayName,
		Team = "Enemy",
		DefId = enemyId,
		DamageType = enemy.DamageType,
		Stats = stats,
		Abilities = enemy.Abilities,
	})
	entity.Flags.StunImmune = enemy.IsBoss == true
	entity.Scale = scale -- summons copy their summoner's scale
	entity.AttackMult = attackMult -- and its fight-length attack factor (Config/Stages FightLength)
	return entity
end

-- A creature raised by `owner` (a living Entity). `statOf(entity, name)` reads current stats (Simulation.GetStat); power multiplies it all.
function StatCalc.NewMinion(id, minionId, owner, statOf, power)
	local def = Minions[minionId]
	assert(def ~= nil, "Unknown minion: " .. tostring(minionId))
	power = power or 1
	local healthPower = power * (EconomyConfig.MinionHealthScale or 1)
	local attackPower = power * (EconomyConfig.MinionScale or 1) -- MinionScale trims damage; MinionHealthScale trims health less, so summons live long enough to tank
	local entity = Entity.new({
		Id = id,
		Name = def.DisplayName,
		Team = owner.Team,
		DefId = minionId,
		DamageType = def.DamageType,
		Stats = {
			MaxHealth = math.max(8, math.floor(statOf(owner, "MaxHealth") * def.HealthFrac * healthPower + 0.5)),
			Attack = math.max(1, statOf(owner, "Attack") * def.AttackFrac * attackPower),
			Defense = statOf(owner, "Defense") * def.DefenseFrac,
			AttackSpeed = def.AttackSpeed,
			CritChance = 0,
		},
		Abilities = def.Abilities,
	})
	entity.Minion = true
	entity.OwnerId = owner.Id
	entity.Leech = def.Leech
	entity.Lifetime = def.Lifetime or 20
	return entity
end

return StatCalc
