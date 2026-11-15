--[[
	Enemies (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Enemies

	Prototype roster: three regular enemies and one boss.
	Every number is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	Slime = {
		Id = "Slime",
		DisplayName = "Slime",
		IsBoss = false,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 60, Attack = 6, Defense = 2, AttackSpeed = 0.8, CritChance = 0 },
	},

	Goblin = {
		Id = "Goblin",
		DisplayName = "Goblin",
		IsBoss = false,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 80, Attack = 9, Defense = 4, AttackSpeed = 1.0, CritChance = 0.05 },
	},

	Mushroom = {
		Id = "Mushroom",
		DisplayName = "Mushroom",
		IsBoss = false,
		DamageType = "Magical",
		BaseStats = { MaxHealth = 110, Attack = 7, Defense = 6, AttackSpeed = 0.7, CritChance = 0 },
	},

	SlimeKing = {
		Id = "SlimeKing",
		DisplayName = "Slime King",
		IsBoss = true,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 600, Attack = 16, Defense = 10, AttackSpeed = 0.9, CritChance = 0.05 },
	},
}
