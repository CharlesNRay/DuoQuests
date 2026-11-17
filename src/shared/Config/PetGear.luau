--[[
	PetGear (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > PetGear

	Four pet gear slots, one per Kind. They open as the ACTIVE pet levels up (Config/Pets GearSlotLevels). Pet gear
	is worn by the pet but helps the PLAYER: extra damage, crit, crit damage, attack speed, shorter cooldowns...

	Each piece: { Id, Kind, Rarity, Stat, Value }   Value = StatUnits[Stat].Base * RarityMult[Rarity]

	Sources are few on purpose: the Pet Store in the plaza (crates) and a chance from bosses.
	Every number is a PLACEHOLDER to be tuned.
]]

return {
	Slots = 4,
	Kinds = { "Collar", "Charm", "Saddle", "Toy" }, -- slot n takes Kinds[n]
	KindGlyph = { Collar = "📿", Charm = "🔮", Saddle = "🐴", Toy = "🧸" },
	BagSize = 30,
	Rarities = { "Common", "Rare", "Epic", "Legendary" },
	RarityMult = { Common = 1, Rare = 1.6, Epic = 2.5, Legendary = 4 },

	-- what a piece can roll: Mode "Mul" = +fraction, "Add" = raw number (Haste shortens skill cooldowns)
	StatUnits = {
		DamageDealt = { Mode = "Mul", Base = 0.03, Label = "Damage" },
		Attack = { Mode = "Mul", Base = 0.03, Label = "Attack" },
		CritChance = { Mode = "Add", Base = 0.015, Label = "Crit Chance" },
		CritMultiplier = { Mode = "Add", Base = 0.06, Label = "Crit Damage" },
		AttackSpeed = { Mode = "Mul", Base = 0.025, Label = "Attack Speed" },
		Haste = { Mode = "Add", Base = 0.02, Label = "Cooldown Speed" },
	},
	StatOrder = { "DamageDealt", "Attack", "CritChance", "CritMultiplier", "AttackSpeed", "Haste" },

	-- Crates sold at the Pet Store: a fixed gold price. Odds are weights per rarity.
	Crates = {
		PetCrate = { DisplayName = "Pet Gear Crate", Glyph = "📦", Price = { Base = 24000, PerStage = 0 }, Odds = { Common = 60, Rare = 30, Epic = 9, Legendary = 1 } },
		GrandCrate = { DisplayName = "Grand Gear Crate", Glyph = "🎁", Price = { Base = 96000, PerStage = 0 }, Odds = { Common = 10, Rare = 45, Epic = 38, Legendary = 7 } },
	},
	CrateOrder = { "PetCrate", "GrandCrate" },

	-- Pet Eggs (a Pet Wish ticket, hatched at the Wishing Tree) are sold too, a few a day
	Egg = { Price = { Base = 80000, PerStage = 0 }, PerDay = 3 },

	-- bosses sometimes drop a piece
	BossDropChance = 0.35,
	BossOdds = { Common = 40, Rare = 40, Epic = 17, Legendary = 3 },

	-- selling a piece back (gold = SellBase * rarity multiplier)
	SellBase = 1500,
}
