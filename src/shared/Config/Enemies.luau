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
		-- Splits off 2 slimelets at 5s, 19s, 33s... (area skills clear them)
		Abilities = { { Id = "SlimeSplit", Level = 1, Timer = 5 } },
	},

	-- Minions (summoned by bosses, never appear on their own) ---------------------------
	Slimelet = {
		Id = "Slimelet",
		DisplayName = "Slimelet",
		Look = { Shape = "Ball", Color = { 130, 225, 150 }, Size = 1.8 },
		IsBoss = false,
		IsMinion = true,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 30, Attack = 4, Defense = 0, AttackSpeed = 1.0, CritChance = 0 },
	},

	Sporeling = {
		Id = "Sporeling",
		DisplayName = "Sporeling",
		Look = { Shape = "Mushroom", Color = { 200, 120, 200 }, Size = 2 },
		IsBoss = false,
		IsMinion = true,
		DamageType = "Magical",
		BaseStats = { MaxHealth = 36, Attack = 5, Defense = 1, AttackSpeed = 0.9, CritChance = 0 },
	},

	-- More bosses. Each tests a different part of your skill set ------------------------
	GoblinWarlord = {
		Id = "GoblinWarlord",
		DisplayName = "Goblin Warlord",
		Look = { Shape = "Biped", Color = { 90, 140, 50 }, Size = 8 },
		IsBoss = true,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 650, Attack = 12, Defense = 10, AttackSpeed = 0.8, CritChance = 0.05 },
		-- Crushing Blow lands at 8s, 19s, 30s... : time a shield before it, or a heal after it.
		Abilities = { { Id = "CrushingBlow", Level = 1, Timer = 8 }, { Id = "Enrage", Level = 1 } },
	},

	SporeMother = {
		Id = "SporeMother",
		DisplayName = "Spore Mother",
		Look = { Shape = "Mushroom", Color = { 170, 70, 170 }, Size = 9 },
		IsBoss = true,
		DamageType = "Magical",
		BaseStats = { MaxHealth = 650, Attack = 10, Defense = 9, AttackSpeed = 0.7, CritChance = 0 },
		Abilities = {
			{ Id = "SporeCall", Level = 1, Timer = 5 },
			{ Id = "SporeBurst", Level = 1, Timer = 10 },
			{ Id = "Enrage", Level = 1 },
		},
	},

	-- Event bosses (fought in your arena from the Boss window; stats are set by Shared/Bosses) ----
	WorldOgre = {
		Id = "WorldOgre", DisplayName = "Gloomhide Ogre",
		Look = { Shape = "Biped", Color = { 120, 90, 150 }, Size = 10 },
		IsBoss = true, DamageType = "Physical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
	Colossus = {
		Id = "Colossus", DisplayName = "Verdant Colossus",
		Look = { Shape = "Biped", Color = { 70, 140, 90 }, Size = 13 },
		IsBoss = true, DamageType = "Physical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
}
