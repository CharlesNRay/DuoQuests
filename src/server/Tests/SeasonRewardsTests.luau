--[[
	SeasonRewardsTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SeasonRewardsTests

	  require(game.ServerScriptService.Server.Tests.SeasonRewardsTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		SeasonRewards = require(Shared.SeasonRewards), SeasonRewardsConfig = require(Shared.Config.SeasonRewards),
		ProfileTemplate = require(Shared.ProfileTemplate), Premium = require(Shared.Premium), Consumables = require(Shared.Consumables), Pets = require(Shared.Pets), PetConfig = require(Shared.Config.Pets),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local SR, Config, ProfileTemplate, Premium, Consumables = m.SeasonRewards, m.SeasonRewardsConfig, m.ProfileTemplate, m.Premium, m.Consumables
	local Pets, PetConfig = m.Pets, m.PetConfig
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

	-- 1000 ranked players: 100 each at stages 3..12
	local results = { Total = 1000, Histogram = {}, Top = {}, ClassTop = { Warrior = {}, Mage = {} } }
	for stage = 3, 12 do
		results.Histogram[stage] = 100
	end
	results.Top[11] = 1
	results.Top[22] = 2
	results.Top[33] = 3
	results.Top[44] = 7
	results.Top[55] = 15
	results.Top[66] = 40
	results.ClassTop.Warrior[11] = 1
	results.ClassTop.Warrior[77] = 2
	results.ClassTop.Mage[22] = 1

	check("Below the minimum stage is unranked", SR.Percent(results, Config.MinStage - 1) == nil)
	check("Best score is the top 10% (ties share a place)", math.abs(SR.Percent(results, 12) - 0.1) < 1e-9)
	check("Worst ranked score is the top 100%", math.abs(SR.Percent(results, 3) - 1) < 1e-9)
	check("A score between groups sits with the tighter tie group", math.abs(SR.Percent(results, 7) - 0.6) < 1e-9)

	local top = SR.Standing(results, { UserId = 11, Score = 12, ClassId = "Warrior" })
	check("Rank 1 gets the Champion row", top.Ranked and top.RankReward.Label == "Champion" and top.Percentile.Label == "Top 10%")
	check("Rank 1 is also best Warrior", top.ClassReward ~= nil and top.ClassReward.MaxRank == 1)
	local reward = SR.Reward(top)
	local expected = Config.Percentiles[1].Sunstones
	for _, row in ipairs(Config.Ranks) do
		expected += row.Sunstones
	end
	for _, row in ipairs(Config.ClassRanks) do
		expected += row.Sunstones
	end
	check("Rank 1 gets every rank row and every class row plus the percentile (StackRanks)", Config.StackRanks == true)
	check("Layers add together (percentile + rank + class)", reward.Sunstones == expected)
	check("Rank 1 gets a title, the class title and an aura", table.find(reward.Titles, "Champion") ~= nil and table.find(reward.Titles, "Grandmaster Warrior") ~= nil and table.find(reward.Cosmetics, "Aura_Champion") ~= nil)
	check("Lines list every row (1 percentile + 6 rank + 3 class)", #reward.Lines == 10)
	check("Rank 1 gets every title below too", table.find(reward.Titles, "Elite Fifty") ~= nil and table.find(reward.Titles, "Podium") ~= nil)

	local everyRank = true
	for rank = 1, Config.TopKept do
		everyRank = everyRank and SR.Standing({ Total = 1000, Histogram = { [12] = 1000 }, Top = { [1] = rank }, ClassTop = {} }, { UserId = 1, Score = 12, ClassId = "Cleric" }).RankReward ~= nil
	end
	check("Every rank from 1 to 50 gets a rank reward", everyRank)
	check("Rank 51 gets none", SR.Standing({ Total = 1000, Histogram = { [12] = 1000 }, Top = { [1] = 51 }, ClassTop = {} }, { UserId = 1, Score = 12, ClassId = "Cleric" }).RankReward == nil)
	check("Rank 7 fits Top 10", SR.Standing(results, { UserId = 44, Score = 10, ClassId = "Cleric" }).RankReward.MaxRank == 10)
	local seven = SR.Reward(SR.Standing(results, { UserId = 44, Score = 10, ClassId = "Cleric" }))
	check("Rank 7 also gets Top 20 and Top 50 rows, not the podium", #seven.Lines == 4 and table.find(seven.Titles, "Elite Ten") ~= nil and table.find(seven.Titles, "Elite Fifty") ~= nil and table.find(seven.Titles, "Podium") == nil)
	check("Rank 15 fits Top 20", SR.Standing(results, { UserId = 55, Score = 10, ClassId = "Cleric" }).RankReward.MaxRank == 20)
	check("Rank 40 fits Top 50", SR.Standing(results, { UserId = 66, Score = 9, ClassId = "Cleric" }).RankReward.MaxRank == 50)
	local plain = SR.Standing(results, { UserId = 999, Score = 5, ClassId = "Cleric" })
	check("An ordinary player gets only the percentile layer", plain.Ranked and plain.RankReward == nil and plain.ClassReward == nil)
	check("Class rank uses the player's own class board", SR.Standing(results, { UserId = 22, Score = 12, ClassId = "Mage" }).ClassReward.MaxRank == 1 and SR.Standing(results, { UserId = 22, Score = 12, ClassId = "Warrior" }).ClassReward == nil)
	check("Second best Warrior gets the Top 3 class row", SR.Standing(results, { UserId = 77, Score = 8, ClassId = "Warrior" }).ClassReward.MaxRank == 3)

	-- every percentile row pays something, and better places never pay less
	local pays, monotone = true, true
	for i, row in ipairs(Config.Percentiles) do
		pays = pays and row.Sunstones > 0
		if i > 1 then
			monotone = monotone and Config.Percentiles[i - 1].Sunstones >= row.Sunstones
		end
	end
	check("Nobody is left out: all 10 brackets pay Sunstones", #Config.Percentiles == 10 and pays and Config.Percentiles[10].Top == 1)
	check("Better percentiles never pay less", monotone)
	local rankMonotone = true
	for i = 2, #Config.Ranks do
		rankMonotone = rankMonotone and Config.Ranks[i - 1].Sunstones >= Config.Ranks[i].Sunstones and Config.Ranks[i - 1].MaxRank < Config.Ranks[i].MaxRank
	end
	check("Rank rewards shrink as the rank widens", rankMonotone)

	-- claiming
	local p = ProfileTemplate.New()
	p.Season.Currencies.Wishstones = 5
	p.Season.SeasonId = 2 -- already playing the next season (claimed during season 1, the Wishstones wait: SeasonRolloverTests)
	local ok, claimed = SR.Claim(p, 1, results, { UserId = 11, Score = 12, ClassId = "Warrior" })
	check("Claim succeeds", ok == true)
	check("Claim adds Sunstones", Premium.Sunstones(p) == expected)
	check("Claim adds Wishstones", p.Season.Currencies.Wishstones == 5 + Config.Percentiles[1].Wishstones)
	local petTickets = Config.Percentiles[1].Tickets.PetWish
	for _, row in ipairs(Config.Ranks) do
		petTickets += (row.Tickets and row.Tickets.PetWish) or 0
	end
	check("Claim adds tickets from every row", Consumables.Count(p, "PetWish") == petTickets)
	check("Claim records titles and cosmetics", p.Permanent.Titles["Champion"] == true and p.Permanent.Cosmetics["Aura_Champion"] == true)
	check("Claim writes season history", p.Permanent.SeasonHistory["1"] ~= nil and p.Permanent.SeasonHistory["1"].Rank == 1)
	local ok2, why = SR.Claim(p, 1, results, { UserId = 11, Score = 12, ClassId = "Warrior" })
	check("Second claim is refused", ok2 == false and why == "AlreadyClaimed" and Premium.Sunstones(p) == expected)
	check("Claimed reads true", SR.Claimed(p, 1) and not SR.Claimed(p, 2))
	local q = ProfileTemplate.New()
	local ok3, why3 = SR.Claim(q, 1, results, { UserId = 5, Score = 1, ClassId = "Warrior" })
	check("Unranked players cannot claim", ok3 == false and why3 == "NotRanked" and Premium.Sunstones(q) == 0 and not SR.Claimed(q, 1))
	check("Brackets list is complete", #SR.Brackets().Percentiles == 10 and #SR.Brackets().Ranks == 6 and #SR.Brackets().ClassRanks == 3)

	-- non-Sunstone prizes
	check("Rank 1 Warrior earns Crownling, Laurelwing and the class pet Bannerhound", #reward.Pets == 3 and table.find(reward.Pets, "Crownling") and table.find(reward.Pets, "Laurelwing") and table.find(reward.Pets, "Bannerhound"))
	check("Rank 1 gets the gold aura and the Warrior aura", table.find(reward.Cosmetics, "Aura_Champion") ~= nil and table.find(reward.Cosmetics, "Aura_Warrior") ~= nil and table.find(reward.Cosmetics, "Kill_Sparks") ~= nil)
	check("Prizes come with readable names for the screen", table.find(reward.Extras, "Pet: Crownling") ~= nil and table.find(reward.Extras, "Warrior aura") ~= nil and table.find(reward.Extras, "Champion aura") ~= nil)
	check("Claim gives the pets and cosmetics", p.Permanent.Pets.Crownling == true and p.Permanent.Pets.Laurelwing == true and p.Permanent.Pets.Bannerhound == true and p.Permanent.Cosmetics.Aura_Warrior == true)
	local mageResults = { Total = 100, Histogram = { [10] = 100 }, Top = {}, ClassTop = { Mage = { [5] = 1 } } }
	local mageReward = SR.Reward(SR.Standing(mageResults, { UserId = 5, Score = 10, ClassId = "Mage" }))
	check("A Mage best earns the Arcanix prize pet", #mageReward.Pets == 1 and mageReward.Pets[1] == "Arcanix" and mageReward.Sunstones > 0)
	local owned = ProfileTemplate.New()
	owned.Permanent.Pets.Bannerhound = true
	SR.Claim(owned, 1, results, { UserId = 11, Score = 12, ClassId = "Warrior" })
	check("A prize pet you already own becomes a copy", Pets.Copies(owned, "Bannerhound") == 1)
	local rewardPetsOk, wishable = true, false
	for _, row in ipairs(Config.Ranks) do
		rewardPetsOk = rewardPetsOk and (row.Pet == nil or (PetConfig.Defs[row.Pet] ~= nil and PetConfig.Defs[row.Pet].Reward == true))
		wishable = wishable or (row.Pet ~= nil and PetConfig.Defs[row.Pet].Wish == true)
	end
	for _, petId in pairs(Config.ClassPets) do
		rewardPetsOk = rewardPetsOk and PetConfig.Defs[petId] ~= nil and PetConfig.Defs[petId].Reward == true
		wishable = wishable or PetConfig.Defs[petId].Wish == true
	end
	check("Every prize pet exists, is marked Reward and cannot be wished for", rewardPetsOk and not wishable)
	local function peak(id) -- a pet's total stat power at level 1 rank 1
		local total = 0
		for _, mod in ipairs(Pets.Mods(id, 1, 1)) do
			total += mod.Value / PetConfig.StatUnits[mod.Stat].Base -- in units of that stat's base size, so different stats compare fairly
		end
		return total
	end
	local strongest = 0
	for id, def in pairs(PetConfig.Defs) do
		if def.Wish and peak(id) > strongest then
			strongest = peak(id)
		end
	end
	check("Laurelwing and Crownling are Legendary", PetConfig.Defs.Laurelwing.Rarity == "Legendary" and PetConfig.Defs.Crownling.Rarity == "Legendary")
	check("Every season prize pet out-stats the best wishable pet", peak("Crownling") > strongest and peak("Laurelwing") > strongest and peak("Bannerhound") > strongest and peak("Haloette") > strongest)
	local classHigher = Config.ClassRanks[1].Sunstones > Config.Ranks[1].Sunstones
	check("Class awards are worth more than the matching overall rows", classHigher)
	local rank50 = SR.Reward(SR.Standing({ Total = 1000, Histogram = { [12] = 1000 }, Top = { [1] = 30 }, ClassTop = {} }, { UserId = 1, Score = 12, ClassId = "Cleric" }))
	check("Rank 21-50 gets a cosmetic and a title as well as Sunstones", #rank50.Cosmetics == 1 and #rank50.Titles == 1 and rank50.Sunstones > 0)

	print(("SeasonRewardsTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
