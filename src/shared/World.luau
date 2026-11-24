--[[
	World (ModuleScript)
	Location: ReplicatedStorage > Shared > World

	Where things are in the shared hub. Server and clients both use this, so an
	arena always appears in the same place for everyone. Pure math.

	Arenas (the battle lots, "player homes") are a 2 x 2 block south-east of the plaza:
	  slot 1 = first arena, slots are reused when a party leaves the server.

	  World.ArenaOrigin(slot)    -> x, y, z, yaw: the arena's centre on the ground and its turn (radians about Y; the
	                                arena's front, +Z in its own frame, where the camera and the sign are, faces the plaza)
	  World.HomesStreet()        -> x, z (where the street leaves the plaza), dx, dz (its direction), length
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
World.APRON_DEPTH = 12 -- the strip of extra ground behind a fight (was 24; the street only fits with 12)
-- The homes street (owner's pick 2026-11-24): a street from the plaza toward the south-east, lots on both sides with
-- their fronts (watch pad, owner sign, battle camera side) facing the street, so no lot is behind another and nobody
-- walks through a fight. Lots go in pairs (odd slots on the left, even on the right as you walk out); First = distance
-- from the plaza centre to the first pair, Spacing = pair to pair, Lateral = street centre line to a lot's centre.
-- Pairs 1-2 (slots 1-4) fit inside the wall; from pair 3 (slots 5-8, owner's pick 2026-11-24 for 8-player servers)
-- the street carries on through the Homes gate in the wall: OuterFirst = distance to the first pair outside it, so no lot
-- straddles the wall (Outside = the pair number from which lots stand outside).
World.HOMES_STREET = { Angle = 145, First = 162, Spacing = 72, Lateral = 39, Width = 12, Outside = 2, OuterFirst = 332 }

-- distance along the homes street from the plaza centre to lot pair `pair` (0-based)
local function pairAlong(pair)
	local s = World.HOMES_STREET
	if pair < s.Outside then
		return s.First + pair * s.Spacing
	end
	return s.OuterFirst + (pair - s.Outside) * s.Spacing
end

-- The plaza: a big circle in the middle with the fountain, the boards and the daily chest.
World.PLAZA = { X = 0, Z = 40, Radius = 70 }

local function polar(angle, radius)
	local a = math.rad(angle)
	return World.PLAZA.X + math.sin(a) * radius, World.PLAZA.Z - math.cos(a) * radius
end

function World.HomesStreet()
	local s = World.HOMES_STREET
	local a = math.rad(s.Angle)
	local dx, dz = math.sin(a), -math.cos(a)
	local x, z = polar(s.Angle, World.PLAZA.Radius - 1)
	local pairCount = math.ceil(World.MAX_LOTS / 2)
	local length = pairAlong(pairCount - 1) + World.ARENA_WIDTH / 2 + 8 - (World.PLAZA.Radius - 1)
	return x, z, dx, dz, length
end

function World.ArenaOrigin(slot)
	local s = World.HOMES_STREET
	local index = slot - 1
	local side = if index % 2 == 0 then -1 else 1 -- -1 = left of the street walking out, 1 = right
	local along = pairAlong(index // 2)
	local a = math.rad(s.Angle)
	local dx, dz = math.sin(a), -math.cos(a) -- along the street, away from the plaza
	local rx, rz = -dz, dx -- to the right of it
	local x = World.PLAZA.X + dx * along + rx * side * s.Lateral
	local z = World.PLAZA.Z + dz * along + rz * side * s.Lateral
	-- the lot's +Z (its front) points back across to the street: (sin yaw, cos yaw) = -side * right
	local yaw = math.atan2(-side * rx, -side * rz)
	return x, 0.5, z, yaw
end

World.MAX_LOTS = 8 -- lots always built and shown as "open". One lot per party (a party of up to 4 shares it).
-- Servers hold up to MAX_PLAYERS (Roblox Max Players, owner's pick 2026-11-24): if more than 8 parties are on one server
-- (many solo players), the 9th..16th get overflow lots further down the same street, built only while in use
-- (Hub.SetLots draws the road on to them; WorldService lays the ground strip for them).
World.MAX_PLAYERS = 16
World.LOT_LIMIT = World.MAX_PLAYERS -- every player solo = one lot each

-- the ground strip outside the Homes gate under lots 5..LOT_LIMIT: centre x, z, yaw, length (along the street), width
function World.OuterGround()
	local s = World.HOMES_STREET
	local from = s.OuterFirst - World.ARENA_WIDTH / 2 - 10
	local to = pairAlong(math.ceil(World.LOT_LIMIT / 2) - 1) + World.ARENA_WIDTH / 2 + 20
	local a = math.rad(s.Angle)
	local dx, dz = math.sin(a), -math.cos(a)
	local mid = (from + to) / 2
	local width = 2 * (s.Lateral + World.ARENA_DEPTH / 2 + World.APRON_DEPTH + 20)
	return World.PLAZA.X + dx * mid, World.PLAZA.Z + dz * mid, math.atan2(dx, dz), to - from, width
end
World.SHOP_RANGE = 30 -- studs from a shop within which buying/selling/upgrading is allowed

-- Shops and boards. The boards and the daily chest: an angle and a distance from the plaza centre. The shops stand in a
-- ring round the Market square (east), facing its middle: Market = angle round the square, 0 = the side toward the
-- plaza (where the road comes in), clockwise seen from above; the gaps at 0 and 180 are the ways in.
World.MARKET_RING = 34 -- studs from the middle of the Market square to a stall
World.PlazaSpots = {
	Merchant = { Market = 40 },
	PetStore = { Market = 90 }, -- eggs, pet gear crates and pet food
	Trainer = { Market = 140 }, -- the Skill Trainer levels your skill slots
	Blacksmith = { Market = 220 },
	RuneCarver = { Market = 270 }, -- carves runes onto gear, sells rune pouches
	Store = { Market = 320 }, -- the Store (Sunstones, packs, cosmetics); not distance-checked
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
		{ Angle = 180, Width = 26, Name = "IDLE PARTY TOWN", Main = true },
		{ Angle = 38, Width = 18, Name = "TO THE GIANT BOSSES" },
		{ Angle = 112, Width = 44, Hill = true }, -- the Dungeon's hill
		{ Angle = 145, Width = 22, Name = "PLAYER HOMES" }, -- the homes street goes on to lots 5-8 (World.HOMES_STREET)
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

-- a point (lx, lz) in a district's frame (as TownSpots: -Z toward the plaza, +X to the right facing the plaza) -> world
function World.DistrictToWorld(id, lx, lz)
	local px, pz = World.DistrictPoint(id)
	local fx, fz = World.PLAZA.X - px, World.PLAZA.Z - pz
	local len = math.sqrt(fx * fx + fz * fz)
	fx, fz = fx / len, fz / len
	return px - fz * lx - fx * lz, pz + fx * lx - fz * lz
end

-- where a shop / board stands
function World.PlazaPoint(name)
	local spot = World.PlazaSpots[name]
	if spot.Market then
		local a = math.rad(spot.Market)
		return World.DistrictToWorld("Market", math.sin(a) * World.MARKET_RING, -math.cos(a) * World.MARKET_RING)
	end
	local a = math.rad(spot.Angle)
	return World.PLAZA.X + math.sin(a) * spot.Radius, World.PLAZA.Z - math.cos(a) * spot.Radius
end

-- the point a shop / board faces: the middle of the Market square for the stalls, the plaza centre for the rest
function World.ShopLook(name)
	local spot = World.PlazaSpots[name]
	if spot and spot.Market then
		return World.DistrictPoint("Market")
	end
	return World.PLAZA.X, World.PLAZA.Z
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
