--[[
	GuildTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > GuildTests

	Pure guild logic: members, succession, missions, upgrades, raid.   require(...GuildTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Guilds = require(Shared.Guilds) }
	end
	local Guilds = m.Guilds
	local Config = Guilds.Config
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			(warn or print)("  FAIL  " .. name)
		end
	end
	print("GuildTests")

	local DAY = 86400
	local t0 = 1000 * DAY + 3600
	local function info(name, level, frontier) return { Name = name, Level = level or 20, Frontier = frontier or 10 } end
	local g = Guilds.New("g1", "Cool Guild", "COOL", 1, info("Leader"), t0)
	check("leader is a member", Guilds.Rank(g, 1) == "Leader")
	check("names validated", Guilds.CleanName("  Hi  ") == nil and Guilds.CleanName("Nice Name") == "Nice Name" and Guilds.CleanName("bad!name") == nil)
	check("tags validated", Guilds.CleanTag("ab") == "AB" and Guilds.CleanTag("abcde") == nil and Guilds.CleanTag("a_b") == nil)

	for i = 2, 6 do
		check("join " .. i, Guilds.Join(g, i, info("P" .. i), t0))
	end
	check("six members", Guilds.Count(g) == 6)
	check("already member", select(2, Guilds.Join(g, 2, info("P2"), t0)) == "AlreadyMember")
	g.Open = false
	local ok, why = Guilds.Join(g, 50, info("Req", 5), t0)
	check("closed guild takes a request", ok and why == "Requested" and g.Requests["50"] ~= nil)
	check("member cannot approve", select(2, Guilds.Approve(g, 2, 50, true, t0)) == "NotAllowed")
	check("leader approves", Guilds.Approve(g, 1, 50, true, t0) and Guilds.Rank(g, 50) == "Member")
	g.MinLevel = 30
	check("min level enforced", select(2, Guilds.Join(g, 60, info("Low", 5), t0)) == "LevelTooLow")
	g.MinLevel = 1

	-- ranks, kick, leave
	check("only leader promotes", not Guilds.SetRank(g, 2, 3, "Officer") and Guilds.SetRank(g, 1, 2, "Officer") and Guilds.SetRank(g, 1, 3, "Officer"))
	check("officer kicks member", Guilds.Kick(g, 2, 50, t0) and g.Members["50"] == nil)
	check("officer cannot kick officer", select(2, Guilds.Kick(g, 2, 3, t0)) == "NotAllowed")
	check("leader cannot leave with others", select(2, Guilds.Leave(g, 1, t0)) == "LeaderCannotLeave")

	-- capacity
	local small = Guilds.New("g2", "Small", "SM", 1, info("L"), t0)
	for i = 2, Config.BaseMembers do
		Guilds.AddMember(small, i, info("x"), t0)
	end
	check("full at base capacity", select(2, Guilds.AddMember(small, 999, info("x"), t0)) == "Full")
	small.Points = 1000
	check("roster upgrade", Guilds.Buy(small, 1, "Roster") and Guilds.Capacity(small) == Config.BaseMembers + 5)

	-- upgrades: only the leader
	g.Points = 100
	check("officer cannot buy", select(2, Guilds.Buy(g, 2, "Attack")) == "NotAllowed")
	local cost = Guilds.UpgradeCost("Attack", 0)
	check("leader buys", Guilds.Buy(g, 1, "Attack") and g.Points == 100 - cost and g.Upgrades.Attack == 1)
	g.Points = 0
	check("not enough points", select(2, Guilds.Buy(g, 1, "Attack")) == "NotEnoughPoints")
	g.Points = 10 ^ 9
	for _ = 1, 40 do
		Guilds.Buy(g, 1, "Attack")
	end
	check("max level", g.Upgrades.Attack == Config.Upgrades.Attack.Max and select(2, Guilds.Buy(g, 1, "Attack")) == "MaxLevel")
	g.Upgrades.XPGain, g.Upgrades.CritChance = 5, 3
	local buffs = Guilds.Buffs(g)
	local atk
	for _, mod in ipairs(buffs.Mods) do
		if mod.Stat == "Attack" then atk = mod end
	end
	check("buffs", atk and math.abs(atk.Value - 0.2) < 1e-9 and atk.Mode == "Mul" and math.abs(buffs.XPGain - 0.05) < 1e-9 and buffs.GoldGain == 0)
	g.Points = 0

	-- missions: collective, claimed per member
	local now = t0 + DAY
	Guilds.Roll(g, now)
	local rows = Guilds.MissionRows(g, 2, "Daily", now)
	check("three daily missions", #rows == 3)
	local row = rows[1]
	check("goal scales", row.Goal >= 3)
	local before = g.Points
	Guilds.Contribute(g, 2, row.Event, row.Goal - 1, now)
	check("not done yet", not Guilds.MissionRows(g, 2, "Daily", now)[1].Done)
	check("cannot claim early", select(2, Guilds.ClaimMission(g, 2, "Daily", 1, now)) == "NotDone")
	Guilds.Contribute(g, 3, row.Event, 5, now)
	check("done by two members", Guilds.MissionRows(g, 2, "Daily", now)[1].Done)
	check("guild earned points", g.Points > before)
	check("member claims", select(1, Guilds.ClaimMission(g, 2, "Daily", 1, now)) == true)
	check("claim once", select(2, Guilds.ClaimMission(g, 2, "Daily", 1, now)) == "AlreadyClaimed")
	check("second contributor claims", select(1, Guilds.ClaimMission(g, 3, "Daily", 1, now)) == true)
	check("non contributor cannot", select(2, Guilds.ClaimMission(g, 4, "Daily", 1, now)) == "NoShare")
	local earned = g.Earned
	Guilds.Contribute(g, 2, row.Event, 99, now)
	check("points not paid twice", g.Earned == earned)
	-- next day resets
	Guilds.Roll(g, now + DAY)
	check("new day resets", Guilds.MissionRows(g, 2, "Daily", now + DAY)[1].Progress == 0)

	-- succession
	local s = Guilds.New("g3", "Succ", "SU", 1, info("Boss"), t0)
	for i = 2, 5 do
		Guilds.AddMember(s, i, info("M" .. i), t0)
	end
	Guilds.SetRank(s, 1, 3, "Officer")
	s.Members["2"].Gave = 500
	local later = t0 + 4 * DAY
	Guilds.Touch(s, 2, later)
	check("leader away 4 days: no change", Guilds.CheckSuccession(s, later) == nil and s.Leader == 1)
	later = t0 + 6 * DAY
	-- officer 3 is inactive, member 2 (most given) was seen, so 3 is skipped
	Guilds.Touch(s, 2, later)
	Guilds.Touch(s, 5, later)
	check("inactive officer skipped", Guilds.CheckSuccession(s, later) == 2 and s.Leader == 2)
	check("old leader demoted", Guilds.Rank(s, 1) == "Member" and Guilds.Rank(s, 2) == "Leader")
	-- nobody active: keeps the leader, checks again later
	local n = Guilds.New("g4", "Quiet", "QT", 1, info("Boss"), t0)
	Guilds.AddMember(n, 2, info("M"), t0)
	check("nobody qualifies", Guilds.CheckSuccession(n, t0 + 10 * DAY) == nil and n.Leader == 1)
	Guilds.Touch(n, 2, t0 + 10 * DAY)
	check("later check passes it on", Guilds.CheckSuccession(n, t0 + 10 * DAY) == 2)
	-- officer preferred
	local o = Guilds.New("g5", "Off", "OF", 1, info("Boss"), t0)
	Guilds.AddMember(o, 2, info("A"), t0)
	Guilds.AddMember(o, 3, info("B"), t0)
	o.Members["2"].Gave = 999
	Guilds.SetRank(o, 1, 3, "Officer")
	Guilds.Touch(o, 2, t0 + 6 * DAY)
	Guilds.Touch(o, 3, t0 + 6 * DAY)
	check("officer outranks contributor", Guilds.CheckSuccession(o, t0 + 6 * DAY) == 3)

	-- raid
	local r = Guilds.New("g6", "Raiders", "RD", 1, info("Boss", 30, 20), t0)
	for i = 2, 4 do
		Guilds.AddMember(r, i, info("R" .. i, 30, 20), t0)
	end
	local day = t0 + 2 * DAY
	for i = 1, 4 do
		Guilds.Touch(r, i, day)
	end
	Guilds.Roll(r, day)
	check("raid has health", r.Raid.Health > 0 and r.Raid.Health == r.Raid.MaxHealth)
	check("three attempts", Guilds.RaidAttempts(r, 1, day) == 3)
	for _ = 1, 3 do
		check("hit", Guilds.RaidHit(r, 1, 1000, day))
	end
	check("no attempts left", select(2, Guilds.RaidHit(r, 1, 1000, day)) == "NoAttempts")
	check("attempts reset next day", Guilds.RaidAttempts(r, 1, day + DAY) == 3)
	check("damage recorded", r.Raid.Dealt["1"] == 3000 and r.Raid.Health == r.Raid.MaxHealth - 3000)
	check("outsider cannot hit", select(2, Guilds.RaidHit(r, 77, 1, day)) == "NotMember")
	check("cannot claim before it ends", select(2, Guilds.RaidClaim(r, 1, "Current", day)) == "NotOver")
	local pointsBefore = r.Points
	r.Raid.Health = 500
	local okHit, res = Guilds.RaidHit(r, 2, 10 ^ 9, day)
	check("kills the boss", okHit and res.Defeated and r.Raid.Health == 0 and res.Damage == 500 and r.Points == pointsBefore + Config.Raid.DefeatPoints)
	check("cannot hit a dead boss", select(2, Guilds.RaidHit(r, 3, 1, day)) == "Defeated")
	local okC, reward = Guilds.RaidClaim(r, 1, "Current", day)
	check("claims by share", okC and reward.Marks > 0 and reward.Defeated)
	check("claim once", select(2, Guilds.RaidClaim(r, 1, "Current", day)) == "AlreadyClaimed")
	check("no share no reward", select(2, Guilds.RaidClaim(r, 3, "Current", day)) == "NoShare")
	-- next week: new boss, old one claimable
	local nextWeek = day + 7 * DAY
	Guilds.Roll(r, nextWeek)
	check("new raid next week", not r.Raid.Defeated and r.Prev ~= nil and r.Raid.Week == r.Prev.Week + 1)
	check("previous raid claimable", select(1, Guilds.RaidClaim(r, 2, "Prev", nextWeek)) == true)

	-- view
	local view = Guilds.View(g, 1, now)
	check("view", view.Name == "Cool Guild" and #view.Members >= 6 and #view.Upgrades == #Config.UpgradeOrder and view.Raid.Attempts == 3)
	check("summary", Guilds.Summary(g, now).Count == Guilds.Count(g))

	-- every raid boss can be fought
	if m.Bosses and m.ProfileTemplate and m.Enemies then
		for _, boss in ipairs(Config.Raid.Bosses) do
			local def = m.Enemies[boss.DefId]
			check(boss.Id .. " has a definition", def ~= nil and def.EventOnly == true)
			local prof = m.ProfileTemplate.New()
			local dmg, secs = m.Bosses.Challenge({ { Id = "1", Name = "A", Profile = prof } }, boss, 5, 7)
			check(boss.Id .. " fight runs", dmg > 0 and secs > 0)
		end
	end
	-- guild buffs reach the combat mod list and the clear rewards
	if m.Pets and m.ProfileTemplate then
		local prof = m.ProfileTemplate.New()
		local before = #m.Pets.Collection(prof).Mods
		prof.Permanent.GuildBuffs = Guilds.Buffs(g)
		check("guild mods join the pet collection mods", #m.Pets.Collection(prof).Mods == before + #prof.Permanent.GuildBuffs.Mods)
	end
	if m.Quests and m.ProfileTemplate then
		local prof = m.ProfileTemplate.New()
		m.Quests.Record(prof, "Clear", 1, t0)
		check("no guild: nothing queued", prof.Permanent.GuildPending == nil or next(prof.Permanent.GuildPending) == nil)
		prof.Permanent.Guild = { Id = "g1" }
		m.Quests.Record(prof, "Clear", 2, t0)
		check("guild: contributions queued", prof.Permanent.GuildPending.Clear == 2)
	end

	if m.GuildWish and m.ProfileTemplate then
		local GW = m.GuildWish
		local prof = m.ProfileTemplate.New()
		check("needs a guild", select(2, GW.Wish(prof, 1)) == "NotInGuild")
		prof.Permanent.Guild = { Id = "g1" }
		check("needs marks", select(2, GW.Wish(prof, 1)) == "NotEnoughMarks")
		check("bad count", select(2, GW.Wish(prof, 3)) == "BadArgs")
		prof.Permanent.GuildMarks = 10 ^ 6
		local seen, rarities = {}, {}
		for i = 1, 40 do
			local ok, data = GW.Wish(prof, 10)
			for _, row in ipairs(data.Results) do
				seen[row.Id] = true
				rarities[row.Rarity] = (rarities[row.Rarity] or 0) + 1
				check("guild pet only", m.PetConfig.Defs[row.Id].Guild == true and m.PetConfig.Defs[row.Id].Wish ~= true)
			end
		end
		check("spends marks", prof.Permanent.GuildMarks == 10 ^ 6 - 40 * 10 * Guilds.Config.Wish.Cost)
		local count = 0
		for _ in pairs(seen) do count += 1 end
		check("whole pool reachable", count == #GW.Info(prof).Pool)
		check("all rarities appear", rarities.Rare and rarities.Epic and rarities.Legendary)
		check("owned after wishing", prof.Permanent.Pets[GW.Info(prof).Pool[1].Id] == true)
		-- pity: a rigged all-Rare roll still gives Epic+ by the pity count
		local p2 = m.ProfileTemplate.New()
		p2.Permanent.Guild, p2.Permanent.GuildMarks = { Id = "g" }, 10 ^ 6
		local best = 0
		local calls = 0
		local rig = function() calls += 1 return 0.99 end
		for i = 1, Guilds.Config.Wish.PityEpic do
			local _, d = GW.Wish(p2, 1, rig)
			local rank = ({ Rare = 2, Epic = 3, Legendary = 4 })[d.Results[1].Rarity]
			best = math.max(best, rank)
		end
		check("epic pity", best >= 3)
	end

	-- guild chat (2026-11-22)
	local cg = Guilds.New("gc", "Chatty", "CHAT", 1, info("Talker"), t0)
	check("A member can post to guild chat", Guilds.Chat(cg, 1, "hello guild", t0) == true and #cg.Chat == 1 and cg.Chat[1].Name == "Talker")
	check("A stranger cannot post", select(2, Guilds.Chat(cg, 999, "hi", t0)) == "NotInGuild")
	check("An empty message is refused", select(2, Guilds.Chat(cg, 1, "   ", t0)) == "Empty")
	for i = 1, 40 do Guilds.Chat(cg, 1, "msg " .. i, t0 + i) end
	check("Chat keeps only the newest messages", #cg.Chat == Config.ChatKeep and cg.Chat[#cg.Chat].Text == "msg 40")
	Guilds.Chat(cg, 1, string.rep("x", 500), t0 + 50)
	check("A long message is cut to ChatMax", #cg.Chat[#cg.Chat].Text == Config.ChatMax)
	check("The guild view carries the chat", #Guilds.View(cg, 1, t0 + 60).Chat == Config.ChatKeep)

	print(("GuildTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
