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
	},
	TimeLimit = 60, -- seconds to clear a regular stage; running out counts as a loss
	BossTimeLimit = 90, -- seconds to clear a boss stage
	MaxEnemies = 3, -- regular stages grow from 1 enemy up to this many
	ScalePerStage = 0.045, -- enemy scale = 1 + ScalePerStage * (stage - 1) ^ ScalePower
	ScalePower = 1.6, -- 1 = linear growth; above 1 gets steeper at higher stages. 1.6 (was 1.35) since 2026-11-16: tuned for PAIRS (a partner or the companion), see docs/BALANCE.md
	-- HealthScalePower = nil, -- when set, enemy HEALTH grows on this (steeper) curve and attack on ScalePower (see Stages.HealthExtra)
	-- Content gets tougher in steps to keep up with the power spikes the player gets
	-- (subclass at level 30, and so on). Each tier multiplies enemy scale from its stage on.
	Tiers = { { From = 31, Mult = 1.1 }, { From = 61, Mult = 1.1 } },
	NormalHealth = { From = 5, Span = 25, Max = 1.6 }, -- ordinary enemies: extra health only, ramping from stage 5 to full at stage 30
	FirstBossMult = 0.6, -- the first boss (stage 10) ends the tutorial, so it is much softer than the later ones
	BossScaleMult = 1.1, -- extra multiplier on boss health and attack (bosses are the real hurdle)
}
