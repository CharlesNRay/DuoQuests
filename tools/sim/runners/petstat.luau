-- Marginal value of each pet stat: same party with +<pet-sized amount> of ONE stat; compares win rate and fight length.
local m = { ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Gear = require("./Gear"), PetConfig = require("./Config/Pets"), Skills = require("./Skills"), Economy = require("./Economy") }
local STATS = { "MaxHealth", "Attack", "Defense", "AttackSpeed", "CritChance", "CritMultiplier", "Haste" }
local CLASSES = { "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }
local LEVEL, SEEDS = 40, 30
local function amount(stat)
	local u = m.PetConfig.StatUnits[stat]
	local share = 1.25 * 1 -- one-stat Common pet at level 20, rank 1
	return (u.Base + u.PerLevel * 19) * share, u.Mode
end
local function party(classId, mod)
	local p = m.ProfileTemplate.New()
	p.Season.ClassId = classId; p.Season.Level = LEVEL; p.Season.HighestStage = LEVEL
	-- a middling gear set
	for i = 1, 24 do local d = m.Gear.RollDrop(LEVEL, true, 0, function() return 0.05 end) if d then m.Gear.Grant(p, LEVEL, d) end end
	m.Gear.EquipBest(p)
	if mod then p.Permanent.GuildBuffs = { Mods = { mod } } end
	return { { Id = "1", Name = "A", Profile = p } }
end
local function measure(classId, mod, stage)
	local wins, secs = 0, 0
	for seed = 1, SEEDS do
		local out = m.StageRunner.Run(party(classId, mod), stage, seed)
		if out.Won then wins += 1 end
		secs += math.min(out.Duration or 120, 120)
	end
	return wins / SEEDS, secs / SEEDS
end
for _, classId in ipairs(CLASSES) do
	-- pick a normal (non-boss) stage where the unbuffed party wins about 60% of the time
	local stage, bestGap = 5, 9
	for s = 5, 220 do
		if s % 10 ~= 0 and s % 4 == 1 then
			local w = measure(classId, nil, s)
			if math.abs(w - 0.6) < bestGap then stage, bestGap = s, math.abs(w - 0.6) end
			if w <= 0.1 then break end
		end
	end
	local bw, bs = measure(classId, nil, stage)
	local line = { ("%s stage %d base win %.2f time %.0f"):format(classId, stage, bw, bs) }
	for _, stat in ipairs(STATS) do
		local v, mode = amount(stat)
		local w, s = measure(classId, { Stat = stat, Mode = mode, Value = v }, stage)
		table.insert(line, ("%s %+.2f/%+.0fs"):format(stat, w - bw, s - bs))
	end
	print("PET " .. table.concat(line, " | "))
end
