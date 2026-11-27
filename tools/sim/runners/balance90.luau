-- Class balance study: an auto-player per class path to a goal level (gear, pets, skills, wishing included), solo or with a partner (see PARTNER).
local m = {
	ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Skills = require("./Skills"), Economy = require("./Economy"),
	Classes = require("./Config/Classes"), Wishing = require("./Wishing"), SkillProgress = require("./SkillProgress"), Subclasses = require("./Subclasses"),
	Gear = require("./Gear"), Pets = require("./Pets"), PetConfig = require("./Config/Pets"), SubclassConfig = require("./Config/Subclasses"),
	Party = require("./Party"), Abilities = require("./Config/Abilities"),
	PetGear = require("./PetGear"), PetGearConfig = require("./Config/PetGear"), Consumables = require("./Consumables"),
	Runes = require("./Runes"), RunesConfig = require("./Config/Runes"),
	Activities = require("./Activities"), Bosses = require("./Bosses"), BossCfg = require("./Config/Bosses"), TableUtil = require("./Util/TableUtil"),
	Talents = require("./Talents"), DataSafety = require("./Util/DataSafety"), Stages = require("./Stages"), Bonds = require("./Bonds"),
}
local ARGS = require("./cfg")
local MODE = ARGS[4] or "full"
local COMBOS = ARGS[7] ~= false -- the bot wears full combos (cfg entry 7 = false: the old level-only bot, for comparison)
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
local doTalent = not (MODE == "lazy" or MODE == "notalent") -- level-up talent points (2026-11-23)
local lcg = 12345
local function rand() lcg = (lcg * 1103515245 + 12345) % 2147483648 return lcg / 2147483648 end

local RARITY_SCORE = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
-- wish tickets (tutorial, bosses, Pet Store eggs): each ticket buys one wish on the best tier unlocked (2026-11-19)
local function spendTickets(profile)
	for _, kind in ipairs({ "Pet", "Skill" }) do
		if (kind == "Pet" and doPet) or (kind == "Skill" and doSkill) then
			for _ = 1, 200 do
				local pick
				for _, tier in ipairs(m.Wishing.Info(profile, kind).Tiers) do
					if tier.Unlocked then pick = tier end
				end
				if pick == nil or not m.Wishing.Wish(profile, kind, pick.Id, "Ticket", 1, rand) then break end
			end
		end
	end
end
-- pets (2026-11-19): wear the best pet gear in every open slot, sell spare pieces, feed all pet food to the active pet
local RARITY_RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
local function petScore(piece) return (RARITY_RANK[piece.Rarity] or 0) * 100 + (piece.Value or 0) * 1000 end
local function petCare(profile)
	if not doPet then return end
	local petId = m.Pets.Active(profile)
	if petId == nil then return end
	for _, food in ipairs({ "GrandPetFood", "PetFood" }) do
		for _ = 1, 100 do
			if not m.Consumables.Use(profile, food, 0, petId) then break end
		end
	end
	local g = profile.Permanent.PetGear
	if g == nil then return end
	local open = m.PetGear.Slots(profile)
	for slot = 1, open do
		local kind = m.PetGearConfig.Kinds[slot]
		local best, bestScore = nil, (g.Equipped[kind] and petScore(g.Equipped[kind])) or -1
		for _, piece in ipairs(g.Bag) do
			if piece.Kind == kind and petScore(piece) > bestScore then best, bestScore = piece, petScore(piece) end
		end
		if best then m.PetGear.Equip(profile, best.Id) end
	end
	-- the bag holds 30: sell everything that is not better than what is worn
	for i = #g.Bag, 1, -1 do
		local piece = g.Bag[i]
		local worn = g.Equipped[piece.Kind]
		if worn and petScore(piece) <= petScore(worn) then m.PetGear.Sell(profile, piece.Id) end
	end
