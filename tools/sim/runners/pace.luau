local m = {
	ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Skills = require("./Skills"),
	Economy = require("./Economy"), Classes = require("./Config/Classes"), BalanceTool = require("./BalanceTool"),
	Pets = require("./Pets"), Gear = require("./Gear"), Subclasses = require("./Subclasses"),
}
local HOURS = tonumber("1.5")
local function run(label, opts)
	math.randomseed(42)
	opts.Hours = { HOURS }
	local snaps = m.BalanceTool.Run(m, opts)
	local parts = {}
	for _, goal in ipairs({ 5, 10, 15, 20, 25, 30, 40, 50 }) do
		local r = snaps.LevelMinutes[goal]
		table.insert(parts, ("L%d:%s"):format(goal, r and ("%.0fm/s%d"):format(r.Minutes, r.Frontier) or "-"))
	end
	print(label, table.concat(parts, " "))
	local bl = {}
	for stage = 10, 100, 10 do
		local b = snaps.BossLog[stage]
		if b then table.insert(bl, ("%d:%.0fm/%dL"):format(stage, b.Minutes, b.Losses)) end
	end
	print("   bosses", table.concat(bl, " "))
	local s = snaps[1]
	print(("   end %.1fh frontier %d lvl %d"):format(s.Hours, s.Frontier, s.Level))
end
run("2P pets+gear+sub", { Pets = true, Gear = true, Subclass = true })
run("solo pets+gear+sub", { Solo = true, Pets = true, Gear = true, Subclass = true })
