--[[
	Config/Audio: every sound and music track the game plays (client/Sound.luau plays them).

	All ids are Roblox's own licensed audio from the Creator Store (creators APMOfficial = music, ProSoundEffects and
	Roblox = sound effects), so they play in any experience. Found 2026-11-23 with the Creator Store search
	(tools: searchCategoryType=Audio). Volume is the base loudness before the player's sliders.

	  Music[name] = { Id, Volume }     Town, Stage, Dungeon, WorldBoss, SeasonBoss, GuildRaid
	  Sfx[name]   = { Ids = { ... } (one picked at random), Volume, Pitch = { min, max }?, Group = "Effects"|"Interface" }
	  Defaults    = the sliders a new player starts with (0..1)
]]
return {
	Music = {
		Town = { Id = 1838661002, Volume = 0.35 }, -- "Fantasy Town" (APM): walking round the plaza and the town
		Stage = { Id = 1842961239, Volume = 0.3 }, -- "Frontiers (Underscore Version)" (APM): watching your own stages
		Dungeon = { Id = 1837814388, Volume = 0.4 }, -- "Dungeon Darkness (a)" (APM)
		WorldBoss = { Id = 1842961333, Volume = 0.4 }, -- "Showdown" (APM)
		SeasonBoss = { Id = 1842961147, Volume = 0.42 }, -- "Valhalla (Underscore Version)" (APM): the Colossus
		GuildRaid = { Id = 1842961067, Volume = 0.4 }, -- "Hall Of Champions (Underscore Version)" (APM)
	},
	Sfx = {
		-- interface
		Click = { Ids = { 15675032796 }, Volume = 0.45, Group = "Interface" }, -- Roblox_UI_Small_Click
		Open = { Ids = { 15675028888 }, Volume = 0.3, Group = "Interface" }, -- Roblox_UI_Whoosh_02
		Pop = { Ids = { 15675055424 }, Volume = 0.5, Group = "Interface" }, -- Roblox_UI_Cute_Pop
		Coins = { Ids = { 9113849492, 9113849445 }, Volume = 0.5, Group = "Interface" }, -- Coins Or Keys Jingle 6 / 5
		Reward = { Ids = { 9126073001 }, Volume = 0.5, Group = "Interface" }, -- Synth Sparkle Tone ... Bell Tone Ding
		Errand = { Ids = { 125706237686412 }, Volume = 0.55, Group = "Interface" }, -- Glistening Harp - Sting (APM)
		Purchase = { Ids = { 9113728049 }, Volume = 0.45, Group = "Interface" }, -- Cash Register 2
		Upgrade = { Ids = { 9113445305 }, Volume = 0.5, Pitch = { 0.95, 1.08 }, Group = "Interface" }, -- Blacksmith Anvil Hammer Hits 1
		PowerUp = { Ids = { 9117886252 }, Volume = 0.45, Group = "Interface" }, -- Power Up Sweeteners 12
		-- big moments
		LevelUp = { Ids = { 1845411858 }, Volume = 0.6, Group = "Interface" }, -- Top Prize (APM)
		StageClear = { Ids = { 9126073318 }, Volume = 0.35, Pitch = { 0.95, 1.08 }, Group = "Interface" }, -- sparkle ding
		BossClear = { Ids = { 125706237686412 }, Volume = 0.6, Group = "Interface" }, -- Glistening Harp - Sting (APM)
		Victory = { Ids = { 1836473422 }, Volume = 0.55, Group = "Interface" }, -- Victory Fanfare Sting (APM)
		Defeat = { Ids = { 15675081158 }, Volume = 0.5, Group = "Interface" }, -- Roblox_UI_Cute_Goodbye
		-- combat (played at the fighter, so only nearby fights are heard)
		Hit = { Ids = { 9119747120, 9119747138, 9119747163 }, Volume = 0.32, Pitch = { 0.9, 1.12 }, Group = "Effects" }, -- Sword Impact 102/202/302
		Crit = { Ids = { 9120728815 }, Volume = 0.55, Pitch = { 0.95, 1.05 }, Group = "Effects" }, -- Whoosh Heavy Punches 1
		Swing = { Ids = { 9120972444, 9120972321 }, Volume = 0.25, Pitch = { 0.9, 1.15 }, Group = "Effects" }, -- Wood Whoosh Slicing Air
		Magic = { Ids = { 9125648149 }, Volume = 0.35, Pitch = { 0.9, 1.1 }, Group = "Effects" }, -- Magic Zoom Up Sharp Tubular Whoosh
		Fire = { Ids = { 9114446852, 9114446802 }, Volume = 0.35, Pitch = { 0.9, 1.1 }, Group = "Effects" }, -- Fire Whoosh 15 / 13
		Heal = { Ids = { 9116394545, 9116394876 }, Volume = 0.35, Pitch = { 0.95, 1.1 }, Group = "Effects" }, -- Magic Glows Chiming Hits
		Ultimate = { Ids = { 9120769331 }, Volume = 0.6, Group = "Effects" }, -- Wind Whoosh Sonic Boom Low End Impact 1
		EnemyDown = { Ids = { 15675055424 }, Volume = 0.3, Pitch = { 0.8, 1.0 }, Group = "Effects" }, -- Roblox_UI_Cute_Pop
		AllyDown = { Ids = { 9113971531 }, Volume = 0.4, Group = "Effects" }, -- Creature Growls Lion 4
		BossRoar = { Ids = { 9113980480 }, Volume = 0.55, Group = "Effects" }, -- Creature Mix Giant Crab Monster Roar Growl 2
	},
	Defaults = { Master = 0.8, Music = 0.6, Effects = 0.8, Interface = 0.8 },
	Channels = { "Master", "Music", "Effects", "Interface" },
}
