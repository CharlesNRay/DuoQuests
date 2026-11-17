--[[
	Economy (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Economy

	Every progression and spending number in one place. PLACEHOLDERS: the
	pacing goal is that a normal player owns every skill for their class after
	about a week, with slot levels nowhere near max.
]]

return {
	-- Player level --------------------------------------------------------
	-- NumberScale makes every health / attack / defense number this many times bigger (heroes, enemies, gear, bosses) without
	-- changing the balance: defense is scaled with it (see Simulation) and percentages stay percentages.
	NumberScale = 10,
	-- XPNumber does the same for experience (needed to level, earned per fight) so levels fly by in bigger numbers.
	XPNumber = 20,
	MaxLevel = 120,
	-- XP to go from level L to L+1 = XPBase + XPCurve * L ^ XPPower (then times XPNumber). A power curve like most RPGs / idle games:
	-- the first levels fly by, the later ones take far longer.
	XPBase = 30,
	XPCurve = 0.9,
	XPPower = 1.8,
	-- Low-level heroes are weaker: Health, Attack and Defense from the class are multiplied by Start at level 1, rising in a straight
	-- line to full strength at FullLevel. So the first stages cannot be skipped at a low level; you have to grow into them.
	-- Gear carries progression: each level adds only LevelGrowth of a class's per-level stats, and flat gear stats (attack, health, defense)
	-- are GearPower times bigger, so a hero that never changes gear stalls while a geared one keeps climbing.
	LevelGrowth = 0.35,
	MinionScale = 0.27, -- a Summoner's minions take this share of their health and attack (their power rides on the summoner's gear, so it is trimmed to keep pace with the other classes)
	GearPower = 9,
	DefenseScaleExp = 0.5, -- Defense is measured against 1000 x (attacking enemy scale ^ this), not a flat 1000, so it cannot run away late (see Simulation)
	EarlyWeak = { Start = 0.55, FullLevel = 60 },
	-- Past the level cap, XP fills Paragon levels (Season.Paragon): each is a small permanent bonus to Attack, Health and Defense for the season.
	Paragon = { Max = 100, XPFactor = 3, PerLevel = 0.004 },

	-- Stage clear rewards (earned at the frontier) --------------------------
	RewardScale = 0.1, -- one dial that scales gold and XP income (shards have their own numbers below)
	-- Gold per clear: Base * Growth^stage + PerStage * stage. It climbs fast on purpose: thousands early, millions later.
	GoldCurve = { Base = 60, Growth = 1.065, PerStage = 8 },
	XPScale = 1.0, -- multiplies XP only (the level pacing dial): lv10 ~12 min, lv20 ~27 min, lv30 ~1 h
	-- Early game (up to the first boss, stage 10) pays extra XP (levels only, no gold) so the opening is quick; the bonus fades out over the next few stages.
	EarlyGame = { LastFullStage = 10, FadeStages = 8, XP = 4, LevelCost = 1, LastCheapLevel = 9, LevelFade = 6 },
	XPRewardBase = 10,
	XPRewardPerStage = 3,
	PetXPPerClear = 240, -- XP the active pet earns from every won fight
	ShardsPerClear = 1, -- plus one extra per ShardStageStep stages
	ShardStageStep = 10,
	BossShardBonus = 5, -- extra shards for clearing a boss stage

	-- Wishstones: the one currency for the Wishing Tree (pet and skill wishes). Every first (frontier) clear pays
	-- WishstonesFrontier, boss stages add WishstonesBoss, and every WishstonesReplayEvery-th replay pays one.
	WishstonesFrontier = 2,
	WishstonesBoss = 4,
	WishstonesReplayEvery = 4,

	-- Replaying a stage you already cleared pays this fraction, so the
	-- frontier is always the best place to be (no farming old content).
	ReplayFactor = 0.5,

	-- Boss stages (every BossEvery) grant this many free skill picks the FIRST
	-- time the player clears them.
	MilestoneSkillPicks = 1,

	-- Unlocking skills (Skill Shards) ------------------------------------------
	UnlockCost = { Common = 180, Rare = 360, Epic = 630 },

	-- Levelling a slot (Gold): cost to go from level L to L+1 is SlotCostPerLevel * L
	SlotCostPerLevel = 5400,

	-- Levelling a passive slot (Gold): cost to go from level L to L+1 is
	-- PassiveCostPerLevel * L. Passives are unlocked by reaching stages.
	PassiveCostPerLevel = 6600,
}
