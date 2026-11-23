--[[
	TalentTests (ModuleScript): level-up talent points (Shared/Talents, Config/Talents).
	Headless: tools/sim/runners/extra.luau. In Studio: require(game.ServerScriptService.Server.Tests.TalentTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if not m then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Talents = require(Shared.Talents), TalentConfig = require(Shared.Config.Talents), ProfileTemplate = require(Shared.ProfileTemplate), Power = require(Shared.Power), StageRunner = require(Shared.StageRunner), Party = require(Shared.Party) }
	end
	local Talents, Config, PT = m.Talents, m.TalentConfig, m.ProfileTemplate
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
	print("Running TalentTests...")

	local profile = PT.New()
	profile.Season.Level = 1
	local total, spent, free = Talents.Points(profile)
	check("A level 1 hero has no talent points", total == 0 and spent == 0 and free == 0)
	check("Spending with no points is refused", select(2, Talents.Spend(profile, "Might")) == "NoPoints")
	profile.Season.Level = 11
	total, spent, free = Talents.Points(profile)
	check("Level 11 gives 10 points", total == 10 and free == 10)
	check("An unknown talent is refused", select(2, Talents.Spend(profile, "Nope")) == "BadTalent")
	check("Spending a point raises the rank", Talents.Spend(profile, "Might") == true and profile.Season.Talents.Might == 1)
	check("Spending several at once stops at the points you have", Talents.Spend(profile, "Vitality", 50) == true and profile.Season.Talents.Vitality == 9)
	check("No points left after that", select(3, Talents.Points(profile)) == 0)
	local mods = Talents.Mods(profile)
	local attack, health = 0, 0
	for _, mod in ipairs(mods) do
		if mod.Stat == "Attack" then attack = mod.Value end
		if mod.Stat == "MaxHealth" then health = mod.Value end
	end
	check("Mods carry the per-rank values", math.abs(attack - Config.Defs.Might.PerRank) < 1e-9 and math.abs(health - Config.Defs.Vitality.PerRank * 9) < 1e-9)
	check("Reset gives every point back", Talents.Reset(profile) == true and select(3, Talents.Points(profile)) == 10)
	profile.Season.Level = 40
	for _ = 1, 20 do
		Talents.Spend(profile, "Precision")
	end
	check("A talent stops at its max rank", profile.Season.Talents.Precision == Config.Defs.Precision.MaxRank and select(2, Talents.Spend(profile, "Precision")) == "MaxRank")
	Talents.Reset(profile)
	local n = Talents.AutoSpend(profile)
	check("Auto-spend uses every point (39 at level 40)", n == 39 and select(3, Talents.Points(profile)) == 0)
	local status = Talents.Status(profile)
	check("Status lists every talent with its text", #status.List == #Config.Order and status.Free == 0 and status.List[1].Now ~= nil)
	check("Describe reads like a stat line", Talents.Describe("Might", 3) == "+4.5% Attack" and Talents.Describe("Ferocity", 2) == "+6% Crit damage")
	local maxRanks = 0
	for _, def in pairs(Config.Defs) do
		maxRanks += def.MaxRank
	end
	check("There are more ranks than points at level 40 (choices matter)", maxRanks > 39)

	-- talents change the hero in a fight, and count towards item power
	local plain = PT.New()
	plain.Season.Level = 40
	local strong = PT.New()
	strong.Season.Level = 40
	for _ = 1, 10 do
		Talents.Spend(strong, "Might")
	end
	check("Spent points add item power", m.Power.Hero(strong).Total > m.Power.Hero(plain).Total)
	local snap = m.Party.MakeSnapshot(strong, 1, "S", nil, 0)
	local found = false
	for _, mod in ipairs(snap.CollectionMods or {}) do
		if mod.Stat == "Attack" and math.abs(mod.Value - 0.15) < 1e-9 then
			found = true
		end
	end
	check("A ghost snapshot carries the talents", found)

	print(("TalentTests done: %d passed, %d failed"):format(passed, failed))
end
