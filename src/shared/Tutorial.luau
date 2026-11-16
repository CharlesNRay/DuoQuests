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
	{ Id = "Welcome", Title = "Welcome to Duo Quest", Text = "Duo Quest is a two-player idle adventure. You and a partner fight on your own, even while you are away. This short guide covers everything you need to beat the first boss.", Target = "Party", Kind = "next" },
	{ Id = "Party", Title = "Your party", Text = "The two cards at the top left are you and your partner. Each shows a name, level, class and item power (IP), the total strength of that hero. Tap a card to inspect it.", Target = "Party", Kind = "next" },
	{ Id = "Fight", Title = "Fights run themselves", Text = "Every win moves you up a stage and drops gold, experience and gear. Stay put and watch the stage counter in the top right climb to stage 3.", Target = "Stage", Kind = "frontier", Goal = 3 },
	{ Id = "Watch", Title = "Watching a fight", Text = "Home takes you to your arena to watch your battle up close. Plaza takes you back to the town square. Your progress is the same in both places.", Target = "Home", Kind = "next" },
	{ Id = "SkillsOpen", Title = "Skills", Text = "Open Skills. This is where most of your power comes from.", Target = "Skills", Kind = "open", Goal = "Skills" },
	{ Id = "SkillsInfo", Title = "Using skills", Text = "Four equipped skills fire in order, left to right, then repeat. Tap a skill to swap it or upgrade it with Skill Picks. New skills unlock as you level.", Target = "Skills", Kind = "next" },
	{ Id = "HeroOpen", Title = "Hero", Text = "Open Hero to see your stats and what you are wearing.", Target = "Hero", Kind = "open", Goal = "Hero" },
	{ Id = "HeroInfo", Title = "Stats and gear", Text = "Health, damage and defense decide how long you survive. Every item you wear raises your IP. Gear drops from enemies, and the Blacksmith upgrades it.", Target = "Hero", Kind = "next" },
	{ Id = "BagOpen", Title = "Bag", Text = "Open Bag to see every item you are carrying.", Target = "Bag", Kind = "open", Goal = "Bag" },
	{ Id = "BagInfo", Title = "Managing items", Text = "Wear anything with a higher IP than your current piece. Sell the extras to the Merchant in the plaza for gold, then spend that gold on upgrades.", Target = "Bag", Kind = "next" },
	{ Id = "PetsOpen", Title = "Pets", Text = "Open Pets.", Target = "Pets", Kind = "open", Goal = "Pets" },
	{ Id = "PetsInfo", Title = "Your pet fights too", Text = "An equipped pet attacks on its own and adds bonus stats. Duplicates become shards that raise its rank. Wish for new pets at the Wishing Tree with Wishstones.", Target = "Pets", Kind = "next" },
	{ Id = "QuestsOpen", Title = "Quests", Text = "Open Quests for daily goals and the season pass.", Target = "Quests", Kind = "open", Goal = "Quests" },
	{ Id = "QuestsInfo", Title = "Rewards worth taking", Text = "Finished quests pay Wishstones, gold and Sunstones. Claim your daily login reward too. It adds up quickly.", Target = "Quests", Kind = "next" },
	{ Id = "Level", Title = "Keep climbing", Text = "Fight on to stage 8. You should level up several times on the way. Check Skills and Gear after each level, since new skills and upgrades unlock.", Target = "Stage", Kind = "frontier", Goal = 8 },
	{ Id = "BossPrep", Title = "Boss ahead", Text = "The Battle button also holds dungeons, expeditions and the world boss. Stage 10 is a boss. It hits harder and has more health than normal enemies, so the fight takes longer. Equip your best gear and upgrade your skills first.", Target = "Battle", Kind = "next" },
	{ Id = "Boss", Title = "Beat the stage 10 boss", Text = "Keep fighting until the boss falls. Clearing it ends the tutorial and pays a reward.", Target = "Stage", Kind = "frontier", Goal = 11 },
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
