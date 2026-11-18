--[[
	GuildService (ModuleScript)
	Location: ServerScriptService > Server > Services > GuildService

	Guilds are shared across every Roblox server through DataStores, like the season boss:
	  G_<id>        the guild document (see Shared/Guilds)
	  N_<name>      name -> id, so names are unique
	  U_<userId>    user -> guild id (so an approved request finds you from any server)
	  Directory     a list of guild summaries for the browser

	Every change goes through DataStore:UpdateAsync (atomic, may rerun, so the transform is pure). Without DataStore access
	(Studio) everything lives in memory on this server. Members never need to be online together: missions are collective and
	the raid boss has one shared health bar.

	  GuildService.Init(getProfile, onChanged)
	  GuildService.OnPlayerReady(player, profile) / OnPlayerLeaving(player, profile)
	  GuildService.State(player, profile)               -> true, { Guild = view|nil, Marks, Wish, Create }
	  GuildService.Create / Join / Leave / Kick / SetRank / Transfer / Approve / SetInfo / Buy / ClaimMission /
	  GuildService.RaidChallenge / RaidClaim / Search / Wish
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guilds = require(Shared.Guilds)
local GuildWish = require(Shared.GuildWish)
local Config = require(Shared.Config.Guilds)
local Bosses = require(Shared.Bosses)
local Quests = require(Shared.Quests)
local Progression = require(Shared.Progression)
local TableUtil = require(Shared.Util.TableUtil)

local GuildService = {}

local IS_STUDIO = RunService:IsStudio()
local CACHE_SECONDS = 15
local TOUCH_SECONDS = 300 -- how often a player's "last seen" is written
local FLUSH_SECONDS = 120

local store = nil
local mem = {} -- fallback when there is no DataStore
local cache = {} -- [guildId] = { Guild, At }
local dirty = {} -- [guildId] = true when the directory entry needs rewriting
local lastTouch = {} -- [userId] = os.clock()
local lastFlush = {} -- [userId] = os.clock()
local getProfile, onChanged

---------------------------------------------------------------- storage
-- fn(old) -> newValue|nil, outcome   (nil cancels the write; outcome is handed back)
local function mutate(key, fn)
	local outcome
	local function transform(old)
		local new, result = fn(old)
		outcome = result
		return new
	end
	if store then
		local ok, err
		for attempt = 1, 3 do
			ok, err = pcall(function()
				return store:UpdateAsync(key, transform)
			end)
			if ok then
				break
			end
			task.wait(0.5 * attempt)
		end
		if not ok then
			warn("[GuildService] " .. key .. ": " .. tostring(err))
			return nil, { false, "Unavailable" }
		end
		return outcome
	end
	local new = transform(if mem[key] ~= nil then TableUtil.DeepCopy(mem[key]) else nil)
	if new ~= nil then
		mem[key] = TableUtil.DeepCopy(new)
	end
	return outcome
end

local function read(key)
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		return if ok then value else nil
	end
	return if mem[key] ~= nil then TableUtil.DeepCopy(mem[key]) else nil
end

local function remove(key)
	if store then
		pcall(function()
			store:RemoveAsync(key)
		end)
	else
		mem[key] = nil
	end
end

local function fetch(id, force)
	local c = cache[id]
	if c and not force and os.clock() - c.At < CACHE_SECONDS then
		return c.Guild
	end
	local g = read("G_" .. id)
	if g then
		cache[id] = { Guild = g, At = os.clock() }
	else
		cache[id] = nil
	end
	return g
end

-- run a change on a guild; outcome = { true, data } | { false, reason }
local function change(id, fn)
	local outcome = mutate("G_" .. id, function(g)
		if g == nil then
			return nil, { false, "NoGuild" }
		end
		local new, result = fn(g)
		if new == nil then
			return nil, result
		end
		return new, result
	end)
	if outcome == nil then
		return false, "Unavailable"
	end
	cache[id] = nil
	if outcome[1] then
		dirty[id] = true
	end
	return outcome[1], outcome[2]
end

---------------------------------------------------------------- profile helpers
local function info(player, profile)
	return { Name = player.Name, Level = profile.Season.Level, Frontier = profile.Season.HighestStage }
end

local function sync(player, profile, g)
	local perm = profile.Permanent
	local before = perm.GuildBuffs
	if g and g.Members[tostring(player.UserId)] then
		perm.Guild = { Id = g.Id, Name = g.Name, Tag = g.Tag }
		perm.GuildBuffs = Guilds.Buffs(g)
	else
		perm.Guild = nil
		perm.GuildBuffs = nil
		perm.GuildPending = nil
	end
	local changed = (before == nil) ~= (perm.GuildBuffs == nil) or (before and perm.GuildBuffs and #before.Mods ~= #perm.GuildBuffs.Mods)
	if not changed and before and perm.GuildBuffs then
		for index, mod in ipairs(perm.GuildBuffs.Mods) do
			if before.Mods[index].Value ~= mod.Value then changed = true end
		end
		changed = changed or before.GoldGain ~= perm.GuildBuffs.GoldGain or before.XPGain ~= perm.GuildBuffs.XPGain
	end
	if changed and onChanged then
		onChanged(player)
	end
end

local function applyReward(profile, reward)
	local c = profile.Season.Currencies
	if reward.GoldClears then
		c.Gold += math.floor(Progression.ClearRewards(profile.Season.HighestStage or 1, true, nil).Gold * reward.GoldClears)
	end
	if reward.Gold then -- raid rewards are also in clears
		c.Gold += math.floor(Progression.ClearRewards(profile.Season.HighestStage or 1, true, nil).Gold * reward.Gold)
	end
	c.Wishstones = (c.Wishstones or 0) + (reward.Wishstones or 0)
	profile.Permanent.GuildMarks = (profile.Permanent.GuildMarks or 0) + (reward.Marks or 0)
end

local function filtered(text, player)
	if text == "" then
		return text
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return if IS_STUDIO then text else nil
	end
	return result
end

---------------------------------------------------------------- directory
local function summaryRow(g)
	return Guilds.Summary(g, os.time())
end

local function flushDirectory()
	local ids = {}
	for id in pairs(dirty) do
		table.insert(ids, id)
	end
	if #ids == 0 then
		return
	end
	local rows = {}
	for _, id in ipairs(ids) do
		dirty[id] = nil
		local g = read("G_" .. id)
		rows[id] = if g and not g.Disbanded then summaryRow(g) else false
	end
	mutate("Directory", function(dir)
		dir = dir or { List = {} }
		for id, row in pairs(rows) do
			dir.List[id] = if row then row else nil
		end
		local count = 0
		for _ in pairs(dir.List) do
			count += 1
		end
		if count > 400 then -- keep the most powerful
			local sorted = {}
			for id, row in pairs(dir.List) do
				table.insert(sorted, { Id = id, Power = row.Power })
			end
			table.sort(sorted, function(a, b) return a.Power > b.Power end)
			for index = 401, #sorted do
				dir.List[sorted[index].Id] = nil
			end
		end
		return dir, { true }
	end)
end

function GuildService.Search(player, profile, query)
	local dir = read("Directory") or { List = {} }
	query = if type(query) == "string" then query:lower():sub(1, 24) else ""
	local rows = {}
	for _, row in pairs(dir.List) do
		if query == "" or row.Name:lower():find(query, 1, true) or row.Tag:lower() == query then
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, b)
		if a.Open ~= b.Open then
			return a.Open
		end
		if a.Active ~= b.Active then
			return a.Active > b.Active
		end
		return a.Name < b.Name
	end)
	while #rows > 25 do
		table.remove(rows)
	end
	return true, { Guilds = rows }
end

---------------------------------------------------------------- state
local function stateFor(player, profile, g)
	local data = {
		Marks = profile.Permanent.GuildMarks or 0,
		Wish = GuildWish.Info(profile),
		Create = { Gold = Config.CreateGold, MinLevel = Config.CreateMinLevel },
	}
	if g then
		data.Guild = Guilds.View(g, player.UserId, os.time())
	end
	return data
end

-- Opens (or refreshes) your guild: touches your "last seen", rolls days/weeks over and checks leader succession.
local function refresh(player, profile, force)
	local pointer = profile.Permanent.Guild
	if pointer == nil then
		-- approved from another server? the user pointer tells
		local id = read("U_" .. player.UserId)
		if type(id) == "string" then
			local g = fetch(id, true)
			if g and g.Members[tostring(player.UserId)] then
				sync(player, profile, g)
				pointer = profile.Permanent.Guild
			end
		end
		if pointer == nil then
			return nil
		end
	end
	local now = os.time()
	local g = fetch(pointer.Id)
	if g == nil then
		sync(player, profile, nil)
		return nil
	end
	local me = g.Members[tostring(player.UserId)]
	if me == nil then
		sync(player, profile, nil)
		return nil
	end
	local stale = force or now - me.LastSeen > TOUCH_SECONDS or g.Missions.Day ~= math.floor(now / Config.Day)
		or not g.Raid or g.Raid.Week ~= (math.floor(now / Config.Day) + 3) // 7
		or now - (g.Members[tostring(g.Leader)] or { LastSeen = 0 }).LastSeen >= Config.InactiveDays * Config.Day
	if stale then
		local ok, fresh = change(pointer.Id, function(doc)
			Guilds.Touch(doc, player.UserId, now, info(player, profile))
			Guilds.Roll(doc, now)
			Guilds.CheckSuccession(doc, now)
			return doc, { true, doc }
		end)
		if ok then
			g = fetch(pointer.Id, true) or fresh
		end
	end
	if g and g.Members[tostring(player.UserId)] then
		sync(player, profile, g)
		lastTouch[player.UserId] = os.clock()
		return g
	end
	sync(player, profile, nil)
	return nil
end

function GuildService.State(player, profile)
	local g = refresh(player, profile, false)
	return true, stateFor(player, profile, g)
end

local function reply(player, profile, ok, extra)
	local g = if profile.Permanent.Guild then fetch(profile.Permanent.Guild.Id, true) else nil
	if g then
		sync(player, profile, g)
	end
	local data = stateFor(player, profile, g)
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			data[k] = v
		end
	end
	return ok, data
end

---------------------------------------------------------------- actions
function GuildService.Create(player, profile, name, tag, open)
	if profile.Permanent.Guild then
		return false, "AlreadyInGuild"
	end
	if profile.Season.Level < Config.CreateMinLevel then
		return false, "LevelTooLow"
	end
	if profile.Season.Currencies.Gold < Config.CreateGold then
		return false, "NotEnoughGold"
	end
	local cleanName, why = Guilds.CleanName(name)
	if not cleanName then
		return false, why
	end
	local cleanTag, why2 = Guilds.CleanTag(tag)
	if not cleanTag then
		return false, why2
	end
	local safeName = filtered(cleanName, player)
	if safeName ~= cleanName then
		return false, "Inappropriate"
	end
	local id = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 10)
	local claim = mutate("N_" .. cleanName:lower():gsub(" ", "_"), function(old)
		if old ~= nil then
			return nil, { false, "NameTaken" }
		end
		return id, { true }
	end)
	if claim == nil or not claim[1] then
		return false, claim and claim[2] or "Unavailable"
	end
	local g = Guilds.New(id, cleanName, cleanTag, player.UserId, info(player, profile), os.time())
	g.Open = open ~= false
	Guilds.Roll(g, os.time())
	mutate("G_" .. id, function() return g, { true } end)
	mutate("U_" .. player.UserId, function() return id, { true } end)
	profile.Season.Currencies.Gold -= Config.CreateGold
	dirty[id] = true
	cache[id] = nil
	sync(player, profile, fetch(id, true))
	return reply(player, profile, true)
