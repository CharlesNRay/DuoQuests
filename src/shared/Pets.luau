--[[
	Pets (ModuleScript)
	Location: ReplicatedStorage > Shared > Pets

	Rules for owning, equipping, levelling and applying pets. Pure functions.
	The data lives in Config/Pets. Each action returns true, or false plus a
	reason, and changes NOTHING when it fails.

	  Pets.MaxLevel
	  Pets.Level(profile, petId)            -> level (1 if never levelled)
	  Pets.Active(profile)                  -> petId, level   or nil
	  Pets.Mods(petId, level)               -> list of { Stat, Mode, Value } for StatCalc
	  Pets.Describe(petId, level)           -> short text, e.g. "+5% Max Health"
	  Pets.GrantForClear(profile, stage)    -> list of pet ids newly received
	  Pets.Equip(profile, petId)            reasons: "UnknownPet", "NotOwned"
	  Pets.Rank / Pets.Copies / Pets.AddDuplicate / Pets.RankUp   duplicates bank as copies; the player ranks a pet up by hand
	  Pets.Shards / BuyWithShards / Condense   copies beyond max rank become rarity shards; 30 buy a pet, 10 condense into the next rarity
	  Pets.Collection(profile)              -> { Points, Percent, Mods }  a small permanent stat bonus for the pets you have collected and ranked
	  Pets.SkillId(petId)                   the pet's own skill (cast by its owner; level = rank)
	  Pets.List(profile)                    -> rows for the UI (owned or not)

	The equipped pet is Season.ActivePet when it is still owned; otherwise the
	first owned pet in Config order, so a new season never leaves you petless.
]]

local Config = require(script.Parent.Config.Pets)

local Pets = {}

Pets.MaxLevel = Config.MaxLevel
Pets.Defs = Config.Defs
Pets.Order = Config.Order

local STAT_LABELS = { MaxHealth = "Max Health", Attack = "Attack", Defense = "Defense", CritChance = "Crit Chance", AttackSpeed = "Attack Speed", CritMultiplier = "Crit Damage" }

function Pets.Level(profile, petId)
	local levels = profile.Season.PetLevels or {}
	return math.clamp(levels[petId] or 1, 1, Config.MaxLevel)
end

local function owned(profile, petId)
	return profile.Permanent.Pets ~= nil and profile.Permanent.Pets[petId] == true
end

-- Rank comes from duplicate pulls (permanent). Owning a pet is rank 1.
function Pets.Rank(profile, petId)
	local ranks = profile.Permanent.PetRanks or {}
	return math.clamp(ranks[petId] or 1, 1, Config.MaxRank)
end

function Pets.Active(profile)
	local active = profile.Season.ActivePet
	if type(active) == "string" and Config.Defs[active] and owned(profile, active) then
		return active, Pets.Level(profile, active), Pets.Rank(profile, active)
	end
	for _, petId in ipairs(Config.Order) do
		if owned(profile, petId) then
			return petId, Pets.Level(profile, petId), Pets.Rank(profile, petId)
		end
	end
	return nil
end

-- One stat line of a pet at a level and rank: { Stat, Mode, Value }
local function statValue(def, entry, level, rank)
	local unit = Config.StatUnits[entry.Stat]
	local scale = (Config.RarityMult[def.Rarity] or 1) * (def.Power or 1) * entry.Share * (1 + Config.RankBonus * (math.clamp(rank or 1, 1, Config.MaxRank) - 1))
	return unit.Base * scale + unit.PerLevel * scale * (math.clamp(level or 1, 1, Config.MaxLevel) - 1)
end

function Pets.Mods(petId, level, rank)
	local def = Config.Defs[petId]
	if def == nil then
		return {}
	end
	local mods = {}
	for _, entry in ipairs(def.Stats) do
		table.insert(mods, { Stat = entry.Stat, Mode = Config.StatUnits[entry.Stat].Mode, Value = statValue(def, entry, level, rank) })
	end
	return mods
end

-- The id of the pet's own skill (an ability in Config/Abilities), or nil
function Pets.SkillId(petId)
	local def = Config.Defs[petId]
	return if def and def.Skill then "Pet_" .. petId else nil
end

