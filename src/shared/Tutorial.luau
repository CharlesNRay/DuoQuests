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
local Consumables = require(script.Parent.Consumables)

local Tutorial = {}

Tutorial.BossStage = 10
Tutorial.Reward = { PetWish = 10, SkillWish = 10 } -- wish tickets (Consumables), paid once for beating the first boss

Tutorial.Steps = {
	{ Id = "Welcome", Title = "Welcome to Duo Quest!", Text = "You and a partner fight together, even while you are away.", Target = nil, Kind = "next" },
	{ Id = "Fight", Title = "Fights run by themselves", Text = "Just wait. Your team wins fights and climbs stages. Reach stage 3.", Target = "Stage", Kind = "frontier", Goal = 3 },
	{ Id = "SkillsOpen", Title = "Your skills", Text = "Tap Skills. This is where your power comes from.", Target = "Skills", Kind = "open", Goal = "Skills" },
	{ Id = "HeroOpen", Title = "Your hero", Text = "Tap Hero to see your stats and gear.", Target = "Hero", Kind = "open", Goal = "Hero" },
	{ Id = "BagOpen", Title = "Your bag", Text = "Tap Bag. Wear any item with higher IP.", Target = "Bag", Kind = "open", Goal = "Bag" },
	{ Id = "PetsOpen", Title = "Your pet", Text = "Tap Pets. Your pet fights for you too.", Target = "Pets", Kind = "open", Goal = "Pets" },
	{ Id = "QuestsOpen", Title = "Quests", Text = "Tap Quests to collect free rewards.", Target = "Quests", Kind = "open", Goal = "Quests" },
	{ Id = "Level", Title = "Keep climbing", Text = "Let the fights run. Reach stage 8.", Target = "Stage", Kind = "frontier", Goal = 8 },
	{ Id = "Boss", Title = "Beat the boss!", Text = "Stage 10 is a boss. Win to finish and get 10 pet wishes and 10 skill wishes.", Target = "Stage", Kind = "frontier", Goal = 11 },
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
	for ticketId, count in pairs(Tutorial.Reward) do
		Consumables.Grant(profile, ticketId, count)
	end
	return true, Tutorial.Reward
end

return Tutorial
