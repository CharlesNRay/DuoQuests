--[[
	Runes (ModuleScript): rune stones carved onto gear (Config/Runes).

	A rune is { Stat, Tier }. The player keeps uncarved runes in Season.Runes = { ["Stat:Tier"] = count }
	(string keys, so the table survives remotes). Carving puts one on a gear item as item.Rune; a new rune
	replaces the old one, which is lost. Replacing a HIGHER tier needs confirm = true (the client asks first).

	  Runes.Key(stat, tier) / Runes.Parse(key)           "CritChance:Rare" <-> stat, tier
	  Runes.TierRank(tier)                               1..4
	  Runes.Mod(rune)                                    { Stat, Mode, Value } | nil
	  Runes.Label(rune)                                  "Precision: Crit chance +2% (Rare)"
	  Runes.Grant(profile, stat, tier, count)
	  Runes.Roll(stage, rand, weights?)                  -> stat, tier
	  Runes.RollDrop(stage, isFrontier, isBoss, rand)    -> stat, tier | nil
	  Runes.List(profile)                                -> { { Key, Stat, Tier, Count, Label, Glyph } } best tier first
	  Runes.Carve(profile, itemId, key, confirm)         -> true, { Item, Replaced } | false, reason
	      reasons: BadRune, NoRune, NoItem, ConfirmOverride (the old rune is a higher tier; resend with confirm = true)
	  Runes.BuyPouch(profile, rand)                      -> true, { Stat, Tier, Label } | false, "NotEnoughGold"
]]
local Config = require(script.Parent.Config.Runes)

local Runes = {}

local TIER_RANK = {}
for index, tier in ipairs(Config.Tiers) do
	TIER_RANK[tier] = index
end

function Runes.Key(stat, tier)
	return stat .. ":" .. tier
end

function Runes.Parse(key)
	if type(key) ~= "string" then
		return nil
	end
	local stat, tier = key:match("^(%w+):(%w+)$")
	if stat and Config.Stats[stat] and TIER_RANK[tier] then
		return stat, tier
	end
	return nil
end

function Runes.TierRank(tier)
	return TIER_RANK[tier] or 0
end

function Runes.Value(stat, tier)
	local def = Config.Stats[stat]
	return def and def.Values[TIER_RANK[tier] or 1] or 0
end

function Runes.Mod(rune)
	if type(rune) ~= "table" then
		return nil
	end
	local def = Config.Stats[rune.Stat]
	if not def or not TIER_RANK[rune.Tier] then
		return nil
	end
	return { Stat = rune.Stat, Mode = def.Mode, Value = Runes.Value(rune.Stat, rune.Tier) }
end

-- "+2%" for an Add on a chance stat, "+5%" for a multiplier, "+0.10x" for crit damage
function Runes.ValueText(stat, value)
	if stat == "CritMultiplier" then
		return ("+%.2fx"):format(value)
	end
	local pct = value * 100
	local text = if math.abs(pct - math.floor(pct + 0.5)) < 0.05 then tostring(math.floor(math.abs(pct) + 0.5)) else ("%.1f"):format(math.abs(pct))
	if stat == "Haste" then
		return "-" .. text .. "%" -- shown as shorter cooldowns
	end
	return (if value >= 0 then "+" else "-") .. text .. "%"
end

function Runes.Label(rune)
	local def = rune and Config.Stats[rune.Stat]
	if not def then
		return "?"
	end
	return ("%s: %s %s (%s)"):format(def.Name, def.Label, Runes.ValueText(rune.Stat, Runes.Value(rune.Stat, rune.Tier)), rune.Tier)
end

local function store(profile)
	local season = profile.Season
	if type(season.Runes) ~= "table" then
		season.Runes = {}
	end
	return season.Runes
end

function Runes.Grant(profile, stat, tier, count)
	if not Config.Stats[stat] or not TIER_RANK[tier] then
		return false
	end
	local s = store(profile)
	local key = Runes.Key(stat, tier)
	s[key] = (s[key] or 0) + (count or 1)
	return true
end

