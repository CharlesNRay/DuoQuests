local m = {
	ProfileTemplate = require("./ProfileTemplate"), StageRunner = require("./StageRunner"), Skills = require("./Skills"),
	Economy = require("./Economy"), Classes = require("./Config/Classes"), BalanceTool = require("./BalanceTool"),
	Pets = require("./Pets"), Gear = require("./Gear"),
}
local function target(h) return 30 * (h / 2) ^ 0.435 end
local hours = { 0.25, 1, 2, 6, 14 }
local function show(label, opts)
	opts.Hours = hours
	local snaps = m.BalanceTool.Run(m, opts)
	print(label)
	for _, s in ipairs(snaps) do
		print(("  %5.2fh frontier %3d [target %3.0f] lvl %2d slots %4.1f skills %d/8"):format(s.Hours, s.Frontier, target(s.Hours), s.Level, s.SlotAverage, s.Owned))
	end
end
math.randomseed(42)
show("2P baseline (no pets/gear)", {})
math.randomseed(42)
show("2P + pets + gear", { Pets = true, Gear = true })
math.randomseed(42)
show("Solo baseline", { Solo = true })
math.randomseed(42)
show("Solo + pets + gear", { Solo = true, Pets = true, Gear = true })
