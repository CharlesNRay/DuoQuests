--[[
	Guilds (ModuleScript)
	Location: ReplicatedStorage > Shared > Guilds

	Pure logic on a guild table (the shared DataStore document). `now` (os.time()) is always passed in so tests can
	move the clock. The server wraps every mutation in DataStore:UpdateAsync, so these functions must be pure
	(they may run more than once on contention).

	Guild = { Id, Name, Tag, Desc, Open, MinLevel, Leader (userId), Created, Points, Earned, Upgrades = {[id]=level},
	          Members = { [tostring(userId)] = { Name, Rank, Joined, LastSeen, Level, Frontier, Gave } },
	          Requests = { [tostring(userId)] = { Name, Level, At } },
	          Missions = { Day, Week, Daily = {...}, Weekly = {...} }, Raid, Prev, Log }
]]

local Config = require(script.Parent.Config.Guilds)
local Bosses = require(script.Parent.Bosses)

local Guilds = {}
Guilds.Config = Config

local DAY = Config.Day

local function key(userId)
	return tostring(userId)
end

local function dayOf(now)
	return math.floor(now / DAY)
end

local function weekOf(now)
	return (dayOf(now) + 3) // 7 -- Monday to Sunday
end

function Guilds.Key(userId)
	return key(userId)
end

---------------------------------------------------------------- names
-- Returns the cleaned text or nil, reason. Roblox's text filter runs on top of this on the server.
function Guilds.CleanName(text)
	if type(text) ~= "string" then
		return nil, "BadName"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #text < Config.NameMin or #text > Config.NameMax or text:find("[^%w ]") then
		return nil, "BadName"
	end
	return text
end

function Guilds.CleanTag(text)
	if type(text) ~= "string" then
		return nil, "BadTag"
	end
	text = text:upper():gsub("%s", "")
	if #text < Config.TagMin or #text > Config.TagMax or text:find("[^%w]") then
		return nil, "BadTag"
	end
	return text
end

---------------------------------------------------------------- creation and members
function Guilds.New(id, name, tag, leaderId, leaderInfo, now)
	local g = {
		Id = id, Name = name, Tag = tag, Desc = "", Open = true, MinLevel = 1,
		Leader = leaderId, Created = now, Points = 0, Earned = 0,
		Upgrades = {}, Members = {}, Requests = {}, Log = {},
		Missions = { Day = dayOf(now), Week = weekOf(now), Daily = { Progress = {}, By = {}, Claimed = {}, Goals = {}, Awarded = {} }, Weekly = { Progress = {}, By = {}, Claimed = {}, Goals = {}, Awarded = {} } },
	}
	g.Members[key(leaderId)] = {
		Name = leaderInfo.Name, Rank = "Leader", Joined = now, LastSeen = now,
		Level = leaderInfo.Level or 1, Frontier = leaderInfo.Frontier or 1, Gave = 0,
	}
	Guilds.Log(g, now, "Founded by " .. leaderInfo.Name .. ".")
	return g
end

function Guilds.Log(g, now, text)
	g.Log = g.Log or {}
	table.insert(g.Log, 1, { At = now, Text = text })
	while #g.Log > 30 do
		table.remove(g.Log)
	end
end

function Guilds.Count(g)
	local n = 0
	for _ in pairs(g.Members) do
		n += 1
	end
	return n
end

function Guilds.Capacity(g)
	local slots = Config.BaseMembers + (g.Upgrades.Roster or 0) * Config.Upgrades.Roster.PerLevel
	return math.min(Config.MaxMembers, slots)
end

function Guilds.Active(g, now)
	local n = 0
	for _, m in pairs(g.Members) do
		if now - m.LastSeen <= Config.ActiveDays * DAY then
			n += 1
		end
	end
	return math.max(1, n)
end

function Guilds.Rank(g, userId)
	local m = g.Members[key(userId)]
	return m and m.Rank or nil
end

local function canManage(g, userId)
	local rank = Guilds.Rank(g, userId)
	return rank == "Leader" or rank == "Officer"
end
Guilds.CanManage = canManage

