--[[
	Wishing (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Wishing

	The Wishing Tree in the plaza. Two kinds of wish:
	  Pet    pays a PetWish ticket or Gold; gives a pet (Config/Pets with Wish = true)
	  Skill  pays a SkillWish ticket or Skill Shards; gives a skill you do not own yet

	Wish tiers unlock as the frontier stage rises; higher tiers have better odds.
	Pity (per kind): a wish is guaranteed Rare or better every PityRare wishes without one,
	and Epic or better every PityEpic wishes without one. Pet wishes also have a tiny hard pity for Legendary.
	Duplicate pets turn into pet XP for that pet (DupXP, by rarity).

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
				Id = "Meadow", Name = "Meadow Wish", UnlockStage = 1, Gold = 200, Tickets = 1,
				Odds = { Common = 80, Rare = 18, Epic = 2 },
			},
			{
				Id = "Bright", Name = "Bright Wish", UnlockStage = 15, Gold = 800, Tickets = 1,
				Odds = { Common = 52, Rare = 36, Epic = 10, Legendary = 2 },
			},
			{
				Id = "Starlit", Name = "Starlit Wish", UnlockStage = 40, Gold = 2600, Tickets = 1,
				Odds = { Common = 25, Rare = 45, Epic = 24, Legendary = 6 },
			},
		},
		Skill = {
			{
				Id = "Meadow", Name = "Meadow Wish", UnlockStage = 1, Shards = 40, Tickets = 1,
				Odds = { Common = 70, Rare = 26, Epic = 4 },
			},
			{
				Id = "Bright", Name = "Bright Wish", UnlockStage = 15, Shards = 120, Tickets = 1,
				Odds = { Common = 45, Rare = 40, Epic = 15 },
			},
			{
				Id = "Starlit", Name = "Starlit Wish", UnlockStage = 40, Shards = 320, Tickets = 1,
				Odds = { Common = 20, Rare = 45, Epic = 35 },
			},
		},
	},

	TicketIds = { Pet = "PetWish", Skill = "SkillWish" },
}
