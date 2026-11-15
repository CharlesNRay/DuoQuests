--[[
	PremiumTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PremiumTests

	  require(game.ServerScriptService.Server.Tests.PremiumTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Premium = require(Shared.Premium), PremiumConfig = require(Shared.Config.Premium), ProfileTemplate = require(Shared.ProfileTemplate),
		Quests = require(Shared.Quests), Consumables = require(Shared.Consumables), Gear = require(Shared.Gear),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Premium, Config, ProfileTemplate, Quests, Consumables, Gear = m.Premium, m.PremiumConfig, m.ProfileTemplate, m.Quests, m.Consumables, m.Gear
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

	local p = ProfileTemplate.New()
	check("Sunstones start at 0", Premium.Sunstones(p) == 0)
	check("Wishstones and Sunstones are separate balances", (p.Season.Currencies.Wishstones or 0) == 0 and Premium.AddSunstones(p, 50) == 50 and (p.Season.Currencies.Wishstones or 0) == 0)

	-- packs: the first purchase of each pack doubles it
	local q = ProfileTemplate.New()
	local ok1, r1 = Premium.AddPack(q, "Sun1")
	check("A pack adds its Sunstones plus a first-time bonus", ok1 and r1.Bonus == Config.Packs[1].FirstBonus and Premium.Sunstones(q) == Config.Packs[1].Sunstones + Config.Packs[1].FirstBonus)
	local before = Premium.Sunstones(q)
	local _, r2 = Premium.AddPack(q, "Sun1")
	check("The second purchase of the same pack has no bonus", r2.Bonus == 0 and Premium.Sunstones(q) == before + Config.Packs[1].Sunstones)
	local _, r3 = Premium.AddPack(q, "Sun2")
	check("Another pack still has its own first-time bonus", r3.Bonus == Config.Packs[2].FirstBonus)
	check("An unknown pack is refused", select(2, Premium.AddPack(q, "Nope")) == "BadPack")
	check("The pack list shows what the next purchase would add", Premium.Packs(q)[1].Bonus == 0 and Premium.Packs(q)[4].Bonus == Config.Packs[4].FirstBonus)

	-- nothing in the shop sells random rewards, Wishstones or tickets
	local clean = true
	for _, item in ipairs(Config.Items) do
		local g = item.Grants
		if g.Wishstones or g.Tickets then clean = false end
		for id in pairs(g.Items or {}) do
			if id == "PetWish" or id == "SkillWish" then clean = false end
		end
	end
	check("No shop item grants Wishstones or wish tickets", clean)

	-- buying
	local s = ProfileTemplate.New()
	check("Buying without Sunstones is refused", select(2, Premium.Buy(s, "StarterPack")) == "NotEnough")
	check("An unknown item is refused", select(2, Premium.Buy(s, "Nope")) == "BadItem")
	Premium.AddSunstones(s, 5000)
	local picksBefore, bagBefore = s.Season.Currencies.SkillPicks, Gear.Cap(s)
	local ok, res = Premium.Buy(s, "StarterPack")
	check("The Starter Pack grants picks, consumables and a bag upgrade", ok and s.Season.Currencies.SkillPicks == picksBefore + 3 and Consumables.Count(s, "XPTonic") >= 5 and Gear.Cap(s) > bagBefore)
	check("Buying spends Sunstones", Premium.Sunstones(s) == 5000 - Config.Items[1].Cost)
	check("The Starter Pack is once per account", select(2, Premium.Buy(s, "StarterPack")) == "LimitReached")

	local levelBefore = s.Season.Level
	for _ = 1, 3 do assert(Premium.Buy(s, "LevelPack")) end
	check("The Level-up Pack gives 3 hero levels each", s.Season.Level == levelBefore + 9)
	check("The Level-up Pack is limited per season", select(2, Premium.Buy(s, "LevelPack")) == "LimitReached")

	local passBefore = Quests.Pass(s).Level
	Premium.Buy(s, "PassBoost")
	check("The Pass Boost raises the pass level by 5", Quests.Pass(s).Level == passBefore + 5)

	check("The Premium Pass item unlocks the premium track", not Quests.Pass(s).Premium and Premium.Buy(s, "PremiumPass") and Quests.Pass(s).Premium)
	check("The Premium Pass cannot be bought twice", select(2, Premium.Buy(s, "PremiumPass")) == "LimitReached")
	local hidden = false
	for _, row in ipairs(Premium.List(s)) do
		if row.Id == "PremiumPass" and row.Hidden then hidden = true end
	end
	check("The Premium Pass row hides once owned", hidden)

	local counts = Consumables.Count(s, "PetFood")
	Premium.Buy(s, "BoostBundle")
	Premium.Buy(s, "BoostBundle")
	check("The Boost Bundle can be bought again and again", Consumables.Count(s, "PetFood") == counts + 20)

	-- season limits reset with the season; the account-wide purchase and Sunstones stay
	local fresh = ProfileTemplate.NewSeasonData(2)
	s.Season = fresh
	check("Season-limited items are available again next season", Premium.List(s)[2].Left == 3)
	check("Sunstones and account purchases survive the season reset", Premium.Sunstones(s) > 0 and select(2, Premium.Buy(s, "StarterPack")) == "LimitReached")

	local rows = Premium.List(ProfileTemplate.New())
	check("The shop lists every item with its price", #rows == #Config.Items and rows[1].Cost == Config.Items[1].Cost)

	print(("PremiumTests done: %d passed, %d failed"):format(passed, failed))
end
