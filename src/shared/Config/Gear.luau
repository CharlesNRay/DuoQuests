--[[
	Gear (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Gear

	Equipment drops from stages. Three slots, three rarities (same ones as skills,
	see Config/Rarities). An item remembers the stage it dropped at (its Power),
	so a drop from stage 40 beats the same rarity from stage 5. Gear is
	SEASONAL: it lives in Season.Equipment and resets with the season.

	  Slots        display order; each gives one flat stat bonus
	  Names        item names by slot and rarity
	  RarityMult   how much stronger rarer items are
	  Drop         chances (every number is a PLACEHOLDER to be tuned)

	Stat at drop stage S for an item of a slot:  (Base + PerStage * S) * RarityMult
]]

return {
	InventoryCap = 30, -- a full bag sells new drops automatically

	Slots = {
		Weapon = { Stat = "Attack", Base = 0.3, PerStage = 0.05 },
		Armor = { Stat = "MaxHealth", Base = 3, PerStage = 0.5 },
		Trinket = { Stat = "Defense", Base = 0.15, PerStage = 0.025 },
	},
	SlotOrder = { "Weapon", "Armor", "Trinket" },

	Names = {
		Weapon = { Common = "Iron Sword", Rare = "Steel Blade", Epic = "Dragonfang" },
		Armor = { Common = "Leather Vest", Rare = "Chain Mail", Epic = "Aegis Plate" },
		Trinket = { Common = "Lucky Charm", Rare = "Silver Ring", Epic = "Star Pendant" },
	},

	RarityMult = { Common = 1, Rare = 1.5, Epic = 2.2 },
	SellValue = { Common = 2, Rare = 6, Epic = 15 }, -- gold per item (before stage scaling)
	SellPerStage = 0.2, -- extra gold per stage of Power

	Drop = {
		Chance = 0.2, -- per won fight at the frontier
		ReplayChance = 0.1, -- replaying a cleared stage
		BossChance = 1, -- boss stages always drop
		-- weights for the rarity roll
		Weights = { Common = 80, Rare = 17, Epic = 3 },
		-- each 0.1 of the ItemRarity passive bonus moves this much weight from Common
		BonusShift = 60,
	},
}
