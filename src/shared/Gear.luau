--[[
	Gear (ModuleScript)
	Location: ReplicatedStorage > Shared > Gear

	Rules for equipment drops, equipping and selling. Pure functions: randomness
	comes in as a function `rand()` returning a number in [0, 1) so tests can fix it.
	Each action returns true, or false plus a reason, and changes NOTHING on failure.

	Item = { Id = "g12", Slot = "Weapon", Rarity = "Rare", Power = 18 }
	Season.Equipment = { Equipped = { Weapon = item, ... }, Inventory = { item, ... }, NextId = n }

	  Gear.StatOf(item)                     -> stat name, value
	  Gear.Name(item)                       -> display name
	  Gear.Mods(equipped)                   -> list of { Stat, Mode = "Add", Value } for StatCalc
	  Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)  -> { Slot, Rarity } or nil
	  Gear.Grant(profile, stage, drop)      -> item, soldFor  (bag full: sold for gold)
	  Gear.Equip(profile, itemId)           reasons: "NotFound"
	  Gear.Unequip(profile, slot)           reasons: "BadSlot", "Empty", "BagFull"
	  Gear.Sell(profile, itemId)            -> true, gold   reasons: "NotFound"
	  Gear.SellValue(item)                  -> gold
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
	return slot.Stat, (slot.Base + slot.PerStage * item.Power) * mult
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
	-- set pieces: only from the zone itself, on frontier fights and replays alike
	local slotFor = function()
		return Config.SlotOrder[math.min(#Config.SlotOrder, math.floor(rand() * #Config.SlotOrder) + 1)]
	end
	if isBoss then
		if rand() < Config.SetBossChance then
			return { Slot = slotFor(), Rarity = "Set", SetId = Zones.IndexForStage(stage) }
		end
	elseif rand() < Config.SetDropChance then
		return { Slot = slotFor(), Rarity = "Set", SetId = Zones.IndexForStage(stage) }
	end
	local chance = if isBoss then drop.BossChance elseif isFrontier then drop.Chance else drop.ReplayChance
	if rand() >= chance then
		return nil
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
	local slot = Config.SlotOrder[math.min(#Config.SlotOrder, math.floor(rand() * #Config.SlotOrder) + 1)]
	return { Slot = slot, Rarity = rarity }
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
	return { Id = item.Id, Slot = item.Slot, Rarity = item.Rarity, Name = Gear.Name(item), Power = item.Power, Stat = stat, Value = value, SellValue = Gear.SellValue(item), SetId = item.SetId, SetName = setName }
end

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

function Gear.List(profile)
	local equipment = bag(profile)
	local result = { Equipped = {}, Inventory = {}, Cap = Config.InventoryCap, Sets = Gear.Sets(profile) }
	for slotName, item in pairs(equipment.Equipped) do
		result.Equipped[slotName] = row(item)
	end
	for _, item in ipairs(equipment.Inventory) do
		table.insert(result.Inventory, row(item))
	end
	return result
end

return Gear
