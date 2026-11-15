--[[
	ProfileTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > ProfileTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.ProfileTests)()

	and read the Output window.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		ProfileTemplate = require(Shared.ProfileTemplate),
		TableUtil = require(Shared.Util.TableUtil),
		Classes = require(Shared.Config.Classes),
		Skills = require(Shared.Skills),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local ProfileTemplate, TableUtil, Classes, Skills = m.ProfileTemplate, m.TableUtil, m.Classes, m.Skills
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
	TableUtil.Reconcile(old, ProfileTemplate.Defaults())
	check("Reconcile keeps existing values", old.Season.Level == 7)
	check("Reconcile adds missing fields", old.Season.HighestStage == 1 and old.Permanent.LegacyPoints == 0)

	-- Classes: skill data hooks.
	for classId, classData in pairs(Classes) do
		check(classId .. " has a Subclasses table", type(classData.Subclasses) == "table")
		check(classId .. " has a BasicAttack", type(classData.BasicAttack) == "table")
		check(classId .. " has a four-skill default loadout", #classData.DefaultLoadout == Skills.SLOTS)
	end

	-- Starter skills ---------------------------------------------------------
	local owned = profile.Season.OwnedAbilities
	local allOwned = true
	for classId, unlocked in pairs(profile.Permanent.UnlockedClasses) do
		if unlocked then
			for _, abilityId in ipairs(Classes[classId].DefaultLoadout) do
				if owned[abilityId] ~= true then
					allOwned = false
				end
			end
		end
	end
	check("A new player owns every unlocked class's starter skills", allOwned)
	check("Starter loadouts are valid", (Skills.ValidateLoadout("Warrior", profile.Season.Loadouts.Warrior, owned)) and (Skills.ValidateLoadout("Cleric", profile.Season.Loadouts.Cleric, owned)))
	check("Non-starter skills are not owned yet", owned.LastStand == nil and owned.Judgment == nil)

	-- Defaults() has no starters, so loading never re-grants skills.
	local defaults = ProfileTemplate.Defaults()
	check("Defaults() contains no skills", next(defaults.Season.OwnedAbilities) == nil and next(defaults.Season.Loadouts) == nil and next(defaults.Season.SlotLevels) == nil)
	local veteran = ProfileTemplate.New()
	veteran.Season.OwnedAbilities.Taunt = nil -- e.g. a future dismantle feature
	TableUtil.Reconcile(veteran, ProfileTemplate.Defaults())
	check("Reconciling an existing profile does not re-grant skills", veteran.Season.OwnedAbilities.Taunt == nil)

	-- The v1 -> v2 migration shape (what DataService's migration does).
	local v1 = ProfileTemplate.Defaults()
	v1.SchemaVersion = 1
	v1.Season.EquippedAbilities = {} -- the old field; migration drops it
	v1.Season.EquippedAbilities = nil
	ProfileTemplate.GrantStarterAbilities(v1)
	check("Granting starters to an old profile fills skills, loadouts and slot levels", v1.Season.OwnedAbilities.Taunt == true and #v1.Season.Loadouts.Warrior == 4 and #v1.Season.SlotLevels.Warrior == 4)

	-- Slot levels survive a re-grant, and skills keep their slot's level.
	local levelled = ProfileTemplate.New()
	levelled.Season.SlotLevels.Warrior[2] = 7
	ProfileTemplate.GrantClassStarters(levelled.Season, "Warrior")
	check("Re-granting starters never resets slot levels", levelled.Season.SlotLevels.Warrior[2] == 7)
	check("New slots start at level 1", levelled.Season.SlotLevels.Warrior[1] == 1)

	print(("ProfileTests done: %d passed, %d failed"):format(passed, failed))
end
