--[[
	Pets (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Pets

	Pets are companions that follow a hero and grant combat bonuses. For now
	they do not fight themselves ("pets as combatants" is on the roadmap), so
	their bonuses are deliberately small: the balance headroom is kept for
	stronger pets later. Ownership is PERMANENT (Permanent.Pets); levels and
	levels, pet XP and the equipped pet also carry across seasons (Permanent.PetLevels / PetXP / ActivePet). Levels go to 50 and are slow: a long account goal.

	Each pet:
	  Rarity       Common / Rare / Epic (Config/Rarities colours)
	  UnlockStage  you receive it the first time you clear this stage
	  Look         { Shape = "Ball"|"Cat"|"Wisp", Color = {r,g,b}, Size }
	  Power        optional multiplier on every stat line (season prize pets use 1.7-2.0 so they out-stat every wishable pet)
	  Bonus        { Stat, Mode = "Add"|"Mul", Base, PerLevel }
	               value at level L = Base + PerLevel * (L - 1)
	               (Mul adds a fraction: 0.05 = +5%; Add adds the raw number)

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	MaxLevel = 50,
	XPPerLevel = 200, -- pet XP to go from level L to L+1 is this * L (pet food and fighting)
	-- Duplicates are banked as copies (Permanent.PetCopies). The player spends RankCost[rank] copies to rank the
	-- pet up by hand (Permanent.PetRanks), up to MaxRank. A rank adds RankBonus (a fraction) of the pet's stats and
	-- raises its skill level by one. Pets level separately from food/fighting.
	MaxRank = 6,
	RankCost = { 1, 1, 2, 2, 3 }, -- copies to go from rank r to r+1 (9 copies for a max rank pet)
	RankBonus = 0.4,
	DupFallbackXP = 80, -- (old) pet XP for a duplicate of a maxed pet; duplicates past what ranking needs are now shards
	-- Pet shards: once a pet has all the copies it needs to reach max rank, every further duplicate becomes one shard of
	-- its rarity. PetCost shards of a rarity buy a pet of that rarity (a copy, or the pet itself if not owned yet).
	-- CondenseCost shards of one rarity make one shard of the next rarity up.
	Shards = { PetCost = 30, CondenseCost = 10, Order = { "Common", "Rare", "Epic", "Legendary" } },
	-- Collecting counts: every owned pet adds points (more for rarer pets, times its rank) and each point is a small permanent
	-- bonus to Attack and Max Health, whether or not that pet is equipped.
	Collection = { Points = { Common = 1, Rare = 2, Epic = 4, Legendary = 8 }, PerPoint = 0.002, Stats = { "Attack", "MaxHealth" } },
	-- Every pet hit (its strike and its skill) is multiplied by this; Beastmaster paths add the PetDamage stat on top.
	DamageScale = 6,
	-- Every equipped pet also strikes on its own (ability Pet_Strike_<Rarity>, level = rank).
	Strike = { Cooldown = 3.5 },
	-- Stat sizes at Share 1 for a Common pet; Share splits them (a one-stat pet gets 1.25, a two-stat pet 0.7 + 0.5,
	-- so the single-stat pet is better at its stat). Mul = +fraction, Add = raw number.
	StatUnits = {
		MaxHealth = { Mode = "Mul", Base = 0.09, PerLevel = 0.008 },
		Attack = { Mode = "Mul", Base = 0.09, PerLevel = 0.008 },
		Defense = { Mode = "Mul", Base = 0.09, PerLevel = 0.008 },
		AttackSpeed = { Mode = "Mul", Base = 0.08, PerLevel = 0.007 },
		CritChance = { Mode = "Add", Base = 0.06, PerLevel = 0.005 },
		CritMultiplier = { Mode = "Add", Base = 0.3, PerLevel = 0.02 },
		Haste = { Mode = "Add", Base = 0.05, PerLevel = 0.004 },
	},
	RarityMult = { Common = 1, Rare = 1.5, Epic = 2.2, Legendary = 3.2 },

	-- Slimey is a gift for clearing stage 1; Foxling for stage 5. Every other pet comes from the Wishing Tree
	-- (Wish = true). Each one has its own look and its own stat, so no two feel alike.
	Order = {
		"Slimey", "Foxling", "Mossback", "Pebbles", "Cottonpuff", "Chirpy",
		"Wisp", "Emberkit", "Shellby", "Zephyr",
		"Frostwing", "Starbun", "Thornback",
		"EmberDrake", "Aurora", "Colossling",
		"Hearthhound", "Bannerling", "Vaultmimic", "Wardenowl", "Charterfox", "Hearthdrake", "Oathgriffin", -- guild pets (Guild = true)
		"Crownling", "Laurelwing", "Bannerhound", "Haloette", "Arcanix", "Skyhawk", "Shadowcat", "Spiritling", -- season prizes (Reward = true): never from the Wishing Tree
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
			Stats = { { Stat = "CritChance", Share = 0.7 }, { Stat = "Haste", Share = 0.5 } },
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
			Stats = { { Stat = "AttackSpeed", Share = 0.7 }, { Stat = "Haste", Share = 0.5 } },
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
			Stats = { { Stat = "Haste", Share = 0.7 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Aurora Veil", Text = "Heals and shields the whole party." },
		},
		-- Guild pets (Guild = true): only from the Guild Wish (see Config/Guilds.Wish), never the Wishing Tree or shards
		Hearthhound = {
			Id = "Hearthhound", DisplayName = "Hearthhound", Rarity = "Rare", Guild = true,
			Look = { Shape = "Cat", Color = { 230, 150, 80 }, Size = 1.15 },
			Stats = { { Stat = "Defense", Share = 0.7 }, { Stat = "MaxHealth", Share = 0.5 } },
			Skill = { Name = "Hearth Ward", Text = "Shields the whole party." },
		},
		Bannerling = {
			Id = "Bannerling", DisplayName = "Bannerling", Rarity = "Rare", Guild = true,
			Look = { Shape = "Wisp", Color = { 220, 70, 70 }, Size = 1.1 },
			Stats = { { Stat = "Attack", Share = 0.7 }, { Stat = "Haste", Share = 0.5 } },
			Skill = { Name = "Rallying Bolt", Text = "A bolt of banner-light hits one enemy." },
		},
		Vaultmimic = {
			Id = "Vaultmimic", DisplayName = "Vaultmimic", Rarity = "Rare", Guild = true,
			Look = { Shape = "Ball", Color = { 200, 160, 60 }, Size = 1.2 },
			Stats = { { Stat = "CritChance", Share = 0.7 }, { Stat = "Attack", Share = 0.5 } },
			Skill = { Name = "Mimic Bite", Text = "A snapping bite on one enemy." },
		},
		Wardenowl = {
			Id = "Wardenowl", DisplayName = "Warden Owl", Rarity = "Epic", Guild = true,
			Look = { Shape = "Bird", Color = { 120, 150, 200 }, Size = 1.35, Glow = true },
			Stats = { { Stat = "MaxHealth", Share = 0.8 }, { Stat = "Defense", Share = 0.4 } },
			Skill = { Name = "Watchful Mend", Text = "Heals every ally." },
		},
		Charterfox = {
			Id = "Charterfox", DisplayName = "Charterfox", Rarity = "Epic", Guild = true,
			Look = { Shape = "Cat", Color = { 250, 120, 50 }, Size = 1.3 },
			Stats = { { Stat = "Attack", Share = 0.8 }, { Stat = "CritMultiplier", Share = 0.4 } },
			Skill = { Name = "Charter Flame", Text = "Fire sweeps over every enemy." },
		},
		Hearthdrake = {
			Id = "Hearthdrake", DisplayName = "Hearthdrake", Rarity = "Legendary", Guild = true,
			Look = { Shape = "Drake", Color = { 255, 120, 60 }, Size = 1.6, Glow = true },
			Stats = { { Stat = "Attack", Share = 0.7 }, { Stat = "MaxHealth", Share = 0.5 } },
			Skill = { Name = "Hearthstorm", Text = "Scorches every enemy." },
		},
		Oathgriffin = {
			Id = "Oathgriffin", DisplayName = "Oathkeeper Griffin", Rarity = "Legendary", Guild = true,
			Look = { Shape = "Bird", Color = { 240, 210, 120 }, Size = 1.6, Glow = true },
			Stats = { { Stat = "Defense", Share = 0.6 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Oath Mantle", Text = "Heals and shields the whole party." },
		},
		-- Season prizes (see Config/SeasonRewards): not wishable, only earned by placing at the end of a season.
		Crownling = {
			Id = "Crownling", DisplayName = "Crownling", Rarity = "Legendary", Reward = true, Power = 1.7,
			Look = { Shape = "Drake", Color = { 255, 205, 70 }, Size = 1.6, Glow = true },
			Stats = { { Stat = "Attack", Share = 0.8 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Royal Decree", Text = "Strikes every enemy and shields the party." },
		},
		Laurelwing = {
			Id = "Laurelwing", DisplayName = "Laurelwing", Rarity = "Legendary", Reward = true, Power = 1.7,
			Look = { Shape = "Wisp", Color = { 160, 220, 110 }, Size = 1.4 },
			Stats = { { Stat = "AttackSpeed", Share = 0.7 }, { Stat = "Attack", Share = 0.5 } },
			Skill = { Name = "Victory March", Text = "Whips the whole party into a frenzy: attack and attack speed up." },
		},
		Bannerhound = {
			Id = "Bannerhound", DisplayName = "Bannerhound", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Cat", Color = { 200, 80, 70 }, Size = 1.3 },
			Stats = { { Stat = "Defense", Share = 0.7 }, { Stat = "MaxHealth", Share = 0.5 } },
			Skill = { Name = "Banner Guard", Text = "Raises the whole party's defense and shields it." },
		},
		Haloette = {
			Id = "Haloette", DisplayName = "Haloette", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Wisp", Color = { 255, 240, 170 }, Size = 1.3, Glow = true },
			Stats = { { Stat = "MaxHealth", Share = 0.8 }, { Stat = "CritMultiplier", Share = 0.4 } },
			Skill = { Name = "Halo Mend", Text = "Heals the most hurt ally a lot and the rest a little." },
		},
		Arcanix = {
			Id = "Arcanix", DisplayName = "Arcanix", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Wisp", Color = { 170, 120, 255 }, Size = 1.3, Glow = true },
			Stats = { { Stat = "Attack", Share = 0.8 }, { Stat = "CritMultiplier", Share = 0.4 } },
			Skill = { Name = "Arcane Echo", Text = "A wave of arcane energy hits every enemy." },
		},
		Skyhawk = {
			Id = "Skyhawk", DisplayName = "Skyhawk", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Bird", Color = { 120, 190, 240 }, Size = 1.3 },
			Stats = { { Stat = "AttackSpeed", Share = 0.7 }, { Stat = "Haste", Share = 0.5 } },
			Skill = { Name = "Hawk Strike", Text = "Dives on an enemy and marks it to take more damage." },
		},
		Shadowcat = {
			Id = "Shadowcat", DisplayName = "Shadowcat", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Cat", Color = { 80, 70, 110 }, Size = 1.3 },
			Stats = { { Stat = "Attack", Share = 0.7 }, { Stat = "CritChance", Share = 0.5 } },
			Skill = { Name = "Shadow Pounce", Text = "Pounces on an enemy; its owner attacks faster for a moment." },
		},
		Spiritling = {
			Id = "Spiritling", DisplayName = "Spiritling", Rarity = "Epic", Reward = true, Power = 2.0,
			Look = { Shape = "Wisp", Color = { 120, 230, 210 }, Size = 1.3, Glow = true },
			Stats = { { Stat = "MaxHealth", Share = 0.7 }, { Stat = "Attack", Share = 0.5 } },
			Skill = { Name = "Spirit Link", Text = "Heals the most hurt ally and shields them." },
		},
	},
}
