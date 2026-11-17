--[[
	NewClassTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > NewClassTests

	Mage, Ranger, Rogue and Summoner: their data is complete, the new mechanics work (burning, poison, freezing, Beastmaster pets),
	every class pair has an ultimate, and every path fights without errors.   require(...NewClassTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Classes = require(Shared.Config.Classes), Abilities = require(Shared.Config.Abilities), PassiveConfig = require(Shared.Config.Passives),
			SubclassConfig = require(Shared.Config.Subclasses), Subclasses = require(Shared.Subclasses), Ultimates = require(Shared.Ultimates),
			UltimateConfig = require(Shared.Config.Ultimates), Simulation = require(Shared.Combat.Simulation), StatCalc = require(Shared.Combat.StatCalc),
			StageRunner = require(Shared.StageRunner), ProfileTemplate = require(Shared.ProfileTemplate), Character = require(Shared.Character),
			PetConfig = require(Shared.Config.Pets), SeasonRewardsConfig = require(Shared.Config.SeasonRewards),
		}
	end
	local Classes, Abilities, PassiveConfig, SubclassConfig = m.Classes, m.Abilities, m.PassiveConfig, m.SubclassConfig
	local Ultimates, UltimateConfig, Simulation, StatCalc, StageRunner = m.Ultimates, m.UltimateConfig, m.Simulation, m.StatCalc, m.StageRunner
	local ProfileTemplate, Character, Subclasses = m.ProfileTemplate, m.Character, m.Subclasses
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

	local NEW = { "Mage", "Ranger", "Rogue", "Summoner" }
	local ALL = { "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }

	-- data is complete ---------------------------------------------------------------------------
	for _, classId in ipairs(NEW) do
		local def = Classes[classId]
		check(classId .. " is playable", def ~= nil and not def.Locked)
		local poolOk, loadoutOk = #def.AbilityPool == 8, #def.DefaultLoadout == 4
		for _, id in ipairs(def.AbilityPool) do
			poolOk = poolOk and Abilities[id] ~= nil and Abilities[id].Class == classId and Abilities[id].Subclass == nil
		end
		for _, id in ipairs(def.DefaultLoadout) do
			loadoutOk = loadoutOk and table.find(def.AbilityPool, id) ~= nil
		end
		check(classId .. " has 8 real skills and a loadout from them", poolOk and loadoutOk)
		local passiveOk = #def.PassivePool == 6
		for _, id in ipairs(def.PassivePool) do
			passiveOk = passiveOk and PassiveConfig.Defs[id] ~= nil and PassiveConfig.Defs[id].Class == classId
		end
		check(classId .. " has 6 passives", passiveOk)
		local paths = Subclasses.Choices(classId)
		local pathsOk = #paths == 2
		for _, path in ipairs(paths) do
			pathsOk = pathsOk and #path.Skills == 3
			for _, skillId in ipairs(path.Skills) do
				pathsOk = pathsOk and Abilities[skillId] ~= nil and Abilities[skillId].Subclass == path.Id and Abilities[skillId].Class == classId
			end
		end
		check(classId .. " has two paths of three skills each", pathsOk)
		check(classId .. " has a prize pet that is a season reward", m.PetConfig.Defs[m.SeasonRewardsConfig.ClassPets[classId] or ""] ~= nil)
	end

	-- every pair of different classes has an ultimate
	local pairsOk, missingPair = true, ""
	for i = 1, #ALL do
		for j = i + 1, #ALL do
			local list = Ultimates.ForPair(ALL[i], ALL[j])
			local ok = #list >= 1
			for _, id in ipairs(list) do
				ok = ok and UltimateConfig.Defs[id] ~= nil
			end
			if not ok then
				pairsOk = false
				missingPair ..= ALL[i] .. "+" .. ALL[j] .. " "
			end
		end
	end
	check("Every pair of different classes has an ultimate" .. (if pairsOk then "" else (": " .. missingPair)), pairsOk)

	-- burning -----------------------------------------------------------------------------------
	local function duel(classId, enemyId)
		local hero = StatCalc.NewPartyMember("h", "Hero", classId, 5, {})
		local foe = StatCalc.NewEnemy("e", enemyId or "Slime", 1)
		foe.Stats.MaxHealth = 100000
		foe.Health = 100000
		foe.Stats.Attack = 10
		hero.Abilities = {}
		local sim = Simulation.new({ Party = { hero }, Enemies = { foe }, Seed = 3, MaxSeconds = 60 })
		return sim, hero, foe
	end
	local sim, hero, foe = duel("Mage")
	hero.Stats.AttackSpeed = 0.0001
	sim:ApplyStatus(foe, "Burning", 5, hero)
	for _ = 1, 50 do
		sim:Step()
	end
	local burns = 0
	for _, e in ipairs(sim.Events) do
		if e.Type == "Damage" and e.Tag == "Burning" then
			burns += 1
		end
	end
	check("Burning hurts the enemy about once a second", burns >= 4 and burns <= 6 and foe.Health < 100000)
	check("Burning wears off", not sim:HasStatus(foe, "Burning"))

	-- poison uses the same system
	sim, hero, foe = duel("Rogue")
	hero.Stats.AttackSpeed = 0.0001
	sim:ApplyStatus(foe, "Poisoned", 3, hero)
	for _ = 1, 40 do
		sim:Step()
	end
	local poisons = 0
	for _, e in ipairs(sim.Events) do
		if e.Type == "Damage" and e.Tag == "Poisoned" then
			poisons += 1
		end
	end
	check("Poison ticks too", poisons >= 2 and poisons <= 4)

	-- freezing ------------------------------------------------------------------------------------
	sim, hero, foe = duel("Mage")
	hero.Stats.AttackSpeed = 0.0001
	foe.Stats.AttackSpeed = 5
	check("A normal enemy can be frozen", sim:ApplyStatus(foe, "Frozen", 3, hero) == true)
	for _ = 1, 25 do
		sim:Step()
	end
	local hitsWhileFrozen = 0
	for _, e in ipairs(sim.Events) do
		if e.Type == "Damage" and e.Source == "e" then
			hitsWhileFrozen += 1
		end
	end
	check("A frozen enemy does not attack", hitsWhileFrozen == 0)
	for _ = 1, 40 do
		sim:Step()
	end
	local hitsAfter = 0
	for _, e in ipairs(sim.Events) do
		if e.Type == "Damage" and e.Source == "e" then
			hitsAfter += 1
		end
	end
	check("It attacks again once the ice melts", hitsAfter > 0)
	local boss = StatCalc.NewEnemy("b", "SlimeKing", 1)
	sim, hero = duel("Mage")
	check("Bosses cannot be frozen", sim:ApplyStatus(boss, "Frozen", 3, hero) == false and not sim:HasStatus(boss, "Frozen"))

	-- Beastmaster ---------------------------------------------------------------------------------
	check("Beastmaster boosts pets and Sharpshooter does not", Subclasses.PetBoost("Beastmaster").Stats > 0 and Subclasses.PetBoost("Beastmaster").SkillLevels > 0 and Subclasses.PetBoost("Sharpshooter").Stats == 0)
	local plain = StatCalc.NewPartyMember("p", "P", "Ranger", 20, { PetId = "Arcanix", PetLevel = 5, PetRank = 1 })
	local beast = StatCalc.NewPartyMember("b", "B", "Ranger", 20, { PetId = "Arcanix", PetLevel = 5, PetRank = 1, SubclassId = "Beastmaster" })
	local petless = StatCalc.NewPartyMember("n", "N", "Ranger", 20, { SubclassId = "Beastmaster" })
	local beastPetless = StatCalc.NewPartyMember("n2", "N2", "Ranger", 20, {})
	local plainSub = StatCalc.NewPartyMember("s", "S", "Ranger", 20, { SubclassId = "Beastmaster", PetId = "Arcanix", PetLevel = 5, PetRank = 1 })
	local function slotOf(entity, id)
		for _, slot in ipairs(entity.Abilities) do
			if slot.Id == id then
				return slot
			end
		end
		return nil
	end
	local petSlot = slotOf(beast, "Pet_Arcanix")
	check("A Beastmaster's pet skill is stronger (more levels)", petSlot ~= nil and slotOf(plain, "Pet_Arcanix") ~= nil and petSlot.Level > slotOf(plain, "Pet_Arcanix").Level)
	check("A Beastmaster with no pet just gets its own bonuses", petless.Stats.Attack > beastPetless.Stats.Attack)
	check("The pet bonus on top of the path is larger than the path alone", plainSub.Stats.Attack > petless.Stats.Attack)

	-- picking a class at creation unlocks it ---------------------------------------------------------
	for _, classId in ipairs(NEW) do
		local p = ProfileTemplate.New()
		local ok = Character.Create(p, "Hero One", classId, {}, false)
		local starters = Classes[classId].DefaultLoadout
		local ownsStarters = true
		for _, id in ipairs(starters) do
			ownsStarters = ownsStarters and p.Season.OwnedAbilities[id] == true
		end
		check(classId .. " can be picked at creation and comes with its starter skills", ok == true and p.Season.ClassId == classId and p.Permanent.UnlockedClasses[classId] == true and ownsStarters and p.Season.Loadouts[classId] ~= nil)
	end

	-- every class pair fights with its ultimate, every path fights, nothing errors ----------------------
	local function member(classId, id)
		local profile = ProfileTemplate.New()
		profile.Permanent.UnlockedClasses[classId] = true
		ProfileTemplate.GrantClassStarters(profile.Season, classId)
		profile.Season.ClassId = classId
		return { Id = id, Name = id, Profile = profile }
	end
	local pairRuns, pairErrors = 0, {}
	for i = 1, #ALL do
		for j = i + 1, #ALL do
			local members = { member(ALL[i], "a"), member(ALL[j], "b") }
			local ult = StageRunner.UltimateFor(members, 100)
			local ok, err = pcall(StageRunner.Run, members, 25, 7, ult, true)
			pairRuns += 1
			if not ok then
				table.insert(pairErrors, ALL[i] .. "+" .. ALL[j] .. ": " .. tostring(err))
			end
		end
	end
	check("All " .. pairRuns .. " class pairs fight with their ultimate" .. (if #pairErrors > 0 then (": " .. table.concat(pairErrors, "; ")) else ""), #pairErrors == 0 and pairRuns == 15)

	local pathErrors = {}
	for _, pathId in ipairs(SubclassConfig.Order) do
		local def = SubclassConfig.Defs[pathId]
		if def.UnlockLevel > 30 then
			continue -- the level-90 forms are tested below
		end
		local mine = member(def.Class, "m")
		mine.Profile.Season.Level = 30
		Subclasses.Choose(mine.Profile, def.Class, pathId)
		for _, skillId in ipairs(def.Skills) do
			mine.Profile.Season.OwnedAbilities[skillId] = true
		end
		mine.Profile.Season.Loadouts[def.Class] = { def.Skills[1], def.Skills[2], def.Skills[3], Classes[def.Class].DefaultLoadout[1] }
		local other = member(def.Class == "Cleric" and "Warrior" or "Cleric", "o")
		local ok, outcome = pcall(StageRunner.Run, { mine, other }, 12, 5, nil, true)
		local casts = {}
		if ok then
			for _, e in ipairs(outcome.Events) do
				if e.Type == "Cast" then
					casts[e.Ability or "?"] = true
				end
			end
		end
		local used = 0
		for _, skillId in ipairs(def.Skills) do
			if casts[skillId] then
				used += 1
			end
		end
		if not ok or used < 2 then
			table.insert(pathErrors, pathId .. (if ok then (" only cast " .. used) else (" errored: " .. tostring(outcome))))
		end
	end
	check("Every new path's skills run and cast in a fight" .. (if #pathErrors > 0 then (": " .. table.concat(pathErrors, "; ")) else ""), #pathErrors == 0)

	-- level 90: the final form of every path stacks on the first and its skill fights
	local tier2Errors = {}
	for _, pathId in ipairs(SubclassConfig.Order) do
		local def = SubclassConfig.Defs[pathId]
		if def.UnlockLevel == 90 then
			local mine = member(def.Class, "m")
			mine.Profile.Season.Level = 30
			Subclasses.Choose(mine.Profile, def.Class, def.Parent)
			if Subclasses.Choose(mine.Profile, def.Class, pathId) ~= false then
				table.insert(tier2Errors, pathId .. " chosen below level 90")
			end
			mine.Profile.Season.Level = 90
			if not Subclasses.Choose(mine.Profile, def.Class, pathId) then
				table.insert(tier2Errors, pathId .. " cannot be chosen at 90")
			end
			local skillId = def.Skills[1]
			mine.Profile.Season.Loadouts[def.Class] = { skillId, Classes[def.Class].DefaultLoadout[1], Classes[def.Class].DefaultLoadout[2], Classes[def.Class].DefaultLoadout[3] }
			local ok, outcome = pcall(StageRunner.Run, { mine, member(def.Class == "Cleric" and "Warrior" or "Cleric", "o") }, 60, 5, nil, true)
			local cast = false
			if ok then
				for _, e in ipairs(outcome.Events) do
					if e.Type == "Cast" and e.Ability == skillId then
						cast = true
					end
				end
			end
			if not (ok and cast) then
				table.insert(tier2Errors, pathId .. " skill did not cast")
			end
			local chain = Subclasses.Chain(pathId)
			if #chain ~= 2 or chain[1].Id ~= def.Parent then
				table.insert(tier2Errors, pathId .. " chain")
			end
		end
	end
	check("All 12 level-90 forms: locked below 90, chosen at 90, stack on their path and cast" .. (if #tier2Errors > 0 then (": " .. table.concat(tier2Errors, "; ")) else ""), #tier2Errors == 0)

	-- early game is winnable with each new class beside a Cleric -----------------------------------------
	local early = true
	for _, classId in ipairs(NEW) do
		local members = { member(classId, "a"), member("Cleric", "b") }
		local out = StageRunner.Run(members, 1, 1)
		early = early and out.Won == true
	end
	check("Each new class clears stage 1 with a Cleric", early)

	print(("NewClassTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
