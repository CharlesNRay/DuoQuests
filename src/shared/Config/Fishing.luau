--[[
	Config/Fishing: the fishing pond in the Wishing Grove (docs/TOWN.md phase 3).

	Cast, wait for the bite (WaitMin..WaitMax seconds); then a skill check: a needle sweeps round a dial (Speed degrees a
	second, from the top) and you press REEL while it is inside the gold zone (ZoneWidth degrees, placed at random). After
	Laps turns without a press the fish gets away. A catch is rolled from Fish by
	Weight. The first DailyRewarded catches each day pay their Reward (pet food mostly: fishing feeds your pet); after
	that the pond is just for fun (and the fish log). Rewards stay small (docs/TOWN.md: town income <= ~10%).
]]
return {
	WaitMin = 2,
	WaitMax = 6,
	Speed = 220, -- needle, degrees a second
	ZoneWidth = 70, -- degrees of the gold zone ("relatively easy")
	Laps = 2, -- turns before the fish gets away
	Tolerance = 8, -- extra degrees each side of the zone, for frame timing
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
