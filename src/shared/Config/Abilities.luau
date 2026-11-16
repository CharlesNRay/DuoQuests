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

}
