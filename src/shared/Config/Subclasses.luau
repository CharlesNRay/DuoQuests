--[[
	Subclasses (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Subclasses

	At player level UnlockLevel a player picks ONE path for their class. A path is a
	big, permanent (for the season) power spike: large stat bonuses plus new
	class skills only that path can use. Every class has 2 paths. A path may also carry PetBoost = { Stats, SkillLevels } (Beastmaster).

	Each subclass:
	  Class        the class it belongs to
	  Parent       what it branches from: the class id (tier 1) or another
	               subclass id (deeper tiers, NOT used yet)
	  UnlockLevel  reach this PLAYER LEVEL to be able to pick it
	  Mods         { Stat, Mode = "Add"|"Mul", Value } applied on top of the class
	               stats (Mul adds a fraction: 0.4 = +40%). DamageDealt,
	               HealingDealt and DamageTaken are multipliers that start at 1.
	  Skills       the new skills, in display order. The FIRST is granted free
	               when you choose the path; the rest are unlocked with shards
	               like any other skill (see Config/Abilities, Subclass = id).

	MORE BRANCHES LATER: to add a third path, add another entry with the same
	Parent. To split a path further, add entries whose Parent is that subclass
	and set a higher UnlockLevel; Subclasses.Chain() already walks Parent links,
	so stats and skills of every tier stack with no code change.

	Every number is a PLACEHOLDER to be tuned (see docs/PROGRESSION.md).
]]

return {
	Defs = {
		Berserker = {
			Id = "Berserker",
			DisplayName = "Berserker",
			Class = "Warrior",
			Parent = "Warrior",
			UnlockLevel = 30,
			Description = "All-out offense. Huge attack, attack speed and crits; a frenzy that makes the Warrior a damage dealer.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.25 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.15 }, -- was -0.313 (halved 2026-11-22; the first commit only changed the docs)
				{ Stat = "AttackSpeed", Mode = "Mul", Value = 0.08 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.05 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.12 }, -- was -0.240
			},
			Skills = { "BloodFrenzy", "Cleave", "ExecutionerStrike" },
		},
		Guardian = {
			Id = "Guardian",
			DisplayName = "Guardian",
			Class = "Warrior",
			Parent = "Warrior",
			UnlockLevel = 30,
			Description = "An immovable wall. Enormous health and defense, damage reduction and party-wide shields.",
			Mods = {
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.093 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.3 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.1 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.15 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.142 } },
			Skills = { "Bulwark", "Retribution", "UnbreakableVow" },
		},
		Priest = {
			Id = "Priest",
			DisplayName = "Priest",
			Class = "Cleric",
			Parent = "Cleric",
			UnlockLevel = 30,
			Description = "A true healer. Much stronger healing, more health, and party-wide heals and wards.",
			Mods = {
				{ Stat = "HealingDealt", Mode = "Mul", Value = 0.3 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.188 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.12 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "DamageDealt", Mode = "Mul", Value = -0.120 }, { Stat = "Haste", Mode = "Add", Value = 0.08 } },
			Skills = { "Sanctuary", "Renewal", "HolyAegis" },
		},
		Templar = {
			Id = "Templar",
			DisplayName = "Templar",
			Class = "Cleric",
			Parent = "Cleric",
			UnlockLevel = 30,
			Description = "A holy warrior. Big attack and holy damage; smites enemies and blesses the party.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.28 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.300 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.04 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.200 },
			},
			Skills = { "HolyWrath", "Verdict", "DivineSmite" },
		},
		Pyromancer = {
			Id = "Pyromancer",
			DisplayName = "Pyromancer",
			Class = "Mage",
			Parent = "Mage",
			UnlockLevel = 30,
			Description = "Fire and fury. Big attack and damage, with burning that keeps hurting; hits hard but stays fragile.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.24 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.504 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.04 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.240 }, { Stat = "Haste", Mode = "Add", Value = 0.06 } },
			Skills = { "Ignite", "Inferno", "PhoenixFire" },
		},
		FrostWeaver = {
			Id = "FrostWeaver",
			DisplayName = "Frost Weaver",
			Class = "Mage",
			Parent = "Mage",
			UnlockLevel = 30,
			Description = "Control. More health and defense, takes less damage; freezes and chills enemies and shields the party.",
			Mods = {
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.096 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.25 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.08 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.15 }, { Stat = "DamageDealt", Mode = "Mul", Value = -0.410 }, { Stat = "Haste", Mode = "Add", Value = 0.06 } },
			Skills = { "DeepFreeze", "FrostArmor", "Glacier" },
		},
		Sharpshooter = {
			Id = "Sharpshooter",
			DisplayName = "Sharpshooter",
			Class = "Ranger",
			Parent = "Ranger",
			UnlockLevel = 30,
			Description = "Deadly aim. Huge crit chance and crit damage; single targets and bosses melt.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.25 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.1 },
				{ Stat = "CritMultiplier", Mode = "Add", Value = 0.3 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.500 }, { Stat = "MaxHealth", Mode = "Mul", Value = -0.300 } },
			Skills = { "DeadEye", "Headshot", "Barrage" },
		},
		Beastmaster = {
			Id = "Beastmaster",
			DisplayName = "Beastmaster",
			Class = "Ranger",
			Parent = "Ranger",
			UnlockLevel = 30,
			Description = "Fights beside the wild. The equipped pet's bonuses are far stronger and its skill hits harder and sooner.",
			Mods = {
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.236 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.2 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.15 },
				{ Stat = "PetDamage", Mode = "Mul", Value = 1.2 }, -- the pet is the main damage dealer
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.500 },
			},
			PetBoost = { Stats = 0.75, SkillLevels = 4 },
			Skills = { "PackHowl", "Stampede", "NaturesBond" },
		},
		Assassin = {
			Id = "Assassin",
			DisplayName = "Assassin",
			Class = "Rogue",
			Parent = "Rogue",
			UnlockLevel = 30,
			Description = "Kills from the shadows. Huge crits and big single-target hits.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.28 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.600 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.05 },
				{ Stat = "CritMultiplier", Mode = "Add", Value = 0.3 }, { Stat = "MaxHealth", Mode = "Mul", Value = -0.300 } },
			Skills = { "DeathMark", "Execute", "ShadowStrike" },
		},
		Duelist = {
			Id = "Duelist",
			DisplayName = "Duelist",
			Class = "Rogue",
			Parent = "Rogue",
			UnlockLevel = 30,
			Description = "A blade-master who cannot be hit. More health and defense, less damage taken, faster attacks, and ripostes that heal.",
			Mods = {
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.028 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.25 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.1 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.12 },
				{ Stat = "AttackSpeed", Mode = "Mul", Value = 0.08 }, { Stat = "DamageDealt", Mode = "Mul", Value = -0.264 } },
			Skills = { "Riposte", "Parry", "BladeDance" },
		},
		Necromancer = {
			Id = "Necromancer",
			DisplayName = "Necromancer",
			Class = "Summoner",
			Parent = "Summoner",
			UnlockLevel = 30,
			Description = "Commands the dead. Stronger minions, ghouls that feed you life, plague and death magic; drains life from its victims.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.2 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = -0.600 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.300 },
				{ Stat = "MinionPower", Mode = "Add", Value = 0.15 },
				{ Stat = "Lifesteal", Mode = "Add", Value = 0.05 }, { Stat = "Haste", Mode = "Add", Value = 0.05 } },
			Skills = { "RaiseDead", "DeathCoil", "Plague" },
		},
		SpiritCaller = {
			Id = "SpiritCaller",
			DisplayName = "Spirit Caller",
			Class = "Summoner",
			Parent = "Summoner",
			UnlockLevel = 30,
			Description = "Calls guardian spirits. Much stronger healing, more health, a spirit that mends allies, and party-wide shields.",
			Mods = {
				{ Stat = "HealingDealt", Mode = "Mul", Value = 0.25 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = -0.090 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.12 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.1 }, { Stat = "DamageDealt", Mode = "Mul", Value = -0.405 }, { Stat = "Haste", Mode = "Add", Value = 0.08 } },
			Skills = { "GuardianSpirit", "AncestralCall", "SpiritStorm" },
		},
		Warlord = {
			Id = "Warlord",
			DisplayName = "Warlord",
			Class = "Warrior",
			Parent = "Berserker",
			UnlockLevel = 90,
			Description = "The final form of the Berserker: a roaring war leader whose blows shake the whole battlefield.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.1 }, { Stat = "CritChance", Mode = "Add", Value = 0.04 } },
			Skills = { "WarlordsRoar" },
		},
		Paragon = {
			Id = "Paragon",
			DisplayName = "Paragon",
			Class = "Warrior",
			Parent = "Guardian",
			UnlockLevel = 90,
			Description = "The final form of the Guardian: a living fortress that shields every ally.",
			Mods = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.25 }, { Stat = "Defense", Mode = "Mul", Value = 0.2 }, { Stat = "DamageTaken", Mode = "Mul", Value = -0.06 } },
			Skills = { "AegisOfAges" },
		},
		Archon = {
			Id = "Archon",
			DisplayName = "Archon",
			Class = "Cleric",
			Parent = "Priest",
			UnlockLevel = 90,
			Description = "The final form of the Priest: healing that overflows and shields that last.",
			Mods = { { Stat = "HealingDealt", Mode = "Mul", Value = 0.3 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.15 }, { Stat = "Defense", Mode = "Mul", Value = 0.1 } },
			Skills = { "Resurgence" },
		},
		Crusader = {
			Id = "Crusader",
			DisplayName = "Crusader",
			Class = "Cleric",
			Parent = "Templar",
			UnlockLevel = 90,
			Description = "The final form of the Templar: holy fire that burns the unworthy.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.1 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.1 } },
			Skills = { "HolyCrusade" },
		},
		Cataclysm = {
			Id = "Cataclysm",
			DisplayName = "Cataclysmist",
			Class = "Mage",
			Parent = "Pyromancer",
			UnlockLevel = 90,
			Description = "The final form of the Pyromancer: ruin on a world scale.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.12 }, { Stat = "CritChance", Mode = "Add", Value = 0.04 } },
			Skills = { "Cataclysm" },
		},
		Glacialist = {
			Id = "Glacialist",
			DisplayName = "Glacialist",
			Class = "Mage",
			Parent = "FrostWeaver",
			UnlockLevel = 90,
			Description = "The final form of the Frost Weaver: the world slows and breaks.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.15 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.1 }, { Stat = "Defense", Mode = "Mul", Value = 0.12 } },
			Skills = { "AbsoluteZero" },
		},
		Marshal = {
			Id = "Marshal",
			DisplayName = "Deadeye Marshal",
			Class = "Ranger",
			Parent = "Sharpshooter",
			UnlockLevel = 90,
			Description = "The final form of the Sharpshooter: arrows that darken the sky.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "CritChance", Mode = "Add", Value = 0.06 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.08 } },
			Skills = { "RainOfArrows" },
		},
		Wildlord = {
			Id = "Wildlord",
			DisplayName = "Wildlord",
			Class = "Ranger",
			Parent = "Beastmaster",
			UnlockLevel = 90,
			Description = "The final form of the Beastmaster: the wild answers every call.",
			Mods = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.15 }, { Stat = "Attack", Mode = "Mul", Value = 0.12 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.08 }, { Stat = "PetDamage", Mode = "Mul", Value = 0.5 } },
			Skills = { "PrimalSurge" },
		},
		Nightblade = {
			Id = "Nightblade",
			DisplayName = "Nightblade",
			Class = "Rogue",
			Parent = "Assassin",
			UnlockLevel = 90,
			Description = "The final form of the Assassin: seen only when the blow lands.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.2 }, { Stat = "CritChance", Mode = "Add", Value = 0.07 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.1 } },
			Skills = { "VanishingStrike" },
		},
		Swordsaint = {
			Id = "Swordsaint",
			DisplayName = "Swordsaint",
			Class = "Rogue",
			Parent = "Duelist",
			UnlockLevel = 90,
			Description = "The final form of the Duelist: a thousand cuts in a breath.",
			Mods = { { Stat = "AttackSpeed", Mode = "Mul", Value = 0.12 }, { Stat = "Attack", Mode = "Mul", Value = 0.15 }, { Stat = "CritChance", Mode = "Add", Value = 0.05 } },
			Skills = { "ThousandCuts" },
		},
		Lich = {
			Id = "Lich",
			DisplayName = "Lich",
			Class = "Summoner",
			Parent = "Necromancer",
			UnlockLevel = 90,
			Description = "The final form of the Necromancer: death itself feeds you.",
			Mods = { { Stat = "Attack", Mode = "Mul", Value = 0.15 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.1 }, { Stat = "MinionPower", Mode = "Add", Value = 0.2 } },
			Skills = { "SoulHarvest" },
		},
		AncestralSage = {
			Id = "AncestralSage",
			DisplayName = "Ancestral Sage",
			Class = "Summoner",
			Parent = "SpiritCaller",
			UnlockLevel = 90,
			Description = "The final form of the Spirit Caller: the ancestors fight beside you.",
			Mods = { { Stat = "HealingDealt", Mode = "Mul", Value = 0.2 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.15 }, { Stat = "Attack", Mode = "Mul", Value = 0.12 } },
			Skills = { "AncestralWrath" },
		},
	},

	-- display order of the options offered to a class
	Order = { "Berserker", "Guardian", "Priest", "Templar", "Pyromancer", "FrostWeaver", "Sharpshooter", "Beastmaster", "Assassin", "Duelist", "Necromancer", "SpiritCaller",
		-- tier 2 (level 90): the final form of the path you chose
		"Warlord", "Paragon", "Archon", "Crusader", "Cataclysm", "Glacialist", "Marshal", "Wildlord", "Nightblade", "Swordsaint", "Lich", "AncestralSage" },
	-- How a path changes the stats you gain each level AFTER you choose it: multipliers on the class's per-level growth.
	-- Offensive paths grow Attack faster and Health / Defense slower, protective paths the other way round.
	Growth = {
		Berserker = { Attack = 1.6, Defense = 0.6, MaxHealth = 0.8 },
		Guardian = { Attack = 0.6, Defense = 1.6, MaxHealth = 1.5 },
		Priest = { Attack = 0.7, Defense = 0.9, MaxHealth = 1.2 },
		Templar = { Attack = 1.8, Defense = 1.4, MaxHealth = 1.2 },
		Pyromancer = { Attack = 1.7, Defense = 0.6, MaxHealth = 0.7 },
		FrostWeaver = { Attack = 1.1, Defense = 1.4, MaxHealth = 1.1 },
		Sharpshooter = { Attack = 1.7, Defense = 0.7, MaxHealth = 0.7 },
		Beastmaster = { Attack = 0.9, Defense = 1.2, MaxHealth = 1.3 },
		Assassin = { Attack = 1.7, Defense = 0.6, MaxHealth = 0.7 },
		Duelist = { Attack = 1.3, Defense = 1.3, MaxHealth = 1.0 },
		Necromancer = { Attack = 1.1, Defense = 0.9, MaxHealth = 1.3 },
		SpiritCaller = { Attack = 0.8, Defense = 1.2, MaxHealth = 1.4 },
	},
}
