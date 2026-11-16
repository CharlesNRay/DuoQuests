--[[
	GuildWish (ModuleScript)
	Location: ReplicatedStorage > Shared > GuildWish

	The Guild Wish: spend personal Guild Marks (from guild missions and raids) on pets that exist nowhere else
	(Config/Pets entries with Guild = true). Duplicates become copies / shards like any other pet.

	  GuildWish.Info(profile)                     -> { Cost, Marks, Odds, Pool = { { Id, Rarity, Owned } }, LeftEpic, LeftLegendary }
	  GuildWish.Wish(profile, count, rand?)       -> true, { Results = { { Id, Rarity, New, Copies?, Shard?, Shards? } }, Spent }
	                                                 | false, "BadArgs" | "NotInGuild" | "NotEnoughMarks"
]]

local Config = require(script.Parent.Config.Guilds).Wish
local PetConfig = require(script.Parent.Config.Pets)
local Pets = require(script.Parent.Pets)

local GuildWish = {}

local RANK = { Rare = 2, Epic = 3, Legendary = 4 }

local function pool()
	local list = {}
	for _, id in ipairs(PetConfig.Order) do
		local def = PetConfig.Defs[id]
		if def and def.Guild then
			table.insert(list, id)
		end
	end
	return list
end

local function pity(profile)
	local p = profile.Permanent.GuildPity
	if p == nil then
		p = { Epic = 0, Legendary = 0 }
		profile.Permanent.GuildPity = p
	end
	return p
end

function GuildWish.Info(profile)
	local p = pity(profile)
	local rows = {}
	for _, id in ipairs(pool()) do
		local def = PetConfig.Defs[id]
		table.insert(rows, { Id = id, Name = def.DisplayName, Rarity = def.Rarity, Owned = profile.Permanent.Pets ~= nil and profile.Permanent.Pets[id] == true })
	end
	return {
		Cost = Config.Cost, Marks = profile.Permanent.GuildMarks or 0, Odds = Config.Odds, Pool = rows,
		LeftEpic = math.max(1, Config.PityEpic - p.Epic), LeftLegendary = math.max(1, Config.PityLegendary - p.Legendary),
	}
end

function GuildWish.Wish(profile, count, rand)
	rand = rand or math.random
	if count ~= 1 and count ~= 10 then
		return false, "BadArgs"
	end
	if profile.Permanent.Guild == nil then
		return false, "NotInGuild"
	end
	local spent = Config.Cost * count
	if (profile.Permanent.GuildMarks or 0) < spent then
		return false, "NotEnoughMarks"
	end
	profile.Permanent.GuildMarks -= spent
	local p = pity(profile)
	local ids = pool()
	local results = {}
	for _ = 1, count do
		local minRank = 2
		if p.Legendary + 1 >= Config.PityLegendary then
			minRank = 4
		elseif p.Epic + 1 >= Config.PityEpic then
			minRank = 3
		end
		local roll, rarity = rand(), "Rare"
		local acc = 0
		for _, r in ipairs({ "Legendary", "Epic", "Rare" }) do
			acc += Config.Odds[r]
			if roll < acc then
				rarity = r
				break
			end
		end
		if RANK[rarity] < minRank then
			rarity = if minRank == 4 then "Legendary" else "Epic"
		end
		local options = {}
		for _, id in ipairs(ids) do
			if PetConfig.Defs[id].Rarity == rarity then
				table.insert(options, id)
			end
		end
		local id = options[math.floor(rand() * #options) + 1] or options[1]
		p.Epic = if RANK[rarity] >= 3 then 0 else p.Epic + 1
		p.Legendary = if RANK[rarity] >= 4 then 0 else p.Legendary + 1
		local row = { Id = id, Rarity = rarity, New = true }
		profile.Permanent.Pets = profile.Permanent.Pets or {}
		if profile.Permanent.Pets[id] then
			row.New = false
			local got, amount = Pets.AddDuplicate(profile, id)
			if got == "Copy" then
				row.Copies = amount
			else
				row.Shard, row.Shards = true, amount
			end
		else
			profile.Permanent.Pets[id] = true
		end
		table.insert(results, row)
	end
	return true, { Results = results, Spent = spent }
end

return GuildWish