function Guilds.AddMember(g, userId, info, now)
	if g.Members[key(userId)] then
		return false, "AlreadyMember"
	end
	if Guilds.Count(g) >= Guilds.Capacity(g) then
		return false, "Full"
	end
	g.Members[key(userId)] = {
		Name = info.Name, Rank = "Member", Joined = now, LastSeen = now,
		Level = info.Level or 1, Frontier = info.Frontier or 1, Gave = 0,
	}
	g.Requests[key(userId)] = nil
	Guilds.Log(g, now, info.Name .. " joined.")
	return true
end

-- A player asks to join, or joins at once when the guild is open. Returns true, "Joined" | "Requested".
function Guilds.Join(g, userId, info, now)
	if g.Members[key(userId)] then
		return false, "AlreadyMember"
	end
	if (info.Level or 1) < (g.MinLevel or 1) then
		return false, "LevelTooLow"
	end
	if g.Open then
		local ok, reason = Guilds.AddMember(g, userId, info, now)
		return ok, if ok then "Joined" else reason
	end
	local n = 0
	for _ in pairs(g.Requests) do
		n += 1
	end
	if n >= Config.MaxRequests and not g.Requests[key(userId)] then
		return false, "RequestsFull"
	end
	g.Requests[key(userId)] = { Name = info.Name, Level = info.Level or 1, At = now }
	return true, "Requested"
end

function Guilds.Approve(g, byId, userId, accept, now)
	if not canManage(g, byId) then
		return false, "NotAllowed"
	end
	local req = g.Requests[key(userId)]
	if req == nil then
		return false, "NoRequest"
	end
	if not accept then
		g.Requests[key(userId)] = nil
		return true
	end
	return Guilds.AddMember(g, userId, { Name = req.Name, Level = req.Level }, now)
end

local function dropMember(g, userId)
	g.Members[key(userId)] = nil
	for _, kind in ipairs({ "Daily", "Weekly" }) do
		local state = g.Missions[kind]
		state.By[key(userId)] = nil
	end
	if g.Raid and g.Raid.Used then
		g.Raid.Used[key(userId)] = g.Raid.Used[key(userId)] -- attempts stay: leaving does not refund strikes
	end
end

-- Leaving: the leader can only leave when alone (the guild then ends), see Guilds.IsEmpty.
function Guilds.Leave(g, userId, now)
	local m = g.Members[key(userId)]
	if m == nil then
		return false, "NotMember"
	end
	if m.Rank == "Leader" and Guilds.Count(g) > 1 then
		return false, "LeaderCannotLeave"
	end
	dropMember(g, userId)
	Guilds.Log(g, now, m.Name .. " left.")
	return true
end

function Guilds.IsEmpty(g)
	return Guilds.Count(g) == 0
end

function Guilds.Kick(g, byId, userId, now)
	local by, target = g.Members[key(byId)], g.Members[key(userId)]
	if by == nil or target == nil then
		return false, "NotMember"
	end
	if byId == userId then
		return false, "BadTarget"
	end
	if by.Rank == "Member" or target.Rank == "Leader" or (target.Rank == "Officer" and by.Rank ~= "Leader") then
		return false, "NotAllowed"
	end
	dropMember(g, userId)
	Guilds.Log(g, now, target.Name .. " was removed.")
	return true
end

function Guilds.SetRank(g, byId, userId, rank)
	if Guilds.Rank(g, byId) ~= "Leader" then
		return false, "NotAllowed"
	end
	local target = g.Members[key(userId)]
	if target == nil or target.Rank == "Leader" or (rank ~= "Officer" and rank ~= "Member") then
		return false, "BadTarget"
	end
	target.Rank = rank
	return true
end

function Guilds.TransferLeader(g, byId, userId, now, reason)
	if Guilds.Rank(g, byId) ~= "Leader" then
		return false, "NotAllowed"
	end
	local target = g.Members[key(userId)]
	if target == nil or byId == userId then
		return false, "BadTarget"
	end
	g.Members[key(byId)].Rank = "Member"
	target.Rank = "Leader"
	g.Leader = userId
	Guilds.Log(g, now, reason or (target.Name .. " is the new leader."))
	return true
end

