--[[
	Config/Errands: the town errands (docs/TOWN.md phase 2). A pool of errands; each day PerDay of them are offered
	(one per townsperson at most, the same for everyone that day), and each offered one can be done once that day.

	  Givers[id]   an NPC in the town (spot id in World.TownSpots): Name, Line (what they say when you take the errand)
	  List         the pool; each errand:
	    Id, Name, Giver (spot id), Blurb (notice board text), StartCarry (held from the start, optional)
	    Steps        after taking it from the giver, in order: Spot (World.TownSpots id, or "Cat" = today's hiding place),
	                 Text (the tracker line), Prompt (the button at that spot), Carry (what you now hold, for the client)
	    Reward       { Wishstones = n, Items = { [consumableId] = n } }
	  CatHints[n]  where Cat<n> is, for the tracker ("Mabel last saw her ...")

	Rewards stay small (docs/TOWN.md: town income <= ~10% of a day's): a day's PerDay errands pay ~15-20 Wishstones and a
	couple of tickets or snacks.
]]

return {
	PerDay = 5,
	Givers = {
		Mabel = { Name = "Old Mabel" },
		Warden = { Name = "Warden Hale" },
		Guildmaster = { Name = "Guildmaster Orin" },
		Sergeant = { Name = "Sergeant Brask" },
		Tavern = { Name = "Greta" },
		Elder = { Name = "Elder Thessaly" },
		Courier = { Name = "Pip the Courier" },
	},
	List = {
		{
			Id = "LostCat", Name = "The Lost Cat", Giver = "Mabel",
			Line = "Oh dear, my Whiskers has wandered off again! Could you find her?",
			Blurb = "Old Mabel at the Town Gate has lost her cat again.",
			Steps = {
				{ Spot = "Cat", Text = "Find Whiskers the cat: Mabel last saw her %s.", Prompt = "Pick up Whiskers", Carry = "Cat" },
				{ Spot = "Mabel", Text = "Bring Whiskers back to Old Mabel at the Town Gate.", Prompt = "Return Whiskers" },
			},
			Reward = { Wishstones = 5 },
		},
		{
			Id = "Flowers", Name = "Flowers for Mabel", Giver = "Mabel",
			Line = "My old bones won't take me to the Grove today. Would you pick me some flowers, dear?",
			Blurb = "Old Mabel would love flowers from the Wishing Grove.",
			Steps = {
				{ Spot = "Flowers", Text = "Pick flowers from the flower bed by the Wishing Grove arch.", Prompt = "Pick flowers", Carry = "Flowers" },
				{ Spot = "Mabel", Text = "Bring the flowers to Old Mabel at the Town Gate.", Prompt = "Give the flowers" },
			},
			Reward = { Wishstones = 3, Items = { PetFood = 2 } },
		},
		{
			Id = "Offering", Name = "Feed the Beasts", Giver = "Warden",
			Line = "The beasts are restless. Bring them a roast boar from the tavern before they get ideas.",
			Blurb = "Warden Hale at the Boss Field wants an offering for the bosses.",
			Steps = {
				{ Spot = "Tavern", Text = "Fetch a roast boar from Greta at the Sleepy Griffin (Town Gate).", Prompt = "Take the roast boar", Carry = "Boar" },
				{ Spot = "Altar", Text = "Lay the boar on the offering stone at the Boss Field.", Prompt = "Make the offering" },
			},
			Reward = { Wishstones = 3, Items = { SkillWish = 1 } },
		},
		{
			Id = "Bones", Name = "Bones from the Deep", Giver = "Warden",
			Line = "The Colossus likes old bones. There's a pile by the Dungeon Gate - bring me a few.",
			Blurb = "Warden Hale needs bones from the Dungeon Gate for the beasts.",
			Steps = {
				{ Spot = "Bones", Text = "Gather bones by the Dungeon Gate, west of the Wishing Grove.", Prompt = "Gather bones", Carry = "Bones" },
				{ Spot = "Altar", Text = "Lay the bones on the offering stone at the Boss Field.", Prompt = "Offer the bones" },
			},
			Reward = { Wishstones = 4, Items = { SkillWish = 1 } },
		},
		{
			Id = "GuildAle", Name = "A Thirsty Guild", Giver = "Guildmaster",
			Line = "The guild has run dry! Fetch us a keg from the Sleepy Griffin.",
			Blurb = "Guildmaster Orin at the Training Grounds needs a keg of ale.",
			Steps = {
				{ Spot = "Tavern", Text = "Pick up a keg of ale from Greta at the Sleepy Griffin (Town Gate).", Prompt = "Take the keg", Carry = "Keg" },
				{ Spot = "Guildmaster", Text = "Carry the keg to Guildmaster Orin at the guild hall.", Prompt = "Deliver the keg" },
			},
			Reward = { Wishstones = 3, Items = { PetWish = 1 } },
		},
		{
			Id = "Supplies", Name = "Supplies for the Camp", Giver = "Guildmaster",
			Line = "Our scouts leave at dawn. Take a crate of supplies from the hall to the Expedition Camp.",
			Blurb = "Guildmaster Orin is sending supplies to the Expedition Camp.",
			Steps = {
				{ Spot = "Crates", Text = "Pick up a supply crate beside the Guild Hall.", Prompt = "Lift a crate", Carry = "Crate" },
				{ Spot = "CampDrop", Text = "Carry the crate to the Expedition Camp outside the town wall (south-east).", Prompt = "Drop off the crate" },
			},
			Reward = { Wishstones = 4, Items = { XPTonic = 1 } },
		},
		{
			Id = "Straw", Name = "Stuffing for the Dummies", Giver = "Sergeant",
			Line = "These dummies are losing their stuffing. Get me some straw from the hay pile by the pet park!",
			Blurb = "Sergeant Brask's training dummies need new straw.",
			Steps = {
				{ Spot = "Hay", Text = "Grab straw from the hay pile beside the pet park (Wishing Grove).", Prompt = "Grab straw", Carry = "Straw" },
				{ Spot = "Sergeant", Text = "Bring the straw to Sergeant Brask at the training dummies.", Prompt = "Hand over the straw" },
			},
			Reward = { Wishstones = 4 },
		},
		{
			Id = "Arrows", Name = "Stray Arrows", Giver = "Sergeant",
			Line = "Recruits! Arrows all over the range. Collect them by the archery targets, on the double!",
			Blurb = "Sergeant Brask wants the stray arrows collected.",
			Steps = {
				{ Spot = "Arrows", Text = "Collect the stray arrows by the archery targets (Training Grounds).", Prompt = "Collect arrows", Carry = "Arrows" },
				{ Spot = "Sergeant", Text = "Hand the arrows to Sergeant Brask.", Prompt = "Hand over the arrows" },
			},
			Reward = { Wishstones = 3, Items = { PetWish = 1 } },
		},
		{
			Id = "FreshCatch", Name = "Fresh Catch", Giver = "Tavern",
			Line = "Fish stew tonight, if someone fetches me a fish! The pond shallows are full of them.",
			Blurb = "Greta at the Sleepy Griffin needs a fish for her stew.",
			Steps = {
				{ Spot = "Shallows", Text = "Scoop a fish from the pond shallows in the Wishing Grove.", Prompt = "Scoop a fish", Carry = "Fish" },
				{ Spot = "Tavern", Text = "Bring the fish to Greta at the Sleepy Griffin.", Prompt = "Give Greta the fish" },
			},
			Reward = { Wishstones = 3, Items = { PetFood = 2 } },
		},
		{
			Id = "Water", Name = "Water for the Tree", Giver = "Elder",
			Line = "The Wishing Tree thirsts, child. Bring it water from the town well.",
			Blurb = "Elder Thessaly wants well water for the Wishing Tree.",
			Steps = {
				{ Spot = "Well", Text = "Fill a bucket at the well in the Town Gate square.", Prompt = "Fill the bucket", Carry = "Bucket" },
				{ Spot = "Elder", Text = "Bring the water to Elder Thessaly by the Wishing Tree.", Prompt = "Water the tree" },
			},
			Reward = { Wishstones = 5 },
		},
		{
			Id = "Delivery", Name = "Special Delivery", Giver = "Courier",
			Line = "Parcel for the Warden, and my feet are killing me. Would you run it out to the Boss Field?",
			Blurb = "Pip the Courier has a parcel for Warden Hale.",
			StartCarry = "Parcel",
			Steps = {
				{ Spot = "Warden", Text = "Deliver Pip's parcel to Warden Hale at the Boss Field.", Prompt = "Hand over the parcel" },
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
