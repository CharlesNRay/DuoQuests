--[[
	Stages (ModuleScript)
	Location: ReplicatedStorage > Shared > Stages

	Describes what a stage contains. Pure and deterministic: the same stage
	number always gives the same enemies, so the server never stores it and the
	party and ghost partner always agree on it.

	  Stages.IsBoss(stage)        true on every BossEvery-th stage
	  Stages.TimeLimit(stage)     seconds allowed to clear the stage
	  Stages.Scale(stage)         enemy health/attack multiplier
	  Stages.Build(stage)         -> { Stage, IsBoss, Scale, Enemies = { {Id, EnemyId, Scale} } }
	  Stages.NewEnemies(stage)    -> enemy combatants ready for Simulation
]]

local Config = require(script.Parent.Config.Stages)
local StatCalc = require(script.Parent.Combat.StatCalc)

local Stages = {}

function Stages.IsBoss(stage)
	return stage % Config.BossEvery == 0
end

-- Seconds the party has to win. Running out of time is a loss, so a fight can
-- never be stalled out (for example a healer outhealing a weak enemy forever).
function Stages.TimeLimit(stage)
	return if Stages.IsBoss(stage) then Config.BossTimeLimit else Config.TimeLimit
end

function Stages.Scale(stage)
	local scale = 1 + Config.ScalePerStage * (stage - 1) ^ Config.ScalePower
	for _, tier in ipairs(Config.Tiers or {}) do
		if stage >= tier.From then
			scale *= tier.Mult
		end
	end
	return scale
end

function Stages.Build(stage)
	assert(type(stage) == "number" and stage >= 1 and stage == math.floor(stage), "Stage must be a whole number >= 1")
	local scale = Stages.Scale(stage)
	local enemies = {}

	if Stages.IsBoss(stage) then
		local bossNumber = stage // Config.BossEvery
		local enemyId = Config.BossPool[(bossNumber - 1) % #Config.BossPool + 1]
		table.insert(enemies, { Id = "e1", EnemyId = enemyId, Scale = scale * (Config.BossScaleMult or 1) })
	else
		local count = math.min(Config.MaxEnemies, 1 + (stage - 1) // 2)
		for index = 1, count do
			local enemyId = Config.EnemyPool[(stage + index) % #Config.EnemyPool + 1]
			table.insert(enemies, { Id = "e" .. index, EnemyId = enemyId, Scale = scale })
		end
	end

	return { Stage = stage, IsBoss = Stages.IsBoss(stage), Scale = scale, Enemies = enemies }
end

function Stages.NewEnemies(stage)
	local built = Stages.Build(stage)
	local enemies = {}
	for _, entry in ipairs(built.Enemies) do
		table.insert(enemies, StatCalc.NewEnemy(entry.Id, entry.EnemyId, entry.Scale))
	end
	return enemies
end

return Stages