function Guilds.SetInfo(g, byId, info)
	if not canManage(g, byId) then
		return false, "NotAllowed"
	end
	if info.Desc ~= nil then
		g.Desc = tostring(info.Desc):sub(1, Config.DescMax)
	end
	if info.Open ~= nil then
		g.Open = info.Open == true
	end
	if info.MinLevel ~= nil then
		g.MinLevel = math.clamp(math.floor(tonumber(info.MinLevel) or 1), 1, 200)
	end
	return true
end

-- Guild chat (2026-11-22): the last Config.ChatKeep messages live in the guild document. The server filters the text
-- (TextService) and rate-limits before this runs; this only checks membership and keeps the list short.
function Guilds.Chat(g, byId, text, now)
	local m = g.Members[key(byId)]
	if m == nil then
		return false, "NotInGuild"
	end
	text = tostring(text or ""):sub(1, Config.ChatMax)
	if text:match("^%s*$") then
		return false, "Empty"
	end
	g.Chat = g.Chat or {}
	table.insert(g.Chat, { UserId = byId, Name = m.Name, Text = text, At = now })
	while #g.Chat > Config.ChatKeep do
		table.remove(g.Chat, 1)
	end
	return true
end

-- Mark that a member was seen (login or contribution) and refresh what the roster shows about them.
function Guilds.Touch(g, userId, now, info)
	local m = g.Members[key(userId)]
	if m == nil then
		return false
	end
	m.LastSeen = now
	if info then
		m.Name = info.Name or m.Name
		m.Level = info.Level or m.Level
		m.Frontier = info.Frontier or m.Frontier
	end
	return true
end

---------------------------------------------------------------- succession
-- If the leader has been away for InactiveDays, leadership passes to the next in command: officers first (longest
-- serving first), then members by what they have given. The successor must have been seen within SuccessorDays; if
-- the first in line has not, the next is tried; if nobody qualifies nothing changes and the check simply runs again
-- the next time (every time the guild is opened). Also drops members unseen for InactiveKickDays.
-- Returns the new leader's id, or nil.
function Guilds.CheckSuccession(g, now)
	local leader = g.Members[key(g.Leader)]
	local changed = nil
	if leader == nil then
		leader = { LastSeen = 0 } -- a missing leader is treated as long gone
	end
	if now - leader.LastSeen >= Config.InactiveDays * DAY then
		local candidates = {}
		for k, m in pairs(g.Members) do
			if tonumber(k) ~= g.Leader and now - m.LastSeen <= Config.SuccessorDays * DAY then
				table.insert(candidates, { Id = tonumber(k), Member = m })
			end
		end
		table.sort(candidates, function(a, b)
			local ao, bo = a.Member.Rank == "Officer", b.Member.Rank == "Officer"
			if ao ~= bo then
				return ao
			end
			if a.Member.Rank == "Officer" and a.Member.Joined ~= b.Member.Joined then
				return a.Member.Joined < b.Member.Joined
			end
			if (a.Member.Gave or 0) ~= (b.Member.Gave or 0) then
				return (a.Member.Gave or 0) > (b.Member.Gave or 0)
			end
			return a.Id < b.Id
		end)
		local pick = candidates[1]
		if pick then
			local old = g.Members[key(g.Leader)]
			if old then
				old.Rank = "Member"
			end
			pick.Member.Rank = "Leader"
			g.Leader = pick.Id
			Guilds.Log(g, now, pick.Member.Name .. " became leader (the previous leader was away).")
			changed = pick.Id
		end
	end
	for k, m in pairs(g.Members) do
		if tonumber(k) ~= g.Leader and now - m.LastSeen > Config.InactiveKickDays * DAY then
			g.Members[k] = nil
		end
	end
	return changed
end

---------------------------------------------------------------- upgrades
function Guilds.UpgradeCost(id, level)
	local def = Config.Upgrades[id]
	return math.floor(def.Cost * Config.Growth ^ level)
end

