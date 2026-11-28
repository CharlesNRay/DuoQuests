--[[
	LeaderboardService (ModuleScript)
	Location: ServerScriptService > Server > Services > LeaderboardService

	Season leaderboards (see Shared/Leaderboards for the rules). Scores live in
	OrderedDataStores, one per season and category, so every server shares one
	board. Every minute this server writes the scores of its players (only when
	they went up, and not after the season ended) and reads up to
	READS_PER_REFRESH boards in turn (GetSortedAsync budget), so each board's
	cached top list is at most a few minutes old. These boards are also the
	season reward boards (SeasonResultsService reads them; it no longer writes).

	  LeaderboardService.Init(onRefresh)     onRefresh(textByCategory) is called after each
	                                         refresh (the hub sign uses it)
	  LeaderboardService.Get(categoryId, userId)
	                                         -> { Rows = top rows (with Rank, Name, Value),
	                                              Mine = { Rank?, Value } }

	Studio: if DataStores are unavailable it falls back to an in-memory board
	for this server only (nothing is saved). NOT yet tested on a live server.
	Names are looked up with Players:GetNameFromUserIdAsync and cached.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local STORE_PREFIX = require(Shared.Config.DataStores).Prefix -- every DataStore name starts with it (Config/DataStores)
local Leaderboards = require(Shared.Leaderboards)
local SeasonClock = require(Shared.SeasonClock)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH_SECONDS = 60
local TOP = 10
-- GetSortedAsync is the scarcest DataStore budget (5 + 2 per player a minute per server, shared with the season
-- results). Each refresh reads at most this many boards, in turn, and leaves RESERVE requests for the Season screen.
local READS_PER_REFRESH = 3
local RESERVE = 3

local stores = {} -- [categoryId] = OrderedDataStore of the current season
local storeSeason = nil -- the season `stores`, `written`, `cache` and `memory` belong to
local memory = {} -- [categoryId] = { [userId] = value }
local useMemory = false
local written = {} -- [categoryId] = { [userId] = last value written }
local cache = {} -- [categoryId] = { Rows, At }
local names = {} -- [userId] = name
local refreshCallback = nil
local initialized = false
local nextRead = 1 -- the category the next refresh reads first

local function storeName(seasonId, categoryId)
	return (STORE_PREFIX .. "Leaderboard_S%d_%s"):format(seasonId, categoryId)
end

-- a test season (Studio cheat) never touches the real boards
local function inMemory()
	return useMemory or SeasonClock.IsTest()
end

-- The season can change while the server runs: new boards, and nothing remembered from the old season (a level 1 hero
-- must be written to the new board even though its old score was higher).
local function syncSeason()
	local id = SeasonClock.CurrentId()
	if id ~= storeSeason then
		storeSeason = id
		stores, written, cache, memory = {}, {}, {}, {}
		if not inMemory() then
			for _, category in ipairs(Leaderboards.Categories) do
				stores[category.Id] = DataStoreService:GetOrderedDataStore(storeName(id, category.Id))
			end
		end
	end
	return id
end

local function sortedBudget()
	if inMemory() then
		return math.huge
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)
	end)
	return if ok then budget else 0
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then result else "Player " .. tostring(userId)
	return names[userId]
end

local function writeScore(categoryId, userId, value)
	if inMemory() then
		local board = memory[categoryId] or {}
		memory[categoryId] = board
		local current = board[userId]
		board[userId] = if current and current > value then current else value
		return true
	end
	local ok, err = pcall(function()
		stores[categoryId]:UpdateAsync(tostring(userId), function(old)
			if old ~= nil and old >= value then
				return nil -- keep the better score (returning nil cancels the write)
			end
			return value
		end)
	end)
	if not ok then
		warn("[LeaderboardService] write failed: " .. tostring(err))
	end
	return ok
end

local function fetchTop(categoryId)
	if inMemory() then
		local entries = {}
		for userId, value in pairs(memory[categoryId] or {}) do
			table.insert(entries, { UserId = userId, Name = nameOf(userId), Value = value })
		end
		return Leaderboards.Rank(entries, TOP)
	end
	local ok, pages = pcall(function()
		return stores[categoryId]:GetSortedAsync(false, TOP)
	end)
	if not ok then
		warn("[LeaderboardService] read failed: " .. tostring(pages))
		return nil
	end
	local entries = {}
	for _, item in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { UserId = userId, Name = nameOf(userId), Value = item.value })
		end
	end
	return Leaderboards.Rank(entries, TOP)
end

local function refresh()
	local seasonId = syncSeason()
	-- after a season's end the boards are final (the season rewards read them); a new season gets new boards
	local open = not SeasonClock.Ended(seasonId)
	local categories = Leaderboards.Categories
	if open then
		for _, category in ipairs(categories) do
			local id = category.Id
			written[id] = written[id] or {}
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile and profile.Season.SeasonId == seasonId then
					local score = Leaderboards.ScoreFor(id, profile)
					if (written[id][player.UserId] or 0) < score then
						if writeScore(id, player.UserId, score) then
							written[id][player.UserId] = score
						end
					end
				end
			end
		end
	end
	-- read a few boards, in turn, while the budget allows
	local reads = 0
	for _ = 1, #categories do
		if reads >= READS_PER_REFRESH or sortedBudget() <= RESERVE then
			break
		end
		local id = categories[nextRead].Id
		nextRead = nextRead % #categories + 1
		local rows = fetchTop(id)
		reads += 1
		if rows then
			cache[id] = { Rows = rows, At = os.clock() }
		end
	end
	local text = {}
	for _, category in ipairs(categories) do
		local lines = { category.Name }
		for _, row in ipairs((cache[category.Id] and cache[category.Id].Rows) or {}) do
			table.insert(lines, ("%d. %s  %d"):format(row.Rank, row.Name, row.Value))
		end
		text[category.Id] = table.concat(lines, "\n")
	end
	if refreshCallback then
		refreshCallback(text)
	end
end

function LeaderboardService.Get(categoryId, userId)
	if not Leaderboards.IsCategory(categoryId) then
		return nil
	end
	local entry = cache[categoryId]
	local rows = entry and entry.Rows or {}
	local mine = { Value = nil, Rank = Leaderboards.PositionOf(rows, userId) }
	local player = Players:GetPlayerByUserId(userId)
	local profile = player and DataService.GetProfile(player)
	if profile then
		mine.Value = Leaderboards.ScoreFor(categoryId, profile)
	end
	return { Rows = rows, Mine = mine }
end

function LeaderboardService.Init(onRefresh)
	if initialized then
		return
	end
	initialized = true
	refreshCallback = onRefresh

	if RunService:IsStudio() then
		local ok = pcall(function()
			DataStoreService:GetOrderedDataStore("__studio_ping"):GetSortedAsync(false, 1)
		end)
		useMemory = not ok
	end
	if useMemory then
		warn("[LeaderboardService] Studio DataStore access unavailable - using an in-memory board (nothing is saved).")
	end
	syncSeason()

	task.spawn(function()
		task.wait(5) -- let the first profiles load
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[LeaderboardService] refresh failed: " .. tostring(err))
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
