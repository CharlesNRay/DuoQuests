--[[
	StageTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > StageTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.StageTests)()

	Checks stages, rewards and spending, then prints a simulated idle playthrough
	so you can see how the placeholder pacing feels.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		ProfileTemplate = require(Shared.ProfileTemplate),
		Stages = require(Shared.Stages),
		Progression = require(Shared.Progression),
		Economy = require(Shared.Economy),
		StageRunner = require(Shared.StageRunner),
		EconomyConfig = require(Shared.Config.Economy),
		StagesConfig = require(Shared.Config.Stages),
		Skills = require(Shared.Skills),
		Classes = require(Shared.Config.Classes),
		TableUtil = require(Shared.Util.TableUtil),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local ProfileTemplate, Stages, Progression, Economy = m.ProfileTemplate, m.Stages, m.Progression, m.Economy
	local StageRunner, EconomyConfig, Skills, Classes, TableUtil = m.StageRunner, m.EconomyConfig, m.Skills, m.Classes, m.TableUtil
	local StagesConfig = m.StagesConfig
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

	print("Running StageTests...")

	-- Stages -----------------------------------------------------------------
	check("Stage 1 has one regular enemy", #Stages.Build(1).Enemies == 1 and not Stages.Build(1).IsBoss)
	check("Every 10th stage is a lone boss", Stages.Build(10).IsBoss and #Stages.Build(10).Enemies == 1 and Stages.Build(20).IsBoss)
	check("Stage 9 is not a boss", not Stages.IsBoss(9))
	check("Later regular stages have up to 3 enemies", #Stages.Build(7).Enemies == 3 and #Stages.Build(29).Enemies == 3)
	check("Enemies get stronger every stage (stage 1 at most scale 1; the early ease softens it)", Stages.Scale(5) > Stages.Scale(4) and Stages.Scale(12) > Stages.Scale(11) and Stages.Scale(41) > Stages.Scale(40) and Stages.Scale(1) > 0 and Stages.Scale(1) <= (StagesConfig.PartyScale or 1))
	check("Stages are deterministic", #Stages.Build(13).Enemies == #Stages.Build(13).Enemies and Stages.Build(13).Enemies[2].EnemyId == Stages.Build(13).Enemies[2].EnemyId)
	check("Bad stage numbers are rejected", not pcall(Stages.Build, 0) and not pcall(Stages.Build, 1.5))

	-- XP and levels ------------------------------------------------------------
	local p = ProfileTemplate.New()
	check("New player has 0 shards, gold and picks", p.Season.Currencies.Gold == 0 and p.Season.Currencies.Shards == 0 and p.Season.Currencies.SkillPicks == 0)
	local gained = Progression.AddXP(p.Season, Progression.XPToNext(1) + 5)
	check("Enough XP levels you up and keeps the remainder", gained == 1 and p.Season.Level == 2 and p.Season.XP == 5)
	local many = ProfileTemplate.New()
	Progression.AddXP(many.Season, 100000000000)
	check("XP stops at the max level", many.Season.Level == EconomyConfig.MaxLevel and many.Season.XP == 0)

	-- Clear rewards ------------------------------------------------------------
	local q = ProfileTemplate.New()
	local first = Progression.ApplyClear(q, 1)
	check("Clearing the frontier pays full rewards and advances it", first.FrontierClear and q.Season.HighestStage == 2 and q.Season.Currencies.Gold == first.Gold and first.Gold > 0 and first.Shards >= 1)
	local goldAfterFirst = q.Season.Currencies.Gold
	local replay = Progression.ApplyClear(q, 1)
	check("Replaying an old stage does not move the frontier", not replay.FrontierClear and q.Season.HighestStage == 2 and q.Season.Currencies.Gold == goldAfterFirst + replay.Gold)
	check("Replaying an old stage pays less than the frontier", Progression.ClearRewards(30, false).Gold < Progression.ClearRewards(30, true).Gold and Progression.ClearRewards(30, false).XP < Progression.ClearRewards(30, true).XP and Progression.ClearRewards(30, false).Shards < Progression.ClearRewards(30, true).Shards)
	check("Frontier rewards grow with the stage", Progression.ClearRewards(30, true).Gold > Progression.ClearRewards(5, true).Gold)
	check("The frontier beats replaying an older stage", Progression.ClearRewards(20, true).Gold > Progression.ClearRewards(19, false).Gold)
	check("Boss stages pay extra shards", Progression.ClearRewards(10, true).Shards > Progression.ClearRewards(9, true).Shards)
	check("Rewards always pay at least 1", Progression.ClearRewards(1, false).Gold >= 1 and Progression.ClearRewards(1, false).Shards >= 1)

	local boss = ProfileTemplate.New()
	boss.Season.HighestStage = 10
	local bossClear = Progression.ApplyClear(boss, 10)
	check("First boss clear grants a free skill pick", bossClear.SkillPicks == 1 and boss.Season.Currencies.SkillPicks == 1 and boss.Season.StageRewardsClaimed[10] == true)
	Progression.ApplyClear(boss, 10)
	check("Repeating a boss never pays the pick again", boss.Season.Currencies.SkillPicks == 1)
	local nonBoss = ProfileTemplate.New()
	nonBoss.Season.HighestStage = 9
	Progression.ApplyClear(nonBoss, 9)
	check("Regular stages grant no pick", nonBoss.Season.Currencies.SkillPicks == 0)

	-- Spending -----------------------------------------------------------------
	local s = ProfileTemplate.New()
	check("Cannot unlock without shards", select(2, Economy.UnlockAbility(s, "Warrior", "ShieldWall")) == "NotEnough" and not s.Season.OwnedAbilities.ShieldWall)
	s.Season.Currencies.Shards = 1500
	local ok = Economy.UnlockAbility(s, "Warrior", "ShieldWall")
	check("Unlock spends the rarity's shard cost", ok and s.Season.OwnedAbilities.ShieldWall == true and s.Season.Currencies.Shards == 1500 - EconomyConfig.UnlockCost.Rare)
	check("Cannot unlock twice", select(2, Economy.UnlockAbility(s, "Warrior", "ShieldWall")) == "AlreadyOwned" and s.Season.Currencies.Shards == 1500 - EconomyConfig.UnlockCost.Rare)
	check("Class-locked: a Warrior cannot unlock Cleric skills", select(2, Economy.UnlockAbility(s, "Warrior", "Judgment")) == "NotInPool")
	check("Unknown class and skill are rejected", select(2, Economy.UnlockAbility(s, "Nope", "Heal")) == "UnknownClass" and select(2, Economy.UnlockAbility(s, "Warrior", 5)) == "NotInPool")
	check("Epic costs 3-4x Common", EconomyConfig.UnlockCost.Epic >= 3 * EconomyConfig.UnlockCost.Common and EconomyConfig.UnlockCost.Epic <= 4 * EconomyConfig.UnlockCost.Common)

	local picks = ProfileTemplate.New()
	check("Cannot use a pick without one", select(2, Economy.UnlockAbilityWithPick(picks, "Cleric", "Judgment")) == "NotEnough")
	picks.Season.Currencies.SkillPicks = 1
	check("A pick unlocks any skill of the class, whatever its rarity", Economy.UnlockAbilityWithPick(picks, "Cleric", "Judgment") and picks.Season.OwnedAbilities.Judgment == true and picks.Season.Currencies.SkillPicks == 0)

	local lv = ProfileTemplate.New()
	check("Cannot level a slot without gold", select(2, Economy.LevelSlot(lv, "Warrior", 1)) == "NotEnough" and lv.Season.SlotLevels.Warrior[1] == 1)
	lv.Season.Currencies.Gold = 1000000
	check("Levelling a slot spends gold and raises only that slot", Economy.LevelSlot(lv, "Warrior", 2) and lv.Season.SlotLevels.Warrior[2] == 2 and lv.Season.SlotLevels.Warrior[1] == 1 and lv.Season.Currencies.Gold == 1000000 - Economy.SlotLevelCost(1))
	check("Bad slot numbers are rejected", select(2, Economy.LevelSlot(lv, "Warrior", 0)) == "BadSlot" and select(2, Economy.LevelSlot(lv, "Warrior", 5)) == "BadSlot" and select(2, Economy.LevelSlot(lv, "Warrior", 1.5)) == "BadSlot")
	lv.Season.Currencies.Gold = 1e9
	lv.Season.SlotLevels.Warrior[3] = Skills.MAX_SLOT_LEVEL
	check("Slots stop at the max level", select(2, Economy.LevelSlot(lv, "Warrior", 3)) == "MaxLevel" and lv.Season.SlotLevels.Warrior[3] == Skills.MAX_SLOT_LEVEL)

	local eq = ProfileTemplate.New()
	eq.Season.OwnedAbilities.ShieldWall = true
	local newLoadout = { "ShieldWall", "Taunt", "IronSkin", "ShieldBash" }
	eq.Season.SlotLevels.Warrior[1] = 6
	check("Equip sets the loadout and the slot keeps its level", Economy.Equip(eq, "Warrior", newLoadout) and eq.Season.Loadouts.Warrior[1] == "ShieldWall" and eq.Season.SlotLevels.Warrior[1] == 6)
	check("Equip rejects unowned skills", select(2, Economy.Equip(eq, "Warrior", { "LastStand", "Taunt", "IronSkin", "ShieldBash" })) == "NotOwned")
	check("Equip rejects duplicates and other classes' skills", select(2, Economy.Equip(eq, "Warrior", { "Taunt", "Taunt", "IronSkin", "ShieldBash" })) == "Duplicate" and select(2, Economy.Equip(eq, "Warrior", { "Heal", "Taunt", "IronSkin", "ShieldBash" })) == "WrongClass")
	check("Equip needs at least one skill", select(2, Economy.Equip(eq, "Warrior", {})) == "NeedOneSkill")
	check("A failed equip changes nothing", eq.Season.Loadouts.Warrior[1] == "ShieldWall")
	check("Skills can be unequipped down to one", Economy.Equip(eq, "Warrior", { "Taunt", "IronSkin" }) == true and #eq.Season.Loadouts.Warrior == 2)
	local locked = ProfileTemplate.New()
	locked.Permanent.UnlockedClasses.Cleric = nil
	check("Locked classes cannot be changed", select(2, Economy.Equip(locked, "Cleric", Classes.Cleric.DefaultLoadout)) == "ClassLocked" and select(2, Economy.LevelSlot(locked, "Cleric", 1)) == "ClassLocked")

	-- Stage runner -------------------------------------------------------------
	local function members(warriorProfile, clericProfile)
		clericProfile.Season.ClassId = "Cleric"
		return { { Id = "p1", Name = "Warrior", Profile = warriorProfile }, { Id = "p2", Name = "Cleric", Profile = clericProfile } }
	end
	local w, c = ProfileTemplate.New(), ProfileTemplate.New()
	local ms = members(w, c)
	local outcome = StageRunner.Run(ms, 1, 11)
	check("A fresh party wins stage 1", outcome.Won and outcome.NextStage == 2)
	check("Every member is rewarded once", outcome.Rewards.p1 ~= nil and outcome.Rewards.p2 ~= nil and w.Season.Currencies.Gold == outcome.Rewards.p1.Gold and c.Season.Currencies.Gold == outcome.Rewards.p2.Gold)
	local again = StageRunner.Run(members(ProfileTemplate.New(), ProfileTemplate.New()), 1, 11)
	check("The same stage and seed give the same fight", again.Duration == outcome.Duration)

	local weakW, weakC = ProfileTemplate.New(), ProfileTemplate.New()
	local lost = StageRunner.Run(members(weakW, weakC), 80, 3)
	check("A losing fight steps back one stage and pays nothing", not lost.Won and lost.NextStage == 79 and next(lost.Rewards) == nil and weakW.Season.Currencies.Gold == 0)
	check("Losing stage 1 stays on stage 1", StageRunner.Run(members(ProfileTemplate.New(), ProfileTemplate.New()), 1, 1).NextStage >= 1)

	local bad = ProfileTemplate.New()
	bad.Season.Loadouts.Warrior = nil
	check("Missing loadouts fall back to the class default", pcall(StageRunner.NewParty, { { Id = "x", Name = "x", Profile = bad } }))

	-- Stage timer ---------------------------------------------------------------
	check("Boss stages get a longer timer than regular stages", Stages.TimeLimit(10) > Stages.TimeLimit(9) and Stages.TimeLimit(9) > 0)
	local stallW, stallC = ProfileTemplate.New(), ProfileTemplate.New()
	local savedLimit = StagesConfig.TimeLimit
	StagesConfig.TimeLimit = 0.5 -- far too short to win stage 1
	local stalled = StageRunner.Run(members(stallW, stallC), 1, 5)
	StagesConfig.TimeLimit = savedLimit
	check("Running out of time is a loss", not stalled.Won and stalled.TimedOut and math.abs(stalled.Duration - 0.5) < 0.11)
	check("A timed-out fight pays nothing and steps back", next(stalled.Rewards) == nil and stallW.Season.Currencies.Gold == 0 and stalled.NextStage == 1)
	check("Winning inside the timer is not a timeout", not StageRunner.Run(members(ProfileTemplate.New(), ProfileTemplate.New()), 1, 5).TimedOut)

	-- Idle playthrough (information only) -----------------------------------------
	-- A simple auto-player: fight the frontier; after each win spend everything
	-- (unlock cheapest skill with shards, then level the lowest slot with gold).
	print("Idle playthrough (placeholder balance, not assertions):")
	local function autoSpend(profile, classId)
		local progressed = true
		while progressed do
			progressed = false
			for _, abilityId in ipairs(Skills.Pool(classId)) do
				if not profile.Season.OwnedAbilities[abilityId] and Economy.UnlockAbility(profile, classId, abilityId) then
					progressed = true
					break
				end
			end
			local lowest, lowestLevel = 1, math.huge
			for index, level in ipairs(profile.Season.SlotLevels[classId]) do
				if level < lowestLevel then
					lowest, lowestLevel = index, level
				end
			end
			if Economy.LevelSlot(profile, classId, lowest) then
				progressed = true
			end
		end
	end
	local function equipBest(profile, classId)
		local owned = {}
		for _, abilityId in ipairs(Skills.Pool(classId)) do
			if profile.Season.OwnedAbilities[abilityId] then
				table.insert(owned, abilityId)
			end
		end
		local best = {}
		for i = #owned, math.max(1, #owned - Skills.SLOTS + 1), -1 do
			table.insert(best, owned[i])
		end
		Economy.Equip(profile, classId, best)
	end
	local pw, pc = ProfileTemplate.New(), ProfileTemplate.New()
	local team = members(pw, pc)
	local stage, fights, seed = 1, 0, 100
	for _, checkpoint in ipairs({ 10, 25, 50, 75, 100 }) do
		while pw.Season.HighestStage < checkpoint and fights < 6000 do
			fights += 1
			seed += 1
			local r = StageRunner.Run(team, stage, seed)
			stage = r.NextStage
			autoSpend(pw, "Warrior")
			autoSpend(pc, "Cleric")
			equipBest(pw, "Warrior")
			equipBest(pc, "Cleric")
		end
		print(("  frontier %3d after %4d fights | player level %2d | warrior slots %s | owns %d skills"):format(pw.Season.HighestStage, fights, pw.Season.Level, table.concat(pw.Season.SlotLevels.Warrior, "/"), (function()
			local n = 0
			for _ in pairs(pw.Season.OwnedAbilities) do
				n += 1
			end
			return n
		end)()))
	end

	print(("StageTests done: %d passed, %d failed"):format(passed, failed))
end
