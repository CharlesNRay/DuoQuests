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
]]

local World = {}

World.PER_ROW = 4
World.ARENA_WIDTH = 64
World.ARENA_DEPTH = 42
World.SPACING_X = 84
World.SPACING_Z = 76
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
World.MAX_LOTS = 12
World.SHOP_RANGE = 30 -- studs from a shop within which buying/selling/upgrading is allowed

-- Props on the plaza ring. Angle 0 = north (towards the lots), going clockwise; Radius from the centre.
World.PlazaSpots = {
	Merchant = { Angle = -38, Radius = 52 },
	Blacksmith = { Angle = 38, Radius = 52 },
	Map = { Angle = -100, Radius = 55 },
	Rankings = { Angle = 100, Radius = 55 },
	Daily = { Angle = 150, Radius = 52 },
	Tree = { Angle = -150, Radius = 100 }, -- out on the grass beyond the paving (plaza radius 70, rim 71.5)
}

function World.PlazaPoint(name)
	local spot = World.PlazaSpots[name]
	local a = math.rad(spot.Angle)
	return World.PLAZA.X + math.sin(a) * spot.Radius, World.PLAZA.Z - math.cos(a) * spot.Radius
end

-- Is a world position within range of a shop ("Merchant" | "Blacksmith" | "Tree")?
function World.NearShop(x, z, name)
	local sx, sz = World.PlazaPoint(name)
	return (x - sx) ^ 2 + (z - sz) ^ 2 <= World.SHOP_RANGE ^ 2
end

function World.SpawnPosition()
	return World.PLAZA.X, 3, World.PLAZA.Z + 38
end

return World
