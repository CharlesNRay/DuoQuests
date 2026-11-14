--[[
	Seasons (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Seasons

	CurrentSeasonId decides which season new data belongs to.
	Later this value moves to a DataStore/MemoryStore key so a season can be
	flipped without republishing the game.
]]

return {
	CurrentSeasonId = 1,

	Seasons = {
		[1] = {
			Id = 1,
			Name = "Prototype Season",
			-- Seasonal mechanic hooks get registered here in later phases
			-- (elements, relics, curses, partner bonds...).
			Mechanic = "None",
		},
	},
}
