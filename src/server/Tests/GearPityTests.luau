--[[
	GearPityTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > GearPityTests

	Bad-luck protection for gear (Config/Gear Pity): a dry spell of wins with no upgrade guarantees one.
	require(...GearPityTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Gear = require(Shared.Gear), GearConfig = require(Shared.Config.Gear), Progression = require(Shared.Progression), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Gear, Progression = m.Gear, m.Progression
	local GearConfig = m.GearConfig
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("GearPityTests")

	-- a hero in full Common stage-5 gear, now at stage 40
	local p = m.ProfileTemplate.New()
	local equipment = p.Season.Equipment
	for _, slotName in ipairs(GearConfig.SlotOrder) do
		equipment.Equipped[slotName] = { Id = "w" .. slotName, Slot = GearConfig.WornType[slotName], Rarity = "Common", Power = 5, Roll = 1 }
	end
	-- the boots are much worse than the rest
	equipment.Equipped.Boots.Power = 1
	equipment.Equipped.Boots.Roll = 0.85

	local drop = Gear.PityDrop(equipment.Equipped, 40)
	check("The lucky find is for the weakest worn slot", drop.Slot == "Boots")
	check("It has that stage's most common rarity", drop.Rarity == "Rare")
	check("It has an average roll", drop.Roll == 1)
	check("It is an upgrade", Gear.IsUpgrade(equipment.Equipped, { Slot = drop.Slot, Rarity = drop.Rarity, Power = 40, Roll = drop.Roll }))

	-- an empty slot is the weakest of all
	equipment.Equipped.Amulet = nil
	check("An empty slot comes first", Gear.PityDrop(equipment.Equipped, 40).Slot == "Amulet")
	check("Anything fills an empty slot", Gear.IsUpgrade(equipment.Equipped, { Slot = "Amulet", Rarity = "Common", Power = 1, Roll = 0.85 }))

	-- gear at par or better never gets a lucky find (catch-up only)
	local q = m.ProfileTemplate.New()
	for _, slotName in ipairs(GearConfig.SlotOrder) do
		q.Season.Equipment.Equipped[slotName] = { Id = "s" .. slotName, Slot = GearConfig.WornType[slotName], Rarity = "Rare", Power = 40, Roll = 0.9 }
	end
	check("Gear near par gets nothing", Gear.PityDrop(q.Season.Equipment.Equipped, 40) == nil)

	-- through ApplyClear: replays with nothing found build up to a guaranteed find at the best cleared stage
	local r = m.ProfileTemplate.New()
	r.Season.HighestStage = 31
	for _, slotName in ipairs(GearConfig.SlotOrder) do
		r.Season.Equipment.Equipped[slotName] = { Id = "r" .. slotName, Slot = GearConfig.WornType[slotName], Rarity = "Uncommon", Power = 25, Roll = 1 }
	end
	local noLuck = function() return 0.99 end -- no natural drop, ever
	local lucky
	for index = 1, GearConfig.Pity.After do
		local result = Progression.ApplyClear(r, 12, noLuck)
		if result.LuckyFind then
			lucky = { At = index, Item = result.Item }
		end
	end
	check("A dry spell ends in a lucky find", lucky ~= nil and lucky.At == GearConfig.Pity.After)
	check("The find is at the best cleared stage, not the replayed one", lucky ~= nil and lucky.Item.Power == 30)
	check("The count starts over after a find", (r.Season.GearDry or 0) == 0)

	-- a full bag never sells a lucky find
	local full = m.ProfileTemplate.New()
	for index = 1, Gear.Cap(full) do
		table.insert(full.Season.Equipment.Inventory, { Id = "x" .. index, Slot = "Ring", Rarity = "Common", Power = 1, Roll = 1 })
	end
	local item, sold = Gear.Grant(full, 10, { Slot = "Boots", Rarity = "Rare", Roll = 1, Keep = true })
	check("A full bag keeps a lucky find", item ~= nil and sold == nil)

	print(("GearPityTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
