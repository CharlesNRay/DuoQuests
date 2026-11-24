--[[
	DataServiceTests (ModuleScript): the real Services/DataService, headless, against a fake DataStore that behaves like
	Roblox's (values go through a JSON-style copy, tables a DataStore cannot hold make the call fail, calls can be made
	to fail). Two (or three) fake servers share the store, so it plays out what live players do: join, play, leave,
	rejoin on another server, open the game twice, a server that crashes, Roblox hiccups, old saves being upgraded.

	Headless only: tools/sim/sync.py builds DataServiceSim.luau (DataService as a factory taking game/task/warn/os);
	run from tools/sim/runners/extra.luau as require("./DataServiceTests")(m) with m.DataServiceSim set.
]]
return function(modulesOverride)
	local m = modulesOverride
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end
	print("Running DataServiceTests...")
	local DS = m.DataSafety
	local Template = m.ProfileTemplate

	-- one clock for every fake server (os.time); task.wait moves it on
	local now = 1800000000
	local fakeOs = setmetatable({ time = function() return math.floor(now) end }, { __index = os })
	local onWait = nil -- a test can make something happen "meanwhile" (another server finishing its save)
	local fakeTask = {
		wait = function(s)
			now += (s or 0.03)
			if onWait then
				local fn = onWait
				onWait = nil
				fn()
			end
			return s
		end,
		-- runs at once; the autosave loop (spawned with no arguments) is skipped and driven by hand (SaveNow) here
		spawn = function(fn, ...)
			if select("#", ...) > 0 then
				fn(...)
			end
		end,
	}
	local logs = {}
	local function fakeWarn(text)
		table.insert(logs, tostring(text))
	end

	-- the fake DataStore: JSON-like copies in and out, refuses what Roblox would refuse
	local stored = {}
	local failCalls = 0
	local calls = 0
	local userIdsSeen = {}
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in pairs(v) do
			out[k] = copy(x)
		end
		return out
	end
	local store = {}
	function store:UpdateAsync(key, transform)
		calls += 1
		if failCalls > 0 then
			failCalls -= 1
			error("502: API Services rejected request (fake)")
		end
		local result, userIds = transform(copy(stored[key]))
		if result == nil then
			return nil -- cancelled: nothing written
		end
		local problems = DS.Problems(result, 1)
		if #problems > 0 then
			error("104: Cannot store value in data store (" .. problems[1] .. ")")
		end
		if #DS.Problems(result) == 0 and DS.Size(result) > DS.LIMIT then
			error("105: Serialized value exceeds 4MB limit")
		end
		userIdsSeen[key] = userIds
		stored[key] = copy(result)
		return copy(result)
	end
	function store:GetAsync(key)
		return copy(stored[key])
	end

	local function newServer(jobId)
		local closers = {}
		local players = {}
		local fakeGame = {
			JobId = jobId,
			BindToClose = function(_, fn) table.insert(closers, fn) end,
		}
		local services = {
			DataStoreService = { GetDataStore = function() return store end },
			Players = { GetPlayerByUserId = function(_, id) return players[id] end },
			ReplicatedStorage = { WaitForChild = function() return {} end },
			RunService = { IsStudio = function() return false end },
		}
		function fakeGame:GetService(name)
			return services[name]
		end
		local service = m.DataServiceSim(fakeGame, fakeTask, fakeWarn, fakeOs)
		service.Init()
		local server = { Service = service, Players = players, JobId = jobId }
		function server.Join(userId)
			local player = { UserId = userId, Parent = {}, Kick = function(self, msg) self.Kicked = msg end }
			players[userId] = player
			local profile, reason = service.LoadProfile(player)
			return profile, reason, player
		end
		function server.Leave(player)
			service.ReleaseProfile(player)
			player.Parent = nil
			players[player.UserId] = nil
		end
		function server.Shutdown()
			for _, fn in ipairs(closers) do
				fn()
			end
		end
		return server
	end

	local A = newServer("server-A")
	local B = newServer("server-B")
	local KEY = "Player_101"

	-- 1. a new player
	local p, reason, playerA = A.Join(101)
	check("A new player gets a fresh profile", p ~= nil and reason == nil and p.SchemaVersion == Template.CURRENT_VERSION)
	check("The record is locked to the server they are on", stored[KEY] and stored[KEY].SessionLock and stored[KEY].SessionLock.JobId == "server-A")
	check("Each write names the player (for data-removal requests)", userIdsSeen[KEY] and userIdsSeen[KEY][1] == 101)

	-- 2. play, autosave, leave
	p.Season.Level = 12
	p.Season.HighestStage = 15
	p.Season.Currencies.Gold = 123456
	check("An autosave works mid-visit", A.Service.SaveNow(playerA) == true and stored[KEY].Data.Season.Level == 12)
	p.Season.Level = 13
	A.Leave(playerA)
	check("Leaving saves the latest progress", stored[KEY].Data.Season.Level == 13 and stored[KEY].Data.Season.Currencies.Gold == 123456)
	check("Leaving releases the lock", stored[KEY].SessionLock == nil)
	check("Logout time is kept", type(stored[KEY].Data.Meta.LastLogoutAt) == "number")

	-- 3. rejoin, on another server
	local p2, _, playerB = B.Join(101)
	check("Rejoining (another server) brings everything back", p2 ~= nil and p2.Season.Level == 13 and p2.Season.HighestStage == 15 and p2.Season.Currencies.Gold == 123456)

	-- 4. the same account opens a second server while the first still has them
	local before = now
	local p3, reason3 = A.Join(101)
	check("A second server cannot open a profile that is in use", p3 == nil and reason3 == "SessionLocked")
	check("...it waited for the other server first (~18 s), then gave up", now - before >= 15 and now - before < 60)
	check("...and did not touch the saved data", stored[KEY].SessionLock.JobId == "server-B" and stored[KEY].Data.Season.Level == 13)

	-- 5. server B crashes (no release); after the lock goes stale the player can join elsewhere
	p2.Season.Level = 20 -- progress since the last save is lost in a crash
	now += 301
	local p4, _, playerA2 = A.Join(101)
	check("After a crash the player gets in again once the lock is old (5 min)", p4 ~= nil and p4.Season.Level == 13)
	check("...with only the progress since the last save lost", stored[KEY].SessionLock.JobId == "server-A")
	-- the crashed server comes back to life and tries to save its old copy
	logs = {}
	local saved = B.Service.SaveNow(playerB)
	check("A server that lost the lock never overwrites the newer data", saved == false and stored[KEY].Data.Season.Level == 13)
	check("...and kicks its stale copy of the player", playerB.Kicked ~= nil)
	check("...saying why in the output", logs[1] ~= nil and logs[1]:find("Lost session lock") ~= nil)
	p4.Season.Level = 14
	A.Leave(playerA2)
	check("The live server's progress is what is kept", stored[KEY].Data.Season.Level == 14)

	-- 5b. a teleport (joining a party by code): the new server asks while the old one is still saving the player
	local pg, _, plg = A.Join(101) -- on the old server
	pg.Season.Level = 15
	local H = newServer("server-H")
	onWait = function()
		A.Leave(plg) -- the old server finishes its save while the new one waits
	end
	local ph, reasonh, plh = H.Join(101)
	check("Teleporting to a party: the new server waits for the old save, then loads it", ph ~= nil and reasonh == nil and ph.Season.Level == 15)
	H.Leave(plh)

	-- 6. Roblox hiccups: a call fails now and then
	local p5, _, pl5 = A.Join(101)
	p5.Season.Level = 15
	failCalls = 2
	check("Two failed calls in a row: the save still lands (3 tries)", A.Service.SaveNow(pl5) == true and stored[KEY].Data.Season.Level == 15)
	failCalls = 3
	p5.Season.Level = 16
	logs = {}
	check("Three failures: the save reports failure, nothing is lost from memory", A.Service.SaveNow(pl5) == false and A.Service.GetProfile(pl5).Season.Level == 16)
	check("...and the output says so", #logs >= 3 and logs[1]:find("attempt 1/3") ~= nil)
	A.Leave(pl5)
	check("The next save (leaving) catches up", stored[KEY].Data.Season.Level == 16 and stored[KEY].SessionLock == nil)
	failCalls = 5
	local p6, reason6 = A.Join(101)
	check("Joining while the DataStore is down: refused (the player is told to rejoin), no fresh profile", p6 == nil and reason6 == "DataStoreError")
	failCalls = 0
	check("...and the saved profile is untouched", stored[KEY].Data.Season.Level == 16)

	-- 7. a value a DataStore cannot hold: the save fails (as on Roblox) and the output names it
	local p7, _, pl7 = A.Join(101)
	p7.Season.Level = 17
	p7.Season.BadTable = { [1] = "a", [3] = "c" }
	logs = {}
	check("A gappy table makes the save fail, like on Roblox", A.Service.SaveNow(pl7) == false and stored[KEY].Data.Season.Level == 16)
	local named = false
	for _, line in ipairs(logs) do
		if line:find("cannot be saved as is") and line:find("BadTable") then
			named = true
		end
	end
	check("...and the output names the bad field", named)
	p7.Season.BadTable = nil
	A.Leave(pl7)
	check("Fixed: the next save works", stored[KEY].Data.Season.Level == 17)

	-- 8. an old save (schema v3) is upgraded on load. (A v3 save with number-keyed milestones never reached a live
	-- DataStore: that save failed. The ledger is empty here; Studio's memory store did hold such tables, and the v4
	-- step converts those: checked with the migration on its own below.)
	local old = Template.New()
	old.SchemaVersion = 3
	old.Season.Level = 30
	old.Season.StageRewardsClaimed = {}
	old.Season.Equipment.Inventory = nil -- as if the field was added in a later update
	stored["Player_202"] = { Data = old } -- written before the fix, as plain JSON would have refused; seeded directly
	local p8, _, pl8 = B.Join(202)
	check("An old save loads and is upgraded", p8 ~= nil and p8.SchemaVersion == Template.CURRENT_VERSION and p8.Season.Level == 30)
	p8.Season.StageRewardsClaimed["10"] = true
	check("...and it saves", B.Service.SaveNow(pl8) == true)
	check("Fields added since are filled in", p8 and type(p8.Season.Equipment.Inventory) == "table")
	B.Leave(pl8)

	-- 9. a save from a NEWER version of the game (a rollback) is never loaded or overwritten
	local newer = Template.New()
	newer.SchemaVersion = Template.CURRENT_VERSION + 1
	newer.Season.Level = 40
	stored["Player_303"] = { Data = newer }
	local p9, reason9 = A.Join(303)
	check("A newer save is refused after a rollback", p9 == nil and reason9 == "NewerSchema")
	check("...and left as it was", stored["Player_303"].Data.Season.Level == 40 and stored["Player_303"].Data.SchemaVersion == Template.CURRENT_VERSION + 1)

	-- 10. the server shuts down (an update, or the last player left): everyone is saved and released
	local C = newServer("server-C")
	local pa, _, ua = C.Join(401)
	local pb, _, ub = C.Join(402)
	pa.Season.Level, pb.Season.Level = 5, 7
	C.Shutdown()
	check("Server shutdown saves everyone", stored["Player_401"].Data.Season.Level == 5 and stored["Player_402"].Data.Season.Level == 7)
	check("...and releases them, so they can join a new server at once", stored["Player_401"].SessionLock == nil and stored["Player_402"].SessionLock == nil)
	local _ = ua and ub

	-- 11. a player who leaves while their data is still loading
	local D = newServer("server-D")
	local leaver = { UserId = 501, Parent = nil, Kick = function() end }
	local pd, reasond = D.Service.LoadProfile(leaver)
	check("Leaving during the load: nothing is kept locked", pd == nil and reasond == "PlayerLeft" and stored["Player_501"] and stored["Player_501"].SessionLock == nil)

	-- 12. a well-played profile round-trips through the store unchanged
	local E = newServer("server-E")
	local pe, _, ue = E.Join(601)
	pe.Season.Level = 40
	for stage = 1, 60 do
		pcall(m.Progression.ApplyClear, pe, stage, function() return 0.5 end)
		if stage % 10 == 0 then
			pcall(m.StageRewards.Claim, pe, stage)
		end
	end
	for _ = 1, 20 do
		pcall(m.Gear.Grant, pe, 50)
	end
	m.Talents.AutoSpend(pe)
	local gearCount = #pe.Season.Equipment.Inventory
	E.Leave(ue)
	local F = newServer("server-F")
	local pf = F.Join(601)
	check("A well-played profile comes back after leave + rejoin", pf ~= nil and pf.Season.Level == pe.Season.Level and pf.Season.HighestStage == pe.Season.HighestStage)
	check("...gear, talents and claimed milestones included", pf and #pf.Season.Equipment.Inventory == gearCount and next(pf.Season.StageRewardsClaimed or {}) ~= nil)
	check(("Calls to the DataStore stay modest (%d for this whole test)"):format(calls), calls < 200)

	print(("DataServiceTests done: %d passed, %d failed"):format(passed, failed))
end
