--[[
	DataService (ModuleScript)
	Location: ServerScriptService > Server > Services > DataService

	Loads, saves and protects player profiles.

	How it protects data:
	  * Session locking: each stored record carries a lock naming the server
	    (JobId) that currently owns it. Another server will not load the data
	    until the lock is released or goes stale (LOCK_TIMEOUT seconds), so a
	    player can never be edited from two servers at once.
	  * All reads/writes use UpdateAsync, which is atomic.
	  * Saves refuse to overwrite data if the lock was taken by another server.
	  * Profiles from a NEWER schema than this server understands are refused,
	    which protects data if you ever roll the game back.

	Public API:
	  DataService.Init()
	  DataService.LoadProfile(player)   -> profile table, or nil + reason
	  DataService.GetProfile(player)    -> profile table or nil
	  DataService.ReleaseProfile(player)-- final save + release the lock

	Studio note: if Studio API access is off (or the place is unpublished),
	the service falls back to an in-memory store so you can still test. Data
	then resets on every playtest. To test real saving, publish the place and
	enable Game Settings > Security > "Enable Studio Access to API Services".
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.ProfileTemplate)
local TableUtil = require(Shared.Util.TableUtil)

local DATASTORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- seconds between autosaves (also refreshes the lock)
local LOCK_TIMEOUT = 300 -- a lock older than this is treated as a crashed server
local MAX_ATTEMPTS = 3 -- DataStore call retries
local LOCK_WAIT_ATTEMPTS = 6 -- how many times to wait for another server to release
local LOCK_WAIT_SECONDS = 3

-- Studio has an empty JobId; give it a stable name so locks still work.
local SERVER_ID = if game.JobId ~= "" then game.JobId else "studio"

local DataService = {}

local store = nil
local useMemory = false
local memory = {} -- used only when the real DataStore is unavailable in Studio
local sessions = {} -- [userId] = { Data, Key, Saving, LockLost }
local loading = {} -- [userId] = true while a load is in flight
local activeReleases = 0
local initialized = false

-- Migrations convert old profiles one version at a time.
-- Migrations[2] = function(data) ... end upgrades version 1 -> 2, and so on.
local Migrations = {}

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

-- Single doorway for UpdateAsync so the memory fallback runs the exact same
-- lock logic as the real DataStore. Returns (ok, result).
local function updateAsync(key, transform)
	if useMemory then
		local current = memory[key]
		local result = transform(if current ~= nil then TableUtil.DeepCopy(current) else nil)
		if result ~= nil then
			memory[key] = TableUtil.DeepCopy(result)
		end
		return true, result
	end
	return pcall(function()
		return store:UpdateAsync(key, transform)
	end)
end

-- NOTE: UpdateAsync may run `transform` more than once, so transforms must not
-- have side effects other than setting flags that they reset on every run.
local function updateWithRetry(key, transform)
	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = updateAsync(key, transform)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[DataService] %s failed (attempt %d/%d): %s"):format(key, attempt, MAX_ATTEMPTS, tostring(result)))
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

local function migrate(data)
	local version = data.SchemaVersion or 0
	if version > ProfileTemplate.CURRENT_VERSION then
		return false
	end
	while version < ProfileTemplate.CURRENT_VERSION do
		version += 1
		local step = Migrations[version]
		if step then
			step(data)
		end
		data.SchemaVersion = version
	end
	return true
end

-- One save. `release` = true also clears the session lock (player leaving).
local function saveSession(userId, session, release)
	if session.LockLost or session.Saving then
		return false
	end
	session.Saving = true

	local lostLock = false
	local ok = updateWithRetry(session.Key, function(old)
		lostLock = false
		if old ~= nil then
			local lock = old.SessionLock
			if lock == nil or lock.JobId ~= SERVER_ID then
				-- Someone else owns this data now. Do NOT overwrite it.
				lostLock = true
				return nil
			end
		end
		session.Data.Meta.LastSaveAt = os.time()
		return {
			Data = session.Data,
			SessionLock = if release then nil else { JobId = SERVER_ID, Timestamp = os.time() },
		}
	end)

	session.Saving = false

	if lostLock then
		session.LockLost = true
		warn(("[DataService] Lost session lock for %d; discarding this server's copy"):format(userId))
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
		return false
	end

	return ok
end

local function releaseUserId(userId)
	local session = sessions[userId]
	if not session then
		return
	end
	sessions[userId] = nil -- no new reads or autosaves from here on
	activeReleases += 1

	local success, err = pcall(function()
		while session.Saving do
			task.wait()
		end
		session.Data.Meta.LastLogoutAt = os.time()
		saveSession(userId, session, true)
	end)
	if not success then
		warn(("[DataService] Release failed for %d: %s"):format(userId, tostring(err)))
	end

	activeReleases -= 1
end

function DataService.Init()
	if initialized then
		return
	end
	initialized = true

	if RunService:IsStudio() then
		local ok = pcall(function()
			store = DataStoreService:GetDataStore(DATASTORE_NAME)
			store:GetAsync("__studio_ping")
		end)
		if not ok then
			useMemory = true
			warn("[DataService] Studio DataStore access unavailable - using in-memory data (nothing will be saved).")
		end
	else
		store = DataStoreService:GetDataStore(DATASTORE_NAME)
	end

	-- Autosave loop. Also refreshes each session's lock timestamp.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for userId, session in pairs(sessions) do
				task.spawn(saveSession, userId, session, false)
			end
		end
	end)

	-- On shutdown, save and release everyone and wait until finished.
	game:BindToClose(function()
		for userId in pairs(table.clone(sessions)) do
			task.spawn(releaseUserId, userId)
		end
		while activeReleases > 0 do
			task.wait()
		end
	end)
