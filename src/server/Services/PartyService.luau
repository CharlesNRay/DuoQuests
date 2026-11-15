--[[
	PartyService (ModuleScript)
	Location: ServerScriptService > Server > Services > PartyService

	Runs parties on this server: saves them, hosts them, runs the stage loop,
	pays rewards, and handles creating, joining (by code) and leaving.
	The rules live in Shared/Party and Services/PartyCore (both tested without
	Roblox). This file only connects them to Roblox: DataStores, the timer loop,
	players and teleports. Keep it thin.

	How a party runs
	  * Every player always has a party (a solo one is made for new players).
	  * A party is HOSTED by one server at a time. If a player joins a server and
	    their party is hosted on another live server, they are teleported there.
	  * The host runs one stage fight at a time. A fight is resolved instantly,
	    then the party "waits out" the fight's duration plus the pause between
	    fights, so real time matches the pacing the economy was tuned against.
	  * While only one member is online they fight with the partner's ghost.
	  * Party records are saved at most every SAVE_INTERVAL seconds (DataStore
	    writes to one key are rate limited) and when a player leaves.

	Public API (called from Main and, later, the client remotes)
	  PartyService.Init()
	  PartyService.OnPlayerReady(player, profile)   after the profile is loaded
	  PartyService.OnPlayerLeaving(player)          BEFORE the profile is released
	  PartyService.CreateCode(player)               -> true, code, expiresAt | false, reason
	  PartyService.JoinByCode(player, code)         -> true | false, reason
	  PartyService.Leave(player)                    -> true | false, reason
	  PartyService.RefreshSnapshot(player)          call after a player changes their build
	  PartyService.SetUltimate(player, ultimateId)  -> true | false, reason (either member)
	  PartyService.SetGhostLoadout(player, targetUserId, abilityIds)
	                                                -> true | false, reason (skills only)
	  PartyService.RevertGhostLoadout(player)       -> true | false, reason (owner undoes the last edit)
	  PartyService.GetState(player)                 -> table for the UI, or nil
	  PartyService.GetLastClaim(player)             -> what they were paid at login

	Studio: like DataService, falls back to in-memory stores if Studio cannot use
	DataStores (nothing is saved). The teleport path only runs in a live game and
	has NOT been tested yet.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared.Party)
local Pets = require(Shared.Pets)
local Hero = require(Shared.Hero)
local OfflineConfig = require(Shared.Config.Offline)
local Seasons = require(Shared.Config.Seasons)
local TableUtil = require(Shared.Util.TableUtil)
local PartyCore = require(script.Parent.PartyCore)

local PARTY_STORE = "Parties_v1"
local CODE_STORE = "PartyCodes_v1"
local LOOP_INTERVAL = 1 -- seconds between checks of the hosted parties
local SAVE_INTERVAL = 30 -- seconds between saves of a changed party
local HEARTBEAT_INTERVAL = PartyCore.HOST_TIMEOUT / 3 -- keeps the host lock fresh
local MAX_ATTEMPTS = 3

local SERVER_ID = if game.JobId ~= "" then game.JobId else "studio"

local PartyService = {}

local deps = nil
local initialized = false
local hosted = {} -- [partyId] = { Record, Online = {[userId] = {Player, Profile, Name}}, NextFightAt, NextSaveAt, Dirty, Saving }
local partyOf = {} -- [userId] = partyId
local lastClaim = {} -- [userId] = what the player was paid at login
local fightListener = nil -- function(record, outcome, onlineList, waitSeconds), set by ApiService

-- Stores ----------------------------------------------------------------------------------

local function retry(label, fn)
	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[PartyService] %s failed (attempt %d/%d): %s"):format(label, attempt, MAX_ATTEMPTS, tostring(result)))
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

local function newDataStoreStore(name)
	local dataStore = DataStoreService:GetDataStore(name)
	local store = {}
	function store:Get(key)
		return retry("Get " .. key, function()
			return dataStore:GetAsync(key)
		end)
	end
	function store:Update(key, transform)
		return retry("Update " .. key, function()
			return dataStore:UpdateAsync(key, transform)
		end)
	end
	function store:Remove(key)
		return (retry("Remove " .. key, function()
			dataStore:RemoveAsync(key)
		end))
	end
	return store
end

local function newMemoryStore()
	local data = {}
	local store = {}
	function store:Get(key)
		return true, if data[key] ~= nil then TableUtil.DeepCopy(data[key]) else nil
	end
	function store:Update(key, transform)
		local result = transform(if data[key] ~= nil then TableUtil.DeepCopy(data[key]) else nil)
		if result ~= nil then
			data[key] = TableUtil.DeepCopy(result)
		end
		return true, result
	end
	function store:Remove(key)
		data[key] = nil
		return true
	end
	return store
end

-- Helpers -----------------------------------------------------------------------------------

local function now()
	return os.time()
end

local function managedSet(entry)
	local set = {}
	for userId in pairs(entry.Online) do
		set[tostring(userId)] = true
	end
	return set
end

local function onlineList(entry)
	local list = {}
	for userId, online in pairs(entry.Online) do
		table.insert(list, { UserId = userId, Name = online.Name, Profile = online.Profile })
	end
	return list
end

local function partnerIsOnline(entry, userId)
	for otherId in pairs(entry.Online) do
		if otherId ~= userId then
			return true
		end
	end
	return false
end

-- Saving and adopting changes ---------------------------------------------------------------

local attach -- forward declaration

-- Writes the hosted party. If someone joined or left on another server, adopts
-- the stored record. If this server lost the host lock, re-attaches its players.
local function saveEntry(entry)
	if entry.Saving or entry.Dead then
		return
	end
	entry.Saving = true
	local ok, record, membershipChanged = PartyCore.SaveProgress(deps, entry.Record, managedSet(entry))
	entry.Saving = false

	if ok then
		entry.Dirty = false
		entry.NextSaveAt = now() + SAVE_INTERVAL
		if membershipChanged then
			entry.Record = record
			-- Drop anyone who is no longer a member of this party.
			for userId in pairs(table.clone(entry.Online)) do
				if record.Members[1] ~= userId and record.Members[2] ~= userId then
					entry.Online[userId] = nil
				end
			end
		end
	elseif record == "LostHost" then
		warn("[PartyService] Lost the host lock for party " .. entry.Record.PartyId .. "; re-attaching its players")
		entry.Dead = true
		hosted[entry.Record.PartyId] = nil
		for _, online in pairs(entry.Online) do
			task.spawn(attach, online.Player, online.Profile)
		end
	elseif record == "NoParty" then
		entry.Dead = true
		hosted[entry.Record.PartyId] = nil
	else
		warn("[PartyService] Could not save party " .. entry.Record.PartyId .. ": " .. tostring(record))
	end
end

-- Attaching players ----------------------------------------------------------------------------

local function sendToHost(player, hostInfo)
	if RunService:IsStudio() then
		warn("[PartyService] Party is hosted on another server; teleport skipped in Studio.")
		return
	end
	-- UNTESTED: sends the player to the server that is running their party.
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, hostInfo.JobId, player)
	end)
	if not ok then
		warn("[PartyService] Teleport to party host failed: " .. tostring(err))
	end
