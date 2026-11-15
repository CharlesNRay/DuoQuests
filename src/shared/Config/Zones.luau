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
	{ Name = "Sunny Meadow", Ground = { 108, 170, 84 }, Sky = { 150, 205, 255 }, Accent = { 74, 130, 60 }, Scenery = "Trees", Brightness = 2.4, Material = "Grass", Decor = { Kind = "Flowers", Color = { 255, 214, 90 } } },
	{ Name = "Whispering Forest", Ground = { 70, 120, 72 }, Sky = { 120, 170, 150 }, Accent = { 38, 84, 52 }, Scenery = "Pines", Brightness = 1.8, Material = "Grass", Decor = { Kind = "Mushrooms", Color = { 220, 90, 90 } } },
	{ Name = "Stonebreak Hills", Ground = { 150, 140, 120 }, Sky = { 190, 200, 215 }, Accent = { 110, 104, 96 }, Scenery = "Rocks", Brightness = 2.2, Material = "Slate", Decor = { Kind = "Stones", Color = { 170, 166, 158 } } },
	{ Name = "Glimmer Cave", Ground = { 70, 62, 96 }, Sky = { 40, 34, 66 }, Accent = { 150, 110, 230 }, Scenery = "Crystals", Brightness = 1.2, Material = "Slate", Decor = { Kind = "Stones", Color = { 120, 100, 190 } } },
	{ Name = "Sunbaked Dunes", Ground = { 222, 190, 120 }, Sky = { 255, 224, 160 }, Accent = { 96, 150, 70 }, Scenery = "Cacti", Brightness = 2.8, Material = "Sand", Decor = { Kind = "Bones", Color = { 240, 234, 214 } } },
	{ Name = "Frostpeak Pass", Ground = { 226, 238, 248 }, Sky = { 180, 210, 240 }, Accent = { 90, 130, 120 }, Scenery = "SnowPines", Brightness = 2.4, Material = "Snow", Decor = { Kind = "Stones", Color = { 190, 210, 230 } } },
	{ Name = "Ember Wastes", Ground = { 70, 48, 44 }, Sky = { 110, 40, 30 }, Accent = { 255, 110, 40 }, Scenery = "LavaRocks", Brightness = 1.4, Material = "Basalt", Decor = { Kind = "Embers", Color = { 255, 150, 50 } } },
	{ Name = "Mirewood Swamp", Ground = { 70, 84, 56 }, Sky = { 110, 130, 96 }, Accent = { 80, 70, 54 }, Scenery = "DeadTrees", Brightness = 1.5, Material = "Mud", Decor = { Kind = "Mushrooms", Color = { 150, 200, 110 } } },
	{ Name = "Sunken Ruins", Ground = { 128, 134, 130 }, Sky = { 100, 150, 170 }, Accent = { 176, 180, 170 }, Scenery = "Pillars", Brightness = 1.9, Material = "Cobblestone", Decor = { Kind = "Stones", Color = { 110, 150, 140 } } },
	{ Name = "Cloud Spire", Ground = { 240, 244, 255 }, Sky = { 170, 200, 255 }, Accent = { 255, 255, 255 }, Scenery = "Clouds", Brightness = 3, Material = "SmoothPlastic", Decor = { Kind = "Flowers", Color = { 190, 220, 255 } } },
}
