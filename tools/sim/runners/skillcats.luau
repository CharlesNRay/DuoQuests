-- Skill audit: what every skill does, sorted into a role category, with its secondary purposes.
-- Categories: Heal, Shield, Summon, AoE (damage to all enemies), Single (damage to one), Buff (allies/self), Debuff (enemies, control).
-- A skill whose only purposes are its category (and combo layers) is flagged PURE: same-category skills of a class should differ.
-- Shared by skillaudit.luau and skillprobe.luau
local Skills = require("./Skills")
local Abilities = require("./Config/Abilities")
local Statuses = require("./Config/Statuses")
local Minions = require("./Config/Minions")

local function statusPurpose(id, target)
	local s = Statuses[id] or {}
	if s.Combo then
		return "Combo" -- builds the class combo
	end
	local enemy = target == "Primary" or target == "AllEnemies" or target == "Random" or target == "Enemy"
	if s.Dot then
		return if enemy then "DoT" else nil
	end
	if s.Hot or (s.Heal) then
		return "Heal"
	end
	if s.Flags and s.Flags.Absorb then
		return "Shield"
	end
	if s.Flags and (s.Flags.Stunned or s.Flags.Frozen) then
		return "Control"
	end
	if s.Flags and s.Flags.Taunting then
		return "Taunt"
	end
	if s.Flags and s.Flags.PreventLethal then
		return "Survive"
	end
	return if enemy then "Debuff" else "Buff"
end

local Cats = {}
function Cats.describe(id)
	local a = Abilities[id]
	local purposes, words = {}, {}
	local dmgPer, healPer = 0, 0
	local hasDamage = false
	for _, e in ipairs(a.Effects or {}) do
		if e.Type == "Damage" then
			hasDamage = true
		end
	end
	local function add(p, w)
		if p then
			purposes[p] = true
		end
		if w then
			table.insert(words, w)
		end
	end
	for _, e in ipairs(a.Effects or {}) do
		local t = e.Target or "?"
		if e.Type == "Damage" then
			add(if t == "AllEnemies" then "AoE" else "Single", ("dmg %s x%s"):format(t, tostring(e.Multiplier or "?")))
			dmgPer += (e.Multiplier or 0)
			if e.Consume then
				add("Finisher")
			end
			if e.Execute then
				add("Execute")
			end
		elseif e.Type == "Heal" then
			if t == "Self" then
				add("Drain", "self-heal")
			else
				add("Heal", ("heal %s x%s"):format(t, tostring(e.Multiplier or e.Percent or "?")))
				healPer += (e.Multiplier or 0) * (if t == "AllAllies" then 4 else 1)
			end
		elseif e.Type == "Shield" then
			add("Shield", ("shield %s"):format(t))
		elseif e.Type == "ApplyStatus" then
			local p = statusPurpose(e.Status, t)
			add(p, ("%s->%s"):format(e.Status, t))
		elseif e.Type == "Summon" or e.Type == "Raise" then
			add("Summon", e.Type .. " " .. tostring(e.MinionId or e.EnemyId or ""))
			local minion = Minions[e.MinionId or ""]
			if minion and minion.Taunt then
				add("Taunt") -- a minion that holds aggro: the summon tanks
			end
			if minion and minion.Leech then
				add("Drain")
			end
			if minion and minion.Abilities then
				add("Heal")
			end
		elseif e.Type == "Cleanse" then
			add("Cleanse", "cleanse " .. t)
		elseif e.Type == "Revive" then
			add("Revive", "revive")
		else
			add(nil, e.Type)
		end
	end
	if a.Passive or a.OnHit then
		add("Passive")
	end
	local order = { "Heal", "Revive", "Shield", "Summon", "AoE", "Single", "Taunt", "Buff", "Survive", "Control", "Debuff", "DoT", "Cleanse", "Drain", "Combo", "Finisher", "Execute" }
	local cat
	for _, k in ipairs(order) do
		if purposes[k] then
			cat = k
			break
		end
	end
	if cat == "Taunt" or cat == "Survive" then
		cat = "Buff"
	end
	if cat == "Control" or cat == "DoT" or cat == "Cleanse" then
		cat = "Debuff"
	end
	local others = {}
	for _, k in ipairs(order) do
		if purposes[k] and k ~= cat then
			table.insert(others, k)
		end
	end
	local cd = a.Cooldown or 1
	local rate = if cat == "Heal" then ("heal/s %.2f"):format(healPer / cd) elseif cat == "AoE" or cat == "Single" then ("dmg/s %.2f"):format(dmgPer / cd) else ""
	return cat or "?", others, rate .. "  " .. table.concat(words, ", "), a
end


return Cats
