--[[
	Bonds (ModuleScript, data only): the season mechanic "Bonds" (docs/SEASONS.md), on in any season whose
	Config/Seasons entry has Mechanic = "Bonds".

	Heroes who win fights together build a bond. Each player keeps a bond level with every hero they fight beside
	(other players by user id, companions by name), so it follows you if you change parties. A won fight gives
	XPPerWin bond XP with each other player in it, CompanionShare of that with a companion. Each bond level gives
	PerLevel Attack and Health in fights where that hero stands beside you. Bonds reset with the season.
]]
return {
	Mechanic = "Bonds",
	MaxLevel = 10,
	-- total bond XP to reach level n = XPBase * n^2 (level 1 after 60 wins together, level 10 after 6,000: ~40 hours)
	XPBase = 60,
	XPPerWin = 1,
	CompanionShare = 0.5,
	PerLevel = 0.005, -- +0.5% Attack and Health per level, per bonded hero in the fight (3 partners at 10 = +15%)
	-- titles for your best bond
	Titles = { [5] = "Trusted Ally", [10] = "Bound by Battle" },
	Glyph = "💞",
}
