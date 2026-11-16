--[[
	CharacterTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CharacterTests

	  require(game.ServerScriptService.Server.Tests.CharacterTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Character = require(Shared.Character), ProfileTemplate = require(Shared.ProfileTemplate), Premium = require(Shared.Premium), CharacterConfig = require(Shared.Config.Character) }
	end
	local Character, ProfileTemplate, Premium, Config = m.Character, m.ProfileTemplate, m.Premium, m.CharacterConfig
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

	check("A good name is accepted and tidied", select(2, Character.CheckName("  Mira   Moon ")) == "Mira Moon")
	check("Too short, too long and odd characters are refused", select(2, Character.CheckName("ab")) == "TooShort" and select(2, Character.CheckName(string.rep("a", 15))) == "TooLong" and select(2, Character.CheckName("bad<name>")) == "BadCharacters" and select(2, Character.CheckName(nil)) == "TooShort")
	check("Blocked words are refused even with spaces or digits", select(2, Character.CheckName("Ad min1")) == "Blocked" and select(2, Character.CheckName("RobloxFan")) == "Blocked")
	check("Looks are clamped to valid indexes", Character.CleanLook({ Skin = 99, Hair = -1, Outfit = 2.5 }).Skin == Config.Defaults.Skin and Character.CleanLook({ Skin = 99, Hair = -1, Outfit = 2.5 }).Outfit == Config.Defaults.Outfit and Character.CleanLook(nil).Hair == Config.Defaults.Hair and Character.CleanLook({ Skin = 3 }).Skin == 3)

	local p = ProfileTemplate.New()
	check("A new profile has no character yet", Character.Get(p).Created == false and Character.DisplayName(p, "Fallback") == "Fallback")
	check("Mage (locked) and unknown classes cannot be picked", select(2, Character.Create(p, "Hero", "Mage", {}, false)) == "BadClass" and select(2, Character.Create(p, "Hero", "Nope", {}, false)) == "BadClass" and not Character.Get(p).Created)
	check("A bad name does not create a character", select(2, Character.Create(p, "x", "Warrior", {}, false)) == "TooShort" and not Character.Get(p).Created)
	check("Create saves name, look, avatar choice and class", Character.Create(p, "Mira Moon", "Cleric", { Skin = 3, Hair = 4, Outfit = 5 }, false) == true and Character.Get(p).Name == "Mira Moon" and p.Season.ClassId == "Cleric" and Character.Get(p).Look.Outfit == 5 and Character.DisplayName(p, "x") == "Mira Moon")
	check("Create works once only", select(2, Character.Create(p, "Other", "Warrior", {}, false)) == "AlreadyCreated" and p.Season.ClassId == "Cleric")
	check("The look can be changed for free", Character.SetLook(p, { Skin = 1, Hair = 1, Outfit = 1 }, true) == true and Character.Get(p).UseAvatar == true and Character.Colors(p).Outfit[1] == Config.Outfits[1][1])
	check("Look changes need a character", select(2, Character.SetLook(ProfileTemplate.New(), {}, false)) == "NotCreated")
	check("A rename costs Sunstones and fails without them", select(2, Character.Rename(p, "New Name", Premium)) == "NotEnough" and Character.Get(p).Name == "Mira Moon")
	Premium.AddSunstones(p, Config.RenameCost + 5)
	local ok, cost = Character.Rename(p, "New Name", Premium)
	check("A paid rename works and spends the cost", ok == true and cost == Config.RenameCost and Premium.Sunstones(p) == 5 and Character.Get(p).Name == "New Name" and Character.Get(p).Renames == 1)
	check("Renaming to the same name is free", select(2, Character.Rename(p, "New Name", Premium)) == 0 and Premium.Sunstones(p) == 5)
	check("A refused rename keeps the old name and the money", select(1, Character.Rename(p, "ab", Premium)) == false and Character.Get(p).Name == "New Name" and Premium.Sunstones(p) == 5)

	print(("CharacterTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
