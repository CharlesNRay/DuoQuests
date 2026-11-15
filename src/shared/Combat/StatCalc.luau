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
local Entity = require(script.Parent.Entity)

local StatCalc = {}

-- Base class stats plus per-level growth.
function StatCalc.ClassStats(classId, level)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))

	local stats = {}
	for statName, baseValue in pairs(class.BaseStats) do
		local growth = class.GrowthPerLevel[statName] or 0
		stats[statName] = baseValue + growth * (level - 1)
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
		table.insert(slots, { Id = abilityId, Level = Skills.ClampSlotLevel(level or 1) })
	end
	return slots
end

-- Stats that default to 1 when a class does not list them (see Simulation).
local MULTIPLIER_STATS = { DamageDealt = true, HealingDealt = true, DamageTaken = true }

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

	local stats = StatCalc.ClassStats(classId, level)
	applyPassives(stats, classId, options.PassiveIds, options.PassiveLevels)
	if options.SubclassId then
		applyMods(stats, Subclasses.Mods(options.SubclassId))
	end
	if options.Equipped then
		applyMods(stats, Gear.Mods(options.Equipped))
	end
	if options.PetId then
		applyMods(stats, Pets.Mods(options.PetId, options.PetLevel))
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
		Abilities = StatCalc.ClassAbilities(classId, options.AbilityIds, options.SlotLevels),
	})
end

-- `scale` multiplies MaxHealth and Attack (stage difficulty comes later).
function StatCalc.NewEnemy(id, enemyId, scale)
	local enemy = Enemies[enemyId]
	assert(enemy ~= nil, "Unknown enemy: " .. tostring(enemyId))
	scale = scale or 1

	local stats = table.clone(enemy.BaseStats)
	stats.MaxHealth = math.floor(stats.MaxHealth * scale)
	stats.Attack = stats.Attack * scale

	local entity = Entity.new({
		Id = id,
		Name = enemy.DisplayName,
		Team = "Enemy",
		DefId = enemyId,
		DamageType = enemy.DamageType,
		Stats = stats,
		Abilities = enemy.Abilities,
	})
	entity.Scale = scale -- summons copy their summoner's scale
	return entity
end

return StatCalc
