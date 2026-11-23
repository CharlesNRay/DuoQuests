--[[
	Shops (ModuleScript): the two plaza NPC screens. The server only accepts these actions while
	you stand near the NPC (World.SHOP_RANGE), and Main closes the panel when you walk away.

	  Shops.Merchant(container, state, call, extra)   sell bagged gear, one piece or in bulk
	  Shops.Blacksmith(container, state, call, extra) upgrade worn or bagged gear with gold
	  Shops.PetStore(container, state, call, extra)   eggs, pet gear crates and pet food
	  Shops.Trainer(container, state, call, extra)    level the skill slots with gold
]]
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local Gear = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Gear)
local C = Kit.Colors

local Shops = {}

local function list(container, top)
	Kit.clear(container)
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -top), Position = UDim2.fromOffset(0, top), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = container,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	return scroll
end

local function row(parent, height)
	return Kit.frame({ Size = UDim2.new(1, -10, 0, height), BackgroundColor3 = C.PanelLight, Parent = parent })
end

local function nameOf(item)
	return item.Name .. ((item.Upgrade or 0) > 0 and ("  +" .. item.Upgrade) or "")
end

local function fmt(v)
	if v < 10 then
		return ("%.1f"):format(v)
	end
	return tostring(math.floor(v + 0.5))
end

local function gold(state)
	return state.Player.Gold
end