end

-- Returns the profile table (the same table the rest of the game edits), or
-- nil plus a reason string. The caller should kick the player on nil.
function DataService.LoadProfile(player)
	local userId = player.UserId
	if sessions[userId] or loading[userId] then
		return if sessions[userId] then sessions[userId].Data else nil, "AlreadyLoading"
	end
	loading[userId] = true

	local key = keyFor(userId)
	local blocked = false
	local record = nil
	local lastError = nil

	for _ = 1, LOCK_WAIT_ATTEMPTS do
		blocked = false
		local ok, result = updateWithRetry(key, function(old)
			local now = os.time()
			if old == nil then
				blocked = false
				return {
					Data = ProfileTemplate.New(),
					SessionLock = { JobId = SERVER_ID, Timestamp = now },
				}
			end
			local lock = old.SessionLock
			if lock ~= nil and lock.JobId ~= SERVER_ID and (now - lock.Timestamp) < LOCK_TIMEOUT then
				blocked = true
				return nil -- cancel: another live server owns this player
			end
			blocked = false
			old.SessionLock = { JobId = SERVER_ID, Timestamp = now }
			return old
		end)

		if not ok then
			lastError = "DataStoreError"
			break
		end
		if not blocked then
			record = result
			break
		end
		lastError = "SessionLocked"
		task.wait(LOCK_WAIT_SECONDS)
	end

	loading[userId] = nil

	if record == nil then
		return nil, lastError or "Unknown"
	end

	local data = record.Data
	if type(data) ~= "table" or not migrate(data) then
		warn(("[DataService] Profile for %d has a newer schema than this server; refusing to load"):format(userId))
		-- Leave the lock to expire rather than risk saving over newer data.
		return nil, "NewerSchema"
	end
	TableUtil.Reconcile(data, ProfileTemplate.New())

	-- Player may have left while we were loading.
	if player.Parent == nil then
		sessions[userId] = { Data = data, Key = key }
		releaseUserId(userId)
		return nil, "PlayerLeft"
	end

	sessions[userId] = { Data = data, Key = key }
	return data
end

function DataService.GetProfile(player)
	local session = sessions[player.UserId]
	return if session then session.Data else nil
end

function DataService.ReleaseProfile(player)
	releaseUserId(player.UserId)
end

return DataService
