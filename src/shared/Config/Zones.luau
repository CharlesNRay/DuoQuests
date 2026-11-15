--[[
	Zones (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Zones

	A zone is a region of the world: a run of stages (BossEvery per zone, see
	Config/Stages) that ends in a boss. Beating the boss opens the next zone.
	The first N zones are listed below; after that the list repeats with a
	growing "Loop" number so the game never runs out while real zones are added.

	  Name         shown on the map and the stage banner
	  Ground       ground colour (Color3 as {r, g, b} 0-255)
	  Sky          sky/ambient colour
	  Accent       secondary colour for scenery (trees, rocks, etc.)
	  Scenery      what the scene builder places: "Trees", "Pines", "Rocks",
	               "Crystals" (placeholder shapes until real assets are chosen)
	  Brightness   lighting brightness (darker for caves)

	Enemy looks are in Config/Enemies (Look field), not here: monsters change
	with the stage through Config/Stages.EnemyPool and BossPool.
]]

return {
	{ Name = "Sunny Meadow", Ground = { 108, 170, 84 }, Sky = { 150, 205, 255 }, Accent = { 74, 130, 60 }, Scenery = "Trees", Brightness = 2.4 },
	{ Name = "Whispering Forest", Ground = { 70, 120, 72 }, Sky = { 120, 170, 150 }, Accent = { 38, 84, 52 }, Scenery = "Pines", Brightness = 1.8 },
	{ Name = "Stonebreak Hills", Ground = { 150, 140, 120 }, Sky = { 190, 200, 215 }, Accent = { 110, 104, 96 }, Scenery = "Rocks", Brightness = 2.2 },
	{ Name = "Glimmer Cave", Ground = { 70, 62, 96 }, Sky = { 40, 34, 66 }, Accent = { 150, 110, 230 }, Scenery = "Crystals", Brightness = 1.2 },
}
