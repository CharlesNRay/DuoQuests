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
	  Backdrop     the silhouettes behind a fight (client Battle/Backdrops): Hills, Peaks, Cave, Dunes, Volcano, Swamp,
	               Ruins, Sky, Storm, Reef, Pyre, Fungal, Aurora, Astral, Void, Radiant, Gale, Slime, Arcane
	  Boss         (optional) this zone's boss instead of the next one in Config/Stages BossPool
	  NoClouds     no drifting clouds (caves, the deep, space); CloudColor tints them (storm clouds)


	Stages 1-100 are the ten real-world zones; 101-200 (2026-11-24) are elemental / magical ones; then the list loops.

	Enemy looks are in Config/Enemies (Look field), not here: monsters change
	with the stage through Config/Stages.EnemyPool and BossPool.
]]

return {
	{ Name = "Sunny Meadow", Ground = { 108, 170, 84 }, Sky = { 150, 205, 255 }, Accent = { 74, 130, 60 }, Scenery = "Trees", Backdrop = "Hills", Brightness = 2.4, Material = "Grass", Decor = { Kind = "Flowers", Color = { 255, 214, 90 } } },
	{ Name = "Whispering Forest", Ground = { 70, 120, 72 }, Sky = { 120, 170, 150 }, Accent = { 38, 84, 52 }, Scenery = "Pines", Backdrop = "Hills", Brightness = 1.8, Material = "Grass", Decor = { Kind = "Mushrooms", Color = { 220, 90, 90 } } },
	{ Name = "Stonebreak Hills", Ground = { 150, 140, 120 }, Sky = { 190, 200, 215 }, Accent = { 110, 104, 96 }, Scenery = "Rocks", Backdrop = "Peaks", Brightness = 2.2, Material = "Slate", Decor = { Kind = "Stones", Color = { 170, 166, 158 } } },
	{ Name = "Glimmer Cave", Ground = { 70, 62, 96 }, Sky = { 40, 34, 66 }, Accent = { 150, 110, 230 }, Scenery = "Crystals", Backdrop = "Cave", NoClouds = true, Brightness = 1.2, Material = "Slate", Decor = { Kind = "Stones", Color = { 120, 100, 190 } } },
	{ Name = "Sunbaked Dunes", Ground = { 222, 190, 120 }, Sky = { 255, 224, 160 }, Accent = { 96, 150, 70 }, Scenery = "Cacti", Backdrop = "Dunes", Brightness = 2.8, Material = "Sand", Decor = { Kind = "Bones", Color = { 240, 234, 214 } } },
	{ Name = "Frostpeak Pass", Ground = { 226, 238, 248 }, Sky = { 180, 210, 240 }, Accent = { 90, 130, 120 }, Scenery = "SnowPines", Backdrop = "Peaks", Brightness = 2.4, Material = "Snow", Decor = { Kind = "Stones", Color = { 190, 210, 230 } } },
	{ Name = "Ember Wastes", Ground = { 70, 48, 44 }, Sky = { 110, 40, 30 }, Accent = { 255, 110, 40 }, Scenery = "LavaRocks", Backdrop = "Volcano", CloudColor = { 90, 55, 50 }, Brightness = 1.4, Material = "Basalt", Decor = { Kind = "Embers", Color = { 255, 150, 50 } } },
	{ Name = "Mirewood Swamp", Ground = { 70, 84, 56 }, Sky = { 110, 130, 96 }, Accent = { 80, 70, 54 }, Scenery = "DeadTrees", Backdrop = "Swamp", Brightness = 1.5, Material = "Mud", Decor = { Kind = "Mushrooms", Color = { 150, 200, 110 } } },
	{ Name = "Sunken Ruins", Ground = { 128, 134, 130 }, Sky = { 100, 150, 170 }, Accent = { 176, 180, 170 }, Scenery = "Pillars", Backdrop = "Ruins", Brightness = 1.9, Material = "Cobblestone", Decor = { Kind = "Stones", Color = { 110, 150, 140 } } },
	{ Name = "Cloud Spire", Ground = { 240, 244, 255 }, Sky = { 170, 200, 255 }, Accent = { 255, 255, 255 }, Scenery = "Clouds", Backdrop = "Sky", Brightness = 3, Material = "SmoothPlastic", Decor = { Kind = "Flowers", Color = { 190, 220, 255 } } },
	-- stages 101-200: the elements and the arcane
	{ Name = "Stormspire Peaks", Ground = { 74, 80, 96 }, Sky = { 58, 66, 92 }, Accent = { 140, 200, 255 }, Scenery = "StormRocks", Backdrop = "Storm", CloudColor = { 70, 76, 96 }, Brightness = 1.4, Material = "Slate", Decor = { Kind = "Stones", Color = { 96, 104, 124 } } },
	{ Name = "Tidal Deep", Ground = { 60, 130, 140 }, Sky = { 24, 70, 110 }, Accent = { 255, 110, 180 }, Scenery = "Coral", Backdrop = "Reef", NoClouds = true, Brightness = 1.6, Material = "Sand", Decor = { Kind = "Shells", Color = { 250, 210, 200 } } },
	{ Name = "Phoenix Pyre", Ground = { 96, 54, 40 }, Sky = { 150, 70, 40 }, Accent = { 255, 120, 40 }, Scenery = "FlameCrystals", Backdrop = "Pyre", CloudColor = { 120, 70, 60 }, Brightness = 1.6, Material = "Basalt", Decor = { Kind = "Embers", Color = { 255, 190, 70 } } },
	{ Name = "Glowshroom Hollow", Ground = { 50, 44, 70 }, Sky = { 30, 26, 52 }, Accent = { 90, 230, 160 }, Scenery = "GlowShrooms", Backdrop = "Fungal", NoClouds = true, Brightness = 1.1, Material = "Mud", Decor = { Kind = "Mushrooms", Color = { 120, 255, 190 } } },
	{ Name = "Aurora Wastes", Ground = { 210, 228, 245 }, Sky = { 40, 50, 90 }, Accent = { 80, 255, 180 }, Scenery = "IceSpikes", Backdrop = "Aurora", NoClouds = true, Brightness = 1.6, Material = "Snow", Decor = { Kind = "Stones", Color = { 170, 205, 235 } } },
	{ Name = "Astral Expanse", Ground = { 58, 50, 90 }, Sky = { 16, 14, 40 }, Accent = { 140, 170, 255 }, Scenery = "StarRocks", Backdrop = "Astral", NoClouds = true, Brightness = 1.2, Material = "Slate", Decor = { Kind = "Embers", Color = { 210, 220, 255 } } },
	{ Name = "Void Rift", Ground = { 36, 28, 48 }, Sky = { 26, 14, 40 }, Accent = { 180, 80, 255 }, Scenery = "VoidShards", Backdrop = "Void", NoClouds = true, Brightness = 1, Material = "Basalt", Decor = { Kind = "Embers", Color = { 190, 110, 255 } } },
	{ Name = "Radiant Sanctum", Ground = { 236, 226, 200 }, Sky = { 255, 236, 190 }, Accent = { 255, 210, 110 }, Scenery = "GoldPillars", Backdrop = "Radiant", Brightness = 3, Material = "Marble", Decor = { Kind = "Flowers", Color = { 255, 230, 140 } } },
	{ Name = "Slime Meadows", Ground = { 170, 230, 160 }, Sky = { 255, 210, 235 }, Accent = { 255, 150, 200 }, Scenery = "Slimelings", Backdrop = "Slime", Boss = "RainbowSlime", CloudColor = { 255, 235, 245 }, Brightness = 2.6, Material = "Grass", Decor = { Kind = "Flowers", Color = { 255, 170, 210 } } },
	{ Name = "Arcane Archive", Ground = { 70, 66, 100 }, Sky = { 44, 40, 86 }, Accent = { 110, 170, 255 }, Scenery = "RuneStones", Backdrop = "Arcane", NoClouds = true, Brightness = 1.3, Material = "Cobblestone", Decor = { Kind = "Embers", Color = { 140, 190, 255 } } },
}
