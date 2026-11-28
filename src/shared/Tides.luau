--[[
	Tides (ModuleScript)
	Location: ReplicatedStorage > Shared > Tides

	The season mechanic "Elemental Tides" (Config/Tides, docs/SEASONS.md). Pure: everything takes the time.

	  Tides.On(seasonId?)                -> true when the season (default: the current one) runs Tides
	  Tides.Week(now)                    -> 0-based week of the current season
	  Tides.Element(now)                 -> id, def of the rising element this week
	  Tides.Spotlight(now)               -> class id in the spotlight this week
	  Tides.ZoneElement(zoneIndex)       -> element id of a zone (zones past 20 loop round), or nil
	  Tides.Rising(stage, now)           -> the element def when this stage's zone is rising (Tides on), else nil
	  Tides.EnemyMult(stage, now)        -> enemy health and attack factor for this stage (1 when not rising)
	  Tides.Rewards(stage, now)          -> { GoldGain, XPGain, RuneRolls } extra for a win on this stage (zeros when not rising)
	  Tides.ClassMods(classId, now)      -> stat mods for a hero of this class in stage fights (the spotlight), or {}
	  Tides.Status(now)                  -> what the UI shows, or nil when Tides is off
]]

local Config = require(script.Parent.Config.Tides)
local ZoneConfig = require(script.Parent.Config.Zones)
local SeasonClock = require(script.Parent.SeasonClock)
local Zones = require(script.Parent.Zones)

local Tides = {}

local zoneElement = {}
for id, def in pairs(Config.Elements) do
	for _, zone in ipairs(def.Zones) do
		zoneElement[zone] = id
	end
end

function Tides.On(seasonId)
	local def = SeasonClock.Def(seasonId or SeasonClock.CurrentId())
	return def ~= nil and def.Mechanic == Config.Mechanic
end

function Tides.Week(now)
	local def = SeasonClock.Def(SeasonClock.CurrentId(now))
	local start = def and def.StartsAt or 0
	return math.max(0, (now - start) // Config.Week)
end

function Tides.Element(now)
	local id = Config.Order[Tides.Week(now) % #Config.Order + 1]
	return id, Config.Elements[id]
end

function Tides.Spotlight(now)
	return Config.Spotlight[Tides.Week(now) % #Config.Spotlight + 1]
end

function Tides.ZoneElement(zoneIndex)
	return zoneElement[(zoneIndex - 1) % #ZoneConfig + 1]
end

function Tides.Rising(stage, now)
	if not Tides.On() then
		return nil
	end
	local id, def = Tides.Element(now)
	if Tides.ZoneElement(Zones.IndexForStage(stage)) == id then
		return def
	end
	return nil
end

function Tides.EnemyMult(stage, now)
	return if Tides.Rising(stage, now) then 1 + Config.Power else 1
end

function Tides.Rewards(stage, now)
	if Tides.Rising(stage, now) then
		return { GoldGain = Config.GoldGain, XPGain = Config.XPGain, RuneRolls = Config.RuneRolls }
	end
	return { GoldGain = 0, XPGain = 0, RuneRolls = 0 }
end

function Tides.ClassMods(classId, now)
	if Tides.On() and classId == Tides.Spotlight(now) then
		return Config.SpotlightMods
	end
	return {}
end

function Tides.Status(now)
	if not Tides.On() then
		return nil
	end
	local id, def = Tides.Element(now)
	local zones = {}
	for _, zone in ipairs(def.Zones) do
		table.insert(zones, ZoneConfig[zone].Name)
	end
	local seasonDef = SeasonClock.Def(SeasonClock.CurrentId(now))
	local start = seasonDef and seasonDef.StartsAt or now
	local week = Tides.Week(now)
	local nextId = Config.Order[(week + 1) % #Config.Order + 1]
	return {
		Element = id,
		Name = def.Name,
		Color = def.Color,
		Zones = zones,
		ZoneIndexes = def.Zones,
		EndsAt = start + (week + 1) * Config.Week,
		Next = Config.Elements[nextId].Name,
		Spotlight = Tides.Spotlight(now),
		Power = Config.Power,
		GoldGain = Config.GoldGain,
		XPGain = Config.XPGain,
	}
end

return Tides
