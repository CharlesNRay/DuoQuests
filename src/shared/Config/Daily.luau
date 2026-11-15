--[[
	Daily (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Daily

	Daily login rewards: a 7 day cycle. Missing a day restarts the cycle at day 1.
	Rewards are expressed so they scale with progress instead of being fixed numbers:

	  GoldClears   gold equal to this many frontier clears at your current frontier
	  Shards       Skill Shards (flat, shards have their own pacing)
	  Wishstones   Wishing Tree currency
	  SkillPicks   free skill unlocks
	  Pet          true: a free pet level for your equipped pet (up to the cap)

	Placeholders: tune once the pacing pass settles income.
]]

return {
	CycleLength = 7,
	Days = {
		{ GoldClears = 8, Shards = 2, Wishstones = 2 },
		{ GoldClears = 10, Shards = 2, Wishstones = 2 },
		{ GoldClears = 12, Shards = 3, Wishstones = 3 },
		{ GoldClears = 14, Shards = 3, Wishstones = 3 },
		{ GoldClears = 16, Shards = 4, Wishstones = 4 },
		{ GoldClears = 18, Shards = 4, Wishstones = 4 },
		{ GoldClears = 25, Shards = 8, SkillPicks = 1, Wishstones = 10 },
	},
}
