--[[
	Classes (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Classes

	Every number here is a PLACEHOLDER to be tuned during playtesting.

	Each class has:
	  BasicAttack      the one automatic attack. Presentation info for now
	                   (Range "Melee"/"Ranged"); damage uses Attack and DamageType.
	  AbilityPool      every skill the class can ever equip, in display order.
	  PassivePool      every passive the class can ever equip (Config/Passives),
	                   in display order. Passives are class specific.
	  DefaultLoadout   four skills in PRIORITY order (slot 1 is checked first
	                   each tick). Also the skills a new player starts owning.
	  Subclasses       empty for now. Later each entry goes here as
	                   Subclasses = { Berserker = { ...stat tweaks, extra skills... } }
	                   with the choice stored as Season.SubclassId.

	Six classes: Warrior (tank), Cleric (healer), and four damage classes: Mage (burst and control),
	Ranger (steady ranged, pets), Rogue (fast, crits) and Summoner (minions paid for in health, and life drain).
]]

local Economy = require(script.Parent.Economy)

local Classes = {
	Warrior = {
		Id = "Warrior",
		DisplayName = "Warrior",
		Blurb = "A frontline fighter. Draws enemy attacks with Taunt, shields the party and wins by outlasting. Paths: Berserker (damage) or Guardian (protector).",
		Weapon = { Name = "Steel Sword", Text = "A heavy blade for holding the line." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Tank",
		DamageType = "Physical",
		BasicAttack = { Id = "SwordSlash", DisplayName = "Sword Slash", Range = "Melee" },

		BaseStats = {
			MaxHealth = 260, -- was 200 (2026-11-18: the tank of a four-hero party died in every fight)
			Attack = 12,
			Defense = 14, -- was 10
			AttackSpeed = 1.0, -- basic attacks per second
			CritChance = 0.05,
		},
		GrowthPerLevel = {
			MaxHealth = 30, -- was 25, then 35 (2026-11-25: with longer fights Warrior parties led at L100, 165-172)
			Attack = 2,
			Defense = 2.5, -- was 2, then 3 (2026-11-25)
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"ShieldBash",
			"Taunt",
			"IronSkin",
			"Whirlwind",
			"ShieldWall",
			"CrushingBlow",
			"LastStand",
			"RallyingCry",
		},
		PassivePool = { "IronHide", "TreasureSense", "BruteForce", "Vitality", "QuickStudy", "FortuneSeeker" },
		DefaultLoadout = { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" },
		Subclasses = {},
	},

	Cleric = {
		Id = "Cleric",
		DisplayName = "Cleric",
		Blurb = "A holy caster. Heals, shields and revives allies, with holy damage on the side. Paths: Priest (healer) or Templar (holy warrior).",
		Weapon = { Name = "Sun Mace", Text = "A blessed mace that glows with healing light." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Healer",
		DamageType = "Magical",
		BasicAttack = { Id = "HolyBolt", DisplayName = "Holy Bolt", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 130,
			Attack = 16, -- was 14 (2026-11-19: Cleric teams cleared stages slowest, fr 39-45 at L40)
			Defense = 4,
			AttackSpeed = 0.9,
			CritChance = 0.05,
		},
		GrowthPerLevel = {
			MaxHealth = 15,
			Attack = 2.9, -- was 2.5
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"Smite",
			"Heal",
			"Blessing",
			"Purify",
			"RadiantBurst",
			"DivineShield",
			"GroupHeal",
			"GuardianAngel",
			"Judgment",
			"Resurrection",
		},
		PassivePool = { "HolyLight", "Tithe", "Devotion", "Warding", "Scholar", "Providence" },
		DefaultLoadout = { "Heal", "Blessing", "RadiantBurst", "Smite" },
		Subclasses = {},
	},

	Mage = {
		Id = "Mage",
		DisplayName = "Mage",
		Blurb = "Ranged spell damage. Fire, frost and lightning hit hard and wide, but the mage is fragile. Paths: Pyromancer (burning) or Frost Weaver (control).",
		Weapon = { Name = "Arcane Staff", Text = "A staff topped with a swirling arcane orb." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Damage",
		DamageType = "Magical",
		BasicAttack = { Id = "ArcaneMissile", DisplayName = "Arcane Missile", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 120, -- was 110 (2026-11-18: the squishiest class died first in long four-hero fights)
			Attack = 18,
			Defense = 3,
			AttackSpeed = 0.8,
			CritChance = 0.08,
		},
		GrowthPerLevel = {
			MaxHealth = 12,
			Attack = 3,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"Fireball",
			"Blizzard",
			"LightningBolt",
			"ArcaneSurge",
			"ArcaneBlast",
			"ChainLightning",
			"ManaShield",
			"Meteor",
		},
		PassivePool = { "ArcanePower", "Alchemy", "Focus", "WardedRobes", "Wisdom", "Gemcutter" },
		DefaultLoadout = { "Fireball", "Blizzard", "LightningBolt", "ArcaneSurge" },
		Subclasses = {},
	},

	Ranger = {
		Id = "Ranger",
		DisplayName = "Ranger",
		Blurb = "A marksman with steady ranged damage, snares and marks. Paths: Sharpshooter (big crits) or Beastmaster (much stronger pets).",
		Weapon = { Name = "Longbow", Text = "A tall bow for shots from afar." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Damage",
		DamageType = "Physical",
		BasicAttack = { Id = "ArrowShot", DisplayName = "Arrow Shot", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 120,
			Attack = 14,
			Defense = 5,
			AttackSpeed = 1.1,
			CritChance = 0.12,
		},
		GrowthPerLevel = {
			MaxHealth = 14,
			Attack = 2.6,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"PowerShot",
			"Volley",
			"PiercingArrow",
			"Snare",
			"Evasion",
			"HuntersMark",
			"RapidFire",
			"ExplosiveArrow",
		},
		PassivePool = { "SteadyAim", "Scavenger", "Fletching", "Camouflage", "Tracker", "KeenEye" },
		DefaultLoadout = { "PowerShot", "Volley", "Snare", "PiercingArrow" },
		Subclasses = {},
	},

	Rogue = {
		Id = "Rogue",
		DisplayName = "Rogue",
		Blurb = "A fast striker with crits, poison and dodging. Paths: Assassin (burst damage) or Duelist (evasion and ripostes).",
		Weapon = { Name = "Shadow Dagger", Text = "A keen blade that drinks the light." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Damage",
		DamageType = "Physical",
		BasicAttack = { Id = "DaggerStab", DisplayName = "Dagger Stab", Range = "Melee" },

		BaseStats = {
			MaxHealth = 125,
			Attack = 13,
			Defense = 4,
			AttackSpeed = 1.3,
			CritChance = 0.15,
		},
		GrowthPerLevel = {
			MaxHealth = 14,
			Attack = 2.2,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"Backstab",
			"FanOfKnives",
			"PoisonBlade",
			"Smokescreen",
			"Shadowstep",
			"Eviscerate",
			"Flurry",
			"Vanish",
		},
		PassivePool = { "Nimble", "Pickpocket", "Lethality", "Fleetfoot", "Streetwise", "Fence" },
		DefaultLoadout = { "Backstab", "FanOfKnives", "PoisonBlade", "Eviscerate" },
		Subclasses = {},
	},

	Summoner = {
		Id = "Summoner",
		DisplayName = "Summoner",
		Blurb = "Pays health to raise imps, skeletons and wraiths that fight and can die, casts dark spells and drains life to recover. Paths: Necromancer (ghouls, plague, lifesteal) or Spirit Caller (healing spirits).",
		Weapon = { Name = "Spirit Tome", Text = "A tome that whispers with the voices of spirits." }, -- the tool a player wields (see Shared/ClassWeapons)
		Role = "Damage",
		DamageType = "Magical",
		BasicAttack = { Id = "SpiritBolt", DisplayName = "Spirit Bolt", Range = "Ranged" },

		BaseStats = {
			MaxHealth = 120,
			Attack = 15,
			Defense = 4,
			AttackSpeed = 0.9,
			CritChance = 0.06,
		},
		GrowthPerLevel = {
			MaxHealth = 13,
			Attack = 2.7,
			Defense = 1,
			AttackSpeed = 0,
			CritChance = 0,
		},

		AbilityPool = {
			"SummonImp",
			"WraithSwarm",
			"SoulLeech",
			"RaiseSkeleton",
			"Haunt",
			"Devour",
			"BoneArmor",
			"CallTitan",
		},
		PassivePool = { "SpiritBond", "Tribute", "Dominion", "Vampirism", "Occultist", "Medium" },
		DefaultLoadout = { "SummonImp", "RaiseSkeleton", "SoulLeech", "Haunt" },
		Subclasses = {},
	},
}

-- every health, attack and defense number is NumberScale times bigger (see Config/Economy)
for _, class in pairs(Classes) do
	for _, group in ipairs({ class.BaseStats, class.GrowthPerLevel }) do
		for _, stat in ipairs({ "MaxHealth", "Attack", "Defense" }) do
			if group[stat] then
				group[stat] *= Economy.NumberScale
			end
		end
	end
end

return Classes