-- Only the leader spends points (that is the point of the role). Reasons: "NotAllowed" "BadUpgrade" "MaxLevel" "NotEnoughPoints"
function Guilds.Buy(g, byId, id)
	if Guilds.Rank(g, byId) ~= "Leader" then
		return false, "NotAllowed"
	end
	local def = Config.Upgrades[id]
	if def == nil then
		return false, "BadUpgrade"
	end
	local level = g.Upgrades[id] or 0
	if level >= def.Max then
		return false, "MaxLevel"
	end
	local cost = Guilds.UpgradeCost(id, level)
	if g.Points < cost then
		return false, "NotEnoughPoints"
	end
	g.Points -= cost
	g.Upgrades[id] = level + 1
	Guilds.Log(g, 0, def.Name .. " reached level " .. (level + 1) .. ".")
	return true, level + 1
end

-- What every member gets: stat mods for combat plus gold / exp fractions.
function Guilds.Buffs(g)
	local mods, buffs = {}, { GoldGain = 0, XPGain = 0 }
	for _, id in ipairs(Config.UpgradeOrder) do
		local def, level = Config.Upgrades[id], g.Upgrades[id] or 0
		if level > 0 and not def.Plain then
			local value = def.PerLevel * level
			if def.Stat then
				table.insert(mods, { Stat = def.Stat, Mode = def.Mode, Value = value })
			else
				buffs[def.Key] = (buffs[def.Key] or 0) + value
			end
		end
	end
	return { Mods = mods, GoldGain = buffs.GoldGain, XPGain = buffs.XPGain }
end

---------------------------------------------------------------- missions
-- deterministic draw, the same for every server
local function draw(pool, count, seedValue)
	local seed = (seedValue * 7919 + 17) % 2147483647
	local function nextInt(n)
		seed = (seed * 48271) % 2147483647
		return seed % n + 1
	end
	local list = table.clone(pool)
	for i = #list, 2, -1 do
		local j = nextInt(i)
		list[i], list[j] = list[j], list[i]
	end
	local picked, kinds = {}, {}
	for _, q in ipairs(list) do
		if not kinds[q.Event] and #picked < count then
			kinds[q.Event] = true
			table.insert(picked, q)
		end
	end
	return picked
end

local function freshState()
	return { Progress = {}, By = {}, Claimed = {}, Goals = {}, Awarded = {} }
end

local function setGoals(g, kind, picked, now)
	local state = g.Missions[kind]
	local active = Guilds.Active(g, now)
	for _, q in ipairs(picked) do
		state.Goals[q.Id] = math.max(q.MinGoal, q.PerMember * active)
	end
end

function Guilds.Today(g, now)
	return draw(Config.Missions.Daily.Pool, Config.Missions.Daily.Count, dayOf(now))
end

function Guilds.ThisWeek(g, now)
	return draw(Config.Missions.Weekly.Pool, Config.Missions.Weekly.Count, weekOf(now) + 100000)
end

-- Roll missions and the raid over to the current day / week. Goals are fixed when the day or week starts.
function Guilds.Roll(g, now)
	local m = g.Missions
	if m.Day ~= dayOf(now) then
		m.Day = dayOf(now)
		m.Daily = freshState()
		setGoals(g, "Daily", Guilds.Today(g, now), now)
	end
	if m.Week ~= weekOf(now) then
		m.Week = weekOf(now)
		m.Weekly = freshState()
		setGoals(g, "Weekly", Guilds.ThisWeek(g, now), now)
	end
	-- goals for a brand new guild's first day / week
	for _, q in ipairs(Guilds.Today(g, now)) do
		if m.Daily.Goals[q.Id] == nil then
			setGoals(g, "Daily", { q }, now)
		end
	end
	for _, q in ipairs(Guilds.ThisWeek(g, now)) do
		if m.Weekly.Goals[q.Id] == nil then
			setGoals(g, "Weekly", { q }, now)
		end
	end
	Guilds.RollRaid(g, now)
end

local function pointsFor(g, base, now)
	return math.floor(base * (1 + Config.Missions.PointsPerMember * Guilds.Active(g, now)))
end

local function addPoints(g, amount)
	g.Points += amount
	g.Earned += amount
end

