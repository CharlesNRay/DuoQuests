--[[
	SubclassTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SubclassTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.SubclassTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Subclasses = require(Shared.Subclasses),
		SubclassConfig = require(Shared.Config.Subclasses),
		Abilities = require(Shared.Config.Abilities),
		Skills = require(Shared.Skills),
		Economy = require(Shared.Economy),
		ProfileTemplate = require(Shared.ProfileTemplate),
		StatCalc = require(Shared.Combat.StatCalc),
		StageRunner = require(Shared.StageRunner),
		Party = require(Shared.Party),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Subclasses, Config, Abilities, Skills, Economy, ProfileTemplate, StatCalc, StageRunner, Party = m.Subclasses, m.SubclassConfig, m.Abilities, m.Skills, m.Economy, m.ProfileTemplate, m.StatCalc, m.StageRunner, m.Party
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

	-- data
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		local allSkills = true
		for _, skillId in ipairs(def.Skills) do
			local ability = Abilities[skillId]
			if not ability or ability.Subclass ~= id or ability.Class ~= def.Class then
				allSkills = false
			end
		end
		check(id .. ": has valid skills tagged with its own id", allSkills and #def.Skills >= 1)
	end
	check("Each class has exactly 2 paths", #Subclasses.Choices("Warrior") == 2 and #Subclasses.Choices("Cleric") == 2)

	-- choosing
	local profile = ProfileTemplate.New()
	profile.Season.Level = 29
	check("Nothing is available before the unlock stage", #Subclasses.Available(profile, "Warrior") == 0)
	check("Choosing too early is refused", select(2, Subclasses.Choose(profile, "Warrior", "Berserker")) == "Locked")
	profile.Season.Level = 30
	check("Both paths are offered at the unlock stage", #Subclasses.Available(profile, "Warrior") == 2)
	check("A path of another class is refused", select(2, Subclasses.Choose(profile, "Warrior", "Priest")) == "WrongClass")
	check("Unknown paths are refused", select(2, Subclasses.Choose(profile, "Warrior", "Nope")) == "UnknownSubclass")
	check("Skills of a path are not owned before choosing", not profile.Season.OwnedAbilities.BloodFrenzy)
	check("They cannot be bought before choosing", select(2, Economy.UnlockAbility(profile, "Warrior", "Cleave")) == "NotInPool")
	check("Choosing works", Subclasses.Choose(profile, "Warrior", "Berserker") and Subclasses.Current(profile, "Warrior") == "Berserker")
	check("The first skill is granted free", profile.Season.OwnedAbilities.BloodFrenzy == true)
	check("The other path cannot be taken afterwards", select(2, Subclasses.Choose(profile, "Warrior", "Guardian")) == "NotAvailable" and #Subclasses.Available(profile, "Warrior") == 0)
	check("The other path's skills stay locked", select(2, Economy.UnlockAbility(profile, "Warrior", "Bulwark")) == "NotInPool")
	profile.Season.Currencies.Shards = 5000
	check("The path's other skills can be bought with shards", Economy.UnlockAbility(profile, "Warrior", "Cleave") and profile.Season.OwnedAbilities.Cleave == true)
	check("The class pool shows them", table.find(Skills.Pool("Warrior", "Berserker"), "ExecutionerStrike") ~= nil and table.find(Skills.Pool("Warrior"), "ExecutionerStrike") == nil)
	check("A loadout can use a path skill", Economy.Equip(profile, "Warrior", { "BloodFrenzy", "Cleave", "Taunt", "IronSkin" }))
	check("A path skill cannot be equipped unowned", select(1, Economy.Equip(profile, "Warrior", { "ExecutionerStrike", "Cleave", "Taunt", "IronSkin" })) == false)

	-- power spike
	local function member(classId, subclassId, level)
		return StatCalc.NewPartyMember("x", "X", classId, level, { SubclassId = subclassId })
	end
	local base = member("Warrior", nil, 30)
	local berserker = member("Warrior", "Berserker", 30)
	local guardian = member("Warrior", "Guardian", 30)
	check("Berserker has much more attack", berserker.Stats.Attack >= base.Stats.Attack * 1.2)
	check("Guardian has much more health and defense", guardian.Stats.MaxHealth >= base.Stats.MaxHealth * 1.3 and guardian.Stats.Defense >= base.Stats.Defense * 1.25)
	check("Guardian takes less damage", guardian.Stats.DamageTaken < 1)
	local priest = member("Cleric", "Priest", 30)
	local templar = member("Cleric", "Templar", 30)
	local plainCleric = member("Cleric", nil, 30)
	check("Priest heals more", priest.Stats.HealingDealt >= 1.25 and plainCleric.Stats.HealingDealt == nil)
	check("Templar hits harder", templar.Stats.Attack >= plainCleric.Stats.Attack * 1.2 and templar.Stats.DamageDealt >= 1.12)

	-- a real fight: the spike clears a stage the plain party cannot beat as fast
	local function party(sub1, sub2)
		local w, c = ProfileTemplate.New(), ProfileTemplate.New()
		c.Season.ClassId = "Cleric"
		w.Season.Level, c.Season.Level = 30, 30
		if sub1 then
			w.Season.Subclasses.Warrior = sub1
		end
		if sub2 then
			c.Season.Subclasses.Cleric = sub2
		end
		return { { Id = "1", Name = "W", Profile = w }, { Id = "2", Name = "C", Profile = c } }
	end
	local plain = StageRunner.Run(party(nil, nil), 40, 11)
	local boosted = StageRunner.Run(party("Berserker", "Templar"), 40, 11)
	check("A Berserker + Templar party clears a stage faster than the plain party", (boosted.Won and not plain.Won) or (boosted.Won and plain.Won and boosted.Duration < plain.Duration))

	-- every path skill actually casts in a fight (no runtime errors)
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		local w, c = ProfileTemplate.New(), ProfileTemplate.New()
		c.Season.ClassId = "Cleric"
		local mine = if def.Class == "Warrior" then w else c
		mine.Season.Level = 30
		Subclasses.Choose(mine, def.Class, id)
		for _, skillId in ipairs(def.Skills) do
			mine.Season.OwnedAbilities[skillId] = true
		end
		mine.Season.Loadouts[def.Class] = { def.Skills[1], def.Skills[2], def.Skills[3], mine.Season.Loadouts[def.Class][1] }
		local ok, outcome = pcall(StageRunner.Run, { { Id = "1", Name = "W", Profile = w }, { Id = "2", Name = "C", Profile = c } }, 35, 5, nil, true)
		local casts = {}
		if ok then
			for _, event in ipairs(outcome.Events) do
				if event.Type == "Cast" then
					casts[event.Ability or event.AbilityId or event.Skill or "?"] = true
				end
			end
		end
		check(id .. ": a fight with its three skills runs", ok)
		local cast = 0
		for _, skillId in ipairs(def.Skills) do
			if casts[skillId] then
				cast += 1
			end
		end
		check(id .. ": its skills are cast during the fight", cast >= 1)
	end

	-- ghosts keep the path
	local snap = Party.MakeSnapshot(profile, 1, "P", nil, 0)
	check("A ghost snapshot carries the subclass and its skills", snap.SubclassId == "Berserker" and snap.Owned.BloodFrenzy == true and snap.Owned.Cleave == true)

	-- branches: a deeper tier stacks on its parent (data-only extension)
	Config.Defs.TestWarlord = { Id = "TestWarlord", Class = "Warrior", Parent = "Berserker", UnlockLevel = 60, Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.1 } }, Skills = {}, DisplayName = "T", Description = "" }
	local chain = Subclasses.Chain("TestWarlord")
	check("Deeper tiers chain through their parents", #chain == 2 and chain[1].Id == "Berserker" and chain[2].Id == "TestWarlord")
	check("Their stats and skills stack", #Subclasses.Mods("TestWarlord") == #Config.Defs.Berserker.Mods + 1 and #Subclasses.SkillIds("TestWarlord") == 3)
	table.insert(Config.Order, "TestWarlord")
	check("They are offered after the first tier", #Subclasses.Choices("Warrior", "Berserker") == 1)
	check("But not before it", #Subclasses.Choices("Warrior") == 2)
	Config.Defs.TestWarlord = nil
	table.remove(Config.Order)

	print(("SubclassTests done: %d passed, %d failed"):format(passed, failed))
end
