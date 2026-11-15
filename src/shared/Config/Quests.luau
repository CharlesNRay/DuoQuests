--[[
	Quests (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Quests

	DAILY QUESTS: every UTC day three quests are drawn from Pool (same three for everyone that day). Each quest
	tracks an event while it is active; finish it to claim its reward. Claiming all three also unlocks the daily bonus.

	  Pool entry   { Id, Event, Goal, Text }   Event is one of:
	               Clear (any won fight), Frontier (a first clear of a stage), Boss (a boss stage won),
	               Wish (wishes made at the Tree, a ten-pull counts as ten), Feed (pet food given), Gear (gear found)
	  QuestReward  per quest   { GoldClears (gold = this many frontier clears), Wishstones, PassXP }
	  BonusReward  all three claimed { Wishstones, PassXP, Tickets = { PetWish = n } }

	SEASON PASS: gaining Pass XP (quests, clearing stages) raises the pass level; each level has a reward to claim.
	It resets with the season. (Only the free track exists so far; Premium = true levels are shown locked.)

	  Pass.MaxLevel, Pass.XPPerLevel
	  Pass.PerClear / PerFrontier / PerBoss     Pass XP from stage clears (frontier and boss stack with the clear)
	  Pass.Rewards   level -> { GoldClears?, Wishstones?, Shards?, SkillPicks?, Items = { [consumableId] = n }? , Premium? }

	Every number is a PLACEHOLDER to be tuned.
]]

local Rewards = {}
for level = 1, 30 do
	local r = { GoldClears = 4 + level // 2 }
	if level % 2 == 0 then
		r.Wishstones = 2 + level // 10
	end
	if level % 3 == 0 then
		r.Items = { XPTonic = 1 + level // 15 }
	end
	if level % 5 == 0 then
		r.Shards = 10 + level
		r.Items = r.Items or {}
		r.Items.PetFood = 2
	end
	if level % 10 == 0 then
		r.SkillPicks = 1
		r.Items = r.Items or {}
		r.Items.PetWish = 1
	end
	if level == 30 then
		r.Wishstones = 20
	end
	Rewards[level] = r
end

return {
	Pool = {
		{ Id = "Clear12", Event = "Clear", Goal = 12, Text = "Win 12 fights" },
		{ Id = "Clear30", Event = "Clear", Goal = 30, Text = "Win 30 fights" },
		{ Id = "Frontier3", Event = "Frontier", Goal = 3, Text = "Clear 3 new stages" },
		{ Id = "Frontier6", Event = "Frontier", Goal = 6, Text = "Clear 6 new stages" },
		{ Id = "Boss1", Event = "Boss", Goal = 1, Text = "Defeat a boss stage" },
		{ Id = "Wish2", Event = "Wish", Goal = 2, Text = "Make 2 wishes at the Wishing Tree" },
		{ Id = "Wish5", Event = "Wish", Goal = 5, Text = "Make 5 wishes at the Wishing Tree" },
		{ Id = "Feed2", Event = "Feed", Goal = 2, Text = "Feed your pet 2 times" },
		{ Id = "Gear3", Event = "Gear", Goal = 3, Text = "Find 3 pieces of gear" },
	},
	QuestsPerDay = 3,
	QuestReward = { GoldClears = 6, Wishstones = 2, PassXP = 40 },
	BonusReward = { Wishstones = 5, PassXP = 60, Tickets = { PetWish = 1 } },

	Pass = {
		MaxLevel = 30,
		XPPerLevel = 150,
		PerClear = 3,
		PerFrontier = 6,
		PerBoss = 25,
		Rewards = Rewards,
	},
}
