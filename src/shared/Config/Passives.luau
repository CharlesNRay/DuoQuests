--[[
	Passives (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Passives

	Passives are class-specific buffs that are ALWAYS active. A player equips
	only a few at once (Slots), so the choice follows their goal: push stages,
	farm gold, level quickly or hunt rarer drops.

	Like skills, passive LEVELS BELONG TO THE SLOT (see Shared/Passives), so
	swapping a passive keeps the slot's level. Passives are unlocked by reaching
	a stage (UnlockStage = the player's frontier), not bought.

	  Slots        how many passives can be equipped
	  SlotUnlocks  { { Stage, Slots } } slots available at a frontier stage
	  Defs         the passives:
	    Class        who can use it
	    Category     "Damage", "Defense", "Healing", "Gold", "XP" or "Rarity"
	                 (what the UI groups and tags it by)
	    UnlockStage  frontier needed
	    Mods         list of { Stat, Mode, Base, PerLevel }
	                   value at a level = Base + PerLevel x (level - 1)
	                   Combat stats (applied to the combatant when a fight starts):
	                     Mode "Mult": stat x (1 + value)    e.g. Defense +8%
	                     Mode "Add":  stat + value          e.g. CritChance
	                     stats: MaxHealth, Attack, Defense, AttackSpeed, CritChance,
	                            DamageDealt, HealingDealt, DamageTaken (use a
	                            negative value to take less damage)
	                   Reward stats (summed across equipped passives; always "Add"):
	                     GoldGain, XPGain, ItemRarity

	Combat passives are deliberately small (pacing was tuned with them on; the
	simulated auto-player does not level passives yet). ItemRarity is stored and shown now and starts doing something once items
	drop. Every number here is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	Slots = 3,
	SlotUnlocks = {
		{ Stage = 1, Slots = 1 },
		{ Stage = 20, Slots = 2 },
		{ Stage = 50, Slots = 3 },
	},

	Defs = {
		-- Warrior ------------------------------------------------------------------
		IronHide = {
			Id = "IronHide",
			DisplayName = "Iron Hide",
			Description = "Always on: more defense.",
			Class = "Warrior",
			Category = "Defense",
			UnlockStage = 1,
			Mods = { { Stat = "Defense", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		TreasureSense = {
			Id = "TreasureSense",
			DisplayName = "Treasure Sense",
			Description = "Always on: enemies drop more gold.",
			Class = "Warrior",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		BruteForce = {
			Id = "BruteForce",
			DisplayName = "Brute Force",
			Description = "Always on: more damage dealt.",
			Class = "Warrior",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "DamageDealt", Mode = "Mult", Base = 0.025, PerLevel = 0.0025 } },
		},
		Vitality = {
			Id = "Vitality",
			DisplayName = "Vitality",
			Description = "Always on: more maximum health.",
			Class = "Warrior",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "MaxHealth", Mode = "Mult", Base = 0.04, PerLevel = 0.004 } },
		},
		QuickStudy = {
			Id = "QuickStudy",
			DisplayName = "Quick Study",
			Description = "Always on: earn more experience.",
			Class = "Warrior",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		FortuneSeeker = {
			Id = "FortuneSeeker",
			DisplayName = "Fortune Seeker",
			Description = "Always on: better item rarity from drops.",
			Class = "Warrior",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Cleric -------------------------------------------------------------------
		HolyLight = {
			Id = "HolyLight",
			DisplayName = "Holy Light",
			Description = "Always on: stronger healing.",
			Class = "Cleric",
			Category = "Healing",
			UnlockStage = 1,
			Mods = { { Stat = "HealingDealt", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Tithe = {
			Id = "Tithe",
			DisplayName = "Tithe",
			Description = "Always on: enemies drop more gold.",
			Class = "Cleric",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Devotion = {
			Id = "Devotion",
			DisplayName = "Devotion",
			Description = "Always on: more attack.",
			Class = "Cleric",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "Attack", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Warding = {
			Id = "Warding",
			DisplayName = "Warding",
			Description = "Always on: take less damage.",
			Class = "Cleric",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "DamageTaken", Mode = "Mult", Base = -0.02, PerLevel = -0.002 } },
		},
		Scholar = {
			Id = "Scholar",
			DisplayName = "Scholar",
			Description = "Always on: earn more experience.",
			Class = "Cleric",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Providence = {
			Id = "Providence",
			DisplayName = "Providence",
			Description = "Always on: better item rarity from drops.",
			Class = "Cleric",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},
	},
}
