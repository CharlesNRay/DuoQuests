local m = {
	ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Skills = require("./Skills"),
	Economy = require("./Economy"), Classes = require("./Config/Classes"), BalanceTool = require("./BalanceTool"),
	Pets = require("./Pets"), Gear = require("./Gear"), Subclasses = require("./Subclasses"),
}
local function go(label, opts)
	math.randomseed(42)
	opts.Hours = { 0.25, 1, 2, 14 }
	local snaps = m.BalanceTool.Run(m, opts)
	print(label)
	for _, s in ipairs(snaps) do
		print(("  %5.2fh frontier %3d lvl %2d slots %4.1f skills %d/8"):format(s.Hours, s.Frontier, s.Level, s.SlotAverage, s.Owned))
	end
	local parts = {}
	for _, goal in ipairs({ 10, 20, 30, 40 }) do
		local r = snaps.LevelMinutes[goal]
		table.insert(parts, ("L%d:%s"):format(goal, r and ("%.0fm/s%d"):format(r.Minutes, r.Frontier) or "-"))
	end
	print("  ", table.concat(parts, " "))
	local bl = {}
	for stage = 10, 100, 10 do
		local b = snaps.BossLog[stage]
		if b then table.insert(bl, ("%d:%.0fm/%dL"):format(stage, b.Minutes, b.Losses)) end
	end
	print("   bosses", table.concat(bl, " "))
end
go("2P plain", {})
go("2P full", { Pets = true, Gear = true, Subclass = true })
