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
			Name = "Prototype Season",
			-- unix seconds; the season boss withers in the last stretch so it dies near EndsAt
			StartsAt = 1793491200, -- 2026-11-01 (placeholder: set real dates before launch)
			EndsAt = 1801440000, -- 2027-02-01
			-- Seasonal mechanic hooks get registered here in later phases
			-- (elements, relics, curses, partner bonds...).
			Mechanic = "None",
		},
	},

	Carry = {
		Stash = true, -- unused consumables (tonics, elixirs, pet food, wish tickets)
		BagUpgrades = true, -- bag size
		WishPity = true, -- progress towards a guaranteed Epic/Legendary wish
	},
}
