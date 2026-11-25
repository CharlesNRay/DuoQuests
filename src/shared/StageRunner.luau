--[[
	StageRunner (ModuleScript)
	Location: ReplicatedStorage > Shared > StageRunner

	Runs one stage fight for a party and applies the results. Pure Luau (no
	Roblox APIs), so it is headless-testable. The server's party service calls
	this on a timer; the stage the party is on is stored by the party, not here.

	  StageRunner.NewParty(members)          -> party combatants for Simulation
	  StageRunner.UltimateFor(members, frontier, chosenId)
	                                         -> { Id, Level } or nil: the party
	                                            ultimate for these two classes
	  StageRunner.Run(members, stage, seed, ultimate, record, setup)  -> outcome
	                                         (ultimate optional, from UltimateFor;
	                                          record = true adds Events and Roster
	                                          so a client can replay the fight; setup =
                                          { Enemies, Waves, MaxSeconds } fights those
                                          instead of the stage's own monsters)

	members is a list of { Id, Name, Profile } for a player who is online, or
	{ Id, Name, Snapshot } for a ghost (an offline partner's saved build, see
	Shared/Party). Only members with a Profile are paid rewards.

	outcome = {
	  Won         true if the party won
	  Stage       the stage that was fought
	  NextStage   stage + 1 on a win; on a loss the party steps back one stage
	              (never below 1) to farm it, then tries again
	  Rewards     { [memberId] = summary from Progression.ApplyClear } (wins only)
	  TimedOut    true if the stage timer ran out (counts as a loss)
	  Duration    fight length in seconds
	  Result      the raw Simulation result
	  Events      (only when record) the fight's event log, see Combat/Simulation
	  Roster      (only when record) everyone in the fight:
	              { { Id, Name, Team, DefId, MaxHealth, UserId?, PetId?, Ghost? } }
	              Party members' DefId is their class; UserId is set for them.
	}

	Why step back instead of retrying the same stage? A party that is too weak
	for a stage would earn nothing while it retried (a soft-lock). Stepping back
	lets it earn reduced rewards, get stronger, and then climb again, with no
	input from the player.
]]

local Progression = require(script.Parent.Progression)
local Simulation = require(script.Parent.Combat.Simulation)
local StatCalc = require(script.Parent.Combat.StatCalc)
local Stages = require(script.Parent.Stages)
local Ultimates = require(script.Parent.Ultimates)
local Pets = require(script.Parent.Pets)
local Consumables = require(script.Parent.Consumables)
local Gear = require(script.Parent.Gear)
local SkillProgress = require(script.Parent.SkillProgress)
local Talents = require(script.Parent.Talents)
local Bestiary = require(script.Parent.Bestiary)
local ClassMastery = require(script.Parent.ClassMastery)

local StageRunner = {}

function StageRunner.NewParty(members)
	-- Party Spirit (Mastery talent): everyone's ranks add up and the whole party gets the bonus
	local spirit = 0
	for _, member in ipairs(members) do
		if member.Profile then
			spirit += Talents.Rank(member.Profile, "PartySpirit")
		elseif member.Snapshot then
			spirit += member.Snapshot.PartySpirit or 0
		end
	end
	local partyMods = Talents.PartyMods(spirit)
	local party = {}
	for _, member in ipairs(members) do
		local classId, level, loadout, slotLevels, passiveIds, passiveLevels, petId, petLevel, petRank, equipped, subclassId, extraMods
		if member.Profile then
			local season = member.Profile.Season
			classId, level = season.ClassId, season.Level
			loadout = season.Loadouts[classId]
			slotLevels = SkillProgress.SlotLevelsFor(season, loadout)
			passiveIds, passiveLevels = season.PassiveLoadouts[classId], season.PassiveSlotLevels[classId]
			petId, petLevel, petRank = Pets.Active(member.Profile)
			subclassId = season.Subclasses and season.Subclasses[classId] or nil
			equipped = season.Equipment and season.Equipment.Equipped
			extraMods = Consumables.Mods(member.Profile, os.time())
			for _, mod in ipairs(Pets.Collection(member.Profile).Mods) do -- the permanent bonus for the pets you have collected
				table.insert(extraMods, mod)
			end
			for _, mod in ipairs(Pets.SecondMods(member.Profile)) do -- VIP second pet slot: its stat bonuses (it does not fight)
				table.insert(extraMods, mod)
			end
			for _, mod in ipairs(Talents.Mods(member.Profile)) do -- level-up talent points
				table.insert(extraMods, mod)
			end
			for _, mod in ipairs(Bestiary.Mods(member.Profile)) do -- permanent: bestiary zones and class mastery
				table.insert(extraMods, mod)
			end
			for _, mod in ipairs(ClassMastery.Mods(member.Profile, classId)) do
				table.insert(extraMods, mod)
			end
		else
			local snapshot = member.Snapshot
			classId, level = snapshot.ClassId, snapshot.Level
			loadout = snapshot.GhostLoadout
			slotLevels = if snapshot.SkillLevels then SkillProgress.WithBonus(SkillProgress.LevelsFor(loadout, snapshot.SkillLevels), snapshot.SlotBonus) else snapshot.SlotLevels
			passiveIds, passiveLevels = snapshot.PassiveIds, snapshot.PassiveLevels
			petId, petLevel, petRank = snapshot.PetId, snapshot.PetLevel, snapshot.PetRank
			subclassId = snapshot.SubclassId
			equipped = snapshot.Gear
			extraMods = snapshot.CollectionMods
		end
		if #partyMods > 0 then
			extraMods = if extraMods then table.clone(extraMods) else {}
			for _, mod in ipairs(partyMods) do
				table.insert(extraMods, mod)
			end
		end
		table.insert(
			party,
			StatCalc.NewPartyMember(member.Id, member.Name, classId, level, {
				AbilityIds = loadout,
				SlotLevels = slotLevels,
				PassiveIds = passiveIds,
				PassiveLevels = passiveLevels,
				PetId = petId,
				PetLevel = petLevel,
				PetRank = petRank,
				Equipped = equipped,
				SubclassId = subclassId,
				ExtraMods = extraMods,
			})
		)
	end
	return party
end

-- A party of two or more has an ultimate (any two of its classes may unlock it). The level is the average slot level
-- of the members. `chosenId` is the party's pick (used when valid and unlocked).
function StageRunner.UltimateFor(members, frontier, chosenId)
	if #members < 2 then
		return nil
	end
	local classes, levelLists = {}, {}
	for index, member in ipairs(members) do
		if member.Profile then
			local season = member.Profile.Season
			classes[index] = season.ClassId
			levelLists[index] = SkillProgress.SlotLevelsFor(season, season.Loadouts[season.ClassId])
		else
			classes[index] = member.Snapshot.ClassId
			local snap = member.Snapshot
			levelLists[index] = if snap.SkillLevels then SkillProgress.WithBonus(SkillProgress.LevelsFor(snap.GhostLoadout, snap.SkillLevels), snap.SlotBonus) else snap.SlotLevels
		end
	end
	local id = Ultimates.ResolveParty(classes, frontier, chosenId)
	if id == nil then
		return nil
	end
	return { Id = id, Level = Ultimates.PartyLevel(levelLists) }
end

function StageRunner.Run(members, stage, seed, ultimate, record, setup)
	local sim = Simulation.new({
		Party = StageRunner.NewParty(members),
		Enemies = if setup and setup.Enemies then setup.Enemies else Stages.NewEnemies(stage),
		Waves = setup and setup.Waves,
		Seed = seed,
		Ultimate = ultimate,
		MaxSeconds = if setup and setup.MaxSeconds then setup.MaxSeconds else Stages.TimeLimit(stage),
		RecordEvents = record == true,
		SpawnEnemy = StatCalc.NewEnemy,
		Metrics = setup and setup.Metrics,
	})
	local roster
	if record then
		roster = {}
		local ghosts = {}
		local looks = {}
		for _, member in ipairs(members) do
			if member.Profile == nil then
				ghosts[member.Id] = true
			end
			local worn
			if member.Profile then
				worn = member.Profile.Season.Equipment and member.Profile.Season.Equipment.Equipped
			else
				worn = member.Snapshot.Gear
			end
			looks[member.Id] = Gear.Look(worn)
			looks[member.Id].ClassId = member.Snapshot and member.Snapshot.ClassId or (member.Profile and member.Profile.Season.ClassId) or nil
		end
		for _, team in ipairs({ sim.Party, sim.Enemies }) do
			for _, entity in ipairs(team) do
				table.insert(roster, {
					Id = entity.Id,
					Name = entity.Name,
					Team = entity.Team,
					DefId = entity.DefId,
					PetId = entity.PetId,
					Ghost = ghosts[entity.Id] or nil,
					Look = looks[entity.Id],
					MaxHealth = entity.Stats.MaxHealth,
					Row = sim:RowOf(entity),
					UserId = if entity.Team == "Party" then tonumber(entity.Id) else nil,
				})
			end
		end
	end
	local result = sim:Run()
	local won = result.Winner == "Party"

	local rewards = {}
	if won and not (setup and setup.NoRewards) then
		for _, member in ipairs(members) do
			if member.Profile then
				rewards[member.Id] = Progression.ApplyClear(member.Profile, stage)
			end
		end
	end

	return {
		Won = won,
		Stage = stage,
		NextStage = if won then stage + 1 else math.max(1, stage - 1),
		Rewards = rewards,
		TimedOut = result.Winner == "Timeout",
		Duration = result.Duration,
		Result = result,
		Events = if record then sim.Events else nil,
		Metrics = sim.Metrics,
		Sim = if setup and setup.Metrics then sim else nil,
		Roster = roster,
	}
end

return StageRunner
