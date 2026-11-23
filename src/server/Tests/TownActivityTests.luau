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
	local cast, castInfo = Fishing.Cast(100, seq(0.5))
	local wait = castInfo.Wait
	check("A cast bites between the min and max wait", wait >= Config.WaitMin and wait <= Config.WaitMax and math.abs(cast.BiteAt - (100 + wait)) < 1e-9)
	check("The gold zone is placed away from the top of the dial", cast.Zone >= 40 and cast.Zone + Config.ZoneWidth <= 320)
	-- the moment the needle is in the middle of the zone
	local good = (cast.Zone + Config.ZoneWidth / 2) / Config.Speed
	local bad = (cast.Zone - 30) / Config.Speed
	check("Reeling with no cast is refused", select(2, Fishing.Reel(profile, nil, 100, 1, seq(0))) == "NoCast")
	check("Reeling before the bite scares the fish", select(2, Fishing.Reel(profile, cast, cast.BiteAt - 1, 1, seq(0))) == "TooEarly")
	check("Reeling after the needle's laps: the fish got away", select(2, Fishing.Reel(profile, cast, cast.BiteAt + Config.Laps * 360 / Config.Speed + Config.Grace + 0.5, 1, seq(0))) == "TooLate")
	check("Reeling with the needle outside the zone misses", select(2, Fishing.Reel(profile, cast, cast.BiteAt + bad + 0.1, 1, seq(0), bad)) == "Missed")
	check("A client cannot claim a time far from the server's clock", select(2, Fishing.Reel(profile, cast, cast.BiteAt + bad - 0.3, 1, seq(0), good + 1)) == "Missed")
	local ok, info = Fishing.Reel(profile, cast, cast.BiteAt + good + 0.1, 1, seq(0.01), good)
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
		Fishing.Reel(profile, cast, cast.BiteAt + good, 1, seq(0.01), good)
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

	-- relics and the pet park (Shared/TownLeisure)
	local TL, World = m.TownLeisure, m.World
	if TL and World then
		local spotsOk = true
		for n = 1, TL.RELIC_COUNT do
			local id = "Relic" .. n
			local x, z = World.TownSpot(id)
			if not x then
				spotsOk = false
			else
				local spot = World.TownSpots[id]
				if spot.District then
					local dx, dz = World.DistrictPoint(spot.District)
					if math.sqrt((x - dx) ^ 2 + (z - dz) ^ 2) > World.Districts[spot.District].Size - 2 then
						spotsOk = false
					end
				end
				if math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2) < World.PLAZA.Radius or math.abs(x) > 340 then
					spotsOk = false
				end
				for slot = 1, World.MAX_LOTS do
					local ax, _, az = World.ArenaOrigin(slot)
					if math.abs(x - ax) < World.ARENA_WIDTH / 2 + 5 and math.abs(z - az) < World.ARENA_DEPTH / 2 + 5 then
						spotsOk = false
					end
				end
			end
		end
		check("Every relic has a spot on town ground, off the plaza and the lots", spotsOk)
		local p = PT.New()
		local stones = p.Season.Currencies.Wishstones or 0
		local okR, infoR = TL.TakeRelic(p, "Relic1")
		check("Taking a relic pays Wishstones", okR and infoR.Found == 1 and (p.Season.Currencies.Wishstones or 0) == stones + TL.RELIC_STONES)
		check("The same relic cannot be taken twice", select(2, TL.TakeRelic(p, "Relic1")) == "Found")
		check("A made-up relic is refused", select(2, TL.TakeRelic(p, "Relic99")) == "BadRelic")
		for n = 2, TL.RELIC_COUNT do
			okR, infoR = TL.TakeRelic(p, "Relic" .. n)
		end
		check("Finding them all gives the bonus and the title", okR and infoR.All == true and p.Permanent.Titles[TL.ALL_TITLE] == true)
		local q = PT.New()
		local hadPet = m.Pets.Active(q) ~= nil
		if not hadPet then
			check("The pet park needs a pet", select(2, TL.PetPlay(q, 5)) == "NoPet")
		end
		local petId = m.PetConfig.Order and m.PetConfig.Order[1]
		if petId then
			q.Permanent.Pets[petId] = true
			m.Pets.Equip(q, petId)
		end
		q.Season.Level = 30
		local okP = TL.PetPlay(q, 5)
		check("Playing with your pet works once a day", okP == true and select(2, TL.PetPlay(q, 5)) == "DoneToday" and TL.PetPlay(q, 6) == true)
	end

	-- sparring duels (Shared/Sparring)
	if m.Sparring then
		local strong, weak = PT.New(), PT.New()
		strong.Season.Level = 40
		weak.Season.Level = 3
		weak.Season.ClassId = "Mage"
		local duel = m.Sparring.Duel({ Id = "1", Name = "Strong", Profile = strong }, { Id = "2", Name = "Weak", Profile = weak }, 5)
		check("A duel has two bouts, one from each side", #duel.Bouts == 2 and duel.Bouts[1].Seconds > 0 and duel.Bouts[2].Seconds > 0)
		check("A level 40 hero beats a level 3 hero", duel.Won == true and duel.MyDamage > duel.TheirDamage)
		local back = m.Sparring.Duel({ Id = "2", Name = "Weak", Profile = weak }, { Id = "1", Name = "Strong", Profile = strong }, 5)
		check("...and the level 3 hero loses from either side", back.Won == false)
		local day = 777
		local stones = strong.Season.Currencies.Wishstones or 0
		local lines = m.Sparring.Record(strong, true, day)
		check("The first win of the day pays", #lines == 1 and (strong.Season.Currencies.Wishstones or 0) == stones + m.Sparring.DailyWinStones)
		check("The second win that day does not", #m.Sparring.Record(strong, true, day) == 0)
		m.Sparring.Record(strong, false, day)
		local st = m.Sparring.Stats(strong)
		check("Wins and losses are counted", st.Wins == 2 and st.Losses == 1)
	end

	print(("TownActivityTests done: %d passed, %d failed"):format(passed, failed))
end