function Pets.Describe(petId, level, rank)
	local def = Config.Defs[petId]
	if def == nil then
		return ""
	end
	local parts = {}
	for _, mod in ipairs(Pets.Mods(petId, level, rank)) do
		local label = STAT_LABELS[mod.Stat] or mod.Stat
		if mod.Mode == "Mul" or mod.Stat == "CritChance" or mod.Stat == "CritMultiplier" then
			table.insert(parts, ("+%.1f%% %s"):format(mod.Value * 100, label))
		else
			table.insert(parts, ("+%d %s"):format(math.floor(mod.Value + 0.5), label))
		end
	end
	return table.concat(parts, ", ")
end

-- Copies still needed to take a pet from its rank to max rank (counting the ones already banked)
function Pets.CopiesWanted(profile, petId)
	local need = 0
	for rank = Pets.Rank(profile, petId), Config.MaxRank - 1 do
		need += Config.RankCost[rank]
	end
	return math.max(0, need - ((profile.Permanent.PetCopies or {})[petId] or 0))
end

local function addShards(profile, rarity, amount)
	profile.Permanent.PetShards = profile.Permanent.PetShards or {}
	profile.Permanent.PetShards[rarity] = (profile.Permanent.PetShards[rarity] or 0) + amount
	return profile.Permanent.PetShards[rarity]
end

-- A duplicate pull of a pet you own is banked as a COPY for ranking it up. Once the banked copies cover every rank up
-- to max, each extra duplicate becomes a PET SHARD of the pet's rarity. Returns "Copy", copiesNow  or  "Shard", shardsNow.
function Pets.AddDuplicate(profile, petId)
	if Pets.CopiesWanted(profile, petId) <= 0 then
		local def = Config.Defs[petId]
		return "Shard", addShards(profile, def.Rarity, 1)
	end
	profile.Permanent.PetCopies = profile.Permanent.PetCopies or {}
	local copies = (profile.Permanent.PetCopies[petId] or 0) + 1
	profile.Permanent.PetCopies[petId] = copies
	return "Copy", copies
end

-- Shards of each rarity: { Common = n, Rare = n, Epic = n, Legendary = n }
function Pets.Shards(profile)
	local out = {}
	for _, rarity in ipairs(Config.Shards.Order) do
		out[rarity] = (profile.Permanent.PetShards or {})[rarity] or 0
	end
	return out
end

-- Spend PetCost shards of the pet's rarity on that pet. Only pets from the Wishing Tree can be bought.
-- Reasons: "UnknownPet", "NotBuyable", "NotEnoughShards", "PetMaxed" (nothing more it could use)
function Pets.BuyWithShards(profile, petId)
	local def = type(petId) == "string" and Config.Defs[petId] or nil
	if def == nil then
		return false, "UnknownPet"
	end
	if def.Wish ~= true then
		return false, "NotBuyable"
	end
	local shards = profile.Permanent.PetShards or {}
	if (shards[def.Rarity] or 0) < Config.Shards.PetCost then
		return false, "NotEnoughShards"
	end
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	if profile.Permanent.Pets[petId] then
		if Pets.CopiesWanted(profile, petId) <= 0 then
			return false, "PetMaxed"
		end
		profile.Permanent.PetCopies = profile.Permanent.PetCopies or {}
		profile.Permanent.PetCopies[petId] = (profile.Permanent.PetCopies[petId] or 0) + 1
	else
		profile.Permanent.Pets[petId] = true
	end
	shards[def.Rarity] -= Config.Shards.PetCost
	profile.Permanent.PetShards = shards
	return true
end

-- Condense CondenseCost shards of one rarity into one shard of the next. rarity = "Common" | "Rare" | "Epic" | "All"
-- ("All" sweeps upward: commons into rares, then rares (including the new ones) into epics, and so on).
-- Returns true, { Made = { Rare = n, ... } }  or  false, "NothingToCondense" / "UnknownRarity"
function Pets.Condense(profile, rarity)
	local order = Config.Shards.Order
	local from = {}
	if rarity == "All" then
		for index = 1, #order - 1 do
			table.insert(from, index)
		end
	else
		local index = table.find(order, rarity)
		if index == nil or index >= #order then
			return false, "UnknownRarity"
		end
		from = { index }
	end
	profile.Permanent.PetShards = profile.Permanent.PetShards or {}
	local shards = profile.Permanent.PetShards
	local made, any = {}, false
	for _, index in ipairs(from) do
		local low, high = order[index], order[index + 1]
		local batches = math.floor((shards[low] or 0) / Config.Shards.CondenseCost)
		if batches > 0 then
			shards[low] -= batches * Config.Shards.CondenseCost
			shards[high] = (shards[high] or 0) + batches
			made[high] = (made[high] or 0) + batches
			any = true
		end
	end
	if not any then
		return false, "NothingToCondense"
	end
	return true, { Made = made }
