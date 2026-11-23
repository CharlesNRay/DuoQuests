--[[
	World (ModuleScript)
	Location: ReplicatedStorage > Shared > World

	Where things are in the shared hub. Server and clients both use this, so an
	arena always appears in the same place for everyone. Pure math.

	Arenas are laid out in rows of PER_ROW, in front of the spawn:
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

World.PER_ROW = 4
World.ARENA_WIDTH = 64
World.ARENA_DEPTH = 50 -- was 42; deeper so four heroes, their pets and summons fit between the trees and the front decor
World.SPACING_X = 100 -- was 84 (2026-11-23: lots were too close together for a busy server)
World.SPACING_Z = 92 -- was 76
World.FIRST_ROW_Z = -95

function World.ArenaOrigin(slot)
	local index = slot - 1
	local col = index % World.PER_ROW
	local row = index // World.PER_ROW
	local x = (col - (World.PER_ROW - 1) / 2) * World.SPACING_X
	return x, 0.5, World.FIRST_ROW_Z - row * World.SPACING_Z
end

-- The plaza: a big circle in the middle with the shops, boards and the daily chest.
-- Player lots (arenas) are in rows north of it. Everything is placed from here so the
-- server (shop distance checks) and the clients (building it) agree.
World.PLAZA = { X = 0, Z = 40, Radius = 70 }
World.MAX_LOTS = 4 -- lots built and shown as "open" (2026-11-23: was 8, the back row went). One lot per party;
-- a 5th party on the server still gets a lot (slot 5+ lands in the next row back), it just is not shown until then.
World.SHOP_RANGE = 30 -- studs from a shop within which buying/selling/upgrading is allowed

-- Props on the plaza ring. Angle 0 = north (towards the lots), going clockwise; Radius from the centre.
World.PlazaSpots = {
	-- vendors spread around the ring (2026-11-23; they were bunched at the north end), the road to the lots stays clear
	Merchant = { Angle = -62, Radius = 54 },
	Blacksmith = { Angle = 62, Radius = 54 },
	PetStore = { Angle = -28, Radius = 56 }, -- eggs, pet gear crates and pet food
	Trainer = { Angle = 28, Radius = 56 }, -- the Skill Trainer levels your skill slots
	RuneCarver = { Angle = -128, Radius = 54 }, -- carves runes onto gear, sells rune pouches
	Store = { Angle = -154, Radius = 54 }, -- the Store (Sunstones, packs, cosmetics); not distance-checked
	Map = { Angle = -100, Radius = 55 },
	Rankings = { Angle = 100, Radius = 55 },
	Season = { Angle = 126, Radius = 55 }, -- the season rewards board, next to the leaderboards
	Daily = { Angle = 150, Radius = 52 },
	Tree = { Angle = -90, Radius = 150 }, -- the heart of the Wishing Grove district (west); was out on the grass at -150 / 100
}

-- Town districts around the plaza (2026-11-23, docs/TOWN.md). A ring road (radius TOWN_RING) runs from the Grove (west)
-- through the Gate (south) to the Training Grounds (east); the north side is the lots. Size = radius of the district's ground.
World.TOWN_RING = 150
World.Districts = {
	Grove = { Name = "Wishing Grove", Angle = -90, Radius = 150, Size = 56 }, -- Wishing Tree, fishing pond, pet park
	Gate = { Name = "Town Gate", Angle = 180, Radius = 150, Size = 46 }, -- notice board, tavern, the town walls
	Training = { Name = "Training Grounds", Angle = 90, Radius = 150, Size = 52 }, -- training dummies, sparring ring, guild hall
}
World.DistrictOrder = { "Grove", "Gate", "Training" }

-- The Boss Field: open ground outside the Town Gate (south) where the world boss and the season Colossus stand.
-- (Until 2026-11-23 they stood at (105, 150) and (0, 190): on the ring road and in the middle of the new Town Gate.)
World.BossField = { X = 0, Z = 365, Radius = 55 } -- outside the town wall's main gate (the wall is at z 302 there)
World.BossSpots = {
	World = { X = -36, Z = 372 }, -- the roaming world boss (26 studs tall)
	Season = { X = 36, Z = 382 }, -- the season Colossus on its altar (90 studs tall, altar 34 wide)
}

-- The town wall (2026-11-23, owner: "the castle walls should encompass the entire town"): a ring round the plaza,
-- the districts and the lots, with the main gate to the south (to the Boss Field) and small gates where the roads
-- leave for the Dungeon Gate (west) and the Expedition Camp (south-east). Angle as for PlazaSpots (0 = north).
World.TOWN_WALL = {
	Radius = 262,
	Gates = {
		{ Angle = 180, Width = 26, Name = "DUO QUEST TOWN", Main = true },
		{ Angle = -90, Width = 16, Name = "TO THE DUNGEONS" },
		{ Angle = 150, Width = 16, Name = "TO THE EXPEDITION CAMP" },
	},
}

-- Town errand spots (docs/TOWN.md phase 2, Shared/Errands): where the errand NPCs stand and the things you pick up.
-- District = the spot is (X, Z) in that district's frame (-Z points at the plaza, +X to the right as you face the plaza
-- from the district); no District = world X, Z. Cat1..CatN are where a lost cat can hide.
World.TownSpots = {
	Mabel = { District = "Gate", X = -18, Z = 17 }, -- Old Mabel, by her cottage
	Tavern = { District = "Gate", X = 15, Z = 4 }, -- the barkeep at the Sleepy Griffin
	Board = { District = "Gate", X = -14, Z = -28 }, -- the notice board by the road into the square (opens the errand list)
	Elder = { District = "Grove", X = -8, Z = -24 }, -- Elder Thessaly, in front of the Wishing Tree
	Courier = { District = "Gate", X = 10, Z = -26 }, -- Pip the Courier, by the road into the square
	Flowers = { District = "Grove", X = 14, Z = -30 }, -- the flower bed inside the Grove arch
	Shallows = { District = "Grove", X = -36, Z = 26 }, -- the far edge of the fishing pond
	Well = { District = "Gate", X = 4.5, Z = 0 }, -- the town well
	Crates = { District = "Training", X = 36, Z = 6 }, -- supply crates beside the Guild Hall
	Arrows = { District = "Training", X = 12, Z = 32 }, -- stray arrows by the archery targets
	Sergeant = { District = "Training", X = 18, Z = -20 }, -- at the end of the row of training dummies
	Guildmaster = { District = "Training", X = 14, Z = 11 }, -- at the guild hall door
	Hay = { District = "Grove", X = 19, Z = 20 }, -- hay pile beside the pet park
	Warden = { X = -12, Z = 322 }, -- the Beast Warden, just inside the Boss Field arch
	Altar = { X = 0, Z = 340 }, -- the offering stone on the Boss Field
	-- places that open a screen (not errands)
	Dummy = { District = "Training", X = 0, Z = -22 }, -- the middle training dummy ("test your build")
	Pond = { District = "Grove", X = -34, Z = 2 }, -- the fishing dock
	PetPark = { District = "Grove", X = 31, Z = 14 }, -- the ball in the pet park
	-- hidden relics (Shared/TownLeisure): tucked behind buildings, under trees, out on the fields
	Relic1 = { District = "Grove", X = 6, Z = 44 }, -- behind the Wishing Tree
	Relic2 = { District = "Grove", X = 41, Z = 23 }, -- by the doghouse in the pet park
	Relic3 = { District = "Gate", X = 37, Z = 17 }, -- behind the Sleepy Griffin
	Relic4 = { District = "Gate", X = -14, Z = 36 }, -- by the town wall behind Old Mabel's garden
	Relic5 = { District = "Training", X = -34, Z = -2 }, -- under the sparring ring corner
	Relic6 = { District = "Training", X = 34, Z = 32 }, -- behind the Guild Hall
	Relic7 = { X = -40, Z = 340 }, -- among the rocks of the Boss Field
	Relic8 = { X = -280, Z = 64 }, -- by the Dungeon Gate hill
	Relic9 = { X = 132, Z = 312 }, -- at the Expedition Camp
	Relic10 = { X = -99, Z = 139 }, -- under a tree on the road between the Grove and the Gate
	DungeonGate = { X = -310, Z = 40 }, -- outside the town wall, west of the Wishing Grove
	ExpeditionCamp = { X = 150, Z = 300 }, -- outside the town wall, south-east
	Bones = { X = -292, Z = 30 }, -- a bone pile in front of the Dungeon Gate
	CampDrop = { X = 161, Z = 296 }, -- the camp's stores
	GuildBoard = { District = "Training", X = 6, Z = 24 }, -- beside the Guild Hall, the other side from Guildmaster Orin
	Cat1 = { District = "Grove", X = -22, Z = 30 }, -- past the fishing pond
	Cat2 = { District = "Training", X = -36, Z = 22 }, -- behind the sparring ring
	Cat3 = { District = "Gate", X = 0, Z = -6 }, -- by the well
	Cat4 = { X = 90, Z = 147 }, -- under a tree on the ring road, south-east
	Cat5 = { District = "Grove", X = 38, Z = 20 }, -- inside the pet park
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
