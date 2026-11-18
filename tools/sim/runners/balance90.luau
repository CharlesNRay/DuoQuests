-- Class balance study: an auto-player per class path to a goal level (gear, pets, skills, wishing included), solo or with a partner (see PARTNER).
local m = {
	ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Skills = require("./Skills"), Economy = require("./Economy"),
	Classes = require("./Config/Classes"), Wishing = require("./Wishing"), SkillProgress = require("./SkillProgress"), Subclasses = require("./Subclasses"),
	Gear = require("./Gear"), Pets = require("./Pets"), PetConfig = require("./Config/Pets"), SubclassConfig = require("./Config/Subclasses"),
	Party = require("./Party"),
	Activities = require("./Activities"), TableUtil = require("./Util/TableUtil"),
}
local ARGS = require("./cfg")
local MODE = ARGS[4] or "full"
-- who fights next to the tested hero (the game is played in pairs):
--   "solo"       nobody (the old behaviour; a real lone player always has the companion)
--   "companion"  the starter ghost the server gives a one-player party (Party.SyncCompanion), plus party ultimates
--   <Class>      a second auto-played hero of that class (always plays "full"), plus party ultimates; ARGS[6] = its path
local PARTNER = ARGS[5] or "solo"
local PARTNER_PATH = ARGS[6]
-- seats in a fight (the server fills the empty ones with companions)
local SEATS = ARGS[7] or m.Party.SEATS
local doGear = not (MODE == "lazy" or MODE == "nogear")
local doSkill = not (MODE == "lazy" or MODE == "noskill")
local doPet = not (MODE == "lazy" or MODE == "nopet")
local doGold = not (MODE == "lazy" or MODE == "nogold")
local lcg = 12345
local function rand() lcg = (lcg * 1103515245 + 12345) % 2147483648 return lcg / 2147483648 end

local RARITY_SCORE = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
local function wishAll(profile)
	-- split the Wishstones on hand evenly between pet and skill wishes (pets matter: they add damage and stats)
	local start = profile.Season.Currencies.Wishstones or 0
	for _, kind in ipairs({ "Pet", "Skill" }) do
		if (kind == "Pet" and not doPet) or (kind == "Skill" and not doSkill) then
			profile.Season.Currencies.Wishstones = (profile.Season.Currencies.Wishstones or 0) - math.floor(start / 2) -- this half is simply not spent on progress
			continue
		end
		local floorLeft = start - math.floor(start / 2) -- what must remain after this kind's half is spent... (kind 1 spends half)
		local budget = math.floor(start / 2)
		local spentTotal = 0
		for _ = 1, 200 do
			local info = m.Wishing.Info(profile, kind)
			local pick
			for _, tier in ipairs(info.Tiers) do
				if tier.Unlocked and info.Currency >= tier.Cost and spentTotal + tier.Cost <= math.max(budget, 0) + (if kind == "Skill" then info.Currency else 0) then pick = tier end
			end
			if pick == nil then break end
			local before = info.Currency
			if not m.Wishing.Wish(profile, kind, pick.Id, "Currency", 1, rand) then break end
			spentTotal += before - m.Wishing.Info(profile, kind).Currency
		end
	end
	for abilityId in pairs(if doSkill then profile.Season.OwnedAbilities else {}) do
		m.SkillProgress.Upgrade(profile, abilityId)
		m.SkillProgress.Consume(profile, abilityId, "All")
		local n = 0 while m.SkillProgress.RankUp(profile, abilityId) do n += 1 if n > 50 then error("skill rankup loop") end end
	end
	local best, bestScore = nil, -1
	for petId in pairs(if doPet then (profile.Permanent.Pets or {}) else {}) do
		local n = 0 while m.Pets.RankUp(profile, petId) do n += 1 if n > 50 then error("pet rankup loop") end end
		local def = m.PetConfig.Defs[petId]
		local score = RARITY_SCORE[def.Rarity] * 10 * (def.Power or 1) + m.Pets.Rank(profile, petId)
		if score > bestScore then best, bestScore = petId, score end
	end
	if best then m.Pets.Equip(profile, best) end