end
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
	-- like a player who knows their role: the healer keeps Heal and the tank keeps Taunt (2026-11-22: with working
	-- finishers the combo-first pick pushed them out, and Cleric/Warrior teams fell behind)
	-- and a Cleric keeps Blessing (the party's +25% attack: a Cleric squad without it was ~16 stages behind at L40)
	local owns = profile.Season.OwnedAbilities
	local keepList = ({ Cleric = { "Heal", "Blessing" }, Warrior = { "Taunt", "IronSkin" } })[classId] or {} -- Warrior without Iron Skin: ~6 stages behind at L40
	for _, id in ipairs(keepList) do
		if owns[id] then table.insert(best, id) end
	end
	local keep = keepList[1]
	-- combos (2026-11-19): like a player who reads the skill text, wear an owned finisher with its owned builders first
	-- (builders in the first slots so the layers go on before the finisher fires), then fill the rest by level
	if COMBOS then
		local bestCombo, bestScore = nil, -1
		for _, f in ipairs(owned) do
			local consume = nil
			for _, e in ipairs(m.Abilities[f.Id].Effects) do if e.Consume then consume = e.Consume.Status end end
			if consume then
				local builders, score = {}, f.Level
				for _, b in ipairs(owned) do
					if b.Id ~= f.Id and not table.find(best, b.Id) and #builders < m.Skills.SLOTS - 1 - #best then
						for _, e in ipairs(m.Abilities[b.Id].Effects) do
							if e.Type == "ApplyStatus" and e.Status == consume then table.insert(builders, b.Id) score += b.Level break end
						end
					end
				end
				if #builders > 0 and score > bestScore then
					bestCombo, bestScore = builders, score
					table.insert(bestCombo, f.Id)
				end
			end
		end
		for _, id in ipairs(bestCombo or {}) do if not table.find(best, id) then table.insert(best, id) end end
	end
	for i = 1, #owned do
		if #best >= m.Skills.SLOTS then break end
		if not table.find(best, owned[i].Id) then table.insert(best, owned[i].Id) end
	end
	m.Economy.Equip(profile, classId, best)
end
local function equipGear(profile)
	m.Gear.EquipBest(profile) -- the real "Equip best" button
	local eq = profile.Season.Equipment
	for i = #eq.Inventory, 1, -1 do m.Gear.Sell(profile, eq.Inventory[i].Id) end
end

-- runes (2026-11-22): carve the best runes onto worn pieces that have none or a lower tier
local function runeCare(profile)
	for _, item in pairs(profile.Season.Equipment.Equipped) do
		local list = m.Runes.List(profile)
		local best = list[1]
		if not best then return end
		local have = item.Rune and m.Runes.TierRank(item.Rune.Tier) or 0
		if m.Runes.TierRank(best.Tier) > have then
			m.Runes.Carve(profile, item.Id, best.Key, false)
		end
	end
end

-- run fn with every upgrade switched on (the partner hero always plays "full", whatever MODE tests on the main hero)
local function asFull(fn)
	local g, s, p, o = doGear, doSkill, doPet, doGold
	doGear, doSkill, doPet, doGold = true, true, true, true
	fn()
	doGear, doSkill, doPet, doGold = g, s, p, o
end

local LAZY = MODE == "lazy"
-- GOLD ledger (2026-11-27): where the tested hero's gold comes from and goes, per level band
local LEDGER = nil -- { Profile, Bands = { [band] = { Earn, Sell, Pet, Rune, Slot, Gear, Other, Hours, Bank } } }
local function bandOf(level)
	return if level >= 100 then 100 else (level // 20) * 20
end
local function gnote(profile, key, amount)
	if LEDGER and LEDGER.Profile == profile and amount ~= 0 then
		local b = bandOf(profile.Season.Level)
		local row = LEDGER.Bands[b] or { Earn = 0, Sell = 0, Pet = 0, Rune = 0, Slot = 0, Gear = 0, Other = 0, Hours = 0, Bank = 0, Peak = 0 }
		LEDGER.Bands[b] = row
		row[key] += amount
	end
end
local function goldSpend(profile, classId, now)
	-- half the gold trains skill slots, half upgrades worn gear (cheapest first), like a player using the Trainer and the Blacksmith
	local cur = profile.Season.Currencies
	local budget = cur.Gold
	-- rune pouches at the Blacksmith: up to a tenth of the gold
	if doGear then
		local runeBudget, spent = budget * 0.1, 0
		while spent + m.RunesConfig.Pouch.Gold <= runeBudget and m.Runes.BuyPouch(profile, rand) do
			spent += m.RunesConfig.Pouch.Gold
		end
		gnote(profile, "Rune", budget - cur.Gold)
		budget = cur.Gold
	end
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
			local before = cur.Gold
			if m.Economy.LevelSlot(profile, classId, bestSlot) then did = true end
			gnote(profile, "Slot", before - cur.Gold)
		end
		local bestItem, bestUp
		for _, item in pairs(profile.Season.Equipment.Equipped) do
			local c = m.Gear.UpgradeCost(item, m.Gear.MaxUpgrade(profile.Season.Level))
			if c and (bestUp == nil or c < bestUp) then bestItem, bestUp = item, c end
		end
		if bestItem and cur.Gold >= bestUp then
			local before = cur.Gold
			if m.Gear.Upgrade(profile, bestItem.Id) then did = true end
			gnote(profile, "Gear", before - cur.Gold)
		end
		if not did then break end
	end
	-- the Pet Store after upgrades (2026-11-27: a player upgrades worn gear first): up to half of what is left on eggs (3 a day) and crates
	if doPet then
		budget = cur.Gold
		-- save for the cheapest worn-gear upgrade first; the Pet Store gets half of what is above that
		local reserve = 0
		if doGear then
			for _, item in pairs(profile.Season.Equipment.Equipped) do
				local c = m.Gear.UpgradeCost(item, m.Gear.MaxUpgrade(profile.Season.Level))
				if c and (reserve == 0 or c < reserve) then reserve = c end
			end
		end
		local petBudget = math.max(0, budget - reserve) * 0.5
		local spent = 0
		while spent < petBudget and m.PetGear.EggsLeft(profile, now) > 0 and m.PetGear.EggPrice(profile.Season.HighestStage) <= petBudget - spent do
			local ok, price = m.PetGear.BuyEgg(profile, now)
			if not ok then break end
			spent += price
		end
		if m.PetGear.Slots(profile) > 0 then
			for _ = 1, 10 do
				local price = m.PetGear.CratePrice("PetCrate", profile.Season.HighestStage)
				if spent + price > petBudget or not m.PetGear.BuyCrate(profile, "PetCrate", rand) then break end
				spent += price
			end
		end
		gnote(profile, "Pet", budget - cur.Gold)
		budget = cur.Gold
	end
end
-- Class report (docs/BALANCE.md "Class report"): N fights at the pushed stage with Simulation metrics on. One METRIC line
-- per hero (the tested hero first, then the companions/partner), one STATUSFX line with what each buff/debuff added or kept off.
local METRIC_KEYS = { "Dealt", "PetDealt", "MinionDealt", "Dot", "Enabled", "Healed", "Lifesteal", "Overheal", "Absorbed", "MitByBuffs", "MitDefense", "Dodged", "Taken", "Deaths", "Hits", "Crits" }
local function sampleMetrics(classId, pathId, profile, team, stage, seed, ultimate, clock)
	local N = 12
	local wins, secs, sums, statusSums = 0, 0, {}, {}
	for i = 1, N do
		local o = m.StageRunner.Run(team, stage, seed * 31 + i, ultimate, false, { Metrics = true, NoRewards = true })
		if o.Won then wins += 1 end
		secs += o.Duration
		local sim = o.Sim
		local ownerOf = {}
		for _, e in ipairs(sim.Party) do if e.OwnerId then ownerOf[e.Id] = e.OwnerId end end
		for id, row in pairs(o.Metrics.Entities) do
			local owner = ownerOf[id]
			local key = owner or id
			sums[key] = sums[key] or {}
			for k, v in pairs(row) do
				if owner and k == "Dealt" then
					sums[key].MinionDealt = (sums[key].MinionDealt or 0) + v
				elseif not owner or k ~= "Taken" then
					sums[key][k] = (sums[key][k] or 0) + v
				end
			end
		end
		for sid, r in pairs(o.Metrics.Statuses) do
			statusSums[sid] = statusSums[sid] or { 0, 0 }
			statusSums[sid][1] += r.Extra
			statusSums[sid][2] += r.Mitigated
		end
	end
	local enemyScale = m.Stages.Build(stage).Scale
	for _, member in ipairs(team) do
		local cls = if member.Profile then member.Profile.Season.ClassId else member.Snapshot.ClassId
		local row = sums[member.Id] or {}
		local parts = {}
		for _, k in ipairs(METRIC_KEYS) do table.insert(parts, ("%s=%.0f"):format(k, (row[k] or 0) / N)) end
		print(("METRIC	%s	%s	lv%d	fr%d	st%d	h%.2f	win%.2f	dur%.1f	esc%.1f	%s	%s	%s"):format(classId, pathId, profile.Season.Level, profile.Season.HighestStage, stage, clock / 3600, wins / N, secs / N, enemyScale, member.Id, cls, table.concat(parts, " ")))
	end
	local fx = {}
	for sid, r in pairs(statusSums) do table.insert(fx, ("%s=%.0f/%.0f"):format(sid, r[1] / N, r[2] / N)) end
	table.sort(fx)
	print(("STATUSFX	%s	%s	lv%d	%s"):format(classId, pathId, profile.Season.Level, table.concat(fx, " ")))
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
	LEDGER = { Profile = profile, Bands = {} }
	local levelAt, first = {}, {}
	local lvAtStage = {}
	local dungeonTried = {}
	local bossTried = {}
	local stonesEarned, stonesAt30 = 0, nil
	local losses = {}
	local lossWhy = {}
	local durs = {}
	local luckPets = ""
	local lastFrontier, lastProgress = 1, 0
	local stuck = nil
	local nextSample = 10
	while profile.Season.Level < goalLevel and clock < 600 * 3600 do
		if profile.Season.HighestStage > lastFrontier then lastFrontier, lastProgress = profile.Season.HighestStage, clock end
		if clock - lastProgress > 120 * 3600 then stuck = lastFrontier break end -- 120 game hours with no new stage (leveling is slow since 2026-11-25): this build is walled
		seed += 1
		fights += 1
		if fights % 100 == 0 then print(("progress %s %s fights %d stage %d lv %d game %.1fh cpu %.0fs"):format(classId, pathId, fights, stage, profile.Season.Level, clock / 3600, os.clock())) end
		if fights % 500 == 0 then -- STATS: what the hero fights with vs the enemy scale at its frontier (late-game runaway check)
			local hero = m.StageRunner.NewParty({ team[1] })[1].Stats
			local fr = profile.Season.HighestStage
			local sc = m.Stages.Build(fr).Scale
			local parts = {}
			for _, k in ipairs({ "Attack", "MaxHealth", "Defense", "AttackSpeed", "CritChance", "CritMultiplier", "DamageDealt", "DamageTaken", "Haste", "Lifesteal" }) do
				local v = hero[k]
				if v then table.insert(parts, ("%s=%s"):format(k, if v >= 100 then ("%.0f"):format(v) else ("%.2f"):format(v))) end
			end
			print(("STATS %s %s lv%d fr%d escale=%.1f %s"):format(classId, pathId, profile.Season.Level, fr, sc, table.concat(parts, " ")))
		end
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
		if profile.Season.Level >= nextSample then -- METRIC: a sample of fights at the stage the party is pushing (no rewards)
			nextSample = (profile.Season.Level // 10 + 1) * 10
			sampleMetrics(classId, pathId, profile, team, math.max(1, profile.Season.HighestStage), seed, ultimate, clock)
		end
		local bossWatch = stage % 10 == 0 and stage >= 60
		-- season mechanic Bonds (as Party.OnlineTick): the tested hero (and a class partner) get their bond bonus
		local bondKeys = nil
		if m.Bonds and m.Bonds.On() then
			bondKeys = {}
			for _, member in ipairs(team) do
				member.BondKey = if member.Snapshot then "c:" .. member.Name else member.Id
				table.insert(bondKeys, member.BondKey)
			end
			for _, member in ipairs(team) do
				if member.Profile then
					local mods = m.Bonds.Mods(member.Profile.Season.Bonds, member.BondKey, bondKeys)
					member.BondMods = if #mods > 0 then mods else nil
				end
			end
		end
		local goldBefore = profile.Season.Currencies.Gold
		local outcome = m.StageRunner.Run(team, stage, seed, ultimate, false, if bossWatch then { Metrics = true } else nil)
		gnote(profile, "Earn", profile.Season.Currencies.Gold - goldBefore)
		if bondKeys and outcome.Won then
			for _, member in ipairs(team) do
				if member.Profile then
					m.Bonds.Gain(member.Profile, member.BondKey, bondKeys)
				end
			end
		end
		gnote(profile, "Hours", (outcome.Duration + 2) / 3600)
		if bossWatch and not outcome.Won and outcome.Sim then -- BOSSWHY: how boss fights are lost (timeout or wipe, boss health left)
			local w = lossWhy[stage] or { 0, 0, 0, 0, 0 }
			lossWhy[stage] = w
			if outcome.TimedOut then w[1] += 1 else w[2] += 1 end
			local big
			for _, e in ipairs(outcome.Sim.Enemies) do if big == nil or e.Stats.MaxHealth > big.Stats.MaxHealth then big = e end end
			if big then w[3] += math.max(0, big.Health) / big.Stats.MaxHealth end
			w[4] += outcome.Duration
			w[5] += #outcome.Result.Survivors
		end
		stonesEarned += (profile.Season.Currencies.Wishstones or 0) - stonesBefore
		if profile.Season.Level >= 30 and stonesAt30 == nil then stonesAt30 = { stonesEarned, profile.Season.HighestStage, clock / 3600, fights } end
		clock += outcome.Duration + 2
		if outcome.Stage % 10 ~= 0 then local band = (outcome.Stage - 1) // 10 durs[band] = durs[band] or { 0, 0 } durs[band][1] += outcome.Duration durs[band][2] += 1 end
		if outcome.Won then
			local s = outcome.Stage
			if first[s] == nil then first[s] = { Minutes = clock / 60, Seconds = outcome.Duration, Losses = losses[s] or 0, Level = profile.Season.Level } end
		else
			losses[outcome.Stage] = (losses[outcome.Stage] or 0) + 1
		end
		stage = outcome.NextStage
		if not m.Subclasses.Current(profile, classId) and profile.Season.Level >= 30 then
			m.Subclasses.Choose(profile, classId, pathId)
		end
		local g0 = profile.Season.Currencies.Gold
		if doGear then equipGear(profile) end
		gnote(profile, "Sell", profile.Season.Currencies.Gold - g0)
		if doGold then goldSpend(profile, classId, clock) end
		g0 = profile.Season.Currencies.Gold
		if doGear then runeCare(profile) end
		spendTickets(profile)
		spend(profile, classId)
		if doTalent then m.Talents.AutoSpend(profile) end
		petCare(profile)
		if doSkill then equipBest(profile, classId) end
		gnote(profile, "Other", g0 - profile.Season.Currencies.Gold)
		do
			local row = LEDGER.Bands[bandOf(profile.Season.Level)]
			if row then
				row.Bank = profile.Season.Currencies.Gold
				row.Peak = math.max(row.Peak, row.Bank)
			end
		end
		if partnerProfile then
			asFull(function()
				if not m.Subclasses.Current(partnerProfile, partnerClass) and partnerProfile.Season.Level >= 30 then
					local path = PARTNER_PATH or m.Subclasses.Choices(partnerClass, nil)[1].Id
					m.Subclasses.Choose(partnerProfile, partnerClass, path)
				end
				equipGear(partnerProfile)
				goldSpend(partnerProfile, partnerClass, clock)
				runeCare(partnerProfile)
				spendTickets(partnerProfile)
				spend(partnerProfile, partnerClass)
				m.Talents.AutoSpend(partnerProfile)
				petCare(partnerProfile)
				equipBest(partnerProfile, partnerClass)
			end)
		end
		for _, st in ipairs({ 3, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100 }) do
			if lvAtStage[st] == nil and profile.Season.HighestStage >= st then lvAtStage[st] = profile.Season.Level end
		end
		-- bosses: at levels 10/20/30/40, the world and season boss damage as a multiple of Bosses.DamageScale (tiers are multiples)
		for _, lv in ipairs({ 10, 20, 30, 40 }) do
			if not bossTried[lv] and profile.Season.Level >= lv then
				bossTried[lv] = true
				local parts = {}
				for _, which in ipairs({ "World", "Season" }) do
					local total = 0
					for k = 1, 3 do
						local copies = {}
						for i, member in ipairs(team) do
							copies[i] = if member.Profile then { Id = member.Id, Name = member.Name, Profile = m.TableUtil.DeepCopy(member.Profile) } else member
						end
						total += m.Bosses.Challenge(copies, m.BossCfg[which], profile.Season.HighestStage, seed * 10 + k, false)
					end
					table.insert(parts, ("%s %.1fx"):format(which, total / 3 / m.Bosses.DamageScale(profile.Season.HighestStage)))
				end
				print(("BOSSDMG lv%d frontier%d %s"):format(lv, profile.Season.HighestStage, table.concat(parts, " ")))
			end
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
	-- pet summary: active pet level, worn pet gear, eggs bought
	do
		local petId, petLevel = m.Pets.Active(profile)
		local worn = {}
		for kind, piece in pairs((profile.Permanent.PetGear or {}).Equipped or {}) do table.insert(worn, kind .. "=" .. piece.Rarity) end
		table.sort(worn)
		print(("PET %s %s pet=%s lv%s gear[%s] stash food=%d"):format(classId, pathId, tostring(petId), tostring(petLevel), table.concat(worn, " "), m.Consumables.Count(profile, "PetFood")))
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
	local worn = {}
	for _, item in pairs(profile.Season.Equipment.Equipped) do
		if item.Rune then table.insert(worn, item.Rune.Stat .. "/" .. item.Rune.Tier:sub(1, 1)) end
	end
	table.sort(worn)
	print(("RUNES	%s	%s	worn %d: %s"):format(classId, pathId, #worn, table.concat(worn, " ")))
	print(("LOADOUT	%s	%s	%s"):format(classId, pathId, table.concat(profile.Season.Loadouts[classId] or {}, " ")))
	-- can this played profile be saved to a DataStore? (Util/DataSafety; a bad table fails every live save)
	local problems = m.DataSafety.Problems(profile, 5)
	print(("SAVECHECK	%s	%s	%s	size %d"):format(classId, pathId, if #problems == 0 then "ok" else table.concat(problems, " | "), m.DataSafety.Size(profile)))
	-- LOOP: how the frontier moves (2026-11-25, owner: upgrade, push a few stages, wait for more upgrades; no big pushes).
	-- Per level band: the most new stages cleared in any one game hour, and the longest wait between two new stages.
	do
		local firsts = {}
		for s, f in pairs(first) do table.insert(firsts, { Stage = s, Minutes = f.Minutes, Level = f.Level or 0 }) end
		table.sort(firsts, function(a, b) return a.Minutes < b.Minutes end)
		local parts = {}
		for _, band in ipairs({ { 1, 39 }, { 40, 59 }, { 60, 79 }, { 80, 99 }, { 100, 120 } }) do
			local list = {}
			for _, f in ipairs(firsts) do if f.Level >= band[1] and f.Level <= band[2] then table.insert(list, f) end end
			if #list > 1 then
				local burst, wait, j = 0, 0, 1
				for i = 1, #list do
					while list[i].Minutes - list[j].Minutes > 60 do j += 1 end
					burst = math.max(burst, i - j + 1)
					if i > 1 then wait = math.max(wait, list[i].Minutes - list[i - 1].Minutes) end
				end
				local span = (list[#list].Minutes - list[1].Minutes) / 60
				table.insert(parts, ("L%d-%d: %d stages in %.1fh, max %d/h, longest wait %.1fh"):format(band[1], band[2], #list, span, burst, wait / 60))
			end
		end
		print(("LOOP	%s	%s	%s"):format(classId, pathId, table.concat(parts, " | ")))
	end
	-- GOLD: per 20-level band, gold earned per game hour (fights + selling) and where it went; Bank = gold held at the band's end
	do
		local function short(n)
			n = math.floor(n)
			for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
				if math.abs(n) >= u[1] then return ("%.1f%s"):format(n / u[1], u[2]) end
			end
			return tostring(n)
		end
		for _, b in ipairs({ 0, 20, 40, 60, 80, 100 }) do
			local r = LEDGER.Bands[b]
			if r and r.Hours > 0 then
				local inc = r.Earn + r.Sell
				local spent = r.Pet + r.Rune + r.Slot + r.Gear + r.Other
				local function pc(x) return if spent > 0 then math.floor(x / spent * 100 + 0.5) else 0 end
				print(("GOLD	%s	%s	L%d-%d	%.1fh	earn/h %s (sell %d%%)	spent %d%% of income: pet %d%% rune %d%% slot %d%% gear %d%% other %d%%	bank %s peak %s"):format(
					classId, pathId, if b == 0 then 1 else b, if b == 100 then 120 else b + 19, r.Hours, short(inc / r.Hours), if inc > 0 then math.floor(r.Sell / inc * 100 + 0.5) else 0,
					if inc > 0 then math.floor(spent / inc * 100 + 0.5) else 0, pc(r.Pet), pc(r.Rune), pc(r.Slot), pc(r.Gear), pc(r.Other), short(r.Bank), short(r.Peak)))
			end
		end
	end
	return { Stuck = stuck, Class = classId, Path = pathId .. (if PARTNER == "solo" then "" else "+" .. PARTNER .. (PARTNER_PATH and ("." .. PARTNER_PATH) or "")), Hours = clock / 3600, Level = profile.Season.Level, Frontier = profile.Season.HighestStage, Fights = fights,
		Durs = durs, LvAtStage = lvAtStage, Stones30 = stonesAt30, First = first, LevelAt = levelAt, Pet = pet, GearScore = gearScore, RarePets = rarePets, LossWhy = lossWhy }
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
			local r = run(p[1], p[2], sd + (ARGS.SeedOffset or 0), goal)
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
			local why = {}
			for st = 60, r.Frontier + 10, 10 do
				local w = r.LossWhy[st]
				if w then local n = w[1] + w[2] table.insert(why, ("%d:n%d/timeout%d/wipe%d/bossleft%.0f%%/%.0fs/alive%.1f"):format(st, n, w[1], w[2], w[3] / n * 100, w[4] / n, w[5] / n)) end
			end
			print("BOSSWHY " .. r.Class .. " " .. r.Path .. " " .. table.concat(why, " "))
			print("LVST " .. r.Class .. " " .. r.Path .. " " .. table.concat(ls, " "))
			print("DUR " .. r.Class .. " " .. r.Path .. " " .. table.concat(dl, " "))
			print(("RESULT\t%s\t%s\tseed%d\tSTUCK=%s\tH=%.2f\tlv%d\tfr%d\tfights%d\tpet=%s\tgear=%.0f\t%s\tBOSS %s\tRARE %s"):format(r.Class, r.Path, sd, tostring(r.Stuck), r.Hours, r.Level, r.Frontier, r.Fights, tostring(r.Pet), r.GearScore, table.concat(lv, " "), table.concat(boss, " "), table.concat(r.RarePets, ",")))
		end
	end
end
print("elapsed", os.clock() - t0)
