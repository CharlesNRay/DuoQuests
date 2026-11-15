--[[
	Consumables (ModuleScript)
	Location: ReplicatedStorage > Shared > Consumables

	The Stash and timed boosts. Pure functions on a profile; `now` is os.time() (passed in for tests).
	Data: Config/Consumables. Stash = Season.Stash { [id] = count }; boosts = Season.Buffs { [id] = expiresAt }.

	  Consumables.Grant(profile, id, count)           -> true | false, reason
	  Consumables.Count(profile, id)
	  Consumables.Use(profile, id, now, petId?)       reasons: "Unknown", "NoneLeft", "UseAtTree", "NoPet", "BadPet"
	                                                  Buff: starts / extends it. PetFood: feeds petId.
	  Consumables.Price(def, frontier)                gold at the Merchant (nil if not sold)
	  Consumables.Buy(profile, id, count)             reasons: "Unknown", "NotSold", "NotEnough"
	  Consumables.Active(profile, now)                -> list of { Id, Name, Glyph, Remaining, Description }
	  Consumables.Mods(profile, now)                  -> combat mods { Stat, Mode, Value } for StatCalc
	  Consumables.Rewards(profile, now)               -> { GoldGain, XPGain } fractions
	  Consumables.RollDrop(isBoss, rand)              -> id or nil  (a stage-clear drop)
	  Consumables.List(profile)                       -> stash rows for the UI, in display order
]]

local Config = require(script.Parent.Config.Consumables)
local Pets = require(script.Parent.Pets)

local Consumables = {}

Consumables.Defs = Config.Defs
Consumables.Order = Config.Order

local REWARD_STATS = { GoldGain = true, XPGain = true }

local function stash(profile)
	local season = profile.Season
	season.Stash = season.Stash or {}
	season.Buffs = season.Buffs or {}
	return season.Stash
end

function Consumables.Count(profile, id)
	return stash(profile)[id] or 0
end

function Consumables.Grant(profile, id, count)
	if Config.Defs[id] == nil then
		return false, "Unknown"
	end
	local s = stash(profile)
	s[id] = (s[id] or 0) + math.max(1, math.floor(count or 1))
	return true
end

function Consumables.Use(profile, id, now, petId)
	local def = Config.Defs[id]
	if def == nil then
		return false, "Unknown"
	end
	local s = stash(profile)
	if (s[id] or 0) < 1 then
		return false, "NoneLeft"
	end
	if def.Kind == "Ticket" then
		return false, "UseAtTree"
	end
	if def.Kind == "PetFood" then
		if type(petId) ~= "string" then
			return false, "NoPet"
		end
		local ok, reason = Pets.AddXP(profile, petId, def.PetXP)
		if not ok then
			return false, reason
		end
		s[id] -= 1
		return true, def.PetXP
	end
	-- timed boost: using it again adds time
	local buffs = profile.Season.Buffs
	local base = math.max(now, buffs[id] or 0)
	buffs[id] = math.min(base + def.Duration, now + Config.MaxStack)
	s[id] -= 1
	return true, buffs[id]
end

function Consumables.Price(def, frontier)
	if def == nil or def.Price == nil then
		return nil
	end
	return math.floor(def.Price.Base + def.Price.PerStage * (frontier or 1))
end

function Consumables.Buy(profile, id, count)
	local def = Config.Defs[id]
	if def == nil then
		return false, "Unknown"
	end
	local price = Consumables.Price(def, profile.Season.HighestStage)
	if price == nil then
		return false, "NotSold"
	end
	count = math.clamp(math.floor(count or 1), 1, 99)
	local total = price * count
	if profile.Season.Currencies.Gold < total then
		return false, "NotEnough"
	end
	profile.Season.Currencies.Gold -= total
	Consumables.Grant(profile, id, count)
	return true, total
end

function Consumables.Active(profile, now)
	stash(profile)
	local list = {}
	for _, id in ipairs(Config.Order) do
		local expires = profile.Season.Buffs[id]
		local def = Config.Defs[id]
		if def and def.Kind == "Buff" and expires and expires > now then
			table.insert(list, { Id = id, Name = def.DisplayName, Glyph = def.Glyph, Remaining = expires - now, Description = def.Description })
		end
	end
	return list
end

local function activeEffects(profile, now)
	stash(profile)
	local effects = {}
	for id, expires in pairs(profile.Season.Buffs) do
		local def = Config.Defs[id]
		if def and def.Kind == "Buff" and expires > now then
			for _, effect in ipairs(def.Effects) do
				table.insert(effects, effect)
			end
		end
	end
	return effects
end

function Consumables.Mods(profile, now)
	local mods = {}
	for _, effect in ipairs(activeEffects(profile, now)) do
		if not REWARD_STATS[effect.Stat] then
			table.insert(mods, { Stat = effect.Stat, Mode = effect.Mode, Value = effect.Value })
		end
	end
	return mods
end

function Consumables.Rewards(profile, now)
	local rewards = { GoldGain = 0, XPGain = 0 }
	for _, effect in ipairs(activeEffects(profile, now)) do
		if REWARD_STATS[effect.Stat] then
			rewards[effect.Stat] += effect.Value
		end
	end
	return rewards
end

function Consumables.RollDrop(isBoss, rand)
	if rand() >= (if isBoss then Config.BossDropChance else Config.DropChance) then
		return nil
	end
	local total = 0
	for _, id in ipairs(Config.Order) do
		total += Config.Defs[id].Drop or 0
	end
	local roll = rand() * total
	for _, id in ipairs(Config.Order) do
		local weight = Config.Defs[id].Drop or 0
		if weight > 0 then
			if roll < weight then
				return id
			end
			roll -= weight
		end
	end
	return nil
end

function Consumables.List(profile)
	local s = stash(profile)
	local rows = {}
	for _, id in ipairs(Config.Order) do
		local def = Config.Defs[id]
		if (s[id] or 0) > 0 then
			table.insert(rows, {
				Id = id, Name = def.DisplayName, Glyph = def.Glyph, Kind = def.Kind, Rarity = def.Rarity, Count = s[id],
				Description = def.Description, Duration = def.Duration,
			})
		end
	end
	return rows
end

return Consumables
