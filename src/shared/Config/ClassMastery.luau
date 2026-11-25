--[[
	ClassMastery (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > ClassMastery

	Each class has its own mastery level that NEVER resets between seasons. Mastery XP comes from progress made
	while playing that class: a new frontier stage, a boss beaten for the first time this season, and a dungeon's
	first full clear of the day. Replaying easy stages gives none, so it cannot be farmed while away.

	  XPToNext(level) = Base + PerLevel * level      (about 2,950 XP to reach MaxLevel 50: three to four seasons on one class)
	  Perks: every PerkEvery levels +PerkValue to Attack, Max health and Defense for that class (capped at MaxLevel)
	  Titles at the listed levels ("<Class> Adept" ...)
]]

return {
	MaxLevel = 50,
	XPBase = 10,
	XPPerLevel = 2,
	XP = { Frontier = 2, Boss = 10, Dungeon = 3 },
	PerkEvery = 10,
	PerkValue = 0.01, -- +1% Attack / MaxHealth / Defense per PerkEvery levels: +5% at level 50
	PerkStats = { "Attack", "MaxHealth", "Defense" },
	Titles = { { Level = 10, Suffix = "Adept" }, { Level = 25, Suffix = "Veteran" }, { Level = 50, Suffix = "Master" } },
}
