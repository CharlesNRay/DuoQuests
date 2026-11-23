--[[
	Fishing (ModuleScript): the fishing pond (Config/Fishing). Pure: the server keeps each player's cast in memory and
	passes clock times (os.clock) in.

	Season.Fishing = { Day, Rewarded, Log = { [fishId] = count } }   (made on first catch)

	  Fishing.Cast(now, rng)                       -> cast = { BiteAt, Zone }, info = { Wait, Zone, ZoneWidth, Speed, Laps }
	                                                  (the client starts the dial at the bite; Zone = start angle of the gold zone)
	  Fishing.Reel(profile, cast, now, day, rng, clientElapsed)
	                                               -> true, { Fish, Name, Glyph, Reward = {lines}, Paid, Left }
	                                                | false, "NoCast" | "TooEarly" | "TooLate" | "Missed"
	      clientElapsed = seconds the player saw the needle spin; the server only trusts it within the round-trip slack
	  Fishing.InZone(elapsed, zone)                -> was the needle in the gold zone after `elapsed` seconds?
	  Fishing.Roll(rng)                            -> a fish def
	  Fishing.Status(profile, day)                 -> { Left, Caught, Log = { { Id, Name, Glyph, Count } } }
]]
local Config = require(script.Parent.Config.Fishing)
local Consumables = require(script.Parent.Consumables)
local ConsumableConfig = require(script.Parent.Config.Consumables)

local Fishing = {}

local totalWeight = 0
for _, f in ipairs(Config.Fish) do
	totalWeight += f.Weight
end

function Fishing.Cast(now, rng)
	rng = rng or math.random
	local wait = Config.WaitMin + rng() * (Config.WaitMax - Config.WaitMin)
	-- the zone never covers the top, so the needle always has to travel to it
	local zone = 50 + rng() * (360 - 100 - Config.ZoneWidth)
	return { BiteAt = now + wait, Zone = zone }, { Wait = wait, Zone = zone, ZoneWidth = Config.ZoneWidth, Speed = Config.Speed, Laps = Config.Laps }
end

function Fishing.InZone(elapsed, zone)
	local angle = (elapsed * Config.Speed) % 360
	return angle >= zone - Config.Tolerance and angle <= zone + Config.ZoneWidth + Config.Tolerance
end

function Fishing.Roll(rng)
	local r = (rng or math.random)() * totalWeight
	for _, f in ipairs(Config.Fish) do
		r -= f.Weight
		if r <= 0 then
			return f
		end
	end
	return Config.Fish[#Config.Fish]
end

local function state(profile, day)
	local s = profile.Season.Fishing
	if not s then
		s = { Day = day, Rewarded = 0, Log = {} }
		profile.Season.Fishing = s
	end
	if s.Day ~= day then
		s.Day, s.Rewarded = day, 0
	end
	s.Log = s.Log or {}
	return s
end

local function rewardLines(reward)
	local lines = {}
	if reward.Wishstones then
		table.insert(lines, ("%d Wishstone%s"):format(reward.Wishstones, if reward.Wishstones == 1 then "" else "s"))
	end
	for id, n in pairs(reward.Items or {}) do
		local def = ConsumableConfig.Defs[id]
		table.insert(lines, ("%dx %s"):format(n, def and def.DisplayName or id))
	end
	return lines
end

function Fishing.Reel(profile, cast, now, day, rng, clientElapsed)
	if not cast then
		return false, "NoCast"
	end
	if now < cast.BiteAt - 0.15 then
		return false, "TooEarly"
	end
	local spin = Config.Laps * 360 / Config.Speed
	local serverElapsed = now - cast.BiteAt
	if serverElapsed > spin + Config.Grace then
		return false, "TooLate"
	end
	-- what the player saw, held to the server's clock within the round trip
	local elapsed = math.clamp(tonumber(clientElapsed) or serverElapsed, serverElapsed - 0.8, serverElapsed + 0.2)
	if elapsed > spin then
		return false, "TooLate"
	end
	if not Fishing.InZone(math.max(elapsed, 0), cast.Zone or 0) then
		return false, "Missed"
	end
	local fish = Fishing.Roll(rng)
	local s = state(profile, day)
	s.Log[fish.Id] = (s.Log[fish.Id] or 0) + 1
	local paid = s.Rewarded < Config.DailyRewarded
	local lines = {}
	if paid then
		s.Rewarded += 1
		local c = profile.Season.Currencies
		if fish.Reward.Wishstones then
			c.Wishstones = (c.Wishstones or 0) + fish.Reward.Wishstones
		end
		for id, n in pairs(fish.Reward.Items or {}) do
			Consumables.Grant(profile, id, n)
		end
		lines = rewardLines(fish.Reward)
	end
	return true, { Fish = fish.Id, Name = fish.Name, Glyph = fish.Glyph, Reward = lines, Paid = paid, Left = Config.DailyRewarded - s.Rewarded }
end

function Fishing.Status(profile, day)
	local s = profile.Season.Fishing
	local rewarded = if s and s.Day == day then s.Rewarded else 0
	local out = { Left = Config.DailyRewarded - rewarded, Caught = 0, Log = {} }
	for _, f in ipairs(Config.Fish) do
		local n = s and s.Log and s.Log[f.Id] or 0
		out.Caught += n
		table.insert(out.Log, { Id = f.Id, Name = f.Name, Glyph = f.Glyph, Count = n })
	end
	return out
end

return Fishing
