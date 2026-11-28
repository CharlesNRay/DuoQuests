--[[
	SeasonRolloverTests (ModuleScript): the season schedule (SeasonClock), moving profiles into a new season
	(SeasonRollover) and season rewards claimed around the switch (SeasonRewards).

	  require(game.ServerScriptService.Server.Tests.SeasonRolloverTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		SeasonClock = require(Shared.SeasonClock), SeasonRollover = require(Shared.SeasonRollover), SeasonRewards = require(Shared.SeasonRewards),
		ProfileTemplate = require(Shared.ProfileTemplate), Characters = require(Shared.Characters), Premium = require(Shared.Premium),
		Consumables = require(Shared.Consumables), DataSafety = require(Shared.Util.DataSafety), SeasonHistogram = require(Shared.SeasonHistogram),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Clock, Roll, SR, Template, Characters = m.SeasonClock, m.SeasonRollover, m.SeasonRewards, m.ProfileTemplate, m.Characters
	local Premium, Consumables, DS = m.Premium, m.Consumables, m.DataSafety
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
	print("Running SeasonRolloverTests...")
	Clock.ClearOverride()

	-- the schedule
	local schedule = { [1] = { StartsAt = 100, EndsAt = 200 }, [2] = { StartsAt = 200, EndsAt = 300 }, [3] = { StartsAt = 300, EndsAt = 400 } }
	check("Before any season: the first one", Clock.CurrentIdFor(schedule, 50) == 1)
	check("During season 1", Clock.CurrentIdFor(schedule, 150) == 1)
	check("Season 2 starts exactly at its StartsAt", Clock.CurrentIdFor(schedule, 200) == 2)
	check("After the last season ends it stays current (off-season)", Clock.CurrentIdFor(schedule, 999) == 3)
	check("The real schedule has a season now", Clock.Def(Clock.CurrentId()) ~= nil and not Clock.IsTest())

	-- a played account: Warrior active (level 80, stage 150), a Mage in slot 2
	local p = Template.New()
	local ok1, warriorSlot = Characters.Create(p, "Warrior")
	local _, mageSlot = Characters.Create(p, "Mage")
	Characters.Select(p, warriorSlot)
	local s = p.Season
	s.Level, s.HighestStage, s.Currencies.Gold, s.Currencies.Wishstones = 80, 150, 9e9, 400
	s.Subclasses = { Warrior = "Guardian" }
	s.Talents = { Might = 10 }
	Consumables.Grant(p, "XPTonic", 7)
	s.Equipment.BagUpgrades = 3
	s.WishPity = { Pet = { Rare = 4, Epic = 20, Legendary = 33 } }
	p.Permanent.Slots[mageSlot].Season.Level = 30
	p.Permanent.Pets.Crownling = true
	p.Permanent.PetLevels = { Crownling = 70 }
	Premium.AddSunstones(p, 500)
	p.Permanent.Cosmetics.Aura_Flame = true
	local oldId = s.SeasonId
	local newId = oldId + 1

	-- a season reward claimed while still in the old season: the Wishstones must not be wiped at the switch
	local results = { Total = 10, Histogram = { [150] = 10 }, Top = { [42] = 1 }, ClassTop = { Warrior = { [42] = 1 } } }
	local okClaim = SR.Claim(p, oldId, results, { UserId = 42, Score = 150, ClassId = "Warrior" })
	local carried = p.Permanent.SeasonRewards.CarryWishstones or 0
	check("A claim before the switch keeps its Wishstones aside", okClaim == true and carried > 0 and s.Currencies.Wishstones == 400)

	check("Rollover is needed for an older season", ok1 and Roll.Needed(p, newId) and not Roll.Needed(p, oldId))
	local news = Roll.Apply(p, newId, 1234)
	local n = p.Season
	check("The active hero starts the new season at level 1, stage 1", n.SeasonId == newId and n.Level == 1 and n.HighestStage == 1)
	check("...keeps its class and gets its starter skills", n.ClassId == "Warrior" and n.Loadouts.Warrior ~= nil and #n.Loadouts.Warrior > 0)
	check("...gold, talents and subclass are gone", n.Currencies.Gold == 0 and next(n.Talents or {}) == nil and next(n.Subclasses) == nil)
	check("...the season reward Wishstones arrive", n.Currencies.Wishstones == carried and p.Permanent.SeasonRewards.CarryWishstones == nil)
	check("...unused items, bag size and wish pity are kept", Consumables.Count(p, "XPTonic") == 7 and n.Equipment.BagUpgrades == 3 and n.WishPity.Pet.Legendary == 33)
	local mage = p.Permanent.Slots[mageSlot].Season
	check("The other character starts over too", mage.SeasonId == newId and mage.Level == 1 and mage.ClassId == "Mage")
	check("Permanent things stay: pets and levels, Sunstones, cosmetics", p.Permanent.Pets.Crownling and p.Permanent.PetLevels.Crownling == 70 and Premium.Sunstones(p) >= 500 and p.Permanent.Cosmetics.Aura_Flame)
	local history = p.Permanent.SeasonHistory[tostring(oldId)]
	check("History keeps both characters and the reward standing", history and #history.Characters == 2 and history.Rank == 1)
	check("History rows say class, level and stage", history and history.Characters[1].ClassId == "Warrior" and history.Characters[1].Level == 80 and history.Characters[1].HighestStage == 150 and history.Characters[1].SubclassId == "Guardian")
	check("The news card data is there", news and news.From == oldId and news.To == newId and p.Permanent.SeasonNews ~= nil and #p.Permanent.SeasonNews.Characters == 2)
	check("A second rollover does nothing", Roll.Apply(p, newId, 9999) == nil and p.Permanent.SeasonHistory[tostring(oldId)].Characters[3] == nil)
	check("The rolled-over profile with its news card can be saved", #DS.Problems(p) == 0)
	Roll.SeenNews(p)
	check("Seen news is cleared", p.Permanent.SeasonNews == nil)
	check("The rolled-over profile can be saved", #DS.Problems(p) == 0)
	check("Switching characters still works", Characters.Select(p, mageSlot) == true and p.Season.ClassId == "Mage" and p.Season.SeasonId == newId)

	-- a claim after the switch goes straight into the new season
	local q = Template.New()
	q.Season.SeasonId = 5
	local okLate = SR.Claim(q, 4, results, { UserId = 42, Score = 150, ClassId = "Warrior" })
	check("A claim after the switch pays Wishstones at once", okLate and q.Season.Currencies.Wishstones > 0 and (q.Permanent.SeasonRewards.CarryWishstones or 0) == 0)
	check("Claiming season 4 but not 1-3 can still be saved (string keys)", SR.Claimed(q, 4) and not SR.Claimed(q, 1) and #DS.Problems(q) == 0)
	local legacy = Template.New()
	legacy.Permanent.SeasonRewards = { Claimed = { [1] = true } }
	check("Old number-keyed claims still count", SR.Claimed(legacy, 1) and legacy.Permanent.SeasonRewards.Claimed["1"] == true)

	-- someone who never made a character: placeholder data only, no history and no card
	local fresh = Template.New()
	local freshNews = Roll.Apply(fresh, fresh.Season.SeasonId + 1, 1)
	check("A player with no character just gets the new season's data", freshNews ~= nil and fresh.Season.SeasonId == freshNews.To and fresh.Permanent.SeasonNews == nil and next(fresh.Permanent.SeasonHistory) == nil)

	-- the Studio test season
	local before = Clock.CurrentId()
	local testId = Clock.StartNext(5000)
	check("StartNext ends the current season and starts the next", testId == before + 1 and Clock.CurrentId() == testId and Clock.Ended(before, 5000) and not Clock.Ended(testId, 5000))
	check("...marked as a test (kept out of real DataStores)", Clock.IsTest() and Clock.Def(testId) ~= nil)
	check("...and listed with the older seasons", #Clock.Ids() == testId)
	check("New characters start in the test season", Template.NewSeasonData(Clock.CurrentId()).SeasonId == testId)
	Clock.ClearOverride()
	check("Clearing goes back to the real schedule", Clock.CurrentId() == before and not Clock.IsTest())

	-- the brackets' histogram counts each player once (it used to count every server a player joined)
	local H = m.SeasonHistogram
	if H then
		local shared = {} -- the DataStore histogram all servers add to
		local function write(pending)
			for score, change in pairs(pending) do
				shared[score] = (shared[score] or 0) + change
				pending[score] = nil
			end
		end
		local function total()
			local t = 0
			for _, c in pairs(shared) do
				t += c
			end
			return t
		end
		local player = Template.New()
		-- server A: reaches stage 20, then 25
		local pendA, flyA = {}, {}
		H.Move(pendA, flyA, player, 1, 77, 20, 5)
		write(pendA) H.Commit(flyA, 1)
		H.Move(pendA, flyA, player, 1, 77, 25, 5)
		write(pendA) H.Commit(flyA, 1)
		check("Histogram: a player moving up counts once", total() == 1 and shared[25] == 1 and shared[20] == 0)
		-- rejoins on server B (fresh server memory), same score, then a second character at a lower stage
		local pendB, flyB = {}, {}
		check("Histogram: rejoining another server does not count them again", H.Move(pendB, flyB, player, 1, 77, 25, 5) == false)
		check("Histogram: a second, weaker character does not count them again", H.Move(pendB, flyB, player, 1, 77, 12, 5) == false and total() == 1)
		-- a write that fails: the move stays pending and the save is not updated
		H.Move(pendB, flyB, player, 1, 77, 30, 5)
		check("Histogram: before the write the save still says 25", player.Permanent.SeasonHist.Score == 25 and H.Counted(player, 1, 77, flyB) == 30)
		check("Histogram: a repeat report while the write waits adds nothing", H.Move(pendB, flyB, player, 1, 77, 30, 5) == false and pendB[30] == 1)
		write(pendB) H.Commit(flyB, 1)
		check("Histogram: after the write, still one player, at 30", total() == 1 and shared[30] == 1 and player.Permanent.SeasonHist.Score == 30)
		check("Histogram: a new season counts them again from scratch", H.Counted(player, 2, 77, {}) == nil and H.Move({}, {}, player, 2, 77, 6, 5) == true)
		check("Histogram: below the minimum stage nobody is counted", H.Move({}, {}, Template.New(), 1, 78, 4, 5) == false)
		check("Histogram: the save field is DataStore-safe", #DS.Problems(player) == 0)
		-- the player leaves while the write is in flight: their last save keeps 30, so the move to 40 is undone
		local pendC, flyC = {}, {}
		H.Move(pendC, flyC, player, 1, 77, 35, 5)
		H.Move(pendC, flyC, player, 1, 77, 40, 5)
		write(pendC)
		H.Commit(flyC, 1, function() return false end, pendC)
		write(pendC)
		check("Histogram: a player who left during the write is undone, not counted twice", total() == 1 and shared[30] == 1 and (shared[40] or 0) == 0 and player.Permanent.SeasonHist.Score == 30)
		H.Move(pendC, flyC, player, 1, 77, 40, 5)
		write(pendC) H.Commit(flyC, 1, function() return true end, pendC)
		check("Histogram: on the next join they move up once", total() == 1 and shared[40] == 1 and player.Permanent.SeasonHist.Score == 40)
	end

	print(("SeasonRolloverTests done: %d passed, %d failed"):format(passed, failed))
end
