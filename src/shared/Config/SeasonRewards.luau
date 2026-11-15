--[[
	SeasonRewards (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > SeasonRewards

	End-of-season rewards. Everyone who played gets a PERCENTILE reward; the very
	best also get RANK rewards on top; the best of each class get CLASS rewards on top.
	The three layers add together.

	Ranking score: furthest stage reached that season (Leaderboards "Stage").
	Sunstones here are EARNED (never random), so they do not touch the paid-random-item rules.

	All numbers are first guesses for tuning. For scale: Premium Pass = 400 Sunstones.
]]

return {
	-- Needs at least this stage to be ranked at all (stops empty alt accounts filling the 100% bracket).
	MinStage = 3,

	-- Everyone ranked gets the first row whose Top (share of ranked players, 0-1) covers them.
	-- Top 10%, 20%, ... 100%: nobody is left out.
	Percentiles = {
		{ Top = 0.10, Label = "Top 10%", Sunstones = 100, Wishstones = 40, Tickets = { PetWish = 2 } },
		{ Top = 0.20, Label = "Top 20%", Sunstones = 80, Wishstones = 32, Tickets = { PetWish = 1 } },
		{ Top = 0.30, Label = "Top 30%", Sunstones = 60, Wishstones = 26 },
		{ Top = 0.40, Label = "Top 40%", Sunstones = 50, Wishstones = 22 },
		{ Top = 0.50, Label = "Top 50%", Sunstones = 40, Wishstones = 18 },
		{ Top = 0.60, Label = "Top 60%", Sunstones = 30, Wishstones = 14 },
		{ Top = 0.70, Label = "Top 70%", Sunstones = 25, Wishstones = 10 },
		{ Top = 0.80, Label = "Top 80%", Sunstones = 20, Wishstones = 8 },
		{ Top = 0.90, Label = "Top 90%", Sunstones = 15, Wishstones = 6 },
		{ Top = 1.00, Label = "Top 100%", Sunstones = 10, Wishstones = 4 },
	},

	-- Exact rank rewards on top of the percentile reward. A player gets ONE row: the tightest MaxRank they fit.
	-- Title / Cosmetic ids are granted into Permanent.Titles / Permanent.Cosmetics (the cosmetics shop shows them).
	Ranks = {
		{ MaxRank = 1, Label = "Champion", Sunstones = 600, Title = "Champion", Cosmetic = "Aura_Champion", Tickets = { PetWish = 3, SkillWish = 3 } },
		{ MaxRank = 2, Label = "Runner-up", Sunstones = 400, Title = "Runner-up", Cosmetic = "Aura_Champion", Tickets = { PetWish = 2, SkillWish = 2 } },
		{ MaxRank = 3, Label = "Third place", Sunstones = 300, Title = "Podium", Cosmetic = "Aura_Podium", Tickets = { PetWish = 2, SkillWish = 2 } },
		{ MaxRank = 10, Label = "Top 10", Sunstones = 150, Title = "Elite Ten", Cosmetic = "Aura_Elite", Tickets = { PetWish = 1, SkillWish = 1 } },
		{ MaxRank = 20, Label = "Top 20", Sunstones = 100, Title = "Elite Twenty", Tickets = { PetWish = 1 } },
		{ MaxRank = 50, Label = "Top 50", Sunstones = 50, Title = "Elite Fifty" },
	},

	-- Best players of each class (their season class when they played; see SeasonResults).
	ClassRanks = {
		{ MaxRank = 1, Label = "Best %s", Sunstones = 150, Title = "Grandmaster %s" },
		{ MaxRank = 3, Label = "Top 3 %s", Sunstones = 75 },
		{ MaxRank = 10, Label = "Top 10 %s", Sunstones = 30 },
	},

	-- How many top places the frozen results keep per board (the exact-rank rewards need this many).
	TopKept = 50,
}
