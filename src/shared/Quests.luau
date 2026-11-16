--[[
	Quests (ModuleScript)
	Location: ReplicatedStorage > Shared > Quests

	Daily quests and the season pass. Pure functions; `now` (os.time()) is passed in so tests can move the clock.

	  Quests.Record(profile, event, amount, now)   count progress for today's quests and add pass XP for stage clears.
	                                               events: "Clear", "Frontier", "Boss", "Wish", "Feed", "Gear", "Strike"
	  Quests.Daily(profile, now)                   -> { Day, Quests = { { Index, Id, Text, Goal, Progress, Done, Claimed } }, BonusClaimed, BonusReady, Reward, Bonus }
	  Quests.ClaimQuest(profile, index, now)       -> true, reward | false, "BadQuest" | "NotDone" | "AlreadyClaimed"
	  Quests.ClaimBonus(profile, now)              -> true, reward | false, "NotReady" | "AlreadyClaimed"
	  Quests.Weekly(profile, now)                  -> like Daily but for the Monday-to-Sunday week, plus SecondsLeft
	  Quests.ClaimWeekly(profile, index, now) / Quests.ClaimWeeklyBonus(profile, now)   like the daily ones
	  Quests.Pass(profile)                         -> { Level, XP, XPInLevel, XPPerLevel, MaxLevel, Rows = { { Level, Reward, Reached, Claimed } } }
	  Quests.AddPassXP(profile, amount)            -> levels gained
	  Quests.ClaimPass(profile, level, track)             -> true, reward | false, "BadLevel" | "NotReached" | "AlreadyClaimed"
	  Quests.ClaimAllPass(profile)                 -> count claimed, totals
]]

local Config = require(script.Parent.Config.Quests)
local Consumables = require(script.Parent.Consumables)

local Quests = {}

local function dayNumber(now)
	return math.floor(now / 86400)
end

