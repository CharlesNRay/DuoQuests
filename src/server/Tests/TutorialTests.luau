--[[
	TutorialTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > TutorialTests

	  require(game.ServerScriptService.Server.Tests.TutorialTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Tutorial = require(Shared.Tutorial), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Tutorial, ProfileTemplate = m.Tutorial, m.ProfileTemplate
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

	local p = ProfileTemplate.New()
	local t = Tutorial.Of(p)
	check("A new player starts on step 1, not done", t.Step == 1 and not t.Done and not t.Rewarded)
	check("The steps are well formed", #Tutorial.Steps >= 5 and Tutorial.Steps[1].Kind == "next")
	local formed = true
	for _, step in ipairs(Tutorial.Steps) do
		formed = formed and type(step.Id) == "string" and type(step.Title) == "string" and type(step.Text) == "string" and (step.Kind == "next" or step.Goal ~= nil)
	end
	check("Every step has an id, a title, text and (when needed) a goal", formed)
	check("The last step is the first boss", Tutorial.Steps[#Tutorial.Steps].Goal == Tutorial.BossStage + 1)

	check("Advancing needs the right current step", select(2, Tutorial.Advance(p, 3)) == "WrongStep" and Tutorial.Of(p).Step == 1)
	check("Advancing moves one step forward", Tutorial.Advance(p, 1) == true and Tutorial.Of(p).Step == 2)
	check("Advancing the same step twice is refused", select(2, Tutorial.Advance(p, 1)) == "WrongStep")
	for step = 2, #Tutorial.Steps - 1 do
		Tutorial.Advance(p, step)
	end
	check("It stops at the last step", Tutorial.Of(p).Step == #Tutorial.Steps and select(2, Tutorial.Advance(p, #Tutorial.Steps)) == "LastStep")

	check("The reward is refused before the boss is beaten", select(2, Tutorial.Finish(p)) == "BossNotBeaten" and not Tutorial.Of(p).Done)
	p.Season.HighestStage = Tutorial.BossStage + 1
	local before = p.Season.Currencies.Wishstones or 0
	local picks = p.Season.Currencies.SkillPicks or 0
	local ok, reward = Tutorial.Finish(p)
	check("Beating the first boss finishes it and pays", ok == true and Tutorial.Of(p).Done and Tutorial.Of(p).Rewarded and reward.Wishstones == Tutorial.Reward.Wishstones)
	check("The reward lands in the wallet", (p.Season.Currencies.Wishstones or 0) == before + Tutorial.Reward.Wishstones and p.Season.Currencies.SkillPicks == picks + Tutorial.Reward.SkillPicks)
	check("It pays only once", select(2, Tutorial.Finish(p)) == "AlreadyRewarded" and (p.Season.Currencies.Wishstones or 0) == before + Tutorial.Reward.Wishstones)
	check("A finished tutorial cannot advance", select(2, Tutorial.Advance(p, 1)) == "Done")

	local q = ProfileTemplate.New()
	Tutorial.Skip(q)
	q.Season.HighestStage = 30
	check("Skipping ends it with no reward", Tutorial.Of(q).Done and not Tutorial.Of(q).Rewarded)

	print(("TutorialTests done: %d passed, %d failed"):format(passed, failed))
end
