--[[
	Party (ModuleScript)
	Location: ReplicatedStorage > Shared > Party

	The rules of a party of up to four players (Party.MAX_MEMBERS), as pure functions on a plain "party record"
	table. A later PartyService saves the record to its own DataStore and calls
	these; nothing here touches Roblox APIs, so it is all headless-testable.

	Party record
	  PartyId, SeasonId
	  Members      { userId, ... } (1 to 4)
	  Companions   starter ghosts filling the empty seats, so every fight has Party.SEATS heroes (Party.SyncCompanions)
	  Stage        the stage the party is fighting now
	  Frontier     the furthest stage the party has unlocked
	  Farm         true while replaying an earlier stage picked on the map
	  Snapshots    { [tostring(userId)] = snapshot }   the "ghost" of each member
	  Pending      { [tostring(userId)] = AFK rewards waiting to be claimed }
	  LastActiveAt os.time of the last moment any member was online
	  History kept per snapshot lets the owner undo ghost loadout changes

	UltimateId   optional: the pair's chosen ultimate (Party.SetUltimate)

	Snapshot (a member's saved build, used as their ghost while offline)
	  UserId, Name, ClassId, SubclassId?, PetId?, PetLevel?, Gear (equipped items), Level, Frontier, SlotLevels, Owned, GhostLoadout,
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
local SkillProgress = require(script.Parent.SkillProgress)
local StageRunner = require(script.Parent.StageRunner)
local Pets = require(script.Parent.Pets)
local Power = require(script.Parent.Power)
local ProfileTemplate = require(script.Parent.ProfileTemplate)
local Subclasses = require(script.Parent.Subclasses)
local Talents = require(script.Parent.Talents)
local Bestiary = require(script.Parent.Bestiary)
local ClassMastery = require(script.Parent.ClassMastery)
local TableUtil = require(script.Parent.Util.TableUtil)
local FIRST_BOSS_STAGE = require(script.Parent.Config.Stages).BossEvery -- stage 10: no farm hold up to it (see Party.OnlineTick)
local Ultimates = require(script.Parent.Ultimates)
local Classes = require(script.Parent.Config.Classes)

local Party = {}

Party.VERSION = 1
Party.HISTORY_LIMIT = 5
Party.COMPANION_ID = -1 -- the first starter ghost's id; the others are -2, -3 (real user ids are positive)
Party.MAX_MEMBERS = 4
Party.SEATS = 4 -- every fight has this many heroes: members (or their ghosts) plus companions in the empty seats

local function key(userId)
	return tostring(userId)
end

local function isMember(party, userId)
	return table.find(party.Members, userId) ~= nil
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
		-- UltimateId is added when the pair picks one (see SetUltimate)
	}
end

-- A party that so far has one member (waiting for a partner). The member can
-- play and progress alone; AddMember turns it into a pair. It starts at `startStage` (the member's own
-- frontier), so leaving a party never sends anyone back to stage 1.
function Party.NewOpen(partyId, seasonId, userId, now, startStage)
	local start = math.max(1, math.floor(startStage or 1))
	return {
		Version = Party.VERSION,
		PartyId = partyId,
		SeasonId = seasonId,
		Members = { userId },
		Stage = start,
		Frontier = start,
		Snapshots = {},
		Pending = {},
		LastActiveAt = now,
		CreatedAt = now,
	}
end

-- room for another player
function Party.IsOpen(party)
	return #party.Members < Party.MAX_MEMBERS
end

-- Completes an open party. The pair starts at the WEAKER member's frontier
-- (the stronger player carries the weaker one up). The first member's frontier
-- comes from their saved snapshot; the newcomer's from their profile.
function Party.AddMember(party, userId, name, profile, now)
	assert(#party.Members < Party.MAX_MEMBERS, "Party is full")
	assert(not isMember(party, userId), "Already a member")
	local frontier = party.Frontier
	if #party.Members == 1 then
		local first = party.Snapshots[key(party.Members[1])]
		frontier = if first then first.Frontier else party.Frontier
	end
	table.insert(party.Members, userId)
	party.Snapshots[key(userId)] = Party.MakeSnapshot(profile, userId, name, nil, now)
	local start = math.min(frontier, profile.Season.HighestStage)
	party.Stage = start
	party.Frontier = start
	party.Pending[key(userId)] = nil
	party.Companion = nil -- (old saves kept one companion here)
	if party.Companions then -- a real player takes a companion's seat
		table.remove(party.Companions)
	end
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

-- the other members (user ids), in party order
function Party.Others(party, userId)
	local out = {}
	for _, memberId in ipairs(party.Members) do
		if memberId ~= userId then
			table.insert(out, memberId)
		end
	end
	return out
end

-- the first other member, or nil (alone in the party, or not a member)
function Party.Partner(party, userId)
	if not isMember(party, userId) then
		return nil
	end
	return Party.Others(party, userId)[1]
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
	party.Companion = nil
	party.Companions = nil
	return true
end

-- Snapshots ------------------------------------------------------------------

-- Builds a snapshot from a live profile. Keeps the partner-edited ghost loadout
-- (and its history) when it is still valid for the same class.
function Party.MakeSnapshot(profile, userId, name, previous, now)
	local season = profile.Season
	local classId = season.ClassId

	local owned = {}
	for _, abilityId in ipairs(Skills.AllSkills(classId)) do
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

	local petId, petLevel, petRank = Pets.Active(profile)
	return {
		UserId = userId,
		Name = name,
		ClassId = classId,
		IP = Power.Hero(profile).Total, -- shown on the partner's card
		PetId = petId,
		PetLevel = petLevel,
		PetRank = petRank,
		SubclassId = season.Subclasses and season.Subclasses[classId] or nil,
		Gear = TableUtil.DeepCopy((season.Equipment and season.Equipment.Equipped) or {}),
		CollectionMods = (function() -- the pet-collection bonus plus the VIP second pet's stats, so a ghost keeps both
			local mods = table.clone(Pets.Collection(profile).Mods)
			for _, mod in ipairs(Pets.SecondMods(profile)) do
				table.insert(mods, mod)
			end
			for _, mod in ipairs(Talents.Mods(profile)) do -- level-up talents travel with the ghost too
				table.insert(mods, mod)
			end
			for _, mod in ipairs(Bestiary.Mods(profile)) do -- and the permanent bestiary and class mastery bonuses
				table.insert(mods, mod)
			end
			for _, mod in ipairs(ClassMastery.Mods(profile, classId)) do
				table.insert(mods, mod)
			end
			return mods
		end)(),
		Level = season.Level,
		PartySpirit = Talents.Rank(profile, "PartySpirit"), -- the Mastery talent that boosts the whole party
		Frontier = season.HighestStage,
		SlotLevels = SkillProgress.SlotLevelsFor(season, season.Loadouts[classId], classId),
		SlotBonus = SkillProgress.SlotBonus(season, classId, #(season.Loadouts[classId] or {})),
		SkillLevels = SkillProgress.LevelMap(season),
		PassiveIds = copyList(season.PassiveLoadouts[classId] or {}), -- view only for the partner
		PassiveLevels = copyList(season.PassiveSlotLevels[classId] or {}),
		Owned = owned,
		GhostLoadout = ghostLoadout,
		History = history,
		SavedAt = now,
	}
end

-- The levels a snapshot's ghost fights its skills at, by slot (skill levels follow the SKILL, not the slot)
function Party.GhostLevels(snapshot)
	if snapshot.SkillLevels then
		return SkillProgress.WithBonus(SkillProgress.LevelsFor(snapshot.GhostLoadout, snapshot.SkillLevels), snapshot.SlotBonus)
	end
	return copyList(snapshot.SlotLevels or {})
end

function Party.RefreshSnapshot(party, userId, name, profile, now)
	assert(isMember(party, userId), "Not a party member")
	party.Snapshots[key(userId)] = Party.MakeSnapshot(profile, userId, name, party.Snapshots[key(userId)], now)
end

-- Starter ghost companion ------------------------------------------------------
-- A party with only one member gets a ghost partner so a new player can fight with
-- a pair (and try the ghost features) before a real partner joins. It is a
-- Cleric (a Warrior for a Cleric player) that keeps pace with its owner: same
-- level and slot levels, and it takes a subclass path when the owner reaches the
-- unlock stage. Its skills can be edited like any ghost's. It earns no rewards, and
-- it disappears the moment a real partner joins.

local COMPANION_NAMES = { Cleric = "Mira", Warrior = "Brom", Mage = "Ilsa", Ranger = "Wren", Rogue = "Vex", Summoner = "Morrow" }
local COMPANION_PATHS = { Cleric = "Priest", Warrior = "Guardian", Mage = "Pyromancer", Ranger = "Sharpshooter", Rogue = "Assassin", Summoner = "SpiritCaller" }
-- companions take the first classes the party does not have yet, in this order: a healer, a tank, then damage
local COMPANION_ORDER = { "Cleric", "Warrior", "Mage", "Ranger", "Rogue", "Summoner" }

local function averageSlotLevel(levels)
	local total, count = 0, 0
	for _, level in ipairs(levels or {}) do
		total += level
		count += 1
	end
	return if count > 0 then math.max(1, math.floor(total / count)) else 1
end

-- Bring the companion's level, slots and path up to its owner's.
local function followOwner(companion, ownerProfile)
	local season = ownerProfile.Season
	local level = averageSlotLevel(SkillProgress.SlotLevelsFor(season, season.Loadouts[season.ClassId]))
	companion.Level = season.Level
	companion.Frontier = season.HighestStage
	companion.SkillLevels = nil -- the companion fights at its owner's average level
	-- it wears gear like its owner's (same slots, rarities, power and upgrades; a class-themed name is chosen by whoever shows it)
	companion.Gear = TableUtil.DeepCopy((season.Equipment and season.Equipment.Equipped) or {})
	for _, item in pairs(companion.Gear) do
		item.Id = "c" .. tostring(item.Id)
	end
	-- and keeps a pet of the owner's rarity, at the owner's pet level and rank (a different pet when one fits)
	local ownerPet, petLevel, petRank = Pets.Active(ownerProfile)
	companion.PetId, companion.PetLevel, companion.PetRank = nil, nil, nil
	if ownerPet then
		local rarity = Pets.Defs[ownerPet].Rarity
		local pick = ownerPet
		for id, def in pairs(Pets.Defs) do
			if id ~= ownerPet and def.Rarity == rarity and def.Wish == true and (pick == ownerPet or id < pick) then
				pick = id
			end
		end
		companion.PetId, companion.PetLevel, companion.PetRank = pick, petLevel, petRank
	end
	companion.CollectionMods = Pets.Collection(ownerProfile).Mods
	for index = 1, Skills.SLOTS do
		companion.SlotLevels[index] = level
	end
	local pathId = COMPANION_PATHS[companion.ClassId]
	local def = Subclasses.Defs[pathId]
	if def and season.Level >= def.UnlockLevel and companion.SubclassId == nil then
		companion.SubclassId = pathId
		companion.Owned[def.Skills[1]] = true
	end
end

function Party.MakeCompanion(ownerProfile, now, classId, id)
	classId = classId or (if ownerProfile.Season.ClassId == "Cleric" then "Warrior" else "Cleric")
	local fresh = ProfileTemplate.New()
	fresh.Season.ClassId = classId
	ProfileTemplate.GrantClassStarters(fresh.Season, classId) -- its starter skills and loadout (any class)
	local snapshot = Party.MakeSnapshot(fresh, id or Party.COMPANION_ID, COMPANION_NAMES[classId] or "Companion", nil, now)
	snapshot.IsCompanion = true
	followOwner(snapshot, ownerProfile)
	return snapshot
end

-- Call on a one-member party whenever its member is online. Creates the companion
-- if it is missing and keeps it level with its owner.
-- Fills the empty seats (Party.SEATS minus the members) with companions that follow `ownerProfile` (an online member),
-- each of a class nobody in the party has yet. Returns the companions list (it is kept on the party as Companions).
-- `classes` optional: the members' classes (default: read from their snapshots, plus the owner's).
function Party.SyncCompanions(party, ownerProfile, now, classes)
	party.Companion = nil -- old saves kept a single companion here
	local need = math.max(0, Party.SEATS - #party.Members)
	local taken = {}
	if classes then
		for _, c in ipairs(classes) do taken[c] = true end
	else
		for _, memberId in ipairs(party.Members) do
			local snap = party.Snapshots[key(memberId)]
			if snap then taken[snap.ClassId] = true end
		end
		taken[ownerProfile.Season.ClassId] = true
	end
	-- keep the companions (and their edited skills) whose class no member plays, up to the free seats
	local list = {}
	for _, companion in ipairs(party.Companions or {}) do
		if #list < need and not taken[companion.ClassId] then
			table.insert(list, companion)
		end
	end
	for _, companion in ipairs(list) do
		taken[companion.ClassId] = true
	end
	while #list < need do
		local classId = nil
		for _, c in ipairs(COMPANION_ORDER) do
			if not taken[c] then
				classId = c
				break
			end
		end
		classId = classId or COMPANION_ORDER[#list + 1]
		taken[classId] = true
		table.insert(list, Party.MakeCompanion(ownerProfile, now, classId, Party.COMPANION_ID - #list))
	end
	for index, companion in ipairs(list) do
		companion.UserId = Party.COMPANION_ID - (index - 1)
		followOwner(companion, ownerProfile)
	end
	party.Companions = if #list > 0 then list else nil
	return list
end

-- old name: the first companion (or nil)
function Party.SyncCompanion(party, ownerProfile, now)
	return Party.SyncCompanions(party, ownerProfile, now)[1]
end

function Party.CompanionById(party, id)
	for _, companion in ipairs(party.Companions or {}) do
		if companion.UserId == id then
			return companion
		end
	end
	return nil
end

-- The fighters list with companions in the empty seats.
local function withCompanion(party, members)
	for _, companion in ipairs(party.Companions or {}) do
		if #members >= Party.SEATS then
			break
		end
		table.insert(members, { Id = key(companion.UserId), Name = companion.Name, Snapshot = companion })
	end
	return members
end

-- Either member may set the ghost loadout of either member (or of the starter companion). Only skills the
-- owner already owns can be used, and it must fill every slot. Nothing is
-- spent or unlocked.
function Party.SetGhostLoadout(party, editorUserId, targetUserId, abilityIds, now)
	local companion = Party.CompanionById(party, targetUserId)
	if not isMember(party, editorUserId) or not (isMember(party, targetUserId) or companion) then
		return false, "NotMember"
	end
	local snapshot = companion or party.Snapshots[key(targetUserId)]
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

-- Party ultimate ------------------------------------------------------------------

-- The pair's ultimate options depend on both classes (Config/Ultimates). Either
-- member may change which unlocked one the party uses. Returns true or
-- false + reason: "NotMember", "NeedPair", "NoUltimate", "NotForPair", "Locked".
function Party.SetUltimate(party, userId, ultimateId)
	if not isMember(party, userId) then
		return false, "NotMember"
	end
	local classes = {}
	for _, memberId in ipairs(party.Members) do
		local snap = party.Snapshots[key(memberId)]
		if snap then table.insert(classes, snap.ClassId) end
	end
	for _, companion in ipairs(party.Companions or {}) do
		table.insert(classes, companion.ClassId)
	end
	if #classes < 2 then
		return false, "NeedPair"
	end
	local ok, reason = Ultimates.ValidateParty(classes, party.Frontier, ultimateId)
	if not ok then
		return false, reason
	end
	party.UltimateId = ultimateId
	return true
end

-- Stage selection -----------------------------------------------------------------

-- Either member picks any stage the party has already unlocked (1..Frontier) from
-- the world map. Picking an earlier stage means "farm it": the party keeps fighting
-- that stage after each win until someone picks another one. A loss steps back one
-- stage and holds there the same way (see OnTick). Picking the Frontier goes back to normal progression.
-- Returns true or false + reason: "NotMember", "BadStage", "Locked".
function Party.SetStage(party, userId, stage)
	if not isMember(party, userId) then
		return false, "NotMember"
	end
	if type(stage) ~= "number" or stage ~= math.floor(stage) or stage < 1 then
		return false, "BadStage"
	end
	if stage > party.Frontier then
		return false, "Locked"
	end
	party.Stage = stage
	party.Farm = if stage < party.Frontier then true else nil
	return true
end

-- Move one stage up from where the party is holding (never past the Frontier).
function Party.Advance(party, userId)
	return Party.SetStage(party, userId, party.Stage + 1)
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
	if not partnerOnline and gap > 0 and #party.Members >= 1 and next(party.Snapshots) ~= nil then
		-- Every member's snapshot must exist to simulate the party; a party whose partner has never logged in cannot
		-- farm AFK yet. A solo player farms too (2026-11-24: it used to need 2 members, so solo players with
		-- companions earned nothing while away): the companions fill the empty seats.
		local complete = true
		for _, memberId in ipairs(party.Members) do
			if party.Snapshots[key(memberId)] == nil then
				complete = false
			end
		end
		if complete then
			local ghosts = withCompanion(party, ghostMembers(party))
			estimate = Offline.Estimate(
				ghosts,
				party.Stage,
				gap,
				StageRunner.UltimateFor(ghosts, party.Frontier, party.UltimateId)
			)
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
		Bestiary.Record(profile, Bestiary.KillsForStage(season.HighestStage, 1), os.time()) -- one win per caught-up stage
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
		if (afk.Fights or 0) > 0 and afk.Stage then -- the bestiary counts away wins too
			Bestiary.Record(profile, Bestiary.KillsForStage(afk.Stage, afk.Fights), os.time())
		end
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

	if online[1] then
		Party.SyncCompanions(party, online[1].Profile, now)
	end
	withCompanion(party, members)

	local stage = party.Stage
	local outcome = StageRunner.Run(members, stage, seed, StageRunner.UltimateFor(members, party.Frontier, party.UltimateId), true)
	-- the bestiary: every online member counts every kill of the fight (party kills count for everyone)
	local kills = Bestiary.CountKills(outcome.Events, outcome.Roster)
	for _, member in ipairs(online) do
		outcome.Bestiary = outcome.Bestiary or {}
		outcome.Bestiary[key(member.UserId)] = Bestiary.Record(member.Profile, kills, now)
	end
	if outcome.Won and stage >= party.Frontier then
		party.Frontier = stage + 1
	end
	-- A loss steps back one stage and HOLDS there: the party keeps farming that stage until a
	-- member chooses to advance (map or Advance button), so it never grinds on a stage it cannot beat.
	-- (Before the first boss there is no hold: a brand-new player in the tutorial has not learned the Advance button,
	-- so the party simply tries again after stepping back.)
	if not outcome.Won and stage > FIRST_BOSS_STAGE then
		party.Farm = true
	end
	local farming = party.Farm == true and outcome.Won and stage < party.Frontier
	party.Stage = if farming then stage else outcome.NextStage
	if party.Stage >= party.Frontier then
		party.Farm = nil
	end
	party.LastActiveAt = now
	return outcome
end

return Party
