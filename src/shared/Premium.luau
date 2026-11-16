--[[
	Premium (ModuleScript)
	Location: ReplicatedStorage > Shared > Premium

	The orange premium currency (Sunstones) and the Premium shop. Sunstones are bought with Robux (the server's receipt handler
	calls Premium.AddPack) and spent here on fixed-content items; they never buy wishes or tickets (see Config/Premium).

	  Premium.Sunstones(profile)            -> balance (permanent: survives seasons)
	  Premium.AddSunstones(profile, n)
	  Premium.SpendSunstones(profile, n)   -> true | false, "NotEnough"   (cosmetics use it)
	  Premium.AddPack(profile, packId)      -> true, { Sunstones, Bonus } | false, "BadPack"   (first purchase of a pack doubles it)
	  Premium.Packs(profile)                -> { { Id, Name, Sunstones, Robux, FirstBonus, Bonus, ProductId } }  (Bonus = what the next buy adds)
	  Premium.List(profile)                 -> { { Id, Name, Text, Cost, Tag, Bought, Max, Left, Affordable, Hidden } }
	  Premium.Offer(profile)                -> the item row to pop up on screen now (the Subclass Pack at the subclass level) | nil
	  Premium.DismissOffer(profile, itemId) -> true | false, "BadItem"   (after this the item is listed in the shop)
	  Premium.Buy(profile, itemId)          -> true, { Item, Cost, Granted } | false, "BadItem" | "LimitReached" | "NotEnough"
]]

local Config = require(script.Parent.Config.Premium)
local QuestConfig = require(script.Parent.Config.Quests)
local Consumables = require(script.Parent.Consumables)
local Quests = require(script.Parent.Quests)
local Gear = require(script.Parent.Gear)
local GearConfig = require(script.Parent.Config.Gear)
local SubclassConfig = require(script.Parent.Config.Subclasses)

local Premium = {}

local itemById = {}
for _, item in ipairs(Config.Items) do
	itemById[item.Id] = item
end
local packById = {}
for _, pack in ipairs(Config.Packs) do
	packById[pack.Id] = pack
end

local function account(profile)
	local p = profile.Permanent.Premium
	if p == nil then
		p = { Sunstones = 0, Bought = {}, PacksBought = {} }
		profile.Permanent.Premium = p
	end
	p.Bought = p.Bought or {}
	p.PacksBought = p.PacksBought or {}
	return p
end

-- this season's purchase counts (the season data resets with the season, so limits per season reset with it)
local function seasonBought(profile)
	profile.Season.PremiumBought = profile.Season.PremiumBought or {}
	return profile.Season.PremiumBought
end

function Premium.Sunstones(profile)
	return account(profile).Sunstones
end

function Premium.AddSunstones(profile, amount)
	local a = account(profile)
	a.Sunstones += math.max(0, math.floor(amount))
	return a.Sunstones
end

-- Spends Sunstones on something outside the shop list (cosmetics): true, or false, "NotEnough"
function Premium.SpendSunstones(profile, amount)
	local a = account(profile)
	amount = math.max(0, math.floor(amount))
	if a.Sunstones < amount then
		return false, "NotEnough"
	end
	a.Sunstones -= amount
	return true
end

function Premium.AddPack(profile, packId)
	local pack = packById[packId]
	if not pack then
		return false, "BadPack"
	end
	local a = account(profile)
	local bonus = if a.PacksBought[packId] then 0 else pack.FirstBonus
	a.PacksBought[packId] = (a.PacksBought[packId] or 0) + 1
	a.Sunstones += pack.Sunstones + bonus
	return true, { Sunstones = pack.Sunstones, Bonus = bonus }
end

function Premium.Packs(profile)
	local a = account(profile)
	local rows = {}
	for _, pack in ipairs(Config.Packs) do
		table.insert(rows, {
			Id = pack.Id, Name = pack.Name, Sunstones = pack.Sunstones, Robux = pack.Robux, FirstBonus = pack.FirstBonus,
			Bonus = if a.PacksBought[pack.Id] then 0 else pack.FirstBonus, ProductId = pack.ProductId,
		})
	end
	return rows
end

local function boughtCount(profile, item)
	if item.Limit == nil then
		return 0
	end
	if item.Limit.Per == "Account" then
		return account(profile).Bought[item.Id] or 0
	end
	return seasonBought(profile)[item.Id] or 0
