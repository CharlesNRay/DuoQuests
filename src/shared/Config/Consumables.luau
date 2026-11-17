--[[
	Consumables (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Consumables

	Things that live in the STASH (Season.Stash = { [id] = count }), not in the gear bag.

	  Kind      "Buff"    use it to start a timed boost (Season.Buffs[id] = expiry time)
	            "PetFood" use it on a pet to give it XP
	            "Ticket"  a wish ticket, spent at the Wishing Tree in the plaza
	  Effects   Buff only: { Stat, Mode = "Mul"|"Add", Value }. Stats XPGain / GoldGain change rewards,
	            the rest are combat stats (StatCalc).
	  Duration  seconds a Buff lasts (using another one extends it, up to MaxStack seconds)
	  Price     { Base, PerStage }: gold at the Merchant (nil = not sold)
	  Drop      weight in the stage-clear drop table (nil = never drops)

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	MaxStack = 7200,
	DropChance = 0.1, -- per won fight
	BossDropChance = 0.6,

	Order = { "XPTonic", "PowerElixir", "IronTonic", "HasteDraught", "PetFood", "GrandPetFood", "PetWish", "SkillWish" },

	Defs = {
		XPTonic = {
			Id = "XPTonic", DisplayName = "XP Tonic", Kind = "Buff", Glyph = "✨", Rarity = "Common", Duration = 900,
			Description = "+50% XP from fights for 15 minutes.",
			Effects = { { Stat = "XPGain", Mode = "Add", Value = 0.5 } },
			Price = { Base = 13800, PerStage = 0 }, Drop = 30,
		},
		PowerElixir = {
			Id = "PowerElixir", DisplayName = "Power Elixir", Kind = "Buff", Glyph = "💥", Rarity = "Rare", Duration = 600,
			Description = "+25% damage dealt for 10 minutes.",
			Effects = { { Stat = "DamageDealt", Mode = "Mul", Value = 0.25 } },
			Price = { Base = 24000, PerStage = 0 }, Drop = 15,
		},
		IronTonic = {
			Id = "IronTonic", DisplayName = "Iron Tonic", Kind = "Buff", Glyph = "🛡", Rarity = "Rare", Duration = 600,
			Description = "-20% damage taken for 10 minutes.",
			Effects = { { Stat = "DamageTaken", Mode = "Mul", Value = -0.2 } },
			Price = { Base = 24000, PerStage = 0 }, Drop = 15,
		},
		HasteDraught = {
			Id = "HasteDraught", DisplayName = "Haste Draught", Kind = "Buff", Glyph = "⚡", Rarity = "Rare", Duration = 600,
			Description = "+20% attack speed for 10 minutes.",
			Effects = { { Stat = "AttackSpeed", Mode = "Mul", Value = 0.2 } },
			Price = { Base = 24000, PerStage = 0 }, Drop = 10,
		},
		PetFood = {
			Id = "PetFood", DisplayName = "Pet Snack", Kind = "PetFood", Glyph = "🍖", Rarity = "Common", PetXP = 1600,
			Description = "Feed it to a pet for 1600 pet XP.",
			Price = { Base = 6900, PerStage = 0 }, Drop = 40,
		},
		GrandPetFood = {
			Id = "GrandPetFood", DisplayName = "Pet Feast", Kind = "PetFood", Glyph = "🍗", Rarity = "Rare", PetXP = 10000,
			Description = "Feed it to a pet for 10000 pet XP.",
			Price = { Base = 34200, PerStage = 0 }, Drop = 6,
		},
		PetWish = {
			Id = "PetWish", DisplayName = "Pet Wish", Kind = "Ticket", Glyph = "🥚", Rarity = "Epic",
			Description = "One wish for a pet egg. Spend it at the Wishing Tree in the plaza.",
		},
		SkillWish = {
			Id = "SkillWish", DisplayName = "Skill Wish", Kind = "Ticket", Glyph = "📖", Rarity = "Epic",
			Description = "One wish for a skill. Spend it at the Wishing Tree in the plaza.",
		},
	},
}
