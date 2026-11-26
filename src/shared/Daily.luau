--[[
	Daily (ModuleScript)
	Location: ReplicatedStorage > Shared > Daily

	Daily login streak. Pure functions: the caller passes `now` (os.time()) so
	tests can move the clock. A "day" is a UTC calendar day.

	Permanent.Login = { Streak = n, LastDay = dayNumber }  (absent until first claim)

	  Daily.DayNumber(now)                 -> whole days since the epoch (UTC)
	  Daily.Status(profile, now)           -> { CanClaim, Streak, NextDay, Reward, Week = { { Day, Reward, State = "Claimed"|"Today"|"Upcoming" } } }
	                                          NextDay is 1..7 (the cycle day you would get)
	  Daily.Claim(profile, now)            -> true, summary | false, "AlreadyClaimed"
	                                          summary = { Day, Streak, Gold, Shards, SkillPicks, PetLevel }
	  Daily.RewardFor(profile, day)        -> { Gold, Shards, SkillPicks } for a cycle day
]]

local Config = require(script.Parent.Config.Daily)
local Pets = require(script.Parent.Pets)

local Daily = {}

function Daily.DayNumber(now)
	return math.floor(now / 86400)
end

local function login(profile)
	profile.Permanent.Login = profile.Permanent.Login or { Streak = 0, LastDay = -1 }
	return profile.Permanent.Login
end

-- The streak you would have after claiming today.
local function nextStreak(state, today)
	if state.LastDay == today - 1 then
		return state.Streak + 1
	end
	return 1
end

local function cycleDay(streak)
	return (streak - 1) % Config.CycleLength + 1
end

function Daily.RewardFor(profile, day)
	local def = Config.Days[day]
	return {
		Gold = def.Gold,
		Shards = def.Shards,
		SkillPicks = def.SkillPicks or 0,
		Wishstones = def.Wishstones or 0,
	}
end

function Daily.Status(profile, now)
	local state = login(profile)
	local today = Daily.DayNumber(now)
	local claimed = state.LastDay == today
	local streak = if claimed then state.Streak else nextStreak(state, today)
	local day = cycleDay(streak)
	-- the whole cycle as a calendar: what each day pays and where you are in it
	local week = {}
	for d = 1, Config.CycleLength do
		table.insert(week, {
			Day = d,
			Reward = Daily.RewardFor(profile, d),
			State = if d < day or (claimed and d == day) then "Claimed" elseif d == day then "Today" else "Upcoming",
		})
	end
	return {
		Week = week,
		CanClaim = not claimed,
		Streak = if claimed then state.Streak else state.Streak, -- current streak before today's claim
		NextStreak = streak,
		NextDay = day,
		Reward = Daily.RewardFor(profile, day),
	}
end

function Daily.Claim(profile, now)
	local state = login(profile)
	local today = Daily.DayNumber(now)
	if state.LastDay == today then
		return false, "AlreadyClaimed"
	end
	local streak = nextStreak(state, today)
	local day = cycleDay(streak)
	local reward = Daily.RewardFor(profile, day)
	local season = profile.Season
	season.Currencies.Gold += reward.Gold
	season.Currencies.Shards += reward.Shards
	season.Currencies.SkillPicks += reward.SkillPicks
	season.Currencies.Wishstones = (season.Currencies.Wishstones or 0) + reward.Wishstones
	state.Streak = streak
	state.LastDay = today
	return true, { Day = day, Streak = streak, Gold = reward.Gold, Shards = reward.Shards, SkillPicks = reward.SkillPicks, Wishstones = reward.Wishstones }
end

return Daily
