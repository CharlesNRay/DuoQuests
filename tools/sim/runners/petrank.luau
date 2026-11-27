-- Pet ranking: every pet (level LV, rank 1) on the same gearless level-LV hero with three companions; party score over a
-- few stages around where the hero starts losing (like skillprobe: win = 1 + speed bonus, loss = share of enemy health
-- taken), the pet's own skill damage, and its worth = score with the pet vs with no pet. Rarer pets should be worth more.
-- Run: py -3 tools/sim/sync.py; cp tools/sim/runners/petrank.luau .build/hl6/; cd .build/hl6; luau petrank.luau [Class]
local P = require("./ProfileTemplate")
local SR = require("./StageRunner")
local Stages = require("./Stages")
local PetConfig = require("./Config/Pets")
local Pets = require("./Pets")

local CLASS = (... and select(1, ...)) or "Mage"
local COMPS = { Mage = { "Warrior", "Cleric", "Ranger" }, Warrior = { "Cleric", "Mage", "Ranger" } }
local LV, N = 60, 10
local RANK = 1 -- pet rank for every pet (1..Config/Pets MaxRank); edit to compare maxed pets
local COMP = COMPS[CLASS] or { "Warrior", "Cleric", "Ranger" }

local function hero(c, petId)
	local p = P.New()
	p.Permanent.UnlockedClasses[c] = true
	p.Season.ClassId = c
	P.GrantClassStarters(p.Season, c)
	p.Season.Level = LV
	p.Season.HighestStage = 100
	if petId then
		p.Permanent.Pets = { [petId] = true }
		p.Permanent.PetLevels = { [petId] = LV }
		if RANK > 1 then p.Permanent.PetRanks = { [petId] = RANK } end
		Pets.Equip(p, petId)
	else
		p.Permanent.Pets = {}
	end
	return p
end

local function score(petId, stage)
	local s, petDmg = 0, 0
	for seed = 1, N do
		local team = { { Id = "1", Name = CLASS, Profile = hero(CLASS, petId) } }
		for i, c in ipairs(COMP) do
			table.insert(team, { Id = tostring(i + 1), Name = c, Profile = hero(c, nil) })
		end
		local o = SR.Run(team, stage, seed, nil, false, { Metrics = true })
		if o.Won then
			s += 1 + 0.5 * (1 - o.Duration / Stages.TimeLimit(stage))
		else
			local hp, max = 0, 0
			for _, en in ipairs(o.Sim.Enemies) do
				hp += math.max(0, en.Health)
				max += en.Stats.MaxHealth
			end
			s += 1 - hp / math.max(max, 1)
		end
		local row = o.Metrics.Entities["1"] or {}
		petDmg += row.PetDealt or 0
	end
	return s / N, petDmg / N
end

-- the stage where a hero with no pet starts losing
local lo, hi = 5, 200
while hi - lo > 2 do
	local mid = (lo + hi) // 2
	if score(nil, mid) >= 0.9 then lo = mid else hi = mid end
end
local stages = { lo, lo + 2, lo + 5 }
local function at(petId)
	local s, d = 0, 0
	for _, st in ipairs(stages) do
		local a, b = score(petId, st)
		s += a / #stages
		d += b / #stages
	end
	return s, d
end
local base = at(nil)
print(("%s level %d, stages %d/%d/%d, no-pet score %.2f"):format(CLASS, LV, stages[1], stages[2], stages[3], base))
local rows = {}
for _, id in ipairs(PetConfig.Order) do
	local def = PetConfig.Defs[id]
	local s, d = at(id)
	table.insert(rows, { id, def.Rarity or "?", (s - base) / math.max(base, 0.01), d, def.Skill and def.Skill.Name or "" })
end
table.sort(rows, function(a, b) return a[3] > b[3] end)
for _, r in ipairs(rows) do
	print(("  %-12s %-9s worth %+5.0f%%  pet dmg/fight %8.0f  %s"):format(r[1], r[2], 100 * r[3], r[4], r[5]))
end
