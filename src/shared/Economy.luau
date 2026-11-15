--[[
	Economy (ModuleScript)
	Location: ReplicatedStorage > Shared > Economy

	Spending actions on a profile. Each one validates everything itself and
	returns true, or false plus a reason, and changes NOTHING when it fails.
	The server calls these when a client asks; the client can never grant itself
	anything.

	  Economy.UnlockCost(abilityId)                       -> shards
	  Economy.SlotLevelCost(level)                        -> gold to go from level to level+1
	  Economy.UnlockAbility(profile, classId, abilityId)  pay shards
	  Economy.UnlockAbilityWithPick(profile, classId, abilityId)  use one free skill pick
	  Economy.LevelSlot(profile, classId, slotIndex)      pay gold
	  Economy.Equip(profile, classId, abilityIds)         set the loadout (exactly Skills.SLOTS)
	  Economy.PassiveSlotLevelCost(level)                 -> gold
	  Economy.LevelPassiveSlot(profile, classId, slot)    pay gold
	  Economy.EquipPassives(profile, classId, passiveIds) up to the unlocked slots; may be empty

	Reasons: "UnknownClass", "ClassLocked", "NotInPool", "AlreadyOwned",
	"NotEnough", "BadSlot", "MaxLevel", "NotOwned" and the Skills.ValidateLoadout
	reasons.
]]

local Abilities = require(script.Parent.Config.Abilities)
local Classes = require(script.Parent.Config.Classes)
local Config = require(script.Parent.Config.Economy)
local Skills = require(script.Parent.Skills)
local Passives = require(script.Parent.Passives)
local Subclasses = require(script.Parent.Subclasses)

local Economy = {}

function Economy.UnlockCost(abilityId)
	local def = Abilities[abilityId]
	assert(def ~= nil, "Unknown ability: " .. tostring(abilityId))
	local cost = Config.UnlockCost[def.Rarity]
	assert(cost ~= nil, "No unlock cost for rarity " .. tostring(def.Rarity))
	return cost
end

function Economy.SlotLevelCost(level)
	return Config.SlotCostPerLevel * level
end

-- Shared checks for the two unlock paths.
local function checkUnlock(profile, classId, abilityId)
	if type(classId) ~= "string" or Classes[classId] == nil then
		return false, "UnknownClass"
	end
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, "ClassLocked"
	end
	local allowed = type(abilityId) == "string"
		and (table.find(Classes[classId].AbilityPool, abilityId) ~= nil
			or table.find(Subclasses.SkillIds(Subclasses.Current(profile, classId)), abilityId) ~= nil)
	if not allowed then
		return false, "NotInPool"
	end
	if profile.Season.OwnedAbilities[abilityId] then
		return false, "AlreadyOwned"
	end
	return true
end

function Economy.UnlockAbility(profile, classId, abilityId)
	local ok, reason = checkUnlock(profile, classId, abilityId)
	if not ok then
		return false, reason
	end
	local cost = Economy.UnlockCost(abilityId)
	local currencies = profile.Season.Currencies
	if currencies.Shards < cost then
		return false, "NotEnough"
	end
	currencies.Shards -= cost
	profile.Season.OwnedAbilities[abilityId] = true
	return true
end

function Economy.UnlockAbilityWithPick(profile, classId, abilityId)
	local ok, reason = checkUnlock(profile, classId, abilityId)
	if not ok then
		return false, reason
	end
	local currencies = profile.Season.Currencies
	if currencies.SkillPicks < 1 then
		return false, "NotEnough"
	end
	currencies.SkillPicks -= 1
	profile.Season.OwnedAbilities[abilityId] = true
	return true
end

function Economy.LevelSlot(profile, classId, slotIndex)
	if type(classId) ~= "string" or Classes[classId] == nil then
		return false, "UnknownClass"
	end
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, "ClassLocked"
	end
	local levels = profile.Season.SlotLevels[classId]
	if levels == nil or type(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > Skills.SLOTS then
		return false, "BadSlot"
	end
	local level = levels[slotIndex]
	if level >= Skills.MAX_SLOT_LEVEL then
		return false, "MaxLevel"
	end
	local cost = Economy.SlotLevelCost(level)
	local currencies = profile.Season.Currencies
	if currencies.Gold < cost then
		return false, "NotEnough"
	end
	currencies.Gold -= cost
	levels[slotIndex] = level + 1
	return true
end

function Economy.Equip(profile, classId, abilityIds)
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, if Classes[classId] == nil then "UnknownClass" else "ClassLocked"
	end
	local ok, reason = Skills.ValidateLoadout(classId, abilityIds, profile.Season.OwnedAbilities)
	if not ok then
		return false, reason
	end
	if #abilityIds ~= Skills.SLOTS then
		return false, "NeedFullLoadout"
	end
	profile.Season.Loadouts[classId] = table.clone(abilityIds)
	return true
end

function Economy.PassiveSlotLevelCost(level)
	return Config.PassiveCostPerLevel * level
end

function Economy.LevelPassiveSlot(profile, classId, slotIndex)
	if type(classId) ~= "string" or Classes[classId] == nil then
		return false, "UnknownClass"
	end
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, "ClassLocked"
	end
	local levels = profile.Season.PassiveSlotLevels[classId]
	local slots = Passives.SlotsAt(profile.Season.HighestStage)
	if levels == nil or type(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > slots then
		return false, "BadSlot"
	end
	local level = levels[slotIndex]
	if level >= Skills.MAX_SLOT_LEVEL then
		return false, "MaxLevel"
	end
	local cost = Economy.PassiveSlotLevelCost(level)
	local currencies = profile.Season.Currencies
	if currencies.Gold < cost then
		return false, "NotEnough"
	end
	currencies.Gold -= cost
	levels[slotIndex] = level + 1
	return true
end

function Economy.EquipPassives(profile, classId, passiveIds)
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, if Classes[classId] == nil then "UnknownClass" else "ClassLocked"
	end
	local ok, reason = Passives.ValidateLoadout(classId, passiveIds, profile.Season.HighestStage)
	if not ok then
		return false, reason
	end
	profile.Season.PassiveLoadouts[classId] = table.clone(passiveIds)
	return true
end

return Economy
