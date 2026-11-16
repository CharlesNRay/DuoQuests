--[[
	CosmeticsTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CosmeticsTests

	  require(game.ServerScriptService.Server.Tests.CosmeticsTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Cosmetics = require(Shared.Cosmetics), CosmeticsConfig = require(Shared.Config.Cosmetics), ProfileTemplate = require(Shared.ProfileTemplate),
		Premium = require(Shared.Premium), SeasonRewardsConfig = require(Shared.Config.SeasonRewards), Classes = require(Shared.Config.Classes),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Cosmetics, Config, ProfileTemplate, Premium = m.Cosmetics, m.CosmeticsConfig, m.ProfileTemplate, m.Premium
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

	-- config sanity
	local ids, sane = {}, true
	for _, def in ipairs(Config.Items) do
		sane = sane and ids[def.Id] == nil and table.find(Config.Slots, def.Slot) ~= nil and def.Id:sub(1, #def.Slot + 1) == def.Slot .. "_" and (def.Source == "Shop" and def.Cost > 0 or def.Source == "Season" and def.Cost == 0) and #def.Color == 3
		ids[def.Id] = true
	end
	check("Every cosmetic has a unique id, a slot prefix, a source and a colour", sane)
	local classOk = true
	for classId in pairs(m.Classes) do
		for _, slot in ipairs({ "Aura", "Kill", "Name" }) do
			classOk = classOk and Cosmetics.Def(slot .. "_" .. classId) ~= nil
		end
	end
	check("Every class has its three prize cosmetics", classOk)
	local prizeOk = true
	for _, rows in ipairs({ m.SeasonRewardsConfig.Ranks, m.SeasonRewardsConfig.ClassRanks }) do
		for _, row in ipairs(rows) do
			if row.Cosmetic then
				for classId in pairs(m.Classes) do
					prizeOk = prizeOk and Cosmetics.Def((row.Cosmetic:gsub("%%s", classId))) ~= nil
				end
			end
		end
	end
	check("Every season prize cosmetic exists", prizeOk)

	local p = ProfileTemplate.New()
	check("Nothing owned or worn at the start", next(Cosmetics.Equipped(p)) == nil and not Cosmetics.Owned(p, "Aura_Flame"))
	check("Buying needs Sunstones", select(2, Cosmetics.Buy(p, "Aura_Flame")) == "NotEnough" and not Cosmetics.Owned(p, "Aura_Flame"))
	Premium.AddSunstones(p, 1000)
	local ok, bought = Cosmetics.Buy(p, "Aura_Flame")
	check("Buying spends Sunstones and unlocks the item", ok and bought.Cost == 200 and Premium.Sunstones(p) == 800 and Cosmetics.Owned(p, "Aura_Flame"))
	check("Buying twice is refused", select(2, Cosmetics.Buy(p, "Aura_Flame")) == "AlreadyOwned" and Premium.Sunstones(p) == 800)
	check("Season prizes cannot be bought", select(2, Cosmetics.Buy(p, "Aura_Champion")) == "NotForSale" and select(2, Cosmetics.Buy(p, "Nope")) == "BadItem")
	check("An unowned item cannot be worn", select(2, Cosmetics.Equip(p, "Aura", "Aura_Frost")) == "NotOwned")
	check("An owned item can be worn", Cosmetics.Equip(p, "Aura", "Aura_Flame") and Cosmetics.Equipped(p).Aura == "Aura_Flame")
	check("An item only fits its own slot", select(2, Cosmetics.Equip(p, "Name", "Aura_Flame")) == "NotOwned" and select(2, Cosmetics.Equip(p, "Hat", "Aura_Flame")) == "BadSlot")
	check("Taking a slot off works", Cosmetics.Equip(p, "Aura", nil) and Cosmetics.Equipped(p).Aura == nil)
	Cosmetics.Equip(p, "Aura", "Aura_Flame")
	Cosmetics.Buy(p, "Name_Gold")
	Cosmetics.Equip(p, "Name", "Name_Gold")
	check("Look reports what is worn", Cosmetics.Look(p).Aura == "Aura_Flame" and Cosmetics.Look(p).Name == "Name_Gold")

	-- titles
	check("A title can be bought for Sunstones", select(1, Cosmetics.Buy(p, "the Brave")) == true and Cosmetics.Owned(p, "the Brave") and Premium.Sunstones(p) == 800 - 80 - 100)
	check("A title can be worn", Cosmetics.Equip(p, "Title", "the Brave") and Cosmetics.Look(p).Title == "the Brave")
	check("A title you do not own cannot be worn", select(2, Cosmetics.Equip(p, "Title", "Champion")) == "NotOwned")
	Cosmetics.GrantTitle(p, "Champion")
	Cosmetics.Grant(p, "Aura_Champion")
	check("Prize titles and cosmetics can be worn once granted", Cosmetics.Equip(p, "Title", "Champion") and Cosmetics.Equip(p, "Aura", "Aura_Champion"))

	-- lists
	local rows = Cosmetics.List(p, "Aura")
	local flame, frost, champ
	for _, row in ipairs(rows) do
		if row.Id == "Aura_Flame" then flame = row elseif row.Id == "Aura_Frost" then frost = row elseif row.Id == "Aura_Champion" then champ = row end
	end
	check("The list shows owned, for sale and prize-only rows", flame.Owned and not flame.Equipped and frost.Affordable and not frost.Owned and champ.Equipped and champ.Source == "Season")
	local titles = Cosmetics.List(p, "Title")
	local hasPrize = false
	for _, row in ipairs(titles) do
		hasPrize = hasPrize or (row.Id == "Champion" and row.Owned and row.Equipped)
	end
	check("The title list includes prize titles you hold", hasPrize and #titles >= #Config.ShopTitles + 1)

	-- stale data: an equipped thing you no longer own is not reported
	p.Permanent.Cosmetics.Aura_Champion = nil
	check("A worn item that is no longer owned is ignored", Cosmetics.Equipped(p).Aura == nil)

	print(("CosmeticsTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
