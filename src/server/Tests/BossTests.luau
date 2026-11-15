--[[
	BossTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > BossTests

	In Studio's Command Bar:  require(game.ServerScriptService.Server.Tests.BossTests)()

	Boss mechanics: scheduled attacks, telegraphs, summons, enrage.
]]

return function(modulesOverride)
	local Shared = (not modulesOverride) and game:GetService("ReplicatedStorage"):WaitForChild("Shared") or nil
	local m = modulesOverride or {
		Simulation = require(Shared.Combat.Simulation),
		StatCalc = require(Shared.Combat.StatCalc),
		Stages = require(Shared.Stages),
		StageRunner = require(Shared.StageRunner),
		Entity = require(Shared.Combat.Entity),
		Enemies = require(Shared.Config.Enemies),
	}
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, ok)
		if ok then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	local function tank(hp)
		return m.Entity.new({ Id = "hero", Team = "Party", Stats = { MaxHealth = hp, Attack = 1, Defense = 0, AttackSpeed = 0.5 } })
	end
	local function fightBoss(enemyId, seconds, hp, partySize)
		local party = { tank(hp or 1e6) }
		for i = 2, partySize or 1 do
			table.insert(party, m.Entity.new({ Id = "h" .. i, Team = "Party", Stats = { MaxHealth = hp or 1e6, Attack = 1, Defense = 0, AttackSpeed = 0.5 } }))
		end
		local sim = m.Simulation.new({
			Party = party,
			Enemies = { m.StatCalc.NewEnemy("e1", enemyId, 1) },
			Seed = 3,
			MaxSeconds = seconds,
			SpawnEnemy = m.StatCalc.NewEnemy,
		})
		sim:Run()
		return sim
	end
	local function eventsOf(sim, kind)
		local list = {}
		for _, e in ipairs(sim.Events) do
			if e.Type == kind then
				table.insert(list, e)
			end
		end
		return list
	end

	print("Running BossTests...")

	-- stage layout
	check("Floors 10, 20, 30 are different bosses", (function()
		local ids = {}
		for _, stage in ipairs({ 10, 20, 30 }) do
			ids[m.Stages.Build(stage).Enemies[1].EnemyId] = true
		end
		return ids.SlimeKing and ids.GoblinWarlord and ids.SporeMother
	end)())
	check("Minions never show up as regular enemies", (function()
		for stage = 1, 200 do
			for _, entry in ipairs(m.Stages.Build(stage).Enemies) do
				if m.Enemies[entry.EnemyId].IsMinion then
					return false
				end
			end
		end
		return true
	end)())

	-- scheduled heavy hit
	local sim = fightBoss("GoblinWarlord", 40)
	local casts = {}
	for _, e in ipairs(eventsOf(sim, "Cast")) do
		if e.Ability == "CrushingBlow" then
			table.insert(casts, e.T)
		end
	end
	check("Crushing Blow lands at 8s then every 11s", #casts >= 3 and math.abs(casts[1] - 8) < 0.15 and math.abs(casts[2] - casts[1] - 11) < 0.15)
	local warns = eventsOf(sim, "Telegraph")
	check("Each blow is telegraphed 1.5s early", #warns >= 3 and math.abs(warns[1].T - 6.5) < 0.25 and warns[1].Ability == "CrushingBlow")
	local heavy = 0
	for _, e in ipairs(eventsOf(sim, "Damage")) do
		if e.Tag == "CrushingBlow" then
			heavy = e.Amount
			break
		end
	end
	check("The blow hits far harder than a normal attack", heavy >= 3 * 12 - 1)

	-- summons
	local slime = fightBoss("SlimeKing", 30)
	local spawns = eventsOf(slime, "Spawn")
	check("Slime King summons slimelets", #spawns >= 2 and spawns[1].Entity.DefId == "Slimelet" and math.abs(spawns[1].T - 5) < 0.25)
	check("Summons are real enemies that fight", #slime.Enemies > 1 and slime.Enemies[2].Team == "Enemy")
	local capped = fightBoss("SlimeKing", 160)
	local living = 0
	for _, enemy in ipairs(capped.Enemies) do
		if enemy.Alive then
			living += 1
		end
	end
	check("Summons are capped so a long fight cannot flood", living <= 7)

	-- enrage
	local enrageSim = m.Simulation.new({
		Party = { tank(1e6) },
		Enemies = { m.StatCalc.NewEnemy("e1", "GoblinWarlord", 1) },
		Seed = 1,
		MaxSeconds = 30,
		SpawnEnemy = m.StatCalc.NewEnemy,
	})
	enrageSim.Enemies[1].Health = enrageSim.Enemies[1].Stats.MaxHealth * 0.4
	enrageSim:Run()
	check("A boss below half health enrages (once)", #eventsOf(enrageSim, "Status") >= 1 and enrageSim:HasStatus(enrageSim.Enemies[1], "Enraged"))

	print(("BossTests done: %d passed, %d failed"):format(passed, failed))
end
