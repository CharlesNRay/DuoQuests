--[[
	Gear (ModuleScript)
	Location: ReplicatedStorage > Shared > Gear

	Rules for equipment drops, equipping and selling. Pure functions: randomness
	comes in as a function `rand()` returning a number in [0, 1) so tests can fix it.
	Each action returns true, or false plus a reason, and changes NOTHING on failure.

	Item = { Id = "g12", Slot = "Weapon", Rarity = "Rare", Power = 18 }
	Season.Equipment = { Equipped = { Weapon = item, ... }, Inventory = { item, ... }, NextId = n }

	  Gear.StatOf(item)                     -> stat name, value
	  Gear.ItemPower(item)                  -> one comparable number for any item (stat / base stat * 10)
	  Gear.EnsureStarter(profile)           gives a wooden-sword-level Common weapon if you own no weapon at all
	  Gear.Name(item)                       -> display name
	  Gear.Mods(equipped)                   -> list of { Stat, Mode = "Add", Value } for StatCalc
	  Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)  -> { Slot, Rarity } or nil
	  Gear.Grant(profile, stage, drop)      -> item, soldFor  (bag full: sold for gold)
	  Gear.Equip(profile, itemId)           reasons: "NotFound"
	  Gear.Unequip(profile, slot)           reasons: "BadSlot", "Empty", "BagFull"
	  Gear.Sell(profile, itemId)            -> true, gold   reasons: "NotFound"
	  Gear.SellValue(item)                  -> gold
	  Gear.SellBulk(profile, mode)          -> true, count, gold   mode "Common" | "Worse" (never set pieces)
	  Gear.UpgradeCost(item)                -> gold for the next level (nil at max)
	  Gear.Upgrade(profile, itemId)         -> true, newLevel   reasons: "NotFound", "MaxLevel", "NoGold"
	                                           works on worn and bagged items
	  Gear.Row(item)                        -> the UI row for one item
	  Gear.List(profile)                    -> { Equipped = {slot = row}, Inventory = {rows}, Sets = {...} } for the UI
	  Gear.SetFor(setId)                    -> definition + Loop for a set (setId = zone number)
	  Gear.SetCounts(equipped)              -> { [setId] = pieces worn }
	  Gear.DescribeMods(mods)               -> text like "Attack +5%, Defense +5%"
]]

local Config = require(script.Parent.Config.Gear)
local StageConfig = require(script.Parent.Config.Stages)
local Zones = require(script.Parent.Zones)

local Gear = {}

local function bag(profile)
	local equipment = profile.Season.Equipment
	equipment.Equipped = equipment.Equipped or {}
	equipment.Inventory = equipment.Inventory or {}
	return equipment
end

function Gear.StatOf(item)
	local slot = Config.Slots[item.Slot]
	if slot == nil then
		return nil, 0
	end
	local mult = Config.RarityMult[item.Rarity] or 1
	local upgrade = 1 + Config.Upgrade.ValuePerLevel * (item.Upgrade or 0)
	return slot.Stat, (slot.Base + slot.PerStage * item.Power) * mult * upgrade
end

-- Item Power: one number that compares any two items (a weapon against armour too), counting rarity,
-- the stage it dropped at and Blacksmith upgrades. A Common item from stage 1 is about 12.
function Gear.ItemPower(item)
	local slot = Config.Slots[item.Slot]
	if slot == nil then
		return 0
	end
	local _, value = Gear.StatOf(item)
	return math.floor(10 * value / slot.Base + 0.5)
end

-- Everybody starts with a weapon. Safe to call every login: it only acts when you own no weapon.
function Gear.EnsureStarter(profile)
	local equipment = bag(profile)
	if equipment.Equipped.Weapon then
		return false
	end
	for _, item in ipairs(equipment.Inventory) do
		if item.Slot == "Weapon" then
			return false
		end
	end
	equipment.NextId = (equipment.NextId or 0) + 1
	equipment.Equipped.Weapon = { Id = "g" .. equipment.NextId, Slot = "Weapon", Rarity = "Common", Power = 1 }
	return true
