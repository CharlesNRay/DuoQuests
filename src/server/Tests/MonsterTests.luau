--[[
	MonsterTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > MonsterTests

	Zone monster pools, bosses and monster skills all exist and every stage up to 500 can be built and fought.   require(...MonsterTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Enemies = require(Shared.Config.Enemies), Abilities = require(Shared.Config.Abilities), StageConfig = require(Shared.Config.Stages),
			Stages = require(Shared.Stages), StageRunner = require(Shared.StageRunner), ProfileTemplate = require(Shared.ProfileTemplate),
		}
	end
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			(warn or print)("  FAIL  " .. name)
		end
	end

	local SHAPES = { Ball = true, Biped = true, Mushroom = true, Beast = true, Bat = true, Spider = true, Skeleton = true, Elemental = true, Golem = true, Frog = true, Scorpion = true, Crab = true, Wraith = true, Bird = true, Serpent = true }
	local shapesOk, abilitiesOk, statsOk = true, true, true
	for id, def in pairs(m.Enemies) do
		if not SHAPES[def.Look.Shape] then
			shapesOk = false
		end
		for _, slot in ipairs(def.Abilities or {}) do
			local ability = m.Abilities[slot.Id]
			if not (ability and ability.Enemy) then
				abilitiesOk = false
			end
		end
		if not (def.BaseStats.MaxHealth > 0 and def.BaseStats.AttackSpeed > 0) then
			statsOk = false
		end
	end
	check("Every monster uses a body shape the client can build", shapesOk)
	check("Every monster skill exists and is marked as an enemy skill", abilitiesOk)
	check("Monster stats are sane", statsOk)

	local poolsOk = true
	for _, pool in ipairs(m.StageConfig.ZonePools) do
		for _, id in ipairs(pool) do
			if not m.Enemies[id] or m.Enemies[id].IsBoss then
				poolsOk = false
			end
		end
	end
	for _, id in ipairs(m.StageConfig.BossPool) do
		if not (m.Enemies[id] and m.Enemies[id].IsBoss) then
			poolsOk = false
		end
	end
	check("Zone pools list regular monsters and the boss pool lists bosses", poolsOk)

	local seen, built = {}, true
	for stage = 1, 500 do
		local ok, result = pcall(m.Stages.Build, stage)
		if not ok then
			built = false
			break
		end
		for _, e in ipairs(result.Enemies) do
			seen[e.EnemyId] = true
		end
	end
	check("Every stage from 1 to 500 builds", built)
	local count = 0
	for _ in pairs(seen) do
		count += 1
	end
	check("Stages 1-500 field at least 25 different monsters", count >= 25)

	-- fight a stage from each zone with a small party: it must run without errors
	local fights = true
	for zone = 1, 10 do
		local stage = (zone - 1) * 10 + 3
		local members = { { Id = "1", Name = "W", Profile = m.ProfileTemplate.New() } }
		local ok = pcall(m.StageRunner.Run, members, stage, 5, nil, true)
		if not ok then
			fights = false
		end
	end
	check("A fight in every zone runs", fights)
	print(("MonsterTests done: %d passed, %d failed"):format(passed, failed))
end
