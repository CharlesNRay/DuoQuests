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
	},
}