end

function GuildService.Join(player, profile, id)
	if profile.Permanent.Guild then
		return false, "AlreadyInGuild"
	end
	if type(id) ~= "string" or #id > 20 then
		return false, "BadArgs"
	end
	local ok, result = change(id, function(g)
		local good, what = Guilds.Join(g, player.UserId, info(player, profile), os.time())
		if not good then
			return nil, { false, what }
		end
		return g, { true, what }
	end)
	if not ok then
		return false, result
	end
	if result == "Joined" then
		mutate("U_" .. player.UserId, function() return id, { true } end)
		sync(player, profile, fetch(id, true))
	end
	return reply(player, profile, true, { Joined = result })
end

local function myId(profile)
	return profile.Permanent.Guild and profile.Permanent.Guild.Id
end

function GuildService.Leave(player, profile)
	local id = myId(profile)
	if not id then
		return false, "NotInGuild"
	end
	GuildService.Flush(player, profile, true)
	local ok, result = change(id, function(g)
		local good, why = Guilds.Leave(g, player.UserId, os.time())
		if not good then
			return nil, { false, why }
		end
		if Guilds.IsEmpty(g) then
			g.Disbanded = true
		end
		return g, { true, g.Disbanded and g.Name or nil }
	end)
	if not ok then
		return false, result
	end
	if result then -- the guild ended: free the name
		remove("N_" .. result:lower():gsub(" ", "_"))
	end
	remove("U_" .. player.UserId)
	sync(player, profile, nil)
	return reply(player, profile, true)
