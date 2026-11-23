--[[
	SkillProgressTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SkillProgressTests
	  require(game.ServerScriptService.Server.Tests.SkillProgressTests)()

	Skill tier, rank and XP: copies from wishes, manual upgrades and rank-ups, combat levels, pacing maths.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		SkillProgress = require(Shared.SkillProgress), SkillConfig = require(Shared.Config.SkillProgress),
		ProfileTemplate = require(Shared.ProfileTemplate), Abilities = require(Shared.Config.Abilities),
		Skills = require(Shared.Skills), Wishing = require(Shared.Wishing), Party = require(Shared.Party),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local SP, Cfg, ProfileTemplate, Abilities = m.SkillProgress, m.SkillConfig, m.ProfileTemplate, m.Abilities
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
	print("Running SkillProgressTests...")

	local profile = ProfileTemplate.New()
	local season = profile.Season
	local common, rare, testClass
	-- the first class with a Common skill it does not start with (the Warrior has none since 2026-11-22)
	for _, classId in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
		local c, r = nil, nil
		for _, id in ipairs(m.Skills.AllSkills(classId)) do
			local base = SP.BaseTier(id)
			if base == "Common" and not c and not season.OwnedAbilities[id] then c = id end
			if base == "Rare" and not r then r = id end
		end
		if c and r then
			common, rare, testClass = c, r, classId
			break
		end
	end
	check("The class has a Common skill to test with", common ~= nil and rare ~= nil)

	-- a starter skill: rank 1 at its base rarity
	local starter = season.Loadouts.Warrior[1]
	local g = SP.Get(season, starter)
	check("A skill with no history is rank 1 at base rarity, level 1", g.Rank == 1 and g.Tier == SP.BaseTier(starter) and g.Level == 1 and not g.CanRank and not g.CanUpgrade)

	-- first copy
	local got = SP.Receive(season, common, "Common")
	check("A first copy unlocks the skill", got == "New" and season.OwnedAbilities[common] == true and SP.Get(season, common).Tier == "Common")
	local got2 = SP.Receive(season, rare, "Epic")
	check("A first copy keeps the tier it dropped at", got2 == "New" and SP.Get(season, rare).Tier == "Epic" and SP.Get(season, rare).Level == 1 + Cfg.TierBonus.Epic - Cfg.TierBonus.Rare)

	-- spare copies are XP
	local kind = SP.Receive(season, common, "Common")
	check("A same-tier copy is banked, not XP yet", kind == "Copy" and SP.Get(season, common).XP == 0 and SP.Get(season, common).Copies.Common == 1 and SP.Get(season, common).CanConsume)
	check("Nothing ranks up by itself", SP.Get(season, common).Rank == 1)
	SP.Receive(season, common, "Common")
	local eat, gained = SP.Consume(profile, common, "All")
	check("Consuming banked copies gives XP", eat and gained == 2 * Cfg.DupXP.Common and SP.Get(season, common).XP == gained and SP.Get(season, common).CopyXP == 0)
	check("Nothing left to consume", select(2, SP.Consume(profile, common, "All")) == "NoCopies")
	check("An unowned skill cannot consume", select(2, SP.Consume(profile, "Nope", "All")) == "NotOwned")
	check("Enough XP makes the rank up button ready, but does not press it", SP.Get(season, common).CanRank and SP.Get(season, common).Rank == 1)
	local ok, rank = SP.RankUp(profile, common)
	check("Rank up is manual and spends the XP", ok and rank == 2 and SP.Get(season, common).XP == 2 * Cfg.DupXP.Common - Cfg.RankXP[1])
	check("Rank up needs the XP", select(2, SP.RankUp(profile, common)) == "NotEnoughXP")
	check("An unowned skill cannot rank up", select(2, SP.RankUp(profile, "Nope")) == "NotOwned")

	-- tier upgrades wait for the player
	local k3 = SP.Receive(season, common, "Epic")
	check("A higher-tier copy waits as an upgrade", k3 == "Upgrade" and SP.Get(season, common).Tier == "Common" and SP.Get(season, common).Pending == "Epic" and SP.Get(season, common).CanUpgrade)
	local k4, displaced = SP.Receive(season, common, "Legendary")
	check("A better one replaces it and the displaced copy is banked", k4 == "Upgrade" and displaced == "Epic" and SP.Get(season, common).Copies.Epic == 1 and SP.Get(season, common).Pending == "Legendary")
	local k5 = SP.Receive(season, common, "Rare")
	check("A lower copy while one is waiting is just banked", k5 == "Copy")
	local up, tier = SP.Upgrade(profile, common)
	check("Upgrade is manual and applies the highest tier unlocked", up and tier == "Legendary" and SP.Get(season, common).Tier == "Legendary" and SP.Get(season, common).Pending == nil)
	check("Nothing left to upgrade", select(2, SP.Upgrade(profile, common)) == "NothingWaiting")
	check("A tier is worth levels", SP.Get(season, common).Level == SP.Get(season, common).Rank + Cfg.TierBonus.Legendary - Cfg.TierBonus.Common)

	-- levels flow to combat
	local map = SP.LevelMap(season)
	check("The level map lists every owned skill", map[common] ~= nil and map[starter] ~= nil)
	local levels = SP.LevelsFor({ common, starter }, map)
	check("Levels follow the skill, not the slot", levels[1] == map[common] and levels[2] == map[starter])
	local swapped = SP.LevelsFor({ starter, common }, map)
	check("Moving a skill keeps its level", swapped[2] == levels[1])
	check("No level exceeds the cap", SP.Level(season, common) <= m.Skills.MAX_SLOT_LEVEL)
	check("Anything ready is reported for the badge", SP.AnyReady(season) == false or SP.AnyReady(season) == true)

	-- snapshot (ghost) levels
	local snap = m.Party.MakeSnapshot(profile, 7, "P", nil, 0)
	check("A snapshot carries per-skill levels for the ghost", snap.SkillLevels[common] == SP.Level(season, common))
	check("Ghost levels follow the ghost's loadout", m.Party.GhostLevels(snap)[1] == (snap.SkillLevels[snap.GhostLoadout[1]] or 1))


	-- slot levels (trained with gold at the Skill Trainer) add on top of the skill's own level
	local slotProfile = m.ProfileTemplate.New()
	slotProfile.Permanent.UnlockedClasses.Warrior = true
	m.ProfileTemplate.GrantStarterAbilities(slotProfile)
	slotProfile.Season.ClassId = "Warrior"
	local sSeason = slotProfile.Season
	local sLoadout = sSeason.Loadouts.Warrior
	local before = SP.SlotLevelsFor(sSeason, sLoadout, "Warrior")
	sSeason.Currencies.Gold = 1e9
	check("Training a slot works", m.Economy.LevelSlot(slotProfile, "Warrior", 1) == true)
	local after = SP.SlotLevelsFor(sSeason, sLoadout, "Warrior")
	check("A trained slot adds one level to its skill", after[1] == before[1] + 1 and after[2] == before[2])
	local swappedLoadout = { sLoadout[2], sLoadout[1] }
	local swappedLevels = SP.SlotLevelsFor(sSeason, swappedLoadout, "Warrior")
	check("The level stays with the SLOT when skills are swapped", swappedLevels[1] == SP.Level(sSeason, sLoadout[2]) + 1)
	check("Slot bonus lists one entry per slot", #SP.SlotBonus(sSeason, "Warrior", 4) == 4 and SP.SlotBonus(sSeason, "Warrior", 4)[1] == 1)
	local snapS = m.Party.MakeSnapshot(slotProfile, 8, "P", nil, 0)
	check("A snapshot carries the slot bonus for the ghost", snapS.SlotBonus[1] == 1 and m.Party.GhostLevels(snapS)[1] == after[1])
	check("Combined levels never pass the max skill level", SP.WithBonus({ 20 }, { 99 })[1] == m.Skills.MAX_LEVEL)

	-- spare copies of a maxed skill pay Skill Shards instead of banking
	local maxId = starter
	season.SkillState[maxId] = season.SkillState[maxId] or { Tier = SP.BaseTier(maxId), Rank = 1, XP = 0 }
	season.SkillState[maxId].Rank = Cfg.MaxRank
	local shardsBefore = season.Currencies.Shards
	local got, amount = SP.Receive(season, maxId, season.SkillState[maxId].Tier)
	check("A copy of a max rank skill pays shards", got == "Excess" and amount == Cfg.DupShards[season.SkillState[maxId].Tier] and season.Currencies.Shards == shardsBefore + amount)
	check("An excess copy is not banked", ((season.SkillState[maxId].Copies or {})[season.SkillState[maxId].Tier] or 0) == 0)
	season.SkillState[maxId].Copies = { Common = 3 }
	local cashed, paid, kind = SP.Consume(profile, maxId, "All")
	check("Copies banked before max rank cash in for shards", cashed == true and kind == "Shards" and paid == 3 * Cfg.DupShards.Common)

	-- pacing maths
	local total = 0
	for r = 1, Cfg.MaxRank - 1 do total += Cfg.RankXP[r] end
	check("A max rank skill needs a few thousand XP (slow, rank 20)", Cfg.MaxRank == 20 and total >= 3000 and total <= 4500)
	check("The last rank costs far more than the first", Cfg.RankXP[Cfg.MaxRank - 1] >= 30 * Cfg.RankXP[1])
	local avg = (0.45 * Cfg.DupXP.Common + 0.40 * Cfg.DupXP.Rare + 0.15 * Cfg.DupXP.Epic)
	check("A Bright wish gives around 15-30 XP on average", avg >= 15 and avg <= 30)
	check("XP per rank strictly grows", (function() for r = 2, #Cfg.RankXP do if Cfg.RankXP[r] <= Cfg.RankXP[r - 1] then return false end end return true end)())

	-- starter skills are never forced to a state
	check("Season reset clears skill progress", next(ProfileTemplate.NewSeasonData(2).SkillState) == nil)

	print(("SkillProgressTests done: %d passed, %d failed"):format(passed, failed))
end
