--[[
	Minions (ModuleScript)
	Location: ReplicatedStorage > Shared > Config > Minions

	Creatures the Summoner raises in a fight (Effect "Raise"). They fight on the party's side, can be hit, and can die.
	A minion's strength comes from its summoner when it is raised (see StatCalc.NewMinion):
	  MaxHealth = summoner max health x HealthFrac x power      Attack = summoner Attack x AttackFrac x power
	  Defense   = summoner Defense x DefenseFrac                power = 1 + the summoner's MinionPower stat (and the skill's level)

	  Look        { Shape, Color, Size } for the client model (Shape: Biped | Ball | Mushroom)
	  Taunt       enemies must hit it first
	  Leech       fraction of the damage it deals that heals its summoner
	  Abilities   skill slots it casts on its own (Config/Abilities, Class "Minion")
	  Lifetime    seconds before it fades on its own (default 20)
	A minion dies when its summoner does, when its Lifetime runs out, or when it is killed.
]]

return {
	Imp = {
		Id = "Imp",
		DisplayName = "Imp",
		Look = { Shape = "Biped", Color = { 230, 80, 60 }, Size = 2.4 },
		DamageType = "Magical",
		HealthFrac = 0.16, AttackFrac = 0.55, DefenseFrac = 0.3, AttackSpeed = 1.2,
	},
	Skeleton = {
		Id = "Skeleton",
		DisplayName = "Skeleton",
		Look = { Shape = "Biped", Color = { 226, 222, 200 }, Size = 3.4 },
		DamageType = "Physical",
		HealthFrac = 0.4, AttackFrac = 0.45, DefenseFrac = 1.2, AttackSpeed = 0.9,
		Taunt = true,
	},
	Wraith = {
		Id = "Wraith",
		DisplayName = "Wraith",
		Look = { Shape = "Ball", Color = { 120, 210, 190 }, Size = 2.4 },
		DamageType = "Magical",
		HealthFrac = 0.11, AttackFrac = 0.5, DefenseFrac = 0, AttackSpeed = 1.5,
	},
	Ghoul = {
		Id = "Ghoul",
		DisplayName = "Ghoul",
		Look = { Shape = "Biped", Color = { 110, 170, 90 }, Size = 3.0 },
		DamageType = "Physical",
		HealthFrac = 0.28, AttackFrac = 0.6, DefenseFrac = 0.5, AttackSpeed = 1.0,
		Leech = 0.4,
	},
	BoneTitan = {
		Id = "BoneTitan",
		DisplayName = "Bone Titan",
		Look = { Shape = "Biped", Color = { 205, 198, 170 }, Size = 6 },
		DamageType = "Physical",
		HealthFrac = 0.9, AttackFrac = 1.1, DefenseFrac = 1.5, AttackSpeed = 0.7,
		Taunt = true,
	},
	SpiritGuardian = {
		Id = "SpiritGuardian",
		DisplayName = "Guardian Spirit",
		Look = { Shape = "Ball", Color = { 170, 245, 235 }, Size = 2.6 },
		DamageType = "Magical",
		HealthFrac = 0.3, AttackFrac = 0.5, DefenseFrac = 0.5, AttackSpeed = 0.6,
		Abilities = { { Id = "Minion_SpiritMend", Level = 1, Timer = 1 } },
	},
}
