--[[
	Tides (ModuleScript, data only): the season mechanic "Elemental Tides" (docs/SEASONS.md), on in any season whose
	Config/Seasons entry has Mechanic = "Tides". DRAFT 2026-11-28: built for the owner to try (Studio "Start next season"
	runs the draft season 2), not on any real season yet.

	Every week of the season one element rises (week 1 the first in Order, and so on, round again after the last).
	Stages in the rising element's zones are tougher but pay more, so the week changes where it is worth fighting:
	push through a rising zone, or farm one on the map. One class is in the spotlight each week.

	  Zones[element]  zone indexes (Config/Zones order, 1-20; zones past 200 loop round to the same themes)
	  Power           rising zones: enemy health and attack x(1 + Power)
	  GoldGain/XPGain rising zones: extra gold and XP on every win there (added like the other gain bonuses)
	  RuneRolls       rising zones: extra rune drop rolls on a win there (runes mostly drop on frontier wins)
	  Spotlight       the classes in weekly turn; the class in the spotlight gets SpotlightMods in stage fights
]]
return {
	Mechanic = "Tides",
	Week = 7 * 86400,
	Order = { "Fire", "Storm", "Frost", "Void" },
	Elements = {
		Fire = { Name = "Fire Tide", Color = { 255, 120, 40 }, Zones = { 1, 5, 7, 13, 18 } }, -- Sunny Meadow, Sunbaked Dunes, Ember Wastes, Phoenix Pyre, Radiant Sanctum
		Storm = { Name = "Storm Tide", Color = { 140, 200, 255 }, Zones = { 8, 9, 11, 12, 19 } }, -- Mirewood Swamp, Sunken Ruins, Stormspire Peaks, Tidal Deep, Slime Meadows
		Frost = { Name = "Frost Tide", Color = { 190, 230, 255 }, Zones = { 3, 6, 10, 15, 16 } }, -- Stonebreak Hills, Frostpeak Pass, Cloud Spire, Aurora Wastes, Astral Expanse
		Void = { Name = "Void Tide", Color = { 180, 80, 255 }, Zones = { 2, 4, 14, 17, 20 } }, -- Whispering Forest, Glimmer Cave, Glowshroom Hollow, Void Rift, Arcane Archive
	},
	Power = 0.2,
	GoldGain = 1.0,
	XPGain = 0.25,
	RuneRolls = 1,
	Spotlight = { "Mage", "Warrior", "Ranger", "Cleric", "Rogue", "Summoner" },
	SpotlightMods = { { Stat = "Attack", Mode = "Mul", Value = 0.1 }, { Stat = "MaxHealth", Mode = "Mul", Value = 0.1 } },
}
