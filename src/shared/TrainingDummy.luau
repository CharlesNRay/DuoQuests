--[[
	TrainingDummy (ModuleScript): "test your build" at the Training Grounds (docs/TOWN.md phase 4). Your whole party
	hits an unkillable dummy for Seconds; the result is the damage per second of each hero. No rewards: it is a tool.
	The dummy has no Defense and does not fight back, so the number is your raw output.

	  TrainingDummy.Run(members, frontier, seed)   members as StageRunner.NewParty takes them
	      -> { Seconds, Total (DPS), Rows = { { Id, Name, Damage, DPS } } }
	  TrainingDummy.Record(profile, total)          -> best so far (kept in Season.DummyBest)
]]
local StageRunner = require(script.Parent.StageRunner)
local StatCalc = require(script.Parent.Combat.StatCalc)

local TrainingDummy = {}

TrainingDummy.Seconds = 20

function TrainingDummy.Run(members, frontier, seed)
	local dummy = StatCalc.NewEnemy("dummy", "TrainingDummy", 1)
	local ultimate = StageRunner.UltimateFor(members, frontier or 1, nil)
	local outcome = StageRunner.Run(members, math.max(1, frontier or 1), seed, ultimate, true, { Enemies = { dummy }, MaxSeconds = TrainingDummy.Seconds })
	local byId, names = {}, {}
	for _, entry in ipairs(outcome.Roster or {}) do
		if entry.Team == "Party" then
			names[entry.Id] = entry.Name
		end
	end
	local ownerOf = {} -- summons count for the hero who raised them
	for _, e in ipairs(outcome.Events or {}) do
		if e.Type == "Spawn" and e.Entity and e.Entity.Owner then
			ownerOf[e.Entity.Id] = e.Entity.Owner
		end
	end
	for _, e in ipairs(outcome.Events or {}) do
		if e.Type == "Damage" and e.Target == "dummy" then
			local id = if names[e.Source] then e.Source else (ownerOf[e.Source] or e.Source)
			byId[id] = (byId[id] or 0) + (e.Amount or 0)
		end
	end
	local seconds = math.max(outcome.Duration or TrainingDummy.Seconds, 1)
	local rows, total = {}, 0
	for id, damage in pairs(byId) do
		if names[id] then
			table.insert(rows, { Id = id, Name = names[id], Damage = math.floor(damage), DPS = math.floor(damage / seconds) })
			total += damage
		end
	end
	table.sort(rows, function(a, b)
		return a.Damage > b.Damage
	end)
	return { Seconds = seconds, Total = math.floor(total / seconds), Rows = rows }
end

function TrainingDummy.Record(profile, total)
	local best = profile.Season.DummyBest or 0
	if total > best then
		profile.Season.DummyBest = total
		best = total
	end
	return best
end

return TrainingDummy
