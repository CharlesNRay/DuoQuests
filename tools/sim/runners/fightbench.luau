-- Fight bench: CPU time of one server fight simulation (StageRunner.Run) for a four-hero party, per stage band, plus
-- the event count a client receives. A full server runs up to 16 parties, each one fight every few seconds.
-- Run: bash tools/sim/fightbench.sh
local P = require("./ProfileTemplate"); local SR = require("./StageRunner")
local function hero(c, lv, stage)
	local p = P.New(); p.Permanent.UnlockedClasses[c] = true; p.Season.ClassId = c; P.GrantClassStarters(p.Season, c); p.Season.Level = lv; p.Season.HighestStage = stage
	return p
end
for _, band in ipairs({ { 10, 8 }, { 40, 30 }, { 100, 60 }, { 150, 100 } }) do
	local stage, lv = band[1], band[2]
	local classes = { "Warrior", "Cleric", "Mage", "Summoner" }
	local n, total, worst, events, dur = 10, 0, 0, 0, 0
	for seed = 1, n do
		local team = {}
		for i, c in ipairs(classes) do team[i] = { Id = tostring(i), Name = c, Profile = hero(c, lv, stage) } end
		local t = os.clock()
		local o = SR.Run(team, stage, seed, SR.UltimateFor(team, stage, nil), true)
		local dt = os.clock() - t
		total += dt; worst = math.max(worst, dt); events += #o.Events; dur += (o.Duration or 0)
	end
	print(("FIGHTBENCH stage %d L%d: sim avg %.1f ms, worst %.1f ms, %d events, fight %.1f s"):format(stage, lv, total / n * 1000, worst * 1000, events // n, dur / n))
end
