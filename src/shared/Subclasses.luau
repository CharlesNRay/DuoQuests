--[[
	Subclasses (ModuleScript)
	Location: ReplicatedStorage > Shared > Subclasses

	Rules for choosing a subclass and what it gives. Pure functions; the data is
	in Config/Subclasses. The choice is stored per class and per season:
	Season.Subclasses[classId] = subclassId   (the deepest tier chosen)

	  Subclasses.Chain(subclassId)            -> list of defs from the first tier down to this one
	  Subclasses.Choices(classId, currentId)  -> defs that could be chosen next (any stage)
	  Subclasses.Available(profile, classId)  -> choices already unlocked by the frontier
	  Subclasses.Mods(subclassId)             -> combined list of stat mods for the whole chain
	  Subclasses.SkillIds(subclassId)         -> skills of the whole chain, in order
	  Subclasses.AllSkillIds(classId)         -> every subclass skill of a class (any path)
	  Subclasses.Current(profile, classId)    -> the chosen subclass id or nil
	  Subclasses.Choose(profile, classId, subclassId)
	      -> true, or false + reason: "UnknownSubclass", "WrongClass", "ClassLocked",
	         "NotAvailable" (not a next step from where you are), "Locked" (stage too low)
	  Subclasses.Describe(subclassId)         -> one line of the biggest bonuses for UI

	Choosing grants the first skill of the new tier for free. There is no respec
	yet (a decision for later): the pick lasts for the season.
]]

local Config = require(script.Parent.Config.Subclasses)
local Classes = require(script.Parent.Config.Classes)

local Subclasses = {}

Subclasses.Defs = Config.Defs
Subclasses.Order = Config.Order

function Subclasses.Chain(subclassId)
	local chain = {}
	local guard = 0
	local id = subclassId
	while id ~= nil and Config.Defs[id] ~= nil and guard < 10 do
		table.insert(chain, 1, Config.Defs[id])
		id = Config.Defs[id].Parent
		guard += 1
	end
	return chain
end

function Subclasses.Choices(classId, currentId)
	local parent = currentId or classId
	local list = {}
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		if def.Class == classId and def.Parent == parent then
			table.insert(list, def)
		end
	end
	return list
end

function Subclasses.Current(profile, classId)
	local chosen = profile.Season.Subclasses
	return chosen and chosen[classId] or nil
end

function Subclasses.Available(profile, classId)
	local list = {}
	for _, def in ipairs(Subclasses.Choices(classId, Subclasses.Current(profile, classId))) do
		if profile.Season.HighestStage >= def.UnlockStage then
			table.insert(list, def)
		end
	end
	return list
end

function Subclasses.Mods(subclassId)
	local mods = {}
	for _, def in ipairs(Subclasses.Chain(subclassId)) do
		for _, mod in ipairs(def.Mods) do
			table.insert(mods, mod)
		end
	end
	return mods
end

function Subclasses.SkillIds(subclassId)
	local ids = {}
	for _, def in ipairs(Subclasses.Chain(subclassId)) do
		for _, id in ipairs(def.Skills) do
			table.insert(ids, id)
		end
	end
	return ids
end

function Subclasses.AllSkillIds(classId)
	local ids = {}
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		if def.Class == classId then
			for _, skillId in ipairs(def.Skills) do
				table.insert(ids, skillId)
			end
		end
	end
	return ids
end

function Subclasses.Choose(profile, classId, subclassId)
	local def = type(subclassId) == "string" and Config.Defs[subclassId] or nil
	if def == nil then
		return false, "UnknownSubclass"
	end
	if type(classId) ~= "string" or Classes[classId] == nil or def.Class ~= classId then
		return false, "WrongClass"
	end
	if not profile.Permanent.UnlockedClasses[classId] then
		return false, "ClassLocked"
	end
	local current = Subclasses.Current(profile, classId)
	if def.Parent ~= (current or classId) then
		return false, "NotAvailable"
	end
	if profile.Season.HighestStage < def.UnlockStage then
		return false, "Locked"
	end
	profile.Season.Subclasses = profile.Season.Subclasses or {}
	profile.Season.Subclasses[classId] = subclassId
	profile.Season.OwnedAbilities = profile.Season.OwnedAbilities or {}
	local granted = def.Skills[1]
	if granted then
		profile.Season.OwnedAbilities[granted] = true
	end
	return true
end

local STAT_LABELS = { Attack = "Attack", MaxHealth = "Health", Defense = "Defense", AttackSpeed = "Attack speed", CritChance = "Crit", DamageDealt = "Damage", HealingDealt = "Healing", DamageTaken = "Damage taken" }

function Subclasses.Describe(subclassId)
	local def = Config.Defs[subclassId]
	if def == nil then
		return ""
	end
	local parts = {}
	for _, mod in ipairs(def.Mods) do
		local sign = if mod.Value >= 0 then "+" else ""
		table.insert(parts, ("%s%d%% %s"):format(sign, math.floor(mod.Value * 100 + 0.5), STAT_LABELS[mod.Stat] or mod.Stat))
	end
	return table.concat(parts, ", ")
end

return Subclasses
