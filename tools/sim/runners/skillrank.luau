-- Skill ranking by category: each skill alone in the loadout (so every hit, heal, shield, status and minion is its own),
-- a gearless level-LV hero (skills rank RANK) with three companions. Output per second of fight:
--   Single: damage on a boss stage (one target)   AoE: damage on a pack stage   Heal: healing   Shield: damage soaked
--   Buff / Debuff: damage its statuses added or kept off   Summon: its minions' damage
-- Within a class and category the best skill may be single-purpose; every other one should have a second purpose
-- (skillcats flags PURE). Run: cp tools/sim/runners/skill*.luau .build/hl6/; cd .build/hl6; luau skillrank.luau
local P = require("./ProfileTemplate")
local SR = require("./StageRunner")
local Skills = require("./Skills")
local Abilities = require("./Config/Abilities")
local Statuses = require("./Config/Statuses")
local Cats = require("./skillcats")
local Stages = require("./Stages")

local LV, RANK, N, HEALTH = 60, 10, 8, 2.5
local BOSS_STAGE, PACK_STAGE = 10, 12
local COMPANIONS = { Warrior = { "Cleric", "Mage", "Ranger" }, Cleric = { "Warrior", "Mage", "Ranger" }, Mage = { "Warrior", "Cleric", "Ranger" },
	Ranger = { "Warrior", "Cleric", "Mage" }, Rogue = { "Warrior", "Cleric", "Mage" }, Summoner = { "Warrior", "Cleric", "Mage" } }

local function hero(c, loadout)
	local p = P.New()
	p.Permanent.UnlockedClasses[c] = true
	p.Season.ClassId = c
	P.GrantClassStarters(p.Season, c)
	p.Season.Level = LV
	p.Season.HighestStage = 100
	p.Season.SkillState = {}
	for _, id in ipairs(Skills.AllSkills(c)) do
		p.Season.OwnedAbilities[id] = true
		p.Season.SkillState[id] = { Tier = "Common", Rank = RANK, XP = 0 }
	end
	if loadout then
		p.Season.Loadouts[c] = loadout
	end
	return p
end

local function statusesOf(id)
	local out = {}
	for _, e in ipairs(Abilities[id].Effects or {}) do
		if e.Type == "ApplyStatus" and e.Status then
			out[e.Status] = true
		end
	end
	return out
end

local function measure(c, id, stage)
	local mine = statusesOf(id)
	local dmg, heal, absorb, fx, secs, casts = 0, 0, 0, 0, 0, 0
	for seed = 1, N do
		local team = { { Id = "1", Name = c, Profile = hero(c, { id }) } }
		for i, other in ipairs(COMPANIONS[c]) do
			table.insert(team, { Id = tostring(i + 1), Name = other, Profile = hero(other, nil) })
		end
		local enemies = Stages.NewEnemies(stage)
		for _, en in ipairs(enemies) do -- tougher enemies: fights long enough for every cooldown to come round
			en.Stats.DamageTaken = (en.Stats.DamageTaken or 1) / HEALTH -- takes less damage instead of more health, so % health effects stay true
		end
		local o = SR.Run(team, stage, seed, nil, true, { Metrics = true, Enemies = enemies, MaxSeconds = 120 })
		secs += o.Duration
		local minions = {}
		for _, e in ipairs(o.Events) do
			if e.Type == "Cast" and e.Source == "1" and e.Ability == id then
				casts += 1
			elseif e.Type == "Spawn" and e.Source == "1" and e.Entity then
				minions[e.Entity.Id] = true
			elseif e.Type == "Damage" and not e.Sacrifice then
				if (e.Source == "1" and (e.Tag == id or mine[e.Tag or ""])) or minions[e.Source or ""] then
					dmg += e.Amount or 0
				end
			elseif e.Type == "Heal" and e.Source == "1" and e.Tag ~= "Lifesteal" then
				heal += e.Amount or 0
			end
		end
		local row = o.Metrics.Entities["1"] or {}
		absorb += row.Absorbed or 0
		for statusId, r in pairs(o.Metrics.Statuses or {}) do
			if mine[statusId] and not (Statuses[statusId] or {}).Dot then
				fx += (r.Extra or 0) + (r.Mitigated or 0)
			end
		end
	end
	secs = math.max(secs, 1)
	return { Dmg = dmg / secs, Heal = heal / secs, Absorb = absorb / secs, Fx = fx / secs, Casts = casts / N, Secs = secs / N }
end

for _, c in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
	local byCat = {}
	for _, id in ipairs(Skills.AllSkills(c)) do
		local cat, others = Cats.describe(id)
		local m = measure(c, id, if cat == "Single" then BOSS_STAGE else PACK_STAGE)
		local value = if cat == "Single" or cat == "AoE" or cat == "Summon" then m.Dmg
			elseif cat == "Heal" then m.Heal + m.Absorb
			elseif cat == "Shield" then m.Absorb
			else m.Fx
		byCat[cat] = byCat[cat] or {}
		table.insert(byCat[cat], { Id = id, Value = value, M = m, Others = others, Rarity = Abilities[id].Rarity, Cd = Abilities[id].Cooldown })
	end
	print("== " .. c)
	for _, cat in ipairs({ "Single", "AoE", "Heal", "Revive", "Shield", "Summon", "Buff", "Debuff", "?" }) do
		local list = byCat[cat]
		if list then
			table.sort(list, function(a, b)
				return a.Value > b.Value
			end)
			local top = math.max(list[1].Value, 1)
			for i, r in ipairs(list) do
				local flag = if #r.Others == 0 and i > 1 then "NEEDS PURPOSE" elseif #r.Others == 0 then "pure (top)" else "+" .. table.concat(r.Others, "+")
				print(("  %-7s %-18s %-9s cd%-3s %4.0f%% of best  casts %4.1f %3.0fs  dmg/s %7.0f heal/s %6.0f soak/s %6.0f fx/s %6.0f  %s"):format(
					cat, r.Id, r.Rarity or "", tostring(r.Cd), 100 * r.Value / top, r.M.Casts, r.M.Secs, r.M.Dmg, r.M.Heal, r.M.Absorb, r.M.Fx, flag))
			end
		end
	end
end
