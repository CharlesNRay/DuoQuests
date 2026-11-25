-- Lists every id that needs an icon: class skills, other abilities, statuses, ultimates, pet skills.
local A = require("./Config/Abilities"); local C = require("./Config/Classes"); local S = require("./Config/Statuses")
local U = require("./Config/Ultimates"); local P = require("./Config/Pets")
local seen = {}
for cid, c in pairs(C) do
	if type(c) == "table" and c.AbilityPool then
		local t = {}
		for _, id in ipairs(c.AbilityPool) do table.insert(t, id); seen[id] = true end
		print("CLASS", cid, table.concat(t, " "))
	end
end
local others = {}
for id in pairs(A) do if not seen[id] then table.insert(others, id) end end
table.sort(others); print("OTHER", table.concat(others, " "))
local st = {} for id in pairs(S) do table.insert(st, id) end table.sort(st) print("STATUS", table.concat(st, " "))
local ul = {} for id in pairs(U.Defs or U) do table.insert(ul, tostring(id)) end table.sort(ul) print("ULT", table.concat(ul, " "))
local ps = {} for _, d in pairs(P.Defs) do if d.Skill then table.insert(ps, d.Skill.Name) end end table.sort(ps) print("PETSKILL", table.concat(ps, " | "))
