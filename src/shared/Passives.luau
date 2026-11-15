--[[
	Passives (ModuleScript)
	Location: ReplicatedStorage > Shared > Passives

	Rules for equipping, levelling and applying passives. Pure functions.
	The data lives in Config/Passives.

	  Passives.SLOTS                          max equipped (3)
	  Passives.SlotsAt(frontier)              how many slots that frontier has unlocked
	  Passives.Pool(classId)                  the class's passives, display order
	  Passives.IsUnlocked(passiveId, frontier)
	  Passives.ValidateLoadout(classId, ids, frontier)
	      -> true, or false + reason: "NotAList", "TooMany", "Duplicate",
	         "UnknownPassive", "WrongClass", "Locked"
	  Passives.ModValue(mod, level)           value of one modifier at a level
	  Passives.Resolve(classId, ids, levels)  -> { Combat = list, Rewards = table }
	  Passives.Rewards(classId, ids, levels)  -> { GoldGain, XPGain, ItemRarity }
	  Passives.Rows(passiveId, level)         -> { { Label, Value } } for UI

	Levels belong to the SLOT (Season.PassiveSlotLevels[classId][slot]) and use
	the same cap as skills.
]]

local Classes = require(script.Parent.Config.Classes)
local Config = require(script.Parent.Config.Passives)
local Skills = require(script.Parent.Skills)

local Passives = {}

Passives.SLOTS = Config.Slots

local REWARD_STATS = { GoldGain = true, XPGain = true, ItemRarity = true }

function Passives.SlotsAt(frontier)
	local slots = 0
	for _, unlock in ipairs(Config.SlotUnlocks) do
		if (frontier or 1) >= unlock.Stage then
			slots = math.max(slots, unlock.Slots)
		end
	end
	return math.min(slots, Passives.SLOTS)
end

function Passives.Pool(classId)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))
	return table.clone(class.PassivePool or {})
end

function Passives.IsUnlocked(passiveId, frontier)
	local def = Config.Defs[passiveId]
	return def ~= nil and (frontier or 1) >= (def.UnlockStage or 1)
end

function Passives.ValidateLoadout(classId, passiveIds, frontier)
	local class = Classes[classId]
	if class == nil then
		return false, "UnknownClass"
	end
	if type(passiveIds) ~= "table" then
		return false, "NotAList"
	end
	if #passiveIds > Passives.SlotsAt(frontier) then
		return false, "TooMany"
	end
	local seen = {}
	for _, passiveId in ipairs(passiveIds) do
		if type(passiveId) ~= "string" or Config.Defs[passiveId] == nil then
			return false, "UnknownPassive"
		end
		if seen[passiveId] then
			return false, "Duplicate"
		end
		seen[passiveId] = true
		if not table.find(class.PassivePool or {}, passiveId) then
			return false, "WrongClass"
		end
		if not Passives.IsUnlocked(passiveId, frontier) then
			return false, "Locked"
		end
	end
	return true
end

function Passives.ModValue(mod, level)
	return mod.Base + (mod.PerLevel or 0) * (Skills.ClampSlotLevel(level) - 1)
end

-- Every modifier of every equipped passive, split into combat modifiers and
-- reward totals. Unknown ids are skipped.
function Passives.Resolve(classId, passiveIds, levels)
	local combat = {}
	local rewards = { GoldGain = 0, XPGain = 0, ItemRarity = 0 }
	for slot, passiveId in ipairs(passiveIds or {}) do
		local def = Config.Defs[passiveId]
		if def ~= nil and def.Class == classId then
			local level = if levels then levels[slot] or 1 else 1
			for _, mod in ipairs(def.Mods) do
				local value = Passives.ModValue(mod, level)
				if REWARD_STATS[mod.Stat] then
					rewards[mod.Stat] += value
				else
					table.insert(combat, { Stat = mod.Stat, Mode = mod.Mode, Value = value })
				end
			end
		end
	end
	return { Combat = combat, Rewards = rewards }
end

function Passives.Rewards(classId, passiveIds, levels)
	return Passives.Resolve(classId, passiveIds, levels).Rewards
end

local function pct(value)
	return string.format("%+.1f%%", value * 100)
end

local STAT_LABELS = {
	MaxHealth = "Max health",
	Attack = "Attack",
	Defense = "Defense",
	AttackSpeed = "Attack speed",
	CritChance = "Crit chance",
	DamageDealt = "Damage dealt",
	HealingDealt = "Healing done",
	DamageTaken = "Damage taken",
	GoldGain = "Gold gained",
	XPGain = "XP gained",
	ItemRarity = "Item rarity",
}

function Passives.Rows(passiveId, level)
	local def = Config.Defs[passiveId]
	assert(def ~= nil, "Unknown passive: " .. tostring(passiveId))
	local rows = {}
	for _, mod in ipairs(def.Mods) do
		table.insert(rows, { Label = STAT_LABELS[mod.Stat] or mod.Stat, Value = pct(Passives.ModValue(mod, level)) })
	end
	return rows
end

return Passives
