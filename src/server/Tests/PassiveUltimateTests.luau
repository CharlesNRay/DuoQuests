--[[
	PassiveUltimateTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PassiveUltimateTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PassiveUltimateTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Combat = Shared:WaitForChild("Combat")
	return {
		Entity = require(Combat.Entity),
		Simulation = require(Combat.Simulation),
		StatCalc = require(Combat.StatCalc),
		Passives = require(Shared.Passives),
		Ultimates = require(Shared.Ultimates),
		ProfileTemplate = require(Shared.ProfileTemplate),
		Progression = require(Shared.Progression),
		Economy = require(Shared.Economy),
		StageRunner = require(Shared.StageRunner),
		Party = require(Shared.Party),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Entity, Simulation, StatCalc, Passives, Ultimates = m.Entity, m.Simulation, m.StatCalc, m.Passives, m.Ultimates
	local ProfileTemplate, Progression, Economy, StageRunner, Party = m.ProfileTemplate, m.Progression, m.Economy, m.StageRunner, m.Party
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

	print("Running PassiveUltimateTests...")

	local function near(a, b)
		return math.abs(a - b) < 1e-6
	end

	-- Passive slots and unlocks ----------------------------------------------------
	check("Slots unlock with the frontier (1, 2, 3)", Passives.SlotsAt(1) == 1 and Passives.SlotsAt(20) == 2 and Passives.SlotsAt(50) == 3 and Passives.SlotsAt(500) == 3)
	check("A starter passive is valid at stage 1", Passives.ValidateLoadout("Warrior", { "IronHide" }, 1))
	local ok, reason = Passives.ValidateLoadout("Warrior", { "BruteForce" }, 1)
	check("A passive above the frontier is locked", ok == false and reason == "Locked")
	ok, reason = Passives.ValidateLoadout("Warrior", { "IronHide", "TreasureSense" }, 1)
	check("Too many for the unlocked slots is refused", ok == false and reason == "TooMany")
	ok, reason = Passives.ValidateLoadout("Warrior", { "HolyLight" }, 60)
	check("Passives are class specific", ok == false and reason == "WrongClass")
	ok, reason = Passives.ValidateLoadout("Warrior", { "IronHide", "IronHide" }, 60)
	check("Duplicates are refused", ok == false and reason == "Duplicate")
	ok, reason = Passives.ValidateLoadout("Warrior", { "Nope" }, 60)
	check("Unknown passives are refused", ok == false and reason == "UnknownPassive")
	check("An empty loadout is allowed", Passives.ValidateLoadout("Warrior", {}, 1))

	-- Levels and effects --------------------------------------------------------------
	local rows1, rows11 = Passives.Rows("IronHide", 1), Passives.Rows("IronHide", 11)
	check("Passive rows describe the stat", rows1[1].Label == "Defense" and rows1[1].Value == "+3.0%" and rows11[1].Value == "+6.0%")
	local resolved = Passives.Resolve("Warrior", { "IronHide", "TreasureSense" }, { 1, 11 })
	check("Resolve splits combat mods from reward totals", #resolved.Combat == 1 and near(resolved.Rewards.GoldGain, 0.18))

	local plain = StatCalc.NewPartyMember("a", "A", "Warrior", 1)
	local buffed = StatCalc.NewPartyMember("b", "B", "Warrior", 1, { PassiveIds = { "IronHide" }, PassiveLevels = { 1 } })
	check("A defense passive raises the combatant's defense", near(buffed.Stats.Defense, plain.Stats.Defense * 1.03))
	local warded = StatCalc.NewPartyMember("c", "C", "Cleric", 1, { PassiveIds = { "HolyLight", "Warding" }, PassiveLevels = { 1, 1 } })
	check("Multiplier stats start from 1 (healing +3%, damage taken -2%)", near(warded.Stats.HealingDealt, 1.03) and near(warded.Stats.DamageTaken, 0.98))
	local vital = StatCalc.NewPartyMember("d", "D", "Warrior", 1, { PassiveIds = { "Vitality" }, PassiveLevels = { 1 } })
	check("A health passive also raises starting health", vital.Health == vital.Stats.MaxHealth and vital.Stats.MaxHealth > plain.Stats.MaxHealth)

	-- Profiles and rewards -----------------------------------------------------------------
	local fresh = ProfileTemplate.New()
	check("New players start with their class's first passive equipped", fresh.Season.PassiveLoadouts.Warrior[1] == "IronHide" and fresh.Season.PassiveLoadouts.Cleric[1] == "HolyLight")
	check("...in level 1 passive slots", #fresh.Season.PassiveSlotLevels.Warrior == Passives.SLOTS and fresh.Season.PassiveSlotLevels.Warrior[1] == 1)

	local boosted = Progression.ClearRewards(5, true, { GoldGain = 0.5, XPGain = 0 })
	local base = Progression.ClearRewards(5, true)
	check("Gold gain raises gold only", boosted.Gold >= base.Gold and boosted.XP == base.XP and boosted.Shards == base.Shards)

	local a, b = ProfileTemplate.New(), ProfileTemplate.New()
	b.Season.PassiveLoadouts.Warrior = { "TreasureSense" }
	a.Season.PassiveLoadouts.Warrior = {}
	local goldA, goldB = 0, 0
	for stage = 1, 30 do
		goldA += Progression.ApplyClear(a, stage).Gold
		goldB += Progression.ApplyClear(b, stage).Gold
	end
	check("An equipped gold passive increases clear rewards", goldB > goldA)

	-- Economy ---------------------------------------------------------------------------------
	local p = ProfileTemplate.New()
	ok, reason = Economy.EquipPassives(p, "Warrior", { "BruteForce" })
	check("Equipping a locked passive fails and changes nothing", ok == false and reason == "Locked" and p.Season.PassiveLoadouts.Warrior[1] == "IronHide")
	p.Season.HighestStage = 30
	ok = Economy.EquipPassives(p, "Warrior", { "BruteForce", "TreasureSense" })
	check("Equipping unlocked passives within the slots works", ok == true and p.Season.PassiveLoadouts.Warrior[2] == "TreasureSense")
	ok, reason = Economy.LevelPassiveSlot(p, "Warrior", 1)
	check("Levelling needs gold", ok == false and reason == "NotEnough")
	p.Season.Currencies.Gold = 1000000
	ok = Economy.LevelPassiveSlot(p, "Warrior", 1)
	check("Levelling a passive slot costs gold and raises the level", ok == true and p.Season.PassiveSlotLevels.Warrior[1] == 2 and p.Season.Currencies.Gold == 1000000 - Economy.PassiveSlotLevelCost(1))
	ok, reason = Economy.LevelPassiveSlot(p, "Warrior", 3)
	check("A slot that is not unlocked yet cannot be levelled", ok == false and reason == "BadSlot")

	-- Ultimates -------------------------------------------------------------------------------------
	check("The pair key ignores class order", Ultimates.PairKey("Warrior", "Cleric") == "Cleric+Warrior" and Ultimates.PairKey("Cleric", "Warrior") == "Cleric+Warrior")
	check("Warrior and Cleric have three ultimates", #Ultimates.ForPair("Warrior", "Cleric") == 3)
	check("Unlocks follow the party frontier", Ultimates.IsUnlocked("SanctifiedCharge", 1) and not Ultimates.IsUnlocked("BulwarkOfDawn", 39) and Ultimates.IsUnlocked("BulwarkOfDawn", 40))
	check("An invalid or locked pick falls back to the first available", Ultimates.Resolve("Warrior", "Cleric", 1, "RadiantJudgment") == "SanctifiedCharge" and Ultimates.Resolve("Warrior", "Cleric", 40, "BulwarkOfDawn") == "BulwarkOfDawn")
	check("Two Warriors have no ultimate yet", Ultimates.Resolve("Warrior", "Warrior", 100, nil) == nil)
	check("Party level is the average slot level", Ultimates.PartyLevel({ { 2, 2, 2, 2 }, { 4, 4, 4, 4 } }) == 3)

	local function party(frontier)
		local warrior, cleric = ProfileTemplate.New(), ProfileTemplate.New()
		cleric.Season.ClassId = "Cleric"
		local record = Party.New("p1", 1, 1, 2, 0, 1, 1)
		Party.RefreshSnapshot(record, 1, "Warrior", warrior, 0)
		Party.RefreshSnapshot(record, 2, "Cleric", cleric, 0)
		record.Frontier = frontier
		return record, warrior, cleric
	end
	local record, warrior, cleric = party(1)
	ok, reason = Party.SetUltimate(record, 1, "BulwarkOfDawn")
	check("A locked ultimate cannot be equipped", ok == false and reason == "Locked")
	record.Frontier = 40
	ok = Party.SetUltimate(record, 2, "BulwarkOfDawn")
	check("Either member can equip an unlocked ultimate", ok == true and record.UltimateId == "BulwarkOfDawn")
	ok, reason = Party.SetUltimate(record, 99, "SanctifiedCharge")
	check("Only members can change it", ok == false and reason == "NotMember")
	ok, reason = Party.SetUltimate(record, 1, "Nonsense")
	check("An ultimate not for this pair is refused", ok == false and reason == "NotForPair")

	local members = { { Id = "1", Name = "W", Profile = warrior }, { Id = "2", Name = "C", Profile = cleric } }
	local ult = StageRunner.UltimateFor(members, 1, nil)
	check("A full pair gets an ultimate for its classes", ult ~= nil and ult.Id == "SanctifiedCharge" and ult.Level == 1)
	check("A lone member has no ultimate", StageRunner.UltimateFor({ members[1] }, 1, nil) == nil)

	-- The gauge in combat ---------------------------------------------------------------------------------
	local function entity(id, team, stats, abilities)
		return Entity.new({ Id = id, Team = team, Stats = stats, Abilities = abilities })
	end
	local function fightWith(abilities, seconds, ultimate)
		local hero = entity("h", "Party", { MaxHealth = 1000, Attack = 10, Defense = 0, AttackSpeed = 0.05 }, abilities)
		local friend = entity("f", "Party", { MaxHealth = 1000, Attack = 10, Defense = 0, AttackSpeed = 0.05 })
		local dummy = entity("d", "Enemy", { MaxHealth = 1000000, Attack = 0, Defense = 0, AttackSpeed = 0.05 })
		local fight = Simulation.new({ Party = { hero, friend }, Enemies = { dummy }, Seed = 1, MaxSeconds = seconds, Ultimate = ultimate })
		fight:Run()
		return fight
	end
	local function firstTime(fight, kind)
		for _, e in ipairs(fight.Events) do
			if e.Type == kind then
				return e.T
			end
		end
		return nil
	end
	local idle = fightWith(nil, 80, { Id = "SanctifiedCharge", Level = 1 })
	local firedAt = firstTime(idle, "Ultimate")
	check("The gauge fills with time and fires the ultimate by itself (about 67s)", firedAt ~= nil and firedAt > 65 and firedAt < 69)
	local damaged = false
	for _, e in ipairs(idle.Events) do
		if e.Type == "Damage" and e.Tag == "SanctifiedCharge" then
			damaged = true
		end
	end
	check("The ultimate's effects run (it damages enemies)", damaged)
	local casting = fightWith({ { Id = "Smite", Level = 1 } }, 80, { Id = "SanctifiedCharge", Level = 1 })
	check("Casting skills charges it faster", firstTime(casting, "Ultimate") ~= nil and firstTime(casting, "Ultimate") < firedAt - 10)
	local none = fightWith(nil, 80, nil)
	check("No ultimate configured means none fires", firstTime(none, "Ultimate") == nil)

	local record2 = party(1)
	local live = {
		{ UserId = 1, Name = "W", Profile = warrior },
		{ UserId = 2, Name = "C", Profile = cleric },
	}
	local outcome = Party.OnlineTick(record2, live, 5, 100)
	check("The party tick runs with an ultimate and passives in play", outcome ~= nil and outcome.Stage == 1)

	print(("PassiveUltimateTests done: %d passed, %d failed"):format(passed, failed))
end
