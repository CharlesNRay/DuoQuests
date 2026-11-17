local P = require("./ProfileTemplate"); local Bosses = require("./Bosses"); local Cfg = require("./Config/Bosses"); local Classes = require("./Config/Classes")
local SC = require("./StageRunner")
local function owned(p, cid) for _, id in ipairs(Classes[cid].AbilityPool) do p.Season.OwnedAbilities[id] = true end end
for _, lv in ipairs({ 10, 30 }) do
	local line = { "L" .. lv }
	for _, cid in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
		local p = P.New(); p.Permanent.UnlockedClasses[cid] = true
		p.Season.ClassId = cid; p.Season.Level = lv; p.Season.HighestStage = lv
		p.Season.Loadouts[cid] = p.Season.Loadouts[cid] or Classes[cid].DefaultLoadout
		local d = Bosses.Challenge({ { Id = "1", Name = "A", Profile = p } }, Cfg.World, lv, 5, false)
		table.insert(line, cid .. "=" .. d)
	end
	print(table.concat(line, "  "))
end
