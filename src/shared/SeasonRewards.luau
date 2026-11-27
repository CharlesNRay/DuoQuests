--[[
	SeasonRewards (ModuleScript)
	Location: ReplicatedStorage > Shared > SeasonRewards

	End-of-season rewards: pure rules (see Config/SeasonRewards for the numbers).
	The server freezes a season's results; this module turns a player's place in
	them into a reward and grants it once.

	Frozen results ("results"):
	  { Total = ranked players,
	    Histogram = { [score] = players with exactly that score },
	    Top = { [userId] = overall rank },                       (the best Config.TopKept)
	    ClassTop = { [classId] = { [userId] = rank in that class } } }

	  SeasonRewards.Percent(results, score)      -> share of ranked players at or above this score, ties counted in (0-1], or nil if unranked
	  SeasonRewards.Standing(results, info)      -> { Ranked, Score, Percent, Percentile, Rank, RankReward, Class, ClassRank, ClassReward }
	                                                info = { UserId, Score, ClassId }
	  SeasonRewards.Reward(standing, seasonId?)  -> (seasonId adds that season's own Prize, Config/Seasons) { Sunstones, Wishstones, Tickets, Titles, Cosmetics, Lines } (all layers added)
	  SeasonRewards.Claimed(profile, seasonId)   -> boolean
	  SeasonRewards.Claim(profile, seasonId, results, info) -> true, reward | false, "AlreadyClaimed" | "NotRanked"
	  SeasonRewards.Brackets(seasonId?)          -> display rows for the screen (percentiles, ranks, class ranks)
]]

local Config = require(script.Parent.Config.SeasonRewards)
local Classes = require(script.Parent.Config.Classes)
local Consumables = require(script.Parent.Consumables)
local Pets = require(script.Parent.Pets)
local Cosmetics = require(script.Parent.Cosmetics)
local PetConfig = require(script.Parent.Config.Pets)
local Premium = require(script.Parent.Premium)
local SeasonClock = require(script.Parent.SeasonClock)

local SeasonRewards = {}

local function ranked(score)
	return type(score) == "number" and score >= Config.MinStage
end

function SeasonRewards.Percent(results, score)
	if not ranked(score) or not results or (results.Total or 0) <= 0 then
		return nil
	end
	local atOrAbove = 0
	for value, count in pairs(results.Histogram or {}) do
		if value >= score then
			atOrAbove += count
		end
	end
	-- everyone on the same score gets the same percentile, counted with the whole tie group, so a bracket
	-- never holds more than its advertised share of players
	return math.min(1, math.max(1, atOrAbove) / results.Total)
end

local function percentileRow(percent)
	for _, row in ipairs(Config.Percentiles) do
		if percent <= row.Top + 1e-9 then
			return row
		end
	end
	return Config.Percentiles[#Config.Percentiles]
end

local function bestRow(rows, rank)
	if rank == nil then
		return nil
	end
	for _, row in ipairs(rows) do -- rows are ordered tightest first
		if rank <= row.MaxRank then
			return row
		end
	end
	return nil
end

-- Every row the rank qualifies for, tightest first (a rank-1 player qualifies for all of them).
local function rowsFor(rows, rank)
	local out = {}
	if rank == nil then
		return out
	end
	for _, row in ipairs(rows) do
		if rank <= row.MaxRank then
			table.insert(out, row)
		end
	end
	return out
end

function SeasonRewards.Standing(results, info)
	local standing = { Ranked = false, Score = info.Score, ClassId = info.ClassId }
	local percent = SeasonRewards.Percent(results, info.Score)
	if percent == nil then
		return standing
	end
	standing.Ranked = true
	standing.Percent = percent
	standing.Percentile = percentileRow(percent)
	standing.Rank = results.Top and results.Top[info.UserId] or nil
	standing.RankReward = bestRow(Config.Ranks, standing.Rank)
	standing.RankRewards = if Config.StackRanks then rowsFor(Config.Ranks, standing.Rank) else { standing.RankReward }
	local classTop = results.ClassTop and results.ClassTop[info.ClassId]
	standing.ClassRank = classTop and classTop[info.UserId] or nil
	standing.ClassReward = bestRow(Config.ClassRanks, standing.ClassRank)
	standing.ClassRewards = if Config.StackRanks then rowsFor(Config.ClassRanks, standing.ClassRank) else { standing.ClassReward }
	return standing
end

local function className(classId)
	local def = Classes[classId]
	return def and (def.DisplayName or def.Name) or classId
end

-- display name of a cosmetic id ("Aura_Warrior" -> "Warrior aura")
local function cosmeticName(id, classId)
	local name = Config.CosmeticNames[id]
	if name then
		return name
	end
	local kind = id:match("^(%a+)_")
	local template = kind and Config.CosmeticNames[kind .. "_Class"]
	return if template then template:gsub("%%s", className(classId)) else id
end

-- A season's own prize (Config/Seasons Prize = { Cosmetic, Top }): everyone ranked in the Top share gets it
local function seasonPrize(seasonId)
	local def = seasonId and SeasonClock.Def(seasonId)
	return def and def.Prize
end

function SeasonRewards.Reward(standing, seasonId)
	local reward = { Sunstones = 0, Wishstones = 0, Tickets = {}, Titles = {}, Cosmetics = {}, Pets = {}, Lines = {} }
	if not standing.Ranked then
		return reward
	end
	local classId = standing.ClassId
	local function add(row, label)
		reward.Sunstones += row.Sunstones or 0
		reward.Wishstones += row.Wishstones or 0
		for id, count in pairs(row.Tickets or {}) do
			reward.Tickets[id] = (reward.Tickets[id] or 0) + count
		end
		if row.Title then
			table.insert(reward.Titles, (row.Title:gsub("%%s", className(classId))))
		end
		if row.Cosmetic then
			local id = row.Cosmetic:gsub("%%s", classId)
			if not table.find(reward.Cosmetics, id) then
				table.insert(reward.Cosmetics, id)
			end
		end
		if row.Pet then
			local petId = if row.Pet == "ClassPet" then Config.ClassPets[classId] else row.Pet
			if petId and PetConfig.Defs[petId] and not table.find(reward.Pets, petId) then
				table.insert(reward.Pets, petId)
			end
		end
		table.insert(reward.Lines, { Label = label, Sunstones = row.Sunstones or 0 })
	end
	add(standing.Percentile, standing.Percentile.Label)
	local prize = seasonPrize(seasonId)
	if prize and standing.Percent and standing.Percent <= prize.Top + 1e-9 and not table.find(reward.Cosmetics, prize.Cosmetic) then
		table.insert(reward.Cosmetics, prize.Cosmetic)
	end
	for _, row in ipairs(standing.RankRewards or {}) do
		add(row, row.Label)
	end
	for _, row in ipairs(standing.ClassRewards or {}) do
		add(row, (row.Label:gsub("%%s", className(classId))))
	end
	-- names for the screen
	reward.Extras = {}
	for _, petId in ipairs(reward.Pets) do
		table.insert(reward.Extras, "Pet: " .. PetConfig.Defs[petId].DisplayName)
	end
	for _, id in ipairs(reward.Cosmetics) do
		table.insert(reward.Extras, cosmeticName(id, classId))
	end
	for _, title in ipairs(reward.Titles) do
		table.insert(reward.Extras, 'Title "' .. title .. '"')
	end
	return reward
end

local function ledger(profile)
	local a = profile.Permanent.SeasonRewards
	if a == nil then
		a = { Claimed = {} }
		profile.Permanent.SeasonRewards = a
	end
	a.Claimed = a.Claimed or {}
	-- keys are strings ("1", "2"): number keys with a gap (season 2 claimed, 1 not) cannot be saved in a DataStore
	for k, v in pairs(a.Claimed) do
		if type(k) == "number" then
			a.Claimed[k] = nil
			a.Claimed[tostring(k)] = v
		end
	end
	return a.Claimed
end

function SeasonRewards.Claimed(profile, seasonId)
	return ledger(profile)[tostring(seasonId)] == true
end

function SeasonRewards.Claim(profile, seasonId, results, info)
	if SeasonRewards.Claimed(profile, seasonId) then
		return false, "AlreadyClaimed"
	end
	local standing = SeasonRewards.Standing(results, info)
	if not standing.Ranked then
		return false, "NotRanked"
	end
	local reward = SeasonRewards.Reward(standing, seasonId)
	Premium.AddSunstones(profile, reward.Sunstones)
	if (profile.Season.SeasonId or 0) <= seasonId then
		-- still in that season's data (claimed before the next season started): the Wishstones would be wiped at the
		-- switch, so they wait and SeasonRollover adds them to the new season
		local a = profile.Permanent.SeasonRewards
		a.CarryWishstones = (a.CarryWishstones or 0) + reward.Wishstones
	else
		local currencies = profile.Season.Currencies
		currencies.Wishstones = (currencies.Wishstones or 0) + reward.Wishstones
	end
	for id, count in pairs(reward.Tickets) do
		Consumables.Grant(profile, id, count)
	end
	for _, title in ipairs(reward.Titles) do
		Cosmetics.GrantTitle(profile, title)
	end
	for _, id in ipairs(reward.Cosmetics) do
		Cosmetics.Grant(profile, id)
	end
	for _, petId in ipairs(reward.Pets) do
		if profile.Permanent.Pets[petId] then
			Pets.AddDuplicate(profile, petId) -- already owned: the prize becomes a copy for ranking the pet up
		else
			profile.Permanent.Pets[petId] = true
		end
	end
	ledger(profile)[tostring(seasonId)] = true
	-- a small history record for the profile screen
	local history = profile.Permanent.SeasonHistory[tostring(seasonId)] or {} -- may already hold Characters (SeasonRollover)
	history.Percent, history.Rank, history.ClassRank, history.Score = standing.Percent, standing.Rank, standing.ClassRank, standing.Score
	profile.Permanent.SeasonHistory[tostring(seasonId)] = history
	return true, reward, standing
end

-- Rows for the "how rewards work" panel. Extras = the non-Sunstone prizes as short texts.
local function extrasOf(row, classWord)
	local extras = {}
	if row.Pet then
		local petId = if row.Pet == "ClassPet" then nil else row.Pet
		table.insert(extras, if petId and PetConfig.Defs[petId] then "Pet: " .. PetConfig.Defs[petId].DisplayName else "a class prize pet")
	end
	if row.Cosmetic then
		table.insert(extras, cosmeticName(row.Cosmetic:gsub("%%s", classWord), classWord))
	end
	if row.Title then
		table.insert(extras, 'Title "' .. row.Title:gsub("%%s", classWord) .. '"')
	end
	return extras
end

function SeasonRewards.Brackets(seasonId)
	local out = { Percentiles = {}, Ranks = {}, ClassRanks = {}, MinStage = Config.MinStage, Stack = Config.StackRanks }
	local prize = seasonPrize(seasonId)
	for _, row in ipairs(Config.Percentiles) do
		local extras = extrasOf(row, "class")
		if prize and row.Top <= prize.Top + 1e-9 then
			table.insert(extras, cosmeticName(prize.Cosmetic, "class"))
		end
		table.insert(out.Percentiles, { Label = row.Label, Sunstones = row.Sunstones, Wishstones = row.Wishstones, Extras = extras })
	end
	for _, row in ipairs(Config.Ranks) do
		table.insert(out.Ranks, { Label = row.Label, Sunstones = row.Sunstones, Extras = extrasOf(row, "class") })
	end
	for _, row in ipairs(Config.ClassRanks) do
		table.insert(out.ClassRanks, { Label = (row.Label:gsub("%%s", "class")), Sunstones = row.Sunstones, Extras = extrasOf(row, "class") })
	end
	return out
end

return SeasonRewards
