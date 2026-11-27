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
	NumberScale = 100, -- was 10 (2026-11-25, owner: bigger health and damage numbers everywhere)
	-- XPNumber does the same for experience (needed to level, earned per fight) so levels fly by in bigger numbers.
	XPNumber = 20,
	MaxLevel = 120,
	-- XP to go from level L to L+1 = XPBase + XPCurve * L ^ XPPower (then times XPNumber). A power curve like most RPGs / idle games:
	-- the first levels fly by, the later ones take far longer.
	XPBase = 30,
	XPCurve = 0.9,
	XPPower = 1.8,
	-- Pace per level band (2026-11-25, owner: L20 ~4 h, L40 ~10 h, L60 ~30-34 h, then much slower so a season lasts):
	-- the XP a level costs is multiplied by Mult, read off these points (straight lines between them, flat past the ends).
	LevelPace = { { Level = 10, Mult = 1.7 }, { Level = 30, Mult = 0.75 }, { Level = 50, Mult = 2.9 }, { Level = 70, Mult = 4.4 }, { Level = 90, Mult = 5.8 }, { Level = 110, Mult = 7 } },
	-- Low-level heroes are weaker: Health, Attack and Defense from the class are multiplied by Start at level 1, rising in a straight
	-- line to full strength at FullLevel. So the first stages cannot be skipped at a low level; you have to grow into them.
	-- Gear carries progression: each level adds only LevelGrowth of a class's per-level stats, and flat gear stats (attack, health, defense)
	-- are GearPower times bigger, so a hero that never changes gear stalls while a geared one keeps climbing.
	LevelGrowth = 0.35,
	MinionHealthScale = 0.4, -- a Summoner's minions take this share of their health (more than MinionScale so tanks can hold aggro)
	MinionScale = 0.27, -- a Summoner's minions take this share of their attack (their power rides on the summoner's gear, so it is trimmed to keep pace with the other classes)
	GearPower = 9,
	DefenseScaleExp = 0.5, -- Defense is measured against 1000 x (attacking enemy scale ^ this), not a flat 1000, so it cannot run away late (see Simulation)
	EarlyWeak = { Start = 0.55, FullLevel = 60 },
	-- Past the level cap, XP fills Paragon levels (Season.Paragon): each is a small permanent bonus to Attack, Health and Defense for the season.
	Paragon = { Max = 100, XPFactor = 3, PerLevel = 0.004 },

	-- Stage clear rewards (earned at the frontier) --------------------------
	RewardScale = 0.1, -- one dial that scales gold and XP income (shards have their own numbers below)
	-- Gold per clear: Base * Growth^stage + PerStage * stage. It climbs fast on purpose: thousands early, millions later.
	-- Past SlowFrom the growth per stage drops to LateGrowth (2026-11-27, owner OK): with 1.065 all the way, gold grew
	-- ~250x from level 20 to 80 while everything gold buys has a fixed price, so late gold piled up (bot GOLD lines).
	GoldCurve = { Base = 60, Growth = 1.065, PerStage = 8, SlowFrom = 40, LateGrowth = 1.035 },
	-- Gold, XP and shards per win are this much bigger since fights last longer (Config/Stages FightLength, 2026-11-25):
	-- fewer fights an hour, the same pace per hour.
	FightPay = 4.3, -- was 1.4; 2026-11-26 fights ~3.5x longer (about 3x fewer an hour)
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
