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
	-- Duplicates are banked as copies (Permanent.PetCopies). The player spends RankCost[rank] copies to rank the
	-- pet up by hand (Permanent.PetRanks), up to MaxRank. A rank adds RankBonus (a fraction) of the pet's stats and
	-- raises its skill level by one. Pets level separately from food/fighting.
	MaxRank = 6,
	RankCost = { 1, 1, 2, 2, 3 }, -- copies to go from rank r to r+1 (9 copies for a max rank pet)
	RankBonus = 0.25,
	DupFallbackXP = 80, -- pet XP when a duplicate comes in after the pet is already at max rank
	-- Stat sizes at Share 1 for a Common pet; Share splits them (a one-stat pet gets 1.25, a two-stat pet 0.7 + 0.5,
	-- so the single-stat pet is better at its stat). Mul = +fraction, Add = raw number.
	StatUnits = {
		MaxHealth = { Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		Attack = { Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		Defense = { Mode = "Mul", Base = 0.05, PerLevel = 0.012 },
		AttackSpeed = { Mode = "Mul", Base = 0.03, PerLevel = 0.008 },
		CritChance = { Mode = "Add", Base = 0.015, PerLevel = 0.003 },
		CritMultiplier = { Mode = "Add", Base = 0.08, PerLevel = 0.016 },
	},
	RarityMult = { Common = 1, Rare = 1.5, Epic = 2.2, Legendary = 3.2 },

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
			Stats = { { Stat = "MaxHealth", Share = 1.25 } },
			Skill = { Name = "Goo Bubble", Text = "Wraps the most hurt ally in a shield." },
		},
		Foxling = {
			Id = "Foxling", DisplayName = "Foxling", Rarity = "Common", UnlockStage = 5,
			Look = { Shape = "Cat", Color = { 240, 150, 70 }, Size = 1.1 },
			Stats = { { Stat = "Attack", Share = 1.25 } },
			Skill = { Name = "Fox Fire", Text = "Burns an enemy with a flicker of flame." },
		},
		Mossback = {
			Id = "Mossback", DisplayName = "Mossback", Rarity = "Common", Wish = true,
			Look = { Shape = "Turtle", Color = { 90, 150, 110 }, Size = 1.3 },
			Stats = { { Stat = "Defense", Share = 0.7 }, { Stat = "MaxHealth", Share = 0.5 } },
			Skill = { Name = "Mossy Guard", Text = "Raises the whole party's defense." },
		},
		Pebbles = {
			Id = "Pebbles", DisplayName = "Pebbles", Rarity = "Common", Wish = true,
			Look = { Shape = "Ball", Color = { 150, 150, 160 }, Size = 1.0, Material = "Slate" },
			Stats = { { Stat = "MaxHealth", Share = 1.25 } },
			Skill = { Name = "Rockfall", Text = "Drops rocks on every enemy when two or more are up." },
		},
		Cottonpuff = {
			Id = "Cottonpuff", DisplayName = "Cottonpuff", Rarity = "Common", Wish = true,
			Look = { Shape = "Bunny", Color = { 245, 240, 235 }, Size = 1.0 },
			Stats = { { Stat = "AttackSpeed", Share = 0.7 }, { Stat = "Attack", Share = 0.5 } },
			Skill = { Name = "Soft Landing", Text = "Heals the most hurt ally." },
		},
		Chirpy = {
			Id = "Chirpy", DisplayName = "Chirpy", Rarity = "Common", Wish = true,
			Look = { Shape = "Bird", Color = { 255, 214, 90 }, Size = 0.9 },
			Stats = { { Stat = "CritChance", Share = 1.25 } },
			Skill = { Name = "Cheerful Song", Text = "Boosts the whole party's attack." },
		},
		Wisp = {
			Id = "Wisp", DisplayName = "Spark Wisp", Rarity = "Rare", Wish = true,
			Look = { Shape = "Wisp", Color = { 150, 210, 255 }, Size = 1 },
			Stats = { { Stat = "CritChance", Share = 0.7 }, { Stat = "CritMultiplier", Share = 0.5 } },
			Skill = { Name = "Spark", Text = "Zaps an enemy with magic." },
		},
		Emberkit = {
			Id = "Emberkit", DisplayName = "Emberkit", Rarity = "Rare", Wish = true,
			Look = { Shape = "Cat", Color = { 235, 90, 50 }, Size = 1.15, Glow = true },
			Stats = { { Stat = "Attack", Share = 0.7 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Ember Claw", Text = "A heavy fiery swipe at one enemy." },
		},
		Shellby = {
			Id = "Shellby", DisplayName = "Shellby", Rarity = "Rare", Wish = true,
			Look = { Shape = "Turtle", Color = { 80, 170, 200 }, Size = 1.25 },
			Stats = { { Stat = "MaxHealth", Share = 1.25 } },
			Skill = { Name = "Tidal Shell", Text = "Shields the whole party." },
		},
		Zephyr = {
			Id = "Zephyr", DisplayName = "Zephyr", Rarity = "Rare", Wish = true,
			Look = { Shape = "Bird", Color = { 130, 200, 235 }, Size = 1.1 },
			Stats = { { Stat = "AttackSpeed", Share = 0.7 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Tailwind", Text = "Speeds up its owner's attacks for a while." },
		},
		Frostwing = {
			Id = "Frostwing", DisplayName = "Frostwing", Rarity = "Epic", Wish = true,
			Look = { Shape = "Bird", Color = { 190, 230, 255 }, Size = 1.35, Glow = true },
			Stats = { { Stat = "CritMultiplier", Share = 0.7 }, { Stat = "AttackSpeed", Share = 0.5 } },
			Skill = { Name = "Cold Snap", Text = "Freezing wind hits every enemy." },
		},
		Starbun = {
			Id = "Starbun", DisplayName = "Starbun", Rarity = "Epic", Wish = true,
			Look = { Shape = "Bunny", Color = { 200, 160, 255 }, Size = 1.2, Glow = true },
			Stats = { { Stat = "Attack", Share = 1.25 } },
			Skill = { Name = "Star Wish", Text = "Heals the whole party." },
		},
		Thornback = {
			Id = "Thornback", DisplayName = "Thornback", Rarity = "Epic", Wish = true,
			Look = { Shape = "Turtle", Color = { 70, 120, 70 }, Size = 1.5, Spikes = true },
			Stats = { { Stat = "Defense", Share = 0.7 }, { Stat = "MaxHealth", Share = 0.5 } },
			Skill = { Name = "Thorn Armor", Text = "Toughens its owner against hits." },
		},
		EmberDrake = {
			Id = "EmberDrake", DisplayName = "Ember Drake", Rarity = "Legendary", Wish = true,
			Look = { Shape = "Drake", Color = { 230, 70, 40 }, Size = 1.6, Glow = true },
			Stats = { { Stat = "Attack", Share = 0.7 }, { Stat = "CritMultiplier", Share = 0.5 } },
			Skill = { Name = "Dragonfire", Text = "Breathes fire on every enemy." },
		},
		Colossling = {
			Id = "Colossling", DisplayName = "Colossling", Rarity = "Legendary", Boss = true,
			Look = { Shape = "Golem", Color = { 80, 150, 95 }, Size = 1.5 },
			Stats = { { Stat = "MaxHealth", Share = 0.7 }, { Stat = "Defense", Share = 0.5 } },
			Skill = { Name = "Colossal Stomp", Text = "Stomps every enemy and braces its owner." },
		},
		Aurora = {
			Id = "Aurora", DisplayName = "Aurora", Rarity = "Legendary", Wish = true,
			Look = { Shape = "Wisp", Color = { 120, 255, 200 }, Size = 1.6 },
			Stats = { { Stat = "CritChance", Share = 1.25 } },
			Skill = { Name = "Aurora Veil", Text = "Heals and shields the whole party." },
		},
	},
}
