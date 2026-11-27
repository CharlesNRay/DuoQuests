--[[
	Market (ModuleScript): the gold shop with limits. Daily items refresh every day; season items can be bought a few times per
	season. Prices are multiples of what one frontier stage clear pays, so they keep up as income grows, and rise with each
	purchase of the same item inside one limit window.

	  Market.Items                       data list: { Id, Name, Glyph, Window = "Day"|"Season", Limit, Clears or Price (fixed gold), Grant }
	  Market.Of(profile, now, seasonId)  -> list of { Id, Name, Glyph, Window, Limit, Bought, Price, Text } (rolls the day / season over)
	  Market.Buy(profile, id, now, seasonId) -> true, lines | false, reason ("Unknown", "SoldOut", "NotEnough")
]]
local Progression = require(script.Parent.Progression)
local Bosses = require(script.Parent.Bosses)

local Market = {}

Market.RiseStep = 0.35 -- each purchase in a window adds this share of the base price

-- Grant: what one purchase gives (Items = consumables, Wishstones / SkillPicks = currencies, Gear = a drop)
Market.Items = {
	{ Id = "PetWish", Name = "Pet Wish", Glyph = "🐾", Window = "Day", Limit = 3, Clears = 90, Grant = { Items = { PetWish = 1 } } },
	{ Id = "SkillWish", Name = "Skill Wish", Glyph = "✨", Window = "Day", Limit = 3, Clears = 90, Grant = { Items = { SkillWish = 1 } } },
	{ Id = "XPTonic", Name = "XP Tonic", Glyph = "🧪", Window = "Day", Limit = 5, Clears = 25, Grant = { Items = { XPTonic = 1 } } },
	{ Id = "PowerElixir", Name = "Power Elixir", Glyph = "💪", Window = "Day", Limit = 2, Clears = 40, Grant = { Items = { PowerElixir = 1 } } },
	{ Id = "Wishstones", Name = "10 Wishstones", Glyph = "💎", Window = "Season", Limit = 3, Clears = 300, Grant = { Wishstones = 10 } },
	{ Id = "SkillPick", Name = "Skill Pick", Glyph = "🎯", Window = "Season", Limit = 2, Clears = 700, Grant = { SkillPicks = 1 } },
	{ Id = "EpicChest", Name = "Epic Gear Chest", Glyph = "🎁", Window = "Season", Limit = 1, Clears = 1500, Grant = { Gear = { Rarity = "Epic", Bonus = 8 } } },
}

local function row(profile, now, seasonId)
	local permanent = profile.Permanent
	if type(permanent.Market) ~= "table" then
		permanent.Market = { Day = 0, Bought = {}, SeasonId = seasonId, SeasonBought = {} }
	end
	local m = permanent.Market
	local day = math.floor((now or os.time()) / 86400)
	if m.Day ~= day then
		m.Day, m.Bought = day, {}
	end
	if m.SeasonId ~= seasonId then
		m.SeasonId, m.SeasonBought = seasonId, {}
	end
	return m
end

local function find(id)
	for _, item in ipairs(Market.Items) do
		if item.Id == id then
			return item
		end
	end
end

local function priceOf(item, frontier, bought)
	-- most items cost a number of stage clears' gold; a few have a fixed Price to match the vendor that sells the same thing
	local base = item.Price or Progression.ClearRewards(math.max(1, frontier), true, nil).Gold * item.Clears
	return math.floor(base * (1 + Market.RiseStep * bought))
end

local function describe(grant)
	return table.concat(Bosses.Describe(grant), ", ")
end

function Market.Of(profile, now, seasonId)
	local m = row(profile, now, seasonId)
	local out = {}
	for _, item in ipairs(Market.Items) do
		local bought = (if item.Window == "Day" then m.Bought else m.SeasonBought)[item.Id] or 0
		table.insert(out, {
			Id = item.Id, Name = item.Name, Glyph = item.Glyph, Window = item.Window, Limit = item.Limit, Bought = bought,
			Price = priceOf(item, profile.Season.HighestStage, bought),
		})
	end
	return out
end

function Market.Buy(profile, id, now, seasonId)
	local item = find(id)
	if not item then
		return false, "Unknown"
	end
	local m = row(profile, now, seasonId)
	local bucket = if item.Window == "Day" then m.Bought else m.SeasonBought
	local bought = bucket[id] or 0
	if bought >= item.Limit then
		return false, "SoldOut"
	end
	local price = priceOf(item, profile.Season.HighestStage, bought)
	local currencies = profile.Season.Currencies
	if currencies.Gold < price then
		return false, "NotEnough"
	end
	currencies.Gold -= price
	bucket[id] = bought + 1
	local lines = Bosses.GrantRewards(profile, { Items = item.Grant.Items, Gear = item.Grant.Gear }, profile.Season.HighestStage)
	if item.Grant.Wishstones then
		currencies.Wishstones = (currencies.Wishstones or 0) + item.Grant.Wishstones
		table.insert(lines, ("%d Wishstones"):format(item.Grant.Wishstones))
	end
	if item.Grant.SkillPicks then
		currencies.SkillPicks = (currencies.SkillPicks or 0) + item.Grant.SkillPicks
		table.insert(lines, ("%d Skill Pick"):format(item.Grant.SkillPicks))
	end
	return true, lines
end

return Market
