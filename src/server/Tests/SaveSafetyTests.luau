--[[
	SaveSafetyTests (ModuleScript): a well-played profile can be stored in a DataStore (Util/DataSafety): no mixed or
	gappy tables, no NaN, well under the 4 MB limit. Headless: tools/sim/runners/extra.luau.
	The balance bot (tools/sim/abl.sh) also checks every profile it plays for hours: look for SAVECHECK lines.
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
	print("Running SaveSafetyTests...")
	local DS = m.DataSafety

	-- the checker itself
	check("A clean table passes", #DS.Problems({ A = 1, B = { 1, 2, 3 }, C = { X = "y" } }) == 0)
	check("A gappy number-keyed table is caught", #DS.Problems({ Slots = { [1] = "a", [3] = "c" } }) == 1)
	check("Mixed keys are caught", #DS.Problems({ T = { [1] = "a", Name = "b" } }) == 1)
	check("NaN is caught", #DS.Problems({ N = 0 / 0 }) == 1)
	check("A function is caught", #DS.Problems({ F = function() end }) == 1)

	-- a profile that has done a bit of everything
	local profile = m.ProfileTemplate.New()
	local rng = 7
	local function rand()
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng / 2147483648
	end
	profile.Season.Level = 40
	for stage = 1, 80 do
		pcall(m.Progression.ApplyClear, profile, stage, rand)
		if m.StageRewards and stage % 10 == 0 then
			pcall(m.StageRewards.Claim, profile, stage)
		end
	end
	for _ = 1, 30 do
		pcall(m.Gear.Grant, profile, 60)
	end
	for _, id in ipairs({ "Attack", "Haste", "CritChance" }) do
		pcall(m.Runes.Grant, profile, id, "Rare", 2)
	end
	m.Talents.AutoSpend(profile)
	local day = 20500
	for _, id in ipairs(m.Errands.Offered(day)) do
		local def = m.Errands.Def(id)
		m.Errands.Interact(profile, def.Giver, day * 86400, function() return 1 end)
		for _, step in ipairs(def.Steps) do
			m.Errands.Interact(profile, if step.Spot == "Cat" then "Cat1" else step.Spot, day * 86400, function() return 1 end)
		end
	end
	local cast = m.Fishing.Cast(10, rand)
	for _ = 1, 5 do
		local good = (cast.Zone + 30) / m.FishingConfig.Speed
		m.Fishing.Reel(profile, cast, cast.BiteAt + good, day, rand, good)
	end
	for n = 1, 4 do
		m.TownLeisure.TakeRelic(profile, "Relic" .. n)
	end
	m.TownLeisure.PetPlay(profile, day)
	m.Sparring.Record(profile, true, day)
	m.Sparring.Record(profile, false, day)
	profile.Permanent.Settings = { Master = 0.5, Music = 0.3, Effects = 1, Interface = 0.8 }
	pcall(m.Daily.Claim, profile, day * 86400)
	local problems = DS.Problems(profile)
	for _, p in ipairs(problems) do
		print("    " .. p)
	end
	check("A well-played profile is DataStore-safe", #problems == 0)
	local size = DS.Size(profile)
	check(("It is far under the 4 MB limit (%d characters)"):format(size), size < DS.LIMIT / 20)
	check("A fresh profile is DataStore-safe", #DS.Problems(m.ProfileTemplate.New()) == 0)

	-- a busy guild record (stored in the IPQ_Guilds DataStore)
	if m.Guilds then
		local G = m.Guilds
		local t0 = 1800000000
		local g = G.New("g1", "Testers", "TST", 1, { Name = "Lead", Level = 30, Frontier = 40 }, t0)
		for uid = 2, 6 do
			G.AddMember(g, uid, { Name = "M" .. uid, Level = 20 + uid, Frontier = 30 }, t0)
		end
		G.Join(g, 9, { Name = "Asker", Level = 5 }, t0)
		local now = t0 + 86400
		pcall(G.Roll, g, now)
		local ok, rows = pcall(G.MissionRows, g, 2, "Daily", now)
		if ok and rows and rows[1] then
			G.Contribute(g, 2, rows[1].Event, rows[1].Goal + 5, now)
			G.Contribute(g, 4, rows[1].Event, 3, now)
			pcall(G.ClaimMission, g, 2, "Daily", 1, now)
		end
		pcall(G.RaidHit, g, 3, 12345, now)
		pcall(G.Chat, g, 2, "hello guild", now)
		local gp = DS.Problems(g)
		for _, p in ipairs(gp) do
			print("    guild " .. p)
		end
		check("A busy guild record is DataStore-safe", #gp == 0)
	end

	-- a party record with a live member, a ghost and companions (stored in the party DataStore)
	if m.Party then
		local P = m.Party
		local party = P.NewOpen("p1", 1, 1001, 100)
		local a, b = m.ProfileTemplate.New(), m.ProfileTemplate.New()
		a.Season.Level, b.Season.Level = 25, 22
		pcall(P.AddMember, party, 1002, "Bee", b, 150)
		for t = 1, 3 do
			pcall(P.OnlineTick, party, { { UserId = 1001, Name = "Ay", Profile = a } }, t, 200 + t * 60)
		end
		pcall(P.SetGhostLoadout, party, 1001, 1002, { "Heal" }, 500)
		local pp = DS.Problems(party)
		for _, p in ipairs(pp) do
			print("    party " .. p)
		end
		check("A party record with a ghost and companions is DataStore-safe", #pp == 0)
	end

	print(("SaveSafetyTests done: %d passed, %d failed"):format(passed, failed))
end
