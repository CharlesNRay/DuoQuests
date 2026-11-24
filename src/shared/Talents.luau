--[[
	Talents (ModuleScript): spend level-up points on small stat boosts (Config/Talents). Pure.

	Season.Talents = { [talentId] = rank }   (made on first spend; a new season starts empty, like the level)

	  Talents.Points(profile)            -> total, spent, free
	  Talents.Spend(profile, id, n?)     -> true | false, "BadTalent" | "NoPoints" | "MaxRank" | "Locked"   (n ranks, default 1)
	  Talents.Rank(profile, id)          -> rank (0 when none)
	  Talents.Rewards(profile)           -> { GoldGain, XPGain } from Fortune (Mastery)
	  Talents.PartyMods(spiritRanks)     -> mods for every party member from the party's summed Party Spirit ranks
	  Talents.Reset(profile)             -> true   (free: every point comes back)
	  Talents.AutoSpend(profile)         -> ranks spent, following Config.Builds for the hero's class role
	  Talents.Mods(profile)              -> { { Stat, Mode, Value } } for StatCalc (ExtraMods)
	  Talents.Status(profile)            -> { Total, Spent, Free, MasteryLevel, List = { { Id, Name, Glyph, Rank, MaxRank, Now, Next, Label, Mastery, Locked, Unlock } } }
	  Talents.Describe(id, rank)         -> "+4.5% Attack" (what that many ranks give)
]]
local Config = require(script.Parent.Config.Talents)
local Classes = require(script.Parent.Config.Classes)

local Talents = {}

local function ranks(profile)
	return profile.Season.Talents or {}
end

function Talents.Points(profile)
	local total = math.max(0, (profile.Season.Level or 1) - 1) * Config.PointsPerLevel
	local spent = 0
	for _, r in pairs(ranks(profile)) do
		spent += r
	end
	return total, spent, math.max(0, total - spent)
end

function Talents.Rank(profile, id)
	return ranks(profile)[id] or 0
end

function Talents.Describe(id, rank)
	local def = Config.Defs[id]
	if not def then
		return ""
	end
	local value = def.PerRank * rank
	if value < 0 then -- Fortitude: "-6% Damage taken"
		local pct = -value * 100
		local text = if pct == math.floor(pct) then ("%d"):format(pct) else ("%.1f"):format(pct)
		return ("-%s%% %s"):format(text, def.Label)
	end
	if def.Stat == "CritMultiplier" then
		return ("+%d%% %s"):format(math.floor(value * 100 + 0.5), def.Label)
	end
	local pct = value * 100
	local text = if pct == math.floor(pct) then ("%d"):format(pct) else ("%.1f"):format(pct)
	return ("+%s%% %s"):format(text, def.Label)
end

function Talents.Spend(profile, id, n)
	local def = Config.Defs[id]
	if not def then
		return false, "BadTalent"
	end
	n = math.max(1, math.floor(tonumber(n) or 1))
	local _, _, free = Talents.Points(profile)
	if free < 1 then
		return false, "NoPoints"
	end
	if def.Unlock and (profile.Season.Level or 1) < def.Unlock then
		return false, "Locked"
	end
	local t = profile.Season.Talents or {}
	profile.Season.Talents = t
	local have = t[id] or 0
	if have >= def.MaxRank then
		return false, "MaxRank"
	end
	t[id] = have + math.min(n, free, def.MaxRank - have)
	return true
end

function Talents.Reset(profile)
	profile.Season.Talents = {}
	return true
end

function Talents.AutoSpend(profile)
	local class = Classes[profile.Season.ClassId]
	local build = Config.Builds[class and class.Role or "Damage"] or Config.Builds.Damage
	local spent = 0
	local guard = 0
	while guard < 400 do
		guard += 1
		local _, _, free = Talents.Points(profile)
		if free < 1 then
			break
		end
		local any = false
		for _, id in ipairs(build) do
			if select(3, Talents.Points(profile)) < 1 then
				break
			end
			if Talents.Spend(profile, id) then
				spent += 1
				any = true
			end
		end
		if not any then -- the build is full: anything left goes in table order
			for _, id in ipairs(Config.Order) do
				if Talents.Spend(profile, id) then
					spent += 1
					any = true
					break
				end
			end
			if not any then
				break
			end
		end
	end
	return spent
end

function Talents.Mods(profile)
	local mods = {}
	for id, rank in pairs(ranks(profile)) do
		local def = Config.Defs[id]
		if def and rank > 0 and (def.Mode == "Mul" or def.Mode == "Add") then -- Party and Reward talents work elsewhere
			table.insert(mods, { Stat = def.Stat, Mode = def.Mode, Value = def.PerRank * rank })
		end
	end
	return mods
end

function Talents.Rewards(profile)
	local value = Config.Defs.Fortune.PerRank * Talents.Rank(profile, "Fortune")
	return { GoldGain = value, XPGain = value }
end

-- Party Spirit: the ranks of everyone in the fight add up and every member gets the bonus
function Talents.PartyMods(spiritRanks)
	if not spiritRanks or spiritRanks <= 0 then
		return {}
	end
	local value = Config.Defs.PartySpirit.PerRank * spiritRanks
	return { { Stat = "Attack", Mode = "Mul", Value = value }, { Stat = "MaxHealth", Mode = "Mul", Value = value } }
end

function Talents.Status(profile)
	local total, spent, free = Talents.Points(profile)
	local out = { Total = total, Spent = spent, Free = free, MasteryLevel = Config.MasteryLevel, List = {} }
	local level = profile.Season.Level or 1
	local r = ranks(profile)
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		local rank = r[id] or 0
		table.insert(out.List, {
			Id = id, Name = def.Name, Glyph = def.Glyph, Rank = rank, MaxRank = def.MaxRank, Label = def.Label,
			Now = Talents.Describe(id, rank), Next = if rank < def.MaxRank then Talents.Describe(id, 1) else nil,
			Mastery = def.Mastery == true, Unlock = def.Unlock, Locked = def.Unlock ~= nil and level < def.Unlock,
		})
	end
	return out
end

return Talents
