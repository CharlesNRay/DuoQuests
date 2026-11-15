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
			-- unix seconds; the season boss withers in the last stretch so it dies near EndsAt
			StartsAt = 1793491200, -- 2026-11-01
			EndsAt = 1801440000, -- 2027-02-01
			-- Seasonal mechanic hooks get registered here in later phases
			-- (elements, relics, curses, partner bonds...).
			Mechanic = "None",
		},
	},
}
