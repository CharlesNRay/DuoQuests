--[[
	SummonerTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > SummonerTests

	The Summoner pays health to raise minions that fight, take hits and die; it recovers health through drain, devouring minions,
	ghoul leech and Vampirism.   require(...SummonerTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Abilities = require(Shared.Config.Abilities), Minions = require(Shared.Config.Minions), Simulation = require(Shared.Combat.Simulation),
			StatCalc = require(Shared.Combat.StatCalc), Classes = require(Shared.Config.Classes), PassiveConfig = require(Shared.Config.Passives),
		}
	end
	local Abilities, Minions, Simulation, StatCalc = m.Abilities, m.Minions, m.Simulation, m.StatCalc
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

	-- a summoner who only casts `skills`, against a dummy that hits back
	local function fight(skills, setup, seconds)
		local hero = StatCalc.NewPartyMember("h", "Summoner", "Summoner", 10, {})
		hero.Abilities = {}
		for _, id in ipairs(skills) do
			table.insert(hero.Abilities, { Id = id, Level = 1, Timer = 0, Uses = 0 })
		end
		local foe = StatCalc.NewEnemy("e", "Slime", 1)
		foe.Stats.MaxHealth, foe.Health = 100000, 100000
		foe.Stats.Attack = 12
		if setup then
			setup(hero, foe)
		end
		local sim = Simulation.new({ Party = { hero }, Enemies = { foe }, Seed = 5, MaxSeconds = seconds or 30 })
		for _ = 1, (seconds or 30) * 10 do
			sim:Step()
		end
		return sim, hero, foe
	end
	local function count(sim, kind, test)
		local n = 0
		for _, e in ipairs(sim.Events) do
			if e.Type == kind and (test == nil or test(e)) then
				n += 1
			end
		end
		return n
	end

	-- data
	for id, def in pairs(Minions) do
		local ok = def.HealthFrac > 0 and def.AttackFrac > 0 and def.AttackSpeed > 0 and def.Look ~= nil
		for _, slot in ipairs(def.Abilities or {}) do
			ok = ok and Abilities[slot.Id] ~= nil
		end
		check("Minion " .. id .. " is complete", ok)
	end
	for _, id in ipairs({ "SummonImp", "RaiseSkeleton", "WraithSwarm", "CallTitan", "RaiseDead", "GuardianSpirit" }) do
		local raises = false
		for _, effect in ipairs(Abilities[id].Effects) do
			raises = raises or (effect.Type == "Raise" and Minions[effect.MinionId] ~= nil)
		end
		check(id .. " raises a real minion", raises)
	end

	-- summoning costs health and a minion joins the party
	local sim, hero = fight({ "SummonImp" }, function(h, foe)
		foe.Stats.Attack = 0
	end, 2)
	local spawns = count(sim, "Spawn", function(e) return e.Entity.Team == "Party" and e.Entity.DefId == "Imp" end)
	check("Summon Imp raises an imp on the party's side", spawns >= 1)
	check("It cost the summoner health", count(sim, "Damage", function(e) return e.Sacrifice == true and e.Target == "h" end) >= 1)
	local imp = nil
	for _, e in ipairs(sim.Party) do
		if e.Minion then
			imp = e
		end
	end
	check("The imp belongs to the summoner and is a fighter", imp ~= nil and imp.OwnerId == "h" and imp.Stats.Attack > 0 and imp.Stats.MaxHealth > 0)

	-- the cap holds
	sim = fight({ "SummonImp" }, function(h, foe)
		foe.Stats.Attack = 0
	end, 40)
	local alive = 0
	for _, e in ipairs(sim.Party) do
		if e.Minion and e.Alive then
			alive += 1
		end
	end
	check("No more than 3 imps at once", alive == 3)

	-- it never kills its own summoner
	sim, hero = fight({ "SummonImp", "RaiseSkeleton", "WraithSwarm", "CallTitan" }, function(h, foe)
		foe.Stats.Attack = 0
		h.Stats.AttackSpeed = 0.0001
	end, 60)
	check("Paying for minions never kills the summoner", hero.Health >= 1 and hero.Alive)

	-- minions can be hit and die; enemies go for them
	sim = fight({ "RaiseSkeleton", "SummonImp" }, function(h, foe)
		foe.Stats.Attack = 60
		foe.Stats.AttackSpeed = 2
	end, 20)
	check("Enemies hit minions", count(sim, "Damage", function(e) return e.Target:sub(1, 1) == "m" end) > 0)
	check("Minions can die", count(sim, "Death", function(e) return e.Target:sub(1, 1) == "m" end) > 0)

	-- a taunting skeleton draws every attack while it stands
	sim = fight({ "RaiseSkeleton" }, function(h, foe)
		foe.Stats.Attack = 5
		h.Stats.AttackSpeed = 0.0001
	end, 6)
	local skeletonHits, summonerHits = 0, 0
	local skeletonUp = false
	for _, e in ipairs(sim.Events) do
		if e.Type == "Status" and e.Status == "Taunting" then
			skeletonUp = true
		elseif e.Type == "Damage" and e.Source == "e" and skeletonUp then
			if e.Target == "h" then
				summonerHits += 1
			else
				skeletonHits += 1
			end
		end
	end
	check("A skeleton taunts: enemies hit it, not the summoner", skeletonUp and skeletonHits > 0 and summonerHits == 0)

	-- minions die with their summoner, and do not keep the party alive
	do
		local h = StatCalc.NewPartyMember("h", "Summoner", "Summoner", 5, {})
		h.Abilities = { { Id = "SummonImp", Level = 1, Timer = 0, Uses = 0 } }
		local foe = StatCalc.NewEnemy("e", "Slime", 1)
		foe.Stats.MaxHealth, foe.Health, foe.Stats.Attack = 100000, 100000, 0
		local s = Simulation.new({ Party = { h }, Enemies = { foe }, Seed = 2, MaxSeconds = 30 })
		for _ = 1, 30 do
			s:Step()
		end
		h.Health = 0
		s:Step()
		local anyMinion = false
		for _, e in ipairs(s.Party) do
			anyMinion = anyMinion or (e.Minion and e.Alive)
		end
		check("Minions fall when their summoner does", not anyMinion)
		check("A wiped party loses even with minions out", s.Result ~= nil and s.Result.Winner == "Enemy" and #s.Result.Survivors == 0)
	end

	-- recovery -----------------------------------------------------------------------------------------
	-- devour
	sim, hero = fight({ "SummonImp", "Devour" }, function(h, foe)
		foe.Stats.Attack = 0
		h.Stats.AttackSpeed = 0.0001
		h.Health = math.floor(h.Stats.MaxHealth * 0.5)
	end, 40)
	local devoured = count(sim, "Damage", function(e) return e.Devoured == true end)
	local devourHeals = count(sim, "Heal", function(e) return e.Tag == "Devour" and e.Amount > 0 end)
	check("Devour consumes a minion", devoured >= 1)
	check("Devour heals the summoner", devourHeals >= 1)

	-- ghouls feed life back
	sim = fight({ "RaiseDead" }, function(h, foe)
		foe.Stats.Attack = 0
		h.Stats.AttackSpeed = 0.0001
	end, 20)
	check("Ghouls leech life back to the summoner", count(sim, "Heal", function(e) return e.Tag == "Lifesteal" and e.Target == "h" and e.Source:sub(1, 1) == "m" end) > 0)

	-- vampirism passive
	local plain = StatCalc.NewPartyMember("p", "S", "Summoner", 10, {})
	local vamp = StatCalc.NewPartyMember("v", "S", "Summoner", 10, { PassiveIds = { "Vampirism" } })
	check("Vampirism gives the summoner lifesteal", (vamp.Stats.Lifesteal or 0) > (plain.Stats.Lifesteal or 0))
	sim = fight({}, function(h, foe)
		h.Stats.Lifesteal = 0.5
		h.Health = 10
		foe.Stats.Attack = 0
	end, 10)
	check("Lifesteal heals on a basic attack", count(sim, "Heal", function(e) return e.Tag == "Lifesteal" and e.Target == "h" end) > 0)

	-- Necromancer is stronger with minions
	local necro = StatCalc.NewPartyMember("n", "S", "Summoner", 30, { SubclassId = "Necromancer" })
	local base = StatCalc.NewPartyMember("b", "S", "Summoner", 30, {})
	check("Necromancer has stronger minions and lifesteal", (necro.Stats.MinionPower or 0) > 0 and (necro.Stats.Lifesteal or 0) > 0 and (base.Stats.MinionPower or 0) == 0)

	-- spirit guardian heals allies by itself
	sim, hero = fight({ "GuardianSpirit" }, function(h, foe)
		foe.Stats.Attack = 90
		foe.Stats.AttackSpeed = 1
		h.Stats.AttackSpeed = 0.0001
	end, 15)
	check("A guardian spirit casts Spirit Mend on its own", count(sim, "Cast", function(e) return e.Ability == "Minion_SpiritMend" end) > 0)

	print(("SummonerTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
