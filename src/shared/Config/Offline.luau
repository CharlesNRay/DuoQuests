--[[
	Offline (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Offline

	How much a party earns while BOTH players are logged out. Offline farming is
	always reduced, and it never moves the frontier. There is no hard cap: the
	longer the party is away, the lower the rate gets, so a partner who plays
	less does not fall far behind. Starting values, adjust with data.
]]

return {
	-- Rate tiers by time away. `Until` is seconds since the party was last
	-- active; the last tier covers everything after it.
	Tiers = {
		{ Until = 12 * 3600, Rate = 0.5 }, -- the first 12 hours pay 50%
		{ Until = 24 * 3600, Rate = 0.3 },
		{ Until = 72 * 3600, Rate = 0.15 },
		{ Until = math.huge, Rate = 0.05 },
	},

	Intermission = 2, -- seconds between fights, the same pause the live loop uses
	MinAwaySeconds = 60, -- shorter gaps are ignored
	ProbeSeed = 7919, -- fixed seed for the "can the party clear this stage?" fight
}
