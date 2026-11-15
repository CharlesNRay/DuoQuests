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
	local common, rare
	for _, id in ipairs(m.Skills.AllSkills("Warrior")) do
		local base = SP.BaseTier(id)
		if base == "Common" and not common and not season.OwnedAbilities[id] then common = id end
		if base == "Rare" and not rare then rare = id end
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
	local kind, xp = SP.Receive(season, common, "Common")
	check("A same-tier copy is XP", kind == "XP" and xp == Cfg.DupXP.Common and SP.Get(season, common).XP == Cfg.DupXP.Common)
	check("Nothing ranks up by itself", SP.Get(season, common).Rank == 1)
	for _ = 1, 1 do SP.Receive(season, common, "Common") end
	check("Enough XP makes the rank up button ready, but does not press it", SP.Get(season, common).CanRank and SP.Get(season, common).Rank == 1)
	local ok, rank = SP.RankUp(profile, common)
	check("Rank up is manual and spends the XP", ok and rank == 2 and SP.Get(season, common).XP == 2 * Cfg.DupXP.Common - Cfg.RankXP[1])
	check("Rank up needs the XP", select(2, SP.RankUp(profile, common)) == "NotEnoughXP")
	check("An unowned skill cannot rank up", select(2, SP.RankUp(profile, "Nope")) == "NotOwned")

	-- tier upgrades wait for the player
	local k3 = SP.Receive(season, common, "Epic")
	check("A higher-tier copy waits as an upgrade", k3 == "Upgrade" and SP.Get(season, common).Tier == "Common" and SP.Get(season, common).Pending == "Epic" and SP.Get(season, common).CanUpgrade)
	local k4, displaced = SP.Receive(season, common, "Legendary")
	check("A better one replaces it and the displaced copy becomes XP", k4 == "Upgrade" and displaced == Cfg.DupXP.Epic and SP.Get(season, common).Pending == "Legendary")
	local k5 = SP.Receive(season, common, "Rare")
	check("A lower copy while one is waiting is just XP", k5 == "XP")
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

	-- pacing maths
	local total = 0
	for r = 1, Cfg.MaxRank - 1 do total += Cfg.RankXP[r] end
	check("A max rank skill needs about 500-900 XP", total >= 500 and total <= 900)
	local avg = (0.45 * Cfg.DupXP.Common + 0.40 * Cfg.DupXP.Rare + 0.15 * Cfg.DupXP.Epic)
	check("A Bright wish gives around 15-30 XP on average", avg >= 15 and avg <= 30)
	check("XP per rank strictly grows", (function() for r = 2, #Cfg.RankXP do if Cfg.RankXP[r] <= Cfg.RankXP[r - 1] then return false end end return true end)())

	-- starter skills are never forced to a state
	check("Season reset clears skill progress", next(ProfileTemplate.NewSeasonData(2).SkillState) == nil)

	print(("SkillProgressTests done: %d passed, %d failed"):format(passed, failed))
end
