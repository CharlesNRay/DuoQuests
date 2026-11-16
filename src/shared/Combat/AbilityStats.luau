--[[
	AbilityStats (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > AbilityStats

	Turns an ability definition plus a slot level into the actual numbers it
	uses. The simulation and the UI both read through here, so what a player
	sees is exactly what combat does.

	EVERY SKILL GROWS ITS OWN STATS. An effect lists how much each field gains
	per level above 1 in a PerLevel table:

	  { Type = "Damage", Target = "Primary", Multiplier = 1.4,
	    PerLevel = { Multiplier = 0.06 } }

	  { Type = "Shield", Target = "Self", PercentMaxHealth = 0.30, Duration = 10,
	    PerLevel = { PercentMaxHealth = 0.012, Duration = 0.2 } }

	  { Type = "ApplyStatus", Target = "Self", Status = "IronSkin", Duration = 8,
	    PerLevel = { Duration = 0.3, Strength = 0.04 } }   -- Strength scales a
	                                                       -- status's stat changes

	The ability itself may also shrink its cooldown:
	  CooldownPerLevel = -0.15   seconds per level (never below MinCooldown, default 1)

	Fields with no PerLevel entry keep the old behaviour for numbers that are
	power (Multiplier, PercentMaxHealth): they grow by the rarity's (or the
	skill's LevelBonus) percentage per level. Anything else stays fixed. Real
	skills should list PerLevel explicitly; the fallback keeps simple test
	abilities and deferred classes working.

	  AbilityStats.Value(ability, effect, field, level)  -> number
	  AbilityStats.Cooldown(ability, level)              -> seconds
	  AbilityStats.Rows(ability, level)                  -> { { Label, Value } } for UI
]]

local Rarities = require(script.Parent.Parent.Config.Rarities)

local AbilityStats = {}

-- Abilities wind up before their effects land, then the caster can't start
-- another ability for AfterCastDelay seconds (basic attacks carry on).
AbilityStats.AfterCastDelay = 1.0
AbilityStats.DefaultCastTime = { Damage = 0.6, AoE = 0.9, Heal = 0.7, Shield = 0.5, Buff = 0.4 }

function AbilityStats.CastTime(ability)
	if ability.CastTime ~= nil then
		return ability.CastTime
	end
	local first = ability.Effects and ability.Effects[1]
	local kind = first and first.Type or "Buff"
	if kind == "Damage" then
		return if first.Target == "AllEnemies" then AbilityStats.DefaultCastTime.AoE else AbilityStats.DefaultCastTime.Damage
	elseif kind == "Heal" or kind == "Revive" then
		return AbilityStats.DefaultCastTime.Heal
	elseif kind == "Shield" then
		return AbilityStats.DefaultCastTime.Shield
	end
	return AbilityStats.DefaultCastTime.Buff
end

local POWER_FIELDS = { Multiplier = true, PercentMaxHealth = true }

local function rarityBonus(ability)
	local rarity = Rarities[ability.Rarity]
	return ability.LevelBonus or (rarity and rarity.PowerPerLevel) or 0.1
end

function AbilityStats.Value(ability, effect, field, level)
	local base = effect[field]
	if base == nil then
		return nil
	end
	local steps = math.max(0, (level or 1) - 1)
	local perLevel = effect.PerLevel
	if perLevel and perLevel[field] ~= nil then
		return base + perLevel[field] * steps
	end
	if POWER_FIELDS[field] then
		return base * (1 + rarityBonus(ability) * steps)
	end
	return base
end

-- Status strength: 1 unless the effect says otherwise, grown per level.
function AbilityStats.Strength(ability, effect, level)
	local perLevel = effect.PerLevel
	local steps = math.max(0, (level or 1) - 1)
	local base = effect.Strength or 1
	return base + (if perLevel and perLevel.Strength then perLevel.Strength else 0) * steps
end

function AbilityStats.Cooldown(ability, level)
	local base = ability.Cooldown or 0
	if ability.CooldownPerLevel == nil then
		return base
	end
	local steps = math.max(0, (level or 1) - 1)
	return math.max(ability.MinCooldown or 1, base + ability.CooldownPerLevel * steps)
end

local function pct(value)
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

local function seconds(value)
	return string.format("%.1fs", value)
end

-- A short list of { Label, Value } strings describing the skill at a level.
function AbilityStats.Rows(ability, level)
	local rows = {}
	local function add(label, value)
		table.insert(rows, { Label = label, Value = value })
	end

	for _, effect in ipairs(ability.Effects or {}) do
		local kind = effect.Type
		if kind == "Damage" then
			add("Damage", pct(AbilityStats.Value(ability, effect, "Multiplier", level)))
			if effect.PercentTargetHealth then
				add("Bonus", ("+%.1f%% of its max HP"):format(effect.PercentTargetHealth * (1 + 0.05 * math.max(0, (level or 1) - 1)) * 100))
			end
		elseif kind == "Heal" or kind == "Shield" then
			local label = if kind == "Heal" then "Heal" else "Shield"
			if effect.Multiplier then
				add(label, pct(AbilityStats.Value(ability, effect, "Multiplier", level)) .. " of Attack")
			end
			if effect.PercentMaxHealth then
				add(label, pct(AbilityStats.Value(ability, effect, "PercentMaxHealth", level)) .. " max HP")
			end
			if kind == "Shield" and effect.Duration then
				add("Lasts", seconds(AbilityStats.Value(ability, effect, "Duration", level)))
			end
		elseif kind == "Cleanse" then
			add("Cleanse", "Removes every debuff")
		elseif kind == "ApplyStatus" then
			local statusDef = require(script.Parent.Parent.Config.Statuses)[effect.Status]
			local name = (statusDef and statusDef.DisplayName) or "Effect"
			local text = seconds(AbilityStats.Value(ability, effect, "Duration", level))
			if statusDef and statusDef.Stacks then
				text ..= (" (stacks to %d)"):format(statusDef.Stacks.Max)
			end
			add(name, text)
		elseif kind == "SpendHealth" then
			add("Costs", pct(AbilityStats.Value(ability, effect, "Fraction", level)) .. " of your max HP")
		elseif kind == "Raise" then
			local def = require(script.Parent.Parent.Config.Minions)[effect.MinionId]
			add("Summons", ("%d x %s (max %d)"):format(effect.Count or 1, def and def.DisplayName or effect.MinionId, effect.Max or 99))
			if effect.PerLevel and effect.PerLevel.Power then
				add("Minion power", pct(AbilityStats.Value(ability, effect, "Power", level)))
			end
		elseif kind == "Devour" then
			add("Heals", pct(AbilityStats.Value(ability, effect, "PercentMaxHealth", level)) .. " max HP + " .. pct(AbilityStats.Value(ability, effect, "MinionLife", level)) .. " of its life")
		elseif kind == "Revive" then
			add("Revives at", pct(AbilityStats.Value(ability, effect, "HealthFraction", level)) .. " HP")
		end
	end

	if ability.UsesPerCombat then
		add("Uses", tostring(ability.UsesPerCombat) .. " per fight")
	elseif ability.Cooldown then
		add("Cooldown", seconds(AbilityStats.Cooldown(ability, level)))
	end
	return rows
end

return AbilityStats
