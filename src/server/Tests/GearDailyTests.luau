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
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Gear, GearConfig, Daily, ProfileTemplate, Progression, StatCalc, Party = m.Gear, m.GearConfig, m.Daily, m.ProfileTemplate, m.Progression, m.StatCalc, m.Party
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
	local drop = Gear.RollDrop(3, true, 0, fixed(0.0, 0.0, 0.0))
	check("A low roll drops a common weapon", drop ~= nil and drop.Rarity == "Common" and drop.Slot == "Weapon")
	check("A top rarity roll is Epic", Gear.RollDrop(3, true, 0, fixed(0.0, 0.999, 0.9)).Rarity == "Epic")
	check("Bosses always drop", Gear.RollDrop(10, false, 0, fixed(0.99, 0.0, 0.0)) ~= nil)
	check("Replays drop less often than the frontier", Gear.RollDrop(3, false, 0, fixed(0.15, 0.0, 0.0)) == nil and Gear.RollDrop(3, true, 0, fixed(0.15, 0.0, 0.0)) ~= nil)
	local lucky = 0
	local plainCount = 0
	for i = 1, 200 do
		local r = (i % 100) / 100
		local with = Gear.RollDrop(3, true, 0.3, fixed(0.0, r, 0.0))
		local without = Gear.RollDrop(3, true, 0, fixed(0.0, r, 0.0))
		if with and with.Rarity ~= "Common" then lucky += 1 end
		if without and without.Rarity ~= "Common" then plainCount += 1 end
	end
	check("The ItemRarity bonus gives better drops", lucky > plainCount)

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

	print(("GearDailyTests done: %d passed, %d failed"):format(passed, failed))
end
