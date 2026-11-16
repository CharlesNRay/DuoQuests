--[[
	MarketTests (ModuleScript): the gold Market.
	  require(game.ServerScriptService.Server.Tests.MarketTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Market = require(Shared.Market), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Market, ProfileTemplate = m.Market, m.ProfileTemplate
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

	local now, season = 86400 * 20000, 1
	local p = ProfileTemplate.New()
	p.Season.HighestStage = 15
	check("Unknown items are refused", select(2, Market.Buy(p, "Nope", now, season)) == "Unknown")
	check("It needs gold", select(2, Market.Buy(p, "PetWish", now, season)) == "NotEnough")
	p.Season.Currencies.Gold = 1e9
	local list = Market.Of(p, now, season)
	local first = list[1]
	check("Items list their limit and a price", #list == #Market.Items and first.Price > 0 and first.Bought == 0)
	local before = p.Season.Currencies.Gold
	local ok, lines = Market.Buy(p, "PetWish", now, season)
	check("A purchase takes gold and gives the item", ok and #lines > 0 and p.Season.Currencies.Gold == before - first.Price)
	check("The price rises with each purchase", Market.Of(p, now, season)[1].Price > first.Price)
	Market.Buy(p, "PetWish", now, season)
	Market.Buy(p, "PetWish", now, season)
	check("A daily cap is enforced", select(2, Market.Buy(p, "PetWish", now, season)) == "SoldOut")
	check("The cap resets the next day", Market.Of(p, now + 86400, season)[1].Bought == 0 and Market.Buy(p, "PetWish", now + 86400, season) == true)
	local picks = p.Season.Currencies.SkillPicks or 0
	Market.Buy(p, "SkillPick", now, season)
	Market.Buy(p, "SkillPick", now, season)
	check("Season items give currencies", (p.Season.Currencies.SkillPicks or 0) == picks + 2)
	check("A season cap holds across days", select(2, Market.Buy(p, "SkillPick", now + 86400 * 3, season)) == "SoldOut")
	check("A new season refills it", Market.Buy(p, "SkillPick", now + 86400 * 3, season + 1) == true)
	local w = p.Season.Currencies.Wishstones or 0
	Market.Buy(p, "Wishstones", now, season)
	check("Wishstones are granted", (p.Season.Currencies.Wishstones or 0) == w + 10)
	print(("MarketTests done: %d passed, %d failed"):format(passed, failed))
end
