--[[
	TutorialTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > TutorialTests

	  require(game.ServerScriptService.Server.Tests.TutorialTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Tutorial = require(Shared.Tutorial), ProfileTemplate = require(Shared.ProfileTemplate), Consumables = require(Shared.Consumables) }
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
	local bossDef = Tutorial.Steps[Tutorial.BossStep]
	check("BossStep is the first-boss step", bossDef ~= nil and bossDef.Kind == "frontier" and bossDef.Goal == Tutorial.BossStage + 1)
	local wrap = {}
	for index = Tutorial.BossStep + 1, #Tutorial.Steps do
		wrap[Tutorial.Steps[index].Id] = Tutorial.Steps[index]
	end
	check("After the boss: make your wishes (with a way to the Wishing Tree), then watch a battle",
		wrap.Wish ~= nil and wrap.Wish.Goal == "Wish" and wrap.Wish.Go == "Tree" and wrap.Watch ~= nil and wrap.Watch.Goal == "Watch" and Tutorial.Steps[#Tutorial.Steps].Id == "Watch")

	check("Advancing needs the right current step", select(2, Tutorial.Advance(p, 3)) == "WrongStep" and Tutorial.Of(p).Step == 1)
	check("Advancing moves one step forward", Tutorial.Advance(p, 1) == true and Tutorial.Of(p).Step == 2)
	check("Advancing the same step twice is refused", select(2, Tutorial.Advance(p, 1)) == "WrongStep")
	for step = 2, Tutorial.BossStep - 1 do
		Tutorial.Advance(p, step)
	end
	check("The reward is refused before the boss is beaten", select(2, Tutorial.Finish(p)) == "BossNotBeaten" and not Tutorial.Of(p).Done)
	p.Season.HighestStage = Tutorial.BossStage + 1
	local Consumables = m.Consumables
	local petBefore, skillBefore = Consumables.Count(p, "PetWish"), Consumables.Count(p, "SkillWish")
	local ok, reward = Tutorial.Finish(p)
	check("Beating the first boss pays but does not end the tutorial", ok == true and Tutorial.Of(p).Rewarded and not Tutorial.Of(p).Done and reward.PetWish == 10 and reward.SkillWish == 10)
	check("10 pet wishes and 10 skill wishes land in the stash", Consumables.Count(p, "PetWish") == petBefore + 10 and Consumables.Count(p, "SkillWish") == skillBefore + 10)
	check("It pays only once", select(2, Tutorial.Finish(p)) == "AlreadyRewarded" and Consumables.Count(p, "PetWish") == petBefore + 10)
	check("Completing is refused before the last step", select(2, Tutorial.Complete(p, Tutorial.BossStep)) == "WrongStep" and not Tutorial.Of(p).Done)
	for step = Tutorial.BossStep, #Tutorial.Steps - 1 do
		Tutorial.Advance(p, step)
	end
	check("It stops at the last step", Tutorial.Of(p).Step == #Tutorial.Steps and select(2, Tutorial.Advance(p, #Tutorial.Steps)) == "LastStep")
	check("Completing the last step ends it", Tutorial.Complete(p, #Tutorial.Steps) == true and Tutorial.Of(p).Done)
	check("A finished tutorial cannot advance", select(2, Tutorial.Advance(p, 1)) == "Done")

	local r = ProfileTemplate.New()
	for step = 1, #Tutorial.Steps - 1 do
		Tutorial.Advance(r, step)
	end
	check("The last step cannot end it before the boss reward is paid", select(2, Tutorial.Complete(r, #Tutorial.Steps)) == "NotRewarded" and not Tutorial.Of(r).Done)
	r.Season.HighestStage = Tutorial.BossStage + 1
	check("Paid while already on the last step: that also ends it", Tutorial.Finish(r) == true and Tutorial.Of(r).Done)

	local q = ProfileTemplate.New()
	Tutorial.Skip(q)
	q.Season.HighestStage = 5
	check("Skipping ends it with no reward yet", Tutorial.Of(q).Done and not Tutorial.Of(q).Rewarded)
	check("Nothing is paid before the first boss falls", Tutorial.PayIfSkipped(q) == nil)
	q.Season.HighestStage = Tutorial.BossStage + 1
	local paid = Tutorial.PayIfSkipped(q)
	check("A skipped tutorial pays the full reward when the first boss falls", paid ~= nil and paid.PetWish == 10 and paid.SkillWish == 10 and Consumables.Count(q, "PetWish") == 10 and Consumables.Count(q, "SkillWish") == 10)
	check("It pays only once", Tutorial.PayIfSkipped(q) == nil and Consumables.Count(q, "PetWish") == 10)
	local fresh = ProfileTemplate.New()
	fresh.Season.HighestStage = Tutorial.BossStage + 1
	check("A player still in the tutorial is not paid here (the tutorial pays them)", Tutorial.PayIfSkipped(fresh) == nil)

	print(("TutorialTests done: %d passed, %d failed"):format(passed, failed))
end
