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
	BossPool = { "SlimeKing", "GoblinWarlord", "SporeMother" }, -- boss stages cycle through these
	TimeLimit = 60, -- seconds to clear a regular stage; running out counts as a loss
	BossTimeLimit = 90, -- seconds to clear a boss stage
	MaxEnemies = 3, -- regular stages grow from 1 enemy up to this many
	ScalePerStage = 0.045, -- enemy scale = 1 + ScalePerStage * (stage - 1) ^ ScalePower
	ScalePower = 1.35, -- 1 = linear growth; above 1 gets steeper at higher stages (calibrated, see docs/PROGRESSION.md)
	-- Content gets tougher in steps to keep up with the power spikes the player gets
	-- (subclass at level 30, and so on). Each tier multiplies enemy scale from its stage on.
	Tiers = { { From = 31, Mult = 1.1 }, { From = 61, Mult = 1.1 } },
	BossScaleMult = 1.1, -- extra multiplier on boss health and attack (bosses are the real hurdle)
}
