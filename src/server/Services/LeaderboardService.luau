--[[
	LeaderboardService (ModuleScript)
	Location: ServerScriptService > Server > Services > LeaderboardService

	Season leaderboards (see Shared/Leaderboards for the rules). Scores live in
	OrderedDataStores, one per season and category, so every server shares one
	board. Every minute this server writes the scores of its players (only when
	they went up) and refreshes a cached top list.

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
local Leaderboards = require(Shared.Leaderboards)
local Seasons = require(Shared.Config.Seasons)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH_SECONDS = 60
local TOP = 10

local stores = {} -- [categoryId] = OrderedDataStore, or nil in memory mode
local memory = {} -- [categoryId] = { [userId] = value }
local useMemory = false
local written = {} -- [categoryId] = { [userId] = last value written }
local cache = {} -- [categoryId] = { Rows, At }
local names = {} -- [userId] = name
local refreshCallback = nil
local initialized = false

local function storeName(categoryId)
	return ("Leaderboard_S%d_%s"):format(Seasons.CurrentSeasonId, categoryId)
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
	if useMemory then
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
	if useMemory then
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
	local text = {}
	for _, category in ipairs(Leaderboards.Categories) do
		local id = category.Id
		-- write this server's players
		written[id] = written[id] or {}
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.GetProfile(player)
			if profile then
				local score = Leaderboards.ScoreFor(id, profile)
				if (written[id][player.UserId] or 0) < score then
					if writeScore(id, player.UserId, score) then
						written[id][player.UserId] = score
					end
				end
			end
		end
		local rows = fetchTop(id)
		if rows then
			cache[id] = { Rows = rows, At = os.clock() }
		end
		local lines = { category.Name }
		for _, row in ipairs((cache[id] and cache[id].Rows) or {}) do
			table.insert(lines, ("%d. %s  %d"):format(row.Rank, row.Name, row.Value))
		end
		text[id] = table.concat(lines, "\n")
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
	else
		for _, category in ipairs(Leaderboards.Categories) do
			stores[category.Id] = DataStoreService:GetOrderedDataStore(storeName(category.Id))
		end
	end

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
