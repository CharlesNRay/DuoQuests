--[[
	Gear (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Gear

	Equipment drops from stages. Seven item types (worn in eight slots), three rarities (same ones as skills,
	see Config/Rarities). An item remembers the stage it dropped at (its Power),
	so a drop from stage 40 beats the same rarity from stage 5. Gear is
	SEASONAL: it lives in Season.Equipment and resets with the season.

	  Slots        display order; each gives one flat stat bonus
	  Names        item names by slot and rarity
	  RarityMult   how much stronger rarer items are
	  Drop         chances (every number is a PLACEHOLDER to be tuned)

	Stat at drop stage S for an item of a slot:  (Base + PerStage * S) * RarityMult
]]

local Economy = require(script.Parent.Economy)

local Gear = {
	-- Blacksmith upgrades: each level adds ValuePerLevel of the item's base stat. The cost grows
	-- with the level and with the stage the item dropped at. Gold is the only cost.
	Upgrade = { MaxLevel = 10, ValuePerLevel = 0.1, BaseCost = 1200, CostGrowth = 1.42, PowerCost = 72 },

	-- every drop rolls its stat between Min and Max of the base value (a 'good roll' shows as a percentage on the item)
	Roll = { Min = 0.85, Max = 1.15 },
	InventoryCap = 30, -- starting bag size; a full bag sells new drops automatically
	BagStep = 5, -- slots added by each bag upgrade (bought at the Merchant)
	BagMaxUpgrades = 14, -- 30 -> 100 slots
	BagCost = { Base = 9000, Growth = 1.32 }, -- gold for upgrade n (0-based): Base * Growth^n

	-- Item TYPES. Each gives one stat: (Base + PerStage * stage) * rarity * upgrades.
	Slots = {
		Weapon = { Stat = "Attack", Base = 0.3, PerStage = 0.05 },
		Helmet = { Stat = "Defense", Base = 0.1, PerStage = 0.0175 },
		Armor = { Stat = "MaxHealth", Base = 3, PerStage = 0.5 },
		Pants = { Stat = "Haste", Base = 0.003, PerStage = 0.0004 }, -- Haste: shorter skill cooldowns
		Boots = { Stat = "AttackSpeed", Base = 0.008, PerStage = 0.0015 },
		Ring = { Stat = "CritChance", Base = 0.003, PerStage = 0.0005 },
		Amulet = { Stat = "DamageDealt", Base = 0.004, PerStage = 0.0008 },
	},
	Types = { "Weapon", "Helmet", "Armor", "Pants", "Boots", "Ring", "Amulet" },
	-- Where things are WORN. Two rings, so a type can have more than one worn slot.
	SlotOrder = { "Helmet", "Amulet", "Armor", "Weapon", "Pants", "Ring1", "Ring2", "Boots" },
	WornType = { Helmet = "Helmet", Amulet = "Amulet", Armor = "Armor", Weapon = "Weapon", Pants = "Pants", Ring1 = "Ring", Ring2 = "Ring", Boots = "Boots" },
	-- pieces of one set worn together that switch a bonus on
	SetThresholds = { 2, 4 },

	Names = {
		Weapon = { Common = "Iron Sword", Uncommon = "Hunter's Blade", Rare = "Steel Blade", Epic = "Dragonfang", Legendary = "Moonsteel Saber" },
		Helmet = { Common = "Leather Cap", Uncommon = "Hardened Helm", Rare = "Iron Helm", Epic = "Crown of Valor", Legendary = "Halo of Ages" },
		Armor = { Common = "Leather Vest", Uncommon = "Studded Armor", Rare = "Chain Mail", Epic = "Aegis Plate", Legendary = "Mythic Bulwark" },
		Pants = { Common = "Cloth Pants", Uncommon = "Reinforced Pants", Rare = "Mail Leggings", Epic = "Titan Greaves", Legendary = "Giantstride Greaves" },
		Boots = { Common = "Worn Boots", Uncommon = "Trailblazer Boots", Rare = "Swift Boots", Epic = "Windrunners", Legendary = "Skystep Treads" },
		Ring = { Common = "Copper Ring", Uncommon = "Bronze Signet", Rare = "Silver Ring", Epic = "Ring of Fate", Legendary = "Ring of Eternity" },
		Amulet = { Common = "Lucky Charm", Uncommon = "Fox Talisman", Rare = "Jade Amulet", Epic = "Star Pendant", Legendary = "Heart of the World" },
	},

	-- Item names by CLASS (the bag shows what suits the class you play). Rings and amulets are shared.
	ClassNames = {
		Warrior = {
			Weapon = { Common = "Iron Sword", Uncommon = "Hunter's Blade", Rare = "Steel Blade", Epic = "Dragonfang", Legendary = "Moonsteel Saber" },
			Helmet = { Common = "Leather Cap", Uncommon = "Hardened Helm", Rare = "Iron Helm", Epic = "Crown of Valor", Legendary = "Halo of Ages" },
			Armor = { Common = "Leather Vest", Uncommon = "Studded Armor", Rare = "Chain Mail", Epic = "Aegis Plate", Legendary = "Mythic Bulwark" },
			Pants = { Common = "Cloth Pants", Uncommon = "Reinforced Pants", Rare = "Mail Leggings", Epic = "Titan Greaves", Legendary = "Giantstride Greaves" },
			Boots = { Common = "Worn Boots", Uncommon = "Trailblazer Boots", Rare = "Swift Boots", Epic = "Windrunners", Legendary = "Skystep Treads" },
		},
		Ranger = {
			Weapon = { Common = "Short Bow", Uncommon = "Hunter's Bow", Rare = "Longbow", Epic = "Stormstring Bow", Legendary = "Windpiercer" },
			Helmet = { Common = "Hunter's Hood", Uncommon = "Scout's Cowl", Rare = "Ranger's Hood", Epic = "Eagle-eye Cowl", Legendary = "Crown of the Wild" },
			Armor = { Common = "Hide Jerkin", Uncommon = "Scout's Leathers", Rare = "Ranger's Cloak", Epic = "Stalker's Mantle", Legendary = "Mantle of the Wild" },
			Pants = { Common = "Hide Leggings", Uncommon = "Scout's Breeches", Rare = "Ranger's Trousers", Epic = "Stalker's Leggings", Legendary = "Wildstride Leggings" },
			Boots = { Common = "Soft Boots", Uncommon = "Trailwalker Boots", Rare = "Quiet Boots", Epic = "Fleetfoot Boots", Legendary = "Skystep Treads" },
		},
		Mage = {
			Weapon = { Common = "Oak Staff", Uncommon = "Apprentice Staff", Rare = "Crystal Staff", Epic = "Arcane Scepter", Legendary = "Staff of Stars" },
			Helmet = { Common = "Cloth Hat", Uncommon = "Apprentice Hat", Rare = "Wizard Hat", Epic = "Archmage Circlet", Legendary = "Crown of Stars" },
			Armor = { Common = "Cloth Robe", Uncommon = "Apprentice Robe", Rare = "Silk Robe", Epic = "Archmage Robe", Legendary = "Starweave Vestments" },
			Pants = { Common = "Cloth Skirt", Uncommon = "Apprentice Legwraps", Rare = "Silk Leggings", Epic = "Archmage Leggings", Legendary = "Starweave Leggings" },
			Boots = { Common = "Cloth Slippers", Uncommon = "Apprentice Shoes", Rare = "Silk Slippers", Epic = "Stormwalkers", Legendary = "Cloudstep Slippers" },
		},
		Cleric = {
			Weapon = { Common = "Wooden Mace", Uncommon = "Blessed Mace", Rare = "Silver Mace", Epic = "Dawnbringer", Legendary = "Scepter of Light" },
			Helmet = { Common = "Cloth Coif", Uncommon = "Blessed Coif", Rare = "Silver Circlet", Epic = "Seraph's Circlet", Legendary = "Halo of Ages" },
			Armor = { Common = "Linen Vestment", Uncommon = "Blessed Vestment", Rare = "Temple Mail", Epic = "Seraph's Vestment", Legendary = "Mantle of Grace" },
			Pants = { Common = "Linen Skirt", Uncommon = "Blessed Leggings", Rare = "Temple Greaves", Epic = "Seraph's Greaves", Legendary = "Graceful Greaves" },
			Boots = { Common = "Pilgrim Sandals", Uncommon = "Blessed Sandals", Rare = "Temple Boots", Epic = "Seraph's Boots", Legendary = "Lightstep Boots" },
		},
		Rogue = {
			Weapon = { Common = "Rusty Daggers", Uncommon = "Alley Daggers", Rare = "Steel Daggers", Epic = "Nightfang Daggers", Legendary = "Shadowbite Daggers" },
			Helmet = { Common = "Rag Mask", Uncommon = "Alley Hood", Rare = "Shadow Mask", Epic = "Nightveil Mask", Legendary = "Mask of a Thousand Faces" },
			Armor = { Common = "Dark Vest", Uncommon = "Alley Leathers", Rare = "Shadow Leathers", Epic = "Nightveil Garb", Legendary = "Mantle of Shadows" },
			Pants = { Common = "Dark Trousers", Uncommon = "Alley Breeches", Rare = "Shadow Trousers", Epic = "Nightveil Leggings", Legendary = "Shadowstep Leggings" },
			Boots = { Common = "Soft Soles", Uncommon = "Alley Boots", Rare = "Silent Boots", Epic = "Nightstalkers", Legendary = "Voidstep Boots" },
		},
		Summoner = {
			Weapon = { Common = "Bone Wand", Uncommon = "Grave Wand", Rare = "Skull Scepter", Epic = "Soulbinder Grimoire", Legendary = "Grimoire of the Dead" },
			Helmet = { Common = "Bone Circlet", Uncommon = "Grave Hood", Rare = "Skull Crown", Epic = "Soulbinder Crown", Legendary = "Crown of the Dead" },
			Armor = { Common = "Gravecloth Robe", Uncommon = "Tattered Shroud", Rare = "Necro Robe", Epic = "Soulbinder Robe", Legendary = "Shroud of the Dead" },
			Pants = { Common = "Gravecloth Wraps", Uncommon = "Tattered Leggings", Rare = "Necro Leggings", Epic = "Soulbinder Leggings", Legendary = "Deathwalk Leggings" },
			Boots = { Common = "Bone Sandals", Uncommon = "Grave Boots", Rare = "Necro Boots", Epic = "Soulbinder Boots", Legendary = "Deathwalk Boots" },
		},
	},
	-- the weapon noun used for a zone SET weapon, per class ("Meadow Warden Longbow")
	ClassWeaponNoun = { Warrior = "Blade", Ranger = "Longbow", Mage = "Staff", Cleric = "Mace", Rogue = "Daggers", Summoner = "Grimoire" },

	RarityMult = { Common = 1, Uncommon = 1.25, Rare = 1.55, Epic = 2.2, Legendary = 3.2, Set = 1.8 },
	SellValue = { Common = 50, Uncommon = 100, Rare = 200, Epic = 450, Legendary = 1100 }, -- gold per item (before stage scaling)
	SellPerStage = 5, -- extra gold per stage of Power

	-- SET GEAR (ordinary wearable gear, not a separate loot roll). Every zone (10 stages) has its own 3-piece set. Pieces only drop while you
	-- fight a stage in that zone (frontier or replay), so a player stuck in a zone can farm
	-- it. A piece is a bit stronger than a normal item (RarityMult.Set) and wearing 2 or 3
	-- pieces of one set adds a bonus. Bonus mods use the usual { Stat, Mode, Value }.
	SetDropChance = 0.22, -- of the drops that happen, how many turn out to be a piece of the zone's set
	SetBossChance = 0.6, -- boss stage: chance the (guaranteed) drop is a set piece
	Sets = {
		{ Name = "Meadow Warden", Pieces = { Weapon = "Warden's Blade", Armor = "Warden's Vest", Trinket = "Warden's Charm" },
			Bonus2 = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.04 } }, Bonus3 = { { Stat = "Attack", Mode = "Mul", Value = 0.05 }, { Stat = "Defense", Mode = "Mul", Value = 0.05 } } },
		{ Name = "Forest Stalker", Pieces = { Weapon = "Stalker's Bow", Armor = "Stalker's Cloak", Trinket = "Stalker's Fang" },
			Bonus2 = { { Stat = "CritChance", Mode = "Add", Value = 0.02 } }, Bonus3 = { { Stat = "Attack", Mode = "Mul", Value = 0.06 }, { Stat = "AttackSpeed", Mode = "Mul", Value = 0.04 } } },
		{ Name = "Stonebreak Plate", Pieces = { Weapon = "Stonebreaker", Armor = "Stonebreak Plate", Trinket = "Granite Sigil" },
			Bonus2 = { { Stat = "Defense", Mode = "Mul", Value = 0.06 } }, Bonus3 = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.08 }, { Stat = "DamageTaken", Mode = "Mul", Value = -0.03 } } },
		{ Name = "Glimmer Regalia", Pieces = { Weapon = "Glimmer Staff", Armor = "Glimmer Robe", Trinket = "Geode Pendant" },
			Bonus2 = { { Stat = "HealingDealt", Mode = "Mul", Value = 0.05 } }, Bonus3 = { { Stat = "Attack", Mode = "Mul", Value = 0.06 }, { Stat = "CritChance", Mode = "Add", Value = 0.03 } } },
		{ Name = "Dune Wanderer", Pieces = { Weapon = "Scimitar of Dunes", Armor = "Wanderer's Wraps", Trinket = "Sun Amulet" },
			Bonus2 = { { Stat = "AttackSpeed", Mode = "Mul", Value = 0.04 } }, Bonus3 = { { Stat = "DamageDealt", Mode = "Mul", Value = 0.06 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.05 } } },
		{ Name = "Frostguard", Pieces = { Weapon = "Rimeblade", Armor = "Frostguard Mail", Trinket = "Icicle Charm" },
			Bonus2 = { { Stat = "MaxHealth", Mode = "Mul", Value = 0.06 } }, Bonus3 = { { Stat = "Defense", Mode = "Mul", Value = 0.08 }, { Stat = "DamageTaken", Mode = "Mul", Value = -0.04 } } },
		{ Name = "Emberforged", Pieces = { Weapon = "Cinder Axe", Armor = "Emberforged Plate", Trinket = "Magma Core" },
			Bonus2 = { { Stat = "Attack", Mode = "Mul", Value = 0.05 } }, Bonus3 = { { Stat = "DamageDealt", Mode = "Mul", Value = 0.08 }, { Stat = "CritChance", Mode = "Add", Value = 0.03 } } },
		{ Name = "Mire Hunter", Pieces = { Weapon = "Bog Spear", Armor = "Mire Hide", Trinket = "Swamp Totem" },
			Bonus2 = { { Stat = "CritChance", Mode = "Add", Value = 0.03 } }, Bonus3 = { { Stat = "HealingDealt", Mode = "Mul", Value = 0.06 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.06 } } },
		{ Name = "Tidebound Relics", Pieces = { Weapon = "Tidal Trident", Armor = "Coral Armor", Trinket = "Sunken Coin" },
			Bonus2 = { { Stat = "Defense", Mode = "Mul", Value = 0.07 } }, Bonus3 = { { Stat = "Attack", Mode = "Mul", Value = 0.07 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.07 } } },
		{ Name = "Skyborn", Pieces = { Weapon = "Cloudpiercer", Armor = "Skyborn Raiment", Trinket = "Wind Feather" },
			Bonus2 = { { Stat = "AttackSpeed", Mode = "Mul", Value = 0.05 } }, Bonus3 = { { Stat = "DamageDealt", Mode = "Mul", Value = 0.08 }, { Stat = "Attack", Mode = "Mul", Value = 0.06 } } },
	},

	Drop = {
		Chance = 0.2, -- per won fight at the frontier
		ReplayChance = 0.1, -- replaying a cleared stage
		BossChance = 1, -- boss stages always drop
		-- weights for the rarity roll
		-- Rarity depends on how far you have got (the frontier stage), blended smoothly between these anchors:
		-- ~stages 1-20 Common/Uncommon, 20-40 Uncommon/Rare (a little Epic), 40-60 Rare/Epic, 60+ Epic/Legendary.
		-- (Stage numbers roughly match player levels; tune freely.)
		Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
		Anchors = {
			{ Stage = 10, Weights = { Common = 60, Uncommon = 40 } },
			{ Stage = 30, Weights = { Uncommon = 45, Rare = 50, Epic = 5 } },
			{ Stage = 50, Weights = { Rare = 30, Epic = 65, Legendary = 5 } },
			{ Stage = 70, Weights = { Epic = 75, Legendary = 25 } },
			{ Stage = 100, Weights = { Epic = 50, Legendary = 50 } },
		},
		-- each 0.1 of the ItemRarity passive bonus moves this much weight from Common
		BonusShift = 60,
	},
	-- bad-luck protection (catch-up only): after this many won fights (replays count) with no gear upgrade,
	-- if your weakest worn piece is below BelowPar of a "par" item (your best cleared stage, that stage's most
	-- common rarity, average roll), the next win drops that par item for that slot. Gear at par or better
	-- never triggers it, so lucky players gain nothing. Any natural upgrade resets the count.
	Pity = { After = 10, BelowPar = 0.85 },
}

-- flat health / attack / defense on items is NumberScale times bigger, like the heroes it is worn by (Config/Economy)
for _, stat in pairs(Gear.Slots) do
	if stat.Stat == "MaxHealth" or stat.Stat == "Attack" or stat.Stat == "Defense" then
		stat.Base *= Economy.NumberScale * (Economy.GearPower or 1)
		stat.PerStage *= Economy.NumberScale * (Economy.GearPower or 1)
	end
end

return Gear
