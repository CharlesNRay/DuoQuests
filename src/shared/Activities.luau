--[[
	Activities (ModuleScript): dungeons and expeditions, the two repeatable activities beside the stage climb.

	DUNGEONS  one long fight at a fixed difficulty (Stage) with a recommended level: 2-3 waves of monsters, then a boss.
	  Each wave walks in when the last one falls, and nothing resets in between (no healing, no cooldown reset), so the
	  party must last until it is fully cleared. Each run costs one key (the keys refill every day). Every wave beaten
	  pays; beating the boss pays a bonus chest. Fought on a copy of the profile, so it never pays the normal stage rewards.
	EXPEDITIONS  send the party away for a while, then collect. One expedition at a time, paid by its length.

	  Activities.Dungeons / Activities.Expeditions       data lists
	  Activities.Of(profile, now)                        -> { Keys, MaxKeys, Daily = { [dungeonId] = true }, Expedition = { Id, EndsAt, Ready } | nil }
	                                                        (rolls the day over; Daily = dungeons whose daily bonus was taken today)
	DAILY BONUS  the first full clear of each dungeon each day also pays Activities.DailyBonus (resets with the keys).
	  Activities.Unlocked(profile, dungeon)              -> bool
	  Activities.BuildDungeon(dungeon)                   -> first wave, later waves (the boss is the last), time limit
	  Activities.FightDungeon(members, dungeon, seed, record) -> waves beaten, outcome (no keys, no rewards; for tests/sims)
	  Activities.RunDungeon(profile, members, id, seed, now, record) -> ok, result | false, reason
	        result = { Name, Floors, Cleared, Full, Lines, Fight? } (Floors = waves including the boss; Fight = the replay)
	  Activities.StartExpedition(profile, id, now)       -> ok | false, reason
	  Activities.CollectExpedition(profile, now)         -> ok, lines | false, reason
]]
local TableUtil = require(script.Parent.Util.TableUtil)
local Simulation = require(script.Parent.Combat.Simulation)
local StatCalc = require(script.Parent.Combat.StatCalc)
local StageRunner = require(script.Parent.StageRunner)
local Stages = require(script.Parent.Stages)
local Bosses = require(script.Parent.Bosses)
local Quests = require(script.Parent.Quests)
local Progression = require(script.Parent.Progression)

local Activities = {}

Activities.MaxKeys = 3

-- Stage = how hard its monsters are (as that map stage), Level = the recommended hero level, Waves = monster waves before
-- the boss, Unlock = highest stage needed to enter
Activities.Dungeons = {
	{ Id = "Crypt", Name = "Forgotten Crypt", Unlock = 5, Stage = 8, Level = 8, Waves = 2, Blurb = "Bones and old curses. A good first dungeon." },
	{ Id = "Foundry", Name = "Ember Foundry", Unlock = 18, Stage = 21, Level = 20, Waves = 3, Blurb = "Molten halls guarded by constructs." },
	{ Id = "Abyss", Name = "Sunken Abyss", Unlock = 32, Stage = 34, Level = 31, Waves = 3, Blurb = "Deep water and deeper things." },
	{ Id = "Spire", Name = "Frostbound Spire", Unlock = 50, Stage = 52, Level = 40, Waves = 3, Blurb = "A frozen tower that never stops climbing." },
}

Activities.Expeditions = {
	{ Id = "Scout", Name = "Short Scout", Seconds = 30 * 60, Power = 1 },
	{ Id = "Patrol", Name = "Long Patrol", Seconds = 2 * 3600, Power = 3.4 },
	{ Id = "Voyage", Name = "Grand Voyage", Seconds = 8 * 3600, Power = 11 },
}

local function dungeonOf(id)
	for _, d in ipairs(Activities.Dungeons) do
		if d.Id == id then
			return d
		end
	end
end

local function expeditionOf(id)
	for _, e in ipairs(Activities.Expeditions) do
		if e.Id == id then
			return e
		end
	end
end

local function maxKeys(profile)
	return Activities.MaxKeys + require(script.Parent.Passes).Perks(profile).DungeonKeys
end

local function row(profile)
	local permanent = profile.Permanent
	if type(permanent.Activities) ~= "table" then
		permanent.Activities = { Day = 0, Keys = Activities.MaxKeys, Expedition = nil }
	end
	return permanent.Activities
end

function Activities.Of(profile, now)
	local a = row(profile)
	local day = math.floor((now or os.time()) / 86400)
	if a.Day ~= day then
		a.Day = day
		a.Keys = maxKeys(profile)
		a.Daily = {}
	end
	if type(a.Daily) ~= "table" then
		a.Daily = {}
	end
	local e = a.Expedition
	return {
		Keys = a.Keys, MaxKeys = maxKeys(profile), Daily = table.clone(a.Daily),
		Expedition = if e then { Id = e.Id, EndsAt = e.EndsAt, Ready = (now or os.time()) >= e.EndsAt } else nil,
	}
end

function Activities.Unlocked(profile, dungeon)
	return profile.Season.HighestStage >= dungeon.Unlock
end

local StagesConfig = require(script.Parent.Config.Stages)

