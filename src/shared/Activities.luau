--[[
	Activities (ModuleScript): dungeons and expeditions, the two repeatable activities beside the stage climb.

	DUNGEONS  a short run of tough floors fought back to back with the normal auto combat. Each run costs one key (the keys
	  refill every day). The run ends at the first lost floor; every floor cleared pays, and a full clear pays a bonus chest.
	  Floors are fought on a copy of the profile, so they never pay the normal stage rewards.
	EXPEDITIONS  send the party away for a while, then collect. One expedition at a time, paid by its length.

	  Activities.Dungeons / Activities.Expeditions       data lists
	  Activities.Of(profile, now)                        -> { Keys, MaxKeys, Expedition = { Id, EndsAt, Ready } | nil } (rolls the day over)
	  Activities.Unlocked(profile, dungeon)              -> bool
	  Activities.FloorStage(frontier, dungeon, floor)    -> the stage whose monsters are fought
	  Activities.RunDungeon(profile, members, id, seed, now, record) -> ok, result | false, reason
	        result = { Name, Floors, Cleared, Full, Lines, Fight? } (Fight = the last floor fought, for the replay)
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

local Activities = {}

Activities.MaxKeys = 3
Activities.FloorsPerDungeon = 4

Activities.Dungeons = {
	{ Id = "Crypt", Name = "Forgotten Crypt", Unlock = 5, Lift = 0, Blurb = "Bones and old curses. A good first dungeon." },
	{ Id = "Foundry", Name = "Ember Foundry", Unlock = 20, Lift = 3, Blurb = "Molten halls guarded by constructs." },
	{ Id = "Abyss", Name = "Sunken Abyss", Unlock = 40, Lift = 6, Blurb = "Deep water and deeper things." },
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
		a.Keys = Activities.MaxKeys
	end
	local e = a.Expedition
	return {
		Keys = a.Keys, MaxKeys = Activities.MaxKeys,
		Expedition = if e then { Id = e.Id, EndsAt = e.EndsAt, Ready = (now or os.time()) >= e.EndsAt } else nil,
	}
end

function Activities.Unlocked(profile, dungeon)
	return profile.Season.HighestStage >= dungeon.Unlock
end

function Activities.FloorStage(frontier, dungeon, floor)
	return math.max(1, math.floor(frontier * 0.8)) + dungeon.Lift + floor - 1
end

local function chestFor(frontier, floors, full)
	local rewards = { Gold = math.floor((120 + frontier * 30) * floors), Items = { PetFood = floors } }
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
	local frontier = profile.Season.HighestStage
	-- floors are fought on copies so they never pay the normal stage rewards
	local copies = {}
	for _, member in ipairs(members) do
		table.insert(copies, if member.Profile then { Id = member.Id, Name = member.Name, Profile = TableUtil.DeepCopy(member.Profile) } else member)
	end
	local cleared, fight = 0, nil
	for floor = 1, Activities.FloorsPerDungeon do
		local outcome = StageRunner.Run(copies, Activities.FloorStage(frontier, dungeon, floor), seed + floor, nil, record)
		if record then
			fight = { Roster = outcome.Roster, Events = outcome.Events, Duration = outcome.Duration, Won = outcome.Won }
		end
		if not outcome.Won then
			break
		end
		cleared += 1
	end
	local full = cleared == Activities.FloorsPerDungeon
	local lines = {}
	if cleared > 0 then
		lines = Bosses.GrantRewards(profile, chestFor(frontier, cleared, full), frontier)
		Quests.Record(profile, "Strike", 1, now)
	end
	return true, { Name = dungeon.Name, Floors = Activities.FloorsPerDungeon, Cleared = cleared, Full = full, Lines = lines, Fight = fight, Keys = row(profile).Keys }
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
		Gold = math.floor((200 + frontier * 40) * def.Power),
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
