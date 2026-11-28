--[[
	Seasons (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Seasons

	The season schedule. The current season is the newest one whose StartsAt has passed (Shared/SeasonClock), so a new
	season starts on its date on every server without republishing: add the next season here ahead of time and publish
	whenever. Keep seasons back to back (next StartsAt = previous EndsAt); a gap is an off-season where nothing scores.

	When a season starts, a player's season data (level, gear, skills, currencies, frontier, talents...) is replaced on
	their next join by fresh data (Shared/SeasonRollover); everything under Permanent stays (pets and their levels,
	passes, Sunstones, cosmetics, titles, bestiary, mastery, guild, characters' classes). Players online at the switch
	are asked to rejoin. Finished seasons' rewards are claimed on the Season screen.

	NEVER change a season's Id once it has started (leaderboards and DataStores are keyed by it).

	Carry: what a character keeps from its old season (unused items are often paid for: Starter Pack items, bag upgrades).
]]

return {
	Seasons = {
		[1] = {
			Id = 1,
			Name = "Unbroken",
			-- unix seconds; the season boss withers in the last stretch so it dies near EndsAt
			StartsAt = 1793491200, -- 2026-11-01 (placeholder: set real dates before launch)
			EndsAt = 1801440000, -- 2027-02-01
			-- The season's own mechanic (docs/SEASONS.md): "Bonds" (Config/Bonds) or "None".
			Mechanic = "Bonds",
			-- the season boss for this season (Bosses.SeasonCfg puts it over Config/Bosses Season): the giant who breaks
			-- every bond, with broken shackles, snapped chains and violet cracks
			Boss = {
				Name = "The Oathbreaker", DefId = "Oathbreaker",
				Look = { Color = { 70, 64, 96 }, Height = 90, EyeColor = { 190, 110, 255 }, Cracks = true, Chains = true, Material = "Basalt" },
			},
			-- this season's own prize on top of the usual rewards: the Kindred aura for everyone in the Top 20%
			Prize = { Cosmetic = "Aura_Kindred", Top = 0.2 },
		},
	},

	-- Seasons built but not scheduled: the real calendar never starts these. Studio's "Start next season" cheat
	-- (SeasonClock.StartNext) runs the draft with the next id, so a draft can be tried before the owner picks it.
	-- To schedule one, move it into Seasons above with real dates.
	Drafts = {
		[2] = {
			Id = 2,
			Name = "Tidebreak",
			StartsAt = 1801440000, -- placeholder (season 1's EndsAt)
			EndsAt = 1803859200, -- placeholder (4 weeks later)
			-- every week one element rises (Config/Tides): its zones are tougher and pay double gold, one class is in
			-- the spotlight
			Mechanic = "Tides",
			Boss = {
				Name = "The Maelstrom", DefId = "Maelstrom",
				Look = {
					Color = { 50, 90, 140 }, Height = 90, EyeColor = { 120, 220, 255 }, Cracks = true, Material = "Glacier",
					Orbs = { { 255, 110, 40 }, { 120, 190, 255 }, { 220, 240, 255 }, { 170, 70, 255 } }, -- fire, storm, frost, void
				},
			},
			Prize = { Cosmetic = "Aura_Tidebound", Top = 0.2 },
		},
	},

	Carry = {
		Stash = true, -- unused consumables (tonics, elixirs, pet food, wish tickets)
		BagUpgrades = true, -- bag size
		WishPity = true, -- progress towards a guaranteed Epic/Legendary wish
	},
}
