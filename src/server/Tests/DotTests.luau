--[[
	DotTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > DotTests

	Stacking burn / poison / bleed and %-of-max-health damage, and their caps.   require(...DotTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Simulation = require(Shared.Combat.Simulation), Entity = require(Shared.Combat.Entity), Statuses = require(Shared.Config.Statuses) }
	end
	local Simulation, Entity = m.Simulation, m.Entity
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			(warn or print)("  FAIL  " .. name)
		end
	end
	print("DotTests")

	local function setup(enemyHealth, boss)
		local hero = Entity.new({ Id = "h", Name = "Hero", Team = "Party", Stats = { MaxHealth = 1e6, Attack = 100, Defense = 0, AttackSpeed = 0.0001, CritChance = 0 }, Abilities = {} })
		local enemy = Entity.new({ Id = "e", Name = "Dummy", Team = "Enemy", Stats = { MaxHealth = enemyHealth, Attack = 1, Defense = 0, AttackSpeed = 0.0001, CritChance = 0 }, Abilities = {} })
		if boss then
			enemy.Flags.StunImmune = true
		end
		local sim = Simulation.new({ Party = { hero }, Enemies = { enemy }, Seed = 1, MaxSeconds = 60 })
		return sim, hero, enemy
	end
	local function stacksOf(enemy, id)
		for _, s in ipairs(enemy.Statuses) do
			if s.Id == id then return s.Stacks end
		end
	end
	local function burnFor(seconds, stacks, health, boss, status)
		local sim, hero, enemy = setup(health, boss)
		for _ = 1, stacks do
			sim:ApplyStatus(enemy, status or "Burning", seconds + 5, hero, nil, 1, 1)
		end
		local before = enemy.Health
		for _ = 1, math.floor(seconds / Simulation.TICK) do
			sim:Step()
		end
		return before - enemy.Health, enemy
	end

	local _, e1 = burnFor(0.1, 3, 1e6, false)
	check("burn stacks add up", stacksOf(e1, "Burning") == 3)
	local _, e2 = burnFor(0.1, 20, 1e6, false)
	check("stacks are capped", stacksOf(e2, "Burning") == m.Statuses.Burning.Stacks.Max)
	local _, e3 = burnFor(0.1, 20, 1e6, false, "Poisoned")
	check("poison stacks deeper than burn", stacksOf(e3, "Poisoned") == m.Statuses.Poisoned.Stacks.Max and m.Statuses.Poisoned.Stacks.Max > m.Statuses.Burning.Stacks.Max)

	local one = burnFor(3, 1, 1e6, false)
	local five = burnFor(3, 5, 1e6, false)
	check("more stacks hurt more", five > one * 3)
	-- percent damage: small, capped, and gentler on bosses
	local soft = burnFor(3, 5, 1e6, false)
	local boss = burnFor(3, 5, 1e6, true)
	check("a boss takes less percent damage", boss < soft)
	local huge = burnFor(3, 5, 1e12, false)
	local cap = (m.Statuses.Burning.Dot.Multiplier + m.Statuses.Burning.Dot.PercentCap) * 5 * 100 * 3 * 1.1 + 100
	check("percent damage is capped on huge health pools", huge <= cap)
	check("a stack still ticks on a tiny target", burnFor(2, 1, 100, false) > 0)
	local bossHuge = burnFor(3, 8, 1e12, true, "Poisoned")
	check("8 poison stacks on a boss stay under 2.5 attack per second", bossHuge / 3 < 2.5 * 100)
	local poison8 = burnFor(3, 8, 1e6, false, "Poisoned")
	check("8 poison stacks hit hard on normal enemies", poison8 / 3 > 1.0 * 100)

	print(("DotTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
