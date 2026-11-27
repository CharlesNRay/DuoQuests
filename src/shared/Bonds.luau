--[[
	Bonds (ModuleScript): the season mechanic "Bonds" (Config/Bonds).

	Season.Bonds = { [heroKey] = xp }, Season.BondNames = { [heroKey] = player name }   heroKey = tostring(userId) for a player, "c:" .. name for a companion
	  Bonds.On(seasonId?)               -> true when the current (or given) season's Mechanic is "Bonds"
	  Bonds.KeyOf(member)               -> heroKey of a fight member { Id, Name, Snapshot? } (companions have negative ids)
	  Bonds.Level(xp)                   -> level, xp into it, xp the level needs (nil at max)
	  Bonds.Mods(bonds, selfKey, keys)  -> stat mods for the hero selfKey from its bonds with the other heroes in keys
	  Bonds.Gain(profile, selfKey, keys, names?) -> list of { Key, Level } bonds that levelled up (also grants titles)
	  Bonds.List(profile)               -> rows for the UI, best first: { Key, Name, Level, Into, Need, Companion }
]]
local Config = require(script.Parent.Config.Bonds)
local SeasonClock = require(script.Parent.SeasonClock)
local Cosmetics = require(script.Parent.Cosmetics)

local Bonds = {}

function Bonds.On(seasonId)
	local def = SeasonClock.Def(seasonId or SeasonClock.CurrentId())
	return def ~= nil and def.Mechanic == Config.Mechanic
end

function Bonds.KeyOf(member)
	local id = tonumber(member.Id)
	if id ~= nil and id < 0 then
		return "c:" .. tostring(member.Name)
	end
	return tostring(member.Id)
end

local function isCompanion(heroKey)
	return heroKey:sub(1, 2) == "c:"
end

function Bonds.Level(xp)
	xp = xp or 0
	local level = math.min(Config.MaxLevel, math.floor(math.sqrt(xp / Config.XPBase)))
	if level >= Config.MaxLevel then
		return level, 0, nil
	end
	local base = Config.XPBase * level * level
	return level, xp - base, Config.XPBase * (level + 1) * (level + 1) - base
end

function Bonds.Mods(bonds, selfKey, keys)
	if not bonds then
		return {}
	end
	local levels = 0
	for _, other in ipairs(keys) do
		if other ~= selfKey then
			levels += (Bonds.Level(bonds[other]))
		end
	end
	if levels <= 0 then
		return {}
	end
	local value = Config.PerLevel * levels
	return { { Stat = "Attack", Mode = "Mul", Value = value }, { Stat = "MaxHealth", Mode = "Mul", Value = value } }
end

function Bonds.Gain(profile, selfKey, keys, names)
	local season = profile.Season
	season.Bonds = season.Bonds or {}
	season.BondNames = season.BondNames or {}
	local ups = {}
	for _, other in ipairs(keys) do
		if other ~= selfKey then
			local before = Bonds.Level(season.Bonds[other])
			local gain = Config.XPPerWin * (if isCompanion(other) then Config.CompanionShare else 1)
			season.Bonds[other] = (season.Bonds[other] or 0) + gain
			if names and names[other] and not isCompanion(other) then
				season.BondNames[other] = names[other]
			end
			local after = Bonds.Level(season.Bonds[other])
			if after > before then
				table.insert(ups, { Key = other, Level = after })
				local title = Config.Titles[after]
				if title then
					Cosmetics.GrantTitle(profile, title)
				end
			end
		end
	end
	return ups
end

function Bonds.List(profile)
	local names = profile.Season.BondNames
	local rows = {}
	for heroKey, xp in pairs(profile.Season.Bonds or {}) do
		local level, into, need = Bonds.Level(xp)
		local companion = isCompanion(heroKey)
		table.insert(rows, {
			Key = heroKey,
			Name = if companion then heroKey:sub(3) else (names and names[heroKey]) or ("Player " .. heroKey),
			Level = level, Into = math.floor(into), Need = need, Companion = companion,
		})
	end
	table.sort(rows, function(a, b)
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return a.Into > b.Into
	end)
	return rows
end

return Bonds
