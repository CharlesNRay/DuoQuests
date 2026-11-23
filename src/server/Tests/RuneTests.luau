--[[
	RuneTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > RuneTests

	Runes carved onto gear: granting, carving, replacing (higher tiers need confirm), stat mods, drops, the pouch.
	require(...RuneTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Runes = require(Shared.Runes), Gear = require(Shared.Gear), ProfileTemplate = require(Shared.ProfileTemplate), RunesConfig = require(Shared.Config.Runes) }
	end
	local Runes, Gear = m.Runes, m.Gear
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("RuneTests")

	local p = m.ProfileTemplate.New()
	local item = Gear.Grant(p, 20, { Slot = "Ring", Rarity = "Rare", Roll = 1 })
	check("A test item was granted", item ~= nil)
	Gear.Equip(p, item.Id)

	check("Carving needs a rune you own", select(2, Runes.Carve(p, item.Id, "CritChance:Rare", false)) == "NoRune")
	check("A bad rune key is refused", select(2, Runes.Carve(p, item.Id, "Nope:Rare", false)) == "BadRune")
	Runes.Grant(p, "CritChance", "Rare", 2)
	Runes.Grant(p, "Attack", "Common", 1)
	Runes.Grant(p, "MaxHealth", "Epic", 1)
	check("The list shows the best tier first", Runes.List(p)[1].Tier == "Epic")
	check("Carving a missing item is refused", select(2, Runes.Carve(p, "nope", "CritChance:Rare", false)) == "NoItem")

	local ok = Runes.Carve(p, item.Id, "CritChance:Rare", false)
	check("A rune carves onto worn gear", ok == true and item.Rune and item.Rune.Stat == "CritChance" and item.Rune.Tier == "Rare")
	check("Carving uses one rune", p.Season.Runes["CritChance:Rare"] == 1)

	local function modFor(stat)
		local total = 0
		for _, mod in ipairs(Gear.Mods(p.Season.Equipment.Equipped)) do
			if mod.Stat == stat then
				total += mod.Value
			end
		end
		return total
	end
	check("The rune adds its stat to the worn gear's mods", math.abs(modFor("CritChance") - (select(2, Gear.StatOf(item)) + m.RunesConfig.Stats.CritChance.Values[2])) < 1e-9)

	local okLower, reason = Runes.Carve(p, item.Id, "Attack:Common", false)
	check("Replacing a higher tier asks first", okLower == false and reason == "ConfirmOverride" and item.Rune.Stat == "CritChance")
	check("Nothing is used up when it asks", p.Season.Runes["Attack:Common"] == 1)
	check("Confirming replaces it", Runes.Carve(p, item.Id, "Attack:Common", true) == true and item.Rune.Stat == "Attack" and p.Season.Runes["Attack:Common"] == nil)
	check("A higher tier replaces a lower one without asking", Runes.Carve(p, item.Id, "MaxHealth:Epic", false) == true and item.Rune.Tier == "Epic")
	check("The same tier replaces without asking", (function()
		Runes.Grant(p, "Defense", "Epic", 1)
		return Runes.Carve(p, item.Id, "Defense:Epic", false) == true
	end)())

	local row = Gear.Row(item)
	check("The item row carries the rune label", row.Rune ~= nil and row.Rune.Tier == "Epic" and type(row.Rune.Label) == "string")

	-- drops
	local seq = { 0.0, 0.5, 0.5 }
	local i = 0
	local function rand()
		i += 1
		return seq[i] or 0.5
	end
	check("A frontier boss always drops a rune", Runes.RollDrop(10, true, true, rand) ~= nil)
	check("Replays never drop runes", Runes.RollDrop(10, false, true, function() return 0 end) == nil)
	check("A normal frontier win rarely drops one", Runes.RollDrop(5, true, false, function() return 0.99 end) == nil)
	local w1, w100 = Runes.TierWeights(1), Runes.TierWeights(150)
	check("Early runes are Common only", w1.Rare == 0 and w1.Legendary == 0)
	check("Late runes can be Legendary", w100.Legendary > 0)

	-- pouch
	local q = m.ProfileTemplate.New()
	q.Season.Currencies.Gold = 0
	check("The pouch needs gold", select(2, Runes.BuyPouch(q)) == "NotEnoughGold")
	q.Season.Currencies.Gold = m.RunesConfig.Pouch.Gold
	local okPouch, got = Runes.BuyPouch(q, function() return 0.1 end)
	check("The pouch gives a rune and takes the gold", okPouch == true and q.Season.Currencies.Gold == 0 and #Runes.List(q) == 1 and got.Tier == "Common")

	print(("RuneTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
