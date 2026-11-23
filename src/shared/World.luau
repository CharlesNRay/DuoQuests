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
World.MAX_LOTS = 8 -- was 12; one lot per party, so a full server (set Max Players to 8) never needs more
World.SHOP_RANGE = 30 -- studs from a shop within which buying/selling/upgrading is allowed

-- Props on the plaza ring. Angle 0 = north (towards the lots), going clockwise; Radius from the centre.
World.PlazaSpots = {
	-- vendors spread around the ring (2026-11-23; they were bunched at the north end), the road to the lots stays clear
	Merchant = { Angle = -62, Radius = 54 },
	Blacksmith = { Angle = 62, Radius = 54 },
	PetStore = { Angle = -28, Radius = 56 }, -- eggs, pet gear crates and pet food
	Trainer = { Angle = 28, Radius = 56 }, -- the Skill Trainer levels your skill slots
	RuneCarver = { Angle = -128, Radius = 54 }, -- carves runes onto gear, sells rune pouches
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
World.BossField = { X = 0, Z = 320, Radius = 60 } -- its north edge (z 260) stays clear of the town wall (z ~232)
World.BossSpots = {
	World = { X = -40, Z = 312 }, -- the roaming world boss (26 studs tall)
	Season = { X = 38, Z = 335 }, -- the season Colossus on its altar (90 studs tall, altar 34 wide)
}

function World.DistrictPoint(id)
	local d = World.Districts[id]
	local a = math.rad(d.Angle)
	return World.PLAZA.X + math.sin(a) * d.Radius, World.PLAZA.Z - math.cos(a) * d.Radius
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
