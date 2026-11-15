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

	-- Slimey is a gift for clearing stage 1; Foxling for stage 5. Every other pet comes from the Wishing Tree
	-- (Wish = true). Each one has its own look and its own stat, so no two feel alike.
	Order = {
		"Slimey", "Foxling", "Mossback", "Pebbles", "Cottonpuff", "Chirpy",
		"Wisp", "Emberkit", "Shellby", "Zephyr",
		"Frostwing", "Starbun", "Thornback",
		"EmberDrake", "Aurora", "Colossling",
	},

	Defs = {
		Slimey = {
			Id = "Slimey", DisplayName = "Slimey", Rarity = "Common", UnlockStage = 1,
			Look = { Shape = "Ball", Color = { 110, 205, 120 }, Size = 1.1 },
			Bonus = { Stat = "MaxHealth", Mode = "Mul", Base = 0.04, PerLevel = 0.01 },
		},
		Foxling = {
			Id = "Foxling", DisplayName = "Foxling", Rarity = "Common", UnlockStage = 5,
			Look = { Shape = "Cat", Color = { 240, 150, 70 }, Size = 1.1 },
			Bonus = { Stat = "Attack", Mode = "Mul", Base = 0.04, PerLevel = 0.01 },
		},
		Mossback = {
			Id = "Mossback", DisplayName = "Mossback", Rarity = "Common", Wish = true,
			Look = { Shape = "Turtle", Color = { 90, 150, 110 }, Size = 1.3 },
			Bonus = { Stat = "Defense", Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		},
		Pebbles = {
			Id = "Pebbles", DisplayName = "Pebbles", Rarity = "Common", Wish = true,
			Look = { Shape = "Ball", Color = { 150, 150, 160 }, Size = 1.0, Material = "Slate" },
			Bonus = { Stat = "MaxHealth", Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		},
		Cottonpuff = {
			Id = "Cottonpuff", DisplayName = "Cottonpuff", Rarity = "Common", Wish = true,
			Look = { Shape = "Bunny", Color = { 245, 240, 235 }, Size = 1.0 },
			Bonus = { Stat = "AttackSpeed", Mode = "Mul", Base = 0.03, PerLevel = 0.008 },
		},
		Chirpy = {
			Id = "Chirpy", DisplayName = "Chirpy", Rarity = "Common", Wish = true,
			Look = { Shape = "Bird", Color = { 255, 214, 90 }, Size = 0.9 },
			Bonus = { Stat = "CritChance", Mode = "Add", Base = 0.015, PerLevel = 0.003 },
		},
		Wisp = {
			Id = "Wisp", DisplayName = "Spark Wisp", Rarity = "Rare", Wish = true,
			Look = { Shape = "Wisp", Color = { 150, 210, 255 }, Size = 1 },
			Bonus = { Stat = "CritChance", Mode = "Add", Base = 0.03, PerLevel = 0.005 },
		},
		Emberkit = {
			Id = "Emberkit", DisplayName = "Emberkit", Rarity = "Rare", Wish = true,
			Look = { Shape = "Cat", Color = { 235, 90, 50 }, Size = 1.15, Glow = true },
			Bonus = { Stat = "Attack", Mode = "Mul", Base = 0.07, PerLevel = 0.014 },
		},
		Shellby = {
			Id = "Shellby", DisplayName = "Shellby", Rarity = "Rare", Wish = true,
			Look = { Shape = "Turtle", Color = { 80, 170, 200 }, Size = 1.25 },
			Bonus = { Stat = "MaxHealth", Mode = "Mul", Base = 0.08, PerLevel = 0.016 },
		},
		Zephyr = {
			Id = "Zephyr", DisplayName = "Zephyr", Rarity = "Rare", Wish = true,
			Look = { Shape = "Bird", Color = { 130, 200, 235 }, Size = 1.1 },
			Bonus = { Stat = "AttackSpeed", Mode = "Mul", Base = 0.06, PerLevel = 0.01 },
		},
		Frostwing = {
			Id = "Frostwing", DisplayName = "Frostwing", Rarity = "Epic", Wish = true,
			Look = { Shape = "Bird", Color = { 190, 230, 255 }, Size = 1.35, Glow = true },
			Bonus = { Stat = "CritMultiplier", Mode = "Add", Base = 0.12, PerLevel = 0.025 },
		},
		Starbun = {
			Id = "Starbun", DisplayName = "Starbun", Rarity = "Epic", Wish = true,
			Look = { Shape = "Bunny", Color = { 200, 160, 255 }, Size = 1.2, Glow = true },
			Bonus = { Stat = "Attack", Mode = "Mul", Base = 0.1, PerLevel = 0.02 },
		},
		Thornback = {
			Id = "Thornback", DisplayName = "Thornback", Rarity = "Epic", Wish = true,
			Look = { Shape = "Turtle", Color = { 70, 120, 70 }, Size = 1.5, Spikes = true },
			Bonus = { Stat = "Defense", Mode = "Mul", Base = 0.12, PerLevel = 0.024 },
		},
		EmberDrake = {
			Id = "EmberDrake", DisplayName = "Ember Drake", Rarity = "Legendary", Wish = true,
			Look = { Shape = "Drake", Color = { 230, 70, 40 }, Size = 1.6, Glow = true },
			Bonus = { Stat = "Attack", Mode = "Mul", Base = 0.16, PerLevel = 0.03 },
		},
		Colossling = {
			Id = "Colossling", DisplayName = "Colossling", Rarity = "Legendary", Boss = true,
			Look = { Shape = "Golem", Color = { 80, 150, 95 }, Size = 1.5 },
			Bonus = { Stat = "MaxHealth", Mode = "Mul", Base = 0.18, PerLevel = 0.03 },
		},
		Aurora = {
			Id = "Aurora", DisplayName = "Aurora", Rarity = "Legendary", Wish = true,
			Look = { Shape = "Wisp", Color = { 120, 255, 200 }, Size = 1.6 },
			Bonus = { Stat = "CritChance", Mode = "Add", Base = 0.07, PerLevel = 0.009 },
		},
	},
}