end
local function spend(profile, classId)
	local sub = m.Subclasses.Current(profile, classId)
	local progressed = doSkill
	while progressed do
		progressed = false
		for _, id in ipairs(m.Skills.Pool(classId, sub)) do
			if not profile.Season.OwnedAbilities[id] and m.Economy.UnlockAbility(profile, classId, id) then progressed = true break end
		end
	end
	wishAll(profile)
end
local function equipBest(profile, classId)
	-- like a player: wear the owned skills with the highest level first (rank + tier), pool order breaks ties
	local owned = {}
	local sub = m.Subclasses.Current(profile, classId)
	for order, id in ipairs(m.Skills.Pool(classId, sub)) do
		if profile.Season.OwnedAbilities[id] then table.insert(owned, { Id = id, Level = m.SkillProgress.Level(profile.Season, id), Order = order }) end
	end
	table.sort(owned, function(a, b) if a.Level ~= b.Level then return a.Level > b.Level end return a.Order > b.Order end)
	local best = {}
	for i = 1, math.min(#owned, m.Skills.SLOTS) do table.insert(best, owned[i].Id) end
	m.Economy.Equip(profile, classId, best)
end
local function equipGear(profile)
	m.Gear.EquipBest(profile) -- the real "Equip best" button
	local eq = profile.Season.Equipment
	for i = #eq.Inventory, 1, -1 do m.Gear.Sell(profile, eq.Inventory[i].Id) end
end

-- run fn with every upgrade switched on (the partner hero always plays "full", whatever MODE tests on the main hero)
local function asFull(fn)
	local g, s, p, o = doGear, doSkill, doPet, doGold
	doGear, doSkill, doPet, doGold = true, true, true, true
	fn()
	doGear, doSkill, doPet, doGold = g, s, p, o
end

local LAZY = MODE == "lazy"
local function goldSpend(profile, classId)
	-- half the gold trains skill slots, half upgrades worn gear (cheapest first), like a player using the Trainer and the Blacksmith
	local cur = profile.Season.Currencies
	local budget = cur.Gold
	for _ = 1, 60 do
		local did = false
		local levels = profile.Season.SlotLevels[classId] or {}
		local bestSlot, bestCost
		for slot = 1, m.Skills.SLOTS do
			if levels[slot] and levels[slot] < m.Skills.MAX_SLOT_LEVEL then
				local c = m.Economy.SlotLevelCost(levels[slot])
				if bestCost == nil or c < bestCost then bestSlot, bestCost = slot, c end
			end
		end
		if bestSlot and cur.Gold >= bestCost and cur.Gold - bestCost >= budget * 0.5 - 0 then
			if m.Economy.LevelSlot(profile, classId, bestSlot) then did = true end
		end
		local bestItem, bestUp
		for _, item in pairs(profile.Season.Equipment.Equipped) do
			local c = m.Gear.UpgradeCost(item)
			if c and (bestUp == nil or c < bestUp) then bestItem, bestUp = item, c end
		end
		if bestItem and cur.Gold >= bestUp then
			if m.Gear.Upgrade(profile, bestItem.Id) then did = true end
		end
		if not did then break end
	end
end
local function run(classId, pathId, seedBase, goalLevel)
	lcg = 12345 + seedBase * 7919
	local profile = m.ProfileTemplate.New()
	profile.Permanent.UnlockedClasses[classId] = true
	profile.Season.ClassId = classId
	m.ProfileTemplate.EnsureClass = nil
	local team = { { Id = "p1", Name = classId, Profile = profile } }
	local companionParty, partnerProfile, partnerClass
	if PARTNER == "companion" then
		companionParty = { Members = { 1 }, Snapshots = {} } -- just enough of a party for Party.SyncCompanions (3 companions)
	elseif PARTNER ~= "solo" then
		partnerClass = PARTNER
		partnerProfile = m.ProfileTemplate.New()
		partnerProfile.Permanent.UnlockedClasses[partnerClass] = true
		partnerProfile.Season.ClassId = partnerClass
		team[2] = { Id = "p2", Name = partnerClass, Profile = partnerProfile }
		if SEATS > 2 then -- the empty seats get companions, as on the server
			companionParty = { Members = { 1, 2 }, Snapshots = {} }
		end
	end
	local clock, stage, seed, fights = 0, 1, seedBase * 1000, 0
	local levelAt, first = {}, {}
	local lvAtStage = {}
	local dungeonTried = {}
	local stonesEarned, stonesAt30 = 0, nil
	local losses = {}
	local durs = {}
	local luckPets = ""
	local lastFrontier, lastProgress = 1, 0
	local stuck = nil
	while profile.Season.Level < goalLevel and clock < 600 * 3600 do
		if profile.Season.HighestStage > lastFrontier then lastFrontier, lastProgress = profile.Season.HighestStage, clock end
		if clock - lastProgress > 30 * 3600 then stuck = lastFrontier break end -- 6 game hours with no new stage: this build is walled
		seed += 1
		fights += 1
		if fights % 100 == 0 then print(("progress %s %s fights %d stage %d lv %d game %.1fh cpu %.0fs"):format(classId, pathId, fights, stage, profile.Season.Level, clock / 3600, os.clock())) end
		local stonesBefore = profile.Season.Currencies.Wishstones or 0
		if companionParty then
			-- what the server does: companions fill the empty seats and follow the owner's level and build
			local classes = { classId, partnerClass }
			local list = m.Party.SyncCompanions(companionParty, profile, 0, classes)
			local base = if partnerProfile then 2 else 1
			for index, companion in ipairs(list) do
				team[base + index] = { Id = "c" .. index, Name = companion.Name, Snapshot = companion }
			end
		end
		local ultimate = if #team >= 2 then m.StageRunner.UltimateFor(team, profile.Season.HighestStage, nil) else nil
		local outcome = m.StageRunner.Run(team, stage, seed, ultimate)
		stonesEarned += (profile.Season.Currencies.Wishstones or 0) - stonesBefore
		if profile.Season.Level >= 30 and stonesAt30 == nil then stonesAt30 = { stonesEarned, profile.Season.HighestStage, clock / 3600, fights } end
		clock += outcome.Duration + 2
		if outcome.Stage % 10 ~= 0 then local band = (outcome.Stage - 1) // 10 durs[band] = durs[band] or { 0, 0 } durs[band][1] += outcome.Duration durs[band][2] += 1 end
		if outcome.Won then
			local s = outcome.Stage
			if first[s] == nil then first[s] = { Minutes = clock / 60, Seconds = outcome.Duration, Losses = losses[s] or 0 } end
		else
			losses[outcome.Stage] = (losses[outcome.Stage] or 0) + 1
		end
		stage = outcome.NextStage
		if not m.Subclasses.Current(profile, classId) and profile.Season.Level >= 30 then
			m.Subclasses.Choose(profile, classId, pathId)
		end
		if doGear then equipGear(profile) end
		spend(profile, classId)
		if doSkill then equipBest(profile, classId) end
		if doGold then goldSpend(profile, classId) end
		if partnerProfile then
			asFull(function()
				if not m.Subclasses.Current(partnerProfile, partnerClass) and partnerProfile.Season.Level >= 30 then
					local path = PARTNER_PATH or m.Subclasses.Choices(partnerClass, nil)[1].Id
					m.Subclasses.Choose(partnerProfile, partnerClass, path)
				end
				equipGear(partnerProfile)
				spend(partnerProfile, partnerClass)
				equipBest(partnerProfile, partnerClass)
				goldSpend(partnerProfile, partnerClass)
			end)
		end
		for _, st in ipairs({ 3, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100 }) do
			if lvAtStage[st] == nil and profile.Season.HighestStage >= st then lvAtStage[st] = profile.Season.Level end
		end
		-- dungeons: the first time the hero reaches a dungeon's recommended level (and can enter it), try it 5 times
		for _, d in ipairs(m.Activities.Dungeons) do
			if not dungeonTried[d.Id] and profile.Season.Level >= d.Level and profile.Season.HighestStage >= d.Unlock then
				dungeonTried[d.Id] = true
				local wins, waves = 0, 0
				for k = 1, 5 do
					local copies = {}
					for i, member in ipairs(team) do
						copies[i] = if member.Profile then { Id = member.Id, Name = member.Name, Profile = m.TableUtil.DeepCopy(member.Profile) } else member
					end
					local beaten, out = m.Activities.FightDungeon(copies, d, seed * 10 + k, false)
					waves += beaten
					if out.Won then wins += 1 end
				end
				print(("DUNGEON %s lv%d frontier%d wins %d/5 avgWaves %.1f/%d"):format(d.Id, profile.Season.Level, profile.Season.HighestStage, wins, waves / 5, d.Waves + 1))
			end
		end
		for _, g in ipairs({ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120 }) do
			if levelAt[g] == nil and profile.Season.Level >= g then levelAt[g] = clock / 3600 end
		end
	end
	-- final build summary
	local pet = m.Pets.Active(profile)
	local gearScore = 0
	for _, item in pairs(profile.Season.Equipment.Equipped) do local _, v = m.Gear.StatOf(item) gearScore += v end
	local rarePets = {}
	for petId in pairs(profile.Permanent.Pets or {}) do
		local r = m.PetConfig.Defs[petId].Rarity
		if r == "Legendary" or r == "Epic" then table.insert(rarePets, petId) end
	end
	table.sort(rarePets)
	return { Stuck = stuck, Class = classId, Path = pathId .. (if PARTNER == "solo" then "" else "+" .. PARTNER .. (PARTNER_PATH and ("." .. PARTNER_PATH) or "")), Hours = clock / 3600, Level = profile.Season.Level, Frontier = profile.Season.HighestStage, Fights = fights,
		Durs = durs, LvAtStage = lvAtStage, Stones30 = stonesAt30, First = first, LevelAt = levelAt, Pet = pet, GearScore = gearScore, RarePets = rarePets }
end

local paths = {}
for _, classId in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
	for _, def in ipairs(m.Subclasses.Choices(classId, nil)) do table.insert(paths, { classId, def.Id }) end
end
local goal = tonumber(ARGS[1]) or 90
local seeds = tonumber(ARGS[2]) or 1
local only = ARGS[3]
local t0 = os.clock()
for _, p in ipairs(paths) do
	if only == nil or only == p[2] or only == p[1] then
		for sd = 1, seeds do
			local r = run(p[1], p[2], sd, goal)
			local lv = {}
			for _, g in ipairs({ 30, 60, 90 }) do table.insert(lv, ("L%d=%.1fh"):format(g, r.LevelAt[g] or -1)) end
			local boss = {}
			for s = 10, r.Frontier, 10 do
				local a, b = r.First[s - 1], r.First[s]
				table.insert(boss, ("%d:%s/%s/%dx/%.0fs"):format(s, a and ("%.0fm"):format(a.Minutes) or "-", b and ("%.0fm"):format(b.Minutes) or "-", b and b.Losses or -1, b and b.Seconds or -1))
			end
			local dl = {}
			for band = 0, 12 do if r.Durs[band] then table.insert(dl, ("s%d-%d=%.1fs(n%d)"):format(band * 10 + 1, band * 10 + 9, r.Durs[band][1] / r.Durs[band][2], r.Durs[band][2])) end end
			local ls = {} for _, st in ipairs({ 3, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100 }) do if r.LvAtStage[st] then table.insert(ls, ("s%d:L%d"):format(st, r.LvAtStage[st])) end end
			if r.Stones30 then print(("STONES30 %s %s stones=%d stage=%d hours=%.1f fights=%d"):format(r.Class, r.Path, r.Stones30[1], r.Stones30[2], r.Stones30[3], r.Stones30[4])) end
			print("LVST " .. r.Class .. " " .. r.Path .. " " .. table.concat(ls, " "))
			print("DUR " .. r.Class .. " " .. r.Path .. " " .. table.concat(dl, " "))
			print(("RESULT\t%s\t%s\tseed%d\tSTUCK=%s\tH=%.2f\tlv%d\tfr%d\tfights%d\tpet=%s\tgear=%.0f\t%s\tBOSS %s\tRARE %s"):format(r.Class, r.Path, sd, tostring(r.Stuck), r.Hours, r.Level, r.Frontier, r.Fights, tostring(r.Pet), r.GearScore, table.concat(lv, " "), table.concat(boss, " "), table.concat(r.RarePets, ",")))
		end
	end
end
print("elapsed", os.clock() - t0)
