--[[
	Config/Fishing: the fishing pond in the Wishing Grove (docs/TOWN.md phase 3).

	Cast, wait for the bite (WaitMin..WaitMax seconds), reel within Window seconds. A catch is rolled from Fish by
	Weight. The first DailyRewarded catches each day pay their Reward (pet food mostly: fishing feeds your pet); after
	that the pond is just for fun (and the fish log). Rewards stay small (docs/TOWN.md: town income <= ~10%).
]]
return {
	WaitMin = 2,
	WaitMax = 6,
	Window = 1.4, -- seconds after the bite to reel in
	Grace = 0.6, -- extra slack for the round trip to the server
	DailyRewarded = 12,
	Fish = {
		{ Id = "Minnow", Name = "Minnow", Glyph = "🐟", Weight = 40, Reward = { Items = { PetFood = 1 } } },
		{ Id = "Perch", Name = "Golden Perch", Glyph = "🐠", Weight = 25, Reward = { Items = { PetFood = 2 } } },
		{ Id = "Crab", Name = "Pond Crab", Glyph = "🦀", Weight = 14, Reward = { Items = { PetFood = 2 } } },
		{ Id = "Puffer", Name = "Puffer", Glyph = "🐡", Weight = 9, Reward = { Wishstones = 1 } },
		{ Id = "Squid", Name = "Grove Squid", Glyph = "🦑", Weight = 4, Reward = { Items = { GrandPetFood = 1 } } },
		{ Id = "Boot", Name = "Old Boot", Glyph = "👢", Weight = 8, Reward = {} },
	},
}
