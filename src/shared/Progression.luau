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
local Gear = require(script.Parent.Gear)
local Consumables = require(script.Parent.Consumables)
local Quests = require(script.Parent.Quests)

local Progression = {}

function Progression.XPToNext(level)
	return Economy.XPBase + Economy.XPPerLevel * (level - 1)
end

function Progression.AddXP(season, amount)
	local gained = 0
	if season.Level >= Economy.MaxLevel then
		season.XP = 0
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
	local factor = Economy.RewardScale * replay -- gold and XP
	local shards = Economy.ShardsPerClear + stage // Economy.ShardStageStep
	if Stages.IsBoss(stage) then
		shards += Economy.BossShardBonus
	end
	return {
		Gold = math.max(1, math.floor((Economy.GoldBase + Economy.GoldPerStage * stage) * factor * goldFactor)),
		XP = math.max(1, math.floor((Economy.XPRewardBase + Economy.XPRewardPerStage * stage) * factor * xpFactor * (Economy.XPScale or 1))),
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
	bonuses = { GoldGain = (bonuses.GoldGain or 0) + boost.GoldGain + (guildBuffs.GoldGain or 0), XPGain = (bonuses.XPGain or 0) + boost.XPGain + (guildBuffs.XPGain or 0), ItemRarity = bonuses.ItemRarity }
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
	if Stages.IsBoss(stage) and not season.StageRewardsClaimed[stage] then
		season.StageRewardsClaimed[stage] = true
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
	local item, itemSoldFor
	if dropped then
		item, itemSoldFor = Gear.Grant(profile, stage, dropped)
	end

	if item or itemSoldFor then
		Quests.Record(profile, "Gear", 1)
	end

	local consumableId = Consumables.RollDrop(Stages.IsBoss(stage), rand or math.random)
	if consumableId then
		Consumables.Grant(profile, consumableId, 1)
	end

	-- the active pet levels up from fighting too
	local petId = Pets.Active(profile)
	local petLevelsGained = 0
	if petId then
		local okPet, gained = Pets.AddXP(profile, petId, Economy.PetXPPerClear or 12)
		petLevelsGained = if okPet then gained else 0
	end

	if isFrontier then
		season.HighestStage = stage + 1
	end

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
		Consumable = consumableId,
		PetLevelsGained = petLevelsGained,
		LevelsGained = levelsGained,
		Level = season.Level,
	}
end

return Progression
