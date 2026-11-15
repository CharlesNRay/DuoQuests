--[[
	Economy (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Economy

	Every progression and spending number in one place. PLACEHOLDERS: the
	pacing goal is that a normal player owns every skill for their class after
	about a week, with slot levels nowhere near max.
]]

return {
	-- Player level --------------------------------------------------------
	MaxLevel = 50,
	XPBase = 50, -- XP needed to go from level 1 to 2
	XPPerLevel = 25, -- each later level needs this much more

	-- Stage clear rewards (earned at the frontier) --------------------------
	RewardScale = 0.1, -- one dial that scales gold and XP income (shards have their own numbers below)
	GoldBase = 10,
	GoldPerStage = 4,
	XPRewardBase = 10,
	XPRewardPerStage = 3,
	ShardsPerClear = 1, -- plus one extra per ShardStageStep stages
	ShardStageStep = 10,
	BossShardBonus = 5, -- extra shards for clearing a boss stage

	-- Replaying a stage you already cleared pays this fraction, so the
	-- frontier is always the best place to be (no farming old content).
	ReplayFactor = 0.5,

	-- Boss stages (every BossEvery) grant this many free skill picks the FIRST
	-- time the player clears them.
	MilestoneSkillPicks = 1,

	-- Unlocking skills (Skill Shards) ------------------------------------------
	UnlockCost = { Common = 180, Rare = 360, Epic = 630 },

	-- Levelling a slot (Gold): cost to go from level L to L+1 is SlotCostPerLevel * L
	SlotCostPerLevel = 90,

	-- Levelling a passive slot (Gold): cost to go from level L to L+1 is
	-- PassiveCostPerLevel * L. Passives are unlocked by reaching stages.
	PassiveCostPerLevel = 110,
}