-- waves of the dungeon's stage (a step harder each wave), then a boss scaled to the stage after the last wave
function Activities.BuildDungeon(dungeon)
	local waves = {}
	for w = 1, dungeon.Waves do
		local stage = dungeon.Stage + w - 1
		if Stages.IsBoss(stage) then
			stage -= 1
		end
		local list = {}
		for _, entry in ipairs(Stages.Build(stage).Enemies) do
			table.insert(list, StatCalc.NewEnemy(("w%d%s"):format(w, entry.Id), entry.EnemyId, entry.Scale, entry.HealthMult))
		end
		table.insert(waves, list)
	end
	local bossAt = dungeon.Stage + dungeon.Waves
	local bossStage = math.max(1, math.ceil(bossAt / StagesConfig.BossEvery)) * StagesConfig.BossEvery
	local bossEntry = Stages.Build(bossStage).Enemies[1]
	local scale = Stages.Scale(bossAt) * (StagesConfig.BossScaleMult or 1)
	table.insert(waves, { StatCalc.NewEnemy("boss", bossEntry.EnemyId, scale, Stages.HealthMult(bossStage) * (Activities.BossHealth or 1)) })
	local first = table.remove(waves, 1)
	local seconds = StagesConfig.TimeLimit * dungeon.Waves + StagesConfig.BossTimeLimit
	return first, waves, seconds
end

Activities.BossHealth = 1

-- paid once a day per dungeon, on its first full clear (gold in stage clears of the dungeon's stage)
Activities.DailyBonus = { GoldClears = 40, Items = { SkillWish = 2, PetWish = 2, XPTonic = 1 } }

local function countWaves(events)
	local n = 0
	for _, e in ipairs(events) do
		if e.Type == "Wave" then
			n = e.Wave - 1
		end
	end
	return n
end

function Activities.FightDungeon(members, dungeon, seed, record)
	local first, waves, seconds = Activities.BuildDungeon(dungeon)
	local frontier = 0
	for _, m in ipairs(members) do
		frontier = math.max(frontier, if m.Profile then m.Profile.Season.HighestStage else 0)
	end
	local ultimate = StageRunner.UltimateFor(members, math.max(frontier, dungeon.Stage), nil)
	local outcome = StageRunner.Run(members, dungeon.Stage, seed, ultimate, true, { Enemies = first, Waves = waves, MaxSeconds = seconds })
	local beaten = countWaves(outcome.Events)
	if outcome.Won then
		beaten = dungeon.Waves + 1
	end
	if not record then
		outcome.Events, outcome.Roster = nil, nil
	end
	return beaten, outcome
end

-- gold is paid in "clears": what one frontier stage clear pays right now
local function clearGold(frontier)
	return Progression.ClearRewards(math.max(1, frontier), true, nil).Gold
end

local function chestFor(frontier, floors, full)
	local rewards = { Gold = math.floor(clearGold(frontier) * 18 * floors), Items = { PetFood = floors } }
	if floors >= 2 then
		rewards.Items.XPTonic = 1
	end
	if full then
		rewards.Items.SkillWish = 1
		rewards.Items.PetWish = 1
		rewards.Gear = { Rarity = "Epic", Bonus = 4 }
	end
	return rewards
end

function Activities.RunDungeon(profile, members, id, seed, now, record)
	local dungeon = dungeonOf(id)
	if not dungeon then
		return false, "BadArgs"
	end
	if not Activities.Unlocked(profile, dungeon) then
		return false, "Locked"
	end
	local state = Activities.Of(profile, now)
	if state.Keys <= 0 then
		return false, "NoKeys"
	end
	row(profile).Keys -= 1
	-- fought on copies so it never pays the normal stage rewards
	local copies = {}
	for _, member in ipairs(members) do
		table.insert(copies, if member.Profile then { Id = member.Id, Name = member.Name, Profile = TableUtil.DeepCopy(member.Profile) } else member)
	end
	local cleared, outcome = Activities.FightDungeon(copies, dungeon, seed, record)
	local fight = if record then { Roster = outcome.Roster, Events = outcome.Events, Duration = outcome.Duration, Won = outcome.Won } else nil
	local floors = dungeon.Waves + 1
	local full = cleared == floors
	local lines = {}
	if cleared > 0 then
		lines = Bosses.GrantRewards(profile, chestFor(dungeon.Stage, cleared, full), dungeon.Stage)
		Quests.Record(profile, "Strike", 1, now)
	end
	local daily = false
	if full and not row(profile).Daily[dungeon.Id] then
		row(profile).Daily[dungeon.Id] = true
		daily = true
		local bonus = Activities.DailyBonus
		local extra = Bosses.GrantRewards(profile, { Gold = math.floor(clearGold(dungeon.Stage) * bonus.GoldClears), Items = table.clone(bonus.Items) }, dungeon.Stage)
		table.insert(lines, "Daily bonus:")
		for _, line in ipairs(extra) do
			table.insert(lines, line)
		end
	end
	return true, { Name = dungeon.Name, Floors = floors, Cleared = cleared, Full = full, Lines = lines, Fight = fight, Keys = row(profile).Keys, Level = dungeon.Level, Daily = daily }
end

function Activities.StartExpedition(profile, id, now)
	local def = expeditionOf(id)
	if not def then
		return false, "BadArgs"
	end
	local a = row(profile)
	if a.Expedition then
		return false, "Busy"
	end
	a.Expedition = { Id = id, EndsAt = (now or os.time()) + def.Seconds }
	return true
end

function Activities.CollectExpedition(profile, now)
	local a = row(profile)
	local e = a.Expedition
	if not e then
		return false, "None"
	end
	if (now or os.time()) < e.EndsAt then
		return false, "NotReady"
	end
	local def = expeditionOf(e.Id)
	a.Expedition = nil
	local frontier = profile.Season.HighestStage
	local rewards = {
		Gold = math.floor(clearGold(frontier) * 120 * def.Power),
		Items = { PetFood = math.max(1, math.floor(def.Power * 2)), XPTonic = math.max(1, math.floor(def.Power)) },
	}
	if def.Power >= 3 then
		rewards.Items.PetWish = 1
	end
	if def.Power >= 10 then
		rewards.Items.SkillWish = 2
		rewards.Gear = { Rarity = "Epic", Bonus = 6 }
	end
	return true, Bosses.GrantRewards(profile, rewards, frontier)
end

return Activities