end

-- A set belongs to a zone (10 stages). Past the authored sets the list repeats.
function Gear.SetFor(setId)
	local sets = Config.Sets
	local def = sets[(setId - 1) % #sets + 1]
	return def, (setId - 1) // #sets + 1
end

function Gear.SetCounts(equipped)
	local counts = {}
	for _, slotName in ipairs(Config.SlotOrder) do
		local item = equipped and equipped[slotName]
		if item and item.SetId then
			counts[item.SetId] = (counts[item.SetId] or 0) + 1
		end
	end
	return counts
end

local STAT_NAMES = { MaxHealth = "Health", AttackSpeed = "Attack speed", CritChance = "Crit chance", DamageDealt = "Damage dealt", HealingDealt = "Healing", DamageTaken = "Damage taken" }

function Gear.DescribeMods(mods)
	local parts = {}
	for _, mod in ipairs(mods) do
		local name = STAT_NAMES[mod.Stat] or mod.Stat
		local value = mod.Value * 100
		table.insert(parts, ("%s %s%s%%"):format(name, if value >= 0 then "+" else "-", tostring(math.abs(math.floor(value * 10 + 0.5) / 10))))
	end
	return table.concat(parts, ", ")
end

function Gear.Name(item)
	if item.SetId then
		local def, loop = Gear.SetFor(item.SetId)
		local piece = def.Pieces[item.Slot] or (def.Name .. " " .. item.Slot)
		return if loop > 1 then piece .. " " .. loop else piece
	end
	local names = Config.Names[item.Slot]
	return names and names[item.Rarity] or (item.Rarity .. " " .. item.Slot)
end

function Gear.Mods(equipped)
	local mods = {}
	for _, slotName in ipairs(Config.SlotOrder) do
		local item = equipped and equipped[slotName]
		if item then
			local stat, value = Gear.StatOf(item)
			if stat then
				table.insert(mods, { Stat = stat, Mode = "Add", Value = value })
			end
		end
	end
	-- set bonuses: 2 pieces of one set, then 3
	for setId, count in pairs(Gear.SetCounts(equipped)) do
		local def = Gear.SetFor(setId)
		if count >= 2 then
			for _, mod in ipairs(def.Bonus2) do
				table.insert(mods, table.clone(mod))
			end
		end
		if count >= 3 then
			for _, mod in ipairs(def.Bonus3) do
				table.insert(mods, table.clone(mod))
			end
		end
	end
	return mods
end

function Gear.SellValue(item)
	return math.max(1, math.floor((Config.SellValue[item.Rarity] or 1) + Config.SellPerStage * item.Power))
end

function Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)
	local drop = Config.Drop
	local isBoss = stage % StageConfig.BossEvery == 0
	local chance = if isBoss then drop.BossChance elseif isFrontier then drop.Chance else drop.ReplayChance
	if rand() >= chance then
		return nil
	end
	local slotFor = function()
		return Config.SlotOrder[math.min(#Config.SlotOrder, math.floor(rand() * #Config.SlotOrder) + 1)]
	end
	-- Set pieces are ordinary gear: some drops simply turn out to be a piece of the zone's set.
	-- (They only come from the zone itself, on frontier fights and replays alike.)
	if rand() < (if isBoss then Config.SetBossChance else Config.SetDropChance) then
		return { Slot = slotFor(), Rarity = "Set", SetId = Zones.IndexForStage(stage) }
	end
	-- rarity roll: the ItemRarity bonus shifts weight from Common to Rare/Epic
	local weights = table.clone(drop.Weights)
	local shift = math.min(weights.Common - 1, (itemRarityBonus or 0) * 10 * drop.BonusShift / 6)
	weights.Common -= shift
	weights.Rare += shift * 0.75
	weights.Epic += shift * 0.25
	local total = weights.Common + weights.Rare + weights.Epic
	local roll = rand() * total
	local rarity = "Common"
	if roll >= weights.Common + weights.Rare then
		rarity = "Epic"
	elseif roll >= weights.Common then
		rarity = "Rare"
	end
	return { Slot = slotFor(), Rarity = rarity }
end

-- Put a drop into the bag (or sell it if the bag is full).
function Gear.Grant(profile, stage, drop)
	local equipment = bag(profile)
	equipment.NextId = (equipment.NextId or 0) + 1
	local item = { Id = "g" .. equipment.NextId, Slot = drop.Slot, Rarity = drop.Rarity, Power = stage, SetId = drop.SetId }
	if drop.SetId then
		equipment.Collected = equipment.Collected or {}
		equipment.Collected[drop.SetId .. ":" .. drop.Slot] = true
	end
	if #equipment.Inventory >= Config.InventoryCap then
		local gold = Gear.SellValue(item)
		profile.Season.Currencies.Gold += gold
		return item, gold
	end
	table.insert(equipment.Inventory, item)
	return item, nil
end

local function findInBag(equipment, itemId)
	for index, item in ipairs(equipment.Inventory) do
		if item.Id == itemId then
			return index, item
		end
	end
	return nil
end

function Gear.Equip(profile, itemId)
	local equipment = bag(profile)
	local index, item = findInBag(equipment, itemId)
	if not index then
		return false, "NotFound"
	end
	local previous = equipment.Equipped[item.Slot]
	table.remove(equipment.Inventory, index)
	equipment.Equipped[item.Slot] = item
	if previous then
		table.insert(equipment.Inventory, previous)
	end
	return true
end

function Gear.Unequip(profile, slotName)
	if type(slotName) ~= "string" or Config.Slots[slotName] == nil then
		return false, "BadSlot"
	end
	local equipment = bag(profile)
	local item = equipment.Equipped[slotName]
	if not item then
		return false, "Empty"
	end
	if #equipment.Inventory >= Config.InventoryCap then
		return false, "BagFull"
	end
	equipment.Equipped[slotName] = nil
	table.insert(equipment.Inventory, item)
	return true
end

function Gear.Sell(profile, itemId)
	local equipment = bag(profile)
	local index, item = findInBag(equipment, itemId)
	if not index then
		return false, "NotFound"
	end
	local gold = Gear.SellValue(item)
	table.remove(equipment.Inventory, index)
	profile.Season.Currencies.Gold += gold
	return true, gold
end

local function row(item)
	local stat, value = Gear.StatOf(item)
	local setName
	if item.SetId then
		local def, loop = Gear.SetFor(item.SetId)
		setName = if loop > 1 then def.Name .. " " .. loop else def.Name
	end
	local cost = Gear.UpgradeCost(item)
	local nextValue = nil
	if cost then
		local copy = table.clone(item)
		copy.Upgrade = (item.Upgrade or 0) + 1
		local _, v = Gear.StatOf(copy)
		nextValue = v
	end
	return {
		Id = item.Id, Slot = item.Slot, Rarity = item.Rarity, Name = Gear.Name(item), Power = item.Power, Stat = stat, Value = value,
		ItemPower = Gear.ItemPower(item), SellValue = Gear.SellValue(item), SetId = item.SetId, SetName = setName,
		Upgrade = item.Upgrade or 0, MaxUpgrade = Config.Upgrade.MaxLevel, UpgradeCost = cost, NextValue = nextValue,
	}
end

Gear.Row = row

-- Every set up to the furthest zone reached, with what has been collected and worn.
function Gear.Sets(profile)
	local equipment = bag(profile)
	local counts = Gear.SetCounts(equipment.Equipped)
	local collected = equipment.Collected or {}
	local last = Zones.IndexForStage(profile.Season.HighestStage)
	local list = {}
	for setId = 1, last do
		local def, loop = Gear.SetFor(setId)
		local zone = Zones.ForStage((setId - 1) * StageConfig.BossEvery + 1)
		local pieces = {}
		local have = 0
		for _, slotName in ipairs(Config.SlotOrder) do
			local owned = collected[setId .. ":" .. slotName] == true
			if owned then
				have += 1
			end
			local worn = equipment.Equipped[slotName]
			table.insert(pieces, { Slot = slotName, Name = if loop > 1 then def.Pieces[slotName] .. " " .. loop else def.Pieces[slotName], Collected = owned, Worn = worn ~= nil and worn.SetId == setId })
		end
		table.insert(list, {
			Id = setId,
			Name = if loop > 1 then def.Name .. " " .. loop else def.Name,
			ZoneName = zone.Name,
			FirstStage = zone.FirstStage,
			LastStage = zone.LastStage,
			Pieces = pieces,
			Collected = have,
			Worn = counts[setId] or 0,
			Bonus2 = Gear.DescribeMods(def.Bonus2),
			Bonus3 = Gear.DescribeMods(def.Bonus3),
		})
	end
	return list
end

function Gear.UpgradeCost(item)
	local level = item.Upgrade or 0
	local cfg = Config.Upgrade
	if level >= cfg.MaxLevel then
		return nil
	end
	return math.floor(cfg.BaseCost * cfg.CostGrowth ^ level + cfg.PowerCost * item.Power)
end

function Gear.Upgrade(profile, itemId)
	local equipment = bag(profile)
	local item
	for _, worn in pairs(equipment.Equipped) do
		if worn.Id == itemId then
			item = worn
		end
	end
	if not item then
		local _, found = findInBag(equipment, itemId)
		item = found
	end
	if not item then
		return false, "NotFound"
	end
	local cost = Gear.UpgradeCost(item)
	if not cost then
		return false, "MaxLevel"
	end
	local currencies = profile.Season.Currencies
	if currencies.Gold < cost then
		return false, "NoGold"
	end
	currencies.Gold -= cost
	item.Upgrade = (item.Upgrade or 0) + 1
	return true, item.Upgrade
end

-- Sell many bagged items at once. "Common": every Common item. "Worse": every item that
-- is no better than what is worn in its slot. Set pieces and upgraded items are never sold in bulk.
function Gear.SellBulk(profile, mode)
	if mode ~= "Common" and mode ~= "Worse" then
		return false, "BadMode"
	end
	local equipment = bag(profile)
	local kept, count, gold = {}, 0, 0
	for _, item in ipairs(equipment.Inventory) do
		local sell = false
		if not item.SetId and (item.Upgrade or 0) == 0 then
			if mode == "Common" then
				sell = item.Rarity == "Common"
			else
				local worn = equipment.Equipped[item.Slot]
				if worn then
					local _, mine = Gear.StatOf(item)
					local _, theirs = Gear.StatOf(worn)
					sell = mine <= theirs
				end
			end
		end
		if sell then
			count += 1
			gold += Gear.SellValue(item)
		else
			table.insert(kept, item)
		end
	end
	equipment.Inventory = kept
	profile.Season.Currencies.Gold += gold
	return true, count, gold
end

function Gear.List(profile)
	local equipment = bag(profile)
	local result = { Equipped = {}, Inventory = {}, Cap = Config.InventoryCap, Sets = Gear.Sets(profile) }
	for slotName, item in pairs(equipment.Equipped) do
		result.Equipped[slotName] = row(item)
	end
	for _, item in ipairs(equipment.Inventory) do
		table.insert(result.Inventory, row(item))
	end
	-- strongest first, so upgrades are at the top left of the bag
	table.sort(result.Inventory, function(a, b)
		if a.ItemPower ~= b.ItemPower then
			return a.ItemPower > b.ItemPower
		end
		return a.Id < b.Id
	end)
	return result
end

return Gear
