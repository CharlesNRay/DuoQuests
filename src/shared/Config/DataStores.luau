--[[
	DataStores (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > DataStores

	Every DataStore name starts with Prefix (player saves, parties, guilds, leaderboards, season results and
	histograms, the season boss, the playtest log). Changing it starts the game from nothing: every save, party,
	guild and board is new and the old ones are simply never read again (they are not deleted).

	LAUNCH (docs/RELEASE.md "Fresh start at launch", owner 2026-11-27: playtest progress does not carry into launch):
	change Prefix ONCE, e.g. to "IPQL_", right before the game goes public. NEVER change it after launch: that would
	wipe every player's progress.
]]
return {
	Prefix = "IPQ_",
}
