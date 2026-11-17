--[[
	PetGearTests (ModuleScript): pet gear slots, mods, the Pet Store and boss drops.
	  require(game.ServerScriptService.Server.Tests.PetGearTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { PetGear = require(Shared.PetGear), Pets = require(Shared.Pets), ProfileTemplate = require(Shared.ProfileTemplate), Consumables = require(Shared.Consumables), StatCalc = require(Shared.Combat.StatCalc) }
	end
	local PetGear, Pets, ProfileTemplate, Consumables = m.PetGear, m.Pets, m.ProfileTemplate, m.Consumables
	local Config = PetGear.Config
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
	local function seq(values)
		local i = 0
		return function() i += 1 return values[math.min(i, #values)] end
	end

	local p = ProfileTemplate.New()
	p.Permanent.Pets = { Slimey = true }
	p.Season.Level = 60
	p.Season.Currencies.Gold = 1e9
	check("No slots open for a level 1 pet", PetGear.Slots(p) == 0)

	local piece = PetGear.Roll({ Common = 1 }, seq({ 0, 0, 0, 0.5 }))
	check("A rolled piece has kind, rarity, stat and a value", piece.Kind == "Collar" and piece.Rarity == "Common" and piece.Stat == "DamageDealt" and piece.Value > 0)
	local legendary = PetGear.Roll({ Legendary = 1 }, seq({ 0.5, 0, 0, 0.5 }))
	check("Higher rarities roll bigger values", legendary.Value > piece.Value * 3)
	local ok, given = PetGear.Give(p, piece)
	check("A piece goes into the bag with an id", ok and given.Id ~= nil and #p.Permanent.PetGear.Bag == 1)
	check("A locked slot refuses the piece", select(2, PetGear.Equip(p, given.Id)) == "SlotLocked")

	p.Permanent.PetLevels.Slimey = 5
	check("Pet level 5 opens the first slot", PetGear.Slots(p) == 1)
	check("The collar can be worn", PetGear.Equip(p, given.Id) == true and p.Permanent.PetGear.Equipped.Collar ~= nil)
	local mods = PetGear.Mods(p)
	check("Worn gear gives a mod", #mods == 1 and mods[1].Stat == "DamageDealt" and mods[1].Mode == "Mul")
	check("Pets.Collection carries the gear mods (so every stat build uses them)", (function() for _, mod in ipairs(Pets.Collection(p).Mods) do if mod.Stat == "DamageDealt" then return true end end return false end)())
	p.Permanent.PetLevels.Slimey = 1
	check("A lower pet level switches the gear off again", #PetGear.Mods(p) == 0)
	p.Permanent.PetLevels.Slimey = 28
	check("Level 28 opens all four slots", PetGear.Slots(p) == 4)
	check("Unequip returns it to the bag", PetGear.Unequip(p, 1) == true and #p.Permanent.PetGear.Bag == 1 and select(2, PetGear.Unequip(p, 1)) == "Empty")

	-- older data keyed Equipped by slot number (only [4] worn = a sparse table that remotes drop): it moves to kind names
	local old = { Kind = "Toy", Rarity = "Common", Stat = "DamageDealt", Value = 0.02, Id = "pgOld" }
	p.Permanent.PetGear.Equipped = { [4] = old }
	check("Old slot-number gear is moved to its kind and still gives its mod", #PetGear.Mods(p) == 1 and p.Permanent.PetGear.Equipped.Toy == old and p.Permanent.PetGear.Equipped[4] == nil)
	check("The view sends gear keyed by kind", PetGear.View(p, 0).Equipped.Toy == old)
	check("Unequip by slot number still works after the move", PetGear.Unequip(p, 4) == true and p.Permanent.PetGear.Equipped.Toy == nil and #p.Permanent.PetGear.Bag == 2)
	table.remove(p.Permanent.PetGear.Bag, 2)

	local gold = p.Season.Currencies.Gold
	local sold, got = PetGear.Sell(p, p.Permanent.PetGear.Bag[1].Id)
	check("Selling pays gold", sold and got > 0 and p.Season.Currencies.Gold == gold + got and #p.Permanent.PetGear.Bag == 0)

	-- the store
	local bought, newPiece = PetGear.BuyCrate(p, "PetCrate", math.random)
	check("A crate gives a piece for gold", bought and newPiece.Id ~= nil and p.Season.Currencies.Gold < gold + got)
	check("Unknown crates are refused", select(2, PetGear.BuyCrate(p, "Nope")) == "Unknown")
	local poor = ProfileTemplate.New()
	check("Not enough gold is refused", select(2, PetGear.BuyCrate(poor, "PetCrate")) == "NotEnough")
	local before = Consumables.Count(p, "PetWish")
	local now = 1000000
	for _ = 1, Config.Egg.PerDay do
		PetGear.BuyEgg(p, now)
	end
	check("Eggs are Pet Wish tickets", Consumables.Count(p, "PetWish") == before + Config.Egg.PerDay)
	check("Eggs sell out for the day", select(2, PetGear.BuyEgg(p, now)) == "SoldOut" and PetGear.EggsLeft(p, now) == 0)
	check("Eggs come back tomorrow", PetGear.EggsLeft(p, now + 86400) == Config.Egg.PerDay)
	local full = ProfileTemplate.New()
	full.Season.Currencies.Gold = 1e9
	for _ = 1, Config.BagSize do PetGear.Give(full, { Kind = "Collar", Rarity = "Common", Stat = "Attack", Value = 0.03 }) end
	check("A full bag refuses crates and gifts", select(2, PetGear.BuyCrate(full, "PetCrate")) == "BagFull" and select(2, PetGear.Give(full, { Kind = "Toy", Rarity = "Common", Stat = "Attack", Value = 0.03 })) == "BagFull")

	check("A boss can drop a piece", select(1, PetGear.BossDrop(ProfileTemplate.New(), seq({ 0 }))) == true)
	check("Often it does not", PetGear.BossDrop(ProfileTemplate.New(), seq({ 0.99 })) == false)
	local view = PetGear.View(p, now)
	check("The view lists slots, bag and store", view.Open == 4 and #view.Crates == 2 and view.EggPrice > 0 and view.BagSize == Config.BagSize)

	print(("PetGearTests done: %d passed, %d failed"):format(passed, failed))
end
