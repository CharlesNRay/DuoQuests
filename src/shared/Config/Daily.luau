--[[
	Daily (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Daily

	Daily login rewards: a 7 day cycle. Missing a day restarts the cycle at day 1.
	Every reward is a flat number (owner 2026-11-26: the daily gift does not scale with progress):

	  Gold         gold
	  Shards       Skill Shards
	  Wishstones   Wishing Tree currency
	  SkillPicks   free skill unlocks
	  Pet          true: a free pet level for your equipped pet (up to the cap)

]]

return {
	CycleLength = 7,
	Days = {
		{ Gold = 10000, Shards = 2, Wishstones = 2 },
		{ Gold = 12000, Shards = 2, Wishstones = 2 },
		{ Gold = 15000, Shards = 3, Wishstones = 3 },
		{ Gold = 18000, Shards = 3, Wishstones = 3 },
		{ Gold = 21000, Shards = 4, Wishstones = 4 },
		{ Gold = 25000, Shards = 4, Wishstones = 4 },
		{ Gold = 40000, Shards = 8, SkillPicks = 1, Wishstones = 10 },
	},
}
