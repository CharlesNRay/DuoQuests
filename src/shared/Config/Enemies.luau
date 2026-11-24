--[[
	Enemies (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Enemies

	Prototype roster: three regular enemies and one boss.
	Look is presentation only: { Shape = "Ball"|"Biped"|"Mushroom", Color = {r,g,b}, Size = studs tall },
	drawn from simple shapes until real assets replace them.
	Every number is a PLACEHOLDER to be tuned during playtesting.
]]

local Economy = require(script.Parent.Economy)

local Enemies = {
	-- the Training Grounds dummy (Shared/TrainingDummy): cannot be killed, does not fight back, no armour
	TrainingDummy = {
		Id = "TrainingDummy",
		DisplayName = "Training Dummy",
		Look = { Shape = "Biped", Color = { 214, 190, 120 }, Size = 5 },
		IsBoss = true, EventOnly = true,
		DamageType = "Physical",
		BaseStats = { MaxHealth = 1e15, Attack = 0, Defense = 0, AttackSpeed = 0.01, CritChance = 0 },
	},

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
		Abilities = { { Id = "RustyStab", Level = 1, Timer = 5 } },
	},

	Mushroom = {
		Id = "Mushroom",
		DisplayName = "Mushroom",
		Look = { Shape = "Mushroom", Color = { 220, 90, 90 }, Size = 4 },
		IsBoss = false,
		DamageType = "Magical",
		BaseStats = { MaxHealth = 110, Attack = 7, Defense = 6, AttackSpeed = 0.7, CritChance = 0 },
		Abilities = { { Id = "SporeCloud", Level = 1, Timer = 5 } },
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
		Abilities = { { Id = "BossCrush", Level = 1, Timer = 8 }, { Id = "Stagger", Level = 1, Timer = 14 }, { Id = "Enrage", Level = 1 } },
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

	-- Regular monsters by zone (see Config/Stages ZonePools) --------------------------------
	Wolf = {
		Id = "Wolf", DisplayName = "Wolf",
		Look = { Shape = "Beast", Color = { 120, 120, 130 }, Size = 4 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 75, Attack = 9, Defense = 3, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 4 } },
	},
	Boar = {
		Id = "Boar", DisplayName = "Wild Boar",
		Look = { Shape = "Beast", Color = { 130, 90, 70 }, Size = 4, Tusks = true },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 105, Attack = 8, Defense = 6, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 6 } },
	},
	Spider = {
		Id = "Spider", DisplayName = "Forest Spider",
		Look = { Shape = "Spider", Color = { 80, 60, 90 }, Size = 3.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 62, Attack = 7, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "WebShot", Level = 1, Timer = 3 } },
	},
	RockGolem = {
		Id = "RockGolem", DisplayName = "Rock Golem",
		Look = { Shape = "Golem", Color = { 130, 125, 115 }, Size = 6 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 135, Attack = 7, Defense = 9, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "BoulderToss", Level = 1, Timer = 6 } },
	},
	Harpy = {
		Id = "Harpy", DisplayName = "Harpy",
		Look = { Shape = "Bird", Color = { 170, 130, 190 }, Size = 4.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 65, Attack = 8, Defense = 2, AttackSpeed = 1.2, CritChance = 0.03 },
		Abilities = { { Id = "Swoop", Level = 1, Timer = 3 } },
	},
	Bat = {
		Id = "Bat", DisplayName = "Cave Bat",
		Look = { Shape = "Bat", Color = { 90, 70, 110 }, Size = 3 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 45, Attack = 6, Defense = 1, AttackSpeed = 1.5, CritChance = 0.03 },
	},
	Wraith = {
		Id = "Wraith", DisplayName = "Wraith",
		Look = { Shape = "Wraith", Color = { 150, 150, 200 }, Size = 5 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 80, Attack = 8, Defense = 3, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 4 } },
	},
	CrystalBeetle = {
		Id = "CrystalBeetle", DisplayName = "Crystal Beetle",
		Look = { Shape = "Crab", Color = { 160, 110, 230 }, Size = 3.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 95, Attack = 7, Defense = 8, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "ShellGuard", Level = 1, Timer = 5 } },
	},
	Scorpion = {
		Id = "Scorpion", DisplayName = "Dune Scorpion",
		Look = { Shape = "Scorpion", Color = { 200, 150, 80 }, Size = 3.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 9, Defense = 4, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "SandSting", Level = 1, Timer = 4 } },
	},
	Mummy = {
		Id = "Mummy", DisplayName = "Mummy",
		Look = { Shape = "Skeleton", Color = { 200, 185, 150 }, Size = 5, Wrapped = true },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 100, Attack = 8, Defense = 5, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "CursedWrap", Level = 1, Timer = 5 } },
	},
	SandSerpent = {
		Id = "SandSerpent", DisplayName = "Sand Serpent",
		Look = { Shape = "Serpent", Color = { 210, 170, 90 }, Size = 5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 8, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 4 } },
	},
	SnowWolf = {
		Id = "SnowWolf", DisplayName = "Snow Wolf",
		Look = { Shape = "Beast", Color = { 235, 240, 250 }, Size = 4 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 80, Attack = 9, Defense = 4, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Howl", Level = 1, Timer = 5 } },
	},
	FrostImp = {
		Id = "FrostImp", DisplayName = "Frost Imp",
		Look = { Shape = "Elemental", Color = { 130, 200, 255 }, Size = 3.5 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 65, Attack = 7, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "FrostBreath", Level = 1, Timer = 5 } },
	},
	Yeti = {
		Id = "Yeti", DisplayName = "Yeti",
		Look = { Shape = "Golem", Color = { 225, 235, 245 }, Size = 6.5, Fur = true },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 130, Attack = 9, Defense = 7, AttackSpeed = 0.7, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 } },
	},
	FireElemental = {
		Id = "FireElemental", DisplayName = "Fire Elemental",
		Look = { Shape = "Elemental", Color = { 255, 120, 40 }, Size = 4 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 80, Attack = 9, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 4 } },
	},
	MagmaHound = {
		Id = "MagmaHound", DisplayName = "Magma Hound",
		Look = { Shape = "Beast", Color = { 230, 84, 38 }, Size = 4.2 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 110, Attack = 7, Defense = 9, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 4 } },
	},
	Imp = {
		Id = "Imp", DisplayName = "Ember Imp",
		Look = { Shape = "Bat", Color = { 220, 60, 50 }, Size = 3 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 55, Attack = 8, Defense = 2, AttackSpeed = 1.3, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 5 } },
	},
	Frog = {
		Id = "Frog", DisplayName = "Bog Frog",
		Look = { Shape = "Frog", Color = { 90, 150, 70 }, Size = 3.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 7, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 3 } },
	},
	BogWraith = {
		Id = "BogWraith", DisplayName = "Bog Wraith",
		Look = { Shape = "Wraith", Color = { 110, 170, 120 }, Size = 5 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 85, Attack = 8, Defense = 3, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 4 } },
	},
	Skeleton = {
		Id = "Skeleton", DisplayName = "Skeleton",
		Look = { Shape = "Skeleton", Color = { 225, 225, 205 }, Size = 5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 85, Attack = 9, Defense = 5, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "BoneRattle", Level = 1, Timer = 4 } },
	},
	Ghost = {
		Id = "Ghost", DisplayName = "Ruin Ghost",
		Look = { Shape = "Wraith", Color = { 210, 225, 235 }, Size = 5 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 75, Attack = 8, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "Screech", Level = 1, Timer = 5 } },
	},
	RuinGolem = {
		Id = "RuinGolem", DisplayName = "Ruin Golem",
		Look = { Shape = "Golem", Color = { 110, 150, 130 }, Size = 6 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 140, Attack = 7, Defense = 10, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 } },
	},
	StormSprite = {
		Id = "StormSprite", DisplayName = "Storm Sprite",
		Look = { Shape = "Elemental", Color = { 255, 235, 110 }, Size = 3.5, Hat = true },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 65, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Thunderclap", Level = 1, Timer = 5 } },
	},
	SkyHarpy = {
		Id = "SkyHarpy", DisplayName = "Sky Harpy",
		Look = { Shape = "Bird", Color = { 150, 200, 240 }, Size = 4.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 9, Defense = 3, AttackSpeed = 1.2, CritChance = 0.03 },
		Abilities = { { Id = "Swoop", Level = 1, Timer = 3 } },
	},

	-- More bosses
	DireWolf = {
		Id = "DireWolf", DisplayName = "Dire Wolf",
		Look = { Shape = "Beast", Color = { 70, 70, 85 }, Size = 9 },
		IsBoss = true, DamageType = "Physical",
		BaseStats = { MaxHealth = 640, Attack = 10.5, Defense = 9, AttackSpeed = 0.85, CritChance = 0.03 }, -- Attack was 12, AttackSpeed 1.0: the stage 40 wall (BALANCE.md)
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 6 }, { Id = "Stagger", Level = 1, Timer = 11 }, { Id = "Howl", Level = 1, Timer = 14 }, { Id = "Enrage", Level = 1 } },
	},
	Broodmother = {
		Id = "Broodmother", DisplayName = "Broodmother",
		Look = { Shape = "Spider", Color = { 60, 40, 80 }, Size = 9 },
		IsBoss = true, DamageType = "Physical",
		BaseStats = { MaxHealth = 620, Attack = 11, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "WebShot", Level = 1, Timer = 5 }, { Id = "PoisonSpit", Level = 1, Timer = 9 }, { Id = "Enrage", Level = 1 } },
	},
	-- the boss of Slime Meadows (Config/Zones Boss): a crowned slime that shifts through the rainbow
	RainbowSlime = {
		Id = "RainbowSlime", DisplayName = "Rainbow Slime",
		Look = { Shape = "Ball", Color = { 255, 120, 200 }, Size = 9, Rainbow = true, Crown = true },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 640, Attack = 12, Defense = 8, AttackSpeed = 0.95, CritChance = 0.05 },
		Abilities = { { Id = "SlimeSplit", Level = 1, Timer = 5 }, { Id = "Enrage", Level = 1 } },
	},
	LichKing = {
		Id = "LichKing", DisplayName = "Lich King",
		Look = { Shape = "Skeleton", Color = { 190, 200, 215 }, Size = 9 },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 640, Attack = 11, Defense = 9, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 6 }, { Id = "BoneRattle", Level = 1, Timer = 10 }, { Id = "Screech", Level = 1, Timer = 16 }, { Id = "Enrage", Level = 1 } },
	},
	InfernoLord = {
		Id = "InfernoLord", DisplayName = "Inferno Lord",
		Look = { Shape = "Elemental", Color = { 255, 100, 30 }, Size = 9 },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 650, Attack = 12, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 5 }, { Id = "GroundPound", Level = 1, Timer = 12 }, { Id = "Stagger", Level = 1, Timer = 9 }, { Id = "Enrage", Level = 1 } },
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
	-- Guild raid bosses (stats set by Shared/Bosses; fought from the guild's Raid tab)
	RaidTitan = {
		Id = "RaidTitan", DisplayName = "Stone Titan",
		Look = { Shape = "Golem", Color = { 130, 125, 120 }, Size = 13 },
		IsBoss = true, DamageType = "Physical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
	RaidWyrm = {
		Id = "RaidWyrm", DisplayName = "Tide Wyrm",
		Look = { Shape = "Serpent", Color = { 60, 140, 190 }, Size = 13 },
		IsBoss = true, DamageType = "Magical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
	RaidLich = {
		Id = "RaidLich", DisplayName = "Hollow Lich",
		Look = { Shape = "Skeleton", Color = { 150, 120, 200 }, Size = 12 },
		IsBoss = true, DamageType = "Magical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
	RaidPhoenix = {
		Id = "RaidPhoenix", DisplayName = "Ashen Phoenix",
		Look = { Shape = "Bird", Color = { 255, 140, 40 }, Size = 13 },
		IsBoss = true, DamageType = "Magical", EventOnly = true,
		BaseStats = { MaxHealth = 1, Attack = 1, Defense = 1, AttackSpeed = 1, CritChance = 0 },
	},
}

for _, enemy in pairs(Enemies) do
	for _, stat in ipairs({ "MaxHealth", "Attack", "Defense" }) do
		if enemy.BaseStats and enemy.BaseStats[stat] then
			enemy.BaseStats[stat] *= Economy.NumberScale
		end
	end
end

return Enemies
