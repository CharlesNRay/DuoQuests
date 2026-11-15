--[[
	Subclasses (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Subclasses

	At stage UnlockStage a player picks ONE path for their class. A path is a
	big, permanent (for the season) power spike: large stat bonuses plus new
	class skills only that path can use. Right now every class has 2 paths.

	Each subclass:
	  Class        the class it belongs to
	  Parent       what it branches from: the class id (tier 1) or another
	               subclass id (deeper tiers, NOT used yet)
	  UnlockStage  reach this stage (frontier) to be able to pick it
	  Mods         { Stat, Mode = "Add"|"Mul", Value } applied on top of the class
	               stats (Mul adds a fraction: 0.4 = +40%). DamageDealt,
	               HealingDealt and DamageTaken are multipliers that start at 1.
	  Skills       the new skills, in display order. The FIRST is granted free
	               when you choose the path; the rest are unlocked with shards
	               like any other skill (see Config/Abilities, Subclass = id).

	MORE BRANCHES LATER: to add a third path, add another entry with the same
	Parent. To split a path further, add entries whose Parent is that subclass
	and set a higher UnlockStage; Subclasses.Chain() already walks Parent links,
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
			UnlockStage = 30,
			Description = "All-out offense. Huge attack, attack speed and crits; a frenzy that makes the Warrior a damage dealer.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.45 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.2 },
				{ Stat = "AttackSpeed", Mode = "Mul", Value = 0.15 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.1 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.1 },
			},
			Skills = { "BloodFrenzy", "Cleave", "ExecutionerStrike" },
		},
		Guardian = {
			Id = "Guardian",
			DisplayName = "Guardian",
			Class = "Warrior",
			Parent = "Warrior",
			UnlockStage = 30,
			Description = "An immovable wall. Enormous health and defense, damage reduction and party-wide shields.",
			Mods = {
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.6 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.5 },
				{ Stat = "DamageTaken", Mode = "Mul", Value = -0.15 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.1 },
			},
			Skills = { "Bulwark", "Retribution", "UnbreakableVow" },
		},
		Priest = {
			Id = "Priest",
			DisplayName = "Priest",
			Class = "Cleric",
			Parent = "Cleric",
			UnlockStage = 30,
			Description = "A true healer. Much stronger healing, more health, and party-wide heals and wards.",
			Mods = {
				{ Stat = "HealingDealt", Mode = "Mul", Value = 0.5 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.3 },
				{ Stat = "Defense", Mode = "Mul", Value = 0.2 },
				{ Stat = "Attack", Mode = "Mul", Value = 0.1 },
			},
			Skills = { "Sanctuary", "Renewal", "HolyAegis" },
		},
		Templar = {
			Id = "Templar",
			DisplayName = "Templar",
			Class = "Cleric",
			Parent = "Cleric",
			UnlockStage = 30,
			Description = "A holy warrior. Big attack and holy damage; smites enemies and blesses the party.",
			Mods = {
				{ Stat = "Attack", Mode = "Mul", Value = 0.5 },
				{ Stat = "DamageDealt", Mode = "Mul", Value = 0.25 },
				{ Stat = "CritChance", Mode = "Add", Value = 0.08 },
				{ Stat = "MaxHealth", Mode = "Mul", Value = 0.15 },
			},
			Skills = { "HolyWrath", "Judgment", "DivineSmite" },
		},
	},

	-- display order of the options offered to a class
	Order = { "Berserker", "Guardian", "Priest", "Templar" },
}
