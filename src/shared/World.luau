--[[
	World (ModuleScript)
	Location: ReplicatedStorage > Shared > World

	Where things are in the shared hub. Server and clients both use this, so an
	arena always appears in the same place for everyone. Pure math.

	Arenas (the battle lots, "player homes") are a 2 x 2 block south-east of the plaza:
	  slot 1 = first arena, slots are reused when a party leaves the server.

	  World.ArenaOrigin(slot)    -> x, y, z of the arena's centre on the ground
	  World.SpawnPosition()      -> x, y, z where players arrive (on the plaza)
	  World.PLAZA, World.PlazaSpots, World.PlazaPoint(name), World.NearShop(x, z, name)
	  World.ARENA_WIDTH / ARENA_DEPTH   size of one arena pad in studs
	  World.Districts, World.DistrictPoint(id), World.TOWN_RING   the town districts around the plaza
	  World.BossField, World.BossSpots                            where the world boss and the season Colossus stand
	  World.TownSpots, World.TownSpot(id), World.NearSpot(x, z, id)   errand NPCs and pick-up spots in the town
]]

local World = {}

-- 2026-11-23 relayout to the owner's blueprint: a walled town with the plaza in the middle, the Guild at the north
-- wall, Old Town (housing) NW, the Wishing Grove NE, the Pet Area W, the Market E, the Combat Arena SW and the
-- battle lots ("player homes") in a block SE; the Dungeon is built into the east wall, the Giant Bosses stand outside
-- the NE gate, the main gate is south and the Expedition Camp is outside it. Angles: 0 = north (-Z), clockwise.
World.ARENA_WIDTH = 64
World.ARENA_DEPTH = 50 -- deep enough for four heroes, their pets and summons between the trees and the front decor
World.LOT_COLUMNS = 2
World.SPACING_X = 76 -- lot centre to lot centre (12 studs between pads)
World.SPACING_Z = 62
World.LOT_BLOCK = { Angle = 135, Radius = 185 } -- the middle of the 2 x 2 block of lots

-- The plaza: a big circle in the middle with the fountain, the boards and the daily chest.
World.PLAZA = { X = 0, Z = 40, Radius = 70 }

local function polar(angle, radius)
	local a = math.rad(angle)
	return World.PLAZA.X + math.sin(a) * radius, World.PLAZA.Z - math.cos(a) * radius
end

function World.ArenaOrigin(slot)
	local index = slot - 1
	local col = index % World.LOT_COLUMNS
	local row = index // World.LOT_COLUMNS
	local cx, cz = polar(World.LOT_BLOCK.Angle, World.LOT_BLOCK.Radius)
	-- slots 5+ (a busy server) carry on in rows to the south of the block
	return cx + (col - (World.LOT_COLUMNS - 1) / 2) * World.SPACING_X, 0.5, cz + (row - 0.5) * World.SPACING_Z
end

World.MAX_LOTS = 4 -- lots built and shown as "open". One lot per party; a 5th party still gets slot 5 (the next row).
World.SHOP_RANGE = 30 -- studs from a shop within which buying/selling/upgrading is allowed

-- Shops and boards, as an angle and a distance from the plaza centre. The shops stand in an arc in the Market (east),
-- facing the plaza; the boards and the daily chest stay on the plaza.
World.PlazaSpots = {
	Merchant = { Angle = 70, Radius = 150 },
	PetStore = { Angle = 78, Radius = 150 }, -- eggs, pet gear crates and pet food
	Trainer = { Angle = 86, Radius = 150 }, -- the Skill Trainer levels your skill slots
	Blacksmith = { Angle = 94, Radius = 150 },
	RuneCarver = { Angle = 102, Radius = 150 }, -- carves runes onto gear, sells rune pouches
	Store = { Angle = 110, Radius = 150 }, -- the Store (Sunstones, packs, cosmetics); not distance-checked
	Map = { Angle = -68, Radius = 55 },
	Rankings = { Angle = 68, Radius = 55 },
	Season = { Angle = 112, Radius = 55 }, -- the season rewards board
	Daily = { Angle = 158, Radius = 52 },
	Tree = { Angle = 45, Radius = 165 }, -- the heart of the Wishing Grove (north-east)
}

