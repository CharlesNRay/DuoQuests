--[[
	TownActivityTests (ModuleScript): fishing (Shared/Fishing) and the Training Dummy (Shared/TrainingDummy).
	Headless: tools/sim/runners/extra.luau. In Studio: require(game.ServerScriptService.Server.Tests.TownActivityTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if not m then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Fishing = require(Shared.Fishing), FishingConfig = require(Shared.Config.Fishing), TrainingDummy = require(Shared.TrainingDummy), ProfileTemplate = require(Shared.ProfileTemplate), Consumables = require(Shared.Consumables), Party = require(Shared.Party) }
	end
	local Fishing, Config, PT = m.Fishing, m.FishingConfig, m.ProfileTemplate
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
	print("Running TownActivityTests...")

	local function seq(...)
		local values, i = { ... }, 0
		return function()
			i = i % #values + 1
			return values[i]
		end
	end

	-- fishing
	local profile = PT.New()
	local cast, wait = Fishing.Cast(100, seq(0.5))
	check("A cast bites between the min and max wait", wait >= Config.WaitMin and wait <= Config.WaitMax and math.abs(cast.BiteAt - (100 + wait)) < 1e-9)
	check("Reeling with no cast is refused", select(2, Fishing.Reel(profile, nil, 100, 1, seq(0))) == "NoCast")
	check("Reeling before the bite scares the fish", select(2, Fishing.Reel(profile, cast, cast.BiteAt - 1, 1, seq(0))) == "TooEarly")
	check("Reeling long after the bite misses", select(2, Fishing.Reel(profile, cast, cast.BiteAt + Config.Window + Config.Grace + 0.5, 1, seq(0))) == "TooLate")
	local ok, info = Fishing.Reel(profile, cast, cast.BiteAt + 0.3, 1, seq(0.01))
	check("Reeling in the window catches the first fish (a Minnow at roll 0)", ok and info.Fish == "Minnow" and info.Paid == true and #info.Reward == 1)
	local food = function()
		for _, row in ipairs(m.Consumables.List(profile)) do
			if row.Id == "PetFood" then
				return row.Count
			end
		end
		return 0
	end
	check("A minnow pays a pet snack", food() == 1)
	for _ = 1, Config.DailyRewarded + 3 do
		Fishing.Reel(profile, cast, cast.BiteAt, 1, seq(0.01))
	end
	local status = Fishing.Status(profile, 1)
	check("Only the first DailyRewarded catches a day pay", status.Left == 0 and food() == Config.DailyRewarded)
	check("Every catch goes in the fish log", status.Caught == Config.DailyRewarded + 4)
	check("A new day pays again", Fishing.Status(profile, 2).Left == Config.DailyRewarded)
	local seen = {}
	for i = 0, 99 do
		seen[Fishing.Roll(function() return i / 100 end).Id] = true
	end
	local every = true
	for _, f in ipairs(Config.Fish) do
		every = every and seen[f.Id] == true
	end
	check("Every fish can be caught", every)

	-- training dummy
	local hero = PT.New()
	hero.Season.Level = 20
	local result = m.TrainingDummy.Run({ { Id = "1", Name = "Hero", Profile = hero } }, 10, 7)
	check("The dummy test lasts its full time (the dummy never dies)", math.abs(result.Seconds - m.TrainingDummy.Seconds) < 0.5)
	check("It reports damage per second for the hero", #result.Rows == 1 and result.Rows[1].DPS > 0 and result.Total == result.Rows[1].DPS)
	local before = hero.Season.Currencies.Gold
	check("The dummy pays nothing and does not clear a stage", hero.Season.Currencies.Gold == before and (hero.Season.HighestStage or 1) <= 1)
	check("The best result is kept", m.TrainingDummy.Record(hero, 50) == 50 and m.TrainingDummy.Record(hero, 20) == 50)

	print(("TownActivityTests done: %d passed, %d failed"):format(passed, failed))
end
