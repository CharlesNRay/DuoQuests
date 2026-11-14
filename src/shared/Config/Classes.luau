--[[
	Classes (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Classes

	Every number here is a PLACEHOLDER to be tuned during playtesting.

	Subclasses: empty for now. When subclasses arrive, each entry goes here as
	Subclasses = { Berserker = { ...stat tweaks, extra abilities... } } and a
	player's chosen subclass is stored as Season.SubclassId (absent until chosen).
	Nothing else needs restructuring.

	AbilityPool lists ability IDs by name. The matching ability definitions
	(cooldowns, damage, effects) are added in the combat phase.
]]

return {
	Warrior = {
		Id = "Warrior",
		DisplayName = "Warrior",
		Role = "Tank",
		DamageType = "Physical",

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

		AbilityPool = { "ShieldBash", "Taunt", "Whirlwind", "LastStand" },
		Subclasses = {},
	},

	Mage = {
		Id = "Mage",
		DisplayName = "Mage",
		Role = "Damage",
		DamageType = "Magical",

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
		Subclasses = {},
	},
}
