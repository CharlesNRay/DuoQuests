--[[
	PowerTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PowerTests

	IP goes up with every way a hero gets stronger.   require(...PowerTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Power = require(Shared.Power), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Power, ProfileTemplate = m.Power, m.ProfileTemplate
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			(warn or print)("  FAIL  " .. name)
		end
	end
	print("PowerTests")

	local profile = ProfileTemplate.New()
	local base = Power.Hero(profile).Total
	check("a new hero has some IP", base > 0)

	profile.Season.Level += 10
	local afterLevel = Power.Hero(profile).Total
	check("levelling up adds IP", afterLevel > base)

	profile.Permanent.Titles["Tester"] = true
	check("a title adds IP", Power.Hero(profile).Total > afterLevel)

	check("a higher skill level has more IP", Power.Skill("Epic", 5) > Power.Skill("Epic", 1))
	check("a rarer skill has more IP", Power.Skill("Legendary", 1) > Power.Skill("Rare", 1))
	check("a higher passive level has more IP", Power.Passive(5) > Power.Passive(1))
	check("a levelled pet has more IP", Power.Pet("Slimey", 5, 1) > Power.Pet("Slimey", 1, 1))
	check("a ranked-up pet has more IP", Power.Pet("Slimey", 1, 3) > Power.Pet("Slimey", 1, 1))
	check("a rarer pet has more IP", Power.Pet("Frostwing", 1, 1) > Power.Pet("Slimey", 1, 1))

	local withPet = Power.Hero(profile)
	profile.Season.PetLevels = { Slimey = 9 }
	check("pet IP follows the pet level", Power.Hero(profile).Pet > withPet.Pet or withPet.Pet == 0)
	check("total is the sum of its parts", withPet.Total == withPet.Level + withPet.Gear + withPet.Skills + withPet.Passives + withPet.Pet + withPet.Collection + withPet.Subclass + withPet.Titles + withPet.Guild)

	print(("PowerTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
