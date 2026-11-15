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
	  StageRunner.Run(members, stage, seed, ultimate)  -> outcome
	                                         (ultimate optional, from UltimateFor)

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

local StageRunner = {}

function StageRunner.NewParty(members)
	local party = {}
	for _, member in ipairs(members) do
		local classId, level, loadout, slotLevels, passiveIds, passiveLevels
		if member.Profile then
			local season = member.Profile.Season
			classId, level = season.ClassId, season.Level
			loadout, slotLevels = season.Loadouts[classId], season.SlotLevels[classId]
			passiveIds, passiveLevels = season.PassiveLoadouts[classId], season.PassiveSlotLevels[classId]
		else
			local snapshot = member.Snapshot
			classId, level = snapshot.ClassId, snapshot.Level
			loadout, slotLevels = snapshot.GhostLoadout, snapshot.SlotLevels
			passiveIds, passiveLevels = snapshot.PassiveIds, snapshot.PassiveLevels
		end
		table.insert(
			party,
			StatCalc.NewPartyMember(member.Id, member.Name, classId, level, {
				AbilityIds = loadout,
				SlotLevels = slotLevels,
				PassiveIds = passiveIds,
				PassiveLevels = passiveLevels,
			})
		)
	end
	return party
end

-- Only a full pair has an ultimate. The level is the average slot level of the
-- two members. `chosenId` is the party's pick (used when valid and unlocked).
function StageRunner.UltimateFor(members, frontier, chosenId)
	if #members ~= 2 then
		return nil
	end
	local classes, levelLists = {}, {}
	for index, member in ipairs(members) do
		if member.Profile then
			local season = member.Profile.Season
			classes[index] = season.ClassId
			levelLists[index] = season.SlotLevels[season.ClassId]
		else
			classes[index] = member.Snapshot.ClassId
			levelLists[index] = member.Snapshot.SlotLevels
		end
	end
	local id = Ultimates.Resolve(classes[1], classes[2], frontier, chosenId)
	if id == nil then
		return nil
	end
	return { Id = id, Level = Ultimates.PartyLevel(levelLists) }
end

function StageRunner.Run(members, stage, seed, ultimate)
	local sim = Simulation.new({
		Party = StageRunner.NewParty(members),
		Enemies = Stages.NewEnemies(stage),
		Seed = seed,
		Ultimate = ultimate,
		MaxSeconds = Stages.TimeLimit(stage),
		RecordEvents = false,
	})
	local result = sim:Run()
	local won = result.Winner == "Party"

	local rewards = {}
	if won then
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
	}
end

return StageRunner