local function pick(weights, order, rand)
	local total = 0
	for _, id in ipairs(order) do
		total += weights[id] or 0
	end
	local roll = rand() * total
	for _, id in ipairs(order) do
		roll -= weights[id] or 0
		if roll < 0 then
			return id
		end
	end
	return order[1]
end

function Runes.TierWeights(stage)
	local anchors = Config.Drop.Anchors
	local from, to, t = anchors[1], anchors[1], 0
	if stage >= anchors[#anchors].Stage then
		from, to = anchors[#anchors], anchors[#anchors]
	else
		for index = 1, #anchors - 1 do
			if stage >= anchors[index].Stage and stage <= anchors[index + 1].Stage then
				from, to = anchors[index], anchors[index + 1]
				t = (stage - from.Stage) / (to.Stage - from.Stage)
				break
			end
		end
	end
	local weights = {}
	for _, tier in ipairs(Config.Tiers) do
		local a, b = from.Weights[tier] or 0, to.Weights[tier] or 0
		weights[tier] = a + (b - a) * t
	end
	return weights
end

function Runes.Roll(stage, rand, weights)
	rand = rand or math.random
	local tier = pick(weights or Runes.TierWeights(stage), Config.Tiers, rand)
	local stat = Config.Order[math.min(#Config.Order, math.floor(rand() * #Config.Order) + 1)]
	return stat, tier
end

function Runes.RollDrop(stage, isFrontier, isBoss, rand)
	if not isFrontier then
		return nil
	end
	rand = rand or math.random
	local chance = if isBoss then Config.Drop.BossChance else Config.Drop.FrontierChance
	if rand() >= chance then
		return nil
	end
	return Runes.Roll(stage, rand)
end

function Runes.List(profile)
	local rows = {}
	for key, count in pairs(store(profile)) do
		local stat, tier = Runes.Parse(key)
		if stat and count > 0 then
			local rune = { Stat = stat, Tier = tier }
			table.insert(rows, { Key = key, Stat = stat, Tier = tier, Count = count, Label = Runes.Label(rune), Glyph = Config.Stats[stat].Glyph, Name = Config.Stats[stat].Name })
		end
	end
	local orderOf = {}
	for index, stat in ipairs(Config.Order) do
		orderOf[stat] = index
	end
	table.sort(rows, function(a, b)
		if a.Tier ~= b.Tier then
			return TIER_RANK[a.Tier] > TIER_RANK[b.Tier]
		end
		return orderOf[a.Stat] < orderOf[b.Stat]
	end)
	return rows
end

local function findItem(profile, itemId)
	local equipment = profile.Season.Equipment
	for _, item in pairs(equipment.Equipped or {}) do
		if item.Id == itemId then
			return item
		end
	end
	for _, item in ipairs(equipment.Inventory or {}) do
		if item.Id == itemId then
			return item
		end
	end
	return nil
end

function Runes.Carve(profile, itemId, key, confirm)
	local stat, tier = Runes.Parse(key)
	if not stat then
		return false, "BadRune"
	end
	local s = store(profile)
	if (s[key] or 0) <= 0 then
		return false, "NoRune"
	end
	local item = type(itemId) == "string" and findItem(profile, itemId)
	if not item then
		return false, "NoItem"
	end
	local old = item.Rune
	local new = { Stat = stat, Tier = tier }
	if old and Runes.TierRank(old.Tier) > Runes.TierRank(tier) and confirm ~= true then
		return false, "ConfirmOverride" -- the client shows both labels and asks first
	end
	s[key] -= 1
	if s[key] <= 0 then
		s[key] = nil
	end
	item.Rune = new
	return true, { Item = item.Id, Replaced = old and Runes.Label(old) or nil, Label = Runes.Label(new) }
end

function Runes.BuyPouch(profile, rand)
	local currencies = profile.Season.Currencies
	if currencies.Gold < Config.Pouch.Gold then
		return false, "NotEnoughGold"
	end
	currencies.Gold -= Config.Pouch.Gold
	local stat, tier = Runes.Roll(1, rand, Config.Pouch.Weights)
	Runes.Grant(profile, stat, tier, 1)
	return true, { Stat = stat, Tier = tier, Label = Runes.Label({ Stat = stat, Tier = tier }) }
end

return Runes
