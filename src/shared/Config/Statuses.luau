--[[
	Statuses (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Statuses

	A status is a timed effect on a combatant. It can do three things:

	  Mods   change stats while active. Each is { Stat, Mode, Value }:
	           Mode "Mult" multiplies the stat, Mode "Add" adds to it.
	           (Add is applied first, then Mult.)
	  Flags  named switches that combat rules look for:
	           Taunting      enemies must attack this combatant first
	           PreventLethal damage can never reduce health below 1
	           Absorb        soaks damage up to the status's Amount (a shield)
	  Amount (set when applied, not here) the remaining shield points.

	Reapplying a status that is already active refreshes its duration (a
	shield keeps whichever Amount is larger).

	Stats that are not in an entity's Stats table fall back to defaults
	(DamageDealt 1, MagicalDamageDealt 1, HealingDealt 1, DamageTaken 1,
	CritMultiplier 1.5, AttackSpeed 1), so seasonal mechanics can modify
	them freely.
]]

return {
	-- Defense ------------------------------------------------------------------
	Fortified = {
		Id = "Fortified",
		DisplayName = "Fortified",
		Description = "Defense increased.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 1.5 } },
	},

	IronSkin = {
		Id = "IronSkin",
		DisplayName = "Iron Skin",
		Description = "Defense greatly increased.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 1.8 } },
	},

	Shield = {
		Id = "Shield",
		DisplayName = "Shield",
		Description = "Absorbs damage before health is lost.",
		Flags = { Absorb = true },
	},

	Taunting = {
		Id = "Taunting",
		DisplayName = "Taunting",
		Description = "Enemies attack this combatant first.",
		Flags = { Taunting = true },
	},

	LastStand = {
		Id = "LastStand",
		DisplayName = "Last Stand",
		Description = "Cannot be reduced below 1 health.",
		Flags = { PreventLethal = true },
	},

	GuardianAngel = {
		Id = "GuardianAngel",
		DisplayName = "Guardian Angel",
		Description = "Protected from lethal damage.",
		Flags = { PreventLethal = true },
	},

	-- Party buffs ----------------------------------------------------------------
	Rallied = {
		Id = "Rallied",
		DisplayName = "Rallied",
		Description = "Defense and attack increased by a rallying cry.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 1.4 }, { Stat = "Attack", Mode = "Mult", Value = 1.1 } }, -- Attack added 2026-11-19
	},

	Blessed = {
		Id = "Blessed",
		DisplayName = "Blessed",
		Description = "Attack increased.",
		Mods = { { Stat = "Attack", Mode = "Mult", Value = 1.25 } }, -- was 1.2 (2026-11-19: the Cleric's main way to add party damage)
	},

	ArcaneSurge = {
		Id = "ArcaneSurge",
		DisplayName = "Arcane Surge",
		Description = "Magical damage increased.",
		Mods = { { Stat = "MagicalDamageDealt", Mode = "Mult", Value = 1.5 } },
	},

	-- Subclass buffs --------------------------------------------------------------
	Frenzied = {
		Id = "Frenzied",
		DisplayName = "Frenzied",
		Description = "Attack and attack speed greatly increased.",
		Mods = { { Stat = "Attack", Mode = "Mult", Value = 1.35 }, { Stat = "AttackSpeed", Mode = "Mult", Value = 1.3 } },
	},

	Unbreakable = {
		Id = "Unbreakable",
		DisplayName = "Unbreakable",
		Description = "Defense more than doubled.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 2.2 } },
	},

	Aegis = {
		Id = "Aegis",
		DisplayName = "Aegis",
		Description = "Defense increased by a holy ward.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 1.6 } },
	},

	-- Debuffs --------------------------------------------------------------------
	Chilled = {
		Id = "Chilled",
		DisplayName = "Chilled",
		Description = "Attack speed reduced.",
		Mods = { { Stat = "AttackSpeed", Mode = "Mult", Value = 0.6 } },
	},

	Enraged = {
		Id = "Enraged",
		DisplayName = "Enraged",
		Description = "Hits much harder and faster.",
		Mods = { { Stat = "Attack", Mode = "Mult", Value = 1.5 }, { Stat = "AttackSpeed", Mode = "Mult", Value = 1.25 } },
	},

	-- Class statuses (Mage, Ranger, Rogue, Summoner) ---------------------------------------
	-- Dot = damage over time: every Interval seconds the holder takes Multiplier x the SOURCE's Attack (times the status Strength).
	Burning = {
		Id = "Burning",
		DisplayName = "Burning",
		Description = "Takes fire damage every second.",
		-- Stacks up to 5 (each fire spell adds one): every stack burns for Multiplier x Attack plus a slice of max health (capped, and
		-- only 40% as much against bosses - see Simulation percentDamage)
		Stacks = { Max = 5 },
		Dot = { Interval = 1, Multiplier = 0.22, PercentMaxHealth = 0.006, PercentCap = 0.22, DamageType = "Magical", Element = "Fire", Tag = "Burning" },
	},
	Poisoned = {
		Id = "Poisoned",
		DisplayName = "Poisoned",
		Description = "Takes poison damage every second.",
		-- Rogue poison stacks deeper (8) and each stack bites harder as it builds: the big payoff of the Rogue's stacking
		Stacks = { Max = 8 },
		Dot = { Interval = 1, Multiplier = 0.16, PercentMaxHealth = 0.008, PercentCap = 0.2, DamageType = "Physical", Element = "Poison", Tag = "Poisoned" },
	},
	Bleeding = {
		Id = "Bleeding",
		DisplayName = "Bleeding",
		Description = "Loses blood every second; stacks up to 5.",
		Stacks = { Max = 5 },
		Dot = { Interval = 1, Multiplier = 0.14, PercentMaxHealth = 0.005, PercentCap = 0.16, DamageType = "Physical", Element = "Blood", Tag = "Bleeding" },
	},
	-- Frozen: cannot attack or cast (bosses are immune; they get Chilled instead from the same skills).
	Frozen = {
		Id = "Frozen",
		DisplayName = "Frozen",
		Description = "Frozen solid: cannot act.",
		Flags = { Stunned = true },
	},
	-- Stunned: hard crowd control. Only bosses stun heroes (and bosses themselves cannot be stunned).
	Stunned = {
		Id = "Stunned",
		DisplayName = "Stunned",
		Description = "Stunned: cannot act.",
		Flags = { Stunned = true },
	},
	Snared = {
		Id = "Snared",
		DisplayName = "Snared",
		Description = "Attacks much more slowly.",
		Mods = { { Stat = "AttackSpeed", Mode = "Mult", Value = 0.5 } },
	},
	Marked = {
		Id = "Marked",
		DisplayName = "Marked",
		Description = "Takes more damage.",
		Mods = { { Stat = "DamageTaken", Mode = "Mult", Value = 1.3 } },
	},
	Cursed = {
		Id = "Cursed",
		DisplayName = "Cursed",
		Description = "Takes more damage and hits weaker.",
		Mods = { { Stat = "DamageTaken", Mode = "Mult", Value = 1.2 }, { Stat = "Attack", Mode = "Mult", Value = 0.85 } },
	},
	-- Combo layers (2026-11-19): builder skills add a layer, the class finisher deals more per layer and removes them all.
	ArcaneCharge = {
		Id = "ArcaneCharge",
		DisplayName = "Arcane Charge",
		Description = "Combo layers: ArcaneBlast hits 30% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	Tracked = {
		Id = "Tracked",
		DisplayName = "Tracked",
		Description = "Combo layers: ExplosiveArrow hits 25% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	Opened = {
		Id = "Opened",
		DisplayName = "Opened",
		Description = "Combo layers: Eviscerate hits 30% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	Sundered = {
		Id = "Sundered",
		DisplayName = "Sundered",
		Description = "Combo layers: CrushingBlow hits 25% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	Judged = {
		Id = "Judged",
		DisplayName = "Judged",
		Description = "Combo layers: Judgment hits 30% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	SoulRot = {
		Id = "SoulRot",
		DisplayName = "Soul Rot",
		Description = "Combo layers: SoulLeech hits 20% harder per layer and uses them up (up to 5).",
		Stacks = { Max = 5 },
		Combo = true,
	},
	TeamAura = {
		Id = "TeamAura",
		DisplayName = "Team Aura",
		Description = "A full team (a tank, a healer and two damage heroes): more health, attack and defense for the whole fight.",
	},
	Exposed = {
		Id = "Exposed",
		DisplayName = "Exposed",
		Description = "Takes more damage (busy fighting a taunting Warrior).",
		Mods = { { Stat = "DamageTaken", Mode = "Mult", Value = 1.1 } },
	},
	Consecrated = {
		Id = "Consecrated",
		DisplayName = "Consecrated",
		Description = "Takes more damage and hits weaker (holy ground from a Cleric's Purify).",
		Mods = { { Stat = "DamageTaken", Mode = "Mult", Value = 1.15 }, { Stat = "Attack", Mode = "Mult", Value = 0.9 } },
	},
	Hasted = {
		Id = "Hasted",
		DisplayName = "Hasted",
		Description = "Attack speed greatly increased.",
		Mods = { { Stat = "AttackSpeed", Mode = "Mult", Value = 1.5 } },
	},
	Evasive = {
		Id = "Evasive",
		DisplayName = "Evasive",
		Description = "Takes much less damage.",
		Mods = { { Stat = "DamageTaken", Mode = "Mult", Value = 0.6 } },
	},
	DeadEye = {
		Id = "DeadEye",
		DisplayName = "Dead Eye",
		Description = "Crit chance and attack greatly increased.",
		Mods = { { Stat = "CritChance", Mode = "Add", Value = 0.3 }, { Stat = "Attack", Mode = "Mult", Value = 1.15 } },
	},
	Emboldened = {
		Id = "Emboldened",
		DisplayName = "Emboldened",
		Description = "Attack and attack speed increased.",
		Mods = { { Stat = "Attack", Mode = "Mult", Value = 1.2 }, { Stat = "AttackSpeed", Mode = "Mult", Value = 1.15 } },
	},
	Shadowed = {
		Id = "Shadowed",
		DisplayName = "Shadowed",
		Description = "Crits much harder.",
		Mods = { { Stat = "CritMultiplier", Mode = "Add", Value = 0.6 }, { Stat = "CritChance", Mode = "Add", Value = 0.15 } },
	},
}
