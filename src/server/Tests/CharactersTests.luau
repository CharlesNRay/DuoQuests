--[[
	CharactersTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CharactersTests

	  require(game.ServerScriptService.Server.Tests.CharactersTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Characters = require(Shared.Characters), Character = require(Shared.Character), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Characters, Character, ProfileTemplate = m.Characters, m.Character, m.ProfileTemplate
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

	local p = ProfileTemplate.New()
	check("A new profile has no characters and nothing active", #Characters.List(p) == 0 and Characters.Active(p) == 0 and not Characters.Entered(p))
	check("Unknown classes cannot be created", select(2, Characters.Create(p, "Nope")) == "BadClass")
	local ok, slot = Characters.Create(p, "Mage")
	check("Creating a character is just a class and gives slot 1", ok == true and slot == 1 and #Characters.List(p) == 1 and Characters.List(p)[1].ClassId == "Mage")
	check("Creating does not start playing it", Characters.Active(p) == 0 and not Character.Get(p).Created)
	check("A character cannot be selected that does not exist", select(2, Characters.Select(p, 2)) == "BadSlot" and select(2, Characters.Select(p, "x")) == "BadSlot")
	check("Selecting makes the character active", Characters.Select(p, 1) == true and Characters.Active(p) == 1 and p.Season.ClassId == "Mage" and Character.Get(p).Created)
	check("Heroes use the player's Roblox avatar", Character.Get(p).UseAvatar == true)
	check("The selected character has starter skills and a weapon", next(p.Season.OwnedAbilities) ~= nil and p.Season.Equipment.Equipped.Weapon ~= nil)

	p.Season.Level = 12
	p.Season.HighestStage = 40
	local ok2, slot2 = Characters.Create(p, "Rogue")
	check("A second character can be created", ok2 == true and slot2 == 2)
	check("A third character is refused", select(2, Characters.Create(p, "Cleric")) == "Full" and #Characters.List(p) == 2)
	check("Switching loads the other character's progress", Characters.Select(p, 2) == true and p.Season.ClassId == "Rogue" and p.Season.Level == 1 and p.Season.HighestStage == 1)
	p.Season.Level = 5
	check("Switching back restores the first character", Characters.Select(p, 1) == true and p.Season.ClassId == "Mage" and p.Season.Level == 12 and p.Season.HighestStage == 40)
	local list = Characters.List(p)
	check("The list shows every character's level and which is active", list[1].Active and not list[2].Active and list[1].Level == 12 and list[2].Level == 5 and list[2].ClassId == "Rogue")
	check("Only the active character holds a Season copy", Characters.List(p) and p.Permanent.Slots[1].Season == nil and p.Permanent.Slots[2].Season ~= nil)

	-- an old single-class profile becomes slot 1
	local old = ProfileTemplate.New()
	Character.ChooseClass(old, "Ranger")
	old.Season.Level = 33
	check("An old profile is migrated into slot 1", Characters.Active(old) == 1 and Characters.List(old)[1].ClassId == "Ranger" and Characters.List(old)[1].Level == 33)
	check("The migrated profile can add a second character", Characters.Create(old, "Warrior") == true and select(2, Characters.Create(old, "Cleric")) == "Full")

	-- the per-session flag
	Characters.Enter(p)
	check("Entering is tracked per session and not saved", Characters.Entered(p) and rawget(p.Permanent, "Entered") == nil)

	print(("CharactersTests done: %d passed, %d failed"):format(passed, failed))
end
