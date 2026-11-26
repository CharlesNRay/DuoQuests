-- Skill audit: what every skill does, sorted into a role category, with its secondary purposes.
-- Categories: Heal, Shield, Summon, AoE (damage to all enemies), Single (damage to one), Buff (allies/self), Debuff (enemies, control).
-- A skill whose only purposes are its category (and combo layers) is flagged PURE: same-category skills of a class should differ.
-- Run: cp tools/sim/runners/skillaudit.luau .build/hl6/; cd .build/hl6; luau skillaudit.luau
local Skills = require("./Skills")
local Cats = require("./skillcats")
local describe = Cats.describe

for _, c in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
	print("== " .. c)
	local byCat = {}
	for _, id in ipairs(Skills.AllSkills(c)) do
		local cat, others, words, a = describe(id)
		byCat[cat] = byCat[cat] or {}
		table.insert(byCat[cat], ("  %-8s %-18s cd%-4s %-9s %s%s  | %s"):format(cat, id, tostring(a.Cooldown or "-"), a.Rarity or "", if #others == 0 then "PURE" else "+" .. table.concat(others, "+"), "", words))
	end
	for _, cat in ipairs({ "Single", "AoE", "Heal", "Revive", "Shield", "Summon", "Buff", "Debuff", "?" }) do
		for _, line in ipairs(byCat[cat] or {}) do
			print(line)
		end
	end
end
