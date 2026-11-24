--[[
	Tutorial (ModuleScript): the guided first session, from the first fight to the first boss, then wishing and watching.

	The steps are data; the client shows them (client/UI/Tutorial) and the server only keeps the player's place and pays
	the finishing reward once.

	  Tutorial.Steps                       ordered list: { Id, Title, Text, Target, Kind, Goal? }
	      Kind "next"      the player presses Next
	      Kind "open"      completes when the player opens the panel named in Goal ("Watch" = watching a battle)
	      Go (optional)    a place the card button walks you to (a PlazaSpots name); Target "Go" points at that button
	      Kind "frontier"  completes when the highest stage reached is at least Goal
	      Kind "equip"     completes when the equipped skills change while the step is current (or nothing is left to equip)
	  Tutorial.Of(profile)                 -> { Step, Done, Rewarded } (created on first use)
	  Tutorial.Advance(profile, step)      moves from `step` to the next one (only forwards, one at a time)
	  Tutorial.Skip(profile)               ends the tutorial (the reward still comes with the first boss, see PayIfSkipped)
	  Tutorial.Finish(profile)             -> ok, reward   pays once, after the first boss is beaten (the wrap-up steps follow)
	  Tutorial.Complete(profile, step)     ends it from the last step (after the reward)
]]
local Consumables = require(script.Parent.Consumables)

local Tutorial = {}

Tutorial.BossStage = 10
Tutorial.Reward = { PetWish = 10, SkillWish = 10 } -- wish tickets (Consumables), paid once for beating the first boss

Tutorial.Steps = {
	{ Id = "Welcome", Title = "Welcome to Idle Party Quest!", Text = "Your party of up to four heroes fights together, even while you are away.", Target = nil, Kind = "next" },
	{ Id = "Fight", Title = "Fights run by themselves", Text = "Just wait. Your team wins fights and climbs stages. Reach stage 3.", Target = "Stage", Kind = "frontier", Goal = 3 },
	{ Id = "SkillsOpen", Title = "Your skills", Text = "Tap Skills. This is where your power comes from.", Target = "Skills", Kind = "open", Goal = "Skills" },
	{ Id = "HeroOpen", Title = "Your hero", Text = "Tap Hero to see your stats and gear.", Target = "Hero", Kind = "open", Goal = "Hero" },
	{ Id = "BagOpen", Title = "Your bag", Text = "Tap Bag. Wear any item with higher IP.", Target = "Bag", Kind = "open", Goal = "Bag" },
	{ Id = "PetsOpen", Title = "Your pet", Text = "Tap Pets. Your pet fights for you too.", Target = "Pets", Kind = "open", Goal = "Pets" },
	{ Id = "QuestsOpen", Title = "Quests", Text = "Tap Quests to collect free rewards.", Target = "Quests", Kind = "open", Goal = "Quests" },
	{ Id = "Level", Title = "Keep climbing", Text = "Let the fights run. Reach stage 8.", Target = "Stage", Kind = "frontier", Goal = 8 },
	{ Id = "Boss", Title = "Beat the boss!", Text = "Stage 10 is a boss. Win to get 10 pet wishes and 10 skill wishes.", Target = "Stage", Kind = "frontier", Goal = 11 },
	-- after the boss (the wishes are paid when it falls): spend them, then learn you can watch the fight
	{ Id = "Wish", Title = "Make your wishes", Text = "Your wishes are here! Visit the Wishing Tree for new pets and skills.", Target = "Go", Kind = "open", Goal = "Wish", Go = "Tree", GoText = "Take me there" },
	{ Id = "Equip", Title = "Equip your new skills", Text = "Wishes gave you new skills. Tap Skills and drag one onto a slot.", Target = "Skills", Kind = "equip" },
	{ Id = "Watch", Title = "Watch your battle", Text = "Tap Home to watch your team fight live. You can watch other parties too.", Target = "Home", Kind = "open", Goal = "Watch" },
}
-- the step whose goal is beating the first boss (the reward is paid then; the steps after it are the wrap-up)
Tutorial.BossStep = 9

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

-- Pays the boss reward once (after the first boss falls). The tutorial goes on to its wrap-up steps (wishes, watching);
-- it only ends here when the player is already on the last step.
function Tutorial.Finish(profile)
	local t = stateOf(profile)
	if t.Rewarded then
		return false, "AlreadyRewarded"
	end
	if profile.Season.HighestStage <= Tutorial.BossStage then
		return false, "BossNotBeaten"
	end
	t.Rewarded = true
	if t.Step >= #Tutorial.Steps then
		t.Done = true
	end
	for ticketId, count in pairs(Tutorial.Reward) do
		Consumables.Grant(profile, ticketId, count)
	end
	return true, Tutorial.Reward
end

-- The last step is done: the tutorial ends (only once the boss reward is paid, so nobody misses it).
function Tutorial.Complete(profile, step)
	local t = stateOf(profile)
	if t.Done then
		return false, "Done"
	end
	if step ~= t.Step or t.Step ~= #Tutorial.Steps then
		return false, "WrongStep"
	end
	if not t.Rewarded then
		return false, "NotRewarded"
	end
	t.Done = true
	return true
end

-- Called after every frontier clear: a skipped tutorial (Done without the reward) pays out once the first boss is beaten.
function Tutorial.PayIfSkipped(profile)
	local t = stateOf(profile)
	if t.Done ~= true or t.Rewarded == true or profile.Season.HighestStage <= Tutorial.BossStage then
		return nil
	end
	t.Rewarded = true
	for ticketId, count in pairs(Tutorial.Reward) do
		Consumables.Grant(profile, ticketId, count)
	end
	return Tutorial.Reward
end

return Tutorial
