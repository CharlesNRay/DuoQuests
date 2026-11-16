--[[
	SeasonRewards (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > SeasonRewards

	End-of-season rewards. Everyone who played gets a PERCENTILE reward; the very
	best also get RANK rewards on top; the best of each class get CLASS rewards on top.
	The three layers add together.

	Ranking score: furthest stage reached that season (Leaderboards "Stage").
	Sunstones here are EARNED (never random), so they do not touch the paid-random-item rules.

	All numbers are first guesses for tuning. For scale: Premium Pass = 400 Sunstones. The #1 player who is also the best of a class
	gets both rank 1 and class 1 rewards on purpose. With StackRanks every lower row adds too.
]]

return {
	-- Needs at least this stage to be ranked at all (stops empty alt accounts filling the 100% bracket).
	MinStage = 3,

	-- Everyone ranked gets the first row whose Top (share of ranked players, 0-1) covers them.
	-- Top 10%, 20%, ... 100%: nobody is left out.
	Percentiles = {
		{ Top = 0.10, Label = "Top 10%", Sunstones = 200, Wishstones = 80, Tickets = { PetWish = 2 } },
		{ Top = 0.20, Label = "Top 20%", Sunstones = 160, Wishstones = 64, Tickets = { PetWish = 1 } },
		{ Top = 0.30, Label = "Top 30%", Sunstones = 125, Wishstones = 50 },
		{ Top = 0.40, Label = "Top 40%", Sunstones = 100, Wishstones = 40 },
		{ Top = 0.50, Label = "Top 50%", Sunstones = 80, Wishstones = 32 },
		{ Top = 0.60, Label = "Top 60%", Sunstones = 60, Wishstones = 24 },
		{ Top = 0.70, Label = "Top 70%", Sunstones = 45, Wishstones = 18 },
		{ Top = 0.80, Label = "Top 80%", Sunstones = 35, Wishstones = 14 },
		{ Top = 0.90, Label = "Top 90%", Sunstones = 25, Wishstones = 10 },
		{ Top = 1.00, Label = "Top 100%", Sunstones = 15, Wishstones = 6 },
	},

	-- true: a player also gets EVERY lower rank row they qualify for (rank 1 gets Champion + Runner-up + Third place + Top 10 +
	-- Top 20 + Top 50), the same for the class rows. false: only the tightest row.
	StackRanks = true,

	-- Exact rank rewards on top of the percentile reward. These rows are MILESTONES: every rank from 1 to 50 gets a reward,
	-- (rank 4-10 gets the Top 10 row and everything below it, 11-20 the Top 20 row and below, 21-50 the Top 50 row; see StackRanks).
	-- Title / Cosmetic ids are granted into Permanent.Titles / Permanent.Cosmetics (the cosmetics shop shows them).
	Ranks = {
		{ MaxRank = 1, Label = "Champion", Sunstones = 1000, Title = "Champion", Cosmetic = "Aura_Champion", Tickets = { PetWish = 3, SkillWish = 3 } },
		{ MaxRank = 2, Label = "Runner-up", Sunstones = 700, Title = "Runner-up", Cosmetic = "Aura_Champion", Tickets = { PetWish = 2, SkillWish = 2 } },
		{ MaxRank = 3, Label = "Third place", Sunstones = 600, Title = "Podium", Cosmetic = "Aura_Podium", Tickets = { PetWish = 2, SkillWish = 2 } },
		{ MaxRank = 10, Label = "Top 10", Sunstones = 400, Title = "Elite Ten", Cosmetic = "Aura_Elite", Tickets = { PetWish = 1, SkillWish = 1 } },
		{ MaxRank = 20, Label = "Top 20", Sunstones = 275, Title = "Elite Twenty", Tickets = { PetWish = 1 } },
		{ MaxRank = 50, Label = "Top 50", Sunstones = 150, Title = "Elite Fifty" },
	},

	-- Best players of each class (their season class when they played; see SeasonResults).
	ClassRanks = {
		{ MaxRank = 1, Label = "Best %s", Sunstones = 300, Title = "Grandmaster %s" },
		{ MaxRank = 3, Label = "Top 3 %s", Sunstones = 150 },
		{ MaxRank = 10, Label = "Top 10 %s", Sunstones = 60 },
	},

	-- How many top places the frozen results keep per board (the exact-rank rewards need this many).
	TopKept = 50,
}