end

local SUBCLASS_LEVEL = math.huge
for _, def in pairs(SubclassConfig.Defs) do
	SUBCLASS_LEVEL = math.min(SUBCLASS_LEVEL, def.UnlockLevel)
end

local function seenOffers(profile)
	profile.Season.PremiumOffers = profile.Season.PremiumOffers or {}
	return profile.Season.PremiumOffers
end

-- is this item sold to this player right now? (separate from "shown in the shop": offers wait for their pop-up)
local function available(profile, item)
	local g = item.Grants
	local pass = Quests.Pass(profile)
	if item.Offer == "Subclass" and profile.Season.Level < SUBCLASS_LEVEL then
		return false
	end
	if g.Premium and pass.Premium then
		return false
	end
	if g.PassMax and pass.Level >= pass.MaxLevel then
		return false
	end
	if g.BagUpgrades and Gear.BagUpgradeCost(profile) == nil then
		return false
	end
	return true
end

function Premium.Offer(profile)
	for _, item in ipairs(Config.Items) do
		if item.Offer and available(profile, item) and not seenOffers(profile)[item.Id] and boughtCount(profile, item) < (item.Limit and item.Limit.Count or math.huge) then
			return { Id = item.Id, Name = item.Name, Text = item.Text, Cost = item.Cost }
		end
	end
	return nil
end

function Premium.DismissOffer(profile, itemId)
	local item = itemById[itemId]
	if not item or not item.Offer then
		return false, "BadItem"
	end
	seenOffers(profile)[itemId] = true
	return true
end

function Premium.List(profile)
	local balance = account(profile).Sunstones
	local rows = {}
	for _, item in ipairs(Config.Items) do
		local bought = boughtCount(profile, item)
		local max = if item.Limit then item.Limit.Count else nil
		local left = if max then max - bought else nil
		local hidden = not available(profile, item) or (item.Offer ~= nil and not seenOffers(profile)[item.Id])
		table.insert(rows, {
			Id = item.Id, Name = item.Name, Text = item.Text, Cost = item.Cost, Tag = item.Tag, Bought = bought, Max = max, Left = left,
			Per = item.Limit and item.Limit.Per or nil, Affordable = balance >= item.Cost, Hidden = hidden,
		})
	end
	return rows
end

local function grant(profile, grants)
	local done = {}
	local season = profile.Season
	if grants.SkillPicks then
		season.Currencies.SkillPicks += grants.SkillPicks
		done.SkillPicks = grants.SkillPicks
	end
	for id, count in pairs(grants.Items or {}) do
		Consumables.Grant(profile, id, count)
	end
	done.Items = grants.Items
	if grants.PassMax then
		Quests.AddPassXP(profile, QuestConfig.Pass.MaxLevel * QuestConfig.Pass.XPPerLevel)
		done.PassMax = true
	end
	if grants.BagUpgrades then
		local equipment = season.Equipment
		local gained = 0
		for _ = 1, grants.BagUpgrades do
			if (equipment.BagUpgrades or 0) < GearConfig.BagMaxUpgrades then
				equipment.BagUpgrades = (equipment.BagUpgrades or 0) + 1
				gained += 1
			end
		end
		done.BagUpgrades = gained
	end
	if grants.Premium then
		Quests.SetPremium(profile, true)
		done.Premium = true
	end
	return done
end

function Premium.Buy(profile, itemId)
	local item = itemById[itemId]
	if not item then
		return false, "BadItem"
	end
	local a = account(profile)
	if item.Limit and boughtCount(profile, item) >= item.Limit.Count then
		return false, "LimitReached"
	end
	if not available(profile, item) then
		return false, "LimitReached"
	end
	if a.Sunstones < item.Cost then
		return false, "NotEnough"
	end
	a.Sunstones -= item.Cost
	if item.Limit then
		if item.Limit.Per == "Account" then
			a.Bought[item.Id] = (a.Bought[item.Id] or 0) + 1
		else
			local s = seasonBought(profile)
			s[item.Id] = (s[item.Id] or 0) + 1
		end
	end
	return true, { Item = item.Name, Cost = item.Cost, Granted = grant(profile, item.Grants) }
end

return Premium
