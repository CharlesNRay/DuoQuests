--[[
	QuestTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > QuestTests

	  require(game.ServerScriptService.Server.Tests.QuestTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Quests = require(Shared.Quests),
		QuestConfig = require(Shared.Config.Quests),
		ProfileTemplate = require(Shared.ProfileTemplate),
		Progression = require(Shared.Progression),
		Consumables = require(Shared.Consumables),
		Daily = require(Shared.Daily),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Quests, QuestConfig, ProfileTemplate, Progression, Consumables, Daily = m.Quests, m.QuestConfig, m.ProfileTemplate, m.Progression, m.Consumables, m.Daily
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

	local day1 = 86400 * 20000 + 100
	local profile = ProfileTemplate.New()
	local daily = Quests.Daily(profile, day1)
	check("Three daily quests of different kinds", #daily.Quests == 3 and daily.Quests[1].Id ~= daily.Quests[2].Id)
	local kinds = {}
	for _, q in ipairs(daily.Quests) do kinds[q.Id] = true end
	check("The same day gives the same quests", #Quests.Daily(ProfileTemplate.New(), day1 + 500).Quests == 3 and Quests.Daily(ProfileTemplate.New(), day1 + 500).Quests[1].Id == daily.Quests[1].Id)

	-- find which events today's quests track and drive them to completion
	local events = {}
	for _, q in ipairs(QuestConfig.Pool) do
		for _, d in ipairs(daily.Quests) do
			if d.Id == q.Id then events[q.Event] = q.Goal end
		end
	end
	check("A quest cannot be claimed before it is done", select(2, Quests.ClaimQuest(profile, 1, day1)) == "NotDone")
	for event, goal in pairs(events) do
		Quests.Record(profile, event, goal + 5, day1)
	end
	local after = Quests.Daily(profile, day1)
	check("Progress is capped at the goal and quests complete", after.Quests[1].Done and after.Quests[2].Done and after.Quests[3].Done and after.Quests[1].Progress == after.Quests[1].Goal)
	check("The bonus is not ready until all are claimed", select(2, Quests.ClaimBonus(profile, day1)) == "NotReady")
	local goldBefore = profile.Season.Currencies.Gold
	local ok, reward = Quests.ClaimQuest(profile, 1, day1)
	check("Claiming a quest pays gold, Wishstones and Pass XP", ok and profile.Season.Currencies.Gold > goldBefore and (profile.Season.Currencies.Wishstones or 0) >= reward.Wishstones and profile.Season.Pass.XP >= reward.PassXP)
	check("A quest pays once", select(2, Quests.ClaimQuest(profile, 1, day1)) == "AlreadyClaimed")
	Quests.ClaimQuest(profile, 2, day1)
	Quests.ClaimQuest(profile, 3, day1)
	check("Claiming all three readies the bonus", Quests.Daily(profile, day1).BonusReady)
	local okBonus = Quests.ClaimBonus(profile, day1)
	check("The bonus pays a pet wish ticket", okBonus and Consumables.Count(profile, "PetWish") == 1 and select(2, Quests.ClaimBonus(profile, day1)) == "AlreadyClaimed")
	check("A new day gives fresh progress", Quests.Daily(profile, day1 + 86400).Quests[1].Progress == 0 and not Quests.Daily(profile, day1 + 86400).Quests[1].Claimed)
	check("A bad quest index is refused", select(2, Quests.ClaimQuest(profile, 9, day1)) == "BadQuest")

	-- stage clears count for quests and pass XP
	local p2 = ProfileTemplate.New()
	Progression.ApplyClear(p2, 1)
	check("A stage clear gives season pass XP", (p2.Season.Pass and p2.Season.Pass.XP or 0) >= QuestConfig.Pass.PerClear + QuestConfig.Pass.PerFrontier)

	-- the season pass
	local p3 = ProfileTemplate.New()
	check("The pass starts at level 0", Quests.Pass(p3).Level == 0 and #Quests.Pass(p3).Rows == QuestConfig.Pass.MaxLevel)
	check("A pass level cannot be claimed before it is reached", select(2, Quests.ClaimPass(p3, 1)) == "NotReached")
	local gained = Quests.AddPassXP(p3, QuestConfig.Pass.XPPerLevel * 5 + 10)
	check("Pass XP raises the level", gained == 5 and Quests.Pass(p3).Level == 5 and Quests.Pass(p3).XPInLevel == 10)
	local okP, rewardP = Quests.ClaimPass(p3, 2)
	check("A reached level pays its reward once", okP and rewardP.Wishstones >= 2 and (p3.Season.Currencies.Wishstones or 0) >= 2 and select(2, Quests.ClaimPass(p3, 2)) == "AlreadyClaimed")
	check("Claim all takes every reached level", Quests.ClaimAllPass(p3) == 4)
	Quests.AddPassXP(p3, 1000000)
	check("The pass caps at the max level", Quests.Pass(p3).Level == QuestConfig.Pass.MaxLevel and Quests.ClaimAllPass(p3) > 0 and Quests.Pass(p3).Rows[QuestConfig.Pass.MaxLevel].Claimed)
	check("Passes reset with the season", ProfileTemplate.NewSeasonData ~= nil and (function()
		p3.Season = ProfileTemplate.NewSeasonData(2)
		return Quests.Pass(p3).Level == 0
	end)())

	-- login streak gives Wishstones
	local p4 = ProfileTemplate.New()
	local okD, summary = Daily.Claim(p4, day1)
	check("The daily login gives Wishstones", okD and summary.Wishstones > 0 and (p4.Season.Currencies.Wishstones or 0) == summary.Wishstones)

	-- the pass never pays gold; it gives consumables, wishes and both kinds of wish ticket
	local goldy, skillTickets, petTickets, stones, items = false, 0, 0, 0, 0
	for level = 1, QuestConfig.Pass.MaxLevel do
		local r = QuestConfig.Pass.Rewards[level]
		if r.GoldClears or r.Gold or r.Shards then
			goldy = true
		end
		stones += r.Wishstones or 0
		for id, n in pairs(r.Items or {}) do
			items += n
			if id == "SkillWish" then skillTickets += n end
			if id == "PetWish" then petTickets += n end
		end
	end
	check("The season pass pays no gold or shards", not goldy)
	check("The pass gives Wishstones and consumables", stones > 40 and items > 15)
	check("The pass gives both Skill and Pet wish tickets", skillTickets >= 3 and petTickets >= 3)
	check("The daily bonus gives both ticket kinds", QuestConfig.BonusReward.Tickets.PetWish == 1 and QuestConfig.BonusReward.Tickets.SkillWish == 1)
	local pp = ProfileTemplate.New()
	Quests.AddPassXP(pp, QuestConfig.Pass.XPPerLevel * 30)
	local goldBefore = pp.Season.Currencies.Gold
	Quests.ClaimAllPass(pp)
	check("Claiming the whole pass leaves gold alone", pp.Season.Currencies.Gold == goldBefore)
	check("Claiming the pass fills the stash with tickets", Consumables.Count(pp, "SkillWish") >= 3 and Consumables.Count(pp, "PetWish") >= 3)

	-- weekly quests: four per week, a Monday-to-Sunday window, bigger goals, a bonus with both tickets
	local monday = 86400 * 20000 + 0
	while ((monday // 86400) + 3) % 7 ~= 0 do monday += 86400 end -- a day that starts a week
	local pw = ProfileTemplate.New()
	local week = Quests.Weekly(pw, monday + 100)
	check("Four weekly quests of different kinds", #week.Quests == 4 and week.Quests[1].Id ~= week.Quests[2].Id)
	check("The same week gives the same quests", Quests.Weekly(ProfileTemplate.New(), monday + 5 * 86400).Quests[1].Id == week.Quests[1].Id)
	check("A new week gives a new window", Quests.Weekly(pw, monday + 7 * 86400).Week == week.Week + 1)
	check("The weekly timer counts down to the next Monday", week.SecondsLeft == 7 * 86400 - 100)
	check("A weekly quest cannot be claimed early", select(2, Quests.ClaimWeekly(pw, 1, monday)) == "NotDone")
	for _, q in ipairs(week.Quests) do
		local def
		for _, d in ipairs(QuestConfig.Weekly.Pool) do if d.Id == q.Id then def = d end end
		Quests.Record(pw, def.Event, def.Goal + 3, monday + 200)
	end
	local done = Quests.Weekly(pw, monday + 300)
	check("Weekly quests complete and cap at their goal", done.Quests[1].Done and done.Quests[4].Done and done.Quests[1].Progress == done.Quests[1].Goal)
	check("The weekly bonus waits for all four claims", select(2, Quests.ClaimWeeklyBonus(pw, monday)) == "NotReady")
	local stonesBefore, goldNow = pw.Season.Currencies.Wishstones or 0, pw.Season.Currencies.Gold
	for i = 1, 4 do
		check("Weekly quest " .. i .. " claims", Quests.ClaimWeekly(pw, i, monday))
	end
	check("A weekly quest claims once", select(2, Quests.ClaimWeekly(pw, 1, monday)) == "AlreadyClaimed")
	check("Weekly quests pay Wishstones and a consumable, never gold", (pw.Season.Currencies.Wishstones or 0) == stonesBefore + 4 * QuestConfig.Weekly.QuestReward.Wishstones and pw.Season.Currencies.Gold == goldNow and Consumables.Count(pw, "GrandPetFood") >= 4)
	check("The weekly bonus is ready", Quests.Weekly(pw, monday).BonusReady)
	local okB = Quests.ClaimWeeklyBonus(pw, monday)
	check("The weekly bonus gives both wish tickets", okB and Consumables.Count(pw, "SkillWish") == 1 and Consumables.Count(pw, "PetWish") == 1)
	check("The weekly bonus claims once", select(2, Quests.ClaimWeeklyBonus(pw, monday)) == "AlreadyClaimed")
	local reset = Quests.Weekly(pw, monday + 7 * 86400)
	check("Next week starts fresh", reset.Quests[1].Progress == 0 and not reset.BonusClaimed)
	local ps = ProfileTemplate.New()
	Quests.Record(ps, "Strike", 1, monday)
	local dstrike
	for _, q in ipairs(Quests.Weekly(ps, monday).Quests) do if q.Id == "WStrike4" then dstrike = q end end
	check("A boss strike counts toward the weekly strike quest when drawn", dstrike == nil or dstrike.Progress == 1)

	print(("QuestTests done: %d passed, %d failed"):format(passed, failed))
end
