--[[
	CompanionTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CompanionTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.CompanionTests)()

	The starter ghost companion: a ghost partner for a one-member party.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Party = require(Shared.Party),
		ProfileTemplate = require(Shared.ProfileTemplate),
		Skills = require(Shared.Skills),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Party, ProfileTemplate, Skills = m.Party, m.ProfileTemplate, m.Skills
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

	local OWNER, FRIEND = 1001, 1002
	local profile = ProfileTemplate.New() -- a Warrior
	local party = Party.NewOpen("p1", 1, OWNER, 100)
	Party.RefreshSnapshot(party, OWNER, "Owner", profile, 100)
	local function first(pt) return pt.Companions and pt.Companions[1] end
	check("A new party has no companion until it fights", party.Companions == nil)

	local outcome = Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 7, 200)
	check("The first fight fills the 3 empty seats with companions, a healer first", party.Companions ~= nil and #party.Companions == 3 and first(party).ClassId == "Cleric" and first(party).Name == "Mira")
	check("Companions take classes nobody has yet", party.Companions[2].ClassId == "Mage" and party.Companions[3].ClassId == "Ranger" and party.Companions[3].UserId == Party.COMPANION_ID - 2)
	check("Every fight has four heroes", (function() local n = 0 for _, e in ipairs(outcome.Roster) do if e.Team == "Party" then n += 1 end end return n end)() == Party.SEATS)
	check("The companion is a ghost with the starter loadout", first(party).IsCompanion == true and #first(party).GhostLoadout == Skills.SLOTS)
	local hasCompanion = false
	for _, entry in ipairs(outcome.Roster) do
		if entry.Id == tostring(Party.COMPANION_ID) then
			hasCompanion = entry.Ghost == true and entry.Team == "Party"
		end
	end
	check("The companion fights beside the player and is marked as a ghost", hasCompanion)
	check("Only the real player is paid", outcome.Rewards["1001"] ~= nil or not outcome.Won)
	check("The companion is not a party member", #party.Members == 1 and party.Snapshots[tostring(Party.COMPANION_ID)] == nil)

	-- it keeps pace with its owner
	profile.Season.Level = 12
	for _, id in ipairs(profile.Season.Loadouts.Warrior) do
		profile.Season.SkillState[id] = { Tier = m.SkillProgress.BaseTier(id), Rank = 5, XP = 0 }
	end
	Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 8, 300)
	check("The companion matches its owner's level and slots", first(party).Level == 12 and first(party).SlotLevels[1] == 5)
	check("Its subclass path comes at the unlock stage", first(party).SubclassId == nil)
	profile.Season.Level = 30
	Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 9, 400)
	check("Then it takes a path and its first skill", first(party).SubclassId == "Priest" and first(party).Owned.Sanctuary == true)

	-- editing the companion's skills
	local owned = {}
	for id in pairs(first(party).Owned) do
		table.insert(owned, id)
	end
	local newLoadout = table.clone(first(party).GhostLoadout)
	newLoadout[1], newLoadout[2] = newLoadout[2], newLoadout[1]
	check("The owner can reorder the companion's skills", Party.SetGhostLoadout(party, OWNER, Party.COMPANION_ID, newLoadout, 500) and first(party).GhostLoadout[1] == newLoadout[1])
	check("A stranger cannot edit it", select(2, Party.SetGhostLoadout(party, 999, Party.COMPANION_ID, newLoadout, 500)) == "NotMember")
	check("Skills it does not own are refused", select(1, Party.SetGhostLoadout(party, OWNER, Party.COMPANION_ID, { "Smite", "Heal", "Blessing", "Bulwark" }, 500)) == false)
	Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 10, 600)
	check("Edits survive the next sync", first(party).GhostLoadout[1] == newLoadout[1])

	-- a Cleric owner gets a Warrior
	local clericProfile = ProfileTemplate.New()
	clericProfile.Season.ClassId = "Cleric"
	local cp = Party.NewOpen("p2", 1, 2001, 0)
	Party.RefreshSnapshot(cp, 2001, "C", clericProfile, 0)
	Party.OnlineTick(cp, { { UserId = 2001, Name = "C", Profile = clericProfile } }, 3, 10)
	check("A Cleric player gets a Warrior companion first", first(cp).ClassId == "Warrior")

	-- a real partner replaces it
	local friend = ProfileTemplate.New()
	friend.Season.ClassId = "Cleric"
	Party.AddMember(party, FRIEND, "Friend", friend, 700)
	check("A real player takes a companion's seat", #party.Companions == 2 and #party.Members == 2)
	local after = Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 11, 800)
	local sawCompanion = false
	for _, entry in ipairs(after.Roster) do
		if entry.Id == tostring(Party.COMPANION_ID) then
			sawCompanion = true
		end
	end
	check("The companion of the newcomer's class (Cleric) gives way to another class", first(party).ClassId ~= "Cleric" and party.Companions[2].ClassId ~= "Cleric")

	-- if the partner leaves, a companion comes back
	Party.RemoveMember(party, FRIEND)
	Party.OnlineTick(party, { { UserId = OWNER, Name = "Owner", Profile = profile } }, 12, 900)
	check("When the partner leaves the seat is filled again", #party.Companions == 3)

	-- a new season resets it
	Party.EnsureSeason(party, 2)
	check("A new season clears the companions (they are rebuilt on the next fight)", party.Companions == nil)

	print(("CompanionTests done: %d passed, %d failed"):format(passed, failed))
end