-- Merchant -----------------------------------------------------------------
-- Tabs: Sell (bagged gear, one piece or in bulk) and Supplies (boosts and pet food for gold).
function Shops.Merchant(container, state, call, extra)
	extra = extra or {}
	local tab = extra.MerchantTab or "Sell"
	local gear = state.Player.Gear
	local scroll = list(container, if tab == "Sell" then 78 else 44)
	Kit.label({ Size = UDim2.new(0.3, 0, 0, 40), Text = ("Gold: %s\nBag %d/%d"):format(Short(gold(state)), #gear.Inventory, gear.Cap), TextColor3 = C.Accent, TextSize = 13, Parent = container })
	for index, name in ipairs({ "Sell", "Supplies", "Bag" }) do
		Kit.button({ Size = UDim2.fromOffset(62, 38), Position = UDim2.new(0.3, (index - 1) * 66, 0, 0), Text = name, BackgroundColor3 = if tab == name then C.Accent else C.Panel, TextColor3 = if tab == name then C.Bg else C.Text, Parent = container }, function()
			extra.MerchantTab = name
			Shops.Merchant(container, state, call, extra)
		end)
	end

	if tab == "Bag" then
		local cost = gear.BagCost
		Kit.label({ Size = UDim2.new(1, 0, 0, 44), Text = ("Your bag holds %d pieces of gear (%d in use).\nEach upgrade adds %d slots."):format(gear.Cap, #gear.Inventory, gear.BagStep or 5), TextColor3 = C.Text, TextSize = 14, TextWrapped = true, Parent = scroll })
		if cost then
			local can = gold(state) >= cost
			local b = Kit.button({ Size = UDim2.new(1, -8, 0, 46), Text = ("Upgrade bag  (+%d slots)  -  %s gold"):format(gear.BagStep or 5, Short(cost)), TextSize = 15, BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = scroll }, function()
				if can then
					call("UpgradeBag")
				end
			end)
			b.Active = can
		else
			Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Your bag is as big as it gets.", TextColor3 = C.Good, TextSize = 14, Parent = scroll })
		end
		return
	end

	if tab == "Supplies" then
		for index, item in ipairs(state.Player.Supplies or {}) do
			local r = row(scroll, 54)
			r.LayoutOrder = index
			Kit.label({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 7), Text = item.Glyph, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = r })
			Kit.label({ Size = UDim2.new(1, -160, 1, 0), Position = UDim2.fromOffset(56, 0), Text = ("%s\n%s"):format(item.Name, item.Description), TextSize = 12, Parent = r })
			local can = gold(state) >= item.Price
			local b = Kit.button({ Size = UDim2.fromOffset(92, 40), Position = UDim2.new(1, -98, 0.5, -20), Text = "Buy " .. item.Price .. "g", BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = r }, function()
				if can then
					call("BuyConsumable", item.Id, 1)
				end
			end)
			b.Active = can
		end
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Boosts and pet food go to your Stash (Bag > Stash).", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
		return
	end

	-- ticked rarities are sold by the one Sell button (set pieces and upgraded gear are always kept)
	local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	extra.SellRarities = extra.SellRarities or { Common = true }
	local picked, count, goldTotal = {}, 0, 0
	for _, rarity in ipairs(RARITIES) do
		if extra.SellRarities[rarity] then
			table.insert(picked, rarity)
		end
	end
	for _, item in ipairs(gear.Inventory) do
		if extra.SellRarities[item.Rarity] and not item.SetId and (item.Upgrade or 0) == 0 then
			count += 1
			goldTotal += item.SellValue or 0
		end
	end
	local can = count > 0
	local sellButton = Kit.button({ Size = UDim2.new(0.32, -4, 0, 38), Position = UDim2.new(0.68, 0, 0, 0), Text = if can then ("Sell (%d items)\n+%sg"):format(count, Short(goldTotal)) else "Sell\n(none ticked)", TextSize = 12, BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then C.Bg else C.Dim, Parent = container }, function()
		if can then
			call("SellBulk", picked)
		end
	end)
	sellButton.Active = can
	for index, rarity in ipairs(RARITIES) do
		local on = extra.SellRarities[rarity] == true
		Kit.button({ Size = UDim2.new(0.2, -4, 0, 28), Position = UDim2.new((index - 1) * 0.2, 0, 0, 44), Text = (if on then "☑ " else "☐ ") .. rarity, TextSize = 12, TextWrapped = false, TextColor3 = Kit.rarityColor(rarity), BackgroundColor3 = if on then C.PanelLight else C.Panel, Parent = container }, function()
			extra.SellRarities[rarity] = if on then nil else true
			Shops.Merchant(container, state, call, extra)
		end)
	end

	local shown = 0
	for _, item in ipairs(gear.Inventory) do
		shown += 1
		local cmp = Tips.Compare(item, gear)
		local r = row(scroll, 54)
		r.LayoutOrder = shown
		Icons.Item(r, item, { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 6) })
		Kit.Hover(r, function() return Tips.Item(item, gear) end)
		local mark = if cmp.Verdict == "Up" then "  ▲ better than worn" elseif cmp.Verdict == "Down" then "  ▼ worse than worn" else ""
		Kit.label({ Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(60, 0), Text = ("%s%s\n%s  %s  (IP %s)"):format(nameOf(item), mark, item.Slot, item.StatText, Short(item.ItemPower or 0)), TextColor3 = if cmp.Verdict == "Up" then C.Good else C.Text, TextSize = 13, Parent = r })
		Kit.button({ Size = UDim2.fromOffset(96, 40), Position = UDim2.new(1, -102, 0.5, -20), Text = "Sell " .. item.SellValue .. "g", BackgroundColor3 = C.Panel, Parent = r }, function()
			call("SellGear", item.Id)
		end)
	end
	if shown == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 60), Text = "\"Nothing to sell? Come back with loot!\"\nWin fights to find gear. Worn gear is never sold here.", TextColor3 = C.Dim, Parent = scroll })
	else
		Kit.label({ Size = UDim2.new(1, 0, 0, 34), Text = "Bulk sales keep set pieces and upgraded items.", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	end
end

-- Blacksmith ---------------------------------------------------------------
local SLOT_ORDER = Gear.WornSlots

local lastPouch = nil -- what the last rune pouch gave, shown on the pouch row
function Shops.Blacksmith(container, state, call)
	local gear = state.Player.Gear
	local scroll = list(container, 26)
	Kit.label({ Size = UDim2.new(1, 0, 0, 24), Text = ("Gold: %s   -   each level adds %d%% of the base stat; costs climb quickly"):format(Short(gold(state)), 6), TextColor3 = C.Accent, TextSize = 13, Parent = container })

	local function block(item, where)
		local cost = item.UpgradeCost
		local r = row(scroll, 58)
		Icons.Item(r, item, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 7) })
		Kit.Hover(r, function() return Tips.Item(item, gear) end)
		local pips = ("%d/%d"):format(item.Upgrade or 0, item.MaxUpgrade or 10)
		local detail
		if cost then
			detail = ("%s  ->  %s  (%s)"):format(item.StatText, Gear.FormatStat(item.Stat, item.NextValue), pips)
		else
			detail = ("%s   MAX (%s)"):format(item.StatText, pips)
		end
		Kit.label({ Size = UDim2.new(1, -160, 1, 0), Position = UDim2.fromOffset(60, 0), Text = ("%s   [%s]\n%s"):format(nameOf(item), where, detail), TextColor3 = C.Text, TextSize = 13, Parent = r })
		if cost then
			local can = gold(state) >= cost
			local b = Kit.button({ Size = UDim2.fromOffset(112, 42), Position = UDim2.new(1, -118, 0.5, -21), Text = "Upgrade\n" .. cost .. "g", BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = r }, function()
				if can then
					call("UpgradeGear", item.Id)
				end
			end)
			b.Active = can
		else
			Kit.label({ Size = UDim2.fromOffset(112, 40), Position = UDim2.new(1, -118, 0.5, -20), Text = "Maxed", TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Parent = r })
		end
	end

	-- rune pouch: one random rune to carve onto gear (Bag > Gear > Carve rune)
	do
		local price = state.Player.RunePouch or 0
		local r = row(scroll, 52)
		Kit.label({ Size = UDim2.fromOffset(40, 52), Position = UDim2.fromOffset(8, 0), Text = "🔮", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Parent = r })
		Kit.label({ Size = UDim2.new(1, -180, 1, 0), Position = UDim2.fromOffset(54, 0), RichText = true, TextSize = 12, Text = "<b>Rune pouch</b>  one random rune (80% Common, 18% Rare, 2% Epic)\n" .. (lastPouch or "Carve runes onto gear from Bag > Gear. Bosses and dungeons drop them too."), Parent = r })
		local can = gold(state) >= price
		local b = Kit.button({ Size = UDim2.fromOffset(112, 40), Position = UDim2.new(1, -118, 0.5, -20), Text = "Buy\n" .. Short(price) .. "g", BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then C.Bg else C.Dim, Parent = r }, function()
			if can then
				local ok, got = call("BuyRunePouch")
				if ok and got then
					lastPouch = "You got: " .. tostring(got.Label)
				end
			end
		end)
		b.Active = can
	end

	local any = false
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Text = "Worn", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	for _, slot in ipairs(SLOT_ORDER) do
		local item = gear.Equipped[slot]
		if item then
			any = true
			block(item, "worn")
		end
	end
	if #gear.Inventory > 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Text = "In your bag", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
		for _, item in ipairs(gear.Inventory) do
			any = true
			block(item, "bag")
		end
	end
	if not any then
		Kit.label({ Size = UDim2.new(1, 0, 0, 50), Text = "\"Bring me something to work on.\"", TextColor3 = C.Dim, Parent = scroll })
	end
end

-- Skill Trainer ---------------------------------------------------------------
-- A slot's level stays with the SLOT: swap the skill in it and the level stays. Skill rank (from copies) adds on top.
function Shops.Trainer(container, state, call)
	local me = state.Player
	local Skills = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Skills)
	local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Economy)
	local Abilities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Abilities)
	local scroll = list(container, 40)
	Kit.label({ Size = UDim2.new(1, 0, 0, 38), Text = ("Gold: %s\nEach slot level adds +1 to the skill in it. Rank (from spare copies) adds on top."):format(Short(gold(state))), TextColor3 = C.Accent, TextSize = 13, TextWrapped = true, Parent = container })
	for slot, id in ipairs(me.Loadout) do
		local def = Abilities[id]
		local base = (me.SlotBase or {})[slot] or 1
		local r = row(scroll, 60)
		if def then
			Icons.Skill(r, def, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 8), Level = me.SlotLevels[slot] })
			Kit.Hover(r, function() return Tips.Skill(def, me.SlotLevels[slot], ((me.SkillInfo or {})[id] or {}).Tier) end)
		end
		Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(60, 0), Text = ("Slot %d  -  Lv %d / %d\n%s  (fights at Lv %d)"):format(slot, base, Skills.MAX_SLOT_LEVEL, def and def.DisplayName or "?", me.SlotLevels[slot] or 1), TextColor3 = C.Text, TextSize = 13, Parent = r })
		if base >= Skills.MAX_SLOT_LEVEL then
			Kit.label({ Size = UDim2.fromOffset(104, 40), Position = UDim2.new(1, -110, 0.5, -20), Text = "Maxed", TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Parent = r })
		else
			local cost = Economy.SlotLevelCost(base)
			local can = gold(state) >= cost
			local b = Kit.button({ Size = UDim2.fromOffset(104, 42), Position = UDim2.new(1, -110, 0.5, -21), Text = "Train\n" .. Short(cost) .. "g", BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = r }, function()
				if can then
					call("LevelSlot", slot)
				end
			end)
			b.Active = can
		end
	end
