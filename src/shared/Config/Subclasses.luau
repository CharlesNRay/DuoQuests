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
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.12 },
				{ Stat = "AttackSpeed", Mode = "Mul", Value = 0.08 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.05 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.05 },
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.35 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.3 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.1 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.05 },
			},
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.2 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.12 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.05 },
			},
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
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.15 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.04 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.08 },
			},
			Skills = { "HolyWrath", "Judgment", "DivineSmite" },
		},
		Pyromancer = {
			Id = "Pyromancer",
			DisplayName = "Pyromancer",
			Class = "Mage",
			Parent = "Mage",
			UnlockLevel = 30,
			Description = "Fire and fury. Big attack and damage, with burning that keeps hurting; hits hard but stays fragile.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.3 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.15 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.04 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.05 },
			},
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.3 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.25 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.08 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.15 },
			},
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
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.12 },
			},
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.2 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.2 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.15 },
				{ Stat = "PetDamage", Mode = "Mul", Value = 2.0 }, -- the pet is the main damage dealer
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
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.14 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.08 },
				{ Stat = "CritMultiplier", Mode = "Add", Value = 0.3 },
			},
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.25 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.25 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.1 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.12 },
				{ Stat = "AttackSpeed", Mode = "Mul", Value = 0.08 },
			},
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
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.1 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.1 },
				{ Stat = "MinionPower", Mode = "Add", Value = 0.3 },
				{ Stat = "Lifesteal", Mode = "Add", Value = 0.05 },
			},
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
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.2 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.12 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.1 },
			},
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
			Mods = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.15 }, { Stat = "Attack", Mode = "Mul", Value = 0.12 }, { Stat = "DamageDealt", Mode = "Mul", Value = 0.08 }, { Stat = "PetDamage", Mode = "Mul", Value = 1.0 } },
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
}