end

local function onMember(player, profile, method, ...)
	local id = myId(profile)
	if not id then
		return false, "NotInGuild"
	end
	local args = table.pack(...)
	local ok, result = change(id, function(g)
		local good, why = Guilds[method](g, player.UserId, table.unpack(args, 1, args.n))
		if not good then
			return nil, { false, why }
		end
		return g, { true, why }
	end)
	if not ok then
		return false, result
	end
	return reply(player, profile, true)
end

function GuildService.Kick(player, profile, userId)
	if type(userId) ~= "number" then
		return false, "BadArgs"
	end
	local ok, data = onMember(player, profile, "Kick", userId, os.time())
	if ok then
		mutate("U_" .. userId, function() return nil, { true } end)
		remove("U_" .. userId)
	end
	return ok, data
end

function GuildService.SetRank(player, profile, userId, rank)
	if type(userId) ~= "number" or type(rank) ~= "string" then
		return false, "BadArgs"
	end
	return onMember(player, profile, "SetRank", userId, rank)
end

function GuildService.Transfer(player, profile, userId)
	if type(userId) ~= "number" then
		return false, "BadArgs"
	end
	return onMember(player, profile, "TransferLeader", userId, os.time())
end

function GuildService.Approve(player, profile, userId, accept)
	if type(userId) ~= "number" then
		return false, "BadArgs"
	end
	local ok, data = onMember(player, profile, "Approve", userId, accept == true, os.time())
	if ok and accept == true then
		mutate("U_" .. userId, function() return profile.Permanent.Guild.Id, { true } end)
	end
	return ok, data
