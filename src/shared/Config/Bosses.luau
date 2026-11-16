--[[
	Bosses (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Bosses

	Two boss events that live in the plaza.

	Both bosses are very hard, real fights in your arena using the normal auto combat: your party fights until it falls (or
	  FightSeconds runs out), and the damage you dealt is your score. Challenge as often as you like (ChallengeCooldown apart);
	  only your HIGHEST damage ever counts.

	WORLD BOSS  appears on every server on a timer and walks around the plaza. When the timer ends, every player who challenged
	  gets rewards for each damage tier their best fight reached, AND all the tiers below it. Tier thresholds are multiplied by
	  DamageScale(frontier) so a fresh player and a veteran aim at tiers that suit them.

	SEASON BOSS shared by ALL servers. Every player's best damage is added up into one global total, which is the boss's
	  PERMANENT health loss (beat your best and the boss loses the difference). The boss also weakens by itself over the last
	  part of the season (the Finale), so it always falls near the end. Crossing health thresholds gives everyone who contributed
	  a reward (claimed from the Boss window); when it dies, everyone who contributed gets a Colossus Egg that hatches into a
	  baby of the boss.

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	World = {
		Name = "Gloomhide Ogre", DefId = "WorldOgre",
		Look = { Color = { 120, 90, 150 }, Height = 26 },
		FirstSpawnSeconds = 120, -- after the server starts
		IntervalSeconds = 1500, -- between the end of one boss and the next
		DurationSeconds = 600,
		StudioFirstSpawn = 25,
		StudioInterval = 90,
		StudioDuration = 240,
		FightSeconds = 120, -- the longest one fight can last
		ChallengeCooldown = 20, -- seconds between your challenges
		AttackMult = 2.4, -- of a stage-appropriate monster
		DefenseMult = 1.5,
		AttackSpeed = 0.9,
		Abilities = { -- a telegraphed single-target blow, a party-wide stomp, and a berserk phase after a minute
			{ Id = "CrushingBlow", Level = 1, Timer = 6 },
			{ Id = "BossStomp", Level = 1, Timer = 14 },
			{ Id = "Berserk", Level = 1, Timer = 60 },
		},
		-- thresholds are multiples of the scale for your frontier (one typical fight's damage)
		Tiers = {
			{ Id = 1, Damage = 1, Name = "Scratched it", Rewards = { Gold = 9000, Items = { PetFood = 2 } } },
			{ Id = 2, Damage = 3, Name = "Bruised it", Rewards = { Gold = 15000, Items = { XPTonic = 2 } } },
			{ Id = 3, Damage = 6, Name = "Hurt it", Rewards = { Items = { SkillWish = 1, PowerElixir = 1 } } },
			{ Id = 4, Damage = 10, Name = "Staggered it", Rewards = { Items = { PetWish = 1, HasteDraught = 1, PetFood = 3 } } },
			{ Id = 5, Damage = 16, Name = "Wounded it", Rewards = { Items = { PetWish = 2, XPTonic = 2, SkillWish = 1 } } },
			{ Id = 6, Damage = 20, Name = "Nearly felled it", Rewards = { Items = { PetWish = 3, SkillWish = 2, GrandPetFood = 1, IronTonic = 1 }, Gear = { Rarity = "Epic", Bonus = 10 } } },
		},
	},

	Season = {
		Name = "Verdant Colossus", DefId = "Colossus",
		Look = { Color = { 70, 140, 90 }, Height = 90 },
		MaxHealth = 30000000, -- the total of every player's best fight
		-- the last FinaleShare of the season: the boss withers faster and faster, reaching 0 at the end
		FinaleShare = 0.2,
		FightSeconds = 150,
		ChallengeCooldown = 20,
		AttackMult = 3.2,
		DefenseMult = 1.8,
		AttackSpeed = 0.8,
		Abilities = {
			{ Id = "CrushingBlow", Level = 1, Timer = 5 },
			{ Id = "BossStomp", Level = 1, Timer = 12 },
			{ Id = "Berserk", Level = 1, Timer = 45 },
		},
		MinContribution = 1, -- challenges needed to share rewards
		SyncSeconds = 20,
		-- Pct = health remaining when it triggers (1 = full health); the last one is death
		Thresholds = {
			{ Id = "p90", Pct = 0.90, Name = "90% health", Rewards = { Gold = 24000, Items = { PetFood = 3, XPTonic = 1 } } },
			{ Id = "p75", Pct = 0.75, Name = "75% health", Rewards = { Items = { PetWish = 1, XPTonic = 2 } } },
			{ Id = "p50", Pct = 0.50, Name = "Half health", Rewards = { Items = { SkillWish = 2, PetWish = 1, PowerElixir = 2 } } },
			{ Id = "p25", Pct = 0.25, Name = "25% health", Rewards = { Items = { PetWish = 2, GrandPetFood = 2, HasteDraught = 2 } } },
			{ Id = "p10", Pct = 0.10, Name = "10% health", Rewards = { Items = { SkillWish = 3, PetWish = 3 } } },
			{ Id = "dead", Pct = 0, Name = "Colossus defeated", Rewards = { Egg = true, Items = { PetWish = 3, SkillWish = 3, GrandPetFood = 3 } } },
		},
		EggPet = "Colossling",
	},
}
