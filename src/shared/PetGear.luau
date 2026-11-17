--[[
	PetGear (ModuleScript)
	Location: ReplicatedStorage > Shared > PetGear

	Gear the active pet wears: 4 slots (collar, charm, saddle, toy) that open as the pet levels. The stats help the player.
	Data: Config/PetGear. Lives in Permanent.PetGear = { Bag = { piece... }, Equipped = { [slot] = piece }, NextId = n, Store = { Day, Eggs } }.

	  PetGear.Slots(profile)                 -> number of slots open (by the active pet's level)
	  PetGear.Mods(profile)                  -> list of { Stat, Mode, Value } from the worn pieces in open slots
	  PetGear.Roll(odds, rand)               -> a new piece { Kind, Rarity, Stat, Value } (no Id yet)
	  PetGear.Give(profile, piece)           put a piece in the bag (false, "BagFull" when full)
	  PetGear.Equip(profile, pieceId)        wear a bagged piece in its slot (reasons: "NotFound", "SlotLocked")
	  PetGear.Unequip(profile, slot)         back to the bag (reasons: "Empty", "BagFull")
	  PetGear.Sell(profile, pieceId)         gold for a bagged piece
	  PetGear.BuyCrate(profile, crateId, rand)  Pet Store: roll a piece for gold
	  PetGear.BuyEgg(profile, now)           Pet Store: a Pet Wish ticket for gold (limited per day)
	  PetGear.BossDrop(profile, rand)        maybe a piece from a boss
	  PetGear.Describe(piece)                -> "+6.0% Damage"
	  PetGear.View(profile, now)             -> everything the UI needs
]]

local Config = require(script.Parent.Config.PetGear)
local PetsConfig = require(script.Parent.Config.Pets)
local Consumables = require(script.Parent.Consumables)

local PetGear = {}
PetGear.Config = Config

local function store(profile)
	local perm = profile.Permanent
	perm.PetGear = perm.PetGear or { Bag = {}, Equipped = {}, NextId = 1, Store = { Day = 0, Eggs = 0 } }
	local g = perm.PetGear
	g.Bag, g.Equipped, g.NextId, g.Store = g.Bag or {}, g.Equipped or {}, g.NextId or 1, g.Store or { Day = 0, Eggs = 0 }
	return g
end

-- slots open: the active pet's level against Config/Pets GearSlotLevels
function PetGear.Slots(profile)
	local Pets = require(script.Parent.Pets)
	local petId, level = Pets.Active(profile)
	if petId == nil then
		return 0
	end
	local open = 0
	for index, need in ipairs(PetsConfig.GearSlotLevels) do
		if level >= need then
			open = index
		end
	end
	return math.min(open, Config.Slots)
end

function PetGear.Describe(piece)
	local unit = Config.StatUnits[piece.Stat]
	return ("+%.1f%% %s"):format(piece.Value * 100, unit and unit.Label or piece.Stat)
end

function PetGear.Mods(profile)
	local g = profile.Permanent.PetGear
	if g == nil then
		return {}
	end
	local mods = {}
	for slot = 1, PetGear.Slots(profile) do
		local piece = g.Equipped and g.Equipped[slot]
		if piece then
			table.insert(mods, { Stat = piece.Stat, Mode = Config.StatUnits[piece.Stat].Mode, Value = piece.Value })
		end
	end
	return mods
end

local function pickWeighted(odds, rand)
	local total = 0
	for _, name in ipairs(Config.Rarities) do
		total += odds[name] or 0
	end
	local roll = rand() * total
	for _, name in ipairs(Config.Rarities) do
		roll -= odds[name] or 0
		if roll < 0 then
			return name
		end
	end
	return "Common"
end

function PetGear.Roll(odds, rand)
	rand = rand or math.random
	local rarity = pickWeighted(odds, rand)
	local kind = Config.Kinds[math.floor(rand() * #Config.Kinds) + 1] or Config.Kinds[1]
	local stat = Config.StatOrder[math.floor(rand() * #Config.StatOrder) + 1] or Config.StatOrder[1]
	local value = Config.StatUnits[stat].Base * Config.RarityMult[rarity] * (0.9 + rand() * 0.2)
	return { Kind = kind, Rarity = rarity, Stat = stat, Value = math.floor(value * 10000 + 0.5) / 10000 }
end

function PetGear.Give(profile, piece)
	local g = store(profile)
	if #g.Bag >= Config.BagSize then
		return false, "BagFull"
	end
	piece.Id = "pg" .. g.NextId
	g.NextId += 1
	table.insert(g.Bag, piece)
	return true, piece
end

local function slotOf(kind)
	for index, name in ipairs(Config.Kinds) do
		if name == kind then
			return index
		end
	end
end

local function indexOf(bag, id)
	for index, piece in ipairs(bag) do
		if piece.Id == id then
			return index
		end
	end
end

function PetGear.Equip(profile, pieceId)
	local g = store(profile)
	local index = type(pieceId) == "string" and indexOf(g.Bag, pieceId)
	if not index then
		return false, "NotFound"
	end
	local piece = g.Bag[index]
	local slot = slotOf(piece.Kind)
	if slot > PetGear.Slots(profile) then
		return false, "SlotLocked"
	end
	table.remove(g.Bag, index)
	local old = g.Equipped[slot]
	if old then
		table.insert(g.Bag, old)
	end
	g.Equipped[slot] = piece
	return true, slot
end

function PetGear.Unequip(profile, slot)
	local g = store(profile)
	if type(slot) ~= "number" or g.Equipped[slot] == nil then
		return false, "Empty"
	end
	if #g.Bag >= Config.BagSize then
		return false, "BagFull"
	end
	table.insert(g.Bag, g.Equipped[slot])
	g.Equipped[slot] = nil
	return true
end

function PetGear.SellValue(piece)
	return math.floor(Config.SellBase * Config.RarityMult[piece.Rarity])
end

function PetGear.Sell(profile, pieceId)
	local g = store(profile)
	local index = type(pieceId) == "string" and indexOf(g.Bag, pieceId)
	if not index then
		return false, "NotFound"
	end
	local gold = PetGear.SellValue(g.Bag[index])
	table.remove(g.Bag, index)
	profile.Season.Currencies.Gold += gold
	return true, gold
end

function PetGear.CratePrice(crateId, frontier)
	local def = Config.Crates[crateId]
	return def and math.floor(def.Price.Base + def.Price.PerStage * (frontier or 1))
end

function PetGear.BuyCrate(profile, crateId, rand)
	local def = Config.Crates[crateId]
	if def == nil then
		return false, "Unknown"
	end
	local g = store(profile)
	if #g.Bag >= Config.BagSize then
		return false, "BagFull"
	end
	local price = PetGear.CratePrice(crateId, profile.Season.HighestStage)
	if profile.Season.Currencies.Gold < price then
		return false, "NotEnough"
	end
	profile.Season.Currencies.Gold -= price
	local _, piece = PetGear.Give(profile, PetGear.Roll(def.Odds, rand))
	return true, piece
end

local function today(now)
	return math.floor((now or os.time()) / 86400)
end

function PetGear.EggsLeft(profile, now)
	local g = store(profile)
	if g.Store.Day ~= today(now) then
		return Config.Egg.PerDay
	end
	return math.max(0, Config.Egg.PerDay - g.Store.Eggs)
end

function PetGear.EggPrice(frontier)
	return math.floor(Config.Egg.Price.Base + Config.Egg.Price.PerStage * (frontier or 1))
end

function PetGear.BuyEgg(profile, now)
	local g = store(profile)
	if PetGear.EggsLeft(profile, now) <= 0 then
		return false, "SoldOut"
	end
	local price = PetGear.EggPrice(profile.Season.HighestStage)
	if profile.Season.Currencies.Gold < price then
		return false, "NotEnough"
	end
	if g.Store.Day ~= today(now) then
		g.Store.Day, g.Store.Eggs = today(now), 0
	end
	profile.Season.Currencies.Gold -= price
	g.Store.Eggs += 1
	Consumables.Grant(profile, "PetWish", 1)
	return true, price
end

-- a boss kill sometimes drops a piece; false when nothing dropped or the bag is full
function PetGear.BossDrop(profile, rand)
	rand = rand or math.random
	if rand() >= Config.BossDropChance then
		return false
	end
	local ok, piece = PetGear.Give(profile, PetGear.Roll(Config.BossOdds, rand))
	return ok, piece
end

function PetGear.View(profile, now)
	local g = store(profile)
	local Pets = require(script.Parent.Pets)
	local _, petLevel = Pets.Active(profile)
	local frontier = profile.Season.HighestStage
	local crates = {}
	for _, id in ipairs(Config.CrateOrder) do
		local def = Config.Crates[id]
		table.insert(crates, { Id = id, Name = def.DisplayName, Glyph = def.Glyph, Price = PetGear.CratePrice(id, frontier), Odds = def.Odds })
	end
	return {
		Open = PetGear.Slots(profile),
		SlotNeeds = PetsConfig.GearSlotLevels,
		PetLevel = petLevel or 1,
		Kinds = Config.Kinds,
		Equipped = g.Equipped,
		Bag = g.Bag,
		BagSize = Config.BagSize,
		Crates = crates,
		EggPrice = PetGear.EggPrice(frontier),
		EggsLeft = PetGear.EggsLeft(profile, now),
	}
end

return PetGear
