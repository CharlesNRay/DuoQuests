--[[
	Cosmetics (ModuleScript)
	Location: ReplicatedStorage > Shared > Cosmetics

	Auras, kill effects, name colours and titles (see Config/Cosmetics). Looks only, never power.
	Owned ids live in Permanent.Cosmetics (titles in Permanent.Titles); what is worn lives in Permanent.CosmeticsEquipped.
	Both are permanent: they survive seasons.

	  Cosmetics.Def(id)                   -> definition | nil
	  Cosmetics.Owned(profile, id)        -> boolean       (id of an item, or the text of a title)
	  Cosmetics.Equipped(profile)         -> { Aura?, Kill?, Name?, Title? }  (only things still owned)
	  Cosmetics.Equip(profile, slot, id)  -> true | false, "BadSlot" | "NotOwned"      (id nil takes the slot off)
	  Cosmetics.Buy(profile, id)          -> true, { Name, Cost } | false, "BadItem" | "NotForSale" | "AlreadyOwned" | "NotEnough"
	  Cosmetics.BuyBundle(profile, bundleId) / Cosmetics.BundlePrice / Cosmetics.Bundles(profile)   themed sets of three, cheaper than singles
	  Cosmetics.List(profile, slot)       -> rows { Id, Name, Source, Cost, Owned, Equipped, Affordable, Class?, Color, Color2?, Rainbow? }
	  Cosmetics.Look(profile)             -> what other players see: { Aura?, Kill?, Name?, Title? } (ids; Title is the text)
	  Cosmetics.GrantTitle(profile, text) / Cosmetics.Grant(profile, id)      used by the season rewards
]]

local Config = require(script.Parent.Config.Cosmetics)
local Premium = require(script.Parent.Premium)

local Cosmetics = {}

local defById = {}
for _, def in ipairs(Config.Items) do
	defById[def.Id] = def
end
local shopTitle = {}
for _, t in ipairs(Config.ShopTitles) do
	shopTitle[t.Id] = t
end

local function isSlot(slot)
	return table.find(Config.Slots, slot) ~= nil
end

local function equippedTable(profile)
	profile.Permanent.CosmeticsEquipped = profile.Permanent.CosmeticsEquipped or {}
	return profile.Permanent.CosmeticsEquipped
end

function Cosmetics.Def(id)
	return defById[id]
end

function Cosmetics.Owned(profile, id)
	return profile.Permanent.Cosmetics[id] == true or profile.Permanent.Titles[id] == true
end

function Cosmetics.Grant(profile, id)
	profile.Permanent.Cosmetics[id] = true
end

function Cosmetics.GrantTitle(profile, text)
	profile.Permanent.Titles[text] = true
end

function Cosmetics.Equipped(profile)
	local out = {}
	for slot, id in pairs(equippedTable(profile)) do
		if slot == "Title" then
			if profile.Permanent.Titles[id] then
				out.Title = id
			end
		elseif defById[id] and defById[id].Slot == slot and profile.Permanent.Cosmetics[id] then
			out[slot] = id
		end
	end
	return out
end

function Cosmetics.Equip(profile, slot, id)
	if not isSlot(slot) then
		return false, "BadSlot"
	end
	local worn = equippedTable(profile)
	if id == nil then
		worn[slot] = nil
		return true
	end
	if type(id) ~= "string" then
		return false, "NotOwned"
	end
	if slot == "Title" then
		if not profile.Permanent.Titles[id] then
			return false, "NotOwned"
		end
	else
		local def = defById[id]
		if def == nil or def.Slot ~= slot or not profile.Permanent.Cosmetics[id] then
			return false, "NotOwned"
		end
	end
	worn[slot] = id
	return true
end

