--[[
	Abilities (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Abilities

	Every combatant fights with up to four equipped abilities. They cast
	AUTOMATICALLY: when an ability's cooldown is over and its Conditions are
	met, it is used. Equipped abilities are checked in slot order (slot 1 has
	priority) and at most one is cast per combatant per tick. Abilities start
	ready at the beginning of a fight.

	Fields
	  Rarity      "Common", "Rare" or "Epic" (Config/Rarities): sets the max
	              level and how much power each level adds
	  Cooldown    seconds between casts
	  Conditions  optional rules that must ALL be true before casting:
	                MinEnemies = n          at least n enemies are alive
	                SelfHealthBelow = f     own health fraction is below f (0-1)
	                AllyHealthBelow = f     any living ally (or self) is below f
	                SelfLacksStatus = id    does not already have that status
	  Effects     list, run in order when cast. Each has a Type and a Target.
	                Damage       Multiplier x the caster's Attack
	                Heal         Multiplier x caster's Attack, plus
	                             PercentMaxHealth x the target's max health
	                Shield       same amounts as Heal, applied as an absorb
	                             shield lasting Duration seconds
	                ApplyStatus  Status, Duration
	              Targets: "Primary" (the normal attack target, so Taunt is
	              respected), "Self", "AllEnemies", "AllAllies", "LowestAlly".
	  LevelBonus  optional: overrides the rarity's PowerPerLevel
	  Element     optional tag ("Fire", "Holy"...) for seasonal mechanics to
	              react to; it does nothing by itself yet

	Warrior skills are about tanking: damage with a defensive rider, shields,
	defense buffs and Taunt. Cleric skills are about healing and protection,
	with a little damage. Both have damage and utility options.

	New effect types and conditions are added in Combat/Simulation by
	registering them (Simulation.Effects / Simulation.Conditions).

	Every number here is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	-- Warrior ----------------------------------------------------------------------
	ShieldBash = {
		Id = "ShieldBash",
		DisplayName = "Shield Bash",
		Description = "Deals damage and generates defense.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 6,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.4 },
			{ Type = "ApplyStatus", Target = "Self", Status = "Fortified", Duration = 5 },
		},
	},

	Taunt = {
		Id = "Taunt",
		DisplayName = "Taunt",
		Description = "Redirects enemy attacks toward the Warrior.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 12,
		Conditions = { SelfLacksStatus = "Taunting" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Taunting", Duration = 6 },
		},
	},

	IronSkin = {
		Id = "IronSkin",
		DisplayName = "Iron Skin",
		Description = "Greatly increases the Warrior's defense.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 16,
		Conditions = { SelfLacksStatus = "IronSkin" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "IronSkin", Duration = 8 },
		},
	},

	Whirlwind = {
		Id = "Whirlwind",
		DisplayName = "Whirlwind",
		Description = "Deals area damage to all enemies.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 8,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.9 },
		},
	},

	ShieldWall = {
		Id = "ShieldWall",
		DisplayName = "Shield Wall",
		Description = "Raises a shield worth a third of max health and fortifies defense.",
		Class = "Warrior",
		Rarity = "Rare",
		Cooldown = 20,
		Effects = {
			{ Type = "Shield", Target = "Self", PercentMaxHealth = 0.3, Duration = 10 },
			{ Type = "ApplyStatus", Target = "Self", Status = "Fortified", Duration = 8 },
		},
	},

	CrushingBlow = {
		Id = "CrushingBlow",
		DisplayName = "Crushing Blow",
		Description = "A heavy blow on a single enemy.",
		Class = "Warrior",
		Rarity = "Rare",
		Cooldown = 9,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.4 },
		},
	},

	LastStand = {
		Id = "LastStand",
		DisplayName = "Last Stand",
		Description = "Temporarily prevents lethal damage.",
		Class = "Warrior",
		Rarity = "Epic",
		Cooldown = 30,
		Conditions = { SelfHealthBelow = 0.5 },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "LastStand", Duration = 4 },
		},
	},

	RallyingCry = {
		Id = "RallyingCry",
		DisplayName = "Rallying Cry",
		Description = "Increases the whole party's defense.",
		Class = "Warrior",
		Rarity = "Epic",
		Cooldown = 20,
		Conditions = { SelfLacksStatus = "Rallied" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Rallied", Duration = 8 },
		},
	},

	-- Cleric -----------------------------------------------------------------------
	Smite = {
		Id = "Smite",
		DisplayName = "Smite",
		Description = "Strikes an enemy with holy light.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 3,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.5, DamageType = "Magical" },
		},
	},

	Heal = {
		Id = "Heal",
		DisplayName = "Heal",
		Description = "Heals the most wounded ally when someone is hurt.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 4,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 2.5 },
		},
	},

	Blessing = {
		Id = "Blessing",
		DisplayName = "Blessing",
		Description = "Increases the whole party's attack.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 15,
		Conditions = { SelfLacksStatus = "Blessed" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Blessed", Duration = 8 },
		},
	},

	RadiantBurst = {
		Id = "RadiantBurst",
		DisplayName = "Radiant Burst",
		Description = "Damages all enemies and heals all allies.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 10,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.8, DamageType = "Magical" },
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.6 },
		},
	},

	DivineShield = {
		Id = "DivineShield",
		DisplayName = "Divine Shield",
		Description = "Shields the most wounded ally.",
		Class = "Cleric",
		Rarity = "Rare",
		Cooldown = 12,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.9 },
		Effects = {
			{ Type = "Shield", Target = "LowestAlly", Multiplier = 1.5, PercentMaxHealth = 0.15, Duration = 8 },
		},
	},

	GroupHeal = {
		Id = "GroupHeal",
		DisplayName = "Group Heal",
		Description = "Heals the whole party when several allies are hurt.",
		Class = "Cleric",
		Rarity = "Rare",
		Cooldown = 14,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.6 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.5 },
		},
	},

	GuardianAngel = {
		Id = "GuardianAngel",
		DisplayName = "Guardian Angel",
		Description = "Protects a dying ally from lethal damage.",
		Class = "Cleric",
		Rarity = "Epic",
		Cooldown = 30,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.35 },
		Effects = {
			{ Type = "ApplyStatus", Target = "LowestAlly", Status = "GuardianAngel", Duration = 4 },
		},
	},

	Judgment = {
		Id = "Judgment",
		DisplayName = "Judgment",
		Description = "Calls down devastating holy damage on one enemy.",
		Class = "Cleric",
		Rarity = "Epic",
		Cooldown = 14,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 3.2, DamageType = "Magical" },
		},
	},

	-- Mage (deferred; kept so the data model stays proven for a damage class) ----
	Fireball = {
		Id = "Fireball",
		DisplayName = "Fireball",
		Description = "Deals magical damage.",
		Class = "Mage",
		Rarity = "Common",
		Cooldown = 5,
		Element = "Fire",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, DamageType = "Magical" },
		},
	},

	Blizzard = {
		Id = "Blizzard",
		DisplayName = "Blizzard",
		Description = "Deals damage and slows all enemies.",
		Class = "Mage",
		Rarity = "Rare",
		Cooldown = 10,
		Element = "Ice",
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.9, DamageType = "Magical" },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Chilled", Duration = 4 },
		},
	},

	LightningBolt = {
		Id = "LightningBolt",
		DisplayName = "Lightning Bolt",
		Description = "Deals high single-target damage.",
		Class = "Mage",
		Rarity = "Rare",
		Cooldown = 10,
		Element = "Lightning",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 3.2, DamageType = "Magical" },
		},
	},

	ArcaneSurge = {
		Id = "ArcaneSurge",
		DisplayName = "Arcane Surge",
		Description = "Temporarily increases magical damage.",
		Class = "Mage",
		Rarity = "Epic",
		Cooldown = 14,
		Conditions = { SelfLacksStatus = "ArcaneSurge" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "ArcaneSurge", Duration = 6 },
		},
	},
}
