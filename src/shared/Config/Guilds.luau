--[[
	Guilds (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Guilds

	Guilds are stored in a shared DataStore, so a guild is the same on every Roblox server. Members work towards
	COLLECTIVE missions (everyone's actions fill one bar), the guild earns Guild Points, and the LEADER spends them
	on upgrades that every member benefits from. A weekly raid boss has one shared health bar that members chip away
	at whenever they log in, exactly like the season boss.

	  Create / Limits       cost, name and tag rules, member cap (grown by the Roster upgrade)
	  Succession            the leader is replaced when inactive (see Guilds.CheckSuccession)
	  Upgrades              [id] = { Stat?, Mode?, PerLevel, Max, Cost, Name, Text }   guild buffs for every member
	  Missions              Daily / Weekly pools; goal = PerMember x active members; Points scale with guild size
	  Raid                  weekly bosses, attempts per day, health, reward tiers
	  Marks                 personal currency for the Guild Wish (guild-only pets)

	Every number is a PLACEHOLDER to be tuned.
]]

local DAY = 86400

return {
	CreateGold = 300000,
	CreateMinLevel = 10,
	NameMin = 3, NameMax = 20, TagMin = 2, TagMax = 4, DescMax = 80,
	BaseMembers = 20, MaxMembers = 50,
	MaxRequests = 30,

	-- the leader is replaced when they have not logged in for InactiveDays; the successor must have logged in within
	-- SuccessorDays (the next in line is tried if not; if nobody qualifies the guild keeps its leader and is checked again)
	InactiveDays = 5,
	SuccessorDays = 3,
	ActiveDays = 7, -- a member counts as active for mission goals and raid health if seen within this long
	InactiveKickDays = 60, -- members unseen this long are dropped when the guild is checked (never the leader)

	Ranks = { "Leader", "Officer", "Member" },

	-- Upgrades the leader buys with Guild Points. Value at level L = PerLevel * L. Cost to go from level L to L+1 =
	-- floor(Cost * Growth^L).
	Growth = 1.25,
	Upgrades = {
		Attack = { Name = "War Banner", Text = "Attack", Stat = "Attack", Mode = "Mul", PerLevel = 0.01, Max = 20, Cost = 15 },
		MaxHealth = { Name = "Hearth Feast", Text = "Max Health", Stat = "MaxHealth", Mode = "Mul", PerLevel = 0.01, Max = 20, Cost = 15 },
		Defense = { Name = "Shield Wall", Text = "Defense", Stat = "Defense", Mode = "Mul", PerLevel = 0.01, Max = 20, Cost = 15 },
		AttackSpeed = { Name = "Drill Yard", Text = "Attack Speed", Stat = "AttackSpeed", Mode = "Mul", PerLevel = 0.005, Max = 10, Cost = 20 },
		CritChance = { Name = "Sharpening Stone", Text = "Crit Chance", Stat = "CritChance", Mode = "Add", PerLevel = 0.002, Max = 15, Cost = 20 },
		CritMultiplier = { Name = "Master Smith", Text = "Crit Damage", Stat = "CritMultiplier", Mode = "Add", PerLevel = 0.01, Max = 15, Cost = 20 },
		XPGain = { Name = "Library", Text = "EXP from stage clears", Key = "XPGain", PerLevel = 0.01, Max = 20, Cost = 12 },
		GoldGain = { Name = "Treasury", Text = "Gold from stage clears", Key = "GoldGain", PerLevel = 0.01, Max = 20, Cost = 12 },
		Roster = { Name = "Barracks", Text = "member slots", Key = "Slots", PerLevel = 5, Max = 6, Cost = 40, Plain = true },
	},
	UpgradeOrder = { "Attack", "MaxHealth", "Defense", "AttackSpeed", "CritChance", "CritMultiplier", "XPGain", "GoldGain", "Roster" },

	-- Mission goal = PerMember x active members (at least MinGoal). Rewards: every member who contributed claims
	-- Gold (clears' worth), Wishstones and Marks; the guild earns Points when the bar fills, more for bigger guilds.
	-- Events are the Quests events plus "Raid" (guild raid attempts) and "Dungeon" (expedition runs).
	Missions = {
		Daily = {
			Count = 3,
			Points = 10,
			BonusPoints = 15, -- all three done
			Reward = { GoldClears = 6, Wishstones = 2, Marks = 2 },
			Pool = {
				{ Id = "dClear", Event = "Clear", PerMember = 20, MinGoal = 20, Text = "Win stage fights together" },
				{ Id = "dFront", Event = "Frontier", PerMember = 1, MinGoal = 3, Text = "Clear new stages" },
				{ Id = "dBoss", Event = "Boss", PerMember = 1, MinGoal = 3, Text = "Defeat boss stages" },
				{ Id = "dStrike", Event = "Strike", PerMember = 1, MinGoal = 3, Text = "Challenge the world or season boss" },
				{ Id = "dWish", Event = "Wish", PerMember = 3, MinGoal = 10, Text = "Make wishes at the Tree" },
				{ Id = "dFeed", Event = "Feed", PerMember = 2, MinGoal = 5, Text = "Feed pets" },
				{ Id = "dGear", Event = "Gear", PerMember = 4, MinGoal = 10, Text = "Find gear" },
				{ Id = "dRaid", Event = "Raid", PerMember = 1, MinGoal = 3, Text = "Strike the guild raid boss" },
				{ Id = "dDungeon", Event = "Dungeon", PerMember = 1, MinGoal = 3, Text = "Run expeditions" },
			},
		},
		Weekly = {
			Count = 3,
			Points = 50,
			BonusPoints = 75,
			Reward = { GoldClears = 30, Wishstones = 8, Marks = 8 },
			Pool = {
				{ Id = "wClear", Event = "Clear", PerMember = 120, MinGoal = 120, Text = "Win stage fights together" },
				{ Id = "wFront", Event = "Frontier", PerMember = 6, MinGoal = 12, Text = "Clear new stages" },
				{ Id = "wBoss", Event = "Boss", PerMember = 5, MinGoal = 10, Text = "Defeat boss stages" },
				{ Id = "wStrike", Event = "Strike", PerMember = 6, MinGoal = 12, Text = "Challenge the world or season boss" },
				{ Id = "wWish", Event = "Wish", PerMember = 15, MinGoal = 40, Text = "Make wishes at the Tree" },
				{ Id = "wGear", Event = "Gear", PerMember = 20, MinGoal = 40, Text = "Find gear" },
				{ Id = "wRaid", Event = "Raid", PerMember = 6, MinGoal = 12, Text = "Strike the guild raid boss" },
				{ Id = "wDungeon", Event = "Dungeon", PerMember = 5, MinGoal = 10, Text = "Run expeditions" },
			},
		},
		PointsPerMember = 0.1, -- points are multiplied by (1 + this x active members)
	},

	-- The raid boss changes every week (the list cycles). Health = HealthPerFrontier x the sum of every active member's
	-- Bosses.DamageScale(frontier), so a guild of any size has a fair fight. Each member has AttemptsPerDay strikes a day.
	Raid = {
		AttemptsPerDay = 3,
		HealthPerScale = 25,
		MinMembers = 5, -- health is never less than this many members' worth
		DefeatPoints = 150,
		Bosses = {
			{ Id = "RaidTitan", Abilities = { { Id = "CrushingBlow", Level = 1, Timer = 6 }, { Id = "BossStomp", Level = 1, Timer = 13 }, { Id = "Berserk", Level = 1, Timer = 30 } }, Name = "Stone Titan", DefId = "RaidTitan", FightSeconds = 40, AttackMult = 1.1, DefenseMult = 1.2, AttackSpeed = 0.8, Blurb = "Ancient guardian of the old vault." },
			{ Id = "RaidWyrm", Abilities = { { Id = "PoisonSpit", Level = 1, Timer = 5 }, { Id = "BossStomp", Level = 1, Timer = 12 }, { Id = "Berserk", Level = 1, Timer = 30 } }, Name = "Tide Wyrm", DefId = "RaidWyrm", FightSeconds = 40, AttackMult = 1.0, DefenseMult = 1.0, AttackSpeed = 1.0, Blurb = "Coils out of the deep every storm season." },
			{ Id = "RaidLich", Abilities = { { Id = "EmberBolt", Level = 1, Timer = 5 }, { Id = "CrushingBlow", Level = 1, Timer = 8 }, { Id = "Berserk", Level = 1, Timer = 30 } }, Name = "Hollow Lich", DefId = "RaidLich", FightSeconds = 40, AttackMult = 1.2, DefenseMult = 0.9, AttackSpeed = 0.9, Blurb = "Counts the days until the guild falls." },
			{ Id = "RaidPhoenix", Abilities = { { Id = "EmberBolt", Level = 1, Timer = 4 }, { Id = "BossStomp", Level = 1, Timer = 11 }, { Id = "Berserk", Level = 1, Timer = 30 } }, Name = "Ashen Phoenix", DefId = "RaidPhoenix", FightSeconds = 40, AttackMult = 1.1, DefenseMult = 0.8, AttackSpeed = 1.2, Blurb = "Burns, falls, and rises again." },
		},
		-- rewards by damage share of the whole guild's average (share x members): Reward tiers, best first
		Tiers = {
			{ Id = "Champion", MinShare = 2.0, Gold = 20, Marks = 10, Wishstones = 8 },
			{ Id = "Fighter", MinShare = 1.0, Gold = 12, Marks = 7, Wishstones = 5 },
			{ Id = "Helper", MinShare = 0.0, Gold = 6, Marks = 4, Wishstones = 3 },
		},
		DefeatBonus = { Gold = 10, Marks = 6, Wishstones = 4 }, -- extra for everyone who struck, when the boss falls
	},

	-- Guild Wish: spend personal Marks for a guild-only pet.
	Wish = {
		Cost = 8,
		Odds = { Rare = 0.60, Epic = 0.33, Legendary = 0.07 },
		PityEpic = 12, -- an Epic or better is guaranteed within this many wishes
		PityLegendary = 60,
	},

	Day = DAY,
}
