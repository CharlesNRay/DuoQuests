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

	profile.Season.Currencies.Gold = 0
	check("Levelling needs gold", select(2, Pets.LevelUp(profile, "Slimey")) == "NotEnough" and Pets.Level(profile, "Slimey") == 1)
	profile.Season.Currencies.Gold = 1000
	local before = profile.Season.Currencies.Gold
	check("Levelling pays the cost", Pets.LevelUp(profile, "Slimey") and Pets.Level(profile, "Slimey") == 2 and before - profile.Season.Currencies.Gold == Pets.LevelCost(1))
	for _ = 1, 20 do
		profile.Season.Currencies.Gold = 100000
		Pets.LevelUp(profile, "Slimey")
	end
	check("Pets stop at the max level", Pets.Level(profile, "Slimey") == Pets.MaxLevel and select(2, Pets.LevelUp(profile, "Slimey")) == "MaxLevel")

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
	check("The pet bonus is small (under 20% at max level)", bigger.Stats.MaxHealth < plain.Stats.MaxHealth * 1.2)
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
		check("Pet " .. petId .. " has a look and a bonus", def ~= nil and def.Look ~= nil and def.Bonus ~= nil and def.Id == petId)
	end

	print(("PetTests done: %d passed, %d failed"):format(passed, failed))
end
