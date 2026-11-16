--[[
	CombatTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CombatTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.CombatTests)()

	and read the Output window. It checks the combat rules, then prints a few
	sample fights so you can see how the placeholder balance feels.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Combat = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Combat")
	return {
		Hooks = require(Combat.Hooks),
		Entity = require(Combat.Entity),
		Rng = require(Combat.Rng),
		Simulation = require(Combat.Simulation),
		StatCalc = require(Combat.StatCalc),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Hooks, Entity, Rng, Simulation, StatCalc = m.Hooks, m.Entity, m.Rng, m.Simulation, m.StatCalc
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

	local function dummy(id, team, stats)
		return Entity.new({ Id = id, Team = team, Stats = stats })
	end

	local function standardParty(level)
		return {
			StatCalc.NewPartyMember("p1", "Warrior", "Warrior", level),
			StatCalc.NewPartyMember("p2", "Cleric", "Cleric", level),
		}
	end

	local function signature(events)
		local parts = {}
		for _, e in ipairs(events) do
			table.insert(parts, ("%s|%.1f|%s|%s|%s"):format(e.Type, e.T, tostring(e.Source or e.Target), tostring(e.Amount), tostring(e.Crit)))
		end
		return table.concat(parts, ";")
	end

	print("Running CombatTests...")

	-- Rng ------------------------------------------------------------------
	local a, b = Rng.new(7), Rng.new(7)
	local same, inRange = true, true
	for _ = 1, 200 do
		local x, y = a(), b()
		if x ~= y then
			same = false
		end
		if x <= 0 or x >= 1 then
			inRange = false
		end
	end
	check("Rng: same seed gives same sequence", same)
	check("Rng: values stay strictly between 0 and 1", inRange)

	-- Determinism ----------------------------------------------------------
	local function runStandard(seed)
		local sim = Simulation.new({
			Party = standardParty(3),
			Enemies = {
				StatCalc.NewEnemy("e1", "Slime"),
				StatCalc.NewEnemy("e2", "Goblin"),
				StatCalc.NewEnemy("e3", "Mushroom"),
			},
			Seed = seed,
		})
		sim:Run()
		return sim
	end
	local first, second = runStandard(42), runStandard(42)
	check("Determinism: same seed gives an identical fight", signature(first.Events) == signature(second.Events))
	check("Determinism: results match", first.Result.Winner == second.Result.Winner and first.Result.Duration == second.Result.Duration)

	-- Basic fight outcomes --------------------------------------------------
	local easy = Simulation.new({ Party = standardParty(1), Enemies = { StatCalc.NewEnemy("e1", "Slime") }, Seed = 1 })
	check("A level 1 party beats one Slime", easy:Run().Winner == "Party")

	local stalemate = Simulation.new({
		Party = { dummy("a", "Party", { MaxHealth = 10, Attack = 0, AttackSpeed = 1 }) },
		Enemies = { dummy("b", "Enemy", { MaxHealth = 10, Attack = 0, AttackSpeed = 1 }) },
		MaxSeconds = 5,
	})
	local stalemateResult = stalemate:Run()
	check("A fight nobody can win ends as a Timeout", stalemateResult.Winner == "Timeout" and math.abs(stalemateResult.Duration - 5) < 0.001)

	-- Damage rules ---------------------------------------------------------
	local minDamage = Simulation.new({
		Party = { dummy("a", "Party", { MaxHealth = 10, Attack = 1, AttackSpeed = 1 }) },
		Enemies = { dummy("b", "Enemy", { MaxHealth = 50, Attack = 0, Defense = 10000, AttackSpeed = 1 }) },
		MaxSeconds = 2,
	})
	minDamage:Run()
	local firstHit = nil
	for _, e in ipairs(minDamage.Events) do
		if e.Type == "Damage" then
			firstHit = e
			break
		end
	end
	check("Damage never drops below 1", firstHit ~= nil and firstHit.Amount == 1)

	local timing = Simulation.new({
		Party = { dummy("a", "Party", { MaxHealth = 10, Attack = 5, AttackSpeed = 2 }) },
		Enemies = { dummy("b", "Enemy", { MaxHealth = 1000, Attack = 0, AttackSpeed = 1 }) },
		MaxSeconds = 10,
	})
	timing:Run()
	local hits = 0
	for _, e in ipairs(timing.Events) do
		if e.Type == "Damage" and e.Source == "a" then
			hits += 1
		end
	end
	check("AttackSpeed 2 lands 20 hits in 10 seconds", hits == 20)

	-- Dead entities stay dead and silent -----------------------------------
	local fight = runStandard(5)
	local deathTimes = {}
	for _, e in ipairs(fight.Events) do
		if e.Type == "Death" then
			deathTimes[e.Target] = e.T
		end
	end
	local actedAfterDeath = false
	for _, e in ipairs(fight.Events) do
		if e.Type == "Damage" and not e.Dot and deathTimes[e.Source] and e.T > deathTimes[e.Source] then
			actedAfterDeath = true
		end
	end
	check("Dead entities never act again", not actedAfterDeath)

	-- Hooks ----------------------------------------------------------------
	local function oneHitFight(hooks)
		local sim = Simulation.new({
			Party = { dummy("a", "Party", { MaxHealth = 10, Attack = 10, AttackSpeed = 1 }) },
			Enemies = {
				dummy("b", "Enemy", { MaxHealth = 1000, Attack = 0, Defense = 0, AttackSpeed = 1 }),
				dummy("c", "Enemy", { MaxHealth = 1000, Attack = 0, Defense = 0, AttackSpeed = 1 }),
			},
			Hooks = hooks,
			MaxSeconds = 1,
		})
		sim:Run()
		for _, e in ipairs(sim.Events) do
			if e.Type == "Damage" then
				return e, sim
			end
		end
		return nil, sim
	end

	local baseline = oneHitFight(nil)
	check("Baseline hit is 10 (Attack 10 vs Defense 0)", baseline ~= nil and baseline.Amount == 10)

	local doubling = Hooks.new()
	doubling:On("OnCalculateDamage", function(ctx)
		ctx.Amount *= 2
	end)
	local doubled = oneHitFight(doubling)
	check("OnCalculateDamage hook can double damage", doubled ~= nil and doubled.Amount == 20)

	local retarget = Hooks.new()
	retarget:On("PickTarget", function(ctx)
		ctx.Target = ctx.Candidates[2]
	end)
	local retargeted = oneHitFight(retarget)
	check("PickTarget hook can redirect attacks", retargeted ~= nil and retargeted.Target == "c")

	local preventing = Hooks.new()
	preventing:On("OnBeforeDamage", function(ctx)
		ctx.Prevented = true
	end)
	local prevented = oneHitFight(preventing)
	check("OnBeforeDamage hook can prevent damage", prevented ~= nil and prevented.Amount == 0)

	local disconnectHooks = Hooks.new()
	local calls = 0
	local disconnect = disconnectHooks:On("OnDeath", function()
		calls += 1
	end)
	disconnectHooks:Fire("OnDeath", {})
	disconnect()
	disconnectHooks:Fire("OnDeath", {})
	check("Hooks can be disconnected", calls == 1)

	-- Sample fights (information only) --------------------------------------
	print("Sample fights (placeholder balance, not assertions):")
	local function sample(label, level, enemyIds)
		local enemies = {}
		for i, enemyId in ipairs(enemyIds) do
			table.insert(enemies, StatCalc.NewEnemy("e" .. i, enemyId))
		end
		local sim = Simulation.new({ Party = standardParty(level), Enemies = enemies, Seed = 99, RecordEvents = false })
		local result = sim:Run()
		print(("  %-28s level %2d -> %-7s in %5.1fs, survivors: %d"):format(label, level, result.Winner, result.Duration, #result.Survivors))
	end
	for _, level in ipairs({ 1, 5, 10 }) do
		sample("Slime + Goblin + Mushroom", level, { "Slime", "Goblin", "Mushroom" })
	end
	for _, level in ipairs({ 1, 5, 10 }) do
		sample("Slime King (boss)", level, { "SlimeKing" })
	end

	print(("CombatTests done: %d passed, %d failed"):format(passed, failed))
end
