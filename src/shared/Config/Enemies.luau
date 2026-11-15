--[[
	Enemies (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Enemies

	Prototype roster: three regular enemies and one boss.
	Look is presentation only: { Shape = "Ball"|"Biped"|"Mushroom", Color = {r,g,b}, Size = studs tall },
	drawn from simple shapes until real assets replace them.
	Every number is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	Slime = {
		Id = "Slime",
		DisplayName = "Slime",
		Look = { Shape = "Ball", Color = { 110, 210, 110 }, Size = 3 },
		IsBoss = false,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 60, Attack = 6, Defense = 2, AttackSpeed = 0.8, CritChance = 0 },
	},

	Goblin = {
		Id = "Goblin",
		DisplayName = "Goblin",
		Look = { Shape = "Biped", Color = { 120, 170, 70 }, Size = 4.5 },
		IsBoss = false,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 80, Attack = 9, Defense = 4, AttackSpeed = 1.0, CritChance = 0.05 },
	},

	Mushroom = {
		Id = "Mushroom",
		DisplayName = "Mushroom",
		Look = { Shape = "Mushroom", Color = { 220, 90, 90 }, Size = 4 },
		IsBoss = false,
		DamageType = "Magical",
		BaseStats = { MaxHealth = 110, Attack = 7, Defense = 6, AttackSpeed = 0.7, CritChance = 0 },
	},

	SlimeKing = {
		Id = "SlimeKing",
		DisplayName = "Slime King",
		Look = { Shape = "Ball", Color = { 80, 190, 140 }, Size = 9 },
		IsBoss = true,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 600, Attack = 16, Defense = 10, AttackSpeed = 0.9, CritChance = 0.05 },
	},
}
