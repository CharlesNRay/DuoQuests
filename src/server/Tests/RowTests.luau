--[[
	RowTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > RowTests

	Front/Back rows, row-limited area attacks, Haste, Cleanse, boss-only stuns and gear rolls.   require(...RowTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Simulation = require(Shared.Combat.Simulation), Entity = require(Shared.Combat.Entity), Abilities = require(Shared.Config.Abilities),
			Enemies = require(Shared.Config.Enemies), Gear = require(Shared.Gear), GearConfig = require(Shared.Config.Gear),
		}
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
	print("RowTests")

	local function stats(health)
		return { MaxHealth = health or 1e6, Attack = 100, Defense = 0, AttackSpeed = 0.0001, CritChance = 0 }
	end
	local function fighter(id, team, range, abilities, extra)
		local e = Entity.new({ Id = id, Team = team, Stats = stats(), BasicAttack = { Id = "x", DisplayName = "x", Range = range }, Abilities = abilities or {} })
		for k, v in pairs(extra or {}) do e[k] = v end
		return e
	end

	-- rows are assigned from range, minions and bosses
	local melee = fighter("m", "Party", "Melee")
	local ranged = fighter("r", "Party", "Ranged")
	local minion = fighter("s", "Party", "Melee", nil, { Minion = true })
	local frontEnemy = fighter("e1", "Enemy", "Melee")
	local bossEnemy = fighter("b", "Enemy", "Melee")
	bossEnemy.Flags.StunImmune = true
	local sim = Simulation.new({ Party = { melee, ranged, minion }, Enemies = { frontEnemy, bossEnemy }, Seed = 1, MaxSeconds = 5 })
	check("melee fighters stand in front", sim:RowOf(melee) == "Front")
	check("ranged fighters stand behind", sim:RowOf(ranged) == "Back")
	check("summons stand in front", sim:RowOf(minion) == "Front")
	check("bosses stand behind their minions", sim:RowOf(bossEnemy) == "Back" and sim:RowOf(frontEnemy) == "Front")

	-- melee can only reach the front row while it has someone alive
	for _ = 1, 40 do
		check("a melee attacker never reaches past the front row", sim:PickTarget(melee) == frontEnemy)
	end
	-- a skill that snipes the back row can
	check("a Reach = Any skill goes for the back row", sim:PickTarget(melee, true) == bossEnemy)
	-- with the front row gone, the back row becomes reachable (nothing is left unable to attack)
	frontEnemy.Health = 0
	frontEnemy.Alive = false
	check("when the front row falls the back row is reachable", sim:PickTarget(melee) == bossEnemy)

	-- ranged fighters sometimes reach the back row
	local f2 = fighter("e2", "Enemy", "Melee")
	local b2 = fighter("b2", "Enemy", "Melee")
	b2.Flags.StunImmune = true
	local sim2 = Simulation.new({ Party = { ranged }, Enemies = { f2, b2 }, Seed = 3, MaxSeconds = 5 })
	local back, front = 0, 0
	for _ = 1, 400 do
		local t = sim2:PickTarget(ranged)
		if t == b2 then back += 1 else front += 1 end
	end
	check("ranged attackers hit the front row most of the time", front > back)
	check("ranged attackers do reach the back row sometimes", back > 40)

	-- area attacks hit only the target's row
	local volley = { Id = "TestAoE", DisplayName = "t", Cooldown = 1, Effects = { { Type = "Damage", Target = "AllEnemies", Multiplier = 1 } } }
	local pierce = { Id = "TestPierce", DisplayName = "t", Cooldown = 1, AllRows = true, Effects = { { Type = "Damage", Target = "AllEnemies", Multiplier = 1 } } }
	local function aoe(def)
		local caster = fighter("c", "Party", "Melee", { { Id = def.Id, Level = 1 } })
		local a1, a2 = fighter("a1", "Enemy", "Melee"), fighter("a2", "Enemy", "Melee")
		local back1 = fighter("bb", "Enemy", "Melee")
		back1.Flags.StunImmune = true
		local s = Simulation.new({ Party = { caster }, Enemies = { a1, a2, back1 }, Seed = 1, MaxSeconds = 5, AbilityDefs = { [def.Id] = def }, CastTimes = false })
		s:Step()
		s:Step()
		return a1.Health < a1.Stats.MaxHealth, a2.Health < a2.Stats.MaxHealth, back1.Health < back1.Stats.MaxHealth
	end
	local f1, f2hit, bk = aoe(volley)
	check("an area attack hits everyone in the target's row", f1 and f2hit)
	check("an area attack leaves the other row alone", not bk)
	local p1, p2, pb = aoe(pierce)
	check("an AllRows skill hits every row", p1 and p2 and pb)

	-- Haste shortens cooldowns
	local function cooldownAfterCast(haste)
		local caster = fighter("c", "Party", "Melee", { { Id = "TestCd", Level = 1 } }, { })
		caster.Stats.Haste = haste
		local enemy = fighter("e", "Enemy", "Melee")
		local def = { Id = "TestCd", DisplayName = "t", Cooldown = 10, Effects = { { Type = "Damage", Target = "Primary", Multiplier = 1 } } }
		local s = Simulation.new({ Party = { caster }, Enemies = { enemy }, Seed = 1, MaxSeconds = 5, AbilityDefs = { TestCd = def }, CastTimes = false })
		s:Step()
		return caster.Abilities[1].Timer
	end
	check("Haste shortens a cooldown", cooldownAfterCast(0.25) < cooldownAfterCast(0) - 1.5)
	check("Haste is capped", cooldownAfterCast(5) >= 10 / (1 + Simulation.MAX_HASTE) - 0.5)

	-- Cleanse
	local priest = fighter("p", "Party", "Ranged", { { Id = "Purify", Level = 1 } })
	local ally = fighter("a", "Party", "Melee")
	local foe = fighter("f", "Enemy", "Melee")
	local cs = Simulation.new({ Party = { priest, ally }, Enemies = { foe }, Seed = 1, MaxSeconds = 30, CastTimes = false })
	cs:ApplyStatus(ally, "Bleeding", 30, foe, nil, 1, 1)
	cs:ApplyStatus(ally, "Cursed", 30, foe)
	local hadBuff = cs:ApplyStatus(ally, "Fortified", 30, foe)
	for _ = 1, 5 do cs:Step() end
	local left = {}
	for _, s in ipairs(ally.Statuses) do left[s.Id] = true end
	check("Purify removes harmful statuses", not left.Bleeding and not left.Cursed)
	check("Purify keeps helpful statuses", left.Fortified or hadBuff == nil)

	-- combo layers (2026-11-19): a finisher deals more per layer of its class mark and uses the layers up
	local function finisherHit(layers)
		local rogue = fighter("rg", "Party", "Melee", { { Id = "Eviscerate", Level = 1 } })
		local dummy = fighter("dm", "Enemy", "Melee")
		local fs = Simulation.new({ Party = { rogue }, Enemies = { dummy }, Seed = 1, MaxSeconds = 5, CastTimes = false })
		if layers > 0 then fs:ApplyStatus(dummy, "Opened", 30, rogue, nil, 1, layers) end
		local before = dummy.Health
		fs:Step()
		local still = false
		for _, st in ipairs(dummy.Statuses) do if st.Id == "Opened" then still = true end end
		return before - dummy.Health, still
	end
	local plain = finisherHit(0)
	local combo, kept = finisherHit(3)
	check("a finisher hits harder with combo layers (3 layers x30% = x1.9)", combo > plain * 1.8 and combo < plain * 2.0)
	check("a finisher uses its combo layers up", not kept)
	local stacked = fighter("st", "Enemy", "Melee")
	local ls = Simulation.new({ Party = { fighter("x1", "Party", "Melee") }, Enemies = { stacked }, Seed = 1, MaxSeconds = 5, CastTimes = false })
	for _ = 1, 9 do ls:ApplyStatus(stacked, "Opened", 30, nil, nil, 1, 1) end
	check("combo layers stop at 5", stacked.Statuses[1].Stacks == 5)

	-- team aura: a tank, a healer and two damage heroes lift everyone's stats
	local function team(classes)
		local list = {}
		for i, c in ipairs(classes) do list[i] = fighter("h" .. i, "Party", "Melee", {}, { DefId = c }) end
		local ts = Simulation.new({ Party = list, Enemies = { fighter("e", "Enemy", "Melee") }, Seed = 1, MaxSeconds = 5, CastTimes = false })
		return ts, list[1]
	end
	local full, hero = team({ "Warrior", "Cleric", "Mage", "Rogue" })
	check("a full team gets the team aura", full.TeamAura == true and hero.Stats.Attack > 100 and hero.Health == hero.Stats.MaxHealth)
	local noHealer = team({ "Warrior", "Ranger", "Mage", "Rogue" })
	check("no healer, no team aura", noHealer.TeamAura == nil)

	-- hard crowd control is for bosses only
	local hardCC = { Stunned = true, Frozen = true }
	local smallOk = true
	for id, def in pairs(m.Enemies) do
		if not def.IsBoss then
			for _, slot in ipairs(def.Abilities or {}) do
				for _, effect in ipairs(m.Abilities[slot.Id].Effects) do
					if effect.Type == "ApplyStatus" and hardCC[effect.Status] then
						smallOk = false
					end
				end
			end
		end
	end
	check("no regular monster uses a stun", smallOk)
	local bossStun = false
	for _, def in pairs(m.Enemies) do
		if def.IsBoss then
			for _, slot in ipairs(def.Abilities or {}) do
				if slot.Id == "Stagger" then bossStun = true end
			end
		end
	end
	check("some bosses stun", bossStun)

	-- gear rolls vary
	local lo, hi = 10, 0
	local n = 0
	local seed = 5
	local function rnd() seed = (seed * 16807) % 2147483647 return seed / 2147483647 end
	for _ = 1, 600 do
		local d = m.Gear.RollDrop(10, true, 0, rnd)
		if d and d.Roll then
			n += 1
			lo, hi = math.min(lo, d.Roll), math.max(hi, d.Roll)
		end
	end
	check("gear drops roll a stat multiplier", n > 20 and lo >= m.GearConfig.Roll.Min - 1e-9 and hi <= m.GearConfig.Roll.Max + 1e-9 and hi - lo > 0.1)
	local a = { Slot = "Weapon", Rarity = "Rare", Power = 10, Roll = 1.15 }
	local b = { Slot = "Weapon", Rarity = "Rare", Power = 10, Roll = 0.85 }
	local _, va = m.Gear.StatOf(a)
	local _, vb = m.Gear.StatOf(b)
	check("a better roll gives a stronger item", va > vb and m.Gear.ItemPower(a) > m.Gear.ItemPower(b))

	print(("RowTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