end

-- The permanent bonus for collecting: { Points, Percent, Mods = { { Stat, Mode, Value } } }
function Pets.Collection(profile)
	local points = 0
	for petId, have in pairs(profile.Permanent.Pets or {}) do
		local def = have and Config.Defs[petId]
		if def then
			points += (Config.Collection.Points[def.Rarity] or 1) * Pets.Rank(profile, petId)
		end
	end
	local value = points * Config.Collection.PerPoint
	local mods = {}
	if value > 0 then
		for _, stat in ipairs(Config.Collection.Stats) do
			table.insert(mods, { Stat = stat, Mode = "Mul", Value = value })
		end
	end
	return { Points = points, Percent = value * 100, Mods = mods }
end

function Pets.Copies(profile, petId)
	return (profile.Permanent.PetCopies or {})[petId] or 0
end

function Pets.RankCost(rank)
	return Config.RankCost[rank]
end

-- Spend banked copies on the next rank. Reasons: "UnknownPet", "NotOwned", "MaxRank", "NotEnoughCopies"
function Pets.RankUp(profile, petId)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	local rank = Pets.Rank(profile, petId)
	if rank >= Config.MaxRank then
		return false, "MaxRank"
	end
	local cost = Config.RankCost[rank]
	local copies = Pets.Copies(profile, petId)
	if copies < cost then
		return false, "NotEnoughCopies"
	end
	profile.Permanent.PetCopies[petId] = copies - cost
	profile.Permanent.PetRanks = profile.Permanent.PetRanks or {}
	profile.Permanent.PetRanks[petId] = rank + 1
	return true, rank + 1
end

function Pets.GrantForClear(profile, stage)
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	local gained = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		if def.UnlockStage ~= nil and stage >= def.UnlockStage and not profile.Permanent.Pets[petId] then
			profile.Permanent.Pets[petId] = true
			table.insert(gained, petId)
		end
	end
	return gained
end

function Pets.Equip(profile, petId)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	profile.Season.ActivePet = petId
	return true
end

-- Pet XP: pets level up from pet food and from fighting (see Progression). XP to go from level L to L+1
-- is Config.XPPerLevel * L. XP is kept in Season.PetXP[petId], the level in Season.PetLevels[petId].
function Pets.XPToNext(level)
	return Config.XPPerLevel * level
end

function Pets.AddXP(profile, petId, amount)
	if type(petId) ~= "string" or Config.Defs[petId] == nil then
		return false, "UnknownPet"
	end
	if not owned(profile, petId) then
		return false, "NotOwned"
	end
	local season = profile.Season
	season.PetLevels = season.PetLevels or {}
	season.PetXP = season.PetXP or {}
	local level = Pets.Level(profile, petId)
	if level >= Config.MaxLevel then
		return false, "MaxLevel"
	end
	local xp = (season.PetXP[petId] or 0) + math.max(0, amount or 0)
	local gained = 0
	while level < Config.MaxLevel and xp >= Pets.XPToNext(level) do
		xp -= Pets.XPToNext(level)
		level += 1
		gained += 1
	end
	if level >= Config.MaxLevel then
		xp = 0
	end
	season.PetXP[petId] = xp
	season.PetLevels[petId] = level
	return true, gained
end

function Pets.List(profile)
	local activeId = Pets.Active(profile)
	local rows = {}
	for _, petId in ipairs(Config.Order) do
		local def = Config.Defs[petId]
		local level = Pets.Level(profile, petId)
		local rank = Pets.Rank(profile, petId)
		table.insert(rows, {
			Id = petId,
			Name = def.DisplayName,
			Rarity = def.Rarity,
			Owned = owned(profile, petId),
			UnlockStage = def.UnlockStage,
			Wish = def.Wish == true,
			Look = def.Look,
			Level = level,
			MaxLevel = Config.MaxLevel,
			Active = petId == activeId,
			Text = Pets.Describe(petId, level, rank),
			Rank = rank,
			MaxRank = Config.MaxRank,
			Copies = Pets.Copies(profile, petId),
			Wanted = Pets.CopiesWanted(profile, petId),
			RankCost = Config.RankCost[rank],
			Skill = def.Skill and { Id = Pets.SkillId(petId), Name = def.Skill.Name, Text = def.Skill.Text } or nil,
		})
	end
	return rows
end

return Pets
