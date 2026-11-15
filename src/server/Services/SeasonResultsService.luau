--[[
	SeasonResultsService (ModuleScript)
	Location: ServerScriptService > Server > Services > SeasonResultsService

	Collects what the end-of-season rewards need (see Shared/SeasonRewards) and freezes it when a season ends.

	While a season runs, every minute this server reports its players' furthest stage:
	  * a per-class OrderedDataStore (Leaderboard_S<season>_Class_<class>) holds each player's best stage as that class
	  * a histogram DataStore (SeasonHist_S<season>, key "h") counts players per stage, for the Top 10%..100% brackets
	  (the overall Top 50 comes from the existing Leaderboard_S<season>_Stage board)
	When a season is over, the first call to Results(seasonId) freezes everything into DataStore "SeasonResults", so every
	server and every later login sees the same final numbers.

	  SeasonResultsService.Init()
	  SeasonResultsService.Ended(seasonId)         -> true once the season's EndsAt has passed
	  SeasonResultsService.Live()                  -> frozen-shaped results from the live boards (for the "where am I now" panel)
	  SeasonResultsService.Results(seasonId)       -> frozen results (see SeasonRewards) | nil if the season has not ended
	  SeasonResultsService.InfoFor(userId, seasonId, results, profile) -> { UserId, Score, ClassId } read from the stored boards

	Studio: if DataStores are unavailable it falls back to memory for this server only. NOT yet tested on a live server.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Seasons = require(Shared.Config.Seasons)
local Config = require(Shared.Config.SeasonRewards)
local Classes = require(Shared.Config.Classes)

local DataService = require(script.Parent.DataService)

local SeasonResultsService = {}

local REPORT_SECONDS = 60

local useMemory = false
local initialized = false
local reported = {} -- [userId] = { Score, ClassId } what this server last counted for the player
local pendingHist = {} -- [score] = change not yet saved
local memory = { Hist = {}, Stage = {}, Class = {}, Final = {} } -- Studio fallback: Hist[score]=n, Stage[userId]=n, Class[classId][userId]=n
local frozen = {} -- [seasonId] = results

local function seasonOf(seasonId)
	return Seasons.Seasons[seasonId]
end

function SeasonResultsService.Ended(seasonId)
	local season = seasonOf(seasonId)
	return season ~= nil and os.time() >= season.EndsAt
end

local function stageStore(seasonId)
	return DataStoreService:GetOrderedDataStore(("Leaderboard_S%d_Stage"):format(seasonId))
end
local function classStore(seasonId, classId)
	return DataStoreService:GetOrderedDataStore(("Leaderboard_S%d_Class_%s"):format(seasonId, classId))
end
local function histStore(seasonId)
	return DataStoreService:GetDataStore(("SeasonHist_S%d"):format(seasonId))
end

local function bump(board, userId, value)
	local old = board[userId]
	if old == nil or value > old then
		board[userId] = value
	end
end

-- Report one player's current numbers: best stage overall, best stage as their class, and the histogram move.
local function report(seasonId, userId, score, classId)
	local before = reported[userId]
	if before and before.Score >= score and before.ClassId == classId then
		return
	end
	local ranked = score >= Config.MinStage
	local wasRanked = before ~= nil and before.Score >= Config.MinStage
	if useMemory then
		if ranked then
			bump(memory.Stage, userId, score)
			memory.Class[classId] = memory.Class[classId] or {}
			bump(memory.Class[classId], userId, score)
		end
	elseif ranked then
		local ok, err = pcall(function()
			local function keep(store)
				store:UpdateAsync(tostring(userId), function(old)
					if old ~= nil and old >= score then
						return nil
					end
					return score
				end)
			end
			keep(stageStore(seasonId))
			keep(classStore(seasonId, classId))
		end)
		if not ok then
			warn("[SeasonResultsService] score write failed: " .. tostring(err))
			return -- not counted yet: try again next minute
		end
	end
	-- histogram: move this player from their old score to the new one (only players who reached MinStage count)
	if wasRanked and before.Score ~= score then
		pendingHist[before.Score] = (pendingHist[before.Score] or 0) - 1
	end
	if ranked and (not wasRanked or before.Score ~= score) then
		pendingHist[score] = (pendingHist[score] or 0) + 1
	end
	reported[userId] = { Score = math.max(score, before and before.Score or 0), ClassId = classId }
end

local function flushHistogram(seasonId)
	if next(pendingHist) == nil then
		return
	end
	local delta = pendingHist
	pendingHist = {}
	if useMemory then
		for score, change in pairs(delta) do
			memory.Hist[score] = math.max(0, (memory.Hist[score] or 0) + change)
		end
		return
	end
	local ok, err = pcall(function()
		histStore(seasonId):UpdateAsync("h", function(old)
			local h = old or {}
			for score, change in pairs(delta) do
				local key = tostring(score)
				h[key] = math.max(0, (h[key] or 0) + change)
			end
			return h
		end)
	end)
	if not ok then
		warn("[SeasonResultsService] histogram write failed: " .. tostring(err))
		for score, change in pairs(delta) do -- keep it for the next try
			pendingHist[score] = (pendingHist[score] or 0) + change
		end
	end
end

local function readHistogram(seasonId)
	local out, total = {}, 0
	if useMemory then
		for score, count in pairs(memory.Hist) do
			if count > 0 then
				out[score] = count
				total += count
			end
		end
		return out, total
	end
	local ok, h = pcall(function()
		return histStore(seasonId):GetAsync("h")
	end)
	if ok and type(h) == "table" then
		for key, count in pairs(h) do
			local score = tonumber(key)
			if score and count > 0 then
				out[score] = count
				total += count
			end
		end
	elseif not ok then
		warn("[SeasonResultsService] histogram read failed: " .. tostring(h))
	end
	return out, total
end

-- { [userId] = rank } for the best `limit` of a board
local function topOf(board, limit)
	local ranks = {}
	if useMemory then
		local entries = {}
		for userId, value in pairs(board) do
			table.insert(entries, { UserId = userId, Value = value })
		end
		table.sort(entries, function(a, b)
			if a.Value ~= b.Value then
				return a.Value > b.Value
			end
			return a.UserId < b.UserId
		end)
		for index = 1, math.min(limit, #entries) do
			ranks[entries[index].UserId] = index
		end
		return ranks
	end
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, limit)
	end)
	if not ok then
		warn("[SeasonResultsService] top read failed: " .. tostring(pages))
		return nil
	end
	for index, item in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(item.key)
		if userId then
			ranks[userId] = index
		end
	end
	return ranks
end

local function build(seasonId)
	local histogram, total = readHistogram(seasonId)
	local results = { Total = total, Histogram = histogram, ClassTop = {} }
	results.Top = topOf(useMemory and memory.Stage or stageStore(seasonId), Config.TopKept)
	if results.Top == nil then
		return nil
	end
	for classId in pairs(Classes) do
		local board = if useMemory then (memory.Class[classId] or {}) else classStore(seasonId, classId)
		local top = topOf(board, Config.TopKept)
		if top == nil then
			return nil
		end
		results.ClassTop[classId] = top
	end
	return results
end

function SeasonResultsService.Live()
	return build(Seasons.CurrentSeasonId)
end

function SeasonResultsService.Results(seasonId)
	if frozen[seasonId] then
		return frozen[seasonId]
	end
	if not SeasonResultsService.Ended(seasonId) then
		return nil
	end
	local store = if useMemory then nil else DataStoreService:GetDataStore("SeasonResults")
	local key = "S" .. seasonId
	if useMemory then
		frozen[seasonId] = memory.Final[seasonId]
	else
		local ok, saved = pcall(function()
			return store:GetAsync(key)
		end)
		if ok and type(saved) == "table" then
			-- DataStore keys are strings: turn them back into numbers
			local results = { Total = saved.Total, Histogram = {}, Top = {}, ClassTop = {} }
			for k, v in pairs(saved.Histogram) do
				results.Histogram[tonumber(k)] = v
			end
			for k, v in pairs(saved.Top) do
				results.Top[tonumber(k)] = v
			end
			for classId, ranks in pairs(saved.ClassTop) do
				results.ClassTop[classId] = {}
				for k, v in pairs(ranks) do
					results.ClassTop[classId][tonumber(k)] = v
				end
			end
			frozen[seasonId] = results
		end
	end
	if frozen[seasonId] then
		return frozen[seasonId]
	end
	flushHistogram(seasonId)
	local results = build(seasonId)
	if results == nil then
		return nil
	end
	frozen[seasonId] = results
	if useMemory then
		memory.Final[seasonId] = results
	else
		local function strKeys(map)
			local out = {}
			for k, v in pairs(map) do
				out[tostring(k)] = v
			end
			return out
		end
		local saveable = { Total = results.Total, Histogram = strKeys(results.Histogram), Top = strKeys(results.Top), ClassTop = {} }
		for classId, ranks in pairs(results.ClassTop) do
			saveable.ClassTop[classId] = strKeys(ranks)
		end
		local ok, err = pcall(function()
			-- the first server to finish wins; later ones adopt what is stored
			store:UpdateAsync(key, function(old)
				if old ~= nil then
					return nil
				end
				return saveable
			end)
		end)
		if not ok then
			warn("[SeasonResultsService] could not save frozen results: " .. tostring(err))
		end
	end
	return results
end

-- The player's score and class for a finished season come from the stored boards, not from the profile
-- (the profile's seasonal part is replaced when the next season starts).
function SeasonResultsService.InfoFor(userId, seasonId, results, profile)
	local score = 0
	if useMemory then
		score = memory.Stage[userId] or 0
	else
		local ok, value = pcall(function()
			return stageStore(seasonId):GetAsync(tostring(userId))
		end)
		score = (ok and tonumber(value)) or 0
	end
	-- the class where the player placed best (or their current class when they placed in none)
	local classId, bestRank = profile.Season.ClassId, nil
	for id, ranks in pairs(results.ClassTop) do
		local rank = ranks[userId]
		if rank and (bestRank == nil or rank < bestRank) then
			classId, bestRank = id, rank
		end
	end
	return { UserId = userId, Score = score, ClassId = classId }
end

function SeasonResultsService.Init()
	if initialized then
		return
	end
	initialized = true
	if RunService:IsStudio() then
		local ok = pcall(function()
			DataStoreService:GetOrderedDataStore("__studio_ping"):GetSortedAsync(false, 1)
		end)
		useMemory = not ok
	end
	if useMemory then
		warn("[SeasonResultsService] Studio DataStore access unavailable - season results are kept in memory (nothing is saved).")
	end
	task.spawn(function()
		task.wait(8)
		while true do
			local seasonId = Seasons.CurrentSeasonId
			if not SeasonResultsService.Ended(seasonId) then -- scores stop counting once the season is over
				for _, player in ipairs(Players:GetPlayers()) do
					local profile = DataService.GetProfile(player)
					if profile and profile.Season.SeasonId == seasonId then
						local ok, err = pcall(report, seasonId, player.UserId, math.max(0, math.floor(profile.Season.HighestStage)), profile.Season.ClassId)
						if not ok then
							warn("[SeasonResultsService] report failed: " .. tostring(err))
						end
					end
				end
				flushHistogram(seasonId)
			end
			task.wait(REPORT_SECONDS)
		end
	end)
end

return SeasonResultsService