end

-- Puts a player into their party on this server (becoming host if nobody is),
-- starts their session and pays what they are owed.
function attach(player, profile)
	local userId = player.UserId
	local partyId = profile.Permanent.PartyId
	local entry = hosted[partyId]

	if entry then
		-- Already hosted here: re-read the stored record in case membership changed.
		local ok, record = PartyCore.Get(deps, partyId)
		if not ok then
			warn("[PartyService] Could not reload party " .. tostring(partyId) .. ": " .. tostring(record))
			return false
		end
		entry.Record = record
	else
		local ok, record, hostInfo = PartyCore.AcquireHost(deps, partyId)
		if not ok then
			if record == "HostedElsewhere" then
				sendToHost(player, hostInfo)
			else
				warn("[PartyService] Could not host party " .. tostring(partyId) .. ": " .. tostring(record))
			end
			return false
		end
		entry = { Record = record, Online = {}, NextFightAt = 0, NextSaveAt = 0, Dirty = true }
		hosted[partyId] = entry
	end

	partyOf[userId] = partyId
	local seasonId = Seasons.CurrentSeasonId
	local partnerOnline = partnerIsOnline(entry, userId)
	Party.OpenSession(entry.Record, seasonId, userId, player.Name, profile, partnerOnline, now())
	entry.Online[userId] = { Player = player, Profile = profile, Name = player.Name }

	local claim = Party.Claim(entry.Record, userId, profile)
	lastClaim[userId] = claim
	entry.Dirty = true

	print(
		("[PartyService] %s joined party %s (stage %d). Caught up %d stage(s); AFK: %s"):format(
			player.Name,
			tostring(partyId),
			entry.Record.Stage,
			claim.CatchUp.Stages,
			if claim.Afk then ("%d gold, %d XP, %d shards"):format(claim.Afk.Gold, claim.Afk.XP, claim.Afk.Shards) else "none"
		)
	)
	return true