-- A member's action counts towards every mission for that event, today and this week.
function Guilds.Contribute(g, userId, event, amount, now)
	Guilds.Roll(g, now)
	local member = g.Members[key(userId)]
	if member == nil or amount <= 0 then
		return false
	end
	member.LastSeen = now
	local gained = 0
	for _, kind in ipairs({ "Daily", "Weekly" }) do
		local cfg = Config.Missions[kind]
		local state = g.Missions[kind]
		local picked = if kind == "Daily" then Guilds.Today(g, now) else Guilds.ThisWeek(g, now)
		for _, q in ipairs(picked) do
			if q.Event == event then
				local goal = state.Goals[q.Id]
				local before = state.Progress[q.Id] or 0
				if before < goal then
					local add = math.min(amount, goal - before)
					state.Progress[q.Id] = before + add
					local by = state.By[key(userId)] or {}
					state.By[key(userId)] = by
					by[q.Id] = (by[q.Id] or 0) + add
					member.Gave += add
					if before + add >= goal and not state.Awarded[q.Id] then
						state.Awarded[q.Id] = true
						local pts = pointsFor(g, cfg.Points, now)
						addPoints(g, pts)
						gained += pts
					end
				end
			end
		end
		-- all missions done: the bonus (once)
		local done = true
		for _, q in ipairs(picked) do
			done = done and state.Awarded[q.Id] == true
		end
		if done and not state.BonusAwarded then
			state.BonusAwarded = true
			local pts = pointsFor(g, cfg.BonusPoints, now)
			addPoints(g, pts)
			gained += pts
		end
	end
	return true, gained
end

-- The view of the missions: rows with progress, your share, and whether you can claim.
function Guilds.MissionRows(g, userId, kind, now)
	local cfg = Config.Missions[kind]
	local state = g.Missions[kind]
	local picked = if kind == "Daily" then Guilds.Today(g, now) else Guilds.ThisWeek(g, now)
	local rows = {}
	for index, q in ipairs(picked) do
		local goal = state.Goals[q.Id] or q.MinGoal
		local mine = (state.By[key(userId)] or {})[q.Id] or 0
		table.insert(rows, {
			Index = index, Id = q.Id, Text = q.Text, Event = q.Event, Goal = goal,
			Progress = state.Progress[q.Id] or 0, Mine = mine,
			Done = state.Awarded[q.Id] == true,
			Claimed = state.Claimed[key(userId) .. ":" .. q.Id] == true,
			CanClaim = state.Awarded[q.Id] == true and mine > 0 and not state.Claimed[key(userId) .. ":" .. q.Id],
		})
	end
	return rows, cfg.Reward
end

-- Reasons: "NotMember" "BadMission" "NotDone" "NoShare" "AlreadyClaimed". Returns true, reward { GoldClears, Wishstones, Marks }.
function Guilds.ClaimMission(g, userId, kind, index, now)
	Guilds.Roll(g, now)
	if g.Members[key(userId)] == nil then
		return false, "NotMember"
	end
	local state, cfg = g.Missions[kind], Config.Missions[kind]
	if state == nil or cfg == nil then
		return false, "BadMission"
	end
	local picked = if kind == "Daily" then Guilds.Today(g, now) else Guilds.ThisWeek(g, now)
	local q = picked[index]
	if q == nil then
		return false, "BadMission"
	end
	local claimKey = key(userId) .. ":" .. q.Id
	if state.Claimed[claimKey] then
		return false, "AlreadyClaimed"
	end
	if not state.Awarded[q.Id] then
		return false, "NotDone"
	end
	if ((state.By[key(userId)] or {})[q.Id] or 0) <= 0 then
		return false, "NoShare"
	end
	state.Claimed[claimKey] = true
	return true, table.clone(cfg.Reward)
end

