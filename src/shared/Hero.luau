--[[
	Hero (ModuleScript)
	Location: ReplicatedStorage > Shared > Hero

	The character sheet: the stats a hero really fights with (class + level + passives +
	subclass + gear + pet, exactly as StatCalc builds them) and its worn gear as UI rows.
	Works for a live profile and for a party snapshot alike.

	  Hero.Sheet(info)  info = { ClassId, Level, PassiveIds, PassiveLevels, SubclassId,
	                             Gear (worn items by slot), PetId, PetLevel }
	                    -> { Stats = { { Label, Value, Key } }, Gear = { [slot] = row } }
]]
local StatCalc = require(script.Parent.Combat.StatCalc)
local Gear = require(script.Parent.Gear)

local Hero = {}

local function pct(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local NumberFormat = require(script.Parent.Util.NumberFormat)

local function plain(value)
	if value < 10 then
		return ("%.1f"):format(value)
	end
	return NumberFormat.Short(value)
end

function Hero.Sheet(info)
	local entity = StatCalc.NewPartyMember("sheet", "sheet", info.ClassId, info.Level, {
		PassiveIds = info.PassiveIds,
		PassiveLevels = info.PassiveLevels,
		SubclassId = info.SubclassId,
		Equipped = info.Gear,
		PetId = info.PetId,
		PetLevel = info.PetLevel,
		PetRank = info.PetRank,
		ExtraMods = info.ExtraMods,
	})
	local s = entity.Stats
	local stats = {
		{ Label = "Health", Key = "MaxHealth", Value = plain(s.MaxHealth) },
		{ Label = "Attack", Key = "Attack", Value = plain(s.Attack or 0) },
		{ Label = "Defense", Key = "Defense", Value = plain(s.Defense or 0) },
		{ Label = "Attack speed", Key = "AttackSpeed", Value = ("%.2f/s"):format(s.AttackSpeed or 1) },
		{ Label = "Crit chance", Key = "CritChance", Value = pct(s.CritChance or 0) },
		{ Label = "Crit damage", Key = "CritMultiplier", Value = ("x%.2f"):format(s.CritMultiplier or 1.5) },
	}
	local function extra(label, key, value, good)
		if value and math.abs(value - 1) > 0.001 then
			table.insert(stats, { Label = label, Key = key, Value = (if value >= 1 then "+" else "-") .. pct(math.abs(value - 1)), Good = good })
		end
	end
	if (s.Haste or 0) > 0.0005 then
		table.insert(stats, { Label = "Haste", Key = "Haste", Value = "+" .. pct(math.min(s.Haste, 0.5)), Good = true })
	end
	extra("Damage dealt", "DamageDealt", s.DamageDealt, true)
	extra("Healing", "HealingDealt", s.HealingDealt, true)
	extra("Damage taken", "DamageTaken", s.DamageTaken, false)

	local rows = {}
	for slotName, item in pairs(info.Gear or {}) do
		rows[slotName] = Gear.Row(item)
	end
	return { Stats = stats, Gear = rows }
end

return Hero
