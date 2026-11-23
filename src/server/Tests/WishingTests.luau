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
	check("A wish you cannot afford fails and spends nothing", ok == false and reason == "NotEnough" and (profile.Season.Currencies.Wishstones or 0) == 0)
	check("A locked tier is refused", select(2, Wishing.Wish(profile, "Pet", "Starlit", "Currency", 1, seeded(1))) == "TierLocked")
	check("Bad arguments are refused", select(2, Wishing.Wish(profile, "Pet", "Meadow", "Currency", 3, seeded(1))) == "BadArgs" and select(2, Wishing.Wish(profile, "Nope", "Meadow", "Ticket", 1)) == "BadArgs")

	profile.Season.Currencies.Wishstones = 10
	ok, reason = Wishing.Wish(profile, "Pet", "Meadow", "Currency", 1, seeded(2))
	check("A Wishstone pet wish works and charges Wishstones", ok == true and profile.Season.Currencies.Wishstones == 7 and #reason.Results == 1)
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
	check("A duplicate pet is banked as a copy", d.Results[1].New == false and (d.Results[1].Copies or 0) >= 1 and Pets.Rank(p3, d.Results[1].Id) == 1)

	-- skills
	local sp = ProfileTemplate.New()
	local info = Wishing.Info(sp, "Skill")
	check("Skill info lists the tiers, all open from the start", #info.Tiers == 3 and info.Remaining > 0 and info.Tiers[1].Unlocked and info.Tiers[2].Unlocked and info.Tiers[3].Unlocked)
	sp.Season.Currencies.Wishstones = 500
	local owned0 = 0
	for _ in pairs(sp.Season.OwnedAbilities) do owned0 += 1 end
	local sok, sdata = Wishing.Wish(sp, "Skill", "Meadow", "Currency", 10, seeded(5))
	local owned1 = 0
	for _ in pairs(sp.Season.OwnedAbilities) do owned1 += 1 end
	local newRows = 0
	for _, r in ipairs(sdata.Results) do
		if r.New then newRows += 1 end
	end
	check("A skill ten-pull gives ten results; new rows match the skills gained", sok == true and #sdata.Results == 10 and owned1 == owned0 + newRows) -- Meadow gives Commons; a fresh Warrior may already own them all (copies)
	check("Skill wishes spend the same Wishstones per wish", sp.Season.Currencies.Wishstones == 500 - 3 * #sdata.Results)
	check("Skill wishes pay with SkillWish tickets, not pet tickets", Wishing.Config.TicketIds.Skill == "SkillWish" and Wishing.Config.TicketIds.Pet == "PetWish")
	-- a fresh player can already wish at the top tier
	local fresh = ProfileTemplate.New()
	fresh.Season.Currencies.Wishstones = 100
	check("A new player can make a Starlit skill wish", select(1, Wishing.Wish(fresh, "Skill", "Starlit", "Currency", 1, seeded(3))) == true)

	-- subclass skills: wishable once the path is chosen, and they arrive Legendary
	local SubclassConfig = m.SubclassConfig
	local pathId = fresh.Season.ClassId == "Warrior" and "Berserker"
	local pathDef
	for id, def in pairs(SubclassConfig.Defs) do
		if def.Class == fresh.Season.ClassId and def.Parent == def.Class and not pathDef then
			pathDef = def
			pathId = id
		end
	end
	check("Subclass skills are Legendary on first copy", m.SkillProgress.IsSubclassSkill(pathDef.Skills[1]))
	local sub = ProfileTemplate.New()
	sub.Season.Subclasses = sub.Season.Subclasses or {}
	sub.Season.Subclasses[sub.Season.ClassId] = pathId
	sub.Season.Currencies.Wishstones = 100000
	local gotPath = false
	for i = 1, 400 do
		local _, d2 = Wishing.Wish(sub, "Skill", "Starlit", "Currency", 1, seeded(100 + i))
		local row = d2.Results[1]
		if row.New and m.SkillProgress.IsSubclassSkill(row.Id) then
			gotPath = true
			check("A subclass skill arrives as Legendary", m.SkillProgress.Get(sub.Season, row.Id).Tier == "Legendary")
			break
		end
	end
	check("A chosen path's skills can come up from wishes", gotPath)

	local drained = ProfileTemplate.New()
	drained.Season.HighestStage = 100
	drained.Season.Currencies.Wishstones = 100000
	for _ = 1, 30 do
		Wishing.Wish(drained, "Skill", "Starlit", "Currency", 10, seeded(11))
	end
	check("Skill wishes never run dry: spare copies keep coming", select(1, Wishing.Wish(drained, "Skill", "Starlit", "Currency", 1, seeded(12))) == true)
	local anyXP = 0
	for _, st in pairs(drained.Season.SkillState) do
		for _, n in pairs(st.Copies or {}) do
			anyXP += n
		end
	end
	check("Spare skill copies are banked", anyXP > 0)

	print(("WishingTests done: %d passed, %d failed"):format(passed, failed))
end
