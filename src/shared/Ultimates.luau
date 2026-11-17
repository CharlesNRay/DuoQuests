--[[
	Ultimates (ModuleScript)
	Location: ReplicatedStorage > Shared > Ultimates

	Rules for which party ultimates a pair of classes can use. Pure functions.
	The data lives in Config/Ultimates.

	  Ultimates.PairKey(classA, classB)               -> "Cleric+Warrior" (order-free)
	  Ultimates.ForPair(classA, classB)               -> list of ultimate ids
	  Ultimates.IsUnlocked(ultimateId, frontier)      -> bool
	  Ultimates.Available(classA, classB, frontier)   -> ids unlocked at that frontier
	  Ultimates.Resolve(classA, classB, frontier, chosenId)
	      -> the id that will actually be used: the chosen one if it is valid
	         and unlocked, otherwise the first available. nil if the pair has none.
	  Ultimates.Validate(classA, classB, frontier, ultimateId) -> true | false, reason
	      reasons: "NoUltimate", "NotForPair", "Locked"
	  Ultimates.PartyLevel(slotLevelLists)            -> average slot level, 1..20
]]

local Config = require(script.Parent.Config.Ultimates)
local Skills = require(script.Parent.Skills)

local Ultimates = {}

function Ultimates.PairKey(classA, classB)
	if classA > classB then
		classA, classB = classB, classA
	end
	return classA .. "+" .. classB
end

function Ultimates.ForPair(classA, classB)
	return Config.Pairs[Ultimates.PairKey(classA, classB)] or {}
end

function Ultimates.IsUnlocked(ultimateId, frontier)
	local def = Config.Defs[ultimateId]
	return def ~= nil and (frontier or 1) >= (def.UnlockStage or 1)
end

function Ultimates.Available(classA, classB, frontier)
	local ids = {}
	for _, id in ipairs(Ultimates.ForPair(classA, classB)) do
		if Ultimates.IsUnlocked(id, frontier) then
			table.insert(ids, id)
		end
	end
	return ids
end

function Ultimates.Validate(classA, classB, frontier, ultimateId)
	local forPair = Ultimates.ForPair(classA, classB)
	if #forPair == 0 then
		return false, "NoUltimate"
	end
	if type(ultimateId) ~= "string" or not table.find(forPair, ultimateId) then
		return false, "NotForPair"
	end
	if not Ultimates.IsUnlocked(ultimateId, frontier) then
		return false, "Locked"
	end
	return true
end

function Ultimates.Resolve(classA, classB, frontier, chosenId)
	if chosenId ~= nil and Ultimates.Validate(classA, classB, frontier, chosenId) then
		return chosenId
	end
	return Ultimates.Available(classA, classB, frontier)[1]
end

-- Average of every slot level in every list given (members' SlotLevels).
function Ultimates.PartyLevel(slotLevelLists)
	local total, count = 0, 0
	for _, levels in ipairs(slotLevelLists) do
		for _, level in ipairs(levels) do
			total += level
			count += 1
		end
	end
	if count == 0 then
		return 1
	end
	return Skills.ClampSkillLevel(math.floor(total / count + 0.5))
end

return Ultimates
