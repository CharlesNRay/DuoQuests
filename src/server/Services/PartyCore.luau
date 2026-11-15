--[[
	PartyCore (ModuleScript)
	Location: ServerScriptService > Server > Services > PartyCore

	Everything about saving parties, hosting them and joining them, written
	against a tiny "store" interface so it can be tested without Roblox. The
	Roblox-facing PartyService supplies DataStore-backed stores.

	deps = {
	  Parties   store for party records  (key "Party_<id>")
	  Codes     store for join codes     (key "Code_<CODE>")
	  ServerId  this server's JobId
	  Now       function() -> os.time style seconds
	  Random    function(n) -> integer in 1..n
	  NewId     function() -> a fresh unique party id string
	}
	store:Get(key)               -> ok, value
	store:Update(key, transform) -> ok, newValue   (transform(old) returns the new
	                                value, or nil to cancel; it may run more than once)
	store:Remove(key)            -> ok

	WHO OWNS WHAT in a party record (so two servers never overwrite each other):
	  Membership (Members, Rev, and the member list's snapshots) is changed only
	  through the join/leave functions here, each a single atomic Update that
	  bumps Rev.
	  Progress (Stage, Frontier, Pending, LastActiveAt, snapshots of members who
	  are online) is written only by the HOST server, which holds `Host`.
	  If a host tries to save and finds Rev changed, it does not overwrite
	  anything: it gets the new record back (membershipChanged) and carries on.

	Hosting: a party runs on one server at a time. Host = { JobId, At } with a
	timeout, refreshed on every save. A server that finds a live host elsewhere
	should send its player there.

	All functions return true, value... or false, reason.
]]

local Party = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Party"))

local PartyCore = {}

PartyCore.CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no 0/O/1/I confusion
PartyCore.CODE_LENGTH = 6
PartyCore.CODE_TTL = 15 * 60 -- join codes last 15 minutes
PartyCore.HOST_TIMEOUT = 60 -- a host that has not saved for this long is presumed gone

local function partyKey(partyId)
	return "Party_" .. partyId
end

local function codeKey(code)
	return "Code_" .. code
end

local function key(userId)
	return tostring(userId)
end

function PartyCore.NormalizeCode(code)
	if type(code) ~= "string" then
		return nil
	end
	code = string.upper((string.gsub(code, "%s+", "")))
	if #code ~= PartyCore.CODE_LENGTH then
		return nil
	end
	for index = 1, #code do
		if not string.find(PartyCore.CODE_CHARS, string.sub(code, index, index), 1, true) then
			return nil
		end
	end
	return code
end

function PartyCore.Get(deps, partyId)
	local ok, record = deps.Parties:Get(partyKey(partyId))
	if not ok then
		return false, "StoreError"
	end
	if record == nil then
		return false, "NoParty"
	end
	return true, record
end

-- A new open party for a player who has none. Sets profile.Permanent.PartyId.
function PartyCore.CreateSolo(deps, userId, name, profile, seasonId)
	local now = deps.Now()
	local party = Party.NewOpen(deps.NewId(), seasonId, userId, now)
	party.Rev = 1
	Party.RefreshSnapshot(party, userId, name, profile, now)

	local ok, saved = deps.Parties:Update(partyKey(party.PartyId), function(old)
		if old ~= nil then
			return nil
		end
		return party
	end)
	if not ok or saved == nil then
		return false, "StoreError"
	end
	profile.Permanent.PartyId = party.PartyId
	return true, saved
end

-- Hosting -------------------------------------------------------------------------

-- Claims the right to run this party on this server. Returns true, record, or
-- false, "HostedElsewhere", hostInfo (send the player to that server), or false, reason.
function PartyCore.AcquireHost(deps, partyId)
	local missing, elsewhere = false, nil
	local ok, record = deps.Parties:Update(partyKey(partyId), function(old)
		missing, elsewhere = false, nil
		if old == nil then
			missing = true
			return nil
		end
		local now = deps.Now()
		local host = old.Host
		if host ~= nil and host.JobId ~= deps.ServerId and (now - host.At) < PartyCore.HOST_TIMEOUT then
			elsewhere = host
			return nil
		end
		old.Host = { JobId = deps.ServerId, At = now }
		return old
	end)
	if not ok then
		return false, "StoreError"
	end
	if missing then
		return false, "NoParty"
	end
	if elsewhere then
		return false, "HostedElsewhere", elsewhere
	end
	return true, record
end

function PartyCore.ReleaseHost(deps, partyId)
	local ok = deps.Parties:Update(partyKey(partyId), function(old)
		if old ~= nil and old.Host ~= nil and old.Host.JobId == deps.ServerId then
			old.Host = nil
			return old
		end
		return nil
	end)
	return ok
end

-- Saves the host's progress. `mine` is the hosted record; `managed` is a set of
-- member user ids (as strings) whose snapshots this server keeps up to date
-- (the members who are online here).
--   true, record, membershipChanged
--   false, "LostHost" | "NoParty" | "StoreError"
-- When membershipChanged is true the returned record is the stored one and the
-- host must adopt it (a member joined or left on another server).
function PartyCore.SaveProgress(deps, mine, managed)
	local lostHost, missing, membershipChanged = false, false, false
	local ok, record = deps.Parties:Update(partyKey(mine.PartyId), function(old)
		lostHost, missing, membershipChanged = false, false, false
		if old == nil then
			missing = true
			return nil
		end
		if old.Host == nil or old.Host.JobId ~= deps.ServerId then
			lostHost = true
			return nil
		end
		local now = deps.Now()
		old.Host = { JobId = deps.ServerId, At = now }
		if old.Rev ~= mine.Rev then
			membershipChanged = true
			return old -- keep the stored membership and progress; only refresh the host time
		end
		old.Stage = mine.Stage
		old.Frontier = mine.Frontier
		old.SeasonId = mine.SeasonId
		old.LastActiveAt = mine.LastActiveAt
		old.Pending = mine.Pending
		for _, userId in ipairs(old.Members) do
			if managed[key(userId)] and mine.Snapshots[key(userId)] then
				old.Snapshots[key(userId)] = mine.Snapshots[key(userId)]
			end
		end
		return old
	end)
	if not ok then
		return false, "StoreError"
	end
	if missing then
		return false, "NoParty"
	end
	if lostHost then
		return false, "LostHost"
	end
	return true, record, membershipChanged
end

-- Join codes ------------------------------------------------------------------------

-- Only an open party (one member) can make a code, and only a member can.
-- Returns true, code, expiresAt.
function PartyCore.CreateCode(deps, partyId, userId)
	local ok, party = PartyCore.Get(deps, partyId)
	if not ok then
		return false, party
	end
	if party.Members[1] ~= userId and party.Members[2] ~= userId then
		return false, "NotMember"
	end
	if not Party.IsOpen(party) then
		return false, "PartyFull"
	end

	for _ = 1, 8 do
		local chars = {}
		for index = 1, PartyCore.CODE_LENGTH do
			local at = deps.Random(#PartyCore.CODE_CHARS)
			chars[index] = string.sub(PartyCore.CODE_CHARS, at, at)
		end
		local code = table.concat(chars)
		local collided, expiresAt = false, 0
		local stored, saved = deps.Codes:Update(codeKey(code), function(old)
			collided = false
			local now = deps.Now()
			if old ~= nil and old.ExpiresAt > now then
				collided = true
				return nil
			end
			expiresAt = now + PartyCore.CODE_TTL
			return { PartyId = partyId, CreatedBy = userId, ExpiresAt = expiresAt }
		end)
		if not stored then
			return false, "StoreError"
		end
		if not collided and saved ~= nil then
			return true, code, expiresAt
		end
	end
	return false, "NoCodeAvailable"
end

-- Joins the party behind a code. The joiner's own current party must be solo
-- (or they have none); it is deleted afterwards. Sets profile.Permanent.PartyId.
-- Returns true, joinedRecord, abandonedPartyId (the joiner's old solo party, which the
-- caller should stop hosting), or false, reason.
function PartyCore.JoinByCode(deps, userId, name, profile, seasonId, code)
	local normalized = PartyCore.NormalizeCode(code)
	if normalized == nil then
		return false, "BadCode"
	end

	local ok, codeRecord = deps.Codes:Get(codeKey(normalized))
	if not ok then
		return false, "StoreError"
	end
	if codeRecord == nil or codeRecord.ExpiresAt <= deps.Now() then
		return false, "BadCode"
	end
	local targetId = codeRecord.PartyId

	local oldId = profile.Permanent.PartyId
	if oldId == targetId then
		return false, "OwnParty"
	end
	if oldId ~= nil then
		local found, oldParty = PartyCore.Get(deps, oldId)
		if found and not Party.IsOpen(oldParty) then
			return false, "AlreadyInParty"
		end
	end

	local failure = nil
	local stored, joined = deps.Parties:Update(partyKey(targetId), function(old)
		failure = nil
		if old == nil then
			failure = "NoParty"
			return nil
		end
		if not Party.IsOpen(old) then
			failure = "PartyFull"
			return nil
		end
		if old.Members[1] == userId then
			failure = "OwnParty"
			return nil
		end
		if old.SeasonId ~= seasonId then
			Party.EnsureSeason(old, seasonId)
		end
		Party.AddMember(old, userId, name, profile, deps.Now())
		old.Rev = (old.Rev or 0) + 1
		return old
	end)
	if not stored then
		return false, "StoreError"
	end
	if failure then
		return false, failure
	end

	deps.Codes:Remove(codeKey(normalized))
	profile.Permanent.PartyId = targetId

	local abandoned = nil
	if oldId ~= nil then
		-- The joiner's old party was solo, so it ends with them.
		deps.Parties:Remove(partyKey(oldId))
		abandoned = oldId
	end
	return true, joined, abandoned
end

-- Leave ----------------------------------------------------------------------------------

-- The caller should have paid the leaver out first (Party.Claim) and saved.
-- Clears profile.Permanent.PartyId. The last member leaving deletes the party.
-- Returns true, remainingMembers.
function PartyCore.Leave(deps, userId, profile)
	local partyId = profile.Permanent.PartyId
	if partyId == nil then
		return false, "NoParty"
	end

	local failure, remaining = nil, 0
	local stored = deps.Parties:Update(partyKey(partyId), function(old)
		failure, remaining = nil, 0
		if old == nil then
			failure = "NoParty"
			return nil
		end
		if old.Members[1] ~= userId and old.Members[2] ~= userId then
			failure = "NotMember"
			return nil
		end
		remaining = Party.RemoveMember(old, userId)
		old.Rev = (old.Rev or 0) + 1
		return old
	end)
	if not stored then
		return false, "StoreError"
	end
	if failure == "NoParty" then
		profile.Permanent.PartyId = nil -- the record is already gone
		return true, 0
	end
	if failure then
		return false, failure
	end
	if remaining == 0 then
		deps.Parties:Remove(partyKey(partyId))
	end
	profile.Permanent.PartyId = nil
	return true, remaining
end

return PartyCore
