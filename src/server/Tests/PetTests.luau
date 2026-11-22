--[[
	PetTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PetTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PetTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Pets = require(Shared.Pets),
		PetConfig = require(Shared.Config.Pets),
		ProfileTemplate = require(Shared.ProfileTemplate),
		Progression = require(Shared.Progression),
		StatCalc = require(Shared.Combat.StatCalc),
		Party = require(Shared.Party),
		Consumables = require(Shared.Consumables),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Pets, PetConfig, ProfileTemplate, Progression, StatCalc, Party = m.Pets, m.PetConfig, m.ProfileTemplate, m.Progression, m.StatCalc, m.Party
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

	local profile = ProfileTemplate.New()
	check("A new player has no pet yet", Pets.Active(profile) == nil)

	local summary = Progression.ApplyClear(profile, 1)
	check("Clearing stage 1 gives the first pet", #summary.PetsGained == 1 and summary.PetsGained[1] == "Slimey" and profile.Permanent.Pets.Slimey == true)
	check("The first owned pet becomes active automatically", Pets.Active(profile) == "Slimey")
	check("Clearing the stage again gives nothing twice", #Progression.ApplyClear(profile, 1).PetsGained == 0)

	check("A frontier clear pays Wishstones", (profile.Season.Currencies.Wishstones or 0) >= 2 and summary.Wishstones >= 2)
	local stones = profile.Season.Currencies.Wishstones
	local replayTotal = 0
	for _ = 1, 8 do
		replayTotal += Progression.ApplyClear(profile, 1).Wishstones
	end
	check("Replays pay a Wishstone only every few clears", replayTotal == 2 and profile.Season.Currencies.Wishstones == stones + 2)
	check("Unknown pets are refused", select(2, Pets.Equip(profile, "Nope")) == "UnknownPet")
	check("A pet you do not own cannot be equipped", select(2, Pets.Equip(profile, "Foxling")) == "NotOwned")

	-- pets level from XP (food, fighting), never for gold; duplicates are banked and ranked up BY HAND
	check("Pets can no longer be levelled with gold", Pets.LevelUp == nil and Pets.LevelCost == nil)
	check("A new pet is rank 1 with no copies", Pets.Rank(profile, "Slimey") == 1 and Pets.Copies(profile, "Slimey") == 0)
	local kind, copies = Pets.AddDuplicate(profile, "Slimey")
	check("A duplicate is banked as a copy, not an automatic rank", kind == "Copy" and copies == 1 and Pets.Rank(profile, "Slimey") == 1)
	local ok, rank = Pets.RankUp(profile, "Slimey")
	check("Rank up spends the copy by hand", ok and rank == 2 and Pets.Copies(profile, "Slimey") == 0)
	check("Rank up needs enough copies", select(2, Pets.RankUp(profile, "Slimey")) == "NotEnoughCopies")
	check("Rank 2 to 3 costs " .. PetConfig.RankCost[2], PetConfig.RankCost[2] ~= nil)
	check("Unknown and unowned pets cannot rank up", select(2, Pets.RankUp(profile, "Nope")) == "UnknownPet" and select(2, Pets.RankUp(profile, "Mossback")) == "NotOwned")
	for _ = 1, 30 do
		Pets.AddDuplicate(profile, "Slimey")
		Pets.RankUp(profile, "Slimey")
	end
	check("Rank stops at the max; extra duplicates become pet shards", Pets.Rank(profile, "Slimey") == PetConfig.MaxRank and select(1, Pets.AddDuplicate(profile, "Slimey")) == "Shard" and select(2, Pets.RankUp(profile, "Slimey")) == "MaxRank")
	local total = 0
	for r = 1, PetConfig.MaxRank - 1 do
		total += PetConfig.RankCost[r]
	end
	check("A max rank pet costs a sensible number of copies", total >= 6 and total <= 14)
	local lowRank = Pets.Mods("Slimey", 1, 1)[1].Value
	local highRank = Pets.Mods("Slimey", 1, PetConfig.MaxRank)[1].Value
	check("A higher rank gives a bigger bonus", highRank > lowRank * 2)
	profile.Season.Level = 20
	Pets.AddXP(profile, "Slimey", 10000000)
	check("Pets stop at the owner's level", Pets.Level(profile, "Slimey") == 20 and select(2, Pets.AddXP(profile, "Slimey", 5)) == "MaxLevel")
	profile.Season.Level = 120
	Pets.AddXP(profile, "Slimey", 1e12)
	check("Pets stop at the max level", Pets.Level(profile, "Slimey") == Pets.MaxLevel)
	check("A pet levels faster than its owner", Pets.XPToNext(10) < m.Progression.XPToNext(10))
	profile.Season.Level = 1
	profile.Permanent.PetRanks.Slimey = 1
	profile.Permanent.PetLevels.Slimey = 1

	for stage = 2, 25 do
		Progression.ApplyClear(profile, stage)
	end
	check("Stage 5 gives Foxling; wish-only pets are not handed out", profile.Permanent.Pets.Foxling and not profile.Permanent.Pets.Mossback and not profile.Permanent.Pets.Wisp)
	check("Equipping a pet changes the active pet", Pets.Equip(profile, "Foxling") and Pets.Active(profile) == "Foxling")

	-- a new season keeps ownership, the equipped pet and its levels
	profile.Season.Level = 30
	Pets.AddXP(profile, "Foxling", 5000)
	local foxLevel = Pets.Level(profile, "Foxling")
	profile.Season = ProfileTemplate.NewSeasonData(2)
	check("After a season reset the pet and its level carry over", Pets.Active(profile) == "Foxling" and profile.Permanent.PetLevels.Foxling == foxLevel and foxLevel > 1 and Pets.Level(profile, "Foxling") == 1)
	profile.Season.Level = 30
	check("The stored pet level returns as the owner levels back up", Pets.Level(profile, "Foxling") == foxLevel)

	-- combat stats
	local plain = StatCalc.NewPartyMember("a", "A", "Warrior", 10)
	local petted = StatCalc.NewPartyMember("b", "B", "Warrior", 10, { PetId = "Slimey", PetLevel = 1 })
	local bigger = StatCalc.NewPartyMember("c", "C", "Warrior", 10, { PetId = "Slimey", PetLevel = 10 })
	check("A pet raises its stat", petted.Stats.MaxHealth > plain.Stats.MaxHealth)
	check("A higher pet level gives a bigger bonus", bigger.Stats.MaxHealth > petted.Stats.MaxHealth)
	check("The pet bonus is modest at max level", bigger.Stats.MaxHealth < plain.Stats.MaxHealth * 1.35)
	check("The entity remembers its pet for display", petted.PetId == "Slimey" and plain.PetId == nil)
	local crit = StatCalc.NewPartyMember("d", "D", "Warrior", 10, { PetId = "Wisp", PetLevel = 1 })
	check("An Add pet raises crit chance", crit.Stats.CritChance > plain.Stats.CritChance)

	-- snapshots carry the pet so a ghost fights with it
	local pp = ProfileTemplate.New()
	Progression.ApplyClear(pp, 1)
	local snap = Party.MakeSnapshot(pp, 1001, "Pat", nil, 0)
	check("A ghost snapshot carries the pet", snap.PetId == "Slimey" and snap.PetLevel == 1)

	for _, petId in ipairs(PetConfig.Order) do
		local def = PetConfig.Defs[petId]
		check("Pet " .. petId .. " has a look, 1-2 stats and its own skill", def ~= nil and def.Look ~= nil and def.Id == petId and #def.Stats >= 1 and #def.Stats <= 2 and def.Skill ~= nil and Pets.SkillId(petId) == "Pet_" .. petId)
	end
	-- single-stat pets beat multi-stat pets at the stat they share
	local single, dual = {}, {}
	for _, petId in ipairs(PetConfig.Order) do
		local def = PetConfig.Defs[petId]
		for _, entry in ipairs(def.Stats) do
			local key = def.Rarity .. entry.Stat
			if #def.Stats == 1 then single[key] = math.max(single[key] or 0, entry.Share) else dual[key] = math.max(dual[key] or 0, entry.Share) end
		end
	end
	local singleBetter = true
	for key, share in pairs(dual) do
		if single[key] and single[key] <= share then singleBetter = false end
	end
	check("A single-stat pet gives more of its stat than a multi-stat pet", singleBetter)
	local two = 0
	for _, petId in ipairs(PetConfig.Order) do if #PetConfig.Defs[petId].Stats == 2 then two += 1 end end
	check("Some pets (not all) give two stats", two >= 3 and two < #PetConfig.Order)
	local withSkill = StatCalc.NewPartyMember("e", "E", "Warrior", 10, { PetId = "Emberkit", PetLevel = 1, PetRank = 3 })
	local function slotOf(entity, id)
		for _, slot in ipairs(entity.Abilities) do
			if slot.Id == id then
				return slot
			end
		end
		return nil
	end
	local last = slotOf(withSkill, "Pet_Emberkit")
	check("A pet's skill joins its owner's abilities at the pet's rank", last ~= nil and last.Level == 3 and slotOf(plain, "Pet_Emberkit") == nil)
	check("Every pet also gets a strike of its rarity at its rank", slotOf(withSkill, "Pet_Strike_Rare") ~= nil and slotOf(withSkill, "Pet_Strike_Rare").Level == 3 and slotOf(plain, "Pet_Strike_Rare") == nil)

	-- shards ------------------------------------------------------------------------------------------
	local sp = ProfileTemplate.New()
	sp.Permanent.Pets = { Slimey = true, Foxling = true }
	local cost = PetConfig.Shards.PetCost
	local needed = Pets.CopiesWanted(sp, "Slimey")
	local kinds = {}
	for _ = 1, needed + 3 do
		table.insert(kinds, (Pets.AddDuplicate(sp, "Slimey")))
	end
	check("Copies bank until they cover max rank, then duplicates become shards", kinds[needed] == "Copy" and kinds[needed + 1] == "Shard" and Pets.Shards(sp).Common == 3)
	check("Shards are per rarity", Pets.Shards(sp).Rare == 0)
	check("Not enough shards buys nothing", select(2, Pets.BuyWithShards(sp, "Mossback")) == "NotEnoughShards" and not (sp.Permanent.Pets.Mossback == true))
	sp.Permanent.PetShards.Common = cost
	check("Shards of a rarity buy a pet of that rarity", Pets.BuyWithShards(sp, "Mossback") and sp.Permanent.Pets.Mossback == true and Pets.Shards(sp).Common == 0)
	sp.Permanent.PetShards.Common = cost
	check("Only the right rarity of shard works", select(2, Pets.BuyWithShards(sp, "Wisp")) == "NotEnoughShards")
	check("Season prize pets cannot be bought with shards", select(2, Pets.BuyWithShards(sp, "Crownling")) == "NotBuyable")
	sp.Permanent.Pets.Chirpy = true
	sp.Permanent.PetRanks = { Chirpy = PetConfig.MaxRank }
	check("A maxed pet cannot be bought again", select(2, Pets.BuyWithShards(sp, "Chirpy")) == "PetMaxed")
	sp.Permanent.PetShards = { Common = PetConfig.Shards.CondenseCost * 2 + 3, Rare = PetConfig.Shards.CondenseCost - 2 }
	local made = select(2, Pets.Condense(sp, "All"))
	check("Condense all turns commons into rares and carries upward", Pets.Shards(sp).Common == 3 and Pets.Shards(sp).Rare == 0 and Pets.Shards(sp).Epic == 1 and made.Made.Rare == 2)
	check("Nothing to condense says so", select(2, Pets.Condense(sp, "Common")) == "NothingToCondense")

	-- collecting counts --------------------------------------------------------------------------------
	local c0 = Pets.Collection(ProfileTemplate.New())
	local c1 = Pets.Collection(sp)
	check("No pets, no collection bonus", c0.Points == 0 and #c0.Mods == 0)
	check("Owning pets gives a small permanent bonus that grows with rank", c1.Points > 0 and c1.Percent > 0 and c1.Percent < 25)
	sp.Permanent.PetRanks = { Chirpy = PetConfig.MaxRank, Slimey = 6 }
	check("Ranking a pet up raises the collection bonus", Pets.Collection(sp).Points > c1.Points)
	check("A snapshot carries the pet rank", snap.PetRank == 1)

	-- VIP second pet slot ------------------------------------------------------------------------------
	local vp = ProfileTemplate.New()
	vp.Permanent.Pets = { Slimey = true, Foxling = true }
	Pets.Equip(vp, "Slimey")
	check("Without VIP there is no second slot", not Pets.HasSecondSlot(vp) and select(2, Pets.EquipSecond(vp, "Foxling")) == "NeedVIP" and #Pets.SecondMods(vp) == 0)
	vp.Permanent.Passes = { VIP = true }
	check("VIP opens the second slot", Pets.HasSecondSlot(vp))
	check("The main pet cannot also be the second", select(2, Pets.EquipSecond(vp, "Slimey")) == "AlreadyMain")
	check("An unowned pet cannot be the second", select(2, Pets.EquipSecond(vp, "Mossback")) == "NotOwned")
	check("A second pet adds its stat bonuses", Pets.EquipSecond(vp, "Foxling") == true and Pets.Second(vp) == "Foxling" and #Pets.SecondMods(vp) == #Pets.Mods("Foxling", Pets.Level(vp, "Foxling"), Pets.Rank(vp, "Foxling")) and #Pets.SecondMods(vp) > 0)
	local vsnap = m.Party.MakeSnapshot(vp, 7, "V", nil, 0)
	check("A ghost snapshot keeps the second pet's bonuses", #vsnap.CollectionMods == #Pets.Collection(vp).Mods + #Pets.SecondMods(vp))
	Pets.Equip(vp, "Foxling")
	check("Making the second pet the main one empties the second slot", Pets.Second(vp) == nil and (Pets.Active(vp)) == "Foxling")
	Pets.EquipSecond(vp, "Slimey")
	check("Clearing the second slot works", Pets.EquipSecond(vp, "") == true and Pets.Second(vp) == nil)
	vp.Permanent.Passes = {}
	Pets.EquipSecond(vp, nil)
	check("Losing VIP switches the second pet off", Pets.Second(vp) == nil and #Pets.SecondMods(vp) == 0)

	-- food for a pet at its cap turns into pet shard progress (2026-11-22)
	local fp = m.ProfileTemplate.New()
	fp.Permanent.Pets = fp.Permanent.Pets or {}
	fp.Permanent.Pets.Slimey = true
	Pets.Equip(fp, "Slimey")
	fp.Season.PetLevels = fp.Season.PetLevels or {}
	fp.Season.PetLevels.Slimey = Pets.LevelCap(fp)
	local rarity = m.PetConfig.Defs.Slimey.Rarity
	local before = Pets.Shards(fp)[rarity]
	m.Consumables.Grant(fp, "PetFood", 10)
	local fed = 0
	for _ = 1, 10 do
		if m.Consumables.Use(fp, "PetFood", 0, "Slimey") then fed += 1 end
	end
	check("A capped pet still eats (food is not wasted)", fed == 10 and m.Consumables.Count(fp, "PetFood") == 0)
	check("10 snacks at the cap = 1 pet shard of the pet's rarity", Pets.Shards(fp)[rarity] == before + 1 and (fp.Permanent.PetFoodOverflow or 0) == 0)
	m.Consumables.Grant(fp, "PetFood", 1)
	m.Consumables.Use(fp, "PetFood", 0, "Slimey")
	check("Leftover overflow XP is kept for the next shard", fp.Permanent.PetFoodOverflow == 1600)

	print(("PetTests done: %d passed, %d failed"):format(passed, failed))
end
