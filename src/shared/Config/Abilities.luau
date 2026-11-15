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
	                AllyDead = true         an ally has fallen
	  Effects     list, run in order when cast. Each has a Type and a Target.
	                Damage       Multiplier x the caster's Attack
	                Revive       brings a fallen ally back (Target "DeadAlly") with
	                             HealthFraction of max health
	                Heal         Multiplier x caster's Attack, plus
	                             PercentMaxHealth x the target's max health
	                Shield       same amounts as Heal, applied as an absorb
	                             shield lasting Duration seconds
	                ApplyStatus  Status, Duration
	              Targets: "Primary" (the normal attack target, so Taunt is
	              respected), "Self", "AllEnemies", "AllAllies", "LowestAlly",
	              "DeadAlly".
	              PerLevel   every effect lists how each of ITS OWN fields grows
	              per slot level (Multiplier, PercentMaxHealth, Duration,
	              HealthFraction, Strength). Damage skills grow damage, defensive
	              skills grow shield size and duration, buffs grow duration and
	              Strength. See Combat/AbilityStats.
	  LevelBonus  optional: fallback power growth per level for effects that do
	              not list PerLevel (the rarity's PowerPerLevel otherwise)
	  CooldownPerLevel / MinCooldown
	              optional: seconds the cooldown changes per slot level (negative
	              to shorten) and its floor (default 1)
	  UsesPerCombat
	              optional: the skill can be cast at most this many times per
	              fight (Resurrection: once)
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
		CooldownPerLevel = -0.1,
		MinCooldown = 3,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.4, PerLevel = { Multiplier = 0.1 } },
			{
				Type = "ApplyStatus",
				Target = "Self",
				Status = "Fortified",
				Duration = 5,
				PerLevel = { Duration = 0.15, Strength = 0.02 },
			},
		},
	},

	Taunt = {
		Id = "Taunt",
		DisplayName = "Taunt",
		Description = "Redirects enemy attacks toward the Warrior.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 12,
		CooldownPerLevel = -0.2,
		MinCooldown = 6,
		Conditions = { SelfLacksStatus = "Taunting" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Taunting", Duration = 6, PerLevel = { Duration = 0.3 } },
		},
	},

	IronSkin = {
		Id = "IronSkin",
		DisplayName = "Iron Skin",
		Description = "Greatly increases the Warrior's defense.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "IronSkin" },
		Effects = {
			{
				Type = "ApplyStatus",
				Target = "Self",
				Status = "IronSkin",
				Duration = 8,
				PerLevel = { Duration = 0.25, Strength = 0.04 },
			},
		},
	},

	Whirlwind = {
		Id = "Whirlwind",
		DisplayName = "Whirlwind",
		Description = "Deals area damage to all enemies.",
		Class = "Warrior",
		Rarity = "Common",
		Cooldown = 8,
		CooldownPerLevel = -0.1,
		MinCooldown = 4,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.9, PerLevel = { Multiplier = 0.07 } },
		},
	},

	ShieldWall = {
		Id = "ShieldWall",
		DisplayName = "Shield Wall",
		Description = "Raises a shield worth a third of max health and fortifies defense.",
		Class = "Warrior",
		Rarity = "Rare",
		Cooldown = 20,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Effects = {
			{
				Type = "Shield",
				Target = "Self",
				PercentMaxHealth = 0.3,
				Duration = 10,
				PerLevel = { PercentMaxHealth = 0.012, Duration = 0.2 },
			},
			{
				Type = "ApplyStatus",
				Target = "Self",
				Status = "Fortified",
				Duration = 8,
				PerLevel = { Duration = 0.2, Strength = 0.03 },
			},
		},
	},

	CrushingBlow = {
		Id = "CrushingBlow",
		DisplayName = "Crushing Blow",
		Description = "A heavy blow on a single enemy.",
		Class = "Warrior",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.15,
		MinCooldown = 5,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.4, PerLevel = { Multiplier = 0.18 } },
		},
	},

	LastStand = {
		Id = "LastStand",
		DisplayName = "Last Stand",
		Description = "Temporarily prevents lethal damage.",
		Class = "Warrior",
		Rarity = "Epic",
		Cooldown = 30,
		CooldownPerLevel = -0.5,
		MinCooldown = 15,
		Conditions = { SelfHealthBelow = 0.5 },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "LastStand", Duration = 4, PerLevel = { Duration = 0.15 } },
		},
	},

	RallyingCry = {
		Id = "RallyingCry",
		DisplayName = "Rallying Cry",
		Description = "Increases the whole party's defense.",
		Class = "Warrior",
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.4,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "Rallied" },
		Effects = {
			{
				Type = "ApplyStatus",
				Target = "AllAllies",
				Status = "Rallied",
				Duration = 8,
				PerLevel = { Duration = 0.3, Strength = 0.04 },
			},
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
		CooldownPerLevel = -0.05,
		MinCooldown = 1.5,
		Element = "Holy",
		Effects = {
			{
				Type = "Damage",
				Target = "Primary",
				Multiplier = 1.5,
				DamageType = "Magical",
				PerLevel = { Multiplier = 0.12 },
			},
		},
	},

	Heal = {
		Id = "Heal",
		DisplayName = "Heal",
		Description = "Heals the most wounded ally when someone is hurt.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 4,
		CooldownPerLevel = -0.08,
		MinCooldown = 2,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 2.5, PerLevel = { Multiplier = 0.2 } },
		},
	},

	Blessing = {
		Id = "Blessing",
		DisplayName = "Blessing",
		Description = "Increases the whole party's attack.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 15,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Blessed" },
		Effects = {
			{
				Type = "ApplyStatus",
				Target = "AllAllies",
				Status = "Blessed",
				Duration = 8,
				PerLevel = { Duration = 0.3, Strength = 0.03 },
			},
		},
	},

	RadiantBurst = {
		Id = "RadiantBurst",
		DisplayName = "Radiant Burst",
		Description = "Damages all enemies and heals all allies.",
		Class = "Cleric",
		Rarity = "Common",
		Cooldown = 10,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Element = "Holy",
		Effects = {
			{
				Type = "Damage",
				Target = "AllEnemies",
				Multiplier = 0.8,
				DamageType = "Magical",
				PerLevel = { Multiplier = 0.06 },
			},
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.6, PerLevel = { Multiplier = 0.05 } },
		},
	},

	DivineShield = {
		Id = "DivineShield",
		DisplayName = "Divine Shield",
		Description = "Shields the most wounded ally.",
		Class = "Cleric",
		Rarity = "Rare",
		Cooldown = 12,
		CooldownPerLevel = -0.25,
		MinCooldown = 6,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.9 },
		Effects = {
			{
				Type = "Shield",
				Target = "LowestAlly",
				Multiplier = 1.5,
				PercentMaxHealth = 0.15,
				Duration = 8,
				PerLevel = { Multiplier = 0.12, PercentMaxHealth = 0.01, Duration = 0.2 },
			},
		},
	},

	GroupHeal = {
		Id = "GroupHeal",
		DisplayName = "Group Heal",
		Description = "Heals the whole party when several allies are hurt.",
		Class = "Cleric",
		Rarity = "Rare",
		Cooldown = 14,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.6 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.5, PerLevel = { Multiplier = 0.12 } },
		},
	},

	GuardianAngel = {
		Id = "GuardianAngel",
		DisplayName = "Guardian Angel",
		Description = "Protects a dying ally from lethal damage.",
		Class = "Cleric",
		Rarity = "Epic",
		Cooldown = 30,
		CooldownPerLevel = -0.5,
		MinCooldown = 15,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.35 },
		Effects = {
			{
				Type = "ApplyStatus",
				Target = "LowestAlly",
				Status = "GuardianAngel",
				Duration = 4,
				PerLevel = { Duration = 0.15 },
			},
		},
	},

	Judgment = {
		Id = "Judgment",
		DisplayName = "Judgment",
		Description = "Calls down devastating holy damage on one enemy.",
		Class = "Cleric",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Element = "Holy",
		Effects = {
			{
				Type = "Damage",
				Target = "Primary",
				Multiplier = 3.2,
				DamageType = "Magical",
				PerLevel = { Multiplier = 0.25 },
			},
		},
	},

	Resurrection = {
		Id = "Resurrection",
		DisplayName = "Resurrection",
		Description = "Returns a fallen ally to the fight. Once per combat.",
		Class = "Cleric",
		Rarity = "Epic",
		Cooldown = 5,
		UsesPerCombat = 1,
		Element = "Holy",
		Conditions = { AllyDead = true },
		Effects = {
			{ Type = "Revive", Target = "DeadAlly", HealthFraction = 0.35, PerLevel = { HealthFraction = 0.025 } },
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
