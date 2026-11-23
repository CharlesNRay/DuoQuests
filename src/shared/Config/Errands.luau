--[[
	Config/Errands: the town errands (docs/TOWN.md phase 2). Each one is done once a day.

	  Givers[id]   an NPC in the town (spot id in World.TownSpots): Name, Line (what they say when you take the errand)
	  List         in board order; each errand:
	    Id, Name, Giver (spot id), Blurb (notice board text)
	    Steps        after taking it from the giver, in order: Spot (World.TownSpots id, or "Cat" = today's hiding place),
	                 Text (the tracker line), Prompt (the button at that spot), Carry (what you now hold, for the client)
	    Reward       { Wishstones = n, Items = { [consumableId] = n } }
	  CatHints[n]  where Cat<n> is, for the tracker ("Mabel last saw her ...")

	Rewards stay small (docs/TOWN.md: town income <= ~10% of a day's): all four together are 15 Wishstones
	(about 3 Meadow wishes) plus one Skill Wish and one Pet Wish ticket.
]]

return {
	Givers = {
		Mabel = { Name = "Old Mabel", Line = "Oh dear, my Whiskers has wandered off again! Could you find her?" },
		Warden = { Name = "Warden Hale", Line = "The beasts are restless. Bring them a roast boar from the tavern before they get ideas." },
		Guildmaster = { Name = "Guildmaster Orin", Line = "The guild has run dry! Fetch us a keg from the Sleepy Griffin." },
		Sergeant = { Name = "Sergeant Brask", Line = "These dummies are losing their stuffing. Get me some straw from the hay pile by the pet park!" },
	},
	List = {
		{
			Id = "LostCat", Name = "The Lost Cat", Giver = "Mabel",
			Blurb = "Old Mabel at the Town Gate has lost her cat again.",
			Steps = {
				{ Spot = "Cat", Text = "Find Whiskers the cat: Mabel last saw her %s.", Prompt = "Pick up Whiskers", Carry = "Cat" },
				{ Spot = "Mabel", Text = "Bring Whiskers back to Old Mabel at the Town Gate.", Prompt = "Return Whiskers" },
			},
			Reward = { Wishstones = 5 },
		},
		{
			Id = "Offering", Name = "Feed the Beasts", Giver = "Warden",
			Blurb = "Warden Hale at the Boss Field wants an offering for the bosses.",
			Steps = {
				{ Spot = "Tavern", Text = "Fetch a roast boar from the Sleepy Griffin tavern at the Town Gate.", Prompt = "Take the roast boar", Carry = "Boar" },
				{ Spot = "Altar", Text = "Lay the boar on the offering stone at the Boss Field.", Prompt = "Make the offering" },
			},
			Reward = { Wishstones = 3, Items = { SkillWish = 1 } },
		},
		{
			Id = "GuildAle", Name = "A Thirsty Guild", Giver = "Guildmaster",
			Blurb = "Guildmaster Orin at the Training Grounds needs a keg of ale.",
			Steps = {
				{ Spot = "Tavern", Text = "Pick up a keg of ale at the Sleepy Griffin tavern (Town Gate).", Prompt = "Take the keg", Carry = "Keg" },
				{ Spot = "Guildmaster", Text = "Carry the keg to Guildmaster Orin at the guild hall.", Prompt = "Deliver the keg" },
			},
			Reward = { Wishstones = 3, Items = { PetWish = 1 } },
		},
		{
			Id = "Straw", Name = "Stuffing for the Dummies", Giver = "Sergeant",
			Blurb = "Sergeant Brask's training dummies need new straw.",
			Steps = {
				{ Spot = "Hay", Text = "Grab straw from the hay pile beside the pet park (Wishing Grove).", Prompt = "Grab straw", Carry = "Straw" },
				{ Spot = "Sergeant", Text = "Bring the straw to Sergeant Brask at the training dummies.", Prompt = "Hand over the straw" },
			},
			Reward = { Wishstones = 4 },
		},
	},
	CatHints = {
		"past the fishing pond in the Wishing Grove",
		"behind the sparring ring at the Training Grounds",
		"by the well at the Town Gate",
		"under a tree on the road between the Town Gate and the Training Grounds",
		"playing in the pet park",
	},
}
