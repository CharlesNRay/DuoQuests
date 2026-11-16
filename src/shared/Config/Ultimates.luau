--[[
	Ultimates (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Ultimates

	A party ultimate is a big move that BOTH members use, decided by the
	COMBINATION of their two classes. The party shares one charge gauge that
	fills over time and with every skill either member casts. When it is full
	the ultimate fires by itself, cast by the first living party member.

	  ChargeNeeded     gauge size
	  ChargePerSecond  charge gained per second of fight time
	  ChargePerCast    charge gained each time a party skill is cast
	  Pairs            [pairKey] = list of ultimate ids that pair can use.
	                   pairKey is the two class ids sorted and joined with "+"
	                   ("Cleric+Warrior"); see Shared/Ultimates.
	  Defs             the ultimates. Same shape as an ability (Effects with
	                   PerLevel, targets, statuses) plus:
	                     UnlockStage  the party's frontier needed to use it
	                   The ultimate's level is the average slot level of the
	                   two members, so a stronger party hits harder.

	The party picks which unlocked ultimate to equip (either member may change
	it). A party always has the first one available.

	Every number here is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	ChargeNeeded = 100,
	ChargePerSecond = 1.5,
	ChargePerCast = 6,

	Pairs = {
		["Cleric+Warrior"] = { "SanctifiedCharge", "BulwarkOfDawn", "RadiantJudgment" },
		["Cleric+Mage"] = { "HolyCataclysm" },
		["Cleric+Ranger"] = { "BlessedBarrage" },
		["Cleric+Rogue"] = { "SacredBlades" },
		["Cleric+Summoner"] = { "SpiritChoir" },
		["Mage+Ranger"] = { "ArcaneArrowstorm" },
		["Mage+Rogue"] = { "Shadowflame" },
		["Mage+Summoner"] = { "SpectralTempest" },
		["Mage+Warrior"] = { "RunicSmash" },
		["Ranger+Rogue"] = { "HailOfBlades" },
		["Ranger+Summoner"] = { "WildHunt" },
		["Ranger+Warrior"] = { "WarbandVolley" },
		["Rogue+Summoner"] = { "ShadowLegion" },
		["Rogue+Warrior"] = { "DuelOfSteel" },
		["Summoner+Warrior"] = { "GraveGuard" },
	},

	Defs = {
		SanctifiedCharge = {
			Id = "SanctifiedCharge",
			DisplayName = "Sanctified Charge",
			Description = "Smites every enemy and heals the whole party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.0,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.2 },
				},
				{ Type = "Heal", Target = "AllAllies", PercentMaxHealth = 0.25, PerLevel = { PercentMaxHealth = 0.01 } },
			},
		},

		BulwarkOfDawn = {
			Id = "BulwarkOfDawn",
			DisplayName = "Bulwark of Dawn",
			Description = "Shields the whole party and slows every enemy.",
			Rarity = "Epic",
			UnlockStage = 40,
			Element = "Holy",
			Effects = {
				{
					Type = "Shield",
					Target = "AllAllies",
					PercentMaxHealth = 0.30,
					Duration = 8,
					PerLevel = { PercentMaxHealth = 0.012, Duration = 0.2 },
				},
				{
					Type = "ApplyStatus",
					Target = "AllEnemies",
					Status = "Chilled",
					Duration = 6,
					PerLevel = { Duration = 0.2, Strength = 0.03 },
				},
			},
		},

		RadiantJudgment = {
			Id = "RadiantJudgment",
			DisplayName = "Radiant Judgment",
			Description = "Devastating holy damage to all enemies and a party attack bonus.",
			Rarity = "Epic",
			UnlockStage = 80,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 7.0,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.3 },
				},
				{
					Type = "ApplyStatus",
					Target = "AllAllies",
					Status = "Blessed",
					Duration = 10,
					PerLevel = { Duration = 0.3, Strength = 0.03 },
				},
			},
		},

		HolyCataclysm = {
			Id = "HolyCataclysm",
			DisplayName = "Holy Cataclysm",
			Description = "A column of holy fire smites every enemy and mends the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "Heal", Target = "AllAllies", PercentMaxHealth = 0.2, PerLevel = { PercentMaxHealth = 0.01 } },
			},
		},

		BlessedBarrage = {
			Id = "BlessedBarrage",
			DisplayName = "Blessed Barrage",
			Description = "Blessed arrows rain on every enemy and bless the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllAllies", Status = "Blessed", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		SacredBlades = {
			Id = "SacredBlades",
			DisplayName = "Sacred Blades",
			Description = "Holy blades cut every enemy while the party is warded.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.22, Duration = 8, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			},
		},

		SpiritChoir = {
			Id = "SpiritChoir",
			DisplayName = "Spirit Choir",
			Description = "A choir of spirits strikes every enemy and shields the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Holy",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.22, Duration = 8, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			},
		},

		ArcaneArrowstorm = {
			Id = "ArcaneArrowstorm",
			DisplayName = "Arcane Arrowstorm",
			Description = "Arrows of pure magic hit every enemy and mark them.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Arcane",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Marked", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		Shadowflame = {
			Id = "Shadowflame",
			DisplayName = "Shadowflame",
			Description = "Dark fire scorches every enemy and keeps burning.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Fire",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Burning", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		SpectralTempest = {
			Id = "SpectralTempest",
			DisplayName = "Spectral Tempest",
			Description = "A tempest of spirits batters and curses every enemy.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Shadow",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Cursed", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		RunicSmash = {
			Id = "RunicSmash",
			DisplayName = "Runic Smash",
			Description = "A runic hammer smashes every enemy and shields the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Arcane",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.22, Duration = 8, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			},
		},

		HailOfBlades = {
			Id = "HailOfBlades",
			DisplayName = "Hail of Blades",
			Description = "Knives and arrows fill the air; the party moves faster.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Physical",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllAllies", Status = "Hasted", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		WildHunt = {
			Id = "WildHunt",
			DisplayName = "Wild Hunt",
			Description = "The hunt rushes through every enemy and emboldens the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Nature",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllAllies", Status = "Emboldened", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		WarbandVolley = {
			Id = "WarbandVolley",
			DisplayName = "Warband Volley",
			Description = "A mighty volley hits every enemy; the party stands firm.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Physical",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllAllies", Status = "Fortified", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		ShadowLegion = {
			Id = "ShadowLegion",
			DisplayName = "Shadow Legion",
			Description = "A legion of shadows poisons every enemy.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Shadow",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Poisoned", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		DuelOfSteel = {
			Id = "DuelOfSteel",
			DisplayName = "Duel of Steel",
			Description = "Steel flashes across every enemy and the party is frenzied.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Physical",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Physical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "ApplyStatus", Target = "AllAllies", Status = "Frenzied", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
			},
		},

		GraveGuard = {
			Id = "GraveGuard",
			DisplayName = "Grave Guard",
			Description = "Spectral guards rise, curse the enemy and shield the party.",
			Rarity = "Epic",
			UnlockStage = 1,
			Element = "Shadow",
			Effects = {
				{
					Type = "Damage",
					Target = "AllEnemies",
					Multiplier = 4.5,
					DamageType = "Magical",
					PerLevel = { Multiplier = 0.25 },
				},
				{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.22, Duration = 8, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			},
		},
	},
}
