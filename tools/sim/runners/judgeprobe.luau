-- Cleric kit probe: Heal/Blessing/RadiantBurst/Smite vs Heal/Blessing/Smite/Judgment, 4-hero gearless L35 party, all skills at
-- equal rank. Run: sync, copy into .build/hl6, luau judgeprobe.luau (2026-11-24: Judgment matches or beats Radiant Burst).
local P = require("./ProfileTemplate"); local SR = require("./StageRunner"); local Classes = require("./Config/Classes")
local function hero(id, c, lv, kit)
	local p = P.New(); p.Permanent.UnlockedClasses[c] = true; p.Season.ClassId = c; p.Season.Level = lv
	P.GrantClassStarters(p.Season, c)
	for _, a in ipairs(Classes[c].AbilityPool) do p.Season.OwnedAbilities[a] = true end
	if kit then p.Season.Loadouts[c] = kit end
	return { Id = id, Name = c, Profile = p }
end
local function run(kit, stage, n)
	local wins, dur, dmg = 0, 0, 0
	for seed = 1, n do
		local party = { hero("1", "Warrior", 35, { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" }), hero("2", "Cleric", 35, kit), hero("3", "Mage", 35), hero("4", "Ranger", 35) }
		local o = SR.Run(party, stage, seed * 31, nil, true)
		if o.Won then wins += 1 end
		dur += o.Duration
		for _, e in ipairs(o.Events) do if e.Type == "Damage" and e.Source == "2" then dmg += e.Amount end end
	end
	return wins, dur / n, dmg / n
end
for _, stage in ipairs({ 14, 17, 19, 20 }) do
	for name, kit in pairs({ Radiant = { "Heal", "Blessing", "RadiantBurst", "Smite" }, Judgment = { "Heal", "Blessing", "Smite", "Judgment" } }) do
		local w, d, g = run(kit, stage, 30)
		print(("stage %d %-9s wins %2d/30  %.1fs  cleric dmg %.0f"):format(stage, name, w, d, g))
	end
end
