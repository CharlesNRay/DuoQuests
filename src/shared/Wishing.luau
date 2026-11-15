--[[
	Wishing (ModuleScript)
	Location: ReplicatedStorage > Shared > Wishing

	The gacha rules behind the Wishing Tree. Pure functions; the data is in Config/Wishing.

	  Wishing.Info(profile, kind)  -> { Tiers = { { Id, Name, Unlocked, UnlockStage, Gold|Shards, Tickets, Odds } },
	                                    Tickets = n, Currency = n, CurrencyName, PityRare, PityEpic, LeftRare, LeftEpic, Remaining? }
	  Wishing.Wish(profile, kind, tierId, method, count, rng?) -> true, { Results = {...}, Spent = n } | false, reason
	      kind "Pet" | "Skill"; method "Ticket" | "Currency"; count 1 or 10 (a skill wish is capped by what is left to find)
	      Results rows: { Id, Rarity, New = bool, Rank = n? (a duplicate pet's new rank), DupXP = n? (at max rank) }
	      reasons: "BadArgs", "UnknownTier", "TierLocked", "NotEnough", "NothingLeft"
	  rng is a function() -> [0,1); default uses Random.

	Nothing is spent when a wish fails.
]]

local Config = require(script.Parent.Config.Wishing)
local PetConfig = require(script.Parent.Config.Pets)
local Rarities = require(script.Parent.Config.Rarities)
local Pets = require(script.Parent.Pets)
local Skills = require(script.Parent.Skills)
local Subclasses = require(script.Parent.Subclasses)
local Abilities = require(script.Parent.Config.Abilities)
local Consumables = require(script.Parent.Consumables)

local Wishing = {}

Wishing.Config = Config

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary" }
local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

local function tiersOf(kind)
	return Config.Tiers[kind]
end

local function pity(profile, kind)
	local season = profile.Season
	season.WishPity = season.WishPity or {}
	season.WishPity[kind] = season.WishPity[kind] or { Rare = 0, Epic = 0, Legendary = 0 }
	return season.WishPity[kind]
end

local function currencyOf(profile, kind)
	local c = profile.Season.Currencies
	if kind == "Pet" then
		return c.Gold or 0, "Gold"
	end
	return c.Shards or 0, "Shards"
end

local function unowned(profile, kind)
	local season = profile.Season
	local list = {}
	if kind == "Skill" then
		for _, id in ipairs(Skills.Pool(season.ClassId, Subclasses.Current(profile, season.ClassId))) do
			if Abilities[id] and not season.OwnedAbilities[id] then
				table.insert(list, id)
			end
		end
	end
	return list
end

function Wishing.Info(profile, kind)
	local tiers = tiersOf(kind)
	if tiers == nil then
		return nil
	end
	local frontier = profile.Season.HighestStage or 1
	local p = pity(profile, kind)
	local have, currencyName = currencyOf(profile, kind)
	local out = {
		Kind = kind, Tiers = {}, Tickets = Consumables.Count(profile, Config.TicketIds[kind]),
		Currency = have, CurrencyName = currencyName,
		PityRare = Config.PityRare, PityEpic = Config.PityEpic, PityLegendary = if kind == "Pet" then Config.PityLegendary else nil,
		LeftRare = Config.PityRare - p.Rare, LeftEpic = Config.PityEpic - p.Epic,
		LeftLegendary = if kind == "Pet" then Config.PityLegendary - p.Legendary else nil,
	}
	if kind == "Skill" then
		out.Remaining = #unowned(profile, kind)
	end
	for _, tier in ipairs(tiers) do
		table.insert(out.Tiers, {
			Id = tier.Id, Name = tier.Name, UnlockStage = tier.UnlockStage, Unlocked = frontier >= tier.UnlockStage,
			Cost = tier.Gold or tier.Shards, Tickets = tier.Tickets, Odds = tier.Odds,
		})
	end
	return out
end

local function rollRarity(odds, floorRank, rand)
	local maxRank = 1
	for _, r in ipairs(RARITY_ORDER) do
		if (odds[r] or 0) > 0 then
			maxRank = math.max(maxRank, RANK[r])
		end
	end
	floorRank = math.min(floorRank, maxRank) -- a tier without Legendary cannot owe you one
	local total = 0
	for _, r in ipairs(RARITY_ORDER) do
		if (odds[r] or 0) > 0 and RANK[r] >= floorRank then
			total += odds[r]
		end
	end
	local pick = rand() * total
	local last
	for _, r in ipairs(RARITY_ORDER) do
		local w = odds[r] or 0
		if w > 0 and RANK[r] >= floorRank then
			last = r
			if pick < w then
				return r
			end
			pick -= w
		end
	end
	return last or "Common"
end

local function choose(list, rand)
	return list[math.clamp(math.floor(rand() * #list) + 1, 1, #list)]
end

-- the item of that rarity, or the nearest rarity that has something left
local function pickItem(pool, rarityOf, rarity, rand)
	for offset = 0, 3 do
		for side = 1, 2 do
			local r = RARITY_ORDER[RANK[rarity] + (if side == 1 then -offset else offset)]
			if r then
				local matches = {}
				for _, id in ipairs(pool) do
					if rarityOf(id) == r then
						table.insert(matches, id)
					end
				end
				if #matches > 0 then
					return choose(matches, rand), r
				end
			end
		end
	end
	return nil
end

local function take(profile, id, n)
	local s = profile.Season.Stash
	s[id] -= n
	if s[id] <= 0 then
		s[id] = nil
	end
end

function Wishing.Wish(profile, kind, tierId, method, count, rng)
	local tiers = tiersOf(kind)
	if tiers == nil or (method ~= "Ticket" and method ~= "Currency") or (count ~= 1 and count ~= Config.TenPullCount) then
		return false, "BadArgs"
	end
	local tier
	for _, t in ipairs(tiers) do
		if t.Id == tierId then
			tier = t
		end
	end
	if tier == nil then
		return false, "UnknownTier"
	end
	if (profile.Season.HighestStage or 1) < tier.UnlockStage then
		return false, "TierLocked"
	end
	local rand = rng
	if rand == nil then
		local r = Random.new()
		rand = function()
			return r:NextNumber()
		end
	end

	local available = if kind == "Skill" then unowned(profile, kind) else nil
	if available then
		if #available == 0 then
			return false, "NothingLeft"
		end
		count = math.min(count, #available)
	end

	local ticketId = Config.TicketIds[kind]
	local spent
	if method == "Ticket" then
		spent = tier.Tickets * count
		if Consumables.Count(profile, ticketId) < spent then
			return false, "NotEnough"
		end
	else
		spent = (tier.Gold or tier.Shards) * count
		if (currencyOf(profile, kind)) < spent then
			return false, "NotEnough"
		end
	end
	if method == "Ticket" then
		take(profile, ticketId, spent)
	elseif kind == "Pet" then
		profile.Season.Currencies.Gold -= spent
	else
		profile.Season.Currencies.Shards -= spent
	end

	local p = pity(profile, kind)
	local results = {}
	local pool, rarityOf
	if kind == "Pet" then
		pool = {}
		for _, id in ipairs(PetConfig.Order) do
			if PetConfig.Defs[id].Wish then
				table.insert(pool, id)
			end
		end
		rarityOf = function(id)
			return PetConfig.Defs[id].Rarity
		end
	else
		pool = available
		rarityOf = function(id)
			return Abilities[id].Rarity
		end
	end

	for _ = 1, count do
		local floorRank = 1
		if kind == "Pet" and p.Legendary + 1 >= Config.PityLegendary then
			floorRank = 4
		elseif p.Epic + 1 >= Config.PityEpic then
			floorRank = 3
		elseif p.Rare + 1 >= Config.PityRare then
			floorRank = 2
		end
		local rarity = rollRarity(tier.Odds, floorRank, rand)
		local id, actual = pickItem(pool, rarityOf, rarity, rand)
		if id == nil then
			break
		end
		rarity = actual
		local rank = RANK[rarity] or 1
		p.Rare = if rank >= 2 then 0 else p.Rare + 1
		p.Epic = if rank >= 3 then 0 else p.Epic + 1
		p.Legendary = if rank >= 4 then 0 else p.Legendary + 1

		local row = { Id = id, Rarity = rarity, New = true }
		if kind == "Pet" then
			profile.Permanent.Pets = profile.Permanent.Pets or {}
			if profile.Permanent.Pets[id] then
				row.New = false
				-- a duplicate ranks the pet up (pet XP once it is at max rank)
				local kind, amount = Pets.AddDuplicate(profile, id)
				if kind == "Rank" then
					row.Rank = amount
				else
					row.DupXP = amount
				end
			else
				profile.Permanent.Pets[id] = true
			end
		else
			profile.Season.OwnedAbilities[id] = true
			table.remove(pool, table.find(pool, id))
		end
		table.insert(results, row)
	end
	if #results < count then -- the pool ran dry: give back what was not used
		local unit = spent // count
		local back = (count - #results) * unit
		spent -= back
		if method == "Ticket" then
			Consumables.Grant(profile, ticketId, back)
		elseif kind == "Pet" then
			profile.Season.Currencies.Gold += back
		else
			profile.Season.Currencies.Shards += back
		end
	end
	return true, { Results = results, Spent = spent }
end

return Wishing
