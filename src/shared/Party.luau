--[[
	Party (ModuleScript)
	Location: ReplicatedStorage > Shared > Party

	The rules of a two-player party, as pure functions on a plain "party record"
	table. A later PartyService saves the record to its own DataStore and calls
	these; nothing here touches Roblox APIs, so it is all headless-testable.

	Party record
	  PartyId, SeasonId
	  Members      { userIdA, userIdB }
	  Stage        the stage the party is fighting now
	  Frontier     the furthest stage the party has unlocked
	  Snapshots    { [tostring(userId)] = snapshot }   the "ghost" of each member
	  Pending      { [tostring(userId)] = AFK rewards waiting to be claimed }
	  LastActiveAt os.time of the last moment any member was online
	  History kept per snapshot lets the owner undo ghost loadout changes

	Snapshot (a member's saved build, used as their ghost while offline)
	  UserId, Name, ClassId, Level, Frontier, SlotLevels, Owned, GhostLoadout,
	  History, SavedAt
	  GhostLoadout is separate from the player's own loadout. Either party member
	  can edit it (SetGhostLoadout), so partners never have to be online together
	  to swap in a skill a boss needs. It is only used while the owner is offline.
	  The ghost is NOT boosted by offline time: it is just the last snapshot.

	Flow
	  OpenSession   a member logs in: season check, AFK for the both-offline gap
	                is worked out and queued for BOTH members, snapshot refreshed
	  Claim         pay the member: partner-progress catch-up + queued AFK gains
	  OnlineTick    run one stage fight: online members fight with the partner's
	                ghost if they are offline; does nothing if nobody is online
	  RefreshSnapshot  call on logout and whenever a member changes their build

	Progress rules
	  * A party starts at the WEAKER member's frontier. A stronger player never
	    lifts it: they carry the weaker partner up until the pair can't climb.
	  * Online member(s) + ghost clear a new stage: the party Frontier moves, and
	    the offline partner is paid for those stages when they Claim.
	  * Both offline: the party never advances. AFK income is farmed on the stage
	    the party can clear, at reduced rate (see Config/Offline), and never
	    moves the frontier.
]]

local Offline = require(script.Parent.Offline)
local Progression = require(script.Parent.Progression)
local Skills = require(script.Parent.Skills)
local StageRunner = require(script.Parent.StageRunner)
local Classes = require(script.Parent.Config.Classes)

local Party = {}

Party.VERSION = 1
Party.HISTORY_LIMIT = 5

local function key(userId)
	return tostring(userId)
end

local function isMember(party, userId)
	return party.Members[1] == userId or party.Members[2] == userId
end

local function copyList(list)
	return table.clone(list)
end

-- frontierA / frontierB are the two players' own frontiers (default 1). The
-- party STARTS at the weaker one's frontier: the stronger player carries the
-- weaker one up from there, until the pair can't climb any further. The
-- stronger player earns the reduced replay rate on stages they already cleared.
function Party.New(partyId, seasonId, userIdA, userIdB, now, frontierA, frontierB)
	assert(userIdA ~= userIdB, "A party needs two different players")
	local start = math.min(frontierA or 1, frontierB or 1)
	return {
		Version = Party.VERSION,
		PartyId = partyId,
		SeasonId = seasonId,
		Members = { userIdA, userIdB },
		Stage = start,
		Frontier = start,
		Snapshots = {},
		Pending = {},
		LastActiveAt = now,
		CreatedAt = now,
	}
end

-- A party that so far has one member (waiting for a partner). The member can
-- play and progress alone; AddMember turns it into a pair.
function Party.NewOpen(partyId, seasonId, userId, now)
	return {
		Version = Party.VERSION,
		PartyId = partyId,
		SeasonId = seasonId,
		Members = { userId },
		Stage = 1,
		Frontier = 1,
		Snapshots = {},
		Pending = {},
		LastActiveAt = now,
		CreatedAt = now,
	}
end

function Party.IsOpen(party)
	return #party.Members == 1
end

-- Completes an open party. The pair starts at the WEAKER member's frontier
-- (the stronger player carries the weaker one up). The first member's frontier
-- comes from their saved snapshot; the newcomer's from their profile.
function Party.AddMember(party, userId, name, profile, now)
	assert(#party.Members == 1, "Party is not open")
	assert(party.Members[1] ~= userId, "Already a member")
	local first = party.Snapshots[key(party.Members[1])]
	local firstFrontier = if first then first.Frontier else party.Frontier
	table.insert(party.Members, userId)
	party.Snapshots[key(userId)] = Party.MakeSnapshot(profile, userId, name, nil, now)
	local start = math.min(firstFrontier, profile.Season.HighestStage)
	party.Stage = start
	party.Frontier = start
	party.Pending = {}
	party.LastActiveAt = now
end

-- Removes a member and their saved ghost and unclaimed AFK. Returns how many
-- members are left (0 means the party should be deleted). Pay out the leaving
-- member with Claim first.
function Party.RemoveMember(party, userId)
	for index, memberId in ipairs(party.Members) do
		if memberId == userId then
			table.remove(party.Members, index)
			break
		end
	end
	party.Snapshots[key(userId)] = nil
	party.Pending[key(userId)] = nil
	return #party.Members
end

function Party.Partner(party, userId)
	if party.Members[1] == userId then
		return party.Members[2]
	elseif party.Members[2] == userId then
		return party.Members[1]
	end
	return nil -- also nil for an open party with no partner yet
end

-- A new season wipes the shared stage, not the party itself.
function Party.EnsureSeason(party, seasonId)
	if party.SeasonId == seasonId then
		return false
	end
	party.SeasonId = seasonId
	party.Stage = 1
	party.Frontier = 1
	party.Pending = {}
	return true
end

-- Snapshots ------------------------------------------------------------------

-- Builds a snapshot from a live profile. Keeps the partner-edited ghost loadout
-- (and its history) when it is still valid for the same class.
function Party.MakeSnapshot(profile, userId, name, previous, now)
	local season = profile.Season
	local classId = season.ClassId

	local owned = {}
	for _, abilityId in ipairs(Classes[classId].AbilityPool) do
		if season.OwnedAbilities[abilityId] then
			owned[abilityId] = true
		end
	end

	local ghostLoadout, history = nil, {}
	if previous and previous.ClassId == classId then
		history = previous.History or {}
		if Skills.ValidateLoadout(classId, previous.GhostLoadout, owned) and #previous.GhostLoadout == Skills.SLOTS then
			ghostLoadout = copyList(previous.GhostLoadout)
		end
	end
	if ghostLoadout == nil then
		ghostLoadout = copyList(season.Loadouts[classId])
		history = {}
	end

	return {
		UserId = userId,
		Name = name,
		ClassId = classId,
		Level = season.Level,
		Frontier = season.HighestStage,
		SlotLevels = copyList(season.SlotLevels[classId]),
		Owned = owned,
		GhostLoadout = ghostLoadout,
		History = history,
		SavedAt = now,
	}
end

function Party.RefreshSnapshot(party, userId, name, profile, now)
	assert(isMember(party, userId), "Not a party member")
	party.Snapshots[key(userId)] = Party.MakeSnapshot(profile, userId, name, party.Snapshots[key(userId)], now)
end

-- Either member may set the ghost loadout of either member. Only skills the
-- owner already owns can be used, and it must fill every slot. Nothing is
-- spent or unlocked.
function Party.SetGhostLoadout(party, editorUserId, targetUserId, abilityIds, now)
	if not isMember(party, editorUserId) or not isMember(party, targetUserId) then
		return false, "NotMember"
	end
	local snapshot = party.Snapshots[key(targetUserId)]
	if snapshot == nil then
		return false, "NoSnapshot"
	end
	local ok, reason = Skills.ValidateLoadout(snapshot.ClassId, abilityIds, snapshot.Owned)
	if not ok then
		return false, reason
	end
	if #abilityIds ~= Skills.SLOTS then
		return false, "NeedFullLoadout"
	end

	table.insert(snapshot.History, { By = editorUserId, At = now, Previous = copyList(snapshot.GhostLoadout) })
	while #snapshot.History > Party.HISTORY_LIMIT do
		table.remove(snapshot.History, 1)
	end
	snapshot.GhostLoadout = copyList(abilityIds)
	return true
end

-- One tap: the owner undoes the latest ghost loadout change.
function Party.RevertGhostLoadout(party, userId)
	local snapshot = party.Snapshots[key(userId)]
	if snapshot == nil then
		return false, "NoSnapshot"
	end
	local last = snapshot.History[#snapshot.History]
	if last == nil then
		return false, "NothingToRevert"
	end
	snapshot.GhostLoadout = copyList(last.Previous)
	table.remove(snapshot.History)
	return true
end

-- Sessions and AFK --------------------------------------------------------------

local function ghostMembers(party)
	local members = {}
	for _, userId in ipairs(party.Members) do
		local snapshot = party.Snapshots[key(userId)]
		assert(snapshot ~= nil, "Missing snapshot for " .. key(userId))
		table.insert(members, { Id = key(userId), Name = snapshot.Name, Snapshot = snapshot })
	end
	return members
end

local function addPending(party, userId, reward, extra)
	local pending = party.Pending[key(userId)]
	if pending == nil then
		pending = { Gold = 0, XP = 0, Shards = 0, Fights = 0, Seconds = 0, Stage = 1 }
		party.Pending[key(userId)] = pending
	end
	pending.Gold += reward.Gold
	pending.XP += reward.XP
	pending.Shards += reward.Shards
	pending.Fights += extra.Fights
	pending.Seconds += extra.Seconds
	pending.Stage = extra.Stage
end

-- Call when a member logs in. `partnerOnline` says whether the partner is
-- connected right now (then the party was active, so there is no both-offline
-- gap). Returns the AFK estimate that was queued, or nil.
function Party.OpenSession(party, seasonId, userId, name, profile, partnerOnline, now)
	assert(isMember(party, userId), "Not a party member")
	Party.EnsureSeason(party, seasonId)

	local estimate = nil
	local gap = now - party.LastActiveAt
	if not partnerOnline and gap > 0 and #party.Members == 2 and next(party.Snapshots) ~= nil then
		-- Both snapshots must exist to simulate the pair; a party whose partner
		-- has never logged in cannot farm AFK yet.
		local complete = true
		for _, memberId in ipairs(party.Members) do
			if party.Snapshots[key(memberId)] == nil then
				complete = false
			end
		end
		if complete then
			estimate = Offline.Estimate(ghostMembers(party), party.Stage, gap)
			if estimate then
				party.Stage = estimate.Stage -- the party "stays on whatever stage it can clear"
				for _, memberId in ipairs(party.Members) do
					addPending(party, memberId, estimate.Rewards[key(memberId)], {
						Fights = estimate.Fights,
						Seconds = estimate.EffectiveSeconds,
						Stage = estimate.Stage,
					})
				end
			end
		end
	end

	party.LastActiveAt = now
	Party.RefreshSnapshot(party, userId, name, profile, now)
	return estimate
end

-- Call when a member logs out (or before their server shuts down): saves their
-- build as the ghost and marks the party inactive from now if the partner is
-- offline too, so the both-offline gap starts at the right moment.
function Party.CloseSession(party, userId, name, profile, now)
	assert(isMember(party, userId), "Not a party member")
	Party.RefreshSnapshot(party, userId, name, profile, now)
	party.LastActiveAt = now
end

-- Pays the member: first the stages the party cleared while they were away
-- (full frontier rewards, once each, because their own frontier moves up as
-- each is paid), then the queued AFK gains. Run it at login, before ticking.
function Party.Claim(party, userId, profile)
	assert(isMember(party, userId), "Not a party member")
	local season = profile.Season

	local catchUp = { Stages = 0, Gold = 0, XP = 0, Shards = 0, SkillPicks = 0, LevelsGained = 0 }
	while season.HighestStage < party.Frontier do
		local summary = Progression.ApplyClear(profile, season.HighestStage)
		catchUp.Stages += 1
		catchUp.Gold += summary.Gold
		catchUp.XP += summary.XP
		catchUp.Shards += summary.Shards
		catchUp.SkillPicks += summary.SkillPicks
		catchUp.LevelsGained += summary.LevelsGained
	end

	local afk = party.Pending[key(userId)]
	party.Pending[key(userId)] = nil
	if afk then
		season.Currencies.Gold += afk.Gold
		season.Currencies.Shards += afk.Shards
		afk.LevelsGained = Progression.AddXP(season, afk.XP)
		afk.Level = season.Level
	end

	return { CatchUp = catchUp, Afk = afk }
end

-- Running fights ---------------------------------------------------------------

-- online: list of { UserId, Name, Profile } for members who are connected.
-- Returns the fight outcome, or nil + "NoneOnline" if nobody is (the party
-- never advances while both are offline). Call Claim first so each online
-- member's frontier matches the party's.
function Party.OnlineTick(party, online, seed, now)
	if #online == 0 then
		return nil, "NoneOnline"
	end

	local byId = {}
	for _, member in ipairs(online) do
		assert(isMember(party, member.UserId), "Not a party member")
		byId[key(member.UserId)] = member
	end

	local members = {}
	for _, userId in ipairs(party.Members) do
		local live = byId[key(userId)]
		if live then
			table.insert(members, { Id = key(userId), Name = live.Name, Profile = live.Profile })
		else
			local snapshot = party.Snapshots[key(userId)]
			assert(snapshot ~= nil, "Missing ghost snapshot for " .. key(userId))
			table.insert(members, { Id = key(userId), Name = snapshot.Name, Snapshot = snapshot })
		end
	end

	local stage = party.Stage
	local outcome = StageRunner.Run(members, stage, seed)
	if outcome.Won and stage >= party.Frontier then
		party.Frontier = stage + 1
	end
	party.Stage = outcome.NextStage
	party.LastActiveAt = now
	return outcome
end

return Party
