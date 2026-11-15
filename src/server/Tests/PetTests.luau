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

	check("Unknown pets are refused", select(2, Pets.Equip(profile, "Nope")) == "UnknownPet")
	check("A pet you do not own cannot be equipped", select(2, Pets.Equip(profile, "Foxling")) == "NotOwned")

	-- pets level from XP (food, fighting), never for gold; duplicates rank them up
	check("Pets can no longer be levelled with gold", Pets.LevelUp == nil and Pets.LevelCost == nil)
	check("A new pet is rank 1", Pets.Rank(profile, "Slimey") == 1)
	local kind, newRank = Pets.AddDuplicate(profile, "Slimey")
	check("A duplicate raises the rank by one", kind == "Rank" and newRank == 2 and Pets.Rank(profile, "Slimey") == 2)
	for _ = 1, 10 do
		Pets.AddDuplicate(profile, "Slimey")
	end
	check("Rank stops at the max; extra duplicates give pet XP", Pets.Rank(profile, "Slimey") == PetConfig.MaxRank and select(1, Pets.AddDuplicate(profile, "Slimey")) == "XP")
	local lowRank = Pets.Mods("Slimey", 1, 1)[1].Value
	local highRank = Pets.Mods("Slimey", 1, PetConfig.MaxRank)[1].Value
	check("A higher rank gives a bigger bonus", highRank > lowRank * 2)
	Pets.AddXP(profile, "Slimey", 100000)
	check("Pets stop at the max level", Pets.Level(profile, "Slimey") == Pets.MaxLevel)
	profile.Permanent.PetRanks.Slimey = 1
	profile.Season.PetLevels.Slimey = 1

	for stage = 2, 25 do
		Progression.ApplyClear(profile, stage)
	end
	check("Stage 5 gives Foxling; wish-only pets are not handed out", profile.Permanent.Pets.Foxling and not profile.Permanent.Pets.Mossback and not profile.Permanent.Pets.Wisp)
	check("Equipping a pet changes the active pet", Pets.Equip(profile, "Foxling") and Pets.Active(profile) == "Foxling")

	-- a new season keeps ownership but resets equip and levels
	profile.Season = ProfileTemplate.NewSeasonData(2)
	check("After a season reset you still get a pet", Pets.Active(profile) == "Slimey" and Pets.Level(profile, "Slimey") == 1)

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
	local last = withSkill.Abilities[#withSkill.Abilities]
	check("A pet's skill joins its owner's abilities at the pet's rank", last.Id == "Pet_Emberkit" and last.Level == 3 and plain.Abilities[#plain.Abilities].Id ~= "Pet_Emberkit")
	check("A snapshot carries the pet rank", snap.PetRank == 1)

	print(("PetTests done: %d passed, %d failed"):format(passed, failed))
end