end

-- Public API ------------------------------------------------------------------------------------

function PartyService.OnPlayerReady(player, profile)
	local userId = player.UserId
	local seasonId = Seasons.CurrentSeasonId

	local partyId = profile.Permanent.PartyId
	if partyId ~= nil then
		local ok, reason = PartyCore.Get(deps, partyId)
		if not ok and reason == "NoParty" then
			profile.Permanent.PartyId = nil -- the record was deleted; start fresh
		elseif not ok then
			warn("[PartyService] Could not read party for " .. player.Name .. ": " .. tostring(reason))
			return false
		end
	end

	if profile.Permanent.PartyId == nil then
		local ok, reason = PartyCore.CreateSolo(deps, userId, player.Name, profile, seasonId)
		if not ok then
			warn("[PartyService] Could not create a party for " .. player.Name .. ": " .. tostring(reason))
			return false
		end
	end
	return attach(player, profile)
end

-- Ends the player's session. Call BEFORE DataService.ReleaseProfile.
function PartyService.OnPlayerLeaving(player)
	local userId = player.UserId
	local partyId = partyOf[userId]
	partyOf[userId] = nil
	lastClaim[userId] = nil
	local entry = partyId and hosted[partyId]
	if not entry then
		return
	end

	local online = entry.Online[userId]
	if online then
		Party.CloseSession(entry.Record, userId, online.Name, online.Profile, now())
		entry.Online[userId] = nil
	end
	entry.Dirty = true
	saveEntry(entry)

	if next(entry.Online) == nil then
		hosted[partyId] = nil
		entry.Dead = true
		PartyCore.ReleaseHost(deps, partyId)
	end
end

function PartyService.CreateCode(player)
	local partyId = partyOf[player.UserId]
	if not partyId then
		return false, "NoParty"
	end
	return PartyCore.CreateCode(deps, partyId, player.UserId)
end

function PartyService.JoinByCode(player, code)
	local userId = player.UserId
	local oldId = partyOf[userId]
	local entry = oldId and hosted[oldId]
	local online = entry and entry.Online[userId]
	if not online then
		return false, "NoParty"
	end
	local profile = online.Profile

	local ok, joined, abandoned = PartyCore.JoinByCode(deps, userId, player.Name, profile, Seasons.CurrentSeasonId, code)
	if not ok then
		return false, joined
	end

	-- The player's old solo party ended with them: stop hosting it.
	if abandoned and hosted[abandoned] then
		hosted[abandoned].Dead = true
		hosted[abandoned] = nil
	end
	partyOf[userId] = nil
	attach(player, profile)
	return true
