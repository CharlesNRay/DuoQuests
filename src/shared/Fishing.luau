--[[
	Fishing (ModuleScript): the fishing pond (Config/Fishing). Pure: the server keeps each player's cast in memory and
	passes clock times (os.clock) in.

	Season.Fishing = { Day, Rewarded, Log = { [fishId] = count } }   (made on first catch)

	  Fishing.Cast(now, rng)                       -> cast = { BiteAt }, wait seconds (the client shows the bite then)
	  Fishing.Reel(profile, cast, now, day, rng)   -> true, { Fish, Name, Glyph, Reward = {lines}, Paid, Left }
	                                                | false, "NoCast" | "TooEarly" | "TooLate"
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
	return { BiteAt = now + wait }, wait
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

function Fishing.Reel(profile, cast, now, day, rng)
	if not cast then
		return false, "NoCast"
	end
	if now < cast.BiteAt - 0.15 then
		return false, "TooEarly"
	end
	if now > cast.BiteAt + Config.Window + Config.Grace then
		return false, "TooLate"
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
