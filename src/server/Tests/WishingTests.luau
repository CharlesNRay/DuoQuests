--[[
	WishingTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > WishingTests
	  require(game.ServerScriptService.Server.Tests.WishingTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Wishing = require(Shared.Wishing), Consumables = require(Shared.Consumables), ProfileTemplate = require(Shared.ProfileTemplate),
		Pets = require(Shared.Pets), PetConfig = require(Shared.Config.Pets), Abilities = require(Shared.Config.Abilities),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Wishing, Consumables, ProfileTemplate, Pets, PetConfig = m.Wishing, m.Consumables, m.ProfileTemplate, m.Pets, m.PetConfig
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
	local function seeded(seed)
		local state = seed
		return function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
	end

	local profile = ProfileTemplate.New()
	local ok, reason = Wishing.Wish(profile, "Pet", "Meadow", "Currency", 1, seeded(1))
	check("A wish you cannot afford fails and spends nothing", ok == false and reason == "NotEnough" and profile.Season.Currencies.Gold == 0)
	check("A locked tier is refused", select(2, Wishing.Wish(profile, "Pet", "Starlit", "Currency", 1, seeded(1))) == "TierLocked")
	check("Bad arguments are refused", select(2, Wishing.Wish(profile, "Pet", "Meadow", "Currency", 3, seeded(1))) == "BadArgs" and select(2, Wishing.Wish(profile, "Nope", "Meadow", "Ticket", 1)) == "BadArgs")

	profile.Season.Currencies.Gold = 1000
	ok, reason = Wishing.Wish(profile, "Pet", "Meadow", "Currency", 1, seeded(2))
	check("A gold pet wish works and charges gold", ok == true and profile.Season.Currencies.Gold == 800 and #reason.Results == 1)
	check("The pet is owned afterwards", profile.Permanent.Pets[reason.Results[1].Id] == true)

	Consumables.Grant(profile, "PetWish", 12)
	ok, reason = Wishing.Wish(profile, "Pet", "Meadow", "Ticket", 10, seeded(3))
	check("A ten-pull with tickets spends ten tickets", ok == true and Consumables.Count(profile, "PetWish") == 2 and #reason.Results == 10)
	local best = 0
	for _, row in ipairs(reason.Results) do
		best = math.max(best, ({ Common = 1, Rare = 2, Epic = 3, Legendary = 4 })[row.Rarity])
	end
	check("A ten-pull always has a Rare or better (pity)", best >= 2)

	-- hard pity: with terrible luck (always rolls the top of the table = Epic odds at the end) pity still bites
	local p2 = ProfileTemplate.New()
	p2.Season.HighestStage = 100
	Consumables.Grant(p2, "PetWish", 200)
	local sinceRare, worstGap, gap = 0, 0, 0
	local rareOrBetter = 0
	for i = 1, 200 do
		local good, data = Wishing.Wish(p2, "Pet", "Meadow", "Ticket", 1, function() return 0.0 end) -- rolls Common first
		local row = data.Results[1]
		if row.Rarity ~= "Common" then
			rareOrBetter += 1
			worstGap = math.max(worstGap, gap)
			gap = 0
		else
			gap += 1
		end
	end
	check("Pity: never more than 9 wishes in a row without a Rare+", worstGap <= 9 and rareOrBetter >= 15)

	-- duplicates become pet XP
	local p3 = ProfileTemplate.New()
	p3.Season.HighestStage = 100
	for id, def in pairs(PetConfig.Defs) do
		if def.Wish then
			p3.Permanent.Pets = p3.Permanent.Pets or {}
			p3.Permanent.Pets[id] = true
		end
	end
	Consumables.Grant(p3, "PetWish", 3)
	local _, d = Wishing.Wish(p3, "Pet", "Meadow", "Ticket", 1, seeded(9))
	check("A duplicate pet gives pet XP instead", d.Results[1].New == false and (d.Results[1].DupXP or 0) > 0)

	-- skills
	local sp = ProfileTemplate.New()
	local info = Wishing.Info(sp, "Skill")
	check("Skill info lists the tiers and what is left to find", #info.Tiers == 3 and info.Remaining > 0 and info.Tiers[1].Unlocked and not info.Tiers[3].Unlocked)
	sp.Season.Currencies.Shards = 500
	local owned0 = 0
	for _ in pairs(sp.Season.OwnedAbilities) do owned0 += 1 end
	local sok, sdata = Wishing.Wish(sp, "Skill", "Meadow", "Currency", 10, seeded(5))
	local owned1 = 0
	for _ in pairs(sp.Season.OwnedAbilities) do owned1 += 1 end
	check("A skill ten-pull unlocks new skills only", sok == true and owned1 == owned0 + #sdata.Results and #sdata.Results >= 1)
	check("Skill wishes spend shards per wish", sp.Season.Currencies.Shards == 500 - 40 * #sdata.Results)
	local drained = ProfileTemplate.New()
	drained.Season.HighestStage = 100
	drained.Season.Currencies.Shards = 100000
	for _ = 1, 30 do
		Wishing.Wish(drained, "Skill", "Starlit", "Currency", 10, seeded(11))
	end
	check("When every skill is owned the wish says NothingLeft", select(2, Wishing.Wish(drained, "Skill", "Starlit", "Currency", 1, seeded(12))) == "NothingLeft")

	print(("WishingTests done: %d passed, %d failed"):format(passed, failed))
end
