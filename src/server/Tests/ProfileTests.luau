--[[
	ProfileTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > ProfileTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.ProfileTests)()

	and read the Output window.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProfileTemplate = require(Shared.ProfileTemplate)
local TableUtil = require(Shared.Util.TableUtil)
local Classes = require(Shared.Config.Classes)

return function()
	local passed, failed = 0, 0

	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warn("  FAIL  " .. name)
		end
	end

	print("Running ProfileTests...")

	-- A fresh profile has both sections and a version number.
	local profile = ProfileTemplate.New()
	check("new profile has SchemaVersion", profile.SchemaVersion == ProfileTemplate.CURRENT_VERSION)
	check("new profile has Permanent and Season", profile.Permanent ~= nil and profile.Season ~= nil)
	check("season stores its SeasonId", profile.Season.SeasonId ~= nil)

	-- DeepCopy produces an independent copy.
	local copy = TableUtil.DeepCopy(profile)
	copy.Season.Level = 99
	check("DeepCopy is independent", profile.Season.Level == 1)

	-- Reconcile fills missing fields but never overwrites saved values.
	local old = { Season = { Level = 7 }, Permanent = {} }
	TableUtil.Reconcile(old, ProfileTemplate.New())
	check("Reconcile keeps existing values", old.Season.Level == 7)
	check("Reconcile adds missing fields", old.Season.HighestStage == 1 and old.Permanent.LegacyPoints == 0)

	-- Subclass hook exists on every class.
	for classId, classData in pairs(Classes) do
		check(classId .. " has a Subclasses table", type(classData.Subclasses) == "table")
		check(classId .. " has four pool abilities", #classData.AbilityPool == 4)
	end

	print(("ProfileTests done: %d passed, %d failed"):format(passed, failed))
end
