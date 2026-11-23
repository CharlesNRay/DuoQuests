--[[
	Config/Runes (ModuleScript): rune stones that are carved onto gear.

	One rune per gear piece; a new rune replaces the old one (the client asks first when the old one is a
	higher tier). A rune is { Stat, Tier }; its bonus comes from Stats[Stat].Values[tier index].
	Values are per piece and stack across the 8 worn pieces, so they are kept small.
	Mode "Mul" multiplies the stat (0.05 = +5%), "Add" adds to it (CritChance 0.02 = +2 points).
]]
return {
	Tiers = { "Common", "Rare", "Epic", "Legendary" },

	-- display order in the rune list
	Order = { "Attack", "MaxHealth", "Defense", "DamageDealt", "DamageTaken", "CritChance", "CritMultiplier", "CritResist", "Haste", "AttackSpeed", "HealingDealt" },

	Stats = {
		Attack = { Name = "Might", Glyph = "⚔", Label = "Attack", Mode = "Mul", Values = { 0.02, 0.03, 0.045, 0.06 } },
		MaxHealth = { Name = "Vitality", Glyph = "❤", Label = "Health", Mode = "Mul", Values = { 0.03, 0.045, 0.065, 0.09 } },
		Defense = { Name = "Stone", Glyph = "🛡", Label = "Defense", Mode = "Mul", Values = { 0.03, 0.045, 0.065, 0.09 } },
		DamageDealt = { Name = "Fury", Glyph = "🔥", Label = "Damage dealt", Mode = "Mul", Values = { 0.02, 0.03, 0.045, 0.06 } },
		DamageTaken = { Name = "Warding", Glyph = "🔰", Label = "Damage taken", Mode = "Mul", Values = { -0.015, -0.025, -0.035, -0.05 } },
		CritChance = { Name = "Precision", Glyph = "🎯", Label = "Crit chance", Mode = "Add", Values = { 0.01, 0.015, 0.02, 0.03 } },
		CritMultiplier = { Name = "Ruin", Glyph = "💥", Label = "Crit damage", Mode = "Add", Values = { 0.04, 0.07, 0.1, 0.15 } },
		CritResist = { Name = "Steadfast", Glyph = "🗿", Label = "Crit resistance", Mode = "Add", Values = { 0.01, 0.02, 0.03, 0.04 } },
		Haste = { Name = "Swiftness", Glyph = "⏳", Label = "Cooldowns", Mode = "Add", Values = { 0.015, 0.025, 0.035, 0.05 } },
		AttackSpeed = { Name = "Alacrity", Glyph = "⚡", Label = "Attack speed", Mode = "Mul", Values = { 0.015, 0.025, 0.035, 0.05 } },
		HealingDealt = { Name = "Mercy", Glyph = "✨", Label = "Healing", Mode = "Mul", Values = { 0.03, 0.05, 0.07, 0.1 } },
	},

	-- Drops. Tier weights by stage, blended between the anchors (like gear rarity).
	Drop = {
		FrontierChance = 0.03, -- a normal frontier win
		BossChance = 1, -- a boss stage on the frontier always drops one
		Anchors = {
			{ Stage = 1, Weights = { Common = 100, Rare = 0, Epic = 0, Legendary = 0 } },
			{ Stage = 30, Weights = { Common = 70, Rare = 30, Epic = 0, Legendary = 0 } },
			{ Stage = 60, Weights = { Common = 45, Rare = 40, Epic = 15, Legendary = 0 } },
			{ Stage = 100, Weights = { Common = 25, Rare = 40, Epic = 28, Legendary = 7 } },
		},
	},

	-- the Blacksmith sells a pouch with one random rune (fixed price, like every shop)
	Pouch = { Gold = 25000, Weights = { Common = 80, Rare = 18, Epic = 2, Legendary = 0 } },
	-- a full dungeon clear drops one rune, rolled as if the stage were this much further
	DungeonStageBonus = 20,
}