end

-- Pet Store ---------------------------------------------------------------------
-- Eggs (Pet Wish tickets), pet gear crates and pet food. Wear the gear on the Pets screen.
-- what the last crate gave, shown in the header for a few seconds (the screen redraws after every buy)
local lastPull -- { Text = rich text, At = os.clock() }
local PULL_SHOW_SECONDS = 12

local function pullText(piece)
	local PetGearConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.PetGear)
	local stat = ("+%.1f%% %s"):format(piece.Value * 100, (PetGearConfig.StatUnits[piece.Stat] or {}).Label or piece.Stat)
	return ("Got: %s %s  %s"):format(PetGearConfig.KindGlyph[piece.Kind] or "", Kit.tint(piece.Rarity .. " " .. piece.Kind, Kit.rarityColor(piece.Rarity)), stat)
end

-- remember what a buy gave and write it into the header call() has just redrawn
local function showPull(container, text)
	lastPull = { Text = text, At = os.clock() }
	local header = container:FindFirstChild("PetStoreHeader")
	if header then
		header.Text = (header.Text:match("^Gold: [^ ]+") or "") .. "   -   " .. text
	end
end

function Shops.PetStore(container, state, call)
	local me = state.Player
	local g = me.PetGear
	local scroll = list(container, 26)
	local goldText = ("Gold: %s"):format(Short(gold(state)))
	local function headerText()
		if lastPull and os.clock() - lastPull.At < PULL_SHOW_SECONDS then
			return goldText .. "   -   " .. lastPull.Text
		end
		return goldText .. "   -   wear what you buy on the Pets screen (Pet gear)"
	end
	Kit.label({ Name = "PetStoreHeader", Size = UDim2.new(1, 0, 0, 24), RichText = true, Text = headerText(), TextColor3 = C.Accent, TextSize = 13, Parent = container })
	local function offer(glyph, name, desc, price, buttonText, action, enabled)
		local r = row(scroll, 60)
		Kit.label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 8), Text = glyph, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = r })
		Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(60, 0), Text = name .. "\n" .. desc, TextColor3 = C.Text, TextSize = 12, TextWrapped = true, Parent = r })
		local can = enabled and gold(state) >= price
		local b = Kit.button({ Size = UDim2.fromOffset(104, 42), Position = UDim2.new(1, -110, 0.5, -21), Text = buttonText .. "\n" .. Short(price) .. "g", TextSize = 12, BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = r }, function()
			if can then
				action()
			end
		end)
		b.Active = can
	end
	offer("🥚", "Pet Egg", ("A Pet Wish: hatch it at the Wishing Tree.  %d left today"):format(g.EggsLeft), g.EggPrice, "Buy", function()
		local ok = call("BuyPetEgg")
		if ok then
			showPull(container, "Got: 🥚 a Pet Wish - hatch it at the Wishing Tree")
		end
	end, g.EggsLeft > 0)
	for _, crate in ipairs(g.Crates) do
		local odds = {}
		for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
			table.insert(odds, ("%s %d%%"):format(rarity:sub(1, 1), crate.Odds[rarity] or 0))
		end
		offer(crate.Glyph, crate.Name, "One piece of pet gear.  " .. table.concat(odds, "  "), crate.Price, "Open", function()
			local ok, piece = call("BuyPetGearCrate", crate.Id)
			if ok and type(piece) == "table" and piece.Kind then
				showPull(container, pullText(piece))
			end
		end, #g.Bag < g.BagSize)
	end
	for _, item in ipairs(me.Supplies or {}) do
		if item.Kind == "PetFood" then
			offer(item.Glyph, item.Name, item.Description, item.Price, "Buy", function() call("BuyConsumable", item.Id, 1) end, true)
		end
	end
end

return Shops
