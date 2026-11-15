--[[
	AbilityTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > AbilityTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.AbilityTests)()

	and read the Output window.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Combat = Shared:WaitForChild("Combat")
	local Config = Shared:WaitForChild("Config")
	return {
		Hooks = require(Combat.Hooks),
		Entity = require(Combat.Entity),
		Simulation = require(Combat.Simulation),
		StatCalc = require(Combat.StatCalc),
		Abilities = require(Config.Abilities),
		Statuses = require(Config.Statuses),
		Classes = require(Config.Classes),
		Rarities = require(Config.Rarities),
		Skills = require(Shared.Skills),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Hooks, Entity, Simulation, StatCalc = m.Hooks, m.Entity, m.Simulation, m.StatCalc
	local Abilities, Statuses, Classes = m.Abilities, m.Statuses, m.Classes
	local Rarities, Skills = m.Rarities, m.Skills
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

	-- Test helpers ----------------------------------------------------------
	local function entity(id, team, stats, abilities, damageType)
		return Entity.new({ Id = id, Team = team, Stats = stats, Abilities = abilities, DamageType = damageType })
	end

	-- A target that never fights back and never dies.
	local function punchingBag(id)
		return entity(id or "bag", "Enemy", { MaxHealth = 100000, Attack = 0, Defense = 0, AttackSpeed = 1 })
	end

	-- A party member whose basic attacks are effectively off.
	local function caster(id, abilities, extraStats)
		local stats = { MaxHealth = 100000, Attack = 10, Defense = 0, AttackSpeed = 0.01, CritChance = 0 }
		for key, value in pairs(extraStats or {}) do
			stats[key] = value
		end
		return entity(id or "c", "Party", stats, abilities)
	end

	local function countEvents(events, predicate)
		local n = 0
		for _, e in ipairs(events) do
			if predicate(e) then
				n += 1
			end
		end
		return n
	end

	local function signature(events)
		local parts = {}
		for _, e in ipairs(events) do
			table.insert(
				parts,
				("%s|%.1f|%s|%s|%s|%s|%s"):format(
					e.Type,
					e.T,
					tostring(e.Source or e.Target),
					tostring(e.Amount),
					tostring(e.Crit),
					tostring(e.Ability),
					tostring(e.Status)
				)
			)
		end
		return table.concat(parts, ";")
	end

	local testDefs = {
		Nuke = {
			Id = "Nuke",
			Cooldown = 5,
			Effects = { { Type = "Damage", Target = "Primary", Multiplier = 2 } },
		},
		Whirl = {
			Id = "Whirl",
			Cooldown = 2,
			Conditions = { MinEnemies = 2 },
			Effects = { { Type = "Damage", Target = "AllEnemies", Multiplier = 1 } },
		},
		FreeLastStand = {
			Id = "FreeLastStand",
			Cooldown = 100,
			Effects = { { Type = "ApplyStatus", Target = "Self", Status = "LastStand", Duration = 100 } },
		},
		SlowAll = {
			Id = "SlowAll",
			Cooldown = 100,
			Effects = { { Type = "ApplyStatus", Target = "AllEnemies", Status = "Chilled", Duration = 100 } },
		},
		ShortFortify = {
			Id = "ShortFortify",
			Cooldown = 100,
			Effects = { { Type = "ApplyStatus", Target = "Self", Status = "Fortified", Duration = 1 } },
		},
		TestHeal = {
			Id = "TestHeal",
			Cooldown = 100,
			Effects = { { Type = "Heal", Target = "LowestAlly", Multiplier = 2 } },
		},
		TestShield = {
			Id = "TestShield",
			Cooldown = 100,
			Effects = { { Type = "Shield", Target = "Self", PercentMaxHealth = 0.5, Duration = 10 } },
		},
		CommonNuke = {
			Id = "CommonNuke",
			Rarity = "Common",
			Cooldown = 100,
			Effects = { { Type = "Damage", Target = "Primary", Multiplier = 1 } },
		},
		EpicNuke = {
			Id = "EpicNuke",
			Rarity = "Epic",
			Cooldown = 100,
			Effects = { { Type = "Damage", Target = "Primary", Multiplier = 1 } },
		},
		Explode = {
			Id = "Explode",
			Cooldown = 100,
			Effects = { { Type = "Explode", Target = "Self" } },
		},
	}
	-- Real config plus the test-only abilities above.
	local defs = {}
	for id, def in pairs(Abilities) do
		defs[id] = def
	end
	for id, def in pairs(testDefs) do
		defs[id] = def
	end

	local function newSim(party, enemies, options)
		options = options or {}
		return Simulation.new({
			Party = party,
			Enemies = enemies,
			Seed = options.Seed or 1,
			MaxSeconds = options.MaxSeconds or 12,
			Hooks = options.Hooks,
			AbilityDefs = defs,
		})
	end

	print("Running AbilityTests...")

	-- Config integrity ------------------------------------------------------
	local allKnown = true
	for classId, class in pairs(Classes) do
		for _, abilityId in ipairs(class.AbilityPool) do
			if Abilities[abilityId] == nil then
				allKnown = false
				warnFn(("    %s lists unknown ability %s"):format(classId, abilityId))
			end
		end
	end
	check("Every class ability exists in Config/Abilities", allKnown)

	local configValid = true
	for abilityId, def in pairs(Abilities) do
		if def.Cooldown == nil or def.Cooldown <= 0 or def.Effects == nil or #def.Effects == 0 then
			configValid = false
			warnFn("    bad ability: " .. abilityId)
		end
		for _, effect in ipairs(def.Effects or {}) do
			if Simulation.Effects[effect.Type] == nil then
				configValid = false
				warnFn(("    %s uses unknown effect %s"):format(abilityId, tostring(effect.Type)))
			end
			if effect.Type == "ApplyStatus" and Statuses[effect.Status] == nil then
				configValid = false
				warnFn(("    %s applies unknown status %s"):format(abilityId, tostring(effect.Status)))
			end
		end
		for key in pairs(def.Conditions or {}) do
			if Simulation.Conditions[key] == nil then
				configValid = false
				warnFn(("    %s uses unknown condition %s"):format(abilityId, key))
			end
		end
	end
	check("Every ability has a cooldown, known effects, statuses and conditions", configValid)

	local warrior = StatCalc.NewPartyMember("w", "Warrior", "Warrior", 1)
	check("Party members get their class's four-skill default loadout", #warrior.Abilities == 4 and warrior.Abilities[1].Id == "Taunt")

	-- Cooldown cadence --------------------------------------------------------
	local cadence = newSim({ caster("c", { { Id = "Nuke" } }) }, { punchingBag() }, { MaxSeconds = 12 })
	cadence:Run()
	check("A 5s-cooldown ability casts 3 times in 12s", countEvents(cadence.Events, function(e)
		return e.Type == "Cast" and e.Ability == "Nuke"
	end) == 3)

	-- Damage scaling ----------------------------------------------------------
	local function firstNukeDamage(level)
		local sim = newSim({ caster("c", { { Id = "Nuke", Level = level } }) }, { punchingBag() }, { MaxSeconds = 1 })
		sim:Run()
		for _, e in ipairs(sim.Events) do
			if e.Type == "Damage" and e.Tag == "Nuke" then
				return e.Amount
			end
		end
		return nil
	end
	check("Damage is Attack x Multiplier (10 x 2 = 20)", firstNukeDamage(1) == 20)
	check("Ability level adds 10% per level (level 3 = 24)", firstNukeDamage(3) == 24)

	-- Conditions ---------------------------------------------------------------
	local solo = newSim({ caster("c", { { Id = "Whirl" } }) }, { punchingBag("b1") }, { MaxSeconds = 6 })
	solo:Run()
	check("MinEnemies=2 blocks a cast against one enemy", countEvents(solo.Events, function(e)
		return e.Type == "Cast"
	end) == 0)

	local pair = newSim({ caster("c", { { Id = "Whirl" } }) }, { punchingBag("b1"), punchingBag("b2") }, { MaxSeconds = 1 })
	pair:Run()
	check("MinEnemies=2 allows a cast against two enemies", countEvents(pair.Events, function(e)
		return e.Type == "Cast"
	end) == 1)
	check("Area damage hits every enemy in the same cast", countEvents(pair.Events, function(e)
		return e.Type == "Damage" and e.Tag == "Whirl"
	end) == 2)

	-- Taunt ----------------------------------------------------------------
	local function enemyHitTargets(withTaunt)
		local tank = caster("tank", if withTaunt then { { Id = "Taunt" } } else nil)
		local ally = caster("ally", nil)
		local attacker = entity("foe", "Enemy", { MaxHealth = 100000, Attack = 1, Defense = 0, AttackSpeed = 1 })
		local sim = newSim({ ally, tank }, { attacker }, { MaxSeconds = 6 })
		sim:Run()
		local hitTank, hitAlly = 0, 0
		for _, e in ipairs(sim.Events) do
			if e.Type == "Damage" and e.Source == "foe" then
				if e.Target == "tank" then
					hitTank += 1
				else
					hitAlly += 1
				end
			end
		end
		return hitTank, hitAlly
	end
	local noTauntTank, noTauntAlly = enemyHitTargets(false)
	check("Without Taunt enemies hit the first party member", noTauntAlly >= 5 and noTauntTank == 0)
	local tauntTank, tauntAlly = enemyHitTargets(true)
	check("Taunt redirects every enemy attack to the Warrior", tauntTank >= 5 and tauntAlly == 0)

	-- Slow -------------------------------------------------------------------
	local function enemyHits(abilities)
		local foe = entity("foe", "Enemy", { MaxHealth = 100000, Attack = 1, Defense = 0, AttackSpeed = 1 })
		local sim = newSim({ caster("c", abilities) }, { foe }, { MaxSeconds = 10 })
		sim:Run()
		return countEvents(sim.Events, function(e)
			return e.Type == "Damage" and e.Source == "foe"
		end)
	end
	local normalHits, slowedHits = enemyHits(nil), enemyHits({ { Id = "SlowAll" } })
	check("Baseline enemy lands 10 hits in 10s", normalHits == 10)
	check("Chilled enemy attacks less often (about 6 hits)", slowedHits >= 5 and slowedHits <= 7 and slowedHits < normalHits)

	-- Last Stand ---------------------------------------------------------------
	local function survivesBigHits(abilities, maxSeconds)
		local hero = entity("hero", "Party", { MaxHealth = 50, Attack = 0, Defense = 0, AttackSpeed = 0.01 }, abilities)
		local brute = entity("brute", "Enemy", { MaxHealth = 100000, Attack = 1000, Defense = 0, AttackSpeed = 1 })
		local sim = newSim({ hero }, { brute }, { MaxSeconds = maxSeconds })
		return sim:Run(), hero
	end
	local protectedResult, protectedHero = survivesBigHits({ { Id = "FreeLastStand" } }, 5)
	check("Last Stand leaves the hero at 1 health instead of dying", protectedResult.Winner == "Timeout" and protectedHero.Health == 1)
	local unprotectedResult = survivesBigHits(nil, 5)
	check("Without Last Stand the same hero dies", unprotectedResult.Winner == "Enemy")

	-- The real Warrior Last Stand triggers below 50% health.
	-- Hits of 30 drop him to 40 health at 2.0s, Last Stand starts at 2.1s and
	-- protects him until 6.1s. Without it he dies at 4.0s.
	local function warriorAt6s(abilities)
		local tank = entity("tank", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 }, abilities)
		local foe = entity("foe", "Enemy", { MaxHealth = 100000, Attack = 30, Defense = 0, AttackSpeed = 1 })
		local sim = Simulation.new({ Party = { tank }, Enemies = { foe }, Seed = 1, MaxSeconds = 6 })
		return sim:Run().Winner
	end
	check("Warrior's Last Stand triggers below 50% health", warriorAt6s({ { Id = "LastStand" } }) == "Timeout")
	check("...and without it the Warrior would have died", warriorAt6s(nil) == "Enemy")

	-- Fortified (generates defense) and expiry ---------------------------------
	local fortifier = caster("c", { { Id = "ShortFortify" } }, { Defense = 10 })
	local fortSim = newSim({ fortifier }, { punchingBag() }, { MaxSeconds = 3 })
	fortSim:Step()
	check("Fortified raises Defense by 50% while active", math.abs(fortSim:GetStat(fortifier, "Defense") - 15) < 1e-9)
	fortSim:Run()
	check("The status expires and Defense returns to normal", math.abs(fortSim:GetStat(fortifier, "Defense") - 10) < 1e-9)
	local endEvent = nil
	for _, e in ipairs(fortSim.Events) do
		if e.Type == "StatusEnd" then
			endEvent = e
		end
	end
	check("A 1s status ends after about 1s", endEvent ~= nil and endEvent.T >= 1.0 and endEvent.T <= 1.2)

	-- Arcane Surge boosts magical damage -----------------------------------------
	local function firstBasicHit(abilities)
		local mage = entity("mage", "Party", { MaxHealth = 1000, Attack = 10, Defense = 0, AttackSpeed = 1, CritChance = 0 }, abilities, "Magical")
		local sim = newSim({ mage }, { punchingBag() }, { MaxSeconds = 2 })
		sim:Run()
		for _, e in ipairs(sim.Events) do
			if e.Type == "Damage" and e.Tag == "BasicAttack" then
				return e.Amount
			end
		end
		return nil
	end
	check("A Mage's basic attack hits for 10 normally", firstBasicHit(nil) == 10)
	check("Arcane Surge raises magical damage by 50%", firstBasicHit({ { Id = "ArcaneSurge" } }) == 15)

	-- Hooks and extension points -----------------------------------------------
	local cancelHooks = Hooks.new()
	local cancelCalls = 0
	cancelHooks:On("OnAbilityCast", function(ctx)
		cancelCalls += 1
		ctx.Cancelled = true
	end)
	local cancelSim = newSim({ caster("c", { { Id = "Nuke" } }) }, { punchingBag() }, { MaxSeconds = 12, Hooks = cancelHooks })
	cancelSim:Run()
	check("OnAbilityCast can cancel a cast", countEvents(cancelSim.Events, function(e)
		return e.Type == "Damage" and e.Tag == "Nuke"
	end) == 0)
	check("A cancelled cast still spends its cooldown", cancelCalls == 3)

	local statusHooks = Hooks.new()
	statusHooks:On("OnApplyStatus", function(ctx)
		ctx.Duration *= 2
	end)
	local doubledSim = newSim({ caster("c", { { Id = "ShortFortify" } }) }, { punchingBag() }, { MaxSeconds = 5, Hooks = statusHooks })
	doubledSim:Run()
	local doubledEnd = nil
	for _, e in ipairs(doubledSim.Events) do
		if e.Type == "StatusEnd" then
			doubledEnd = e
		end
	end
	check("OnApplyStatus can change a status duration", doubledEnd ~= nil and doubledEnd.T >= 2.0 and doubledEnd.T <= 2.2)

	local exploded = 0
	Simulation.Effects.Explode = function()
		exploded += 1
	end
	newSim({ caster("c", { { Id = "Explode" } }) }, { punchingBag() }, { MaxSeconds = 1 }):Run()
	Simulation.Effects.Explode = nil
	check("New effect types can be registered without editing combat", exploded == 1)

	-- Healing --------------------------------------------------------------------
	local function healScenario(startHealth, hooks)
		local healer = entity("healer", "Party", { MaxHealth = 100, Attack = 10, Defense = 0, AttackSpeed = 0.01 }, { { Id = "TestHeal" } })
		local hurt = entity("hurt", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 })
		hurt.Health = startHealth
		local sim = newSim({ healer, hurt }, { punchingBag() }, { MaxSeconds = 1, Hooks = hooks })
		sim:Run()
		return hurt, sim
	end
	local hurtOne = healScenario(50)
	check("Heal restores Attack x Multiplier (10 x 2 = 20) to the lowest ally", hurtOne.Health == 70)
	local nearlyFull, nearlyFullSim = healScenario(95)
	local healEvent = nil
	for _, e in ipairs(nearlyFullSim.Events) do
		if e.Type == "Heal" then
			healEvent = e
		end
	end
	check("Healing never exceeds max health", nearlyFull.Health == 100 and healEvent ~= nil and healEvent.Amount == 5 and healEvent.Overheal == 15)
	local doubleHeal = Hooks.new()
	doubleHeal:On("OnHeal", function(ctx)
		ctx.Amount *= 2
	end)
	check("OnHeal hook can change a heal (20 becomes 40)", (healScenario(50, doubleHeal)).Health == 90)

	local function healCasts(startHealth)
		local healer = entity("healer", "Party", { MaxHealth = 100, Attack = 10, Defense = 0, AttackSpeed = 0.01 }, { { Id = "Heal" } })
		local ally = entity("ally", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 })
		ally.Health = startHealth
		local sim = newSim({ healer, ally }, { punchingBag() }, { MaxSeconds = 3 })
		sim:Run()
		return countEvents(sim.Events, function(e)
			return e.Type == "Cast" and e.Ability == "Heal"
		end)
	end
	check("The Cleric's Heal waits until an ally is below 70% health", healCasts(100) == 0 and healCasts(50) >= 1)

	-- Shields ---------------------------------------------------------------------
	local function shieldFight(maxSeconds)
		local hero = entity("hero", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 }, { { Id = "TestShield" } })
		local foe = entity("foe", "Enemy", { MaxHealth = 100000, Attack = 30, Defense = 0, AttackSpeed = 1 })
		local sim = newSim({ hero }, { foe }, { MaxSeconds = maxSeconds })
		sim:Run()
		return hero, sim
	end
	-- Shield is 50 (50% of 100 max health). Hits of 30 at 1.0s and 2.0s:
	-- the first is fully absorbed, the second loses 10 health after 20 is absorbed.
	local shieldedHero, shieldSim = shieldFight(2)
	check("A shield soaks damage before health is lost", shieldedHero.Health == 90)
	local shieldBroke = false
	for _, e in ipairs(shieldSim.Events) do
		if e.Type == "StatusEnd" and e.Status == "Shield" and e.Reason == "Broken" then
			shieldBroke = true
		end
	end
	check("A used-up shield is removed", shieldBroke and not shieldSim:HasStatus(shieldedHero, "Shield"))
	local firstHit = nil
	for _, e in ipairs(shieldSim.Events) do
		if e.Type == "Damage" and e.Source == "foe" then
			firstHit = e
			break
		end
	end
	check("Damage events report how much a shield absorbed", firstHit ~= nil and firstHit.Amount == 0 and firstHit.Absorbed == 30)

	-- Guardian Angel (the Cleric's lifesaver) ------------------------------------
	local function angelFight(withAngel)
		local hero = entity("hero", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 })
		hero.Health = 30 -- below the 35% trigger
		local cleric = entity("cleric", "Party", { MaxHealth = 100, Attack = 0, Defense = 0, AttackSpeed = 0.01 }, if withAngel then { { Id = "GuardianAngel" } } else nil)
		local brute = entity("brute", "Enemy", { MaxHealth = 100000, Attack = 1000, Defense = 0, AttackSpeed = 1 })
		local sim = newSim({ hero, cleric }, { brute }, { MaxSeconds = 3 })
		sim:Run()
		return hero
	end
	local angelHero = angelFight(true)
	check("Guardian Angel keeps a dying ally alive at 1 health", angelHero.Alive and angelHero.Health == 1)
	check("...and without it the same ally dies", not angelFight(false).Alive)

	-- Rarity and levelling -------------------------------------------------------
	local function levelledHit(abilityId, level)
		local sim = newSim({ caster("c", { { Id = abilityId, Level = level } }) }, { punchingBag() }, { MaxSeconds = 1 })
		sim:Run()
		for _, e in ipairs(sim.Events) do
			if e.Type == "Damage" and e.Tag == abilityId then
				return e.Amount
			end
		end
		return nil
	end
	check("Common skills gain 8% per level (level 6 = 14)", levelledHit("CommonNuke", 6) == 14)
	check("Epic skills gain 12% per level (level 6 = 16)", levelledHit("EpicNuke", 6) == 16)
	check("Every slot has the same level cap (20)", Skills.MAX_SLOT_LEVEL == 20)
	check("Slot levels are clamped to the cap and floor", Skills.ClampSlotLevel(99) == 20 and Skills.ClampSlotLevel(0) == 1 and Skills.ClampSlotLevel(nil) == 1)
	local levelled = StatCalc.ClassAbilities("Warrior", { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" }, { 5, 99, 3 })
	check("Levels follow the slot position, clamped, defaulting to 1", levelled[1].Level == 5 and levelled[2].Level == 20 and levelled[3].Level == 3 and levelled[4].Level == 1)
	local swapped = StatCalc.ClassAbilities("Warrior", { "Taunt", "LastStand", "ShieldBash", "Whirlwind" }, { 5, 8, 3, 1 })
	check("Swapping the skill in a slot keeps the slot's level", swapped[2].Id == "LastStand" and swapped[2].Level == 8)

	-- Class design: both classes have damage and role skills ---------------------
	local function poolHasEffect(classId, effectType, extra)
		for _, abilityId in ipairs(Classes[classId].AbilityPool) do
			for _, effect in ipairs(Abilities[abilityId].Effects) do
				if effect.Type == effectType and (extra == nil or extra(effect)) then
					return true
				end
			end
		end
		return false
	end
	local function poolRarities(classId)
		local counts = { Common = 0, Rare = 0, Epic = 0 }
		for _, abilityId in ipairs(Classes[classId].AbilityPool) do
			counts[Abilities[abilityId].Rarity] += 1
		end
		return counts
	end
	for _, classId in ipairs({ "Warrior", "Cleric" }) do
		local counts = poolRarities(classId)
		check(classId .. " has its full skill list across all three rarities", #Classes[classId].AbilityPool == (if classId == "Cleric" then 9 else 8) and counts.Common > 0 and counts.Rare > 0 and counts.Epic > 0)
		check(classId .. " has damage skills", poolHasEffect(classId, "Damage"))
	end
	check("Warrior has shield skills and defense buffs", poolHasEffect("Warrior", "Shield") and poolHasEffect("Warrior", "ApplyStatus", function(e)
		return e.Status == "Fortified" or e.Status == "IronSkin"
	end))
	check("Cleric has healing and shield skills", poolHasEffect("Cleric", "Heal") and poolHasEffect("Cleric", "Shield"))

	-- Loadout rules (server-side validation) --------------------------------------
	local ownsAllWarrior = {}
	for _, abilityId in ipairs(Classes.Warrior.AbilityPool) do
		ownsAllWarrior[abilityId] = 1
	end
	check("A valid four-skill loadout is accepted", (Skills.ValidateLoadout("Warrior", { "Taunt", "IronSkin", "ShieldBash", "LastStand" }, ownsAllWarrior)))
	local _, tooMany = Skills.ValidateLoadout("Warrior", { "Taunt", "IronSkin", "ShieldBash", "LastStand", "Whirlwind" }, ownsAllWarrior)
	check("More than four skills is rejected", tooMany == "TooMany")
	local _, duplicate = Skills.ValidateLoadout("Warrior", { "Taunt", "Taunt" }, ownsAllWarrior)
	check("The same skill twice is rejected", duplicate == "Duplicate")
	local _, wrongClass = Skills.ValidateLoadout("Warrior", { "Smite" }, { Smite = 1 })
	check("Another class's skill is rejected", wrongClass == "WrongClass")
	local _, notOwned = Skills.ValidateLoadout("Warrior", { "LastStand" }, { Taunt = 1 })
	check("A skill the player does not own is rejected", notOwned == "NotOwned")
	local _, unknown = Skills.ValidateLoadout("Warrior", { "NotARealSkill" }, ownsAllWarrior)
	check("An unknown skill id is rejected", unknown == "UnknownAbility")
	local _, notList = Skills.ValidateLoadout("Warrior", "Taunt", ownsAllWarrior)
	check("A non-list request is rejected", notList == "NotAList")
	local pool = Skills.Pool("Cleric")
	check("Skill pools list lower rarities first", Abilities[pool[1]].Rarity == "Common" and Abilities[pool[#pool]].Rarity == "Epic")

	-- A real Warrior + Cleric fight uses healing and shielding --------------------
	local duoSim = Simulation.new({
		Party = {
			StatCalc.NewPartyMember("w", "Warrior", "Warrior", 1),
			StatCalc.NewPartyMember("c", "Cleric", "Cleric", 1),
		},
		Enemies = { StatCalc.NewEnemy("boss", "SlimeKing") },
		Seed = 5,
		MaxSeconds = 60,
	})
	duoSim:Run()
	check("In a boss fight the Cleric heals", countEvents(duoSim.Events, function(e)
		return e.Type == "Heal" and e.Source == "c"
	end) > 0)

	-- Determinism with abilities -----------------------------------------------
	local function fullFight(seed)
		local sim = Simulation.new({
			Party = {
				StatCalc.NewPartyMember("p1", "Warrior", "Warrior", 4),
				StatCalc.NewPartyMember("p2", "Cleric", "Cleric", 4),
			},
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
	local one, two = fullFight(77), fullFight(77)
	check("Fights with abilities are still deterministic", signature(one.Events) == signature(two.Events))
	check("Both classes actually cast during a real fight", countEvents(one.Events, function(e)
		return e.Type == "Cast" and e.Source == "p1"
	end) > 0 and countEvents(one.Events, function(e)
		return e.Type == "Cast" and e.Source == "p2"
	end) > 0)

	-- Sample fights (information only) -------------------------------------------
	print("Sample fights with abilities (placeholder balance, not assertions):")
	local function sample(label, level, enemyIds)
		local enemies = {}
		for i, enemyId in ipairs(enemyIds) do
			table.insert(enemies, StatCalc.NewEnemy("e" .. i, enemyId))
		end
		local sim = Simulation.new({
			Party = {
				StatCalc.NewPartyMember("p1", "Warrior", "Warrior", level),
				StatCalc.NewPartyMember("p2", "Cleric", "Cleric", level),
			},
			Enemies = enemies,
			Seed = 99,
			RecordEvents = false,
		})
		local result = sim:Run()
		print(("  %-28s level %2d -> %-7s in %5.1fs, survivors: %d"):format(label, level, result.Winner, result.Duration, #result.Survivors))
	end
	for _, level in ipairs({ 1, 5, 10 }) do
		sample("Slime + Goblin + Mushroom", level, { "Slime", "Goblin", "Mushroom" })
	end
	for _, level in ipairs({ 1, 5, 10 }) do
		sample("Slime King (boss)", level, { "SlimeKing" })
	end

	print(("AbilityTests done: %d passed, %d failed"):format(passed, failed))
end
