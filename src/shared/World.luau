--[[
	World (ModuleScript)
	Location: ReplicatedStorage > Shared > World

	Where things are in the shared hub. Server and clients both use this, so an
	arena always appears in the same place for everyone. Pure math.

	Arenas are laid out in rows of PER_ROW, in front of the spawn:
	  slot 1 = first arena, slots are reused when a party leaves the server.

	  World.ArenaOrigin(slot)    -> x, y, z of the arena's centre on the ground
	  World.SpawnPosition()      -> x, y, z where players arrive
	  World.ARENA_WIDTH / ARENA_DEPTH   size of one arena pad in studs
]]

local World = {}

World.PER_ROW = 4
World.ARENA_WIDTH = 64
World.ARENA_DEPTH = 42
World.SPACING_X = 84
World.SPACING_Z = 70
World.FIRST_ROW_Z = -55

function World.ArenaOrigin(slot)
	local index = slot - 1
	local col = index % World.PER_ROW
	local row = index // World.PER_ROW
	local x = (col - (World.PER_ROW - 1) / 2) * World.SPACING_X
	return x, 0.5, World.FIRST_ROW_Z - row * World.SPACING_Z
end

function World.SpawnPosition()
	return 0, 3, 20
end

return World
