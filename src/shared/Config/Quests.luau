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
	  Pass.Rewards   level -> { Wishstones?, SkillPicks?, Items = { [consumableId] = n }, Premium? }  (never gold)

	Every number is a PLACEHOLDER to be tuned.
]]

-- The pass never pays gold: odd levels give a consumable, even levels give Wishstones, and every 5th level gives a
-- wish ticket (Skill Wish on 5/15/25, Pet Wish on 10/20/30). Levels 15 and 30 add a free skill pick.
local CONSUMABLE_CYCLE = {
	{ XPTonic = 1 }, { PowerElixir = 1 }, { PetFood = 2 }, { IronTonic = 1 }, { HasteDraught = 1 }, { GrandPetFood = 1 },
}
local Rewards = {}
for level = 1, 30 do
	local r = { Items = {} }
	if level % 2 == 0 then
		r.Wishstones = 2 + level // 10 + (if level % 10 == 0 then 2 else 0)
	else
		for id, n in pairs(CONSUMABLE_CYCLE[((level - 1) // 2) % #CONSUMABLE_CYCLE + 1]) do
			r.Items[id] = n + level // 20
		end
	end
	if level % 10 == 5 then
		r.Items.SkillWish = 1 + level // 25
	elseif level % 10 == 0 then
		r.Items.PetWish = if level == 30 then 2 else 1
	end
	if level == 15 or level == 30 then
		r.SkillPicks = 1
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
	BonusReward = { Wishstones = 5, PassXP = 60, Tickets = { PetWish = 1, SkillWish = 1 } },

	Pass = {
		MaxLevel = 30,
		XPPerLevel = 150,
		PerClear = 3,
		PerFrontier = 6,
		PerBoss = 25,
		Rewards = Rewards,
	},
}
