--[[
	SkillStatsTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SkillStatsTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.SkillStatsTests)()

	Checks that every skill grows its own stats per level, status Strength,
	and the once-per-combat Resurrection.
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
		AbilityStats = require(Combat.AbilityStats),
		Abilities = require(Shared.Config.Abilities),
		Classes = require(Shared.Config.Classes),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Entity, Simulation, AbilityStats, Abilities, Classes = m.Entity, m.Simulation, m.AbilityStats, m.Abilities, m.Classes
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

	print("Running SkillStatsTests...")

	local function near(a, b)
		return math.abs(a - b) < 1e-6
	end

	-- Per-level growth -----------------------------------------------------------
	local bash = Abilities.ShieldBash
	local damageEffect = bash.Effects[1]
	check("Shield Bash damage: 140% at level 1", near(AbilityStats.Value(bash, damageEffect, "Multiplier", 1), 1.4))
	check("Shield Bash damage: +10% per level (level 11 = 240%)", near(AbilityStats.Value(bash, damageEffect, "Multiplier", 11), 2.4))
	check("Shield Bash cooldown shortens with level (6.0s -> 5.0s at level 11)", near(AbilityStats.Cooldown(bash, 1), 6) and near(AbilityStats.Cooldown(bash, 11), 5))
	check("Cooldown never drops below the skill's floor", AbilityStats.Cooldown(bash, 500) == bash.MinCooldown)

	local wall = Abilities.ShieldWall
	local shieldEffect = wall.Effects[1]
	check("Shield Wall grows shield size per level", AbilityStats.Value(wall, shieldEffect, "PercentMaxHealth", 11) > AbilityStats.Value(wall, shieldEffect, "PercentMaxHealth", 1))
	check("Shield Wall grows shield duration per level", near(AbilityStats.Value(wall, shieldEffect, "Duration", 11), 12))

	local function rowLabels(abilityId, level)
		local labels = {}
		for _, row in ipairs(AbilityStats.Rows(Abilities[abilityId], level)) do
			labels[row.Label] = row.Value
		end
		return labels
	end
	check("A damage skill lists Damage", rowLabels("Smite", 1).Damage == "150%")
	check("A heal skill lists Heal and no Damage", rowLabels("Heal", 1).Heal ~= nil and rowLabels("Heal", 1).Damage == nil)
	check("A defensive buff lists Duration and Strength", rowLabels("IronSkin", 5).Duration ~= nil and rowLabels("IronSkin", 5).Strength ~= nil)
	check("Resurrection lists its once-per-fight limit", rowLabels("Resurrection", 1).Uses == "1 per fight")

	local everySkillHasRows = true
	for classId, class in pairs(Classes) do
		for _, abilityId in ipairs(class.AbilityPool) do
			if #AbilityStats.Rows(Abilities[abilityId], 1) == 0 then
				everySkillHasRows = false
			end
		end
	end
	check("Every class skill describes itself in UI rows", everySkillHasRows)

	local everyEffectGrows = true
	for _, classId in ipairs({ "Warrior", "Cleric" }) do
		for _, abilityId in ipairs(Classes[classId].AbilityPool) do
			for _, effect in ipairs(Abilities[abilityId].Effects) do
				if effect.PerLevel == nil then
					everyEffectGrows = false
				end
			end
		end
	end
	check("Every Warrior and Cleric effect lists its own PerLevel growth", everyEffectGrows)

	-- Status strength -------------------------------------------------------------
	local function entity(id, team, stats, abilities)
		return Entity.new({ Id = id, Team = team, Stats = stats, Abilities = abilities })
	end
	local dummy = entity("w", "Party", { MaxHealth = 100, Attack = 1, Defense = 100 })
	local foe = entity("e", "Enemy", { MaxHealth = 100000, Attack = 0, Defense = 0 })
	local sim = Simulation.new({ Party = { dummy }, Enemies = { foe }, Seed = 1 })
	sim:ApplyStatus(dummy, "IronSkin", 5, nil, nil, 1)
	check("Iron Skin at strength 1 multiplies defense by 1.8", near(sim:GetStat(dummy, "Defense"), 180))
	sim:ApplyStatus(dummy, "IronSkin", 5, nil, nil, 1.5)
	check("A stronger Iron Skin raises defense further (strength 1.5 = x2.2)", near(sim:GetStat(dummy, "Defense"), 220))
	sim:ApplyStatus(dummy, "IronSkin", 5, nil, nil, 1)
	check("Reapplying a weaker one keeps the stronger strength", near(sim:GetStat(dummy, "Defense"), 220))

	-- Resurrection ----------------------------------------------------------------
	local function reviveFight(withCleric)
		local hero = entity("hero", "Party", { MaxHealth = 50, Attack = 0, Defense = 0, AttackSpeed = 0.05 })
		local cleric = entity("cleric", "Party", { MaxHealth = 100000, Attack = 0, Defense = 1000, AttackSpeed = 0.05 }, if withCleric then { { Id = "Resurrection", Level = 1 } } else nil)
		local brute = entity("brute", "Enemy", { MaxHealth = 1000000, Attack = 100, Defense = 0, AttackSpeed = 1 })
		local fight = Simulation.new({ Party = { hero, cleric }, Enemies = { brute }, Seed = 3, MaxSeconds = 30 })
		fight:Run()
		return fight, hero
	end
	local function countType(events, kind)
		local total = 0
		for _, e in ipairs(events) do
			if e.Type == kind then
				total += 1
			end
		end
		return total
	end
	local fight, hero = reviveFight(true)
	check("Resurrection revives the fallen ally", countType(fight.Events, "Revive") == 1)
	local reviveEvent
	for _, e in ipairs(fight.Events) do
		if e.Type == "Revive" then
			reviveEvent = e
		end
	end
	check("...at 35% of max health at level 1 (18 of 50)", reviveEvent ~= nil and reviveEvent.TargetHealth == 18)
	check("Resurrection is cast only once per combat, even when the ally dies again", countType(fight.Events, "Revive") == 1 and not hero.Alive)
	local noCleric = reviveFight(false)
	check("Without Resurrection nobody is revived", countType(noCleric.Events, "Revive") == 0)

	local healthyHero = entity("h2", "Party", { MaxHealth = 100000, Attack = 0, Defense = 0, AttackSpeed = 0.05 })
	local healthyCleric = entity("c2", "Party", { MaxHealth = 100000, Attack = 0, Defense = 0, AttackSpeed = 0.05 }, { { Id = "Resurrection", Level = 1 } })
	local idle = Simulation.new({ Party = { healthyHero, healthyCleric }, Enemies = { entity("e2", "Enemy", { MaxHealth = 100000, Attack = 0, Defense = 0 }) }, Seed = 1, MaxSeconds = 20 })
	idle:Run()
	check("It is not cast while everyone is alive", countType(idle.Events, "Cast") == 0)

	local lonely = entity("solo", "Party", { MaxHealth = 50, Attack = 0, Defense = 0, AttackSpeed = 0.05 }, { { Id = "Resurrection", Level = 1 } })
	local killer = entity("k", "Enemy", { MaxHealth = 1000000, Attack = 100, Defense = 0, AttackSpeed = 1 })
	local lost = Simulation.new({ Party = { lonely }, Enemies = { killer }, Seed = 1, MaxSeconds = 30 })
	local result = lost:Run()
	check("A Cleric cannot revive anyone once the whole party is down", result.Winner == "Enemy" and countType(lost.Events, "Revive") == 0)

	print(("SkillStatsTests done: %d passed, %d failed"):format(passed, failed))
end
