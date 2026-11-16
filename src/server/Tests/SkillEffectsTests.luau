--[[
	SkillEffectsTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SkillEffectsTests

	Every skill in the game has a look, and every look uses a real kind.   require(...SkillEffectsTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Effects = require(Shared.Config.SkillEffects), Abilities = require(Shared.Config.Abilities),
			UltimateConfig = require(Shared.Config.Ultimates), Statuses = require(Shared.Config.Statuses),
			Classes = require(Shared.Config.Classes),
		}
	end
	local E, Abilities, Ultimates = m.Effects, m.Abilities, m.UltimateConfig
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	local missing, badKind = {}, {}
	local function has(t, key)
		return t[key] ~= nil
	end
	for id, def in pairs(Abilities) do
		local style = E.Abilities[id]
		if style == nil then
			table.insert(missing, id)
		else
			for field, group in pairs({ Hit = "Hit", Area = "Area", Heal = "Heal", Shield = "Shield", Buff = "Buff", Revive = "Revive" }) do
				if style[field] ~= nil and not E.Kinds[group][style[field]] then
					table.insert(badKind, id .. "." .. field)
				end
			end
			-- the style must cover what the skill does
			local needs = {}
			for _, effect in ipairs(def.Effects or {}) do
				if effect.Type == "Damage" then
					needs[if effect.Target == "AllEnemies" then "Area" else "Hit"] = true
				elseif effect.Type == "Heal" then
					needs.Heal = true
				elseif effect.Type == "Shield" then
					needs.Shield = true
				elseif effect.Type == "Revive" then
					needs.Revive = true
				end
			end
			for field in pairs(needs) do
				if style[field] == nil and not (field == "Heal" and style.Area ~= nil) then
					table.insert(missing, id .. " needs " .. field)
				end
			end
			if style.Color == nil then
				table.insert(missing, id .. " needs Color")
			end
		end
	end
	check("Every ability and pet skill has a look" .. (if #missing > 0 then (": " .. table.concat(missing, ", ")) else ""), #missing == 0)
	check("Every look uses a known kind" .. (if #badKind > 0 then (": " .. table.concat(badKind, ", ")) else ""), #badKind == 0)

	local petOk = true
	for id in pairs(Abilities) do
		if id:sub(1, 4) == "Pet_" and (E.Abilities[id] == nil or E.Abilities[id].Glyph == nil) then
			petOk = false
		end
	end
	check("Every pet skill has a glyph that pops up over the pet", petOk)

	local ultMissing = {}
	for id in pairs(Ultimates.Defs) do
		if E.Ultimates[id] == nil then
			table.insert(ultMissing, id)
		elseif not E.Kinds.Ultimate[E.Ultimates[id].Kind] then
			table.insert(ultMissing, id .. " (bad kind)")
		end
	end
	check("Every ultimate has its own show" .. (if #ultMissing > 0 then (": " .. table.concat(ultMissing, ", ")) else ""), #ultMissing == 0)

	local statusMissing = {}
	for id in pairs(m.Statuses.Defs or m.Statuses) do
		if type(id) == "string" and E.Statuses[id] == nil then
			table.insert(statusMissing, id)
		end
	end
	check("Every status has a look" .. (if #statusMissing > 0 then (": " .. table.concat(statusMissing, ", ")) else ""), #statusMissing == 0)

	local classOk = true
	for classId in pairs(m.Classes) do
		if type(classId) == "string" and m.Classes[classId].BasicAttack and E.Basic[classId] == nil then
			classOk = false
		end
	end
	check("Every class has a basic attack look", classOk and E.Basic.Enemy ~= nil)

	-- uniqueness: no two hero skills of the same kind share a main colour
	local seen, clashes = {}, {}
	for id, style in pairs(E.Abilities) do
		if id:sub(1, 4) ~= "Pet_" and Abilities[id] and Abilities[id].Class ~= nil then
			for _, field in ipairs({ "Hit", "Area", "Heal", "Shield", "Buff", "Revive" }) do
				if style[field] then
					local key = field .. style[field] .. table.concat(style.Color, ",")
					if seen[key] then
						table.insert(clashes, id .. "~" .. seen[key])
					end
					seen[key] = id
				end
			end
		end
	end
	check("No two class skills look identical" .. (if #clashes > 0 then (": " .. table.concat(clashes, ", ")) else ""), #clashes == 0)

	print(("SkillEffectsTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
