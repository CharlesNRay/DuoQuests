--[[
	SeasonResultsService (ModuleScript)
	Location: ServerScriptService > Server > Services > SeasonResultsService

	Collects what the end-of-season rewards need (see Shared/SeasonRewards) and freezes it when a season ends.

	While a season runs, every minute this server reports its players' furthest stage:
	  * the per-class OrderedDataStores (Leaderboard_S<season>_Class_<class>) and the overall Stage board are written by
	    LeaderboardService (same stores); this service only reads them
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
local STORE_PREFIX = require(Shared.Config.DataStores).Prefix -- every DataStore name starts with it (Config/DataStores)
local SeasonClock = require(Shared.SeasonClock)
local SeasonHistogram = require(Shared.SeasonHistogram)
local Config = require(Shared.Config.SeasonRewards)
local Classes = require(Shared.Config.Classes)

local DataService = require(script.Parent.DataService)

local SeasonResultsService = {}

local REPORT_SECONDS = 60

local useMemory = false
local initialized = false
-- Each PLAYER counts once in the histogram (Shared/SeasonHistogram: the counted score lives in their save).
local inflightBy = {} -- [seasonId] = { [userId] = { Profile, Score } }
local pendingBy = {} -- [seasonId] = { [score] = change not yet saved }
-- Studio fallback (and every test season started by the Studio cheat): memory[seasonId] = { Hist, Stage, Class }
local memory = {}
local memoryFinal = {} -- [seasonId] = frozen results kept in memory
local frozen = {} -- [seasonId] = results

-- A test season (SeasonClock.StartNext, Studio cheat) never touches the real DataStores: with Studio API access on they
-- are the live game's stores, and a frozen season result can never be undone.
local function inMemory()
	return useMemory or SeasonClock.IsTest()
end

local function mem(seasonId)
	local m = memory[seasonId]
	if m == nil then
		m = { Hist = {}, Stage = {}, Class = {} }
		memory[seasonId] = m
	end
	return m
end

local function inflightOf(seasonId)
	inflightBy[seasonId] = inflightBy[seasonId] or {}
	return inflightBy[seasonId]
end

local function pendingOf(seasonId)
	pendingBy[seasonId] = pendingBy[seasonId] or {}
	return pendingBy[seasonId]
end

function SeasonResultsService.Ended(seasonId)
	return SeasonClock.Ended(seasonId)
end

local function stageStore(seasonId)
	return DataStoreService:GetOrderedDataStore((STORE_PREFIX .. "Leaderboard_S%d_Stage"):format(seasonId))
end
local function classStore(seasonId, classId)
	return DataStoreService:GetOrderedDataStore((STORE_PREFIX .. "Leaderboard_S%d_Class_%s"):format(seasonId, classId))
end
local function histStore(seasonId)
	return DataStoreService:GetDataStore((STORE_PREFIX .. "SeasonHist_S%d"):format(seasonId))
end

local function bump(board, userId, value)
	local old = board[userId]
	if old == nil or value > old then
		board[userId] = value
	end
end

-- Report one player's current numbers: the histogram move (and, in memory mode, the boards LeaderboardService keeps
-- for real stores).
local function report(seasonId, profile, userId, score, classId)
	local ranked = score >= Config.MinStage
	if ranked and inMemory() then
		local m = mem(seasonId)
		bump(m.Stage, userId, score)
		m.Class[classId] = m.Class[classId] or {}
		bump(m.Class[classId], userId, score)
	end
	SeasonHistogram.Move(pendingOf(seasonId), inflightOf(seasonId), profile, seasonId, userId, score, Config.MinStage)
end

-- a player who left during the write has had their last save: their moves are undone instead (SeasonHistogram.Commit)
local function isLive(userId, profile)
	local player = Players:GetPlayerByUserId(userId)
	return player ~= nil and DataService.GetProfile(player) == profile
end

local function commitInflight(seasonId)
	SeasonHistogram.Commit(inflightOf(seasonId), seasonId, isLive, pendingOf(seasonId))
end

local function flushHistogram(seasonId)
	local delta = pendingOf(seasonId)
	if next(delta) == nil then
		return
	end
	pendingBy[seasonId] = {}
	if inMemory() then
		local hist = mem(seasonId).Hist
		for score, change in pairs(delta) do
			hist[score] = math.max(0, (hist[score] or 0) + change)
		end
		if not SeasonClock.IsTest() then -- a test season's counts must not reach the saved profile
			commitInflight(seasonId)
		else
			inflightBy[seasonId] = {}
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
	if ok then
		commitInflight(seasonId)
	else
		warn("[SeasonResultsService] histogram write failed: " .. tostring(err))
		local pendingHist = pendingOf(seasonId)
		for score, change in pairs(delta) do -- keep it for the next try
			pendingHist[score] = (pendingHist[score] or 0) + change
		end
	end
end

local function readHistogram(seasonId)
	local out, total = {}, 0
	if inMemory() then
		for score, count in pairs(mem(seasonId).Hist) do
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
	if type(board) == "table" then -- a memory board
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
	results.Top = topOf(if inMemory() then mem(seasonId).Stage else stageStore(seasonId), Config.TopKept)
	if results.Top == nil then
		return nil
	end
	for classId in pairs(Classes) do
		local board = if inMemory() then (mem(seasonId).Class[classId] or {}) else classStore(seasonId, classId)
		local top = topOf(board, Config.TopKept)
		if top == nil then
			return nil
		end
		results.ClassTop[classId] = top
	end
	return results
end

-- Live standings read 1 + one board per class with GetSortedAsync (the scarcest budget): only when the budget has room,
-- else nil (ApiService keeps showing its last copy).
function SeasonResultsService.Live()
	if not inMemory() then
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)
		end)
		local needed = 1
		for _ in pairs(Classes) do
			needed += 1
		end
		if not ok or budget < needed + 1 then
			return nil
		end
	end
	return build(SeasonClock.CurrentId())
end

function SeasonResultsService.Results(seasonId)
	if frozen[seasonId] then
		return frozen[seasonId]
	end
	if not SeasonResultsService.Ended(seasonId) then
		return nil
	end
	local memoryMode = inMemory()
	local store = if memoryMode then nil else DataStoreService:GetDataStore(STORE_PREFIX .. "SeasonResults")
	local key = "S" .. seasonId
	if memoryMode then
		frozen[seasonId] = memoryFinal[seasonId]
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
	if memoryMode then
		memoryFinal[seasonId] = results
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
	if inMemory() then
		score = mem(seasonId).Stage[userId] or 0
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

-- Studio cheat: count a player's current numbers for a season right now (in memory while a test season runs).
function SeasonResultsService.ReportNow(seasonId, profile, userId)
	-- test seasons start a fresh memory histogram, so the player's real counted score must not hide this one
	local saved = profile.Permanent.SeasonHist
	profile.Permanent.SeasonHist = nil
	report(seasonId, profile, userId, math.max(0, math.floor(profile.Season.HighestStage)), profile.Season.ClassId)
	flushHistogram(seasonId)
	profile.Permanent.SeasonHist = saved
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
			local seasonId = SeasonClock.CurrentId()
			if not SeasonResultsService.Ended(seasonId) then -- scores stop counting once the season is over
				for _, player in ipairs(Players:GetPlayers()) do
					local profile = DataService.GetProfile(player)
					if profile and profile.Season.SeasonId == seasonId and profile.Permanent.Character and profile.Permanent.Character.Created then
						local ok, err = pcall(report, seasonId, profile, player.UserId, math.max(0, math.floor(profile.Season.HighestStage)), profile.Season.ClassId)
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
