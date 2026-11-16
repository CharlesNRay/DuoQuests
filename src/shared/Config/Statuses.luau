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
		Description = "Defense increased by a rallying cry.",
		Mods = { { Stat = "Defense", Mode = "Mult", Value = 1.4 } },
	},

	Blessed = {
		Id = "Blessed",
		DisplayName = "Blessed",
		Description = "Attack increased.",
		Mods = { { Stat = "Attack", Mode = "Mult", Value = 1.2 } },
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
		Dot = { Interval = 1, Multiplier = 0.3, DamageType = "Magical", Element = "Fire", Tag = "Burning" },
	},
	Poisoned = {
		Id = "Poisoned",
		DisplayName = "Poisoned",
		Description = "Takes poison damage every second.",
		Dot = { Interval = 1, Multiplier = 0.25, DamageType = "Physical", Element = "Poison", Tag = "Poisoned" },
	},
	-- Frozen: cannot attack or cast (bosses are immune; they get Chilled instead from the same skills).
	Frozen = {
		Id = "Frozen",
		DisplayName = "Frozen",
		Description = "Frozen solid: cannot act.",
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
