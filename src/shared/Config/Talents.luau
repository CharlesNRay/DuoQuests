--[[
	Config/Talents: level-up points (owner 2026-11-23: "when a player levels up i want the player to be able to do
	something, spend points for each level up"). Every level past 1 gives PointsPerLevel talent points; each rank of a
	talent costs one point. There are more ranks than points (8 talents x 10 ranks vs 39 points at level 40), so every
	hero is a choice. Reset is free (try builds). Talents belong to the season, like levels.

	  Defs[id] = { Name, Glyph, Stat, Mode ("Mul" | "Add"), PerRank, MaxRank, Label (stat words for the UI) }
	  Builds[role] = the order the auto-spend (and the sim bot) fills talents for that class role
]]
return {
	PointsPerLevel = 1,
	Order = { "Might", "Vitality", "Bulwark", "Precision", "Ferocity", "Swiftness", "Focus", "Mending" },
	Defs = {
		Might = { Name = "Might", Glyph = "⚔", Stat = "Attack", Mode = "Mul", PerRank = 0.015, MaxRank = 10, Label = "Attack" },
		Vitality = { Name = "Vitality", Glyph = "❤", Stat = "MaxHealth", Mode = "Mul", PerRank = 0.02, MaxRank = 10, Label = "Health" },
		Bulwark = { Name = "Bulwark", Glyph = "🛡", Stat = "Defense", Mode = "Mul", PerRank = 0.02, MaxRank = 10, Label = "Defense" },
		Precision = { Name = "Precision", Glyph = "🎯", Stat = "CritChance", Mode = "Add", PerRank = 0.005, MaxRank = 10, Label = "Crit chance" },
		Ferocity = { Name = "Ferocity", Glyph = "💥", Stat = "CritMultiplier", Mode = "Add", PerRank = 0.03, MaxRank = 10, Label = "Crit damage" },
		Swiftness = { Name = "Swiftness", Glyph = "⚡", Stat = "AttackSpeed", Mode = "Mul", PerRank = 0.01, MaxRank = 10, Label = "Attack speed" },
		Focus = { Name = "Focus", Glyph = "⏳", Stat = "Haste", Mode = "Add", PerRank = 0.008, MaxRank = 10, Label = "Cooldowns" },
		Mending = { Name = "Mending", Glyph = "✨", Stat = "HealingDealt", Mode = "Mul", PerRank = 0.025, MaxRank = 10, Label = "Healing" },
	},
	-- auto-spend order per role (Config/Classes Role); one rank at a time round the list
	Builds = {
		Tank = { "Vitality", "Bulwark", "Might", "Focus", "Vitality", "Bulwark", "Swiftness" },
		Healer = { "Might", "Mending", "Focus", "Might", "Vitality", "Swiftness" }, -- 2026-11-23: Mending-first left Cleric behind its no-talent runs
		Damage = { "Might", "Precision", "Ferocity", "Swiftness", "Might", "Focus", "Vitality" },
	},
	PowerPerRank = 4, -- item power (IP) per point spent, for the IP total
}
