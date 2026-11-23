--[[
	SkillIdTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SkillIdTests

	Guards against two skills sharing one key in Config/Abilities (the later one silently replaces the first:
	until 2026-11-22 the Templar "Judgment" and the boss "CrushingBlow" hid the Cleric and Warrior combo finishers).
	require(...SkillIdTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Abilities = require(Shared.Config.Abilities), Classes = require(Shared.Config.Classes), Subclasses = require(Shared.Config.Subclasses) }
	end
	local Abilities, Classes = m.Abilities, m.Classes
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("SkillIdTests")

	-- every combo layer a skill puts on is used up by some finisher of the same class
	local finishers = {}
	for id, def in pairs(Abilities) do
		for _, e in ipairs(def.Effects or {}) do
			if e.Consume then
				finishers[e.Consume.Status] = finishers[e.Consume.Status] or {}
				finishers[e.Consume.Status][def.Class or "?"] = id
			end
		end
	end
	local combo = { Judged = "Cleric", Sundered = "Warrior" }
	for status, classId in pairs(combo) do
		check(status .. " layers have a " .. classId .. " finisher", finishers[status] ~= nil and finishers[status][classId] ~= nil)
	end
	check("Judgment is the Cleric combo finisher", Abilities.Judgment and Abilities.Judgment.Class == "Cleric" and Abilities.Judgment.Rarity == "Epic")
	check("CrushingBlow is the Warrior combo finisher", Abilities.CrushingBlow and Abilities.CrushingBlow.Class == "Warrior" and not Abilities.CrushingBlow.Enemy)
	check("The Templar's single-target skill is Verdict", Abilities.Verdict and Abilities.Verdict.Subclass == "Templar")

	-- each ability's key matches its Id, and no class skill pool lists an enemy skill
	local mismatched, enemyInPool = {}, {}
	for key, def in pairs(Abilities) do
		if type(def) == "table" and def.Id and def.Id ~= key then
			table.insert(mismatched, key)
		end
	end
	for classId, class in pairs(Classes) do
		if type(class) == "table" and class.AbilityPool then
			for _, id in ipairs(class.AbilityPool) do
				if Abilities[id] and Abilities[id].Enemy then
					table.insert(enemyInPool, classId .. ":" .. id)
				end
			end
		end
	end
	check("Every ability key matches its Id (" .. table.concat(mismatched, ", ") .. ")", #mismatched == 0)
	check("No class pool holds an enemy skill (" .. table.concat(enemyInPool, ", ") .. ")", #enemyInPool == 0)

	print(("SkillIdTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