end

function PartyService.Leave(player)
	local userId = player.UserId
	local partyId = partyOf[userId]
	local entry = partyId and hosted[partyId]
	if not entry or not entry.Online[userId] then
		return false, "NoParty"
	end
	local profile = entry.Online[userId].Profile

	-- Pay the leaver everything they are owed first, then save, then leave.
	lastClaim[userId] = Party.Claim(entry.Record, userId, profile)
	entry.Dirty = true
	saveEntry(entry)

	local ok, remaining = PartyCore.Leave(deps, userId, profile)
	if not ok then
		return false, remaining
	end
	entry.Online[userId] = nil
	partyOf[userId] = nil

	if remaining == 0 then
		entry.Dead = true
		hosted[partyId] = nil
	else
		local reloaded, record = PartyCore.Get(deps, partyId)
		if reloaded then
			entry.Record = record
		end
		if next(entry.Online) == nil then
			-- Nobody is left online here: stop hosting it.
			entry.Dead = true
			hosted[partyId] = nil
			PartyCore.ReleaseHost(deps, partyId)
		end
	end

	-- Everyone always has a party: start a fresh solo one.
	local created, reason = PartyCore.CreateSolo(deps, userId, player.Name, profile, Seasons.CurrentSeasonId)
	if not created then
		warn("[PartyService] Could not create a new party after leaving: " .. tostring(reason))
		return true
	end
	attach(player, profile)
	return true
end

function PartyService.RefreshSnapshot(player)
	local partyId = partyOf[player.UserId]
	local entry = partyId and hosted[partyId]
	local online = entry and entry.Online[player.UserId]
	if online then
		Party.RefreshSnapshot(entry.Record, player.UserId, online.Name, online.Profile, now())
		entry.Dirty = true
	end
end

local function entryFor(player)
	local partyId = partyOf[player.UserId]
	return partyId and hosted[partyId]
end

function PartyService.SetStage(player, stage)
	local entry = entryFor(player)
	if not entry then
		return false, "NoParty"
	end
	local ok, reason = Party.SetStage(entry.Record, player.UserId, stage)
	if ok then
		entry.Dirty = true
		entry.NextFightAt = 0 -- start the chosen stage right away
	end
	return ok, reason
end

function PartyService.Advance(player)
	local entry = entryFor(player)
	if not entry then
		return false, "NoParty"
	end
	local ok, reason = Party.Advance(entry.Record, player.UserId)
	if ok then
		entry.Dirty = true
		entry.NextFightAt = 0
	end
	return ok, reason
end

function PartyService.SetUltimate(player, ultimateId)
	local entry = entryFor(player)
	if not entry then
		return false, "NoParty"
	end
	local ok, reason = Party.SetUltimate(entry.Record, player.UserId, ultimateId)
	if ok then
		entry.Dirty = true
	end
	return ok, reason
end

-- Either member may edit the skills (and their order) of either member's ghost.
-- Passives, pets and gear stay view only.
function PartyService.SetGhostLoadout(player, targetUserId, abilityIds)
	local entry = entryFor(player)
	if not entry then
		return false, "NoParty"
	end
	local ok, reason = Party.SetGhostLoadout(entry.Record, player.UserId, targetUserId, abilityIds, now())
	if ok then
		entry.Dirty = true
	end
	return ok, reason
end

function PartyService.RevertGhostLoadout(player)
	local entry = entryFor(player)
	if not entry then
		return false, "NoParty"
	end
	local ok, reason = Party.RevertGhostLoadout(entry.Record, player.UserId)
	if ok then
		entry.Dirty = true
	end
	return ok, reason
end

-- ApiService hooks in here to tell clients about each finished fight.
function PartyService.SetFightListener(fn)
	fightListener = fn
end