end

function GuildService.SetInfo(player, profile, fields)
	if type(fields) ~= "table" then
		return false, "BadArgs"
	end
	local desc = nil
	if fields.Desc ~= nil then
		desc = filtered(tostring(fields.Desc):sub(1, Config.DescMax), player)
		if desc == nil then
			return false, "Inappropriate"
		end
	end
	return onMember(player, profile, "SetInfo", { Desc = desc, Open = fields.Open, MinLevel = fields.MinLevel })
end

function GuildService.Buy(player, profile, upgradeId)
	if type(upgradeId) ~= "string" then
		return false, "BadArgs"
	end
	return onMember(player, profile, "Buy", upgradeId)
end

function GuildService.ClaimMission(player, profile, kind, index)
	local id = myId(profile)
	if not id then
		return false, "NotInGuild"
	end
	if (kind ~= "Daily" and kind ~= "Weekly") or type(index) ~= "number" then
		return false, "BadArgs"
	end
	GuildService.Flush(player, profile, true)
	local ok, reward = change(id, function(g)
		local good, result = Guilds.ClaimMission(g, player.UserId, kind, index, os.time())
		if not good then
			return nil, { false, result }
		end
		return g, { true, result }
	end)
	if not ok then
		return false, reward
	end
	applyReward(profile, reward)
	return reply(player, profile, true, { Reward = reward })
end

