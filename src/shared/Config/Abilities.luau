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

	-- Subclass skills ----------------------------------------------------------------
	-- Each has Subclass = <Config/Subclasses id>. The FIRST skill of a subclass is
	-- granted free when you choose the path; the others are bought with shards.

	-- Warrior: Berserker
	BloodFrenzy = {
		Id = "BloodFrenzy",
		DisplayName = "Blood Frenzy",
		Description = "Whips the Berserker into a frenzy: attack and attack speed soar.",
		Class = "Warrior",
		Subclass = "Berserker",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "Frenzied" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Frenzied", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
		},
	},

	Cleave = {
		Id = "Cleave",
		DisplayName = "Cleave",
		Description = "A wide swing that hits every enemy hard.",
		Class = "Warrior",
		Subclass = "Berserker",
		Rarity = "Rare",
		Cooldown = 7,
		CooldownPerLevel = -0.12,
		MinCooldown = 4,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.6, PerLevel = { Multiplier = 0.12 } },
		},
	},

	ExecutionerStrike = {
		Id = "ExecutionerStrike",
		DisplayName = "Executioner Strike",
		Description = "A devastating blow on a single enemy.",
		Class = "Warrior",
		Subclass = "Berserker",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.25,
		MinCooldown = 8,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 4.2, PerLevel = { Multiplier = 0.3 } },
		},
	},

	-- Warrior: Guardian
	Bulwark = {
		Id = "Bulwark",
		DisplayName = "Bulwark",
		Description = "Shields the whole party and draws every enemy's attention.",
		Class = "Warrior",
		Subclass = "Guardian",
		Rarity = "Epic",
		Cooldown = 22,
		CooldownPerLevel = -0.4,
		MinCooldown = 12,
		Effects = {
			{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.25, Duration = 8, PerLevel = { PercentMaxHealth = 0.012, Duration = 0.2 } },
			{ Type = "ApplyStatus", Target = "Self", Status = "Taunting", Duration = 8, PerLevel = { Duration = 0.3 } },
		},
	},

	Retribution = {
		Id = "Retribution",
		DisplayName = "Retribution",
		Description = "Strikes back and recovers some health.",
		Class = "Warrior",
		Subclass = "Guardian",
		Rarity = "Rare",
		Cooldown = 8,
		CooldownPerLevel = -0.15,
		MinCooldown = 4,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, PerLevel = { Multiplier = 0.14 } },
			{ Type = "Heal", Target = "Self", Multiplier = 0, PercentMaxHealth = 0.08, PerLevel = { PercentMaxHealth = 0.004 } },
		},
	},

	UnbreakableVow = {
		Id = "UnbreakableVow",
		DisplayName = "Unbreakable Vow",
		Description = "When hurt, the Guardian's defense more than doubles.",
		Class = "Warrior",
		Subclass = "Guardian",
		Rarity = "Epic",
		Cooldown = 24,
		CooldownPerLevel = -0.4,
		MinCooldown = 12,
		Conditions = { SelfHealthBelow = 0.6, SelfLacksStatus = "Unbreakable" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Unbreakable", Duration = 6, PerLevel = { Duration = 0.25, Strength = 0.04 } },
		},
	},

	-- Cleric: Priest
	Sanctuary = {
		Id = "Sanctuary",
		DisplayName = "Sanctuary",
		Description = "Heals and shields the whole party when they are hurt.",
		Class = "Cleric",
		Subclass = "Priest",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.6 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.4, PerLevel = { Multiplier = 0.12 } },
			{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.15, Duration = 6, PerLevel = { PercentMaxHealth = 0.008, Duration = 0.2 } },
		},
	},

	Renewal = {
		Id = "Renewal",
		DisplayName = "Renewal",
		Description = "A powerful heal for a badly wounded ally.",
		Class = "Cleric",
		Subclass = "Priest",
		Rarity = "Rare",
		Cooldown = 7,
		CooldownPerLevel = -0.12,
		MinCooldown = 3.5,
		Element = "Holy",
		Conditions = { AllyHealthBelow = 0.5 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 4, PerLevel = { Multiplier = 0.3 } },
		},
	},

	HolyAegis = {
		Id = "HolyAegis",
		DisplayName = "Holy Aegis",
		Description = "A holy ward raises the whole party's defense and heals them.",
		Class = "Cleric",
		Subclass = "Priest",
		Rarity = "Epic",
		Cooldown = 24,
		CooldownPerLevel = -0.4,
		MinCooldown = 12,
		Element = "Holy",
		Conditions = { SelfLacksStatus = "Aegis" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Aegis", Duration = 10, PerLevel = { Duration = 0.3, Strength = 0.04 } },
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.8, PerLevel = { Multiplier = 0.07 } },
		},
	},

	-- Cleric: Templar
	HolyWrath = {
		Id = "HolyWrath",
		DisplayName = "Holy Wrath",
		Description = "Smites every enemy and blesses the party with greater attack.",
		Class = "Cleric",
		Subclass = "Templar",
		Rarity = "Epic",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 9,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.2, DamageType = "Magical", PerLevel = { Multiplier = 0.16 } },
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Blessed", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
		},
	},

	Judgment = {
		Id = "Judgment",
		DisplayName = "Judgment",
		Description = "Holy damage on a single enemy.",
		Class = "Cleric",
		Subclass = "Templar",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.15,
		MinCooldown = 5,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 3.2, DamageType = "Magical", PerLevel = { Multiplier = 0.24 } },
		},
	},

	DivineSmite = {
		Id = "DivineSmite",
		DisplayName = "Divine Smite",
		Description = "A massive burst of holy power on one enemy.",
		Class = "Cleric",
		Subclass = "Templar",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Element = "Holy",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 5, DamageType = "Magical", PerLevel = { Multiplier = 0.35 } },
		},
	},

	-- Boss and enemy skills ---------------------------------------------------------
	-- Bosses cast these on FIXED timers (opening Timer on the enemy, then Cooldown), so a
	-- player can plan: a Telegraph warning appears that many seconds before the cast. A
	-- Warrior wants a shield up when the blow lands; a Cleric wants a heal ready just after.
	-- Not in any class pool (Enemy = true).
	SlimeSplit = {
		Id = "SlimeSplit",
		DisplayName = "Slime Split",
		Description = "Splits off slimelets. Area skills clear them fast.",
		Enemy = true,
		Rarity = "Common",
		Cooldown = 14,
		Conditions = { MaxAllies = 5 },
		Effects = { { Type = "Summon", EnemyId = "Slimelet", Count = 2 } },
	},

	CrushingBlow = {
		Id = "CrushingBlow",
		DisplayName = "Crushing Blow",
		Description = "A huge hit on one target.",
		Enemy = true,
		Rarity = "Common",
		Cooldown = 11,
		Telegraph = 1.5,
		Effects = { { Type = "Damage", Target = "Primary", Multiplier = 3, PerLevel = { Multiplier = 0 } } },
	},

	Enrage = {
		Id = "Enrage",
		DisplayName = "Enrage",
		Description = "Below half health, hits much harder and faster.",
		Enemy = true,
		Rarity = "Common",
		Cooldown = 1,
		UsesPerCombat = 1,
		Conditions = { SelfHealthBelow = 0.5 },
		Effects = { { Type = "ApplyStatus", Target = "Self", Status = "Enraged", Duration = 90 } },
	},

	SporeBurst = {
		Id = "SporeBurst",
		DisplayName = "Spore Burst",
		Description = "Damages the whole party.",
		Enemy = true,
		Rarity = "Common",
		Cooldown = 12,
		Telegraph = 1.5,
		Effects = { { Type = "Damage", Target = "AllEnemies", Multiplier = 1.2, DamageType = "Magical", PerLevel = { Multiplier = 0 } } },
	},

	SporeCall = {
		Id = "SporeCall",
		DisplayName = "Spore Call",
		Description = "Calls sporelings to fight.",
		Enemy = true,
		Rarity = "Common",
		Cooldown = 16,
		Conditions = { MaxAllies = 5 },
		Effects = { { Type = "Summon", EnemyId = "Sporeling", Count = 2 } },
	},

	-- Pet skills (cast automatically by a pet's owner; level = pet rank; see Config/Pets, Shared/Pets) ----------
	Pet_Slimey = {
		Id = "Pet_Slimey",
		DisplayName = "Goo Bubble",
		Description = "Wraps the most hurt ally in a shield.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 12,
		CooldownPerLevel = -0.3,
		MinCooldown = 6,
		Conditions = { AllyHealthBelow = 0.9 },
		Effects = {
			{ Type = "Shield", Target = "LowestAlly", Multiplier = 1.0, PercentMaxHealth = 0.08, Duration = 6, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.01, Duration = 0.3 } },
		},
	},

	Pet_Foxling = {
		Id = "Pet_Foxling",
		DisplayName = "Fox Fire",
		Description = "Burns an enemy with a flicker of flame.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 7,
		CooldownPerLevel = -0.3,
		MinCooldown = 3,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.3, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Mossback = {
		Id = "Pet_Mossback",
		DisplayName = "Mossy Guard",
		Description = "Raises the whole party's defense.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 9,
		Conditions = { SelfLacksStatus = "Fortified" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Fortified", Duration = 6, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_Pebbles = {
		Id = "Pet_Pebbles",
		DisplayName = "Rockfall",
		Description = "Drops rocks on every enemy when two or more are up.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 10,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.8, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Cottonpuff = {
		Id = "Pet_Cottonpuff",
		DisplayName = "Soft Landing",
		Description = "Heals the most hurt ally.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 10,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Conditions = { AllyHealthBelow = 0.65 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 1.3, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Chirpy = {
		Id = "Pet_Chirpy",
		DisplayName = "Cheerful Song",
		Description = "Boosts the whole party's attack.",
		Class = "Pet",
		Pet = true,
		Rarity = "Common",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Rallied" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Rallied", Duration = 6, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_Wisp = {
		Id = "Pet_Wisp",
		DisplayName = "Spark",
		Description = "Zaps an enemy with magic.",
		Class = "Pet",
		Pet = true,
		Rarity = "Rare",
		Cooldown = 8,
		CooldownPerLevel = -0.3,
		MinCooldown = 4,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, DamageType = "Magical", PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Emberkit = {
		Id = "Pet_Emberkit",
		DisplayName = "Ember Claw",
		Description = "A heavy fiery swipe at one enemy.",
		Class = "Pet",
		Pet = true,
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.3,
		MinCooldown = 4,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.2, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Shellby = {
		Id = "Pet_Shellby",
		DisplayName = "Tidal Shell",
		Description = "Shields the whole party.",
		Class = "Pet",
		Pet = true,
		Rarity = "Rare",
		Cooldown = 14,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Conditions = { AllyHealthBelow = 0.85 },
		Effects = {
			{ Type = "Shield", Target = "AllAllies", Multiplier = 0.9, PercentMaxHealth = 0.08, Duration = 6, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.01, Duration = 0.3 } },
		},
	},

	Pet_Zephyr = {
		Id = "Pet_Zephyr",
		DisplayName = "Tailwind",
		Description = "Speeds up its owner's attacks for a while.",
		Class = "Pet",
		Pet = true,
		Rarity = "Rare",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 9,
		Conditions = { SelfLacksStatus = "Frenzied" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Frenzied", Duration = 6, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_Frostwing = {
		Id = "Pet_Frostwing",
		DisplayName = "Cold Snap",
		Description = "Freezing wind hits every enemy and chills one.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 13,
		CooldownPerLevel = -0.3,
		MinCooldown = 6,
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.2, DamageType = "Magical", PerLevel = { Multiplier = 0.1 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Chilled", Duration = 4, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_Starbun = {
		Id = "Pet_Starbun",
		DisplayName = "Star Wish",
		Description = "Heals the whole party.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 15,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.1, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Thornback = {
		Id = "Pet_Thornback",
		DisplayName = "Thorn Armor",
		Description = "Toughens its owner against hits.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "Aegis" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Aegis", Duration = 8, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_EmberDrake = {
		Id = "Pet_EmberDrake",
		DisplayName = "Dragonfire",
		Description = "Breathes fire on every enemy.",
		Class = "Pet",
		Pet = true,
		Rarity = "Legendary",
		Cooldown = 14,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.4, DamageType = "Magical", PerLevel = { Multiplier = 0.15 } },
		},
	},

	Pet_Colossling = {
		Id = "Pet_Colossling",
		DisplayName = "Colossal Stomp",
		Description = "Stomps every enemy and braces its owner.",
		Class = "Pet",
		Pet = true,
		Rarity = "Legendary",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.8, PerLevel = { Multiplier = 0.15 } },
			{ Type = "ApplyStatus", Target = "Self", Status = "Fortified", Duration = 6, PerLevel = { Duration = 0.4 } },
		},
	},

	Pet_Crownling = {
		Id = "Pet_Crownling",
		DisplayName = "Royal Decree",
		Description = "Strikes every enemy and shields the party.",
		Class = "Pet",
		Pet = true,
		Rarity = "Legendary",
		Cooldown = 13,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 3.0, DamageType = "Magical", PerLevel = { Multiplier = 0.2 } },
			{ Type = "Shield", Target = "AllAllies", Multiplier = 1.2, PercentMaxHealth = 0.08, Duration = 8, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.01, Duration = 0.3 } },
		},
	},

	Pet_Laurelwing = {
		Id = "Pet_Laurelwing",
		DisplayName = "Victory March",
		Description = "Whips the whole party into a frenzy: attack and attack speed up.",
		Class = "Pet",
		Pet = true,
		Rarity = "Legendary",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Frenzied" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Frenzied", Duration = 9, PerLevel = { Duration = 0.5 } },
		},
	},

	Pet_Bannerhound = {
		Id = "Pet_Bannerhound",
		DisplayName = "Banner Guard",
		Description = "Raises the whole party's defense and shields it.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 15,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Fortified" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Fortified", Duration = 9, PerLevel = { Duration = 0.5 } },
			{ Type = "Shield", Target = "AllAllies", Multiplier = 0.8, PercentMaxHealth = 0.05, Duration = 8, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.01, Duration = 0.3 } },
		},
	},

	Pet_Haloette = {
		Id = "Pet_Haloette",
		DisplayName = "Halo Mend",
		Description = "Heals the most hurt ally a lot and the rest a little.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 9,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 2.4, PerLevel = { Multiplier = 0.18 } },
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.6, PerLevel = { Multiplier = 0.06 } },
		},
	},

	Pet_Aurora = {
		Id = "Pet_Aurora",
		DisplayName = "Aurora Veil",
		Description = "Heals and shields the whole party.",
		Class = "Pet",
		Pet = true,
		Rarity = "Legendary",
		Cooldown = 16,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Conditions = { AllyHealthBelow = 0.85 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.0, PerLevel = { Multiplier = 0.12 } },
			{ Type = "Shield", Target = "AllAllies", Multiplier = 1.2, PercentMaxHealth = 0.08, Duration = 8, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.01, Duration = 0.3 } },
		},
	},

	-- New classes: Mage, Ranger, Rogue, Summoner ----------------------------------------------
	ArcaneBlast = {
		Id = "ArcaneBlast",
		DisplayName = "Arcane Blast",
		Description = "A burst of arcane force hits every enemy.",
		Class = "Mage",
		Rarity = "Common",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Element = "Arcane",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.1, PerLevel = { Multiplier = 0.1 } },
		},
	},

	ChainLightning = {
		Id = "ChainLightning",
		DisplayName = "Chain Lightning",
		Description = "Lightning leaps between every enemy.",
		Class = "Mage",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Element = "Lightning",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.5, PerLevel = { Multiplier = 0.12 } },
		},
	},

	ManaShield = {
		Id = "ManaShield",
		DisplayName = "Mana Shield",
		Description = "Wraps the mage in a shield of raw magic.",
		Class = "Mage",
		Rarity = "Rare",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Element = "Arcane",
		Conditions = { SelfHealthBelow = 0.75 },
		Effects = {
			{ Type = "Shield", Target = "Self", PercentMaxHealth = 0.3, Duration = 6, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
		},
	},

	Meteor = {
		Id = "Meteor",
		DisplayName = "Meteor",
		Description = "Calls down a meteor that crushes every enemy.",
		Class = "Mage",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.2,
		MinCooldown = 10,
		Element = "Fire",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.8, PerLevel = { Multiplier = 0.2 } },
		},
	},

	Ignite = {
		Id = "Ignite",
		DisplayName = "Ignite",
		Description = "Sets an enemy ablaze: big damage and burning.",
		Class = "Mage",
		Subclass = "Pyromancer",
		Rarity = "Rare",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Element = "Fire",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, PerLevel = { Multiplier = 0.13 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Burning", Duration = 6, PerLevel = { Duration = 0.3 } },
		},
	},

	Inferno = {
		Id = "Inferno",
		DisplayName = "Inferno",
		Description = "Engulfs every enemy in flames that keep burning.",
		Class = "Mage",
		Subclass = "Pyromancer",
		Rarity = "Epic",
		Cooldown = 16,
		CooldownPerLevel = -0.2,
		MinCooldown = 9,
		Element = "Fire",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.8, PerLevel = { Multiplier = 0.14 } },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Burning", Duration = 6, PerLevel = { Duration = 0.3 } },
		},
	},

	PhoenixFire = {
		Id = "PhoenixFire",
		DisplayName = "Phoenix Fire",
		Description = "A blazing phoenix scorches one enemy and warms the mage.",
		Class = "Mage",
		Subclass = "Pyromancer",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Element = "Fire",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 4.4, PerLevel = { Multiplier = 0.3 } },
			{ Type = "Heal", Target = "Self", Multiplier = 0, PercentMaxHealth = 0.08, PerLevel = { PercentMaxHealth = 0.004 } },
		},
	},

	DeepFreeze = {
		Id = "DeepFreeze",
		DisplayName = "Deep Freeze",
		Description = "Freezes an enemy solid (bosses are only chilled).",
		Class = "Mage",
		Subclass = "FrostWeaver",
		Rarity = "Rare",
		Cooldown = 11,
		CooldownPerLevel = -0.2,
		MinCooldown = 6,
		Element = "Ice",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.4, PerLevel = { Multiplier = 0.1 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Frozen", Duration = 2.5, PerLevel = { Duration = 0.1 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Chilled", Duration = 5, PerLevel = { Duration = 0.2 } },
		},
	},

	FrostArmor = {
		Id = "FrostArmor",
		DisplayName = "Frost Armor",
		Description = "Shields the whole party in ice and chills every enemy.",
		Class = "Mage",
		Subclass = "FrostWeaver",
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.2,
		MinCooldown = 11,
		Element = "Ice",
		Effects = {
			{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.18, Duration = 7, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Chilled", Duration = 6, PerLevel = { Duration = 0.2 } },
		},
	},

	Glacier = {
		Id = "Glacier",
		DisplayName = "Glacier",
		Description = "A glacier slams every enemy and freezes them in place.",
		Class = "Mage",
		Subclass = "FrostWeaver",
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.2,
		MinCooldown = 11,
		Element = "Ice",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.0, PerLevel = { Multiplier = 0.15 } },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Frozen", Duration = 2, PerLevel = { Duration = 0.08 } },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Chilled", Duration = 5, PerLevel = { Duration = 0.2 } },
		},
	},

	PowerShot = {
		Id = "PowerShot",
		DisplayName = "Power Shot",
		Description = "A hard-pulled arrow into one enemy.",
		Class = "Ranger",
		Rarity = "Common",
		Cooldown = 5,
		CooldownPerLevel = -0.2,
		MinCooldown = 3,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.0, PerLevel = { Multiplier = 0.14 } },
		},
	},

	Volley = {
		Id = "Volley",
		DisplayName = "Volley",
		Description = "Rains arrows on every enemy.",
		Class = "Ranger",
		Rarity = "Common",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.1, PerLevel = { Multiplier = 0.08 } },
		},
	},

	PiercingArrow = {
		Id = "PiercingArrow",
		DisplayName = "Piercing Arrow",
		Description = "An armor-piercing shot for big single-target damage.",
		Class = "Ranger",
		Rarity = "Rare",
		Cooldown = 10,
		CooldownPerLevel = -0.2,
		MinCooldown = 6,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 3.3, PerLevel = { Multiplier = 0.22 } },
		},
	},

	Snare = {
		Id = "Snare",
		DisplayName = "Snare",
		Description = "Pins an enemy in a net: damage and much slower attacks.",
		Class = "Ranger",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 0.9, PerLevel = { Multiplier = 0.07 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Snared", Duration = 6, PerLevel = { Duration = 0.25 } },
		},
	},

	Evasion = {
		Id = "Evasion",
		DisplayName = "Evasion",
		Description = "Dodges aside: takes far less damage for a while.",
		Class = "Ranger",
		Rarity = "Rare",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Evasive", SelfHealthBelow = 0.8 },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Evasive", Duration = 5, PerLevel = { Duration = 0.25 } },
		},
	},

	HuntersMark = {
		Id = "HuntersMark",
		DisplayName = "Hunter's Mark",
		Description = "Marks an enemy: it takes much more damage.",
		Class = "Ranger",
		Rarity = "Epic",
		Cooldown = 16,
		CooldownPerLevel = -0.2,
		MinCooldown = 9,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 0.6, PerLevel = { Multiplier = 0.05 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Marked", Duration = 8, PerLevel = { Duration = 0.3 } },
		},
	},

	RapidFire = {
		Id = "RapidFire",
		DisplayName = "Rapid Fire",
		Description = "Looses arrows faster for a short time.",
		Class = "Ranger",
		Rarity = "Epic",
		Cooldown = 16,
		CooldownPerLevel = -0.2,
		MinCooldown = 9,
		Conditions = { SelfLacksStatus = "Hasted" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Hasted", Duration = 6, PerLevel = { Duration = 0.25 } },
		},
	},

	ExplosiveArrow = {
		Id = "ExplosiveArrow",
		DisplayName = "Explosive Arrow",
		Description = "An arrow that explodes among the enemies.",
		Class = "Ranger",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Element = "Fire",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.2, PerLevel = { Multiplier = 0.16 } },
		},
	},

	DeadEye = {
		Id = "DeadEye",
		DisplayName = "Dead Eye",
		Description = "Locks on: crit chance and attack soar.",
		Class = "Ranger",
		Subclass = "Sharpshooter",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.2,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "DeadEye" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "DeadEye", Duration = 8, PerLevel = { Duration = 0.3, Strength = 0.03 } },
		},
	},

	Headshot = {
		Id = "Headshot",
		DisplayName = "Headshot",
		Description = "One devastating shot on a single enemy.",
		Class = "Ranger",
		Subclass = "Sharpshooter",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 4.8, PerLevel = { Multiplier = 0.34 } },
		},
	},

	Barrage = {
		Id = "Barrage",
		DisplayName = "Barrage",
		Description = "A storm of arrows on every enemy.",
		Class = "Ranger",
		Subclass = "Sharpshooter",
		Rarity = "Rare",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.7, PerLevel = { Multiplier = 0.12 } },
		},
	},

	PackHowl = {
		Id = "PackHowl",
		DisplayName = "Pack Howl",
		Description = "A howl that emboldens the whole party.",
		Class = "Ranger",
		Subclass = "Beastmaster",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.2,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "Emboldened" },
		Effects = {
			{ Type = "ApplyStatus", Target = "AllAllies", Status = "Emboldened", Duration = 9, PerLevel = { Duration = 0.3, Strength = 0.03 } },
		},
	},

	Stampede = {
		Id = "Stampede",
		DisplayName = "Stampede",
		Description = "The beasts stampede through every enemy.",
		Class = "Ranger",
		Subclass = "Beastmaster",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.7, PerLevel = { Multiplier = 0.12 } },
		},
	},

	NaturesBond = {
		Id = "NaturesBond",
		DisplayName = "Nature's Bond",
		Description = "The wild mends every ally.",
		Class = "Ranger",
		Subclass = "Beastmaster",
		Rarity = "Rare",
		Cooldown = 13,
		CooldownPerLevel = -0.2,
		MinCooldown = 7,
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.1, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Backstab = {
		Id = "Backstab",
		DisplayName = "Backstab",
		Description = "A quick stab for good single-target damage.",
		Class = "Rogue",
		Rarity = "Common",
		Cooldown = 5,
		CooldownPerLevel = -0.2,
		MinCooldown = 3,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.0, PerLevel = { Multiplier = 0.14 } },
		},
	},

	FanOfKnives = {
		Id = "FanOfKnives",
		DisplayName = "Fan of Knives",
		Description = "Throws knives at every enemy.",
		Class = "Rogue",
		Rarity = "Common",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.1, PerLevel = { Multiplier = 0.08 } },
		},
	},

	PoisonBlade = {
		Id = "PoisonBlade",
		DisplayName = "Poison Blade",
		Description = "A coated blade: damage and poison.",
		Class = "Rogue",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Element = "Poison",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.0, PerLevel = { Multiplier = 0.08 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Poisoned", Duration = 7, PerLevel = { Duration = 0.3 } },
		},
	},

	Smokescreen = {
		Id = "Smokescreen",
		DisplayName = "Smokescreen",
		Description = "Vanishes in smoke: takes far less damage.",
		Class = "Rogue",
		Rarity = "Rare",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Evasive", SelfHealthBelow = 0.8 },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Evasive", Duration = 5, PerLevel = { Duration = 0.25 } },
		},
	},

	Shadowstep = {
		Id = "Shadowstep",
		DisplayName = "Shadowstep",
		Description = "Slips into the shadows: attacks come faster.",
		Class = "Rogue",
		Rarity = "Rare",
		Cooldown = 15,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Conditions = { SelfLacksStatus = "Hasted" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Hasted", Duration = 6, PerLevel = { Duration = 0.25 } },
		},
	},

	Eviscerate = {
		Id = "Eviscerate",
		DisplayName = "Eviscerate",
		Description = "A brutal finishing strike.",
		Class = "Rogue",
		Rarity = "Epic",
		Cooldown = 13,
		CooldownPerLevel = -0.2,
		MinCooldown = 7,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 4.0, PerLevel = { Multiplier = 0.28 } },
		},
	},

	Flurry = {
		Id = "Flurry",
		DisplayName = "Flurry",
		Description = "A blur of cuts across every enemy.",
		Class = "Rogue",
		Rarity = "Rare",
		Cooldown = 10,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.5, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Vanish = {
		Id = "Vanish",
		DisplayName = "Vanish",
		Description = "Fades from sight behind a veil of shadow.",
		Class = "Rogue",
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.2,
		MinCooldown = 11,
		Element = "Shadow",
		Conditions = { SelfHealthBelow = 0.5 },
		Effects = {
			{ Type = "Shield", Target = "Self", PercentMaxHealth = 0.35, Duration = 6, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
		},
	},

	DeathMark = {
		Id = "DeathMark",
		DisplayName = "Death Mark",
		Description = "Marks an enemy for death: crits hit far harder.",
		Class = "Rogue",
		Subclass = "Assassin",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.2,
		MinCooldown = 10,
		Element = "Shadow",
		Conditions = { SelfLacksStatus = "Shadowed" },
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.0, PerLevel = { Multiplier = 0.08 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Marked", Duration = 8, PerLevel = { Duration = 0.3 } },
			{ Type = "ApplyStatus", Target = "Self", Status = "Shadowed", Duration = 8, PerLevel = { Duration = 0.3 } },
		},
	},

	Execute = {
		Id = "Execute",
		DisplayName = "Execute",
		Description = "A killing blow on a single enemy.",
		Class = "Rogue",
		Subclass = "Assassin",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Element = "Shadow",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 5.0, PerLevel = { Multiplier = 0.36 } },
		},
	},

	ShadowStrike = {
		Id = "ShadowStrike",
		DisplayName = "Shadow Strike",
		Description = "Strikes every enemy from the shadows.",
		Class = "Rogue",
		Subclass = "Assassin",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Element = "Shadow",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 1.8, PerLevel = { Multiplier = 0.13 } },
		},
	},

	Riposte = {
		Id = "Riposte",
		DisplayName = "Riposte",
		Description = "Turns an attack aside and strikes back, mending the duelist.",
		Class = "Rogue",
		Subclass = "Duelist",
		Rarity = "Rare",
		Cooldown = 8,
		CooldownPerLevel = -0.2,
		MinCooldown = 4,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, PerLevel = { Multiplier = 0.13 } },
			{ Type = "Heal", Target = "Self", Multiplier = 0, PercentMaxHealth = 0.06, PerLevel = { PercentMaxHealth = 0.004 } },
		},
	},

	Parry = {
		Id = "Parry",
		DisplayName = "Parry",
		Description = "A perfect guard: tougher and much harder to hurt.",
		Class = "Rogue",
		Subclass = "Duelist",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.2,
		MinCooldown = 10,
		Conditions = { SelfLacksStatus = "Evasive" },
		Effects = {
			{ Type = "ApplyStatus", Target = "Self", Status = "Evasive", Duration = 6, PerLevel = { Duration = 0.3 } },
			{ Type = "ApplyStatus", Target = "Self", Status = "Fortified", Duration = 6, PerLevel = { Duration = 0.3 } },
		},
	},

	BladeDance = {
		Id = "BladeDance",
		DisplayName = "Blade Dance",
		Description = "Whirls through every enemy in a dance of steel.",
		Class = "Rogue",
		Subclass = "Duelist",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.1, PerLevel = { Multiplier = 0.15 } },
		},
	},

	SummonImp = {
		Id = "SummonImp",
		DisplayName = "Summon Imp",
		Description = "Spend a little health to summon an imp that hurls fire. Up to 3 imps at once.",
		Class = "Summoner",
		Rarity = "Common",
		Cooldown = 5,
		CooldownPerLevel = -0.2,
		MinCooldown = 3,
		Element = "Fire",
		Conditions = { SelfHealthAbove = 0.35, MinionsBelow = { Id = "Imp", Max = 3 } },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.05 },
			{ Type = "Raise", MinionId = "Imp", Count = 1, Max = 3, Power = 1, PerLevel = { Power = 0.07 } },
		},
	},

	WraithSwarm = {
		Id = "WraithSwarm",
		DisplayName = "Wraith Swarm",
		Description = "Spend health to call two fast, fragile wraiths. Up to 4 at once.",
		Class = "Summoner",
		Rarity = "Common",
		Cooldown = 12,
		CooldownPerLevel = -0.3,
		MinCooldown = 7,
		Element = "Shadow",
		Conditions = { SelfHealthAbove = 0.4, MinionsBelow = { Id = "Wraith", Max = 3 } },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.08 },
			{ Type = "Raise", MinionId = "Wraith", Count = 2, Max = 4, Power = 1, PerLevel = { Power = 0.07 } },
		},
	},

	SoulLeech = {
		Id = "SoulLeech",
		DisplayName = "Soul Leech",
		Description = "Drains an enemy's life to mend the summoner.",
		Class = "Summoner",
		Rarity = "Rare",
		Cooldown = 9,
		CooldownPerLevel = -0.2,
		MinCooldown = 5,
		Element = "Shadow",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.6, PerLevel = { Multiplier = 0.12 } },
			{ Type = "Heal", Target = "Self", Multiplier = 0, PercentMaxHealth = 0.09, PerLevel = { PercentMaxHealth = 0.005 } },
		},
	},

	RaiseSkeleton = {
		Id = "RaiseSkeleton",
		DisplayName = "Raise Skeleton",
		Description = "Spend health to raise a sturdy skeleton that taunts enemies and soaks up their hits.",
		Class = "Summoner",
		Rarity = "Common",
		Cooldown = 10,
		CooldownPerLevel = -0.3,
		MinCooldown = 6,
		Element = "Shadow",
		Conditions = { SelfHealthAbove = 0.45, MinionsBelow = { Id = "Skeleton", Max = 1 } },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.1 },
			{ Type = "Raise", MinionId = "Skeleton", Count = 1, Max = 1, Power = 1, PerLevel = { Power = 0.08 } },
		},
	},

	Haunt = {
		Id = "Haunt",
		DisplayName = "Haunt",
		Description = "A haunting that makes an enemy take more damage and hit weaker.",
		Class = "Summoner",
		Rarity = "Rare",
		Cooldown = 11,
		CooldownPerLevel = -0.2,
		MinCooldown = 6,
		Element = "Shadow",
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 0.9, PerLevel = { Multiplier = 0.07 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Cursed", Duration = 7, PerLevel = { Duration = 0.3 } },
		},
	},

	Devour = {
		Id = "Devour",
		DisplayName = "Devour",
		Description = "Consume your weakest minion to restore health: a share of your max HP plus part of its remaining life.",
		Class = "Summoner",
		Rarity = "Epic",
		Cooldown = 14,
		CooldownPerLevel = -0.3,
		MinCooldown = 8,
		Element = "Shadow",
		Conditions = { HasMinions = true, SelfHealthBelow = 0.75 },
		Effects = {
			{ Type = "Devour", PercentMaxHealth = 0.1, MinionLife = 0.7, PerLevel = { PercentMaxHealth = 0.006, MinionLife = 0.03 } },
		},
	},

	BoneArmor = {
		Id = "BoneArmor",
		DisplayName = "Bone Armor",
		Description = "Armor of bone shields the summoner.",
		Class = "Summoner",
		Rarity = "Rare",
		Cooldown = 15,
		CooldownPerLevel = -0.2,
		MinCooldown = 8,
		Element = "Shadow",
		Conditions = { SelfHealthBelow = 0.7 },
		Effects = {
			{ Type = "Shield", Target = "Self", PercentMaxHealth = 0.28, Duration = 6, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
		},
	},

	CallTitan = {
		Id = "CallTitan",
		DisplayName = "Call Titan",
		Description = "Spend a large share of your health to raise a towering bone titan that taunts and smashes.",
		Class = "Summoner",
		Rarity = "Epic",
		Cooldown = 22,
		CooldownPerLevel = -0.4,
		MinCooldown = 14,
		Element = "Shadow",
		Conditions = { SelfHealthAbove = 0.6, MinionsBelow = { Id = "BoneTitan", Max = 1 } },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.2 },
			{ Type = "Raise", MinionId = "BoneTitan", Count = 1, Max = 1, Power = 1, PerLevel = { Power = 0.1 } },
		},
	},

	RaiseDead = {
		Id = "RaiseDead",
		DisplayName = "Raise Dead",
		Description = "Spend health to raise three ghouls that maul enemies and feed life back to you.",
		Class = "Summoner",
		Subclass = "Necromancer",
		Rarity = "Epic",
		Cooldown = 18,
		CooldownPerLevel = -0.3,
		MinCooldown = 10,
		Element = "Shadow",
		Conditions = { SelfHealthAbove = 0.5, MinionsBelow = { Id = "Ghoul", Max = 3 } },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.12 },
			{ Type = "Raise", MinionId = "Ghoul", Count = 3, Max = 3, Power = 1, PerLevel = { Power = 0.08 } },
		},
	},

	DeathCoil = {
		Id = "DeathCoil",
		DisplayName = "Death Coil",
		Description = "Spend some health to unleash a coil of death that hits hard and heals the necromancer more than it cost.",
		Class = "Summoner",
		Subclass = "Necromancer",
		Rarity = "Epic",
		Cooldown = 13,
		CooldownPerLevel = -0.2,
		MinCooldown = 7,
		Element = "Shadow",
		Conditions = { SelfHealthAbove = 0.3 },
		Effects = {
			{ Type = "SpendHealth", Fraction = 0.06 },
			{ Type = "Damage", Target = "Primary", Multiplier = 3.8, PerLevel = { Multiplier = 0.28 } },
			{ Type = "Heal", Target = "Self", Multiplier = 0, PercentMaxHealth = 0.14, PerLevel = { PercentMaxHealth = 0.006 } },
		},
	},

	Plague = {
		Id = "Plague",
		DisplayName = "Plague",
		Description = "A plague poisons every enemy.",
		Class = "Summoner",
		Subclass = "Necromancer",
		Rarity = "Rare",
		Cooldown = 12,
		CooldownPerLevel = -0.2,
		MinCooldown = 7,
		Element = "Poison",
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.9, PerLevel = { Multiplier = 0.07 } },
			{ Type = "ApplyStatus", Target = "AllEnemies", Status = "Poisoned", Duration = 8, PerLevel = { Duration = 0.3 } },
		},
	},

	GuardianSpirit = {
		Id = "GuardianSpirit",
		DisplayName = "Guardian Spirit",
		Description = "Calls a guardian spirit that keeps healing your allies, and shields and mends the whole party.",
		Class = "Summoner",
		Subclass = "SpiritCaller",
		Rarity = "Epic",
		Cooldown = 20,
		CooldownPerLevel = -0.2,
		MinCooldown = 11,
		Effects = {
			{ Type = "Raise", MinionId = "SpiritGuardian", Count = 1, Max = 1, Power = 1, PerLevel = { Power = 0.08 } },
			{ Type = "Shield", Target = "AllAllies", PercentMaxHealth = 0.2, Duration = 8, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.5, PerLevel = { Multiplier = 0.05 } },
		},
	},

	-- cast by a minion on its own (Config/Minions)
	Minion_SpiritMend = {
		Id = "Minion_SpiritMend",
		DisplayName = "Spirit Mend",
		Description = "The guardian spirit mends the most wounded ally.",
		Class = "Minion",
		Minion = true,
		Rarity = "Rare",
		Cooldown = 4,
		Conditions = { AllyHealthBelow = 0.9 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 1.5 },
		},
	},

	AncestralCall = {
		Id = "AncestralCall",
		DisplayName = "Ancestral Call",
		Description = "Ancestors mend every ally.",
		Class = "Summoner",
		Subclass = "SpiritCaller",
		Rarity = "Rare",
		Cooldown = 12,
		CooldownPerLevel = -0.2,
		MinCooldown = 6,
		Conditions = { AllyHealthBelow = 0.7 },
		Effects = {
			{ Type = "Heal", Target = "AllAllies", Multiplier = 1.5, PercentMaxHealth = 0.12, PerLevel = { Multiplier = 0.1, PercentMaxHealth = 0.005 } },
		},
	},

	SpiritStorm = {
		Id = "SpiritStorm",
		DisplayName = "Spirit Storm",
		Description = "A storm of spirits hits every enemy and mends the party.",
		Class = "Summoner",
		Subclass = "SpiritCaller",
		Rarity = "Epic",
		Cooldown = 16,
		CooldownPerLevel = -0.2,
		MinCooldown = 9,
		Conditions = { MinEnemies = 2 },
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 2.0, PerLevel = { Multiplier = 0.15 } },
			{ Type = "Heal", Target = "AllAllies", Multiplier = 0.4, PerLevel = { Multiplier = 0.04 } },
		},
	},
	Pet_Arcanix = {
		Id = "Pet_Arcanix",
		DisplayName = "Arcane Echo",
		Description = "A wave of arcane energy hits every enemy.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 10,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Effects = {
			{ Type = "Damage", Target = "AllEnemies", Multiplier = 0.9, PerLevel = { Multiplier = 0.1 } },
		},
	},

	Pet_Skyhawk = {
		Id = "Pet_Skyhawk",
		DisplayName = "Hawk Strike",
		Description = "Dives on an enemy and marks it.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 11,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 1.8, PerLevel = { Multiplier = 0.12 } },
			{ Type = "ApplyStatus", Target = "Primary", Status = "Marked", Duration = 6, PerLevel = { Duration = 0.3 } },
		},
	},

	Pet_Shadowcat = {
		Id = "Pet_Shadowcat",
		DisplayName = "Shadow Pounce",
		Description = "Pounces on an enemy; its owner attacks faster for a moment.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 10,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Effects = {
			{ Type = "Damage", Target = "Primary", Multiplier = 2.2, PerLevel = { Multiplier = 0.15 } },
			{ Type = "ApplyStatus", Target = "Self", Status = "Hasted", Duration = 4, PerLevel = { Duration = 0.2 } },
		},
	},

	Pet_Spiritling = {
		Id = "Pet_Spiritling",
		DisplayName = "Spirit Link",
		Description = "Heals the most hurt ally and shields them.",
		Class = "Pet",
		Pet = true,
		Rarity = "Epic",
		Cooldown = 11,
		CooldownPerLevel = -0.3,
		MinCooldown = 5,
		Conditions = { AllyHealthBelow = 0.75 },
		Effects = {
			{ Type = "Heal", Target = "LowestAlly", Multiplier = 2.0, PerLevel = { Multiplier = 0.16 } },
			{ Type = "Shield", Target = "LowestAlly", PercentMaxHealth = 0.1, Duration = 6, PerLevel = { PercentMaxHealth = 0.01, Duration = 0.2 } },
		},
	},

}
