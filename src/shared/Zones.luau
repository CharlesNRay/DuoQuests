--[[
	Zones (ModuleScript)
	Location: ReplicatedStorage > Shared > Zones

	Pure rules for which zone a stage belongs to. The data is in Config/Zones.

	  Zones.IndexForStage(stage)      -> zone number, 1-based (10 stages each)
	  Zones.ForStage(stage)           -> { Index, Name, Theme, FirstStage, LastStage, Loop }
	                                     Theme is the Config/Zones entry; Loop is
	                                     1 the first time through the list, then 2...
	  Zones.StageInZone(stage)        -> 1..BossEvery (the boss is the last)
	  Zones.Count()                   -> number of authored zones
]]

local Config = require(script.Parent.Config.Zones)
local StageConfig = require(script.Parent.Config.Stages)

local Zones = {}

function Zones.Count()
	return #Config
end

function Zones.IndexForStage(stage)
	return (math.max(1, stage) - 1) // StageConfig.BossEvery + 1
end

function Zones.StageInZone(stage)
	return (math.max(1, stage) - 1) % StageConfig.BossEvery + 1
end

function Zones.ForStage(stage)
	local index = Zones.IndexForStage(stage)
	local themeIndex = (index - 1) % #Config + 1
	local loop = (index - 1) // #Config + 1
	local theme = Config[themeIndex]
	return {
		Index = index,
		Name = if loop > 1 then theme.Name .. " " .. loop else theme.Name,
		Theme = theme,
		FirstStage = (index - 1) * StageConfig.BossEvery + 1,
		LastStage = index * StageConfig.BossEvery,
		Loop = loop,
	}
end

return Zones
