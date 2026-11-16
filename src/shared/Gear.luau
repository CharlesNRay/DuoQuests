--[[
	Gear (ModuleScript)
	Location: ReplicatedStorage > Shared > Gear

	Rules for equipment drops, equipping and selling. Pure functions: randomness
	comes in as a function `rand()` returning a number in [0, 1) so tests can fix it.
	Each action returns true, or false plus a reason, and changes NOTHING on failure.

	Item = { Id = "g12", Slot = "Weapon", Rarity = "Rare", Power = 18 }   (Slot is the item TYPE)
	Season.Equipment = { Equipped = { Weapon = item, Ring1 = item, ... }, Inventory = { item, ... }, NextId = n }
	Worn slots: Helmet, Amulet, Armor, Weapon, Pants, Ring1, Ring2, Boots (Gear.WornSlots); Ring1/Ring2 take Ring items.

	  Gear.StatOf(item)                     -> stat name, value
	  Gear.ItemPower(item)                  -> one comparable number for any item (stat / base stat * 10)
	  Gear.EnsureStarter(profile)           gives a wooden-sword-level Common weapon if you own no weapon at all
	  Gear.Name(item, classId?)             -> display name (class themed)
	  Gear.Mods(equipped)                   -> list of { Stat, Mode = "Add", Value } for StatCalc
	  Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)  -> { Slot, Rarity } or nil
	  Gear.Cap(profile) / Gear.BagUpgradeCost(profile) / Gear.UpgradeBag(profile)   bag size and its Merchant upgrade
	  Gear.RarityWeights(stage)             -> { Common=, Uncommon=, Rare=, Epic=, Legendary= } drop weights at that stage
	  Gear.Grant(profile, stage, drop)      -> item, soldFor  (bag full: sold for gold)
	  Gear.Equip(profile, itemId, wornSlot?)  reasons: "NotFound", "BadSlot"; a Ring goes to a free ring slot, else replaces the weaker
	  Gear.Replaced(equipped, type)         -> the worn item an item of that type would replace (nil if a slot is free)
	  Gear.Migrate(profile)                 old saves: Trinket -> Amulet
	  Gear.FormatStat(stat, value)          -> "+3.2% Crit" style text
	  Gear.EquipBest(profile)               -> true, slots changed: wears the highest Item Power of each type
	  Gear.Unequip(profile, slot)           reasons: "BadSlot", "Empty", "BagFull"
	  Gear.Sell(profile, itemId)            -> true, gold   reasons: "NotFound"
	  Gear.SellValue(item)                  -> gold
	  Gear.SellBulk(profile, mode)          -> true, count, gold   mode a rarity ("Common".."Legendary") (never set pieces)
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

-- Bag size: the starting cap plus Merchant upgrades.
function Gear.Cap(profile)
	return Config.InventoryCap + (bag(profile).BagUpgrades or 0) * Config.BagStep
end

function Gear.BagUpgradeCost(profile)
	local done = bag(profile).BagUpgrades or 0
	if done >= Config.BagMaxUpgrades then
		return nil
	end
	return math.floor(Config.BagCost.Base * Config.BagCost.Growth ^ done)
end

function Gear.UpgradeBag(profile)
	local cost = Gear.BagUpgradeCost(profile)
	if not cost then
		return false, "MaxBag"
	end
	local currencies = profile.Season.Currencies
	if currencies.Gold < cost then
		return false, "NotEnough"
	end
	currencies.Gold -= cost
	local equipment = bag(profile)
	equipment.BagUpgrades = (equipment.BagUpgrades or 0) + 1
	return true, Gear.Cap(profile)
end

Gear.WornSlots = Config.SlotOrder
Gear.Types = Config.Types

local STAT_LABELS_SHORT = { Haste = "Haste", MaxHealth = "Health", Attack = "Attack", Defense = "Defense", AttackSpeed = "Atk speed", CritChance = "Crit chance", DamageDealt = "Damage" }
local PERCENT_STATS = { CritChance = true, DamageDealt = true, Haste = true }

function Gear.StatLabel(stat)
	return STAT_LABELS_SHORT[stat] or stat
end

-- "+3.2% Crit chance", "+0.05/s Atk speed", "+8.1 Health"
function Gear.FormatStat(stat, value)
	if stat == nil then
		return ""
	end
	local label = Gear.StatLabel(stat)
	if PERCENT_STATS[stat] then
		return ("+%.1f%% %s"):format(value * 100, label)
	elseif stat == "AttackSpeed" then
		return ("+%.2f/s %s"):format(value, label)
	elseif value < 10 then
		return ("+%.1f %s"):format(value, label)
	end
	return ("+%d %s"):format(math.floor(value + 0.5), label)
end

-- Which worn item would an item of `itemType` replace? Nil when a slot of that type is free.
-- With two ring slots, the weaker ring (by Value) is the one replaced.
function Gear.Replaced(equipped, itemType)
	local worst
	for _, slotName in ipairs(Config.SlotOrder) do
		if Config.WornType[slotName] == itemType then
			local worn = equipped and equipped[slotName]
			if not worn then
				return nil
			end
			if not worst or (worn.Value or select(2, Gear.StatOf(worn))) < (worst.Value or select(2, Gear.StatOf(worst))) then
				worst = worn
			end
		end
	end
	return worst
end

function Gear.StatOf(item)
	local slot = Config.Slots[item.Slot]
	if slot == nil then
		return nil, 0
	end
	local mult = Config.RarityMult[item.Rarity] or 1
	local upgrade = 1 + Config.Upgrade.ValuePerLevel * (item.Upgrade or 0)
	return slot.Stat, (slot.Base + slot.PerStage * item.Power) * mult * upgrade * (item.Roll or 1)
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

-- Old saves had a Trinket slot; it became the Amulet.
function Gear.Migrate(profile)
	local equipment = bag(profile)
	if equipment.Equipped.Trinket then
		local item = equipment.Equipped.Trinket
		equipment.Equipped.Trinket = nil
		item.Slot = "Amulet"
		if equipment.Equipped.Amulet then
			table.insert(equipment.Inventory, item)
		else
			equipment.Equipped.Amulet = item
		end
	end
	for _, item in ipairs(equipment.Inventory) do
		if item.Slot == "Trinket" then
			item.Slot = "Amulet"
		end
	end
end

-- Everybody starts with a weapon. Safe to call every login: it only acts when you own no weapon.
function Gear.EnsureStarter(profile)
	Gear.Migrate(profile)
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

-- What the 3D hero should show for the worn gear: the rarity of the weapon / armour / helmet / boots
-- and the strongest set (id + pieces worn, 2+). Pure data so it can ride along in a fight roster.
function Gear.Look(equipped)
	local look = {}
	if equipped == nil then
		return look
	end
	for key, slotName in pairs({ Weapon = "Weapon", Armor = "Armor", Helmet = "Helmet", Boots = "Boots", Amulet = "Amulet" }) do
		local item = equipped[slotName]
		if item then
			look[key] = item.Rarity or "Common"
		end
	end
	local bestId, bestCount
	for setId, count in pairs(Gear.SetCounts(equipped)) do
		if count >= 2 and (bestCount == nil or count > bestCount or (count == bestCount and setId < bestId)) then
			bestId, bestCount = setId, count
		end
	end
	if bestId then
		look.SetId, look.SetCount = bestId, bestCount
	end
	return look
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

local STAT_NAMES = { Haste = "Haste", MaxHealth = "Health", AttackSpeed = "Attack speed", CritChance = "Crit chance", DamageDealt = "Damage dealt", HealingDealt = "Healing", DamageTaken = "Damage taken" }

function Gear.DescribeMods(mods)
	local parts = {}
	for _, mod in ipairs(mods) do
		local name = STAT_NAMES[mod.Stat] or mod.Stat
		local value = mod.Value * 100
		table.insert(parts, ("%s %s%s%%"):format(name, if value >= 0 then "+" else "-", tostring(math.abs(math.floor(value * 10 + 0.5) / 10))))
	end
	return table.concat(parts, ", ")
end

function Gear.Name(item, classId)
	if item.SetId then
		local def, loop = Gear.SetFor(item.SetId)
		local piece = def.Pieces[item.Slot] or (def.Name .. " " .. item.Slot)
		local noun = classId and Config.ClassWeaponNoun[classId]
		if item.Slot == "Weapon" and noun then
			piece = def.Name .. " " .. noun
		end
		return if loop > 1 then piece .. " " .. loop else piece
	end
	local byClass = classId and Config.ClassNames[classId]
	local names = (byClass and byClass[item.Slot]) or Config.Names[item.Slot]
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
		if count >= Config.SetThresholds[1] then
			for _, mod in ipairs(def.Bonus2) do
				table.insert(mods, table.clone(mod))
			end
		end
		if count >= Config.SetThresholds[2] then
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

-- Rarity weights for drops at this stage: linear blend between the two nearest anchors.
function Gear.RarityWeights(stage)
	local anchors, order = Config.Drop.Anchors, Config.Drop.Order
	local lowA, highA = anchors[1], anchors[#anchors]
	local from, to, t = lowA, lowA, 0
	if stage >= highA.Stage then
		from, to = highA, highA
	elseif stage > lowA.Stage then
		for index = 1, #anchors - 1 do
			if stage >= anchors[index].Stage and stage <= anchors[index + 1].Stage then
				from, to = anchors[index], anchors[index + 1]
				t = (stage - from.Stage) / (to.Stage - from.Stage)
				break
			end
		end
	end
	local weights = {}
	for _, id in ipairs(order) do
		local a, b = from.Weights[id] or 0, to.Weights[id] or 0
		weights[id] = a + (b - a) * t
	end
	return weights
end

function Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)
	local drop = Config.Drop
	local isBoss = stage % StageConfig.BossEvery == 0
	local chance = if isBoss then drop.BossChance elseif isFrontier then drop.Chance else drop.ReplayChance
	if rand() >= chance then
		return nil
	end
	local slotFor = function()
		return Config.Types[math.min(#Config.Types, math.floor(rand() * #Config.Types) + 1)]
	end
	-- Set pieces are ordinary gear: some drops simply turn out to be a piece of the zone's set.
	-- (They only come from the zone itself, on frontier fights and replays alike.)
	if rand() < (if isBoss then Config.SetBossChance else Config.SetDropChance) then
		return { Slot = slotFor(), Rarity = "Set", SetId = Zones.IndexForStage(stage), Roll = Config.Roll.Min + rand() * (Config.Roll.Max - Config.Roll.Min) }
	end
	-- rarity roll: weights come from the stage (blended between the anchors in Config.Drop); the
	-- ItemRarity bonus shifts weight from the lowest tier you can find towards the tiers above it
	local weights = Gear.RarityWeights(stage)
	local order = drop.Order
	local lowest
	for index, id in ipairs(order) do
		if weights[id] > 0 then
			lowest = index
			break
		end
	end
	local shift = math.min(weights[order[lowest]] * 0.9, (itemRarityBonus or 0) * 10 * drop.BonusShift / 6)
	weights[order[lowest]] -= shift
	local up1, up2 = order[math.min(#order, lowest + 1)], order[math.min(#order, lowest + 2)]
	weights[up1] += shift * 0.75
	weights[up2] += shift * 0.25
	local total = 0
	for _, id in ipairs(order) do
		total += weights[id]
	end
	local roll = rand() * total
	local rarity = order[#order]
	local running = 0
	for _, id in ipairs(order) do
		running += weights[id]
		if roll < running then
			rarity = id
			break
		end
	end
	return { Slot = slotFor(), Rarity = rarity, Roll = Config.Roll.Min + rand() * (Config.Roll.Max - Config.Roll.Min) }
end

-- Put a drop into the bag (or sell it if the bag is full).
function Gear.Grant(profile, stage, drop)
	local equipment = bag(profile)
	equipment.NextId = (equipment.NextId or 0) + 1
	local item = { Id = "g" .. equipment.NextId, Slot = drop.Slot, Rarity = drop.Rarity, Power = stage, SetId = drop.SetId, Roll = drop.Roll }
	if #equipment.Inventory >= Gear.Cap(profile) then
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

function Gear.Equip(profile, itemId, wornSlot)
	local equipment = bag(profile)
	local index, item = findInBag(equipment, itemId)
	if not index then
		return false, "NotFound"
	end
	-- pick the worn slot: the one asked for (if it takes this type), a free one, else the weaker one
	local target
	if wornSlot ~= nil then
		if Config.WornType[wornSlot] ~= item.Slot then
			return false, "BadSlot"
		end
		target = wornSlot
	else
		local weakest, weakestValue
		for _, slotName in ipairs(Config.SlotOrder) do
			if Config.WornType[slotName] == item.Slot then
				local worn = equipment.Equipped[slotName]
				if not worn then
					target = slotName
					break
				end
				local _, value = Gear.StatOf(worn)
				if not weakest or value < weakestValue then
					weakest, weakestValue = slotName, value
				end
			end
		end
		target = target or weakest
	end
	if target == nil then
		return false, "BadSlot"
	end
	local previous = equipment.Equipped[target]
	table.remove(equipment.Inventory, index)
	equipment.Equipped[target] = item
	if previous then
		table.insert(equipment.Inventory, previous)
	end
	return true
end

-- Wear the highest Item Power of every type: for each worn slot type (a type with two slots, rings, keeps the best two),
-- the best items from the worn gear and the bag are put on and the rest go back in the bag. Ties keep what is already
-- worn. Set bonuses are not counted, only Item Power. -> true, number of slots that changed
function Gear.EquipBest(profile)
	local equipment = bag(profile)
	local worn, spare = {}, {}
	for _, slotName in ipairs(Config.SlotOrder) do
		local item = equipment.Equipped[slotName]
		if item then
			worn[item.Id] = slotName
		end
	end
	local oldSlot = {}
	for slotName, item in pairs(equipment.Equipped) do
		oldSlot[slotName] = item
	end
	local pool = {}
	for _, item in pairs(equipment.Equipped) do
		table.insert(pool, item)
	end
	for _, item in ipairs(equipment.Inventory) do
		table.insert(pool, item)
	end
	local newEquipped, used = {}, {}
	local types = {}
	for _, slotName in ipairs(Config.SlotOrder) do
		local itemType = Config.WornType[slotName]
		if not types[itemType] then
			types[itemType] = {}
		end
		table.insert(types[itemType], slotName)
	end
	for itemType, slots in pairs(types) do
		local candidates = {}
		for _, item in ipairs(pool) do
			if item.Slot == itemType then
				table.insert(candidates, item)
			end
		end
		table.sort(candidates, function(a, b)
			local pa, pb = Gear.ItemPower(a), Gear.ItemPower(b)
			if pa ~= pb then
				return pa > pb
			end
			local wa, wb = worn[a.Id] ~= nil, worn[b.Id] ~= nil
			if wa ~= wb then
				return wa
			end
			return tostring(a.Id) < tostring(b.Id)
		end)
		for index, slotName in ipairs(slots) do
			local item = candidates[index]
			if item then
				-- an item already worn in one of this type's slots stays where it is
				newEquipped[slotName] = item
				used[item.Id] = true
			end
		end
		-- keep a worn item in its own slot when it is still among the chosen ones
		for _, slotName in ipairs(slots) do
			local current = oldSlot[slotName]
			if current and used[current.Id] and newEquipped[slotName] ~= current then
				for other, item in pairs(newEquipped) do
					if item == current and Config.WornType[other] == itemType then
						newEquipped[other] = newEquipped[slotName]
						newEquipped[slotName] = current
						break
					end
				end
			end
		end
	end
	for _, item in ipairs(equipment.Inventory) do
		if not used[item.Id] then
			table.insert(spare, item)
		end
	end
	for _, item in pairs(oldSlot) do
		if not used[item.Id] then
			table.insert(spare, item)
		end
	end
	local changed = 0
	for _, slotName in ipairs(Config.SlotOrder) do
		if newEquipped[slotName] ~= oldSlot[slotName] then
			changed += 1
		end
	end
	equipment.Equipped = newEquipped
	equipment.Inventory = spare
	return true, changed
end

function Gear.Unequip(profile, slotName)
	if type(slotName) ~= "string" or Config.WornType[slotName] == nil then
		return false, "BadSlot"
	end
	local equipment = bag(profile)
	local item = equipment.Equipped[slotName]
	if not item then
		return false, "Empty"
	end
	if #equipment.Inventory >= Gear.Cap(profile) then
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

local function row(item, classId)
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
		Id = item.Id, Slot = item.Slot, Rarity = item.Rarity, Name = Gear.Name(item, classId), Power = item.Power, Stat = stat, Value = value,
		ItemPower = Gear.ItemPower(item), StatText = Gear.FormatStat(stat, value), SellValue = Gear.SellValue(item), SetId = item.SetId, SetName = setName,
		Roll = item.Roll or 1, Upgrade = item.Upgrade or 0, MaxUpgrade = Config.Upgrade.MaxLevel, UpgradeCost = cost, NextValue = nextValue,
	}
end

Gear.Row = row

-- Every set up to the furthest zone reached, with how many of its pieces are worn.
function Gear.Sets(profile)
	local equipment = bag(profile)
	local counts = Gear.SetCounts(equipment.Equipped)
	local last = Zones.IndexForStage(profile.Season.HighestStage)
	local list = {}
	for setId = 1, last do
		local def, loop = Gear.SetFor(setId)
		local zone = Zones.ForStage((setId - 1) * StageConfig.BossEvery + 1)
		table.insert(list, {
			Id = setId,
			Name = if loop > 1 then def.Name .. " " .. loop else def.Name,
			ZoneName = zone.Name,
			FirstStage = zone.FirstStage,
			LastStage = zone.LastStage,
			Worn = counts[setId] or 0,
			Need1 = Config.SetThresholds[1],
			Need2 = Config.SetThresholds[2],
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
	local rarities = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true }
	-- mode: one rarity, "Worse", or a list of rarities (the Merchant's ticked boxes)
	local wanted = {}
	if type(mode) == "table" then
		for _, id in ipairs(mode) do
			if not rarities[id] then
				return false, "BadMode"
			end
			wanted[id] = true
		end
		if next(wanted) == nil then
			return false, "BadMode"
		end
		mode = "List"
	elseif mode ~= "Worse" and not rarities[mode] then
		return false, "BadMode"
	else
		wanted[mode] = true
	end
	local equipment = bag(profile)
	local kept, count, gold = {}, 0, 0
	for _, item in ipairs(equipment.Inventory) do
		local sell = false
		if not item.SetId and (item.Upgrade or 0) == 0 then
			if mode ~= "Worse" then
				sell = wanted[item.Rarity] == true
			else
				local worn = Gear.Replaced(equipment.Equipped, item.Slot)
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
	local classId = profile.Season and profile.Season.ClassId
	local result = { Equipped = {}, Inventory = {}, Cap = Gear.Cap(profile), BagCost = Gear.BagUpgradeCost(profile), BagStep = Config.BagStep, Sets = Gear.Sets(profile) }
	for slotName, item in pairs(equipment.Equipped) do
		result.Equipped[slotName] = row(item, classId)
	end
	for _, item in ipairs(equipment.Inventory) do
		table.insert(result.Inventory, row(item, classId))
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
