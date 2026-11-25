--[[
	Bestiary (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Bestiary

	A monster book that fills in from kills (every monster a fight you are in kills counts, party fights and
	away fights too). Kill counts are PERMANENT: they carry over every season.

	  Tiers.Regular / Tiers.Boss   kills for tier 1..4 of one monster
	  Zone completion: every monster of a zone (its three and its boss) at tier ZoneTier -> the zone's Hunter title and
	  ZoneBonus; all at MasterTier -> the Master title and MasterBonus on top. Bonuses add up over zones, capped at Cap.
]]

return {
	Tiers = {
		Regular = { 25, 250, 2500, 25000 },
		Boss = { 1, 10, 50, 250 },
	},
	TierNames = { "Seen", "Hunted", "Trophy", "Mastered" },
	ZoneTier = 2,
	MasterTier = 4,
	ZoneBonus = { Attack = 0.005, MaxHealth = 0.005 }, -- per zone, Mode "Mul"
	MasterBonus = { Attack = 0.005, MaxHealth = 0.005 },
	Cap = 0.1, -- the most either stat can get from the bestiary
	-- the weekly hunt: one monster (picked from the week number) counts double
	WeeklyHunt = { Factor = 2 },
}
