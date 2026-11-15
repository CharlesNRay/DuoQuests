--[[
	Pets (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Pets

	Pets are companions that follow a hero and grant combat bonuses. For now
	they do not fight themselves ("pets as combatants" is on the roadmap), so
	their bonuses are deliberately small: the balance headroom is kept for
	stronger pets later. Ownership is PERMANENT (Permanent.Pets); levels and
	the equipped pet reset each season (Season.PetLevels, Season.ActivePet).

	Each pet:
	  Rarity       Common / Rare / Epic (Config/Rarities colours)
	  UnlockStage  you receive it the first time you clear this stage
	  Look         { Shape = "Ball"|"Cat"|"Wisp", Color = {r,g,b}, Size }
	  Bonus        { Stat, Mode = "Add"|"Mul", Base, PerLevel }
	               value at level L = Base + PerLevel * (L - 1)
	               (Mul adds a fraction: 0.05 = +5%; Add adds the raw number)

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	MaxLevel = 10,
	XPPerLevel = 100, -- pet XP to go from level L to L+1 is this * L (pet food and fighting)
	LevelCostPerLevel = 70, -- Gold to go from level L to L+1 is this * L

	Order = { "Slimey", "Foxling", "Mossback", "Wisp" },

	Defs = {
		Slimey = {
			Id = "Slimey",
			DisplayName = "Slimey",
			Rarity = "Common",
			UnlockStage = 1,
			Look = { Shape = "Ball", Color = { 110, 205, 120 }, Size = 1.1 },
			Bonus = { Stat = "MaxHealth", Mode = "Mul", Base = 0.04, PerLevel = 0.01 },
		},
		Foxling = {
			Id = "Foxling",
			DisplayName = "Foxling",
			Rarity = "Common",
			UnlockStage = 5,
			Look = { Shape = "Cat", Color = { 240, 150, 70 }, Size = 1.1 },
			Bonus = { Stat = "Attack", Mode = "Mul", Base = 0.04, PerLevel = 0.01 },
		},
		Mossback = {
			Id = "Mossback",
			DisplayName = "Mossback",
			Rarity = "Common",
			UnlockStage = 10,
			Look = { Shape = "Ball", Color = { 90, 150, 110 }, Size = 1.3 },
			Bonus = { Stat = "Defense", Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		},
		Wisp = {
			Id = "Wisp",
			DisplayName = "Spark Wisp",
			Rarity = "Rare",
			UnlockStage = 20,
			Look = { Shape = "Wisp", Color = { 150, 210, 255 }, Size = 1 },
			Bonus = { Stat = "CritChance", Mode = "Add", Base = 0.02, PerLevel = 0.004 },
		},
	},
}
