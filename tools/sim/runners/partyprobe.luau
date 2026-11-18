-- Party probe: gearless level-30 four-hero parties fight a stage 30 times; prints wins, damage and deaths per member.
-- Quick check for role balance (who dies, who deals the damage). Run: sync, copy into .build/hl6, luau partyprobe.luau
local P = require("./ProfileTemplate"); local SR = require("./StageRunner")
local function hero(c, lv)
	local p = P.New(); p.Permanent.UnlockedClasses[c] = true; p.Season.ClassId = c; P.GrantClassStarters(p.Season, c); p.Season.Level = lv; p.Season.HighestStage = 60
	return p
end
local function test(classes, stage)
	local wins, deaths, dmg, n = 0, {}, {}, 30
	for seed = 1, n do
		local team = {}
		for i, c in ipairs(classes) do team[i] = { Id = tostring(i), Name = c, Profile = hero(c, 30) } end
		local o = SR.Run(team, stage, seed, SR.UltimateFor(team, 60, nil), true)
		if o.Won then wins += 1 end
		for _, e in ipairs(o.Events) do
			local i = tonumber(e.Target or "")
			if e.Type == "Death" and i and i <= 4 then deaths[i] = (deaths[i] or 0) + 1 end
			local s = tonumber(e.Source or "")
			if e.Type == "Damage" and s and s <= 4 and not e.Sacrifice then dmg[s] = (dmg[s] or 0) + e.Amount end
		end
	end
	local line = {}
	for i, c in ipairs(classes) do table.insert(line, ("%s dmg=%.0fk dies=%d"):format(c, (dmg[i] or 0) / n / 1000, deaths[i] or 0)) end
	print(("stage %d wins %d/%d  %s"):format(stage, wins, n, table.concat(line, " | ")))
end
for _, st in ipairs({ 14, 18 }) do
	test({ "Mage", "Cleric", "Warrior", "Ranger" }, st)
	test({ "Summoner", "Cleric", "Warrior", "Mage" }, st)
	test({ "Rogue", "Cleric", "Warrior", "Mage" }, st)
end
