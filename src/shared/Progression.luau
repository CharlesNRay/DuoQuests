--[[
	Progression (ModuleScript)
	Location: ReplicatedStorage > Shared > Progression

	XP, levels and stage-clear rewards. Pure functions on a profile table.
	The server calls ApplyClear exactly once per won fight.

	Season.HighestStage is the FRONTIER: the furthest stage the player has
	unlocked (it starts at 1). Clearing the frontier stage pays full rewards and
	moves it up by one. Replaying an older stage pays Economy.ReplayFactor of the
	rewards, so pushing forward is always the best thing to do.

	The first clear of each boss stage grants a free skill pick, guarded by the
	Season.StageRewardsClaimed ledger so it can never be paid twice.

	  Progression.XPToNext(level)
	  Progression.AddXP(season, amount)            -> levels gained
	  Progression.ClearRewards(stage, isFrontier, bonuses)  -> { Gold, XP, Shards }
	      bonuses is optional { GoldGain, XPGain } (fractions from passives);
	      shards are not affected
	  Progression.ApplyClear(profile, stage)       -> summary table
]]

local Economy = require(script.Parent.Config.Economy)
local Stages = require(script.Parent.Stages)
local Passives = require(script.Parent.Passives)
local Pets = require(script.Parent.Pets)

local Progression = {}

function Progression.XPToNext(level)
	return Economy.XPBase + Economy.XPPerLevel * (level - 1)
end

function Progression.AddXP(season, amount)
	local gained = 0
	if season.Level >= Economy.MaxLevel then
		season.XP = 0
		return 0
	end
	season.XP += amount
	while season.Level < Economy.MaxLevel and season.XP >= Progression.XPToNext(season.Level) do
		season.XP -= Progression.XPToNext(season.Level)
		season.Level += 1
		gained += 1
	end
	if season.Level >= Economy.MaxLevel then
		season.XP = 0
	end
	return gained
end

function Progression.ClearRewards(stage, isFrontier, bonuses)
	local goldFactor = 1 + (if bonuses then bonuses.GoldGain or 0 else 0)
	local xpFactor = 1 + (if bonuses then bonuses.XPGain or 0 else 0)
	local replay = if isFrontier then 1 else Economy.ReplayFactor
	local factor = Economy.RewardScale * replay -- gold and XP
	local shards = Economy.ShardsPerClear + stage // Economy.ShardStageStep
	if Stages.IsBoss(stage) then
		shards += Economy.BossShardBonus
	end
	return {
		Gold = math.max(1, math.floor((Economy.GoldBase + Economy.GoldPerStage * stage) * factor * goldFactor)),
		XP = math.max(1, math.floor((Economy.XPRewardBase + Economy.XPRewardPerStage * stage) * factor * xpFactor)),
		Shards = math.max(1, math.floor(shards * replay)), -- shards ignore RewardScale: unlock costs are tuned for them
	}
end

function Progression.ApplyClear(profile, stage)
	local season = profile.Season
	local isFrontier = stage >= season.HighestStage
	local classId = season.ClassId
	local bonuses = Passives.Rewards(classId, season.PassiveLoadouts[classId], season.PassiveSlotLevels[classId])
	local rewards = Progression.ClearRewards(stage, isFrontier, bonuses)

	season.Currencies.Gold += rewards.Gold
	season.Currencies.Shards += rewards.Shards
	local levelsGained = Progression.AddXP(season, rewards.XP)

	local skillPicks = 0
	if Stages.IsBoss(stage) and not season.StageRewardsClaimed[stage] then
		season.StageRewardsClaimed[stage] = true
		skillPicks = Economy.MilestoneSkillPicks
		season.Currencies.SkillPicks += skillPicks
	end

	local petsGained = Pets.GrantForClear(profile, stage)

	if isFrontier then
		season.HighestStage = stage + 1
	end

	return {
		Stage = stage,
		FrontierClear = isFrontier,
		Gold = rewards.Gold,
		XP = rewards.XP,
		Shards = rewards.Shards,
		SkillPicks = skillPicks,
		PetsGained = petsGained,
		LevelsGained = levelsGained,
		Level = season.Level,
	}
end

return Progression
