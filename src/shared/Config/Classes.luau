--[[
	Classes (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Classes

	Every number here is a PLACEHOLDER to be tuned during playtesting.

	Each class has:
	  BasicAttack      the one automatic attack. Presentation info for now
	                   (Range "Melee"/"Ranged"); damage uses Attack and DamageType.
	  AbilityPool      every skill the class can ever equip, in display order.
	  DefaultLoadout   four skills in PRIORITY order (slot 1 is checked first
	                   each tick). Also the skills a new player starts owning.
	  Subclasses       empty for now. Later each entry goes here as
	                   Subclasses = { Berserker = { ...stat tweaks, extra skills... } }
	                   with the choice stored as Season.SubclassId.

	Prototype focus: Warrior (tank) and Cleric (healer). Mage is kept for
	later and is not unlocked for new players.
]]

return {
	Warrior = {
		Id = "Warrior",
		DisplayName = "Warrior",
		Role = "Tank",
		DamageType = "Physical",
		BasicAttack = { Id = "SwordSlash", DisplayName = "Sword Slash", Range = "Melee" },

		BaseStats = {
			MaxHealth = 200,
			Attack = 12,
			Defense = 10,
			AttackSpeed = 1.0, -- basic attacks per second
			CritChance = 0.05,
		},
		GrowthPerLevel = {
			MaxHealth = 25,
			Attack = 2,
			Defense = 2,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"ShieldBash",
			"Taunt",
			"IronSkin",
			"Whirlwind",
			"ShieldWall",
			"CrushingBlow",
			"LastStand",
			"RallyingCry",
		},
		DefaultLoadout = { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" },
		Subclasses = {},
	},

	Cleric = {
		Id = "Cleric",
		DisplayName = "Cleric",
		Role = "Healer",
		DamageType = "Magical",
		BasicAttack = { Id = "HolyBolt", DisplayName = "Holy Bolt", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 130,
			Attack = 14,
			Defense = 4,
			AttackSpeed = 0.9,
			CritChance = 0.05,
		},
		GrowthPerLevel = {
			MaxHealth = 15,
			Attack = 2.5,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"Smite",
			"Heal",
			"Blessing",
			"RadiantBurst",
			"DivineShield",
			"GroupHeal",
			"GuardianAngel",
			"Judgment",
		},
		DefaultLoadout = { "Heal", "Blessing", "RadiantBurst", "Smite" },
		Subclasses = {},
	},

	Mage = {
		Id = "Mage",
		DisplayName = "Mage",
		Role = "Damage",
		DamageType = "Magical",
		BasicAttack = { Id = "ArcaneMissile", DisplayName = "Arcane Missile", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 110,
			Attack = 18,
			Defense = 3,
			AttackSpeed = 0.8,
			CritChance = 0.08,
		},
		GrowthPerLevel = {
			MaxHealth = 12,
			Attack = 3,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = { "Fireball", "Blizzard", "LightningBolt", "ArcaneSurge" },
		DefaultLoadout = { "Fireball", "Blizzard", "LightningBolt", "ArcaneSurge" },
		Subclasses = {},
	},
}
