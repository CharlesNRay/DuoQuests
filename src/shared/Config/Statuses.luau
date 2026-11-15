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
}