function Cosmetics.Buy(profile, id)
	local def = defById[id]
	local title = shopTitle[id]
	if def == nil and title == nil then
		return false, "BadItem"
	end
	if def and def.Source ~= "Shop" then
		return false, "NotForSale"
	end
	if Cosmetics.Owned(profile, id) then
		return false, "AlreadyOwned"
	end
	local cost = if def then def.Cost else title.Cost
	local ok, reason = Premium.SpendSunstones(profile, cost)
	if not ok then
		return false, reason
	end
	if def then
		profile.Permanent.Cosmetics[id] = true
	else
		profile.Permanent.Titles[id] = true
	end
	return true, { Name = if def then def.Name else id, Cost = cost }
end

-- What a bundle costs this player: the set price, lowered in proportion to the items they already own.
-- -> price, full price of the unowned items bought one by one
function Cosmetics.BundlePrice(profile, bundle)
	local total, unowned = 0, 0
	for _, id in ipairs(bundle.Items) do
		local def = defById[id]
		total += def.Cost
		if not profile.Permanent.Cosmetics[id] then
			unowned += def.Cost
		end
	end
	return math.floor(bundle.Cost * unowned / total + 0.5), unowned
end

function Cosmetics.BuyBundle(profile, bundleId)
	local bundle
	for _, b in ipairs(Config.Bundles) do
		if b.Id == bundleId then
			bundle = b
		end
	end
	if bundle == nil then
		return false, "BadItem"
	end
	local price, unowned = Cosmetics.BundlePrice(profile, bundle)
	if unowned == 0 then
		return false, "AlreadyOwned"
	end
	local ok, reason = Premium.SpendSunstones(profile, price)
	if not ok then
		return false, reason
	end
	for _, id in ipairs(bundle.Items) do
		profile.Permanent.Cosmetics[id] = true
	end
	return true, { Name = bundle.Name, Cost = price }
end

-- Rows for the Bundles tab.
function Cosmetics.Bundles(profile)
	local rows = {}
	local balance = Premium.Sunstones(profile)
	for _, bundle in ipairs(Config.Bundles) do
		local price, unowned = Cosmetics.BundlePrice(profile, bundle)
		local names = {}
		for _, id in ipairs(bundle.Items) do
			table.insert(names, defById[id].Name)
		end
		table.insert(rows, { Id = bundle.Id, Name = bundle.Name, Items = names, Price = price, Separate = unowned, Owned = unowned == 0, Affordable = balance >= price })
	end
	return rows
end

function Cosmetics.List(profile, slot)
	local rows = {}
	local worn = Cosmetics.Equipped(profile)
	local balance = Premium.Sunstones(profile)
	if slot == "Title" then
		local seen = {}
		for _, t in ipairs(Config.ShopTitles) do
			seen[t.Id] = true
			local owned = profile.Permanent.Titles[t.Id] == true
			table.insert(rows, { Id = t.Id, Name = t.Id, Source = "Shop", Cost = t.Cost, Owned = owned, Equipped = worn.Title == t.Id, Affordable = balance >= t.Cost })
		end
		local extra = {}
		for text in pairs(profile.Permanent.Titles) do
			if not seen[text] then
				table.insert(extra, text)
			end
		end
		table.sort(extra)
		for _, text in ipairs(extra) do
			table.insert(rows, { Id = text, Name = text, Source = "Season", Cost = 0, Owned = true, Equipped = worn.Title == text, Affordable = true })
		end
		return rows
	end
	for _, def in ipairs(Config.Items) do
		if def.Slot == slot then
			local owned = profile.Permanent.Cosmetics[def.Id] == true
			-- season prizes you do not own are listed too (locked), so players see what there is to win
			table.insert(rows, {
				Id = def.Id, Name = def.Name, Source = def.Source, Cost = def.Cost, Owned = owned, Equipped = worn[slot] == def.Id,
				Affordable = def.Source == "Shop" and balance >= def.Cost, Class = def.Class, Color = def.Color, Color2 = def.Color2, Rainbow = def.Rainbow,
			})
		end
	end
	return rows
end

function Cosmetics.Look(profile)
	return Cosmetics.Equipped(profile)
end

return Cosmetics
