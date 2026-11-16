--[[
	SkillProgress (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > SkillProgress

	How a skill grows. Every owned skill has
	  Tier   its rarity as YOU hold it (Common < Rare < Epic < Legendary). A skill starts at its own base rarity.
	         Pulling a higher-tier copy at the Wishing Tree does NOT change it by itself: it waits as an upgrade the
	         player applies by hand (Skills page > Upgrade).
	  Rank   1..MaxRank, raised by hand with XP. Duplicate copies of a skill turn into XP.

	The skill fights at level  Rank + (TierBonus[Tier] - TierBonus[its base rarity])  (a Common skill held at Legendary
	maxes at 10 + 10 = 20, the old slot-level cap), so each tier above its own is worth several ranks.

	  RankXP[r]   XP to go from rank r to r+1
	  DupXP       XP a spare copy of that rarity gives (any copy that is not an upgrade)

	PACING (placeholder; simulated with Bright-tier skill wishes, a class has ~12 skills incl. its subclass):
	  a Bright wish drops ~23 XP on average, spread over every skill of the class
	  100 wishes -> the best four skills are around level 12-13 (no skill maxed yet)
	  200 wishes -> about 2 skills at max rank, the best four around level 15
	  300 wishes -> about 5 skills at max rank, the best four around level 16
	A full season of play is roughly 250-350 skill wishes (Wishstones from stages, daily quests, the pass and
	the daily login), so an engaged player maxes a few skills and a spender (extra wishes) maxes more.
]]

return {
	MaxRank = 20,
	-- slow at the top: each rank costs ~24 percent more than the one before (3663 XP from rank 1 to 20)
	RankXP = { 15, 19, 23, 29, 35, 44, 55, 68, 84, 104, 129, 160, 198, 246, 305, 378, 469, 581, 721 },
	TierBonus = { Common = 0, Rare = 2, Epic = 4, Legendary = 6 }, -- a higher TIER is a head start of a few ranks
	DupXP = { Common = 10, Rare = 25, Epic = 60, Legendary = 150 },
	TierOrder = { "Common", "Rare", "Epic", "Legendary" },
	-- unowned skills are this much more likely to be picked than owned ones (so new skills turn up early)
	NewSkillWeight = 3,
}
