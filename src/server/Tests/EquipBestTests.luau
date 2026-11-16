--[[
	EquipBestTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > EquipBestTests

	  require(game.ServerScriptService.Server.Tests.EquipBestTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Gear = require(Shared.Gear), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Gear, ProfileTemplate = m.Gear, m.ProfileTemplate
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

	local nextId = 0
	local function item(slot, rarity, power)
		nextId += 1
		return { Id = "t" .. nextId, Slot = slot, Rarity = rarity, Power = power }
	end
	local function fresh()
		local p = ProfileTemplate.New()
		local e = p.Season.Equipment
		e.Equipped, e.Inventory = {}, {}
		return p, e
	end
	local function total(e)
		local n = #e.Inventory
		for _ in pairs(e.Equipped) do
			n += 1
		end
		return n
	end

	local p, e = fresh()
	local weak, strong = item("Weapon", "Common", 1), item("Weapon", "Epic", 20)
	e.Equipped.Weapon = weak
	e.Inventory = { strong, item("Helmet", "Rare", 10) }
	local ok, changed = Gear.EquipBest(p)
	check("The stronger weapon is worn and the weak one goes to the bag", ok and e.Equipped.Weapon == strong and table.find(e.Inventory, weak) ~= nil)
	check("Empty slots get the best item of their type", e.Equipped.Helmet ~= nil and changed == 2)
	check("No item is lost or copied", total(e) == 3)

	local again, none = Gear.EquipBest(p)
	check("Running it again changes nothing", again and none == 0 and e.Equipped.Weapon == strong)

	local p2, e2 = fresh()
	local r1, r2, r3 = item("Ring", "Common", 1), item("Ring", "Epic", 20), item("Ring", "Rare", 10)
	e2.Equipped.Ring1 = r1
	e2.Inventory = { r2, r3 }
	Gear.EquipBest(p2)
	check("Two ring slots take the two best rings", (e2.Equipped.Ring1 == r2 or e2.Equipped.Ring2 == r2) and (e2.Equipped.Ring1 == r3 or e2.Equipped.Ring2 == r3) and table.find(e2.Inventory, r1) ~= nil)

	local p3, e3 = fresh()
	local a, b = item("Boots", "Rare", 10), item("Boots", "Rare", 10)
	e3.Equipped.Boots = a
	e3.Inventory = { b }
	local _, tie = Gear.EquipBest(p3)
	check("A tie keeps what is already worn", e3.Equipped.Boots == a and tie == 0)

	local p4, e4 = fresh()
	e4.Equipped.Weapon = strong
	e4.Equipped.Ring1 = r2
	e4.Inventory = { item("Weapon", "Common", 2) }
	Gear.EquipBest(p4)
	check("Better worn gear stays put and a worn ring keeps its slot", e4.Equipped.Weapon == strong and e4.Equipped.Ring1 == r2 and total(e4) == 3)

	print(("EquipBestTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
