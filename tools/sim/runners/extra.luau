local m = {
	Consumables = require("./Consumables"),
	Zones = require("./Zones"), ZoneConfig = require("./Config/Zones"), Enemies = require("./Config/Enemies"),
	StageRunner = require("./StageRunner"), Stages = require("./Stages"), Abilities = require("./Config/Abilities"),
	Classes = require("./Config/Classes"), ProfileTemplate = require("./ProfileTemplate"), Skills = require("./Skills"),
	Statuses = require("./Config/Statuses"), Party = require("./Party"),
	Pets = require("./Pets"), PetConfig = require("./Config/Pets"), Progression = require("./Progression"), StatCalc = require("./Combat/StatCalc"),
	Entity = require("./Combat/Entity"), Simulation = require("./Combat/Simulation"), Passives = require("./Passives"), Ultimates = require("./Ultimates"),
	Economy = require("./Economy"), PassiveConfig = require("./Config/Passives"), UltimateConfig = require("./Config/Ultimates"),
	AbilityStats = require("./Combat/AbilityStats"), Rarities = require("./Config/Rarities"), EconomyConfig = require("./Config/Economy"),
}
m.FightStats = require("./FightStats")
m.SkillProgress = require("./SkillProgress") m.SkillConfig = require("./Config/SkillProgress")
require("./PresentationTests")(m)
require("./PetTests")(m)
require("./PassiveUltimateTests")(m)
require("./SkillStatsTests")(m)
m.Leaderboards = require("./Leaderboards")
require("./LeaderboardTests")(m)
m.World = require("./World") m.Hero = require("./Hero") m.Gear = require("./Gear") m.GearConfig = require("./Config/Gear") m.Daily = require("./Daily")
require("./GearDailyTests")(m)
m.Subclasses = require("./Subclasses") m.SubclassConfig = require("./Config/Subclasses")
require("./SubclassTests")(m)
require("./CompanionTests")(m)
require("./BossTests")(m)

m.Wishing = require("./Wishing") m.Abilities = require("./Config/Abilities")
require("./WishingTests")(m)

m.Bosses = require("./Bosses") m.BossConfig = require("./Config/Bosses")
require("./BossEventTests")(m)

m.Quests = require("./Quests") m.QuestConfig = require("./Config/Quests")
require("./QuestTests")(m)

require("./SkillProgressTests")(m)

m.Premium = require("./Premium") m.PremiumConfig = require("./Config/Premium")
require("./PremiumTests")(m)

m.SeasonRewards = require("./SeasonRewards") m.SeasonRewardsConfig = require("./Config/SeasonRewards")
require("./SeasonRewardsTests")(m)

m.Cosmetics = require("./Cosmetics") m.CosmeticsConfig = require("./Config/Cosmetics")
require("./CosmeticsTests")(m)

m.ConsumableConfig = require("./Config/Consumables") m.Codes = require("./Codes")
m.CodeList = require("./CodeList")
require("./CodesTests")(m)

m.ClassWeapons = require("./ClassWeapons") m.Character = require("./Character") m.CharacterConfig = require("./Config/Character")
require("./CharacterTests")(m)
m.Characters = require("./Characters")
require("./CharactersTests")(m)

require("./EquipBestTests")(m)

m.SkillEffects = require("./Config/SkillEffects") m.UltimateConfig2 = nil
m.UltimateConfig = require("./Config/Ultimates") m.Statuses = require("./Config/Statuses") m.Classes = require("./Config/Classes") m.Abilities = require("./Config/Abilities")
m.Effects = m.SkillEffects
require("./SkillEffectsTests")(m)

m.Simulation = require("./Combat/Simulation") m.StatCalc = require("./Combat/StatCalc") m.StageRunner = require("./StageRunner")
m.PassiveConfig = require("./Config/Passives") m.SubclassConfig = require("./Config/Subclasses") m.Subclasses = require("./Subclasses") m.Ultimates = require("./Ultimates")
m.PetConfig = require("./Config/Pets") m.SeasonRewardsConfig = require("./Config/SeasonRewards")
require("./NewClassTests")(m)

m.Minions = require("./Config/Minions")
require("./SummonerTests")(m)
require("./FightStatsTests")(m)
m.StageConfig = require("./Config/Stages")
require("./MonsterTests")(m)
m.GuildWish = require("./GuildWish") m.ProfileTemplate = m.ProfileTemplate m.Guilds = require("./Guilds") m.Bosses = require("./Bosses") m.Quests = require("./Quests")
require("./GuildTests")(m)
m.Statuses = m.Statuses or require("./Config/Statuses")
require("./DotTests")(m)
m.Power = require("./Power")
require("./PowerTests")(m)
m.Abilities = require("./Config/Abilities") m.Enemies = require("./Config/Enemies") m.GearConfig = require("./Config/Gear") m.Gear = require("./Gear") m.Entity = m.Entity or require("./Combat/Entity")
require("./RowTests")(m)

m.Tutorial = require("./Tutorial")
require("./TutorialTests")(m)

m.Activities = require("./Activities")
require("./ActivitiesTests")(m)
m.Market = require("./Market")
require("./MarketTests")(m)
m.Passes = require("./Passes") m.TableUtil = require("./Util/TableUtil")
require("./PassTests")(m)
m.StageRewards = require("./StageRewards")
require("./StageRewardsTests")(m)
m.PetGear = require("./PetGear")
require("./PetGearTests")(m)
m.Gifts = require("./Gifts")
require("./GiftTests")(m)
m.Runes = require("./Runes") m.RunesConfig = require("./Config/Runes")
require("./RuneTests")(m)
