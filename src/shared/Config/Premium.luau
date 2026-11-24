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
	           Tag    optional label on the row ("BEST VALUE", "SAVE 10%")
	           Offer  "Subclass" = hidden until the player reaches the subclass level and has seen the pop-up for it
	           Limit  nil = unlimited | { Per = "Account" | "Season", Count = n }
	           Grants any of: SkillPicks = n, Items = { [consumableId] = n }, PassMax = true (season pass straight to the top level),
	                  BagUpgrades = n, Premium = true (the premium pass track)

	Every number is a PLACEHOLDER to be tuned.
]]

return {
	-- One-time Robux purchases (Game Passes). GamePassId is 0 until the pass exists in the creator dashboard.
	-- Perks are permanent and checked with Passes.Perks(profile). Every number is a PLACEHOLDER to be tuned.
	Passes = {
		VIP = {
			Id = "VIP", Name = "VIP Pass", Robux = 499, GamePassId = 0,
			Text = "+25% gold, +25% XP, 20 more bag slots, 2 more dungeon keys a day and a second pet slot (its stat bonuses count too).",
			Perks = { GoldGain = 0.25, XPGain = 0.25, BagSlots = 20, DungeonKeys = 2, PetSlots = 1 },
		},
		-- sold on the main menu (a locked third card) and in the Store
		CharacterSlots = {
			Id = "CharacterSlots", Name = "Extra Character Slots", Robux = 149, GamePassId = 0,
			Text = "2 more character slots (4 in all): play two more classes, each with its own level, gear and progress.",
			Perks = { CharacterSlots = 2 },
		},
	},

	Packs = {
		{ Id = "Sun1", Name = "Handful of Sunstones", Sunstones = 80, Robux = 79, FirstBonus = 80, ProductId = 0 },
		{ Id = "Sun2", Name = "Pouch of Sunstones", Sunstones = 420, Robux = 399, FirstBonus = 420, ProductId = 0 },
		{ Id = "Sun3", Name = "Chest of Sunstones", Sunstones = 900, Robux = 799, FirstBonus = 900, ProductId = 0 },
		{ Id = "Sun4", Name = "Vault of Sunstones", Sunstones = 2000, Robux = 1699, FirstBonus = 2000, ProductId = 0 },
	},

	Items = {
		{
			Id = "StarterPack", Name = "Starter Pack", Limit = { Per = "Account", Count = 1 }, Cost = 120,
			Text = "2 free skill picks, 5 XP Tonics, 3 Power Elixirs, 3 Grand Pet Foods and a bigger bag.",
			Grants = { SkillPicks = 2, BagUpgrades = 1, Items = { XPTonic = 5, PowerElixir = 3, GrandPetFood = 3 } },
		},
		{
			Id = "EnhancedStarter", Name = "Enhanced Starter Pack", Tag = "BEST VALUE", Limit = { Per = "Account", Count = 1 }, Cost = 450,
			Text = "4 free skill picks, 15 XP Tonics, 10 Power Elixirs, 10 Grand Pet Foods, 5 Iron Tonics, 5 Haste Draughts and 3 bag upgrades.",
			Grants = { SkillPicks = 4, BagUpgrades = 3, Items = { XPTonic = 15, PowerElixir = 10, GrandPetFood = 10, IronTonic = 5, HasteDraught = 5 } },
		},
		{
			-- shown on screen as a pop-up when the player reaches the subclass level; listed here once they close it
			Id = "SubclassPack", Name = "Subclass Pack", Offer = "Subclass", Limit = { Per = "Season", Count = 1 }, Cost = 180,
			Text = "4 free skill picks to unlock the skills you want (including subclass skills), plus defense and speed boosts.",
			Grants = { SkillPicks = 4, Items = { IronTonic = 3, HasteDraught = 3 } },
		},
		{
			Id = "PremiumPass", Name = "Premium Season Pass", Limit = { Per = "Season", Count = 1 }, Cost = 400,
			Text = "Unlocks the Premium reward track for this season's pass.",
			Grants = { Premium = true },
		},
		{
			Id = "PassMax", Name = "Pass Max-out", Limit = { Per = "Season", Count = 1 }, Cost = 700,
			Text = "Instantly takes the Season Pass to level 30. Every reward is yours to claim (premium rewards need the Premium Pass).",
			Grants = { PassMax = true },
		},
		{
			-- cheaper than PremiumPass (400) + PassMax (700) = 1100; gone once the player owns either half
			Id = "PassBundle", Name = "Premium Pass + Max-out Deal", Tag = "SAVE 10%", Limit = { Per = "Season", Count = 1 }, Cost = 990,
			Text = "The Premium Season Pass and the Pass Max-out together: every free and premium reward, ready to claim.",
			Grants = { Premium = true, PassMax = true },
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
	},
}
