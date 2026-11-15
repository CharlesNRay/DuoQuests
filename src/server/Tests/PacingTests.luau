--[[
	PacingTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PacingTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PacingTests)()

	or, to also check the end of a 6-week season (takes longer):

	  require(game.ServerScriptService.Server.Tests.PacingTests)(nil, { Full = true })

	Plays a simulated auto-player through the real game code and checks the
	progression against the design targets below. If you change Config/Economy or
	Config/Stages and a check fails, either retune or change the targets on purpose.

	DESIGN ASSUMPTIONS (change them here and in docs/PROGRESSION.md together)
	  * An active player is online about 2 hours a day, 14 hours in week one.
	  * A season lasts about 6 weeks, about 84 online hours.
	  * Target frontier by online time:  stage(t) = 30 * (t / 2h) ^ 0.435
	    (the inverse of T(s) = 2h * (s / 30) ^ 2.3: each new stage takes
	    longer than the one before). That is about stage 12 at 15 min, 30 at
	    2 h, 70 at 14 h and 152 at 84 h.
	  * After week one: every class skill owned, slots about 20-60% of max.
	  * A fully built party still has headroom: it cannot run out of stages
	    before the target season end.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Tests = script.Parent
	return {
		ProfileTemplate = require(Shared.ProfileTemplate),
		StageRunner = require(Shared.StageRunner),
		Skills = require(Shared.Skills),
		Economy = require(Shared.Economy),
		Classes = require(Shared.Config.Classes),
		BalanceTool = require(Tests.BalanceTool),
	}
end

local function target(hours)
	return 30 * (hours / 2) ^ 0.435
end

return function(modulesOverride, options)
	local m = loadModules(modulesOverride)
	options = options or {}
	local warnFn = warn or print

	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	print("Running PacingTests...")

	local hours = { 0.25, 2, 14 }
	if options.Full then
		table.insert(hours, 84)
	end
	local snaps = m.BalanceTool.Run(m, { Hours = hours })

	print("Auto-player pacing (target frontier in brackets):")
	for _, s in ipairs(snaps) do
		print(("  %5.2f h | frontier %3d [%3.0f] | level %2d | slot avg %4.1f | warrior skills %d/8 | %d fights"):format(s.Hours, s.Frontier, target(s.Hours), s.Level, s.SlotAverage, s.Owned, s.Fights))
	end

	local function within(snapshot, low, high)
		local t = target(snapshot.Hours)
		return snapshot.Frontier >= t * low and snapshot.Frontier <= t * high
	end

	check("15 minutes in: first boss region reached (frontier 8-15)", snaps[1].Frontier >= 8 and snaps[1].Frontier <= 15)
	check("2 hours in: frontier within 30% of target", within(snaps[2], 0.7, 1.3))
	check("14 hours in: frontier within 30% of target", within(snaps[3], 0.7, 1.4))
	check("2 hours in: not every skill is owned yet", snaps[2].Owned < 8)
	check("Week one: every Warrior skill owned", snaps[3].Owned == 8)
	check("Week one: slots at 20-60% of the cap", snaps[3].SlotAverage >= 0.2 * m.Skills.MAX_SLOT_LEVEL and snaps[3].SlotAverage <= 0.6 * m.Skills.MAX_SLOT_LEVEL)
	check("Progress slows over time (later hours add fewer stages per hour)", (snaps[3].Frontier - snaps[2].Frontier) / (snaps[3].Hours - snaps[2].Hours) < (snaps[2].Frontier - snaps[1].Frontier) / (snaps[2].Hours - snaps[1].Hours))
	if options.Full then
		local season = snaps[4]
		check("Season end: frontier within 30% of target", within(season, 0.8, 1.3))
		check("Season end: a maxed party has stage headroom (frontier at or above target)", season.Frontier >= target(season.Hours))
	end

	print(("PacingTests done: %d passed, %d failed"):format(passed, failed))
end
