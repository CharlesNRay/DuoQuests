--[[
	Tutorial (ModuleScript): the guided first session, from the first fight to the first boss.

	The steps are data; the client shows them (client/UI/Tutorial) and the server only keeps the player's place and pays
	the finishing reward once.

	  Tutorial.Steps                       ordered list: { Id, Title, Text, Target, Kind, Goal? }
	      Kind "next"      the player presses Next
	      Kind "open"      completes when the player opens the panel named in Goal
	      Kind "frontier"  completes when the highest stage reached is at least Goal
	  Tutorial.Of(profile)                 -> { Step, Done, Rewarded } (created on first use)
	  Tutorial.Advance(profile, step)      moves from `step` to the next one (only forwards, one at a time)
	  Tutorial.Skip(profile)               ends the tutorial without the reward
	  Tutorial.Finish(profile)             -> ok, reward   pays once, after the first boss is beaten
]]
local Tutorial = {}

Tutorial.BossStage = 10
Tutorial.Reward = { Wishstones = 6, SkillPicks = 1 }

Tutorial.Steps = {
	{ Id = "Welcome", Title = "Welcome to Duo Quest", Text = "You and your partner fight on your own. Your party sits in the top left. Everything you do from here makes the pair stronger.", Target = "Party", Kind = "next" },
	{ Id = "Fight", Title = "The battle runs itself", Text = "Fights play out automatically and every win moves you on a stage. Watch your stage in the top right climb.", Target = "Stage", Kind = "frontier", Goal = 3 },
	{ Id = "Skills", Title = "Choose your skills", Text = "Open Skills. The four equipped skills fire in order, left to right. Upgrade them whenever a skill is ready.", Target = "Skills", Kind = "open", Goal = "Skills" },
	{ Id = "Hero", Title = "Gear and stats", Text = "Open Hero to see your stats and equipment. Better gear from the Blacksmith and drops makes every fight faster.", Target = "Hero", Kind = "open", Goal = "Hero" },
	{ Id = "Pets", Title = "Your pet fights too", Text = "Open Pets. The pet you equip strikes on its own and adds bonus stats. You can wish for more at the Wishing Tree.", Target = "Pets", Kind = "open", Goal = "Pets" },
	{ Id = "Boss", Title = "Beat the Stage 10 boss", Text = "The first boss waits at stage 10. Keep fighting, level up and upgrade your skills until it falls.", Target = "Stage", Kind = "frontier", Goal = 11 },
}

local function stateOf(profile)
	local permanent = profile.Permanent
	if type(permanent.Tutorial) ~= "table" then
		permanent.Tutorial = { Step = 1, Done = false, Rewarded = false }
	end
	return permanent.Tutorial
end

function Tutorial.Of(profile)
	local t = stateOf(profile)
	return { Step = t.Step, Done = t.Done == true, Rewarded = t.Rewarded == true }
end

function Tutorial.Advance(profile, step)
	local t = stateOf(profile)
	if t.Done then
		return false, "Done"
	end
	if step ~= t.Step then
		return false, "WrongStep"
	end
	if t.Step >= #Tutorial.Steps then
		return false, "LastStep"
	end
	t.Step += 1
	return true, t.Step
end

function Tutorial.Skip(profile)
	local t = stateOf(profile)
	t.Done = true
	return true
end

function Tutorial.Finish(profile)
	local t = stateOf(profile)
	if t.Rewarded then
		t.Done = true
		return false, "AlreadyRewarded"
	end
	if profile.Season.HighestStage <= Tutorial.BossStage then
		return false, "BossNotBeaten"
	end
	t.Done, t.Rewarded = true, true
	local currencies = profile.Season.Currencies
	currencies.Wishstones = (currencies.Wishstones or 0) + Tutorial.Reward.Wishstones
	currencies.SkillPicks = (currencies.SkillPicks or 0) + Tutorial.Reward.SkillPicks
	return true, Tutorial.Reward
end

return Tutorial
