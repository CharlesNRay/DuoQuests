--[[
	Wishing (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Wishing

	The Wishing Tree in the plaza. Two kinds of wish:
	  Pet    pays a PetWish ticket or Wishstones; gives a pet (Config/Pets with Wish = true)
	  Skill  pays a SkillWish ticket or Wishstones (the same currency); gives any skill of your class (copies of owned
	         skills become XP or a waiting tier upgrade, see SkillProgress)

	Pet wish tiers unlock as the frontier stage rises; skill wish tiers are open from the start. Higher tiers have better odds.
	Pity (per kind): a wish is guaranteed Rare or better every PityRare wishes without one,
	and Epic or better every PityEpic wishes without one. Pet wishes also have a tiny hard pity for Legendary.
	A duplicate pet raises that pet's rank (pet XP once it is at max rank).

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	PityRare = 10,
	PityEpic = 40,
	PityLegendary = 90, -- pets only
	TenPullCount = 10,

	DupXP = { Common = 60, Rare = 120, Epic = 260, Legendary = 600 },

	Tiers = {
		Pet = {
			{
				Id = "Meadow", Name = "Meadow Wish", UnlockStage = 1, Cost = 3, Tickets = 1,
				Odds = { Common = 80, Rare = 18, Epic = 2 },
			},
			{
				Id = "Bright", Name = "Bright Wish", UnlockStage = 15, Cost = 5, Tickets = 1,
				Odds = { Common = 52, Rare = 36, Epic = 10, Legendary = 2 },
			},
			{
				Id = "Starlit", Name = "Starlit Wish", UnlockStage = 40, Cost = 8, Tickets = 1,
				Odds = { Common = 25, Rare = 45, Epic = 24, Legendary = 6 },
			},
		},
		-- Skill wishes are never locked behind stage milestones: every tier is open from the start and any class skill
		-- (and your chosen subclass's) can come up. Higher tiers just have better odds of higher rarities.
		Skill = {
			{
				Id = "Meadow", Name = "Meadow Wish", UnlockStage = 1, Cost = 3, Tickets = 1,
				Odds = { Common = 70, Rare = 26, Epic = 3.5, Legendary = 0.5 },
			},
			{
				Id = "Bright", Name = "Bright Wish", UnlockStage = 1, Cost = 5, Tickets = 1,
				Odds = { Common = 45, Rare = 40, Epic = 13, Legendary = 2 },
			},
			{
				Id = "Starlit", Name = "Starlit Wish", UnlockStage = 1, Cost = 8, Tickets = 1,
				Odds = { Common = 20, Rare = 45, Epic = 30, Legendary = 5 },
			},
		},
	},

	TicketIds = { Pet = "PetWish", Skill = "SkillWish" },
}