-- The partner's saved build (their ghost), for the partner loadout popup.
local function sheetOfSnapshot(snapshot)
	return Hero.Sheet({
		ClassId = snapshot.ClassId,
		Level = snapshot.Level,
		PassiveIds = snapshot.PassiveIds,
		PassiveLevels = snapshot.PassiveLevels,
		SubclassId = snapshot.SubclassId,
		Gear = snapshot.Gear or {},
		PetId = snapshot.PetId,
		PetLevel = snapshot.PetLevel,
		PetRank = snapshot.PetRank,
	})
end

function PartyService.GetPartner(player)
	local entry = entryFor(player)
	if not entry then
		return nil
	end
	local partnerId = Party.Partner(entry.Record, player.UserId)
	local snapshot = partnerId and entry.Record.Snapshots[tostring(partnerId)]
	local isCompanion = false
	if not snapshot and entry.Record.Companion then
		-- no real partner yet: the starter ghost stands in
		snapshot = entry.Record.Companion
		partnerId = Party.COMPANION_ID
		isCompanion = true
	end
	if not snapshot then
		return nil
	end
	return {
		IsCompanion = isCompanion,
		UserId = partnerId,
		Name = snapshot.Name,
		ClassId = snapshot.ClassId,
		Level = snapshot.Level,
		PetId = snapshot.PetId,
		PetLevel = snapshot.PetLevel,
		PetRank = snapshot.PetRank,
		Online = entry.Online[partnerId] ~= nil,
		SlotLevels = table.clone(snapshot.SlotLevels),
		GhostLoadout = table.clone(snapshot.GhostLoadout),
		Owned = table.clone(snapshot.Owned),
		PassiveIds = table.clone(snapshot.PassiveIds or {}),
		PassiveLevels = table.clone(snapshot.PassiveLevels or {}),
		CanRevert = not isCompanion and #(snapshot.History or {}) > 0,
		SubclassId = snapshot.SubclassId,
		Sheet = sheetOfSnapshot(snapshot),
	}
end

-- The member's own snapshot (used to offer "undo partner edits").
-- Public view of any member of a party hosted on this server (online or ghost),
-- for the inspect card. Returns nil for anyone else.
function PartyService.GetInspect(userId)
	local partyId = partyOf[userId]
	local entry = partyId and hosted[partyId]
	if not entry then
		return nil
	end
	local record = entry.Record
	local snapshot = record.Snapshots[tostring(userId)]
	if not snapshot then
		return nil
	end
	local online = entry.Online[userId]
	local info = {
		UserId = userId,
		Name = snapshot.Name,
		ClassId = snapshot.ClassId,
		Level = snapshot.Level,
		Online = online ~= nil,
		Frontier = snapshot.Frontier,
		PartyStage = record.Stage,
		PartyFrontier = record.Frontier,
		PassiveIds = table.clone(snapshot.PassiveIds or {}),
		SlotLevels = table.clone(snapshot.SlotLevels or {}),
		Loadout = table.clone(snapshot.GhostLoadout or {}),
		SubclassId = snapshot.SubclassId,
		Sheet = sheetOfSnapshot(snapshot),
	}
	if online then
		local season = online.Profile.Season
		info.Loadout = table.clone(season.Loadouts[season.ClassId] or info.Loadout)
		info.PetId, info.PetLevel, info.PetRank = Pets.Active(online.Profile)
		info.Level = season.Level
	else
		info.PetId, info.PetLevel, info.PetRank = snapshot.PetId, snapshot.PetLevel, snapshot.PetRank
	end
	for _, memberId in ipairs(record.Members) do
		if memberId ~= userId then
			local other = record.Snapshots[tostring(memberId)]
			info.Partner = other and { UserId = memberId, Name = other.Name, ClassId = other.ClassId, Level = other.Level }
		end
	end
	return info
end

