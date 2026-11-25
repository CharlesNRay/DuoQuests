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
local ZoneConfig = require(script.Parent.Config.Zones)
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
	-- past LateGrowth.From every stage is Rate harder on top (compounding). The power curve alone flattens late (stage 150
	-- is only ~1% harder than 149), so any power spike turned into dozens of free stages (BALANCE.md "Late game runaway").
	local late = Config.LateGrowth
	if late and stage > late.From then
		scale *= (1 + late.Rate) ^ (stage - late.From)
	end
	local ease = Config.EarlyEase
	if ease and stage >= ease.From and stage < ease.To then
		local t = (stage - ease.From) / (ease.To - ease.From) -- 0 at From, 1 at To
		scale *= ease.Mult + (1 - ease.Mult) * t
	end
	return scale * (Config.PartyScale or 1)
end

-- Enemy HEALTH can grow on a steeper curve than attack (Config.HealthScalePower). Pairs that never die (a tank and a
-- healer) only race the clock, so health is what slows them; squishy pairs are not crushed by harder hits.
-- Returns the extra health factor on top of Stages.Scale (1 when HealthScalePower is not set).
function Stages.HealthExtra(stage)
	local power = Config.HealthScalePower
	if power == nil or power == Config.ScalePower then
		return 1
	end
	local steps = stage - 1
	return (1 + Config.ScalePerStage * steps ^ power) / (1 + Config.ScalePerStage * steps ^ Config.ScalePower)
end

-- Ordinary (non-boss) enemies get extra health only, so fights last long enough to watch (about 10-16 s) without hitting harder.
-- Both kinds also get Stages.HealthExtra.
function Stages.HealthMult(stage)
	local ramp = Config.NormalHealth
	if not ramp or Stages.IsBoss(stage) then
		return Stages.HealthExtra(stage)
	end
	return (1 + (ramp.Max - 1) * math.clamp((stage - ramp.From) / ramp.Span, 0, 1)) * Stages.HealthExtra(stage)
end

function Stages.Build(stage)
	assert(type(stage) == "number" and stage >= 1 and stage == math.floor(stage), "Stage must be a whole number >= 1")
	local scale = Stages.Scale(stage)
	local enemies = {}

	if Stages.IsBoss(stage) then
		local bossNumber = stage // Config.BossEvery
		local enemyId = Config.BossPool[(bossNumber - 1) % #Config.BossPool + 1]
		-- a zone can name its own boss (Config/Zones Boss: Slime Meadows has the Rainbow Slime)
		local zone = ZoneConfig[(bossNumber - 1) % #ZoneConfig + 1]
		if zone and zone.Boss then
			enemyId = zone.Boss
		end
		table.insert(enemies, { Id = "e1", EnemyId = enemyId, Scale = scale * (Config.BossScaleMult or 1) * (if bossNumber == 1 then Config.FirstBossMult or 1 else 1), HealthMult = Stages.HealthMult(stage) })
	else
		local count = math.min(Config.MaxEnemies, 1 + (stage - 1) // 2)
		for index = 1, count do
			local pool = Config.ZonePools[((stage - 1) // Config.BossEvery) % #Config.ZonePools + 1] or Config.EnemyPool
			local enemyId = pool[(stage + index) % #pool + 1]
			table.insert(enemies, { Id = "e" .. index, EnemyId = enemyId, Scale = scale, HealthMult = Stages.HealthMult(stage) })
		end
	end

	return { Stage = stage, IsBoss = Stages.IsBoss(stage), Scale = scale, Enemies = enemies }
end

function Stages.NewEnemies(stage)
	local built = Stages.Build(stage)
	local enemies = {}
	for _, entry in ipairs(built.Enemies) do
		table.insert(enemies, StatCalc.NewEnemy(entry.Id, entry.EnemyId, entry.Scale, entry.HealthMult))
	end
	return enemies
end

return Stages
