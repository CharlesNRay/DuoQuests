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
			Description = "More defense.",
			Class = "Warrior",
			Category = "Defense",
			UnlockStage = 1,
			Mods = { { Stat = "Defense", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		TreasureSense = {
			Id = "TreasureSense",
			DisplayName = "Treasure Sense",
			Description = "Enemies drop more gold.",
			Class = "Warrior",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		BruteForce = {
			Id = "BruteForce",
			DisplayName = "Brute Force",
			Description = "More damage dealt.",
			Class = "Warrior",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "DamageDealt", Mode = "Mult", Base = 0.025, PerLevel = 0.0025 } },
		},
		Vitality = {
			Id = "Vitality",
			DisplayName = "Vitality",
			Description = "More maximum health.",
			Class = "Warrior",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "MaxHealth", Mode = "Mult", Base = 0.04, PerLevel = 0.004 } },
		},
		QuickStudy = {
			Id = "QuickStudy",
			DisplayName = "Quick Study",
			Description = "Earn more experience.",
			Class = "Warrior",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		FortuneSeeker = {
			Id = "FortuneSeeker",
			DisplayName = "Fortune Seeker",
			Description = "Better item rarity from drops.",
			Class = "Warrior",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Cleric -------------------------------------------------------------------
		HolyLight = {
			Id = "HolyLight",
			DisplayName = "Holy Light",
			Description = "Stronger healing.",
			Class = "Cleric",
			Category = "Healing",
			UnlockStage = 1,
			Mods = { { Stat = "HealingDealt", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Tithe = {
			Id = "Tithe",
			DisplayName = "Tithe",
			Description = "Enemies drop more gold.",
			Class = "Cleric",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Devotion = {
			Id = "Devotion",
			DisplayName = "Devotion",
			Description = "More attack.",
			Class = "Cleric",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "Attack", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Warding = {
			Id = "Warding",
			DisplayName = "Warding",
			Description = "Take less damage.",
			Class = "Cleric",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "DamageTaken", Mode = "Mult", Base = -0.02, PerLevel = -0.002 } },
		},
		Scholar = {
			Id = "Scholar",
			DisplayName = "Scholar",
			Description = "Earn more experience.",
			Class = "Cleric",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Providence = {
			Id = "Providence",
			DisplayName = "Providence",
			Description = "Better item rarity from drops.",
			Class = "Cleric",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Mage ----------------------------------------
		ArcanePower = {
			Id = "ArcanePower",
			DisplayName = "Arcane Power",
			Description = "More damage dealt.",
			Class = "Mage",
			Category = "Damage",
			UnlockStage = 1,
			Mods = { { Stat = "DamageDealt", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Alchemy = {
			Id = "Alchemy",
			DisplayName = "Alchemy",
			Description = "Enemies drop more gold.",
			Class = "Mage",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Focus = {
			Id = "Focus",
			DisplayName = "Focus",
			Description = "Higher crit chance.",
			Class = "Mage",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "CritChance", Mode = "Add", Base = 0.015, PerLevel = 0.0015 } },
		},
		WardedRobes = {
			Id = "WardedRobes",
			DisplayName = "Warded Robes",
			Description = "More defense.",
			Class = "Mage",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "Defense", Mode = "Mult", Base = 0.04, PerLevel = 0.004 } },
		},
		Wisdom = {
			Id = "Wisdom",
			DisplayName = "Wisdom",
			Description = "Earn more experience.",
			Class = "Mage",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Gemcutter = {
			Id = "Gemcutter",
			DisplayName = "Gemcutter",
			Description = "Better item rarity from drops.",
			Class = "Mage",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Ranger ----------------------------------------
		SteadyAim = {
			Id = "SteadyAim",
			DisplayName = "Steady Aim",
			Description = "Higher crit chance.",
			Class = "Ranger",
			Category = "Damage",
			UnlockStage = 1,
			Mods = { { Stat = "CritChance", Mode = "Add", Base = 0.015, PerLevel = 0.0015 } },
		},
		Scavenger = {
			Id = "Scavenger",
			DisplayName = "Scavenger",
			Description = "Enemies drop more gold.",
			Class = "Ranger",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Fletching = {
			Id = "Fletching",
			DisplayName = "Fletching",
			Description = "More damage dealt.",
			Class = "Ranger",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "DamageDealt", Mode = "Mult", Base = 0.025, PerLevel = 0.0025 } },
		},
		Camouflage = {
			Id = "Camouflage",
			DisplayName = "Camouflage",
			Description = "Take less damage.",
			Class = "Ranger",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "DamageTaken", Mode = "Mult", Base = -0.02, PerLevel = -0.002 } },
		},
		Tracker = {
			Id = "Tracker",
			DisplayName = "Tracker",
			Description = "Earn more experience.",
			Class = "Ranger",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		KeenEye = {
			Id = "KeenEye",
			DisplayName = "Keen Eye",
			Description = "Better item rarity from drops.",
			Class = "Ranger",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Rogue ----------------------------------------
		Nimble = {
			Id = "Nimble",
			DisplayName = "Nimble",
			Description = "Attack faster.",
			Class = "Rogue",
			Category = "Damage",
			UnlockStage = 1,
			Mods = { { Stat = "AttackSpeed", Mode = "Mult", Base = 0.03, PerLevel = 0.003 } },
		},
		Pickpocket = {
			Id = "Pickpocket",
			DisplayName = "Pickpocket",
			Description = "Enemies drop more gold.",
			Class = "Rogue",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Lethality = {
			Id = "Lethality",
			DisplayName = "Lethality",
			Description = "Crits hit harder.",
			Class = "Rogue",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "CritMultiplier", Mode = "Add", Base = 0.06, PerLevel = 0.006 } },
		},
		Fleetfoot = {
			Id = "Fleetfoot",
			DisplayName = "Fleetfoot",
			Description = "Take less damage.",
			Class = "Rogue",
			Category = "Defense",
			UnlockStage = 30,
			Mods = { { Stat = "DamageTaken", Mode = "Mult", Base = -0.02, PerLevel = -0.002 } },
		},
		Streetwise = {
			Id = "Streetwise",
			DisplayName = "Streetwise",
			Description = "Earn more experience.",
			Class = "Rogue",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Fence = {
			Id = "Fence",
			DisplayName = "Fence",
			Description = "Better item rarity from drops.",
			Class = "Rogue",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},

		-- Summoner ----------------------------------------
		SpiritBond = {
			Id = "SpiritBond",
			DisplayName = "Spirit Bond",
			Description = "Your minions are stronger.",
			Class = "Summoner",
			Category = "Damage",
			UnlockStage = 1,
			Mods = { { Stat = "MinionPower", Mode = "Add", Base = 0.05, PerLevel = 0.005 } },
		},
		Tribute = {
			Id = "Tribute",
			DisplayName = "Tribute",
			Description = "Enemies drop more gold.",
			Class = "Summoner",
			Category = "Gold",
			UnlockStage = 10,
			Mods = { { Stat = "GoldGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Dominion = {
			Id = "Dominion",
			DisplayName = "Dominion",
			Description = "More damage dealt.",
			Class = "Summoner",
			Category = "Damage",
			UnlockStage = 20,
			Mods = { { Stat = "DamageDealt", Mode = "Mult", Base = 0.025, PerLevel = 0.0025 } },
		},
		Vampirism = {
			Id = "Vampirism",
			DisplayName = "Vampirism",
			Description = "Heal for a share of the damage you deal.",
			Class = "Summoner",
			Category = "Healing",
			UnlockStage = 30,
			Mods = { { Stat = "Lifesteal", Mode = "Add", Base = 0.03, PerLevel = 0.004 } },
		},
		Occultist = {
			Id = "Occultist",
			DisplayName = "Occultist",
			Description = "Earn more experience.",
			Class = "Summoner",
			Category = "XP",
			UnlockStage = 40,
			Mods = { { Stat = "XPGain", Mode = "Add", Base = 0.08, PerLevel = 0.01 } },
		},
		Medium = {
			Id = "Medium",
			DisplayName = "Medium",
			Description = "Better item rarity from drops.",
			Class = "Summoner",
			Category = "Rarity",
			UnlockStage = 60,
			Mods = { { Stat = "ItemRarity", Mode = "Add", Base = 0.05, PerLevel = 0.008 } },
		},
	},
}
