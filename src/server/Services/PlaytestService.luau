--[[
	PlaytestService (ModuleScript): the playtest log (rules in Shared/PlaytestLog).

	Collects tester feedback, server and client errors and one line per player visit, buffers them in memory and adds
	them to the DataStore "IPQ_Playtest" (keys "Feedback:<day>", "Errors:<day>", "Sessions:<day>") every 60 s and
	when the server closes. UpdateAsync merges, so every live server adds to the same day lists.
	In Studio without API access it keeps everything in memory (gone when Play stops).

	  PlaytestService.Init()
	  PlaytestService.Feedback(player, profile, topic, text, where) -> ok, reason
	  PlaytestService.ClientError(player, profile, text, where)      -> ok, reason
	  PlaytestService.ServerError(text, where)
	  PlaytestService.Joined(player, profile) / Left(player, profile)
	  PlaytestService.CanRead(player)                                 Studio, or the place's creator (group: rank 254+)
	  PlaytestService.Read(days)                                      -> { Feedback = {...}, Errors = {...}, Sessions = {...}, Days = n, Memory = bool }
	                                                                   (1-3 days, newest first, at most READ_MAX rows per list)
]]
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local STORE_PREFIX = require(Shared.Config.DataStores).Prefix -- every DataStore name starts with it (Config/DataStores)
local PlaytestLog = require(Shared.PlaytestLog)

local PlaytestService = {}

local STORE_NAME = STORE_PREFIX .. "Playtest"
local FLUSH_EVERY = 60
local READ_MAX = 200 -- rows per list sent to the reader (keeps the remote reply small)

local store = nil
local memory = {} -- key -> list (Studio fallback, and what this server already wrote)
local useMemory = false
local pending = {} -- key -> list of entries not yet written
local limits = {}
local visits = {} -- userId -> { Start, Level, Stage }
local initialized = false
local flushing = false

local function day(now)
	return math.floor(now / 86400)
end

local function add(entry)
	if not entry then
		return
	end
	local key = PlaytestLog.Key(PlaytestLog.Bucket(entry.Kind), day(entry.At))
	-- the same error repeated is counted, not stored again (a loop that errors every frame stays one line)
	pending[key] = PlaytestLog.Merge(pending[key], entry, 300)
end

local function keepFor(key)
	return PlaytestLog.KEEP[key:match("^(%a+)")] or 300
end

local function flush()
	if flushing then
		return
	end
	flushing = true
	local batch = pending
	pending = {}
	for key, entries in pairs(batch) do
		local function merge(old)
			local list = if type(old) == "table" then table.clone(old) else {}
			for _, entry in ipairs(entries) do
				list = PlaytestLog.Merge(list, table.clone(entry), keepFor(key))
			end
			return list
		end
		if useMemory then
			memory[key] = merge(memory[key])
		else
			local ok, err = pcall(function()
				store:UpdateAsync(key, merge)
			end)
			if not ok then
				-- try again next time (keep the newest few hundred so a broken store cannot eat memory)
				print("[PlaytestService] could not write " .. key .. ": " .. tostring(err))
				pending[key] = pending[key] or {}
				for _, entry in ipairs(entries) do
					table.insert(pending[key], entry)
				end
				while #pending[key] > 300 do
					table.remove(pending[key], 1)
				end
			end
		end
	end
	flushing = false
end

local function whoInfo(player, profile)
	local info = { UserId = player.UserId, Name = player.Name }
	local season = profile and profile.Season
	if season then
		info.Level = season.Level
		info.Stage = season.HighestStage
		info.Class = season.ClassId
	end
	return info
end

function PlaytestService.Init()
	if initialized then
		return
	end
	initialized = true
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME)
		if RunService:IsStudio() then
			store:GetAsync("__studio_ping")
		end
	end)
	useMemory = not ok
	-- every server script error (handlers that throw are reported by ApiService, which catches them)
	ScriptContext.Error:Connect(function(message, trace, source)
		local where = if typeof(source) == "Instance" then source:GetFullName() else nil
		PlaytestService.ServerError(tostring(message) .. " | " .. tostring(trace or ""), where)
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			pcall(flush)
		end
	end)
	game:BindToClose(function()
		for userId, visit in pairs(visits) do
			-- players still here when the server closes (PlayerRemoving may not run in time)
			add(PlaytestLog.Entry("Session", { UserId = userId, Name = visit.Name, Minutes = (os.time() - visit.Start) / 60, LevelFrom = visit.Level, StageFrom = visit.Stage, Level = visit.Level, Stage = visit.Stage, Extra = "server closed" }, os.time()))
		end
		visits = {}
		pcall(flush)
	end)
end

function PlaytestService.Feedback(player, profile, topic, text, where)
	local entryInfo = whoInfo(player, profile)
	entryInfo.Topic = topic
	entryInfo.Text = text
	entryInfo.Where = where
	local entry = PlaytestLog.Entry("Feedback", entryInfo, os.time())
	if not entry then
		return false, "Empty"
	end
	local ok, reason = PlaytestLog.Allow(limits, player.UserId, "Feedback", os.time())
	if not ok then
		return false, reason
	end
	add(entry)
	task.spawn(pcall, flush) -- feedback is rare and precious: write it now
	return true
end

function PlaytestService.ClientError(player, profile, text, where)
	if not PlaytestLog.Allow(limits, player.UserId, "ClientError", os.time()) then
		return false, "TooMany"
	end
	local info = whoInfo(player, profile)
	info.Text = text
	info.Where = where
	add(PlaytestLog.Entry("ClientError", info, os.time()))
	return true
end

function PlaytestService.ServerError(text, where)
	add(PlaytestLog.Entry("ServerError", { Text = text, Where = where }, os.time()))
end

function PlaytestService.Joined(player, profile)
	local info = whoInfo(player, profile)
	visits[player.UserId] = { Start = os.time(), Level = info.Level, Stage = info.Stage, Name = player.Name }
end

function PlaytestService.Left(player, profile)
	local visit = visits[player.UserId]
	visits[player.UserId] = nil
	limits[player.UserId] = nil
	if not visit then
		return
	end
	local info = whoInfo(player, profile)
	info.Minutes = (os.time() - visit.Start) / 60
	info.LevelFrom = visit.Level
	info.StageFrom = visit.Stage
	add(PlaytestLog.Entry("Session", info, os.time()))
end

local readers = {} -- userId -> true/false (GetRankInGroup yields, so ask once)
function PlaytestService.CanRead(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if readers[player.UserId] == nil then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		readers[player.UserId] = ok and rank >= 254
	end
	return readers[player.UserId]
end

-- the last `days` days (today first), newest entries first, with this server's unsaved ones included
function PlaytestService.Read(days)
	days = math.clamp(math.floor(tonumber(days) or 1), 1, 3)
	pcall(flush)
	local out = { Feedback = {}, Errors = {}, Sessions = {}, Days = days, Memory = useMemory }
	local today = day(os.time())
	for d = today, today - days + 1, -1 do
		for bucket, list in pairs(out) do
			if type(list) == "table" then
				local key = PlaytestLog.Key(bucket, d)
				local rows
				if useMemory then
					rows = memory[key]
				else
					local ok, value = pcall(function()
						return store:GetAsync(key)
					end)
					rows = if ok then value else nil
				end
				for _, entry in ipairs(pending[key] or {}) do
					rows = PlaytestLog.Merge(if rows then table.clone(rows) else {}, table.clone(entry), keepFor(key))
				end
				for i = #(rows or {}), 1, -1 do
					if #list < READ_MAX then
						table.insert(list, rows[i])
					end
				end
			end
		end
	end
	return out
end

return PlaytestService
