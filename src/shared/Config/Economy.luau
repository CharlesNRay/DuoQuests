--[[
	Economy (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Economy

	Every progression and spending number in one place. PLACEHOLDERS: the
	pacing goal is that a normal player owns every skill for their class after
	about a week, with slot levels nowhere near max.
]]

return {
	-- Player level --------------------------------------------------------
	MaxLevel = 120,
	XPBase = 50, -- XP needed to go from level 1 to 2
	XPPerLevel = 25, -- each later level needs this much more
	-- Past the level cap, XP fills Paragon levels (Season.Paragon): each is a small permanent bonus to Attack, Health and Defense for the season.
	Paragon = { Max = 100, XPFactor = 3, PerLevel = 0.004 },

	-- Stage clear rewards (earned at the frontier) --------------------------
	RewardScale = 0.1, -- one dial that scales gold and XP income (shards have their own numbers below)
	GoldBase = 10,
	GoldPerStage = 4,
	XPScale = 0.9, -- multiplies XP only (the level pacing dial): lv10 ~12 min, lv20 ~27 min, lv30 ~1 h
	XPRewardBase = 10,
	XPRewardPerStage = 3,
	PetXPPerClear = 12, -- XP the active pet earns from every won fight
	ShardsPerClear = 1, -- plus one extra per ShardStageStep stages
	ShardStageStep = 10,
	BossShardBonus = 5, -- extra shards for clearing a boss stage

	-- Wishstones: the one currency for the Wishing Tree (pet and skill wishes). Every first (frontier) clear pays
	-- WishstonesFrontier, boss stages add WishstonesBoss, and every WishstonesReplayEvery-th replay pays one.
	WishstonesFrontier = 2,
	WishstonesBoss = 4,
	WishstonesReplayEvery = 4,

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