---------------------------------------------------------------- the raid
function GuildService.RaidChallenge(player, profile, team, playFight)
	local id = myId(profile)
	if not id then
		return false, "NotInGuild"
	end
	local g = fetch(id, true)
	if g == nil or g.Members[tostring(player.UserId)] == nil then
		return false, "NotMember"
	end
	local now = os.time()
	Guilds.Roll(g, now)
	if g.Raid.Defeated then
		return false, "Defeated"
	end
	if Guilds.RaidAttempts(g, player.UserId, now) <= 0 then
		return false, "NoAttempts"
	end
	local boss
	for _, b in ipairs(Config.Raid.Bosses) do
		if b.Id == g.Raid.BossId then
			boss = b
		end
	end
	if boss == nil then
		return false, "NoRaid"
	end
	local members = { { Id = tostring(player.UserId), Name = player.Name, Profile = profile } }
	for _, mate in ipairs(team or {}) do
		table.insert(members, { Id = mate.Id, Name = mate.Name, Snapshot = mate.Snapshot })
	end
	local damage, _, fight = Bosses.Challenge(members, boss, profile.Season.HighestStage, math.random(1, 1e9), true)
	local ok, result = change(id, function(doc)
		local good, res = Guilds.RaidHit(doc, player.UserId, damage, os.time())
		if not good then
			return nil, { false, res }
		end
		return doc, { true, res }
	end)
	if not ok then
		return false, result
	end
	Quests.Record(profile, "Raid", 1)
	GuildService.Flush(player, profile, true)
	if fight and playFight then
		playFight(fight, boss.Name, result.Damage)
	end
	return reply(player, profile, true, { Damage = result.Damage, Defeated = result.Defeated })
end

function GuildService.RaidClaim(player, profile, which)
	local id = myId(profile)
	if not id then
		return false, "NotInGuild"
	end
	if which ~= "Current" and which ~= "Prev" then
		return false, "BadArgs"
	end
	local ok, reward = change(id, function(g)
		local good, result = Guilds.RaidClaim(g, player.UserId, which, os.time())
		if not good then
			return nil, { false, result }
		end
		return g, { true, result }
	end)
	if not ok then
		return false, reward
	end
	applyReward(profile, reward)
	return reply(player, profile, true, { Reward = reward })
end

---------------------------------------------------------------- guild wish
function GuildService.Wish(player, profile, count)
	if type(count) ~= "number" then
		return false, "BadArgs"
	end
	local ok, data = GuildWish.Wish(profile, count)
	if not ok then
		return false, data
	end
	Quests.Record(profile, "Wish", #data.Results)
	if onChanged then
		onChanged(player)
	end
	return reply(player, profile, true, { Results = data.Results })
end

---------------------------------------------------------------- contributions
-- Send what a player did (queued in Permanent.GuildPending by Quests.Record) to the shared guild.
function GuildService.Flush(player, profile, force)
	local pointer, pending = profile.Permanent.Guild, profile.Permanent.GuildPending
	if pointer == nil or pending == nil or next(pending) == nil then
		return
	end
	if not force and os.clock() - (lastFlush[player.UserId] or 0) < FLUSH_SECONDS then
		return
	end
	lastFlush[player.UserId] = os.clock()
	local sent = table.clone(pending)
	local now = os.time()
	local ok = change(pointer.Id, function(g)
		if g.Members[tostring(player.UserId)] == nil then
			return nil, { false, "NotMember" }
		end
		for event, amount in pairs(sent) do
			Guilds.Contribute(g, player.UserId, event, amount, now)
		end
		Guilds.Touch(g, player.UserId, now, info(player, profile))
		Guilds.CheckSuccession(g, now)
		return g, { true }
	end)
	if ok then
		for event, amount in pairs(sent) do
			local left = (pending[event] or 0) - amount
			pending[event] = if left > 0 then left else nil
		end
	end
end

function GuildService.OnPlayerReady(player, profile)
	task.spawn(function()
		refresh(player, profile, true)
	end)
end

function GuildService.OnPlayerLeaving(player, profile)
	if profile and profile.Permanent.Guild then
		GuildService.Flush(player, profile, true)
	end
	lastTouch[player.UserId], lastFlush[player.UserId] = nil, nil
end

function GuildService.Init(profileGetter, changedCallback)
	getProfile, onChanged = profileGetter, changedCallback
	if not IS_STUDIO then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("DuoQuestGuilds")
		end)
		store = if ok then result else nil
	end
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = getProfile(player)
				if profile and profile.Permanent.Guild then
					GuildService.Flush(player, profile, false)
				end
			end
			flushDirectory()
		end
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = getProfile(player)
			if profile and profile.Permanent.Guild then
				GuildService.Flush(player, profile, true)
			end
		end
	end)
end

return GuildService
