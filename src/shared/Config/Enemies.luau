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
		BaseStats = { MaxHealth = 65, Attack = 8, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 }, -- AttackSpeed was 1.1 (zone 10 wall)
		Abilities = { { Id = "Thunderclap", Level = 1, Timer = 5 } },
	},
	SkyHarpy = {
		Id = "SkyHarpy", DisplayName = "Sky Harpy",
		Look = { Shape = "Bird", Color = { 150, 200, 240 }, Size = 4.5 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 8, Defense = 3, AttackSpeed = 1.05, CritChance = 0.03 }, -- was Attack 9, AttackSpeed 1.2: zone 10 walled most runs at stage 91-100 (BALANCE.md "Zone 10")
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

	-- Stage 101-200 monsters (the elemental / magical zones; Config/Stages ZonePools 11-20) ----------------
	StormHound = {
		Id = "StormHound", DisplayName = "Storm Hound",
		Look = { Shape = "Beast", Color = { 70, 110, 180 }, Size = 4.2, Material = "Neon", Transparency = 0.15, Glow = { 140, 200, 255 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 80, Attack = 9, Defense = 4, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 4 } },
	},
	ThunderHawk = {
		Id = "ThunderHawk", DisplayName = "Thunder Hawk",
		Look = { Shape = "Bird", Color = { 250, 220, 90 }, Size = 4.5, Glow = { 255, 230, 120 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 68, Attack = 9, Defense = 3, AttackSpeed = 1.2, CritChance = 0.03 },
		Abilities = { { Id = "Swoop", Level = 1, Timer = 3 } },
	},
	VoltWisp = {
		Id = "VoltWisp", DisplayName = "Volt Wisp",
		Look = { Shape = "Elemental", Color = { 140, 220, 255 }, Size = 3.5, Material = "Neon", Glow = { 140, 220, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 62, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Thunderclap", Level = 1, Timer = 5 } },
	},
	ReefCrab = {
		Id = "ReefCrab", DisplayName = "Reef Crab",
		Look = { Shape = "Crab", Color = { 240, 120, 90 }, Size = 3.6 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 100, Attack = 7, Defense = 8, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "ShellGuard", Level = 1, Timer = 5 } },
	},
	GlowEel = {
		Id = "GlowEel", DisplayName = "Glow Eel",
		Look = { Shape = "Serpent", Color = { 60, 200, 190 }, Size = 5, Glow = { 90, 230, 220 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 72, Attack = 8, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 4 } },
	},
	Jellyfish = {
		Id = "Jellyfish", DisplayName = "Jellyfish",
		Look = { Shape = "Wraith", Color = { 255, 140, 210 }, Size = 4.5, Material = "Neon", Transparency = 0.35, Glow = { 255, 150, 220 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 70, Attack = 8, Defense = 2, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 4 } },
	},
	FlameHawk = {
		Id = "FlameHawk", DisplayName = "Flame Hawk",
		Look = { Shape = "Bird", Color = { 255, 120, 40 }, Size = 4.5, Material = "Neon", Glow = { 255, 140, 60 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 68, Attack = 9, Defense = 3, AttackSpeed = 1.2, CritChance = 0.03 },
		Abilities = { { Id = "Swoop", Level = 1, Timer = 3 } },
	},
	CinderGolem = {
		Id = "CinderGolem", DisplayName = "Cinder Golem",
		Look = { Shape = "Golem", Color = { 70, 44, 40 }, Size = 6, Glow = { 255, 110, 40 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 138, Attack = 7, Defense = 10, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 } },
	},
	Salamander = {
		Id = "Salamander", DisplayName = "Salamander",
		Look = { Shape = "Serpent", Color = { 230, 90, 50 }, Size = 4.6, Glow = { 255, 120, 60 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 70, Attack = 8, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 4 } },
	},
	Shroomling = {
		Id = "Shroomling", DisplayName = "Glowshroom",
		Look = { Shape = "Mushroom", Color = { 90, 230, 160 }, Size = 3.8, Glow = { 110, 255, 180 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 78, Attack = 7, Defense = 4, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 3 } },
	},
	GlowMoth = {
		Id = "GlowMoth", DisplayName = "Glow Moth",
		Look = { Shape = "Bat", Color = { 200, 255, 190 }, Size = 3.2, Material = "Neon", Glow = { 200, 255, 190 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 48, Attack = 7, Defense = 1, AttackSpeed = 1.5, CritChance = 0.03 },
		Abilities = { { Id = "Screech", Level = 1, Timer = 5 } },
	},
	SporeBeetle = {
		Id = "SporeBeetle", DisplayName = "Spore Beetle",
		Look = { Shape = "Crab", Color = { 70, 140, 110 }, Size = 3.6, Glow = { 110, 255, 180 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 98, Attack = 7, Defense = 8, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "ShellGuard", Level = 1, Timer = 5 } },
	},
	IceWraith = {
		Id = "IceWraith", DisplayName = "Ice Wraith",
		Look = { Shape = "Wraith", Color = { 150, 235, 255 }, Size = 5, Material = "Glass", Transparency = 0.25, Glow = { 150, 235, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 80, Attack = 8, Defense = 3, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "FrostBreath", Level = 1, Timer = 5 } },
	},
	FrostBear = {
		Id = "FrostBear", DisplayName = "Frost Bear",
		Look = { Shape = "Golem", Color = { 220, 235, 250 }, Size = 6.4, Fur = true },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 132, Attack = 9, Defense = 7, AttackSpeed = 0.7, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 } },
	},
	AuroraFox = {
		Id = "AuroraFox", DisplayName = "Aurora Fox",
		Look = { Shape = "Beast", Color = { 90, 240, 190 }, Size = 3.8, Glow = { 90, 255, 200 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 74, Attack = 9, Defense = 3, AttackSpeed = 1.2, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 4 } },
	},
	StarSprite = {
		Id = "StarSprite", DisplayName = "Star Sprite",
		Look = { Shape = "Elemental", Color = { 220, 220, 255 }, Size = 3.4, Material = "Neon", Glow = { 220, 220, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 62, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Thunderclap", Level = 1, Timer = 5 } },
	},
	MeteorGolem = {
		Id = "MeteorGolem", DisplayName = "Meteor Golem",
		Look = { Shape = "Golem", Color = { 70, 60, 100 }, Size = 6, Glow = { 160, 140, 255 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 136, Attack = 7, Defense = 9, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "BoulderToss", Level = 1, Timer = 6 } },
	},
	CometSerpent = {
		Id = "CometSerpent", DisplayName = "Comet Serpent",
		Look = { Shape = "Serpent", Color = { 150, 170, 255 }, Size = 5, Material = "Neon", Transparency = 0.1, Glow = { 150, 170, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 70, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 4 } },
	},
	VoidStalker = {
		Id = "VoidStalker", DisplayName = "Void Stalker",
		Look = { Shape = "Beast", Color = { 36, 24, 52 }, Size = 4.2, Glow = { 180, 80, 255 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 78, Attack = 9, Defense = 4, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "FeralPounce", Level = 1, Timer = 4 } },
	},
	Shade = {
		Id = "Shade", DisplayName = "Shade",
		Look = { Shape = "Wraith", Color = { 60, 30, 90 }, Size = 5, Transparency = 0.3, Glow = { 170, 80, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 80, Attack = 8, Defense = 3, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 4 } },
	},
	VoidWeaver = {
		Id = "VoidWeaver", DisplayName = "Void Weaver",
		Look = { Shape = "Spider", Color = { 40, 26, 60 }, Size = 3.8, Glow = { 190, 90, 255 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 64, Attack = 7, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "WebShot", Level = 1, Timer = 3 } },
	},
	Sentinel = {
		Id = "Sentinel", DisplayName = "Sun Sentinel",
		Look = { Shape = "Golem", Color = { 240, 230, 200 }, Size = 6, Material = "Marble", Glow = { 255, 225, 140 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 140, Attack = 7, Defense = 10, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 } },
	},
	Seraph = {
		Id = "Seraph", DisplayName = "Seraph",
		Look = { Shape = "Bird", Color = { 255, 225, 140 }, Size = 4.6, Material = "Foil", Glow = { 255, 235, 160 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 70, Attack = 9, Defense = 3, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Swoop", Level = 1, Timer = 3 } },
	},
	LightWisp = {
		Id = "LightWisp", DisplayName = "Light Wisp",
		Look = { Shape = "Elemental", Color = { 255, 240, 180 }, Size = 3.4, Material = "Neon", Glow = { 255, 240, 180 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 62, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "Thunderclap", Level = 1, Timer = 5 } },
	},
	BubbleSlime = {
		Id = "BubbleSlime", DisplayName = "Bubble Slime",
		Look = { Shape = "Ball", Color = { 255, 150, 200 }, Size = 3 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 70, Attack = 7, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 4 } },
	},
	JellySlime = {
		Id = "JellySlime", DisplayName = "Jelly Slime",
		Look = { Shape = "Ball", Color = { 130, 190, 255 }, Size = 3.4 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 90, Attack = 7, Defense = 5, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "ShellGuard", Level = 1, Timer = 5 } },
	},
	GummyFrog = {
		Id = "GummyFrog", DisplayName = "Gummy Frog",
		Look = { Shape = "Frog", Color = { 255, 170, 90 }, Size = 3.5, Material = "Glass", Transparency = 0.15 },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 72, Attack = 8, Defense = 3, AttackSpeed = 1.0, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 3 } },
	},
	FlyingTome = {
		Id = "FlyingTome", DisplayName = "Flying Tome",
		Look = { Shape = "Bat", Color = { 120, 80, 60 }, Size = 3.2 },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 52, Attack = 8, Defense = 1, AttackSpeed = 1.4, CritChance = 0.03 },
		Abilities = { { Id = "Screech", Level = 1, Timer = 5 } },
	},
	RuneGolem = {
		Id = "RuneGolem", DisplayName = "Rune Golem",
		Look = { Shape = "Golem", Color = { 80, 86, 116 }, Size = 6, Glow = { 110, 170, 255 } },
		IsBoss = false, DamageType = "Physical",
		BaseStats = { MaxHealth = 136, Attack = 7, Defense = 9, AttackSpeed = 0.6, CritChance = 0.03 },
		Abilities = { { Id = "BoulderToss", Level = 1, Timer = 6 } },
	},
	ArcaneWisp = {
		Id = "ArcaneWisp", DisplayName = "Arcane Wisp",
		Look = { Shape = "Elemental", Color = { 110, 170, 255 }, Size = 3.4, Material = "Neon", Glow = { 110, 170, 255 } },
		IsBoss = false, DamageType = "Magical",
		BaseStats = { MaxHealth = 62, Attack = 8, Defense = 2, AttackSpeed = 1.1, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 4 } },
	},

	-- Stage 101-200 bosses (Config/Zones Boss) ----------------
	ThunderTitan = {
		Id = "ThunderTitan", DisplayName = "Thunder Titan",
		Look = { Shape = "Golem", Color = { 60, 66, 90 }, Size = 9, Glow = { 140, 200, 255 } },
		IsBoss = true, DamageType = "Physical",
		BaseStats = { MaxHealth = 650, Attack = 11, Defense = 9, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "GroundPound", Level = 1, Timer = 6 }, { Id = "Thunderclap", Level = 1, Timer = 10 }, { Id = "Stagger", Level = 1, Timer = 13 }, { Id = "Enrage", Level = 1 } },
	},
	Leviathan = {
		Id = "Leviathan", DisplayName = "Leviathan",
		Look = { Shape = "Serpent", Color = { 30, 90, 140 }, Size = 9, Glow = { 90, 220, 230 } },
		IsBoss = true, DamageType = "Physical",
		BaseStats = { MaxHealth = 640, Attack = 11, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 5 }, { Id = "Stagger", Level = 1, Timer = 11 }, { Id = "Enrage", Level = 1 } },
	},
	Phoenix = {
		Id = "Phoenix", DisplayName = "The Phoenix",
		Look = { Shape = "Bird", Color = { 255, 120, 40 }, Size = 9, Material = "Neon", Glow = { 255, 150, 60 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 630, Attack = 12, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 5 }, { Id = "Swoop", Level = 1, Timer = 8 }, { Id = "Enrage", Level = 1 } },
	},
	ElderMycelid = {
		Id = "ElderMycelid", DisplayName = "Elder Mycelid",
		Look = { Shape = "Mushroom", Color = { 60, 200, 150 }, Size = 9, Glow = { 110, 255, 180 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 660, Attack = 10, Defense = 9, AttackSpeed = 0.7, CritChance = 0.03 },
		Abilities = { { Id = "SporeCall", Level = 1, Timer = 5 }, { Id = "SporeBurst", Level = 1, Timer = 10 }, { Id = "Enrage", Level = 1 } },
	},
	FrostWyrm = {
		Id = "FrostWyrm", DisplayName = "Frost Wyrm",
		Look = { Shape = "Serpent", Color = { 170, 220, 250 }, Size = 9, Material = "Ice", Glow = { 170, 230, 255 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 640, Attack = 11, Defense = 9, AttackSpeed = 0.85, CritChance = 0.03 },
		Abilities = { { Id = "FrostBreath", Level = 1, Timer = 5 }, { Id = "Stagger", Level = 1, Timer = 12 }, { Id = "Enrage", Level = 1 } },
	},
	AstralWatcher = {
		Id = "AstralWatcher", DisplayName = "Astral Watcher",
		Look = { Shape = "Wraith", Color = { 110, 100, 200 }, Size = 9, Material = "Neon", Transparency = 0.15, Glow = { 160, 150, 255 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 630, Attack = 11, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 6 }, { Id = "Screech", Level = 1, Timer = 14 }, { Id = "Enrage", Level = 1 } },
	},
	VoidHerald = {
		Id = "VoidHerald", DisplayName = "Void Herald",
		Look = { Shape = "Biped", Color = { 34, 22, 50 }, Size = 9, Glow = { 180, 80, 255 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 650, Attack = 12, Defense = 8, AttackSpeed = 0.85, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 6 }, { Id = "Stagger", Level = 1, Timer = 10 }, { Id = "Enrage", Level = 1 } },
	},
	SolarArchon = {
		Id = "SolarArchon", DisplayName = "Solar Archon",
		Look = { Shape = "Elemental", Color = { 255, 215, 110 }, Size = 9, Material = "Neon", Glow = { 255, 225, 140 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 640, Attack = 12, Defense = 8, AttackSpeed = 0.9, CritChance = 0.03 },
		Abilities = { { Id = "EmberBolt", Level = 1, Timer = 5 }, { Id = "Thunderclap", Level = 1, Timer = 9 }, { Id = "Enrage", Level = 1 } },
	},
	ArcaneLich = {
		Id = "ArcaneLich", DisplayName = "Arcane Lich",
		Look = { Shape = "Skeleton", Color = { 130, 110, 200 }, Size = 9, Glow = { 120, 170, 255 } },
		IsBoss = true, DamageType = "Magical",
		BaseStats = { MaxHealth = 640, Attack = 11, Defense = 9, AttackSpeed = 0.8, CritChance = 0.03 },
		Abilities = { { Id = "ShadowDrain", Level = 1, Timer = 6 }, { Id = "BoneRattle", Level = 1, Timer = 10 }, { Id = "Thunderclap", Level = 1, Timer = 16 }, { Id = "Enrage", Level = 1 } },
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
