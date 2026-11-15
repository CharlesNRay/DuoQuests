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
	  SeasonRewards.Reward(standing)             -> { Sunstones, Wishstones, Tickets, Titles, Cosmetics, Lines } (all layers added)
	  SeasonRewards.Claimed(profile, seasonId)   -> boolean
	  SeasonRewards.Claim(profile, seasonId, results, info) -> true, reward | false, "AlreadyClaimed" | "NotRanked"
	  SeasonRewards.Brackets()                   -> display rows for the screen (percentiles, ranks, class ranks)
]]

local Config = require(script.Parent.Config.SeasonRewards)
local Classes = require(script.Parent.Config.Classes)
local Consumables = require(script.Parent.Consumables)
local Premium = require(script.Parent.Premium)

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
	local classTop = results.ClassTop and results.ClassTop[info.ClassId]
	standing.ClassRank = classTop and classTop[info.UserId] or nil
	standing.ClassReward = bestRow(Config.ClassRanks, standing.ClassRank)
	return standing
end

local function className(classId)
	local def = Classes[classId]
	return def and (def.DisplayName or def.Name) or classId
end

function SeasonRewards.Reward(standing)
	local reward = { Sunstones = 0, Wishstones = 0, Tickets = {}, Titles = {}, Cosmetics = {}, Lines = {} }
	if not standing.Ranked then
		return reward
	end
	local function add(row, label)
		reward.Sunstones += row.Sunstones or 0
		reward.Wishstones += row.Wishstones or 0
		for id, count in pairs(row.Tickets or {}) do
			reward.Tickets[id] = (reward.Tickets[id] or 0) + count
		end
		if row.Title then
			table.insert(reward.Titles, (row.Title:gsub("%%s", className(standing.ClassId))))
		end
		if row.Cosmetic then
			table.insert(reward.Cosmetics, row.Cosmetic)
		end
		table.insert(reward.Lines, { Label = label, Sunstones = row.Sunstones or 0 })
	end
	add(standing.Percentile, standing.Percentile.Label)
	if standing.RankReward then
		add(standing.RankReward, standing.RankReward.Label)
	end
	if standing.ClassReward then
		add(standing.ClassReward, (standing.ClassReward.Label:gsub("%%s", className(standing.ClassId))))
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
	return a.Claimed
end

function SeasonRewards.Claimed(profile, seasonId)
	return ledger(profile)[seasonId] == true
end

function SeasonRewards.Claim(profile, seasonId, results, info)
	if SeasonRewards.Claimed(profile, seasonId) then
		return false, "AlreadyClaimed"
	end
	local standing = SeasonRewards.Standing(results, info)
	if not standing.Ranked then
		return false, "NotRanked"
	end
	local reward = SeasonRewards.Reward(standing)
	Premium.AddSunstones(profile, reward.Sunstones)
	local currencies = profile.Season.Currencies
	currencies.Wishstones = (currencies.Wishstones or 0) + reward.Wishstones
	for id, count in pairs(reward.Tickets) do
		Consumables.Grant(profile, id, count)
	end
	for _, title in ipairs(reward.Titles) do
		profile.Permanent.Titles[title] = true
	end
	for _, id in ipairs(reward.Cosmetics) do
		profile.Permanent.Cosmetics[id] = true
	end
	ledger(profile)[seasonId] = true
	-- a small history record for the profile screen
	profile.Permanent.SeasonHistory[tostring(seasonId)] = {
		Percent = standing.Percent, Rank = standing.Rank, ClassRank = standing.ClassRank, Score = standing.Score,
	}
	return true, reward, standing
end

-- Rows for the "how rewards work" panel.
function SeasonRewards.Brackets()
	local out = { Percentiles = {}, Ranks = {}, ClassRanks = {}, MinStage = Config.MinStage }
	for _, row in ipairs(Config.Percentiles) do
		table.insert(out.Percentiles, { Label = row.Label, Sunstones = row.Sunstones, Wishstones = row.Wishstones })
	end
	for _, row in ipairs(Config.Ranks) do
		table.insert(out.Ranks, { Label = row.Label, Sunstones = row.Sunstones, Title = row.Title })
	end
	for _, row in ipairs(Config.ClassRanks) do
		table.insert(out.ClassRanks, { Label = row.Label:gsub("%%s", "class"), Sunstones = row.Sunstones, Title = row.Title })
	end
	return out
end

return SeasonRewards
