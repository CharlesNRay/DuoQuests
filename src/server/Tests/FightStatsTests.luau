--[[
	FightStatsTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > FightStatsTests

	The damage meter splits hero, pet and minion damage.   require(...FightStatsTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { FightStats = require(Shared.FightStats) }
	end
	local FightStats = m.FightStats
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			(warn or print)("  FAIL  " .. name)
		end
	end
	print("FightStatsTests")

	local fight = {
		Duration = 10,
		Roster = {
			{ Id = "1", Name = "Ann", Team = "Party", PetId = "Foxling" },
			{ Id = "2", Name = "Bob", Team = "Party" },
			{ Id = "e1", Name = "Rat", Team = "Enemy" },
		},
		Events = {
			{ T = 1, Type = "Spawn", Source = "2", Entity = { Id = "m1", Name = "Imp", Team = "Party", Owner = "2" } },
			{ T = 1, Type = "Damage", Source = "1", Target = "e1", Amount = 100, Tag = "BasicAttack" },
			{ T = 2, Type = "Damage", Source = "1", Target = "e1", Amount = 40, Tag = "Pet_Foxling", Crit = true },
			{ T = 3, Type = "Damage", Source = "m1", Target = "e1", Amount = 60, Tag = "BasicAttack" },
			{ T = 4, Type = "Damage", Source = "2", Target = "2", Amount = 500, Tag = "SummonImp", Sacrifice = true },
			{ T = 5, Type = "Damage", Source = "e1", Target = "1", Amount = 999, Tag = "BasicAttack" },
			{ T = 9, Type = "Damage", Source = "2", Target = "e1", Amount = 200, Tag = "BasicAttack" },
		},
	}
	local stats = FightStats.Compute(fight)
	local byKey = {}
	for _, r in ipairs(stats.Rows) do
		byKey[r.Key] = r
	end
	check("Total counts only party damage to enemies", stats.Total == 400)
	check("Hero damage excludes the pet's hit", byKey["1"].Damage == 100)
	check("The pet gets its own row and DPS", byKey["1:pet"] ~= nil and byKey["1:pet"].Damage == 40 and byKey["1:pet"].Kind == "Pet" and byKey["1:pet"].Dps == 4)
	check("Minion damage goes to a minions row of the owner", byKey["2:minions"] and byKey["2:minions"].Damage == 60 and byKey["2:minions"].OwnerId == "2")
	check("Self-sacrifice is not counted as damage", byKey["2"].Damage == 200)
	check("Rows are sorted biggest first", stats.Rows[1].Key == "2")
	check("Players get different colours", byKey["1"].Color ~= byKey["2"].Color)
	check("Shares add to 100%", math.abs((byKey["1"].Share + byKey["1:pet"].Share + byKey["2"].Share + byKey["2:minions"].Share) - 1) < 1e-6)
	local early = FightStats.Compute(fight, 3)
	check("A cut-off time only counts damage so far", early.Total == 200)
	-- damage by skill, both sides
	local src = FightStats.Sources(fight)
	local named = {}
	for _, r in ipairs(src.Rows) do
		named[r.Name] = r
	end
	check("Sources count every damage source, enemies included", src.Total == 1399)
	check("A basic attack is its own row", named["Basic attack (Ann)"] and named["Basic attack (Ann)"].Damage == 100)
	check("A pet strike is its own row", named["Pet_Foxling (Ann)"] ~= nil or named["Foxling Strike (Ann)"] ~= nil or (function() for name, r in pairs(named) do if r.Kind == "Pet" then return true end end return false end)())
	check("Enemy damage is marked as Enemy", named["Basic attack (Rat)"] and named["Basic attack (Rat)"].Kind == "Enemy" and named["Basic attack (Rat)"].Damage == 999)
	check("Sacrifices are left out of the sources too", src.Total == 1399)
	check("Sources are sorted biggest first", src.Rows[1].Damage >= src.Rows[2].Damage)
	print(("FightStatsTests: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
