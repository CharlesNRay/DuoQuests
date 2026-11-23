--[[
	Progression (ModuleScript)
	Location: ReplicatedStorage > Shared > Progression

	XP, levels and stage-clear rewards. Pure functions on a profile table.
	The server calls ApplyClear exactly once per won fight.

	Season.HighestStage is the FRONTIER: the furthest stage the player has
	unlocked (it starts at 1). Clearing the frontier stage pays full rewards and
	moves it up by one. Replaying an older stage pays Economy.ReplayFactor of the
	rewards, so pushing forward is always the best thing to do.

	The first clear of each boss stage grants a free skill pick, guarded by the
	Season.StageRewardsClaimed ledger so it can never be paid twice.

	  Progression.XPToNext(level)
	  Progression.AddXP(season, amount)            -> levels gained
	  Progression.ClearRewards(stage, isFrontier, bonuses)  -> { Gold, XP, Shards }
	      bonuses is optional { GoldGain, XPGain } (fractions from passives);
	      shards are not affected
	  Progression.ApplyClear(profile, stage, rand?) -> summary table (rand() in [0,1) is for tests)
]]

local Economy = require(script.Parent.Config.Economy)
local Stages = require(script.Parent.Stages)
local Passives = require(script.Parent.Passives)
local Pets = require(script.Parent.Pets)
local PetGear = require(script.Parent.PetGear)
local Runes = require(script.Parent.Runes)
local Tutorial = require(script.Parent.Tutorial)
local PetsConfig = require(script.Parent.Config.Pets)
local Gear = require(script.Parent.Gear)
local GearConfig = require(script.Parent.Config.Gear)
local Consumables = require(script.Parent.Consumables)
local Quests = require(script.Parent.Quests)
local Passes = require(script.Parent.Passes)

local Progression = {}

function Progression.XPToNext(level)
	local need = (Economy.XPBase + Economy.XPCurve * level ^ Economy.XPPower) * (Economy.XPNumber or 1)
	local early = Economy.EarlyGame
	if early and early.LevelCost then
		-- the first levels are cheaper, fading back to the full cost a few levels later
		local fade = math.clamp((early.LastCheapLevel + early.LevelFade - level) / early.LevelFade, 0, 1)
		need *= 1 - (1 - early.LevelCost) * fade
	end
	return math.max(1, math.floor(need))
end

-- XP for the next Paragon level (a little more each level)
function Progression.ParagonXPToNext(paragonLevel)
	return math.floor(Progression.XPToNext(Economy.MaxLevel) * Economy.Paragon.XPFactor * (1 + 0.03 * paragonLevel))
end

function Progression.AddXP(season, amount)
	local gained = 0
	if season.Level >= Economy.MaxLevel then
		season.XP = 0
		season.Paragon = season.Paragon or { Level = 0, XP = 0 }
		local para = season.Paragon
		if para.Level < Economy.Paragon.Max then
			para.XP += amount
			while para.Level < Economy.Paragon.Max and para.XP >= Progression.ParagonXPToNext(para.Level) do
				para.XP -= Progression.ParagonXPToNext(para.Level)
				para.Level += 1
			end
			if para.Level >= Economy.Paragon.Max then
				para.XP = 0
			end
		end
		return 0
	end
	season.XP += amount
	while season.Level < Economy.MaxLevel and season.XP >= Progression.XPToNext(season.Level) do
		season.XP -= Progression.XPToNext(season.Level)
		season.Level += 1
		gained += 1
	end
	if season.Level >= Economy.MaxLevel then
		season.XP = 0
	end
	return gained
end

function Progression.ClearRewards(stage, isFrontier, bonuses)
	local goldFactor = 1 + (if bonuses then bonuses.GoldGain or 0 else 0)
	local xpFactor = 1 + (if bonuses then bonuses.XPGain or 0 else 0)
	local replay = if isFrontier then 1 else Economy.ReplayFactor
	-- the opening (up to the first boss) pays extra, fading to normal over a few stages
	local early = Economy.EarlyGame
	local fade = if early then math.clamp((early.LastFullStage + early.FadeStages - stage) / early.FadeStages, 0, 1) else 0
	xpFactor *= 1 + ((early and early.XP or 1) - 1) * fade
	local factor = Economy.RewardScale * replay -- gold and XP
	local shards = Economy.ShardsPerClear + stage // Economy.ShardStageStep
	if Stages.IsBoss(stage) then
		shards += Economy.BossShardBonus
	end
	return {
		Gold = math.max(1, math.floor((Economy.GoldCurve.Base * Economy.GoldCurve.Growth ^ stage + Economy.GoldCurve.PerStage * stage) * replay * goldFactor)),
		XP = math.max(1, math.floor((Economy.XPRewardBase + Economy.XPRewardPerStage * stage) * factor * xpFactor * (Economy.XPScale or 1) * (Economy.XPNumber or 1))),
		Shards = math.max(1, math.floor(shards * replay)), -- shards ignore RewardScale: unlock costs are tuned for them
	}
end