---------------------------------------------------------------- raid
function Guilds.RaidBoss(week)
	local list = Config.Raid.Bosses
	return list[week % #list + 1]
end

local function raidHealth(g, now)
	local total = 0
	local count = 0
	for _, m in pairs(g.Members) do
		if now - m.LastSeen <= Config.ActiveDays * DAY then
			total += Bosses.DamageScale(m.Frontier or 1)
			count += 1
		end
	end
	local avg = if count > 0 then total / count else Bosses.DamageScale(1)
	return math.floor(Config.Raid.HealthPerScale * math.max(total, avg * Config.Raid.MinMembers))
end

function Guilds.RollRaid(g, now)
	local week = weekOf(now)
	if g.Raid and g.Raid.Week == week then
		return
	end
	if g.Raid then
		g.Prev = g.Raid
	end
	local boss = Guilds.RaidBoss(week)
	local health = raidHealth(g, now)
	g.Raid = { Week = week, BossId = boss.Id, Health = health, MaxHealth = health, Dealt = {}, Used = {}, Claimed = {}, Defeated = false }
end

function Guilds.RaidAttempts(g, userId, now)
	Guilds.Roll(g, now)
	local used = g.Raid.Used[key(userId)]
	if used == nil or used.Day ~= dayOf(now) then
		return Config.Raid.AttemptsPerDay
	end
	return math.max(0, Config.Raid.AttemptsPerDay - used.N)
end

-- Apply one strike. Reasons: "NotMember" "Defeated" "NoAttempts". Returns true, { Damage, Defeated, Health, Points }.
function Guilds.RaidHit(g, userId, damage, now)
	Guilds.Roll(g, now)
	if g.Members[key(userId)] == nil then
		return false, "NotMember"
	end
	local raid = g.Raid
	if raid.Defeated then
		return false, "Defeated"
	end
	if Guilds.RaidAttempts(g, userId, now) <= 0 then
		return false, "NoAttempts"
	end
	local used = raid.Used[key(userId)]
	if used == nil or used.Day ~= dayOf(now) then
		used = { Day = dayOf(now), N = 0 }
		raid.Used[key(userId)] = used
	end
	used.N += 1
	damage = math.max(0, math.floor(damage))
	local dealt = math.min(damage, raid.Health)
	raid.Health -= dealt
	raid.Dealt[key(userId)] = (raid.Dealt[key(userId)] or 0) + dealt
	g.Members[key(userId)].LastSeen = now
	local points = 0
	if raid.Health <= 0 then
		raid.Defeated = true
		points = Config.Raid.DefeatPoints
		addPoints(g, points)
		Guilds.Log(g, now, Guilds.RaidBoss(raid.Week).Name .. " was defeated!")
	end
	return true, { Damage = dealt, Defeated = raid.Defeated, Health = raid.Health, Points = points }
end

-- Rewards for a raid (the current one once it is defeated, or last week's). `which` = "Current" | "Prev".
-- Returns true, reward { Gold (clears), Marks, Wishstones, Tier } | false, "NoRaid" "NotOver" "NoShare" "AlreadyClaimed"
function Guilds.RaidClaim(g, userId, which, now)
	Guilds.Roll(g, now)
	local raid = if which == "Prev" then g.Prev else g.Raid
	if raid == nil then
		return false, "NoRaid"
	end
	if which ~= "Prev" and not raid.Defeated then
		return false, "NotOver"
	end
	if raid.Claimed[key(userId)] then
		return false, "AlreadyClaimed"
	end
	local dealt = raid.Dealt[key(userId)] or 0
	if dealt <= 0 then
		return false, "NoShare"
	end
	local participants = 0
	local total = 0
	for _, v in pairs(raid.Dealt) do
		participants += 1
		total += v
	end
	local share = (dealt / math.max(1, total)) * participants -- 1.0 = exactly an average member
	local tier = Config.Raid.Tiers[#Config.Raid.Tiers]
	for _, t in ipairs(Config.Raid.Tiers) do
		if share >= t.MinShare then
			tier = t
			break
		end
	end
	raid.Claimed[key(userId)] = true
	local reward = { Gold = tier.Gold, Marks = tier.Marks, Wishstones = tier.Wishstones, Tier = tier.Id, Share = share }
	if raid.Defeated then
		reward.Gold += Config.Raid.DefeatBonus.Gold
		reward.Marks += Config.Raid.DefeatBonus.Marks
		reward.Wishstones += Config.Raid.DefeatBonus.Wishstones
		reward.Defeated = true
	end
	return true, reward
end

---------------------------------------------------------------- view
-- What the client needs about a guild (never the whole document).
function Guilds.View(g, userId, now)
	Guilds.Roll(g, now)
	local members = {}
	for k, m in pairs(g.Members) do
		table.insert(members, {
			UserId = tonumber(k), Name = m.Name, Rank = m.Rank, Level = m.Level, Frontier = m.Frontier,
			Gave = m.Gave, SecondsAgo = math.max(0, now - m.LastSeen), Dealt = (g.Raid.Dealt[k] or 0),
		})
	end
	local rank = { Leader = 1, Officer = 2, Member = 3 }
	table.sort(members, function(a, b)
		if a.Rank ~= b.Rank then
			return rank[a.Rank] < rank[b.Rank]
		end
		return a.Gave > b.Gave
	end)
	local upgrades = {}
	for _, id in ipairs(Config.UpgradeOrder) do
		local def, level = Config.Upgrades[id], g.Upgrades[id] or 0
		table.insert(upgrades, {
			Id = id, Name = def.Name, Text = def.Text, Level = level, Max = def.Max,
			Cost = if level < def.Max then Guilds.UpgradeCost(id, level) else nil,
			Value = def.PerLevel * level, PerLevel = def.PerLevel, Mode = def.Mode, Plain = def.Plain,
		})
	end
	local dailyRows, dailyReward = Guilds.MissionRows(g, userId, "Daily", now)
	local weeklyRows, weeklyReward = Guilds.MissionRows(g, userId, "Weekly", now)
	local boss = Guilds.RaidBoss(g.Raid.Week)
	local requests = {}
	if canManage(g, userId) then
		for k, r in pairs(g.Requests) do
			table.insert(requests, { UserId = tonumber(k), Name = r.Name, Level = r.Level })
		end
		table.sort(requests, function(a, b) return a.UserId < b.UserId end)
	end
	return {
		Id = g.Id, Name = g.Name, Tag = g.Tag, Desc = g.Desc, Open = g.Open, MinLevel = g.MinLevel,
		Leader = g.Leader, Rank = Guilds.Rank(g, userId), Points = g.Points, Earned = g.Earned,
		Count = Guilds.Count(g), Capacity = Guilds.Capacity(g), Members = members, Requests = requests,
		Upgrades = upgrades, Log = g.Log,
		Chat = (function()
			local rows = {}
			for _, c in ipairs(g.Chat or {}) do
				table.insert(rows, { UserId = c.UserId, Name = c.Name, Text = c.Text, SecondsAgo = math.max(0, now - c.At) })
			end
			return rows
		end)(),
		Daily = { Rows = dailyRows, Reward = dailyReward, Bonus = Config.Missions.Daily.BonusPoints, SecondsLeft = (dayOf(now) + 1) * DAY - now },
		Weekly = { Rows = weeklyRows, Reward = weeklyReward, Bonus = Config.Missions.Weekly.BonusPoints, SecondsLeft = ((weekOf(now) * 7 - 3) + 7) * DAY - now },
		Raid = {
			Boss = { Id = boss.Id, Name = boss.Name, Blurb = boss.Blurb }, Health = g.Raid.Health, MaxHealth = g.Raid.MaxHealth,
			Defeated = g.Raid.Defeated, Attempts = Guilds.RaidAttempts(g, userId, now), PerDay = Config.Raid.AttemptsPerDay,
			MyDamage = g.Raid.Dealt[key(userId)] or 0, Claimed = g.Raid.Claimed[key(userId)] == true,
			CanClaim = g.Raid.Defeated and not g.Raid.Claimed[key(userId)] and (g.Raid.Dealt[key(userId)] or 0) > 0,
			PrevClaim = g.Prev ~= nil and not g.Prev.Claimed[key(userId)] and (g.Prev.Dealt[key(userId)] or 0) > 0,
			SecondsLeft = ((weekOf(now) * 7 - 3) + 7) * DAY - now,
		},
	}
end

-- A short row for the directory / search.
function Guilds.Summary(g, now)
	local boss = g.Raid and Guilds.RaidBoss(g.Raid.Week)
	local levels = 0
	for _, level in pairs(g.Upgrades) do
		levels += level
	end
	return {
		Id = g.Id, Name = g.Name, Tag = g.Tag, Desc = g.Desc, Open = g.Open, MinLevel = g.MinLevel,
		Count = Guilds.Count(g), Capacity = Guilds.Capacity(g), Power = levels, Active = Guilds.Active(g, now),
		Boss = boss and boss.Name or nil,
	}
end

return Guilds