function PartyService.GetMyGhostHistory(player)
	local entry = entryFor(player)
	local snapshot = entry and entry.Record.Snapshots[tostring(player.UserId)]
	return snapshot and #(snapshot.History or {}) or 0
end

function PartyService.GetUltimateInfo(player)
	local entry = entryFor(player)
	if not entry or #entry.Record.Members ~= 2 then
		return nil
	end
	local first = entry.Record.Snapshots[tostring(entry.Record.Members[1])]
	local second = entry.Record.Snapshots[tostring(entry.Record.Members[2])]
	if not first or not second then
		return nil
	end
	local Ultimates = require(Shared.Ultimates)
	return {
		Options = Ultimates.ForPair(first.ClassId, second.ClassId),
		Frontier = entry.Record.Frontier,
		Chosen = Ultimates.Resolve(first.ClassId, second.ClassId, entry.Record.Frontier, entry.Record.UltimateId),
	}
end

-- One line per hosted party with someone online, for the shared hub: who is in it,
-- their class and level (live if online, else the ghost snapshot).
function PartyService.GetHostedSummaries()
	local list = {}
	for partyId, entry in pairs(hosted) do
		if next(entry.Online) ~= nil then
			local record = entry.Record
			local members = {}
			for _, userId in ipairs(record.Members) do
				local online = entry.Online[userId]
				local snapshot = record.Snapshots[tostring(userId)]
				local season = online and online.Profile.Season
				local petId, petLevel, petRank
				if online then
					petId, petLevel, petRank = Pets.Active(online.Profile)
				elseif snapshot then
					petId, petLevel, petRank = snapshot.PetId, snapshot.PetLevel, snapshot.PetRank
				end
				table.insert(members, {
					PetId = petId,
					PetLevel = petLevel,
					PetRank = petRank,
					UserId = userId,
					Name = (online and online.Name) or (snapshot and snapshot.Name) or "?",
					ClassId = (season and season.ClassId) or (snapshot and snapshot.ClassId) or "Warrior",
					Level = (season and season.Level) or (snapshot and snapshot.Level) or 1,
					Online = online ~= nil,
				})
			end
			if #record.Members == 1 and record.Companion then
				table.insert(members, {
					UserId = Party.COMPANION_ID,
					Name = record.Companion.Name,
					ClassId = record.Companion.ClassId,
					Level = record.Companion.Level,
					Online = false,
				})
			end
			table.insert(list, { PartyId = partyId, Stage = record.Stage, Frontier = record.Frontier, Members = members })
		end
	end
	return list
end

-- The ghost snapshot of your partner (nil when solo), used when a boss fight needs a second fighter.
function PartyService.GetPartnerSnapshot(player)
	local partyId = partyOf[player.UserId]
	local entry = partyId and hosted[partyId]
	if not entry then
		return nil
	end
	local record = entry.Record
	local partnerId = Party.Partner(record, player.UserId)
	if partnerId then
		local snapshot = record.Snapshots[tostring(partnerId)]
		return snapshot and { Id = tostring(partnerId), Name = snapshot.Name or "Partner", Snapshot = snapshot } or nil
	end
	-- solo: the starter ghost fights beside you, as in normal stages
	if record.Companion then
		return { Id = tostring(Party.COMPANION_ID), Name = record.Companion.Name, Snapshot = record.Companion }
	end
	return nil
end

-- A boss fight takes over your arena: pause the party's normal fights for a while.
function PartyService.HoldFights(player, seconds)
	local partyId = partyOf[player.UserId]
	local entry = partyId and hosted[partyId]
	if entry then
		entry.NextFightAt = math.max(entry.NextFightAt, now() + seconds)
	end
end

function PartyService.GetLastClaim(player)
	return lastClaim[player.UserId]
end