function Progression.ApplyClear(profile, stage, rand)
	local season = profile.Season
	local isFrontier = stage >= season.HighestStage
	local classId = season.ClassId
	local bonuses = Passives.Rewards(classId, season.PassiveLoadouts[classId], season.PassiveSlotLevels[classId])
	local boost = Consumables.Rewards(profile, os.time())
	local guildBuffs = profile.Permanent and profile.Permanent.GuildBuffs or {} -- from the guild's upgrades
	local perks = Passes.Perks(profile)
	bonuses = { GoldGain = (bonuses.GoldGain or 0) + boost.GoldGain + (guildBuffs.GoldGain or 0) + perks.GoldGain, XPGain = (bonuses.XPGain or 0) + boost.XPGain + (guildBuffs.XPGain or 0) + perks.XPGain, ItemRarity = bonuses.ItemRarity }
	local rewards = Progression.ClearRewards(stage, isFrontier, bonuses)

	season.Currencies.Gold += rewards.Gold
	season.Currencies.Shards += rewards.Shards
	-- Wishstones: a frontier clear pays, boss stages pay extra, every few replays pay one
	local wishstones = 0
	if isFrontier then
		wishstones = Economy.WishstonesFrontier + (if Stages.IsBoss(stage) then Economy.WishstonesBoss else 0)
	else
		season.ReplayClears = (season.ReplayClears or 0) + 1
		if season.ReplayClears % Economy.WishstonesReplayEvery == 0 then
			wishstones = 1
		end
	end
	season.Currencies.Wishstones = (season.Currencies.Wishstones or 0) + wishstones
	local levelsGained = Progression.AddXP(season, rewards.XP)

	local skillPicks = 0
	-- string keys: a DataStore cannot hold a table keyed by stage numbers with gaps (10, 20, ...)
	if Stages.IsBoss(stage) and not season.StageRewardsClaimed[tostring(stage)] then
		season.StageRewardsClaimed[tostring(stage)] = true
		skillPicks = Economy.MilestoneSkillPicks
		season.Currencies.SkillPicks += skillPicks
	end

	-- quests and the season pass count every won fight
	Quests.Record(profile, "Clear", 1)
	if isFrontier then
		Quests.Record(profile, "Frontier", 1)
	end
	if Stages.IsBoss(stage) then
		Quests.Record(profile, "Boss", 1)
	end

	local petsGained = Pets.GrantForClear(profile, stage)
	local dropped = Gear.RollDrop(stage, isFrontier, bonuses.ItemRarity, rand or math.random)
	local equipped = (season.Equipment and season.Equipment.Equipped) or {}
	local dropStage, pity = stage, false
	if dropped and Gear.IsUpgrade(equipped, { Slot = dropped.Slot, Rarity = dropped.Rarity, Power = stage, Roll = dropped.Roll }) then
		season.GearDry = 0
	else
		-- bad-luck protection (Config/Gear Pity): a long dry spell with gear below par brings a par item
		season.GearDry = (season.GearDry or 0) + 1
		if season.GearDry >= GearConfig.Pity.After then
			local best = math.max(stage, season.HighestStage - 1)
			local lucky = Gear.PityDrop(equipped, best)
			if lucky then
				dropped, dropStage, pity = lucky, best, true
			end
			season.GearDry = 0
		end
	end
	local item, itemSoldFor
	if dropped then
		item, itemSoldFor = Gear.Grant(profile, dropStage, dropped)
	end

	if item or itemSoldFor then
		Quests.Record(profile, "Gear", 1)
	end

	-- runes: every frontier boss drops one, other frontier wins sometimes (Config/Runes Drop)
	local runeStat, runeTier = Runes.RollDrop(stage, isFrontier, Stages.IsBoss(stage), rand or math.random)
	local runeDrop = nil
	if runeStat then
		Runes.Grant(profile, runeStat, runeTier, 1)
		runeDrop = Runes.Label({ Stat = runeStat, Tier = runeTier })
	end

	local consumableId = Consumables.RollDrop(Stages.IsBoss(stage), rand or math.random)
	if consumableId then
		Consumables.Grant(profile, consumableId, 1)
	end

	-- bosses sometimes drop a piece of pet gear
	local petGearDrop = nil
	if Stages.IsBoss(stage) then
		local gotGear, piece = PetGear.BossDrop(profile, rand)
		if gotGear then
			petGearDrop = piece
		end
	end

	-- the active pet levels up from fighting too
	local petId = Pets.Active(profile)
	local petLevelsGained = 0
	if petId then
		local okPet, gained = Pets.AddXP(profile, petId, math.floor((rewards.XP or 0) * (PetsConfig.PetXPShare or 1)))
		petLevelsGained = if okPet then gained else 0
	end

	if isFrontier then
		season.HighestStage = stage + 1
	end
	local tutorialReward = Tutorial.PayIfSkipped(profile) -- a skipped tutorial still pays when the first boss falls

	return {
		Stage = stage,
		FrontierClear = isFrontier,
		Gold = rewards.Gold,
		XP = rewards.XP,
		Shards = rewards.Shards,
		Wishstones = wishstones,
		SkillPicks = skillPicks,
		PetsGained = petsGained,
		Item = item,
		ItemSoldFor = itemSoldFor,
		LuckyFind = pity or nil,
		Consumable = consumableId,
		PetGearDrop = petGearDrop,
		Rune = runeDrop,
		TutorialReward = tutorialReward,
		PetLevelsGained = petLevelsGained,
		LevelsGained = levelsGained,
		Level = season.Level,
	}
end

return Progression
