--[[
	Skills (ModuleScript)
	Location: ReplicatedStorage > Shared > Skills

	Rules for owning, levelling and equipping skills. Pure functions with no
	Roblox APIs. The server uses these to validate every equip request, since
	the client may only ever ask: "equip these skills in this order".

	  Skills.SLOTS                      number of equipped skills (4)
	  Skills.MAX_SLOT_LEVEL             level cap for every slot (20)
	  Skills.ClampSlotLevel(n)          n limited to 1..MAX_SLOT_LEVEL
	  Skills.Pool(classId)              the class's skills, lowest rarity first
	  Skills.StarterAbilities(classId)  skills a new player owns (default loadout)
	  Skills.ValidateLoadout(classId, abilityIds, owned)
	                                    -> true, or false + reason
	      owned is a table keyed by ability id (Season.OwnedAbilities).
	      reasons: "NotAList", "TooMany", "Duplicate", "UnknownAbility",
	               "WrongClass", "NotOwned"

	A loadout is an ordered list; slot 1 has casting priority. LEVELS BELONG TO
	THE SLOT: a slot keeps its level when a different skill is put in it
	(Season.SlotLevels[classId][slotIndex]). Moving a skill to another slot
	changes its priority and gives it that slot's level.
]]

local Abilities = require(script.Parent.Config.Abilities)
local Classes = require(script.Parent.Config.Classes)
local Rarities = require(script.Parent.Config.Rarities)

local Skills = {}

Skills.SLOTS = 4
Skills.MAX_SLOT_LEVEL = 20 -- placeholder; raise as the game grows

local function rarityOf(abilityId)
	local def = Abilities[abilityId]
	assert(def ~= nil, "Unknown ability: " .. tostring(abilityId))
	local rarity = Rarities[def.Rarity]
	assert(rarity ~= nil, "Ability has no valid Rarity: " .. tostring(abilityId))
	return rarity
end

function Skills.ClampSlotLevel(level)
	return math.clamp(math.floor(level or 1), 1, Skills.MAX_SLOT_LEVEL)
end

function Skills.Pool(classId)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))

	local entries = {}
	for index, abilityId in ipairs(class.AbilityPool) do
		table.insert(entries, { Id = abilityId, Order = rarityOf(abilityId).Order, Index = index })
	end
	table.sort(entries, function(a, b)
		if a.Order ~= b.Order then
			return a.Order < b.Order
		end
		return a.Index < b.Index
	end)

	local ids = {}
	for _, entry in ipairs(entries) do
		table.insert(ids, entry.Id)
	end
	return ids
end

function Skills.StarterAbilities(classId)
	local class = Classes[classId]
	assert(class ~= nil, "Unknown class: " .. tostring(classId))
	return table.clone(class.DefaultLoadout)
end

function Skills.ValidateLoadout(classId, abilityIds, owned)
	local class = Classes[classId]
	if class == nil then
		return false, "UnknownClass"
	end
	if type(abilityIds) ~= "table" then
		return false, "NotAList"
	end
	if #abilityIds > Skills.SLOTS then
		return false, "TooMany"
	end

	local inPool = {}
	for _, id in ipairs(class.AbilityPool) do
		inPool[id] = true
	end

	local seen = {}
	for _, abilityId in ipairs(abilityIds) do
		if type(abilityId) ~= "string" or Abilities[abilityId] == nil then
			return false, "UnknownAbility"
		end
		if seen[abilityId] then
			return false, "Duplicate"
		end
		seen[abilityId] = true
		if not inPool[abilityId] then
			return false, "WrongClass"
		end
		if owned == nil or owned[abilityId] == nil then
			return false, "NotOwned"
		end
	end
	return true
end

return Skills
