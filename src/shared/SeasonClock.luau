--[[
	SeasonClock (ModuleScript)
	Location: ReplicatedStorage > Shared > SeasonClock

	Which season is running, from the schedule in Config/Seasons. Ask every time (never cache the id at require time):
	a server can live across a season switch.

	  SeasonClock.CurrentId(now?)   -> id of the newest season whose StartsAt <= now (the first season before any start)
	  SeasonClock.CurrentIdFor(schedule, now) the same rule for any schedule (tests)
	  SeasonClock.Def(id)           -> the season's table | nil
	  SeasonClock.Ended(id, now?)   -> true once its EndsAt has passed
	  SeasonClock.Ids(now?)         -> every season id up to the current one, ascending
	  SeasonClock.StartNext(now?)   -> new id. TEST ONLY (Studio cheat, headless tests): ends the current season now and
	                                   starts the next (a made-up "Test Season N" if the schedule has none). Lives in this
	                                   server's memory only.
	  SeasonClock.IsTest()          -> true while StartNext's made-up schedule is in use (keep real DataStores out of it)
	  SeasonClock.ClearOverride()   -- back to the real schedule
]]

local Config = require(script.Parent.Config.Seasons)

local SeasonClock = {}

local override = nil -- { Id = n, Defs = { [id] = def } }

function SeasonClock.Def(id)
	if override and override.Defs[id] then
		return override.Defs[id]
	end
	return Config.Seasons[id]
end

-- The pure rule, for any schedule ({ [id] = { StartsAt } }): the newest season that has started, else the first.
function SeasonClock.CurrentIdFor(schedule, now)
	local best, first = nil, nil
	for id, def in pairs(schedule) do
		if first == nil or id < first then
			first = id
		end
		if def.StartsAt <= now and (best == nil or id > best) then
			best = id
		end
	end
	return best or first or 1
end

function SeasonClock.CurrentId(now)
	if override then
		return override.Id
	end
	return SeasonClock.CurrentIdFor(Config.Seasons, now or os.time())
end

function SeasonClock.Ended(id, now)
	local def = SeasonClock.Def(id)
	return def ~= nil and (now or os.time()) >= def.EndsAt
end

function SeasonClock.Ids(now)
	local current = SeasonClock.CurrentId(now)
	local out = {}
	for id = 1, current do
		if SeasonClock.Def(id) then
			table.insert(out, id)
		end
	end
	return out
end

function SeasonClock.StartNext(now)
	now = now or os.time()
	local current = SeasonClock.CurrentId(now)
	override = override or { Defs = {} }
	local def = table.clone(SeasonClock.Def(current) or { Id = current, Name = "Season " .. current, StartsAt = now })
	def.EndsAt = math.min(def.EndsAt or now, now)
	override.Defs[current] = def
	local nextId = current + 1
	local planned = Config.Seasons[nextId]
	local nextDef = if planned then table.clone(planned) else { Id = nextId, Name = "Test Season " .. nextId, EndsAt = now + 14 * 86400, Mechanic = "None" }
	nextDef.StartsAt = now
	override.Defs[nextId] = nextDef
	override.Id = nextId
	return nextId
end

function SeasonClock.IsTest()
	return override ~= nil
end

function SeasonClock.ClearOverride()
	override = nil
end

return SeasonClock
