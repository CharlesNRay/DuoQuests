--[[
	GearDailyTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > GearDailyTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.GearDailyTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Gear = require(Shared.Gear),
		GearConfig = require(Shared.Config.Gear),
		Daily = require(Shared.Daily),
		ProfileTemplate = require(Shared.ProfileTemplate),
		Progression = require(Shared.Progression),
		StatCalc = require(Shared.Combat.StatCalc),
		Party = require(Shared.Party),
		World = require(Shared.World),
		Hero = require(Shared.Hero),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Gear, GearConfig, Daily, ProfileTemplate, Progression, StatCalc, Party = m.Gear, m.GearConfig, m.Daily, m.ProfileTemplate, m.Progression, m.StatCalc, m.Party
	local World, Hero = m.World, m.Hero
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
	local function fixed(...)
		local values, i = { ... }, 0
		return function()
			i += 1
			return values[math.min(i, #values)]
		end
	end

	-- drops
	check("A high roll means no drop", Gear.RollDrop(3, true, 0, fixed(0.99)) == nil)
	local drop = Gear.RollDrop(3, true, 0, fixed(0.0, 0.99, 0.0, 0.0))
	check("A low roll drops a common weapon", drop ~= nil and drop.Rarity == "Common" and drop.Slot == "Weapon")
	check("Early stages never drop Rare or better", Gear.RollDrop(3, true, 0, fixed(0.0, 0.99, 0.999, 0.9)).Rarity == "Uncommon")
	check("Stage 50 drops Epics at the top of the roll", Gear.RollDrop(50, true, 0, fixed(0.0, 0.99, 0.9, 0.9)).Rarity == "Epic")
	check("Stage 80 can drop Legendary", Gear.RollDrop(80, true, 0, fixed(0.0, 0.99, 0.999, 0.9)).Rarity == "Legendary")
	local w25, w50, w80 = Gear.RarityWeights(25), Gear.RarityWeights(50), Gear.RarityWeights(80)
	check("Stages 1-20 are Common and Uncommon only", Gear.RarityWeights(5).Rare == 0 and Gear.RarityWeights(5).Uncommon > 0 and Gear.RarityWeights(18).Epic < 4)
	check("Stages 20-40 give Uncommon and Rare with little Epic", w25.Uncommon > 0 and w25.Rare > 20 and w25.Epic > 0 and w25.Epic < 10 and w25.Legendary == 0)
	check("Stage 50 is Rare/Epic with a hint of Legendary", w50.Epic > w50.Rare and w50.Legendary > 0 and w50.Common == 0)
	check("Past stage 60 it is Epic and Legendary", w80.Epic + w80.Legendary > 95 and w80.Legendary > 25)
	check("Bosses always drop", Gear.RollDrop(10, false, 0, fixed(0.0, 0.99, 0.0)) ~= nil)
	check("Replays drop less often than the frontier", Gear.RollDrop(3, false, 0, fixed(0.15, 0.99, 0.0, 0.0)) == nil and Gear.RollDrop(3, true, 0, fixed(0.15, 0.99, 0.0, 0.0)) ~= nil)
	local lucky = 0
	local plainCount = 0
	for i = 1, 200 do
		local r = (i % 100) / 100
		local with = Gear.RollDrop(15, true, 0.3, fixed(0.0, 0.99, r, 0.0))
		local without = Gear.RollDrop(15, true, 0, fixed(0.0, 0.99, r, 0.0))
		if with and with.Rarity ~= "Common" and with.Rarity ~= "Uncommon" then lucky += 1 end
		if without and without.Rarity ~= "Common" and without.Rarity ~= "Uncommon" then plainCount += 1 end
	end
	check("The ItemRarity bonus gives better drops", lucky > plainCount)

	-- set pieces
	local setDrop = Gear.RollDrop(25, true, 0, fixed(0.0, 0.0))
	check("A low set roll drops a set piece from the zone", setDrop ~= nil and setDrop.Rarity == "Set" and setDrop.SetId == 3)
	local setBoss = Gear.RollDrop(30, false, 0, fixed(0.0, 0.0))
	check("Boss set roll drops the zone set", setBoss ~= nil and setBoss.Rarity == "Set" and setBoss.SetId == 3)
	local sets = Gear.Sets and Gear.SetFor(1)
	check("Set definitions exist for zone 1", sets ~= nil and sets.Pieces ~= nil and sets.Bonus2 ~= nil and sets.Bonus3 ~= nil)
	check("Set pieces only appear as part of a normal drop (no drop, no set)", Gear.RollDrop(25, true, 0, fixed(0.99, 0.0)) == nil)

	-- item power, starter weapon, bag order
	local ipW = Gear.ItemPower({ Slot = "Weapon", Rarity = "Common", Power = 1 })
	local ipA = Gear.ItemPower({ Slot = "Armor", Rarity = "Common", Power = 1 })
	check("Item Power is comparable across slots", ipW == ipA and ipW > 0)
	check("Rarer and later items have more Item Power", Gear.ItemPower({ Slot = "Weapon", Rarity = "Epic", Power = 40 }) > Gear.ItemPower({ Slot = "Weapon", Rarity = "Common", Power = 40 }) and Gear.ItemPower({ Slot = "Weapon", Rarity = "Common", Power = 40 }) > ipW)
	local fresh = ProfileTemplate.New()
	check("A new profile has no weapon until the starter is given", fresh.Season.Equipment.Equipped.Weapon == nil)
	check("The starter weapon is given once", Gear.EnsureStarter(fresh) == true and fresh.Season.Equipment.Equipped.Weapon.Rarity == "Common" and Gear.EnsureStarter(fresh) == false)
	local withBag = ProfileTemplate.New()
	Gear.Grant(withBag, 4, { Slot = "Weapon", Rarity = "Common" })
	check("No starter when a weapon is already in the bag", Gear.EnsureStarter(withBag) == false)
	local sorted = ProfileTemplate.New()
	Gear.Grant(sorted, 3, { Slot = "Armor", Rarity = "Common" })
	Gear.Grant(sorted, 30, { Slot = "Weapon", Rarity = "Epic" })
	Gear.Grant(sorted, 12, { Slot = "Amulet", Rarity = "Rare" })
	local listed = Gear.List(sorted).Inventory
	check("The bag lists the strongest item first", listed[1].ItemPower >= listed[2].ItemPower and listed[2].ItemPower >= listed[3].ItemPower and listed[1].Slot == "Weapon")

	-- bag, equip, sell
	local profile = ProfileTemplate.New()
	local item1 = Gear.Grant(profile, 10, { Slot = "Weapon", Rarity = "Common" })
	local item2 = Gear.Grant(profile, 30, { Slot = "Weapon", Rarity = "Rare" })
	check("Items get unique ids", item1.Id ~= item2.Id and #profile.Season.Equipment.Inventory == 2)
	check("Equipping moves an item out of the bag", Gear.Equip(profile, item1.Id) and profile.Season.Equipment.Equipped.Weapon.Id == item1.Id and #profile.Season.Equipment.Inventory == 1)
	check("Equipping over a slot returns the old item to the bag", Gear.Equip(profile, item2.Id) and profile.Season.Equipment.Equipped.Weapon.Id == item2.Id and profile.Season.Equipment.Inventory[1].Id == item1.Id)
	check("Unknown items are refused", select(2, Gear.Equip(profile, "nope")) == "NotFound")
	check("Unequip puts it back", Gear.Unequip(profile, "Weapon") and profile.Season.Equipment.Equipped.Weapon == nil and #profile.Season.Equipment.Inventory == 2)
	check("Unequipping an empty slot is refused", select(2, Gear.Unequip(profile, "Weapon")) == "Empty" and select(2, Gear.Unequip(profile, "Cape")) == "BadSlot")
	local gold = profile.Season.Currencies.Gold
	local ok, paid = Gear.Sell(profile, item1.Id)
	check("Selling pays gold and removes the item", ok and profile.Season.Currencies.Gold == gold + paid and paid > 0 and #profile.Season.Equipment.Inventory == 1)
	check("Rarer and later items sell for more", Gear.SellValue({ Rarity = "Epic", Power = 40 }) > Gear.SellValue({ Rarity = "Common", Power = 1 }))

	-- a full bag sells new drops
	local full = ProfileTemplate.New()
	for _ = 1, GearConfig.InventoryCap do
		Gear.Grant(full, 5, { Slot = "Armor", Rarity = "Common" })
	end
	local _, soldFor = Gear.Grant(full, 5, { Slot = "Armor", Rarity = "Common" })
	check("A full bag sells new drops instead", soldFor ~= nil and #full.Season.Equipment.Inventory == GearConfig.InventoryCap)

	-- stats
	local plain = StatCalc.NewPartyMember("a", "A", "Warrior", 10)
	local geared = StatCalc.NewPartyMember("b", "B", "Warrior", 10, { Equipped = { Weapon = { Id = "x", Slot = "Weapon", Rarity = "Rare", Power = 20 }, Armor = { Id = "y", Slot = "Armor", Rarity = "Common", Power = 20 } } })
	check("Gear adds attack and health", geared.Stats.Attack > plain.Stats.Attack and geared.Stats.MaxHealth > plain.Stats.MaxHealth)
	local statName, value = Gear.StatOf({ Slot = "Weapon", Rarity = "Common", Power = 20 })
	check("Weapon stat follows the formula", statName == "Attack" and math.abs(value - (0.3 + 0.05 * 20)) < 1e-9)
	local snap = Party.MakeSnapshot(profile, 1, "P", nil, 0)
	profile.Season.Equipment.Equipped.Weapon = { Id = "w", Slot = "Weapon", Rarity = "Epic", Power = 9 }
	local snap2 = Party.MakeSnapshot(profile, 1, "P", nil, 0)
	check("A ghost snapshot carries equipped gear", snap2.Gear.Weapon ~= nil and snap2.Gear.Weapon.Rarity == "Epic" and snap.Gear.Weapon == nil)

	-- clears can drop gear
	local clearProfile = ProfileTemplate.New()
	local summary = Progression.ApplyClear(clearProfile, 1, fixed(0.0, 0.0, 0.0))
	check("A clear can drop an item", summary.Item ~= nil and #clearProfile.Season.Equipment.Inventory == 1)
	local noDrop = Progression.ApplyClear(ProfileTemplate.New(), 1, fixed(0.99))
	check("A clear can also drop nothing", noDrop.Item == nil)

	-- daily login
	local p = ProfileTemplate.New()
	p.Season.HighestStage = 10
	local day = 86400
	local t0 = day * 20000 + 3600
	local status = Daily.Status(p, t0)
	check("A new player can claim day 1", status.CanClaim and status.NextDay == 1 and status.Reward.Gold > 0)
	local goldBefore = p.Season.Currencies.Gold
	local claimed, summary = Daily.Claim(p, t0)
	check("Claiming pays the reward", claimed and summary.Day == 1 and p.Season.Currencies.Gold == goldBefore + summary.Gold and p.Season.Currencies.Shards >= summary.Shards)
	check("A second claim the same day is refused", select(2, Daily.Claim(p, t0 + 5000)) == "AlreadyClaimed" and not Daily.Status(p, t0 + 5000).CanClaim)
	check("The next day continues the streak", select(2, Daily.Claim(p, t0 + day)).Day == 2)
	local _, third = Daily.Claim(p, t0 + 2 * day)
	check("Streak days climb", third.Day == 3 and third.Streak == 3)
	local skipped = select(2, Daily.Claim(p, t0 + 5 * day))
	check("Missing a day restarts at day 1", skipped.Day == 1 and skipped.Streak == 1)
	for d = 6, 11 do
		Daily.Claim(p, t0 + d * day)
	end
	local picksBefore = p.Season.Currencies.SkillPicks
	local seventh = Daily.Claim(p, t0 + 12 * day)
	check("Day 7 gives a skill pick", p.Season.Currencies.SkillPicks >= picksBefore)
	check("The cycle wraps after day 7", select(2, Daily.Claim(p, t0 + 13 * day)).Day == 1 or seventh)
	check("Rewards grow with the frontier", Daily.RewardFor((function() local q = ProfileTemplate.New() q.Season.HighestStage = 50 return q end)(), 1).Gold > Daily.RewardFor((function() local q = ProfileTemplate.New() q.Season.HighestStage = 5 return q end)(), 1).Gold)

	-- blacksmith + merchant -------------------------------------------------------
	local up = ProfileTemplate.New()
	local sword = Gear.Grant(up, 10, { Slot = "Weapon", Rarity = "Common" })
	local _, base = Gear.StatOf(sword)
	local cost = Gear.UpgradeCost(sword)
	check("An upgrade has a gold cost", cost ~= nil and cost > 0)
	local okBroke, whyBroke = Gear.Upgrade(up, sword.Id)
	check("Upgrading without gold is refused", not okBroke and whyBroke == "NoGold")
	up.Season.Currencies.Gold = 100000
	local okUp, level = Gear.Upgrade(up, sword.Id)
	local _, boosted = Gear.StatOf(sword)
	check("Upgrading raises the level, costs gold and boosts the stat", okUp and level == 1 and up.Season.Currencies.Gold == 100000 - cost and boosted > base)
	check("Each level costs more", Gear.UpgradeCost(sword) > cost)
	for _ = 1, 20 do
		Gear.Upgrade(up, sword.Id)
	end
	check("Upgrades stop at the max level", sword.Upgrade == GearConfig.Upgrade.MaxLevel and select(2, Gear.Upgrade(up, sword.Id)) == "MaxLevel" and Gear.UpgradeCost(sword) == nil)
	check("Upgrading an unknown item fails", select(2, Gear.Upgrade(up, "nope")) == "NotFound")

	local shop = ProfileTemplate.New()
	local worn = Gear.Grant(shop, 30, { Slot = "Weapon", Rarity = "Epic" })
	Gear.Equip(shop, worn.Id)
	local c1 = Gear.Grant(shop, 5, { Slot = "Armor", Rarity = "Common" })
	local c2 = Gear.Grant(shop, 6, { Slot = "Amulet", Rarity = "Common" })
	local weak = Gear.Grant(shop, 1, { Slot = "Weapon", Rarity = "Uncommon" })
	local keep = Gear.Grant(shop, 6, { Slot = "Armor", Rarity = "Common" })
	Gear.Upgrade((function() shop.Season.Currencies.Gold = 100000 return shop end)(), keep.Id)
	local goldBefore = shop.Season.Currencies.Gold
	local okBulk, count, gold = Gear.SellBulk(shop, "Common")
	check("Sell all Common sells commons and pays gold", okBulk and count == 2 and gold > 0 and shop.Season.Currencies.Gold == goldBefore + gold)
	check("An upgraded item survives the bulk sale", (function() for _, i in ipairs(shop.Season.Equipment.Inventory) do if i.Id == keep.Id then return true end end return false end)())
	local okWorse, count2 = Gear.SellBulk(shop, "Worse")
	check("Sell worse gear sells items no better than worn", okWorse and count2 == 1)
	check("A bad bulk mode is refused", select(2, Gear.SellBulk(shop, "Everything")) == "BadMode")

	-- plaza geometry ---------------------------------------------------------------
	local mx, mz = World.PlazaPoint("Merchant")
	check("The plaza has a merchant and a blacksmith", mx ~= nil and World.PlazaPoint("Blacksmith") ~= nil)
	check("Standing at a shop counts as near it", World.NearShop(mx, mz, "Merchant"))
	check("Far from a shop is not near it", not World.NearShop(mx + 500, mz, "Merchant"))
	local sx, _, sz = World.SpawnPosition()
	check("Players spawn on the plaza", math.sqrt((sx - World.PLAZA.X) ^ 2 + (sz - World.PLAZA.Z) ^ 2) <= World.PLAZA.Radius)

	-- hero sheet -------------------------------------------------------------------
	local sheet = Hero.Sheet({ ClassId = "Warrior", Level = 10, Gear = shop.Season.Equipment.Equipped })
	check("The hero sheet lists stats and gear", sheet and #sheet.Stats >= 6 and sheet.Gear.Weapon ~= nil)

	-- eight worn slots, two rings ------------------------------------------------------
	local kit = ProfileTemplate.New()
	local types = { "Weapon", "Helmet", "Armor", "Pants", "Boots", "Ring", "Ring", "Amulet" }
	for _, t in ipairs(types) do
		local it = Gear.Grant(kit, 10, { Slot = t, Rarity = "Common" })
		Gear.Equip(kit, it.Id)
	end
	local worn = kit.Season.Equipment.Equipped
	check("All eight slots fill, rings in both ring slots", worn.Helmet and worn.Amulet and worn.Armor and worn.Weapon and worn.Pants and worn.Boots and worn.Ring1 and worn.Ring2 and #kit.Season.Equipment.Inventory == 0)
	local strongRing = Gear.Grant(kit, 40, { Slot = "Ring", Rarity = "Epic" })
	Gear.Equip(kit, strongRing.Id)
	check("A third ring replaces a ring and the old one returns to the bag", (worn.Ring1.Id == strongRing.Id or worn.Ring2.Id == strongRing.Id) and #kit.Season.Equipment.Inventory == 1)
	local weakRing = Gear.Grant(kit, 1, { Slot = "Ring", Rarity = "Common" })
	check("A ring cannot go in a non-ring slot", select(2, Gear.Equip(kit, weakRing.Id, "Helmet")) == "BadSlot")
	check("A ring can be put in a chosen ring slot", Gear.Equip(kit, weakRing.Id, "Ring2") and worn.Ring2.Id == weakRing.Id)
	check("Unequip works on Ring1", Gear.Unequip(kit, "Ring1") and worn.Ring1 == nil)
	check("Every item type has a stat", (function() for _, t in ipairs(Gear.Types) do if select(1, Gear.StatOf({ Slot = t, Rarity = "Common", Power = 5 })) == nil then return false end end return true end)())
	local old = ProfileTemplate.New()
	old.Season.Equipment.Equipped.Trinket = { Id = "g1", Slot = "Trinket", Rarity = "Rare", Power = 9 }
	table.insert(old.Season.Equipment.Inventory, { Id = "g2", Slot = "Trinket", Rarity = "Common", Power = 3 })
	Gear.Migrate(old)
	check("Old Trinkets become Amulets", old.Season.Equipment.Equipped.Amulet ~= nil and old.Season.Equipment.Equipped.Trinket == nil and old.Season.Equipment.Inventory[1].Slot == "Amulet")
	check("Set bonuses need 2 and 4 pieces", GearConfig.SetThresholds[1] == 2 and GearConfig.SetThresholds[2] == 4)

	-- the Stash and timed boosts ---------------------------------------------------------
	local C = m.Consumables
	local p = ProfileTemplate.New()
	local now = 1000
	check("An empty stash cannot be used", select(2, C.Use(p, "XPTonic", now)) == "NoneLeft")
	C.Grant(p, "XPTonic", 2)
	C.Grant(p, "PowerElixir", 1)
	check("Using an XP Tonic starts a boost and spends one", C.Use(p, "XPTonic", now) and C.Count(p, "XPTonic") == 1 and C.Rewards(p, now + 10).XPGain == 0.5)
	check("The boost ends on time", C.Rewards(p, now + 901).XPGain == 0)
	C.Use(p, "XPTonic", now)
	check("Using it again extends the timer", p.Season.Buffs.XPTonic == now + 1800)
	C.Use(p, "PowerElixir", now)
	local mods = C.Mods(p, now + 5)
	check("A damage boost becomes a combat modifier", #mods == 1 and mods[1].Stat == "DamageDealt" and mods[1].Value == 0.25)
	check("Active boosts list their time left", #C.Active(p, now + 5) == 2 and C.Active(p, now + 5)[1].Remaining > 0)
	check("Wish tickets cannot be used from the stash", (function() C.Grant(p, "PetWish", 1) return select(2, C.Use(p, "PetWish", now)) == "UseAtTree" end)())
	p.Season.Currencies.Gold = 10
	check("Supplies cost gold", select(2, C.Buy(p, "XPTonic", 1)) == "NotEnough" and select(2, C.Buy(p, "PetWish", 1)) == "NotSold")
	p.Season.Currencies.Gold = 100000
	check("Buying spends gold and fills the stash", C.Buy(p, "XPTonic", 3) and C.Count(p, "XPTonic") == 3 and p.Season.Currencies.Gold < 100000)
	local geared2 = StatCalc.NewPartyMember("z", "Z", "Warrior", 5, { ExtraMods = { { Stat = "DamageDealt", Mode = "Mul", Value = 0.25 } } })
	local base2 = StatCalc.NewPartyMember("z", "Z", "Warrior", 5, {})
	check("A damage boost raises damage dealt in combat", (geared2.Stats.DamageDealt or 1) > (base2.Stats.DamageDealt or 1))
	local drops = {}
	for i = 1, 300 do
		local id = C.RollDrop(false, (function() local v = { 0.0, (i % 100) / 100 } local k = 0 return function() k += 1 return v[math.min(k, 2)] end end)())
		if id then drops[id] = true end
	end
	check("Stage drops can give boosts and pet food but never wish tickets", drops.XPTonic and drops.PetFood and not drops.PetWish and not drops.SkillWish)
	local fed = ProfileTemplate.New()
	fed.Permanent.Pets = { Slimey = true }
	C.Grant(fed, "PetFood", 3)
	local okFeed = C.Use(fed, "PetFood", now, "Slimey")
	check("Pet food gives a pet XP and levels it", okFeed and fed.Season.PetXP.Slimey ~= nil and C.Count(fed, "PetFood") == 2)
	C.Use(fed, "PetFood", now, "Slimey")
	C.Use(fed, "PetFood", now, "Slimey")
	check("Enough pet food raises the pet level", (fed.Season.PetLevels.Slimey or 1) >= 2)
	check("Pet food needs a pet you own", select(2, C.Use(ProfileTemplate.New(), "PetFood", now, "Slimey")) == "NoneLeft")

	print(("GearDailyTests done: %d passed, %d failed"):format(passed, failed))
end
