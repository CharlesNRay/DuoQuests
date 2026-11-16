--[[
	LeaderboardTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > LeaderboardTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.LeaderboardTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Leaderboards = require(Shared.Leaderboards),
		ProfileTemplate = require(Shared.ProfileTemplate),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Leaderboards, ProfileTemplate = m.Leaderboards, m.ProfileTemplate
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	local rows = Leaderboards.Rank({
		{ UserId = 3, Name = "Cy", Value = 10 },
		{ UserId = 1, Name = "Al", Value = 25 },
		{ UserId = 2, Name = "Bo", Value = 25 },
		{ UserId = 4, Name = "Di", Value = 7 },
	})
	check("Highest value is first", rows[1].Value == 25 and rows[#rows].Value == 7)
	check("Ties are broken by name", rows[1].Name == "Al" and rows[2].Name == "Bo")
	check("Ranks are the list positions", rows[1].Rank == 1 and rows[4].Rank == 4)
	check("The limit cuts the list", #Leaderboards.Rank({ { UserId = 1, Name = "A", Value = 1 }, { UserId = 2, Name = "B", Value = 2 } }, 1) == 1)
	check("Bad entries are skipped", #Leaderboards.Rank({ { UserId = 1, Name = "A", Value = "x" }, { Name = "B", Value = 3 } }) == 0)
	check("PositionOf finds a player", Leaderboards.PositionOf(rows, 3) == 3 and Leaderboards.PositionOf(rows, 99) == nil)

	local profile = ProfileTemplate.New()
	profile.Season.HighestStage = 17
	profile.Season.Level = 9
	check("Stage score is the frontier", Leaderboards.ScoreFor("Stage", profile) == 17)
	check("Level score is the season level", Leaderboards.ScoreFor("Level", profile) == 9)
	check("Unknown categories are not valid", not Leaderboards.IsCategory("Gold") and Leaderboards.IsCategory("Stage"))
	check("Values are formatted for display", Leaderboards.Format("Stage", 42) == "Stage 42")

	-- class boards
	local classBoards = {}
	for _, category in ipairs(Leaderboards.Categories) do
		if category.Class then
			classBoards[category.Class] = category.Id
		end
	end
	check("Every playable class has a board", classBoards.Warrior == "Class_Warrior" and classBoards.Cleric == "Class_Cleric" and classBoards.Mage == "Class_Mage" and classBoards.Ranger == "Class_Ranger" and classBoards.Rogue == "Class_Rogue" and classBoards.Summoner == "Class_Summoner")
	local warrior = ProfileTemplate.New()
	warrior.Season.HighestStage = 12
	warrior.Season.ClassId = "Warrior"
	check("A class board scores only that class's players", Leaderboards.ScoreFor("Class_Warrior", warrior) == 12 and Leaderboards.ScoreFor("Class_Cleric", warrior) == 0)
	warrior.Season.ClassId = "Cleric"
	check("Changing class moves the score to the new board", Leaderboards.ScoreFor("Class_Warrior", warrior) == 0 and Leaderboards.ScoreFor("Class_Cleric", warrior) == 12)
	check("Class boards are valid categories and format as stages", Leaderboards.IsCategory("Class_Warrior") and Leaderboards.Format("Class_Cleric", 5) == "Stage 5")

	print(("LeaderboardTests done: %d passed, %d failed"):format(passed, failed))
end