-- The districts. Size = radius of the district's ground. Each has a spoke road from the plaza.
World.TOWN_RING = 220 -- the town's districts all lie within this distance of the plaza centre
World.Districts = {
	Guild = { Name = "Guild Hall", Angle = 0, Radius = 175, Size = 52 }, -- the guild castle, Orin, the guild board
	Housing = { Name = "Old Town", Angle = -45, Radius = 165, Size = 50 }, -- the tavern, Old Mabel, the well, the notice board, Pip
	Grove = { Name = "Wishing Grove", Angle = 45, Radius = 165, Size = 52 }, -- the Wishing Tree, Elder Thessaly
	PetArea = { Name = "Pet Area", Angle = -90, Radius = 160, Size = 50 }, -- the pet park, the fishing pond, the hay pile
	Market = { Name = "Market", Angle = 90, Radius = 150, Size = 58 }, -- the shop stalls
	Training = { Name = "Combat Arena", Angle = -135, Radius = 165, Size = 52 }, -- the sparring ring, training dummies
}
World.DistrictOrder = { "Guild", "Grove", "Market", "Training", "PetArea", "Housing" }

-- The Giant Bosses: a field outside the north-east gate where the world boss and the season Colossus stand.
World.BossField = { X = 237, Z = -263, Radius = 55 }
World.BossSpots = {
	World = { X = 210, Z = -262 }, -- the roaming world boss (26 studs tall)
	Season = { X = 258, Z = -280 }, -- the season Colossus on its altar (90 studs tall, altar 34 wide)
}

-- The town wall: a ring round everything that is the town, with the main gate to the south, a gate to the Giant
-- Bosses (north-east), and the Dungeon built into the east wall (a rocky hill where the wall would be).
World.TOWN_WALL = {
	Radius = 290,
	Gates = {
		{ Angle = 180, Width = 26, Name = "DUO QUEST TOWN", Main = true },
		{ Angle = 38, Width = 18, Name = "TO THE GIANT BOSSES" },
		{ Angle = 112, Width = 44, Hill = true }, -- the Dungeon's hill
	},
}

