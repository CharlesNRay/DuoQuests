--[[
	Offline (ModuleScript)
	Location: ReplicatedStorage > Shared > Offline

	Estimates what a party would have earned while both players were away.
	Pure Luau. Nothing here changes a profile: Party.Claim applies the result.

	  Offline.EffectiveSeconds(elapsed)
	      Time away converted to "full rate" seconds using the reduced tiers
	      (12 h away = 6 h of full-rate farming at the default tiers).

	  Offline.FindFarmStage(members, startStage)
	      Walks down from startStage until the party can win. Returns the stage
	      and how long that fight took. "The party stays on whatever stage it can
	      clear."

	  Offline.Estimate(members, startStage, elapsed)
	      -> nil if the gap is too short, otherwise
	      { Stage, FightSeconds, Fights, EffectiveSeconds, Rewards = { [memberId] = { Gold, XP, Shards } } }

	members use the same shape as StageRunner: { Id, Name, Snapshot = {...} }.
	Rewards are an estimate of the clears the party would have made at the farm
	stage, paid per member using that member's own frontier (a stage behind
	their frontier pays the reduced replay rate).
]]

local Config = require(script.Parent.Config.Offline)
local Progression = require(script.Parent.Progression)
local Simulation = require(script.Parent.Combat.Simulation)
local StageRunner = require(script.Parent.StageRunner)
local Stages = require(script.Parent.Stages)

local Offline = {}

function Offline.EffectiveSeconds(elapsed)
	local total, previousEnd = 0, 0
	for _, tier in ipairs(Config.Tiers) do
		if elapsed <= previousEnd then
			break
		end
		local span = math.min(elapsed, tier.Until) - previousEnd
		total += span * tier.Rate
		previousEnd = tier.Until
	end
	return total
end

function Offline.FindFarmStage(members, startStage)
	for stage = math.max(1, startStage), 1, -1 do
		local sim = Simulation.new({
			Party = StageRunner.NewParty(members),
			Enemies = Stages.NewEnemies(stage),
			Seed = Config.ProbeSeed + stage,
			MaxSeconds = Stages.TimeLimit(stage),
			RecordEvents = false,
		})
		local result = sim:Run()
		if result.Winner == "Party" then
			return stage, math.max(1, result.Duration)
		end
	end
	-- Even stage 1 is a loss: stay on stage 1 with a slow, safe estimate.
	return 1, 60
end

function Offline.Estimate(members, startStage, elapsed)
	if elapsed < Config.MinAwaySeconds then
		return nil
	end

	local stage, fightSeconds = Offline.FindFarmStage(members, startStage)
	local effective = Offline.EffectiveSeconds(elapsed)
	local fights = effective / (fightSeconds + Config.Intermission)

	local rewards = {}
	for _, member in ipairs(members) do
		local frontier = member.Snapshot.Frontier or 1
		local perClear = Progression.ClearRewards(stage, stage >= frontier)
		rewards[member.Id] = {
			Gold = math.floor(perClear.Gold * fights),
			XP = math.floor(perClear.XP * fights),
			Shards = math.floor(perClear.Shards * fights),
		}
	end

	return {
		Stage = stage,
		FightSeconds = fightSeconds,
		Fights = fights,
		EffectiveSeconds = effective,
		Rewards = rewards,
	}
end

return Offline