-- today's quest ids: a deterministic shuffle of the pool seeded by the day, one quest per event kind first
local function drawPool(sourcePool, count, key, salt)
	-- a small deterministic generator (the same on every server and in tests)
	local seed = (key * 7919 + 13 + salt) % 2147483647
	local function nextInt(n)
		seed = (seed * 48271) % 2147483647
		return seed % n + 1
	end
	local pool = table.clone(sourcePool)
	for i = #pool, 2, -1 do
		local j = nextInt(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local picked, kinds = {}, {}
	for _, q in ipairs(pool) do
		if not kinds[q.Event] and #picked < count then
			kinds[q.Event] = true
			table.insert(picked, q)
		end
	end
	return picked
end

local function todaysPool(day)
	return drawPool(Config.Pool, Config.QuestsPerDay, day, 0)
end

local function weekNumber(now)
	return (dayNumber(now) + 3) // 7 -- weeks start on Monday (day 0 was a Thursday)
end

local function weeksPool(week)
	return drawPool(Config.Weekly.Pool, Config.Weekly.QuestsPerWeek, week, 101)
end

local function weekState(profile, now)
	local week = weekNumber(now)
	local w = profile.Permanent.WeeklyQuests
	if w == nil or w.Week ~= week then
		w = { Week = week, Progress = {}, Claimed = {}, BonusClaimed = false }
		profile.Permanent.WeeklyQuests = w
	end
	return w
end

local function state(profile, now)
	local day = dayNumber(now)
	local q = profile.Permanent.Quests
	if q == nil or q.Day ~= day then
		q = { Day = day, Progress = {}, Claimed = {}, BonusClaimed = false }
		profile.Permanent.Quests = q
	end
	return q
end

local function goldFor(profile, clears)
	local Progression = require(script.Parent.Progression) -- lazy: Progression records quest progress
	local clear = Progression.ClearRewards(profile.Season.HighestStage or 1, true, nil)
	return math.floor(clear.Gold * clears)
end

function Quests.AddPassXP(profile, amount)
	local pass = profile.Season.Pass
	if pass == nil then
		pass = { XP = 0, Claimed = {} }
		profile.Season.Pass = pass
	end
	local before = math.min(Config.Pass.MaxLevel, pass.XP // Config.Pass.XPPerLevel)
	pass.XP = math.min(pass.XP + math.max(0, amount), Config.Pass.MaxLevel * Config.Pass.XPPerLevel)
	return math.min(Config.Pass.MaxLevel, pass.XP // Config.Pass.XPPerLevel) - before
end

function Quests.Record(profile, event, amount, now)
	amount = amount or 1
	now = now or os.time()
	local q = state(profile, now)
	-- guild missions: remembered here, sent to the shared guild by GuildService (see Permanent.GuildPending)
	local perm = profile.Permanent
	if perm and perm.Guild then
		perm.GuildPending = perm.GuildPending or {}
		perm.GuildPending[event] = (perm.GuildPending[event] or 0) + amount
	end
	for _, quest in ipairs(todaysPool(q.Day)) do
		if quest.Event == event then
			q.Progress[quest.Id] = math.min(quest.Goal, (q.Progress[quest.Id] or 0) + amount)
		end
	end
	local w = weekState(profile, now)
	for _, quest in ipairs(weeksPool(w.Week)) do
		if quest.Event == event then
			w.Progress[quest.Id] = math.min(quest.Goal, (w.Progress[quest.Id] or 0) + amount)
		end
	end
	local pass = Config.Pass
	if event == "Clear" then
		Quests.AddPassXP(profile, pass.PerClear)
	elseif event == "Frontier" then
		Quests.AddPassXP(profile, pass.PerFrontier)
	elseif event == "Boss" then
		Quests.AddPassXP(profile, pass.PerBoss)
	end
end

function Quests.Daily(profile, now)
	local q = state(profile, now)
	local rows, claimed = {}, 0
	for index, quest in ipairs(todaysPool(q.Day)) do
		local progress = q.Progress[quest.Id] or 0
		local isClaimed = q.Claimed[quest.Id] == true
		if isClaimed then
			claimed += 1
		end
		table.insert(rows, { Index = index, Id = quest.Id, Text = quest.Text, Goal = quest.Goal, Progress = progress, Done = progress >= quest.Goal, Claimed = isClaimed })
	end
	return {
		Day = q.Day, Quests = rows, BonusClaimed = q.BonusClaimed == true, BonusReady = claimed >= #rows and not q.BonusClaimed,
		Reward = { Gold = goldFor(profile, Config.QuestReward.GoldClears), Wishstones = Config.QuestReward.Wishstones, PassXP = Config.QuestReward.PassXP },
		Bonus = Config.BonusReward,
	}
end

function Quests.ClaimQuest(profile, index, now)
	local q = state(profile, now)
	local quest = todaysPool(q.Day)[index]
	if quest == nil then
		return false, "BadQuest"
	end
	if q.Claimed[quest.Id] then
		return false, "AlreadyClaimed"
	end
	if (q.Progress[quest.Id] or 0) < quest.Goal then
		return false, "NotDone"
	end
	q.Claimed[quest.Id] = true
	local reward = { Gold = goldFor(profile, Config.QuestReward.GoldClears), Wishstones = Config.QuestReward.Wishstones, PassXP = Config.QuestReward.PassXP }
	local c = profile.Season.Currencies
	c.Gold += reward.Gold
	c.Wishstones = (c.Wishstones or 0) + reward.Wishstones
	Quests.AddPassXP(profile, reward.PassXP)
	return true, reward
end

function Quests.ClaimBonus(profile, now)
	local q = state(profile, now)
	if q.BonusClaimed then
		return false, "AlreadyClaimed"
	end
	local daily = Quests.Daily(profile, now)
	if not daily.BonusReady then
		return false, "NotReady"
	end
	q.BonusClaimed = true
	local reward = Config.BonusReward
	local c = profile.Season.Currencies
	c.Wishstones = (c.Wishstones or 0) + reward.Wishstones
	for id, count in pairs(reward.Tickets or {}) do
		Consumables.Grant(profile, id, count)
	end
	Quests.AddPassXP(profile, reward.PassXP)
	return true, reward
end

-- Weekly quests ---------------------------------------------------------------------

function Quests.Weekly(profile, now)
	local w = weekState(profile, now)
	local rows, claimed = {}, 0
	for index, quest in ipairs(weeksPool(w.Week)) do
		local progress = w.Progress[quest.Id] or 0
		local isClaimed = w.Claimed[quest.Id] == true
		if isClaimed then
			claimed += 1
		end
		table.insert(rows, { Index = index, Id = quest.Id, Text = quest.Text, Goal = quest.Goal, Progress = progress, Done = progress >= quest.Goal, Claimed = isClaimed })
	end
	return {
		Week = w.Week, Quests = rows, BonusClaimed = w.BonusClaimed == true, BonusReady = claimed >= #rows and not w.BonusClaimed,
		Reward = Config.Weekly.QuestReward, Bonus = Config.Weekly.BonusReward,
		SecondsLeft = ((w.Week + 1) * 7 - 3) * 86400 - now,
	}
end

-- Sunstones live in Permanent.Premium (see Shared/Premium, which requires this module, so it is written here directly)
local function addSunstones(profile, amount)
	local n = math.max(0, math.floor(amount or 0))
	if n == 0 then
		return
	end
	local p = profile.Permanent.Premium
	if p == nil then
		p = { Sunstones = 0, Bought = {}, PacksBought = {} }
		profile.Permanent.Premium = p
	end
	p.Sunstones = (p.Sunstones or 0) + n
end

local function payWeekly(profile, reward)
	addSunstones(profile, reward.Sunstones)
	local c = profile.Season.Currencies
	c.Wishstones = (c.Wishstones or 0) + (reward.Wishstones or 0)
	for id, count in pairs(reward.Items or {}) do
		Consumables.Grant(profile, id, count)
	end
	for id, count in pairs(reward.Tickets or {}) do
		Consumables.Grant(profile, id, count)
	end
	Quests.AddPassXP(profile, reward.PassXP or 0)
end

function Quests.ClaimWeekly(profile, index, now)
	local w = weekState(profile, now)
	local quest = weeksPool(w.Week)[index]
	if quest == nil then
		return false, "BadQuest"
	end
	if w.Claimed[quest.Id] then
		return false, "AlreadyClaimed"
	end
	if (w.Progress[quest.Id] or 0) < quest.Goal then
		return false, "NotDone"
	end
	w.Claimed[quest.Id] = true
	payWeekly(profile, Config.Weekly.QuestReward)
	return true, Config.Weekly.QuestReward
end

function Quests.ClaimWeeklyBonus(profile, now)
	local w = weekState(profile, now)
	if w.BonusClaimed then
		return false, "AlreadyClaimed"
	end
	if not Quests.Weekly(profile, now).BonusReady then
		return false, "NotReady"
	end
	w.BonusClaimed = true
	payWeekly(profile, Config.Weekly.BonusReward)
	return true, Config.Weekly.BonusReward
end

local function passState(profile)
	profile.Season.Pass = profile.Season.Pass or { XP = 0, Claimed = {} }
	profile.Season.Pass.Claimed = profile.Season.Pass.Claimed or {}
	profile.Season.Pass.PremiumClaimed = profile.Season.Pass.PremiumClaimed or {}
	return profile.Season.Pass
end

local function rewardRow(profile, r)
	return { Gold = goldFor(profile, r.GoldClears or 0), Wishstones = r.Wishstones, Sunstones = r.Sunstones, Shards = r.Shards, SkillPicks = r.SkillPicks, Items = r.Items }
end

function Quests.Pass(profile)
	local pass = passState(profile)
	local per = Config.Pass.XPPerLevel
	local level = math.min(Config.Pass.MaxLevel, pass.XP // per)
	local rows = {}
	for l = 1, Config.Pass.MaxLevel do
		table.insert(rows, {
			Level = l, Reached = level >= l, Claimed = pass.Claimed[l] == true,
			Reward = rewardRow(profile, Config.Pass.Rewards[l]),
			PremiumReward = rewardRow(profile, Config.Pass.PremiumRewards[l]), PremiumClaimed = pass.PremiumClaimed[l] == true,
		})
	end
	return {
		Level = level, XP = pass.XP, XPInLevel = if level >= Config.Pass.MaxLevel then per else pass.XP % per, XPPerLevel = per,
		MaxLevel = Config.Pass.MaxLevel, Premium = pass.Premium == true, Rows = rows,
	}
end

-- Unlocks (or locks) the premium track. The real purchase calls this after a successful Robux purchase.
function Quests.SetPremium(profile, owned)
	passState(profile).Premium = owned == true
end

-- track: "Free" (default) or "Premium"
function Quests.ClaimPass(profile, level, track)
	local pass = passState(profile)
	local premium = track == "Premium"
	if type(level) ~= "number" or level ~= math.floor(level) or level < 1 or level > Config.Pass.MaxLevel then
		return false, "BadLevel"
	end
	if pass.XP // Config.Pass.XPPerLevel < level then
		return false, "NotReached"
	end
	if premium and not pass.Premium then
		return false, "PremiumOnly"
	end
	local claimed = if premium then pass.PremiumClaimed else pass.Claimed
	if claimed[level] then
		return false, "AlreadyClaimed"
	end
	local r = (if premium then Config.Pass.PremiumRewards else Config.Pass.Rewards)[level]
	claimed[level] = true
	local c = profile.Season.Currencies
	local reward = { Gold = goldFor(profile, r.GoldClears or 0), Wishstones = r.Wishstones or 0, Sunstones = r.Sunstones or 0, Shards = r.Shards or 0, SkillPicks = r.SkillPicks or 0, Items = r.Items }
	addSunstones(profile, reward.Sunstones)
	c.Gold += reward.Gold
	c.Wishstones = (c.Wishstones or 0) + reward.Wishstones
	c.Shards += reward.Shards
	c.SkillPicks += reward.SkillPicks
	for id, count in pairs(r.Items or {}) do
		Consumables.Grant(profile, id, count)
	end
	return true, reward
end

-- claims every free level that is ready, and every premium one when the premium track is owned
function Quests.ClaimAllPass(profile)
	local claimed = 0
	for l = 1, Config.Pass.MaxLevel do
		if Quests.ClaimPass(profile, l, "Free") then
			claimed += 1
		end
		if Quests.ClaimPass(profile, l, "Premium") then
			claimed += 1
		end
	end
	return claimed
end

return Quests
