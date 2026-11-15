--[[
	Premium (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Premium

	TWO CURRENCIES
	  Wishstones (blue)  the wishing currency. EARNED ONLY (stage clears, quests, pass, daily). Never sold for Robux.
	  Sunstones  (orange) the premium currency. Bought with Robux (Packs below) and spent in the Premium shop (Items below).

	WHY THIS SPLIT: Roblox treats random rewards bought directly OR INDIRECTLY with Robux (gems, tickets, keys...) as "paid
	random items", which are restricted in some regions and need odds shown. Sunstones therefore never buy wishes, tickets,
	Wishstones or anything random. Every shop item below has FIXED contents, so it is the same for every player and region.
	(The premium season pass track still contains wish tickets: for players Roblox flags as restricted, hide or swap those
	rewards. TODO with PolicyService before launch.)

	  Packs    Robux -> Sunstones. ProductId is the Developer Product id (0 until it exists in the creator dashboard).
	           FirstBonus: the first time a player buys that pack they get this many extra Sunstones.
	  Items    the Premium shop. { Id, Name, Text, Cost (Sunstones), Limit, Grants }
	           Limit  nil = unlimited | { Per = "Account" | "Season", Count = n }
	           Grants any of: SkillPicks = n, Items = { [consumableId] = n }, Levels = n (hero levels),
	                  PassLevels = n (season pass levels), BagUpgrades = n, Premium = true (the premium pass track)

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	Packs = {
		{ Id = "Sun1", Name = "Handful of Sunstones", Sunstones = 80, Robux = 79, FirstBonus = 80, ProductId = 0 },
		{ Id = "Sun2", Name = "Pouch of Sunstones", Sunstones = 420, Robux = 399, FirstBonus = 420, ProductId = 0 },
		{ Id = "Sun3", Name = "Chest of Sunstones", Sunstones = 900, Robux = 799, FirstBonus = 900, ProductId = 0 },
		{ Id = "Sun4", Name = "Vault of Sunstones", Sunstones = 2000, Robux = 1699, FirstBonus = 2000, ProductId = 0 },
	},

	Items = {
		{
			Id = "StarterPack", Name = "Starter Pack", Limit = { Per = "Account", Count = 1 }, Cost = 120,
			Text = "3 free skill picks, 5 XP Tonics, 3 Power Elixirs, 3 Grand Pet Foods and a bigger bag.",
			Grants = { SkillPicks = 3, BagUpgrades = 1, Items = { XPTonic = 5, PowerElixir = 3, GrandPetFood = 3 } },
		},
		{
			Id = "LevelPack", Name = "Level-up Pack", Limit = { Per = "Season", Count = 3 }, Cost = 150,
			Text = "Instantly gain 3 hero levels.",
			Grants = { Levels = 3 },
		},
		{
			Id = "SubclassPack", Name = "Subclass Pack", Limit = { Per = "Season", Count = 1 }, Cost = 180,
			Text = "4 free skill picks to unlock the skills you want (including subclass skills), plus defense and speed boosts.",
			Grants = { SkillPicks = 4, Items = { IronTonic = 3, HasteDraught = 3 } },
		},
		{
			Id = "PassBoost", Name = "Pass Boost", Limit = { Per = "Season", Count = 4 }, Cost = 100,
			Text = "Skip ahead 5 levels on the Season Pass.",
			Grants = { PassLevels = 5 },
		},
		{
			Id = "BagPack", Name = "Bag Expansion", Limit = { Per = "Season", Count = 4 }, Cost = 60,
			Text = "Two more bag upgrades (10 slots).",
			Grants = { BagUpgrades = 2 },
		},
		{
			Id = "BoostBundle", Name = "Boost Bundle", Limit = nil, Cost = 80,
			Text = "5 XP Tonics, 5 Power Elixirs, 5 Haste Draughts and 10 Pet Foods.",
			Grants = { Items = { XPTonic = 5, PowerElixir = 5, HasteDraught = 5, PetFood = 10 } },
		},
		{
			Id = "PremiumPass", Name = "Premium Season Pass", Limit = { Per = "Season", Count = 1 }, Cost = 400,
			Text = "Unlocks the Premium reward track for this season's pass.",
			Grants = { Premium = true },
		},
	},
}
