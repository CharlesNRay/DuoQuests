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
	  Gear.List(profile)                    -> { Equipped = {slot = row}, Inventory = {rows} } for the UI
]]

local Config = require(script.Parent.Config.Gear)
local StageConfig = require(script.Parent.Config.Stages)

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

function Gear.Name(item)
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
	return mods
end

function Gear.SellValue(item)
	return math.max(1, math.floor((Config.SellValue[item.Rarity] or 1) + Config.SellPerStage * item.Power))
end

function Gear.RollDrop(stage, isFrontier, itemRarityBonus, rand)
	local drop = Config.Drop
	local chance = if stage % StageConfig.BossEvery == 0 then drop.BossChance elseif isFrontier then drop.Chance else drop.ReplayChance
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
	local item = { Id = "g" .. equipment.NextId, Slot = drop.Slot, Rarity = drop.Rarity, Power = stage }
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
	return { Id = item.Id, Slot = item.Slot, Rarity = item.Rarity, Name = Gear.Name(item), Power = item.Power, Stat = stat, Value = value, SellValue = Gear.SellValue(item) }
end

function Gear.List(profile)
	local equipment = bag(profile)
	local result = { Equipped = {}, Inventory = {}, Cap = Config.InventoryCap }
	for slotName, item in pairs(equipment.Equipped) do
		result.Equipped[slotName] = row(item)
	end
	for _, item in ipairs(equipment.Inventory) do
		table.insert(result.Inventory, row(item))
	end
	return result
end

return Gear
