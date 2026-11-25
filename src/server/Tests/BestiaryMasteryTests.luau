--[[
	BestiaryMasteryTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > BestiaryMasteryTests

	The permanent bestiary (kills -> tiers -> zone titles and capped bonuses) and per-class mastery (XP from progress,
	perks every 10 levels, titles), and that both survive in a save-safe shape.
	require(...BestiaryMasteryTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Bestiary = require(Shared.Bestiary), BestiaryConfig = require(Shared.Config.Bestiary), ClassMastery = require(Shared.ClassMastery),
			MasteryConfig = require(Shared.Config.ClassMastery), ProfileTemplate = require(Shared.ProfileTemplate), Progression = require(Shared.Progression),
			StageRunner = require(Shared.StageRunner), DataSafety = require(Shared.Util.DataSafety),
		}
	end
	local B, M, Cfg = m.Bestiary, m.ClassMastery, m.BestiaryConfig
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("BestiaryMasteryTests")

	local zones = B.Zones()
	check("20 zones, each with three monsters and a boss", #zones == 20 and #zones[1].Monsters == 3 and zones[1].Boss ~= nil and zones[19].Boss == "RainbowSlime")
	check("tiers: regular 25/250/2500/25000", B.TierOf("Slime", 24) == 0 and B.TierOf("Slime", 25) == 1 and B.TierOf("Slime", 25000) == 4)
	check("tiers: a boss needs far fewer kills", B.TierOf(zones[1].Boss, 1) == 1 and B.TierOf(zones[1].Boss, 250) == 4)

	local p = m.ProfileTemplate.New()
	local now = 1800000000
	local hunt = B.HuntOf(now)
	local reached = B.Record(p, { Slime = 30 }, now)
	local slimeKills = p.Permanent.Bestiary.Kills.Slime
	check("kills are counted (double for the weekly hunt)", slimeKills == (if hunt == "Slime" then 60 else 30) and #reached == 1 and reached[1].Tier == 1)
	check("no bonus before a whole zone is hunted", #B.Mods(p) == 0)

	-- hunt the whole first zone to tier 2
	local z1 = zones[1]
	local counts = {}
	for _, id in ipairs(z1.Monsters) do counts[id] = 250 end
	counts[z1.Boss] = 10
	B.Record(p, counts, now)
	local bonus = B.Bonus(p)
	check("a hunted zone gives its title", p.Permanent.Titles[z1.Name .. " Hunter"] == true)
	check("a hunted zone gives +0.5% attack and health", math.abs((bonus.Attack or 0) - Cfg.ZoneBonus.Attack) < 1e-9 and math.abs((bonus.MaxHealth or 0) - Cfg.ZoneBonus.MaxHealth) < 1e-9)
	-- every zone mastered: the bonus stays at the cap
	local all = {}
	for _, z in ipairs(zones) do
		for _, id in ipairs(z.Monsters) do all[id] = 25000 end
		all[z.Boss] = 250
	end
	B.Record(p, all, now)
	bonus = B.Bonus(p)
	check("bonuses are capped", bonus.Attack == Cfg.Cap and bonus.MaxHealth == Cfg.Cap)
	check("a mastered zone gives the Master title", p.Permanent.Titles[zones[5].Name .. " Master"] == true)
	local status = B.Status(p, now)
	check("status lists every zone with four entries", #status.Zones == 20 and #status.Zones[1].Monsters == 4 and status.Zones[1].Tier == 4)

	-- kills from a recorded fight
	local q = m.ProfileTemplate.New()
	q.Permanent.UnlockedClasses.Warrior = true
	q.Season.ClassId = "Warrior"
	m.ProfileTemplate.GrantClassStarters(q.Season, "Warrior")
	q.Season.Level = 30
	local outcome = m.StageRunner.Run({ { Id = "1", Name = "W", Profile = q } }, 3, 5, nil, true, { NoRewards = true })
	local fightKills, deaths = 0, 0
	for _, n in pairs(B.CountKills(outcome.Events, outcome.Roster)) do fightKills += n end
	local enemyIds = {}
	for _, r in ipairs(outcome.Roster) do if r.Team == "Enemy" then enemyIds[r.Id] = true end end
	for _, e in ipairs(outcome.Events) do if e.Type == "Death" and enemyIds[e.Target] then deaths += 1 end end
	check("a fight's kills are its monsters' deaths", fightKills == deaths and (not outcome.Won or fightKills > 0))
	local away = B.KillsForStage(25, 10)
	local awayTotal = 0
	for _, n in pairs(away) do awayTotal += n end
	check("away wins count every monster of the stage", awayTotal >= 10)

	-- class mastery
	local r = m.ProfileTemplate.New()
	r.Season.ClassId = "Mage"
	check("mastery starts at 0", M.Of(r, "Mage").Level == 0 and #M.Mods(r, "Mage") == 0)
	check("replaying a stage gives no mastery", M.OnClear(r, false, false) == 0 and M.Of(r, "Mage").XP == 0)
	M.OnClear(r, true, true)
	local got = m.MasteryConfig.XP.Frontier + m.MasteryConfig.XP.Boss
	check("a first boss kill gives frontier + boss XP", M.Of(r, "Mage").Level * M.XPToNext(0) + M.Of(r, "Mage").XP == got)
	local need = -got
	for level = 0, 9 do need += M.XPToNext(level) end
	M.Add(r, "Mage", need)
	check("level 10 gives a perk and the Adept title", M.Of(r, "Mage").Level == 10 and #M.Mods(r, "Mage") == 3 and r.Permanent.Titles["Mage Adept"] == true)
	check("the perk is +1% per 10 levels", math.abs(M.Mods(r, "Mage")[1].Value - 0.01) < 1e-9)
	check("mastery is per class", M.Of(r, "Warrior").Level == 0 and #M.Mods(r, "Warrior") == 0)
	M.Add(r, "Mage", 1e9)
	check("mastery stops at the cap with +5%", M.Of(r, "Mage").Level == m.MasteryConfig.MaxLevel and math.abs(M.Mods(r, "Mage")[1].Value - 0.05) < 1e-9 and r.Permanent.Titles["Mage Master"] == true)
	local ms = M.Status(r)
	check("status lists every class", #ms.Classes == 6)
	-- a new season keeps both
	local seasonBefore = r.Season
	r.Season = m.ProfileTemplate.NewSeasonData(2)
	check("a new season keeps mastery and the bestiary", M.Of(r, "Mage").Level == m.MasteryConfig.MaxLevel and r.Permanent.Bestiary ~= nil)
	r.Season = seasonBefore
	-- a stage clear through Progression gives mastery
	local s = m.ProfileTemplate.New()
	s.Season.ClassId = "Cleric"
	m.Progression.ApplyClear(s, 1)
	check("a frontier clear gives mastery XP", M.Of(s, "Cleric").XP >= m.MasteryConfig.XP.Frontier)

	-- save safety
	local problems = m.DataSafety.Problems(p)
	check("a filled bestiary is save-safe (" .. table.concat(problems or {}, "; ") .. ")", problems == nil or #problems == 0)
	problems = m.DataSafety.Problems(r)
	check("mastery is save-safe", problems == nil or #problems == 0)

	print(("BestiaryMasteryTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
