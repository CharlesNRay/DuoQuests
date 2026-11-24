--[[
	Passes (ModuleScript): permanent Game Pass perks (Config/Premium.Passes). Pure and shared so tests and the server agree.

	  Passes.Has(profile, passId)       -> true when the pass is owned
	  Passes.Grant(profile, passId)     -> true (false, "BadPass" for an unknown id); safe to call again
	  Passes.Perks(profile)             -> { GoldGain, XPGain, BagSlots, DungeonKeys, PetSlots, CharacterSlots } summed over owned passes (zeros when none)
	  Passes.List(profile)              -> { { Id, Name, Text, Robux, Available, Owned } } for the shop
]]
local Config = require(script.Parent.Config.Premium)

local Passes = {}

local function owned(profile)
	local permanent = profile.Permanent
	if permanent == nil then
		return {} -- a bare test profile
	end
	if type(permanent.Passes) ~= "table" then
		permanent.Passes = {}
	end
	return permanent.Passes
end

function Passes.Has(profile, passId)
	return owned(profile)[passId] == true
end

function Passes.Grant(profile, passId)
	if Config.Passes[passId] == nil then
		return false, "BadPass"
	end
	owned(profile)[passId] = true
	return true
end

function Passes.Perks(profile)
	local sum = { GoldGain = 0, XPGain = 0, BagSlots = 0, DungeonKeys = 0, PetSlots = 0, CharacterSlots = 0 }
	for id, def in pairs(Config.Passes) do
		if owned(profile)[id] then
			for key, value in pairs(def.Perks) do
				sum[key] = (sum[key] or 0) + value
			end
		end
	end
	return sum
end

function Passes.List(profile)
	local list = {}
	for id, def in pairs(Config.Passes) do
		table.insert(list, { Id = id, Name = def.Name, Text = def.Text, Robux = def.Robux, Available = def.GamePassId ~= 0, Owned = owned(profile)[id] == true })
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

return Passes
