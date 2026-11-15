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

	-- the enhanced starter pack is bigger than the first and costs more, also once per account
	local starter, enhanced
	for _, item in ipairs(Config.Items) do
		if item.Id == "StarterPack" then starter = item end
		if item.Id == "EnhancedStarter" then enhanced = item end
	end
	check("The Enhanced Starter Pack gives more and costs more", enhanced and enhanced.Cost > starter.Cost and enhanced.Grants.SkillPicks > starter.Grants.SkillPicks and enhanced.Grants.BagUpgrades > starter.Grants.BagUpgrades)
	local picksE = s.Season.Currencies.SkillPicks
	check("The Enhanced Starter Pack grants its skill picks", select(1, Premium.Buy(s, "EnhancedStarter")) and s.Season.Currencies.SkillPicks == picksE + enhanced.Grants.SkillPicks)
	check("The Enhanced Starter Pack is once per account", select(2, Premium.Buy(s, "EnhancedStarter")) == "LimitReached")
	local hasLevelPack = false
	for _, item in ipairs(Config.Items) do if item.Id == "LevelPack" or item.Id == "PassBoost" then hasLevelPack = true end end
	check("The level-up pack and the +5 pass boost are gone", not hasLevelPack)

	-- the subclass pack waits for the subclass level, pops up once, then is listed in the shop
	local sub = ProfileTemplate.New()
	Premium.AddSunstones(sub, 5000)
	local function listed(profile, id)
		for _, row in ipairs(Premium.List(profile)) do
			if row.Id == id and not row.Hidden then return true end
		end
		return false
	end
	check("No subclass offer before the subclass level", Premium.Offer(sub) == nil and not listed(sub, "SubclassPack") and select(2, Premium.Buy(sub, "SubclassPack")) == "LimitReached")
	sub.Season.Level = 30
	local offer = Premium.Offer(sub)
	check("The subclass level pops the Subclass Pack up", offer ~= nil and offer.Id == "SubclassPack" and offer.Cost == 180)
	check("It is not in the shop list until the pop-up is closed", not listed(sub, "SubclassPack"))
	Premium.DismissOffer(sub, "SubclassPack")
	check("Closing the pop-up lists it in the shop", Premium.Offer(sub) == nil and listed(sub, "SubclassPack"))
	check("The Subclass Pack gives skill picks", select(1, Premium.Buy(sub, "SubclassPack")) and sub.Season.Currencies.SkillPicks == 4)
	check("The Subclass Pack is once per season", select(2, Premium.Buy(sub, "SubclassPack")) == "LimitReached")
	local buyFirst = ProfileTemplate.New()
	buyFirst.Season.Level = 30
	Premium.AddSunstones(buyFirst, 500)
	check("Buying from the pop-up needs no earlier close", select(1, Premium.Buy(buyFirst, "SubclassPack")) and Premium.Offer(buyFirst) == nil)

	-- pass: premium, max-out, and the cheaper bundle
	local function cost(id)
		for _, item in ipairs(Config.Items) do if item.Id == id then return item.Cost end end
	end
	check("The bundle is cheaper than buying the pass and the max-out separately", cost("PassBundle") < cost("PremiumPass") + cost("PassMax") and cost("PassMax") > cost("PremiumPass"))
	local b1 = ProfileTemplate.New()
	Premium.AddSunstones(b1, 5000)
	check("Max-out lists before it is bought", listed(b1, "PassMax") and listed(b1, "PassBundle") and listed(b1, "PremiumPass"))
	local ok2 = Premium.Buy(b1, "PassBundle")
	local passB = Quests.Pass(b1)
	check("The bundle unlocks premium and maxes the pass", ok2 and passB.Premium and passB.Level == passB.MaxLevel)
	check("The bundle spent its price", Premium.Sunstones(b1) == 5000 - cost("PassBundle"))
	check("Nothing pass-related is sold afterwards", not listed(b1, "PassMax") and not listed(b1, "PassBundle") and not listed(b1, "PremiumPass"))
	local b2 = ProfileTemplate.New()
	Premium.AddSunstones(b2, 5000)
	Premium.Buy(b2, "PassMax")
	check("Max-out takes the pass to the top level without premium", Quests.Pass(b2).Level == Quests.Pass(b2).MaxLevel and not Quests.Pass(b2).Premium)
	check("The bundle is gone once the pass is maxed", not listed(b2, "PassBundle") and select(2, Premium.Buy(b2, "PassBundle")) == "LimitReached")
	check("The Premium Pass can still be bought alone afterwards", listed(b2, "PremiumPass") and select(1, Premium.Buy(b2, "PremiumPass")) and Quests.Pass(b2).Premium)
	local b3 = ProfileTemplate.New()
	Premium.AddSunstones(b3, 5000)
	Premium.Buy(b3, "PremiumPass")
	check("The bundle is gone once premium is owned, max-out stays", not listed(b3, "PassBundle") and listed(b3, "PassMax"))

	local counts = Consumables.Count(s, "PetFood")
	Premium.Buy(s, "BoostBundle")
	Premium.Buy(s, "BoostBundle")
	check("The Boost Bundle can be bought again and again", Consumables.Count(s, "PetFood") == counts + 20)

	-- season limits reset with the season; the account-wide purchase and Sunstones stay
	local fresh = ProfileTemplate.NewSeasonData(2)
	s.Season = fresh
	local subRow
	for _, row in ipairs(Premium.List(s)) do if row.Id == "BagPack" then subRow = row end end
	check("Season-limited items are available again next season", subRow ~= nil and subRow.Left == subRow.Max)
	check("Sunstones and account purchases survive the season reset", Premium.Sunstones(s) > 0 and select(2, Premium.Buy(s, "StarterPack")) == "LimitReached")

	local rows = Premium.List(ProfileTemplate.New())
	check("The shop lists every item with its price", #rows == #Config.Items and rows[1].Cost == Config.Items[1].Cost)

	print(("PremiumTests done: %d passed, %d failed"):format(passed, failed))
end
