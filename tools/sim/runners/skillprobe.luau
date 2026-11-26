-- Skill probe: how much each skill does. For every class path, a gearless level-LV hero (all skills rank RANK) fights with
-- three companions; the path's default loadout is the baseline and every other skill takes slot 4 in turn.
-- Per skill: party wins out of N at a stage the baseline wins about half the time, and the skill's own output per fight
-- (damage + healing + shield soak from its tagged events, damage of the minions it raised, and what its statuses added/kept off).
-- Run: py -3 tools/sim/sync.py; cp tools/sim/runners/skillprobe.luau .build/hl6/; cd .build/hl6; luau skillprobe.luau
local P = require("./ProfileTemplate")
local SR = require("./StageRunner")
local Skills = require("./Skills")
local Subclasses = require("./Subclasses")
local Abilities = require("./Config/Abilities")
local Classes = require("./Config/Classes")
local Stages = require("./Stages")

local LV, RANK, N = 60, 10, 12
local COMPANIONS = { Warrior = { "Cleric", "Mage", "Ranger" }, Cleric = { "Warrior", "Mage", "Ranger" }, Mage = { "Warrior", "Cleric", "Ranger" },
	Ranger = { "Warrior", "Cleric", "Mage" }, Rogue = { "Warrior", "Cleric", "Mage" }, Summoner = { "Warrior", "Cleric", "Mage" } }

local function hero(c, path, loadout)
	local p = P.New()
	p.Permanent.UnlockedClasses[c] = true
	p.Season.ClassId = c
	P.GrantClassStarters(p.Season, c)
	p.Season.Level = LV
	p.Season.HighestStage = 100
	if path then
		p.Season.Subclasses = { [c] = path }
	end
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

-- which statuses each skill applies (to credit status value to the skill)
local statusOf = {}
for id, a in pairs(Abilities) do
	for _, e in ipairs(a.Effects or {}) do
		if e.Type == "ApplyStatus" and e.Status then
			statusOf[e.Status] = statusOf[e.Status] or id
		end
	end
end

local function run(c, path, loadout, stage, seeds)
	local wins, own, score = 0, {}, 0
	for seed = 1, seeds do
		local team = { { Id = "1", Name = c, Profile = hero(c, path, loadout) } }
		for i, other in ipairs(COMPANIONS[c]) do
			table.insert(team, { Id = tostring(i + 1), Name = other, Profile = hero(other, nil, nil) })
		end
		local o = SR.Run(team, stage, seed, SR.UltimateFor(team, 100, nil), true, { Metrics = true })
		if o.Won then
			wins += 1
			score += 1 + 0.5 * (1 - o.Duration / Stages.TimeLimit(stage))
		else
			local hp, max = 0, 0
			for _, en in ipairs(o.Sim.Enemies) do
				hp += math.max(0, en.Health)
				max += en.Stats.MaxHealth
			end
			score += 1 - hp / math.max(max, 1)
		end
		local lastCast, minionOf = nil, {}
		for _, e in ipairs(o.Events) do
			if e.Type == "Cast" and e.Source == "1" then
				lastCast = e.Ability
			elseif e.Type == "Spawn" and e.Source == "1" and e.Entity then
				minionOf[e.Entity.Id] = lastCast
			elseif (e.Type == "Damage" or e.Type == "Heal") and not e.Sacrifice then
				local tag = if e.Source == "1" then e.Tag else minionOf[e.Source or ""]
				if tag and Abilities[tag] then
					own[tag] = (own[tag] or 0) + (e.Amount or 0)
				end
			end
		end
		for statusId, row in pairs(o.Metrics and o.Metrics.Statuses or {}) do
			local skill = statusOf[statusId]
			if skill then
				own[skill] = (own[skill] or 0) + (row.Extra or 0) + (row.Mitigated or 0)
			end
		end
	end
	return wins, own, score / seeds
end

local function runAt(c, path, loadout, stages)
	local wins, own, score = 0, {}, 0
	for _, st in ipairs(stages) do
		local w, o, sc = run(c, path, loadout, st, N)
		wins += w
		score += sc / #stages
		for k, v in pairs(o) do
			own[k] = (own[k] or 0) + v
		end
	end
	return wins, own, score
end

local function findStage(c, path, loadout)
	local lo, hi = 5, 160
	while hi - lo > 2 do
		local mid = (lo + hi) // 2
		local w = run(c, path, loadout, mid, 10)
		if w >= 5 then
			lo = mid
		else
			hi = mid
		end
	end
	return lo
end

for _, c in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
	for _, pdef in ipairs(Subclasses.Choices(c, nil)) do
		local path = pdef.Id
		local base = table.clone(Classes[c].DefaultLoadout)
		local stage = findStage(c, path, base) + 1
		local stages = { stage - 1, stage, stage + 2, stage + 5 }
		local bw, bown, bscore = runAt(c, path, base, stages)
		-- worth of a skill = how much the party score drops without it (a 3-skill loadout), as % of the 3-skill score
		local rows = {}
		local three = { base[1], base[2], base[3] }
		local _, _, s3 = runAt(c, path, three, stages)
		for i, id in ipairs(base) do
			local without = table.clone(base)
			table.remove(without, i)
			local _, _, sw = runAt(c, path, without, stages)
			table.insert(rows, { id, bw, bown[id] or 0, "base", (bscore - sw) / math.max(sw, 0.01) })
		end
		for _, id in ipairs(Skills.Pool(c, path)) do
			if not table.find(base, id) then
				local l = table.clone(three)
				l[4] = id
				local w, own, sc = runAt(c, path, l, stages)
				table.insert(rows, { id, w, own[id] or 0, "slot4", (sc - s3) / math.max(s3, 0.01) })
			end
		end
		local top = 0
		for _, r in ipairs(rows) do
			top = math.max(top, r[3])
		end
		print(("== %s / %s  stages %d-%d  baseline wins %d/%d score %.2f (slot 4 = %s)"):format(c, path, stage - 1, stage + 5, bw, N * 4, bscore, base[4]))
		table.sort(rows, function(a, b)
			return a[5] > b[5]
		end)
		for _, r in ipairs(rows) do
			print(("  %-17s %-5s wins %2d/%d  worth %+5.0f%%  own %4.0f%% of best"):format(r[1], r[4], r[2], N * 4, 100 * r[5], 100 * r[3] / math.max(top, 1)))
		end
	end
end
