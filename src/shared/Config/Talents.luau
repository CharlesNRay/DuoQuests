--[[
	Config/Talents: level-up points (owner 2026-11-23: "when a player levels up i want the player to be able to do
	something, spend points for each level up"). Every level past 1 gives PointsPerLevel talent points; each rank of a
	talent costs one point. There are more ranks than points (8 talents x 10 ranks vs 39 points at level 40), so every
	hero is a choice. Reset is free (try builds). Talents belong to the season, like levels.

	  Defs[id] = { Name, Glyph, Stat, Mode ("Mul" | "Add" | "Party" | "Reward"), PerRank, MaxRank, Label, Unlock? }

	Mastery (2026-11-24): the 8 talents are full at level 81 (80 ranks), but levels go to 120. Four Mastery talents open at
	level Unlock (81) and take the 39 points of levels 82-120: Onslaught (damage dealt), Fortitude (damage taken),
	Party Spirit (Mode "Party": every member's ranks add up and boost the WHOLE party's Attack and Health, StageRunner)
	and Fortune (Mode "Reward": gold and XP from clears, Progression.ApplyClear).
	  Builds[role] = the order the auto-spend (and the sim bot) fills talents for that class role
]]
return {
	PointsPerLevel = 1,
	-- per-rank values about doubled 2026-11-25: talents added only ~4 stages at level 60 (BALANCE.md "Talents")
	Order = { "Might", "Vitality", "Bulwark", "Precision", "Ferocity", "Swiftness", "Focus", "Mending", "Onslaught", "Fortitude", "PartySpirit", "Fortune" },
	MasteryLevel = 81,
	Defs = {
		Might = { Name = "Might", Glyph = "🐂", Stat = "Attack", Mode = "Mul", PerRank = 0.03, MaxRank = 10, Label = "Attack" },
		Vitality = { Name = "Vitality", Glyph = "💓", Stat = "MaxHealth", Mode = "Mul", PerRank = 0.035, MaxRank = 10, Label = "Health" },
		Bulwark = { Name = "Bulwark", Glyph = "🐢", Stat = "Defense", Mode = "Mul", PerRank = 0.025, MaxRank = 10, Label = "Defense" },
		Precision = { Name = "Precision", Glyph = "📐", Stat = "CritChance", Mode = "Add", PerRank = 0.008, MaxRank = 10, Label = "Crit chance" },
		Ferocity = { Name = "Ferocity", Glyph = "🐯", Stat = "CritMultiplier", Mode = "Add", PerRank = 0.05, MaxRank = 10, Label = "Crit damage" },
		Swiftness = { Name = "Swiftness", Glyph = "🐆", Stat = "AttackSpeed", Mode = "Mul", PerRank = 0.018, MaxRank = 10, Label = "Attack speed" },
		Focus = { Name = "Focus", Glyph = "⏳", Stat = "Haste", Mode = "Add", PerRank = 0.012, MaxRank = 10, Label = "Cooldowns" },
		Mending = { Name = "Mending", Glyph = "💊", Stat = "HealingDealt", Mode = "Mul", PerRank = 0.04, MaxRank = 10, Label = "Healing" },
		-- Mastery (level 81+)
		Onslaught = { Name = "Onslaught", Glyph = "⚒", Stat = "DamageDealt", Mode = "Mul", PerRank = 0.025, MaxRank = 10, Label = "Damage dealt", Unlock = 81, Mastery = true },
		Fortitude = { Name = "Fortitude", Glyph = "🏋", Stat = "DamageTaken", Mode = "Mul", PerRank = -0.02, MaxRank = 10, Label = "Damage taken", Unlock = 81, Mastery = true },
		PartySpirit = { Name = "Party Spirit", Glyph = "🤝", Stat = "PartySpirit", Mode = "Party", PerRank = 0.008, MaxRank = 10, Label = "Attack and Health for the whole party", Unlock = 81, Mastery = true },
		Fortune = { Name = "Fortune", Glyph = "🤑", Stat = "Fortune", Mode = "Reward", PerRank = 0.02, MaxRank = 10, Label = "Gold and XP", Unlock = 81, Mastery = true },
	},
	-- auto-spend order per role (Config/Classes Role); one rank at a time round the list
	Builds = {
		Tank = { "Vitality", "Bulwark", "Might", "Focus", "Vitality", "Bulwark", "Swiftness", "Fortitude", "PartySpirit", "Onslaught" },
		Healer = { "Might", "Mending", "Focus", "Might", "Vitality", "Swiftness", "PartySpirit", "Onslaught", "Fortitude" }, -- 2026-11-23: Mending-first left Cleric behind its no-talent runs
		Damage = { "Might", "Precision", "Ferocity", "Swiftness", "Might", "Focus", "Vitality", "Onslaught", "PartySpirit", "Fortitude" },
	},
	PowerPerRank = 4, -- item power (IP) per point spent, for the IP total
}