-- Errand NPCs, pick-up spots and places in the town (Shared/Errands, TownLeisure, the activities).
-- District = (X, Z) in that district's frame (-Z points at the plaza, +X to the right as you face the plaza from the
-- district); no District = world X, Z. Cat1..CatN are where a lost cat can hide.
World.TownSpots = {
	-- Old Town
	Mabel = { District = "Housing", X = -18, Z = 17 }, -- Old Mabel, by her cottage
	Tavern = { District = "Housing", X = 15, Z = 4 }, -- Greta the barkeep at the Sleepy Griffin
	Board = { District = "Housing", X = -14, Z = -28 }, -- the notice board by the road in (opens the errand list)
	Courier = { District = "Housing", X = 10, Z = -26 }, -- Pip the Courier
	Well = { District = "Housing", X = 4.5, Z = 0 }, -- the town well
	-- Wishing Grove
	Elder = { District = "Grove", X = -8, Z = -24 }, -- Elder Thessaly, in front of the Wishing Tree
	Flowers = { District = "Grove", X = 14, Z = -30 }, -- the flower bed inside the Grove arch
	-- Pet Area
	Pond = { District = "PetArea", X = -18, Z = -6 }, -- the fishing dock
	Shallows = { District = "PetArea", X = -18, Z = 19 }, -- the far edge of the fishing pond
	PetPark = { District = "PetArea", X = 13, Z = 2 }, -- the ball in the pet park
	Hay = { District = "PetArea", X = 4, Z = 26 }, -- the hay pile behind the pet park
	-- Guild Hall
	Guildmaster = { District = "Guild", X = 8, Z = 2 }, -- Guildmaster Orin at the castle door
	GuildBoard = { District = "Guild", X = -14, Z = 2 }, -- the guild board on the other side of the door
	Crates = { District = "Guild", X = 28, Z = -4 }, -- supply crates beside the castle
	-- Combat Arena
	Ring = { District = "Training", X = 0, Z = 8 }, -- the sparring ring
	Dummy = { District = "Training", X = 0, Z = -24 }, -- the middle training dummy ("test your build")
	Sergeant = { District = "Training", X = 18, Z = -22 }, -- at the end of the row of training dummies
	Arrows = { District = "Training", X = 12, Z = 34 }, -- stray arrows by the archery targets
	-- outside the walls and at the gates
	Warden = { X = 212, Z = -231 }, -- the Beast Warden, at the edge of the Giant Bosses field
	Altar = { X = 223, Z = -246 }, -- the offering stone on the field
	DungeonGate = { X = 243, Z = 138 }, -- the Dungeon, built into the east wall
	Bones = { X = 229, Z = 129 }, -- a bone pile in front of the Dungeon
	ExpeditionCamp = { X = -148, Z = 357 }, -- outside the main gate, south-west
	CampDrop = { X = -150, Z = 370 }, -- the camp's stores
	-- hidden relics (Shared/TownLeisure)
	Relic1 = { District = "Grove", X = 6, Z = 44 }, -- behind the Wishing Tree
	Relic2 = { District = "PetArea", X = 24, Z = -2 }, -- by the doghouse in the pet park
	Relic3 = { District = "Housing", X = 37, Z = 17 }, -- behind the Sleepy Griffin
	Relic4 = { District = "Housing", X = -14, Z = 36 }, -- behind Old Mabel's garden
	Relic5 = { District = "Training", X = -32, Z = 20 }, -- beside the sparring ring
	Relic6 = { District = "Guild", X = 30, Z = 24 }, -- behind the guild castle
	Relic7 = { X = 217, Z = -283 }, -- among the rocks of the Giant Bosses field
	Relic8 = { X = 236, Z = 160 }, -- beside the Dungeon's hill
	Relic9 = { X = -132, Z = 348 }, -- at the Expedition Camp
	Relic10 = { X = -14, Z = 262 }, -- by the main gate
	-- where a lost cat can hide (Config/Errands CatHints says which)
	Cat1 = { District = "PetArea", X = -34, Z = 22 }, -- past the fishing pond
	Cat2 = { District = "Training", X = -22, Z = 30 }, -- behind the sparring ring
	Cat3 = { District = "Housing", X = 0, Z = -6 }, -- by the well
	Cat4 = { X = 14, Z = 200 }, -- under a tree by the road to the main gate
	Cat5 = { District = "PetArea", X = 20, Z = 8 }, -- in the pet park
}
World.SPOT_RANGE = 16 -- studs; the prompts are 14 wide

function World.DistrictPoint(id)
	local d = World.Districts[id]
	local a = math.rad(d.Angle)
	return World.PLAZA.X + math.sin(a) * d.Radius, World.PLAZA.Z - math.cos(a) * d.Radius
end

function World.TownSpot(id)
	local spot = World.TownSpots[id]
	if not spot then
		return nil
	end
	if not spot.District then
		return spot.X, spot.Z
	end
	-- same frame as CFrame.lookAt(district point, plaza centre): forward f, right = (-f.z, f.x), local +Z = -f
	local px, pz = World.DistrictPoint(spot.District)
	local fx, fz = World.PLAZA.X - px, World.PLAZA.Z - pz
	local len = math.sqrt(fx * fx + fz * fz)
	fx, fz = fx / len, fz / len
	return px - fz * spot.X - fx * spot.Z, pz + fx * spot.X - fz * spot.Z
end

function World.NearSpot(x, z, id)
	local sx, sz = World.TownSpot(id)
	return sx ~= nil and (x - sx) ^ 2 + (z - sz) ^ 2 <= World.SPOT_RANGE ^ 2
end

function World.PlazaPoint(name)
	local spot = World.PlazaSpots[name]
	local a = math.rad(spot.Angle)
	return World.PLAZA.X + math.sin(a) * spot.Radius, World.PLAZA.Z - math.cos(a) * spot.Radius
end

-- Is a world position within range of a shop ("Merchant" | "Blacksmith" | "Trainer" | "PetStore" | "RuneCarver" | "Tree")?
function World.NearShop(x, z, name)
	local sx, sz = World.PlazaPoint(name)
	return (x - sx) ^ 2 + (z - sz) ^ 2 <= World.SHOP_RANGE ^ 2
end

function World.SpawnPosition()
	return World.PLAZA.X, 3, World.PLAZA.Z + 38
end

return World
