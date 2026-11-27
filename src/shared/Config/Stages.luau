--[[
	Stages (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Stages

	How stages are put together. Stage content is a pure function of the stage
	number (see Shared/Stages), so nothing about a stage is ever stored.
	All numbers are PLACEHOLDERS to tune during playtesting.
]]

return {
	BossEvery = 10, -- every 10th stage is a boss stage
	EnemyPool = { "Slime", "Goblin", "Mushroom" }, -- regular stages cycle through these
	BossPool = { "SlimeKing", "GoblinWarlord", "SporeMother", "DireWolf", "Broodmother", "LichKing", "InfernoLord" }, -- boss stages cycle through these
	-- Each zone (BossEvery stages) fields its own monsters; zones past the last repeat the list. Zone 1 keeps the starter trio.
	ZonePools = {
		{ "Slime", "Goblin", "Mushroom" },
		{ "Wolf", "Spider", "Boar" },
		{ "RockGolem", "Harpy", "Goblin" },
		{ "Bat", "Wraith", "CrystalBeetle" },
		{ "Scorpion", "Mummy", "SandSerpent" },
		{ "SnowWolf", "FrostImp", "Yeti" },
		{ "FireElemental", "MagmaHound", "Imp" },
		{ "Frog", "BogWraith", "Spider" },
		{ "Skeleton", "Ghost", "RuinGolem" },
		{ "SkyHarpy", "StormSprite", "Bat" },
		-- stages 101-200: the elemental / magical zones
		{ "StormHound", "ThunderHawk", "VoltWisp" },
		{ "ReefCrab", "GlowEel", "Jellyfish" },
		{ "FlameHawk", "CinderGolem", "Salamander" },
		{ "Shroomling", "GlowMoth", "SporeBeetle" },
		{ "IceWraith", "FrostBear", "AuroraFox" },
		{ "StarSprite", "MeteorGolem", "CometSerpent" },
		{ "VoidStalker", "Shade", "VoidWeaver" },
		{ "Sentinel", "Seraph", "LightWisp" },
		{ "BubbleSlime", "JellySlime", "GummyFrog" },
		{ "FlyingTome", "RuneGolem", "ArcaneWisp" },
	},
	TimeLimit = 200, -- (was 60 before the 2026-11-26 longer fights) seconds to clear a regular stage; running out counts as a loss
	BossTimeLimit = 300, -- (was 90) seconds to clear a boss stage
	MaxEnemies = 3, -- regular stages grow from 1 enemy up to this many
	ScalePerStage = 0.045, -- enemy scale = 1 + ScalePerStage * (stage - 1) ^ ScalePower
	PartyScale = 2.6, -- every fight has 4 heroes (players, ghosts or companions; since 2026-11-18): enemies are this much stronger
	ScalePower = 1.6, -- 1 = linear growth; above 1 gets steeper at higher stages. 1.6 (was 1.35) since 2026-11-16: tuned for PAIRS (a partner or the companion), see docs/BALANCE.md
	-- HealthScalePower = nil, -- when set, enemy HEALTH grows on this (steeper) curve and attack on ScalePower (see Stages.HealthExtra)
	-- Content gets tougher in steps to keep up with the power spikes the player gets
	-- (subclass at level 30, and so on). Each tier multiplies enemy scale from its stage on.
	Tiers = { { From = 31, Mult = 1.1 } }, -- the stage 61 step (x1.1) went 2026-11-25: on top of LateGrowth it was a 20-50 h wall
	-- past stage From every stage is Rate harder on top of the curve (compounding), so the late game stays a climb
	-- AttackShare: attack gets Rate x AttackShare per stage and health the rest (health x attack still grows (1+Rate)^2 a
	-- stage), so late fights get longer instead of more lethal (at 1/1 frontier fights past L50 were 4-7 s again)
	-- Bands (2026-11-25, owner: upgrade, push a few stages, wait for more upgrades): 1.8% a stage from 25, 0.5% from 70 (1% from 70 left L60-90 runs ~6 stages in 120 h).
	LateGrowth = { Bands = { { From = 25, Rate = 0.018 }, { From = 70, Rate = 0.005 } }, AttackShare = 0.5 },
	-- Stage monsters: Health times more health and Attack times the attack. The same "who wins" (both sides take about
	-- 1/Attack x Health longer to fall) but fights last long enough for heals, shields, buffs and debuffs to matter and to
	-- be watched: at 1/1 frontier fights were over in 3-5 s and the heroes all fell (BALANCE.md "Fight length").
	-- 2026-11-26 (owner: fights 3-4x longer so every skill cycles): Health 2.4 -> 8.4, Attack 0.7 -> 0.45 (heals and shields gain in long fights).
	FightLength = { Health = 8.4, Attack = 0.45 }, -- 0.3 made long fights too easy (L60 stage 81-115 vs 55-85)
	-- Softer early zones (the tutorial and the ones after it): from stage From enemies are scaled by Mult, easing back to full strength at To
	-- (new players have not learned wishing and gear yet; the late game keeps the pair balance). nil = off.
	EarlyEase = { From = 1, To = 40, Mult = 0.8 },
	NormalHealth = { From = 5, Span = 25, Max = 1.6 }, -- ordinary enemies: extra health only, ramping from stage 5 to full at stage 30
	FirstBossMult = 0.6, -- the first boss (stage 10) ends the tutorial, so it is much softer than the later ones
	BossScaleMult = 1.1, -- extra multiplier on boss health and attack (bosses are the real hurdle)
	-- Stage bosses on top of FightLength (2026-11-26): every lost boss fight past 60 was a wipe 30-60 s in with the boss at
	-- 20-40% (its enraged half), shorter than a normal fight, and 1 run in 36 sat at boss 90/100 for 50-60 h (mostly healer
	-- pairs). More health, less attack: about the same damage race, but heals and shields get time to work.
	BossFightLength = { Health = 1.3, Attack = 0.8 },
}