function PartyService.GetState(player)
	local partyId = partyOf[player.UserId]
	local entry = partyId and hosted[partyId]
	if not entry then
		return nil
	end
	local record = entry.Record
	local partnerId = Party.Partner(record, player.UserId)
	local partnerSnapshot = partnerId and record.Snapshots[tostring(partnerId)]
	return {
		PartyId = partyId,
		Stage = record.Stage,
		Frontier = record.Frontier,
		Holding = record.Farm == true and record.Stage < record.Frontier,
		IsOpen = Party.IsOpen(record),
		PartnerName = partnerSnapshot and partnerSnapshot.Name,
		PartnerOnline = partnerId ~= nil and entry.Online[partnerId] ~= nil,
		GhostLoadout = partnerSnapshot and table.clone(partnerSnapshot.GhostLoadout),
		PartnerPassives = partnerSnapshot and table.clone(partnerSnapshot.PassiveIds or {}),
		UltimateId = record.UltimateId,
	}
end

-- Loop -----------------------------------------------------------------------------------------

local function tickEntry(entry, currentTime)
	if next(entry.Online) == nil then
		return
	end

	if currentTime >= entry.NextFightAt then
		local seed = math.random(1, 1073741824)
		local outcome = Party.OnlineTick(entry.Record, onlineList(entry), seed, currentTime)
		if outcome then
			local waitSeconds = outcome.Duration + OfflineConfig.Intermission
			entry.NextFightAt = currentTime + waitSeconds
			entry.Dirty = true
			if outcome.Won then
				print(("[PartyService] Party %s cleared stage %d (%.1fs). Frontier %d."):format(entry.Record.PartyId, outcome.Stage, outcome.Duration, entry.Record.Frontier))
			end
			if fightListener then
				task.spawn(fightListener, entry.Record, outcome, onlineList(entry), waitSeconds)
			end
			-- Levels and gold changed: keep each ghost snapshot fresh.
			for userId, online in pairs(entry.Online) do
				Party.RefreshSnapshot(entry.Record, userId, online.Name, online.Profile, currentTime)
			end
		end
	end

	if (entry.Dirty and currentTime >= entry.NextSaveAt) or (currentTime >= entry.NextSaveAt + HEARTBEAT_INTERVAL) then
		task.spawn(saveEntry, entry)
	end
end

function PartyService.Init()
	if initialized then
		return
	end
	initialized = true

	local parties, codes
	local usingMemory = false
	if RunService:IsStudio() then
		local ok = pcall(function()
			DataStoreService:GetDataStore(PARTY_STORE):GetAsync("__studio_ping")
		end)
		usingMemory = not ok
	end
	if usingMemory then
		warn("[PartyService] Studio DataStore access unavailable - using in-memory parties (nothing will be saved).")
		parties, codes = newMemoryStore(), newMemoryStore()
	else
		parties, codes = newDataStoreStore(PARTY_STORE), newDataStoreStore(CODE_STORE)
	end

	deps = {
		Parties = parties,
		Codes = codes,
		ServerId = SERVER_ID,
		Now = now,
		Random = function(n)
			return math.random(1, n)
		end,
		NewId = function()
			return HttpService:GenerateGUID(false)
		end,
	}

	task.spawn(function()
		while true do
			task.wait(LOOP_INTERVAL)
			local currentTime = now()
			for _, entry in pairs(table.clone(hosted)) do
				local ok, err = pcall(tickEntry, entry, currentTime)
				if not ok then
					warn("[PartyService] Tick failed: " .. tostring(err))
				end
			end
		end
	end)

	-- On shutdown: close every session, save, and release the host locks.
	game:BindToClose(function()
		for partyId, entry in pairs(table.clone(hosted)) do
			for userId, online in pairs(table.clone(entry.Online)) do
				Party.CloseSession(entry.Record, userId, online.Name, online.Profile, now())
				entry.Online[userId] = nil
			end
			entry.Dirty = true
			saveEntry(entry)
			PartyCore.ReleaseHost(deps, partyId)
			hosted[partyId] = nil
		end
	end)
end

return PartyService
