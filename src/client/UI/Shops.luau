--[[
	Shops (ModuleScript): the plaza NPC screens. The server only accepts these actions while
	you stand near the NPC (World.SHOP_RANGE), and Main closes the panel when you walk away.

	  Shops.Merchant(container, state, call, extra)   sell bagged gear, one piece or in bulk
	  Shops.Blacksmith(container, state, call, extra) upgrade worn or bagged gear with gold
	  Shops.PetStore(container, state, call, extra)   eggs, pet gear crates and pet food
	  Shops.Trainer(container, state, call, extra)    level the skill slots with gold
	  Shops.RuneCarver(container, state, call, extra) carve runes onto gear, buy rune pouches
]]
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local Gear = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Gear)
local GearConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Gear)
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
-- Tabs: Sell (bagged gear, one piece or in bulk) and Supplies (boosts for gold; pet food is at the Pet Store).
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
			if item.Kind == "PetFood" then
				continue -- pet food is sold only at the Pet Store (owner, 2026-11-27)
			end
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
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Boosts go to your Stash (Bag > Stash). Pet food is at the Pet Store.", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
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

function Shops.Blacksmith(container, state, call)
	local gear = state.Player.Gear
	local scroll = list(container, 26)
	local up = GearConfig.Upgrade
	local cap = gear.UpgradeCap or up.MaxLevel
	local capText = if up.LevelCap and cap < up.LevelCap.Max then ("upgrades open to +%d (one more every %d hero levels past %d, up to +%d)"):format(cap, up.LevelCap.Every, up.LevelCap.From, up.LevelCap.Max) else ("upgrades open to +%d"):format(cap)
	Kit.label({ Size = UDim2.new(1, 0, 0, 24), Text = ("Gold: %s   -   %s"):format(Short(gold(state)), capText), TextColor3 = C.Accent, TextSize = 13, Parent = container })

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
			local b = Kit.button({ Size = UDim2.fromOffset(112, 42), Position = UDim2.new(1, -118, 0.5, -21), Text = "Upgrade\n" .. Short(cost) .. "g", BackgroundColor3 = if can then C.Up else C.Panel, TextColor3 = if can then C.Text else C.Dim, Parent = r }, function()
				if can then
					call("UpgradeGear", item.Id)
				end
			end)
			b.Active = can
		else
			local atTop = not up.LevelCap or (item.Upgrade or 0) >= up.LevelCap.Max
			Kit.label({ Size = UDim2.fromOffset(112, 40), Position = UDim2.new(1, -118, 0.5, -20), Text = if atTop then "Maxed" else "Max for\nyour level", TextSize = 12, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Parent = r })
		end
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
		local full = #g.Bag >= g.BagSize
		local text = if full
			then ("Pet gear bag full (%d/%d): wear or sell some on the Pets screen first."):format(#g.Bag, g.BagSize)
			else "One piece of pet gear.  " .. table.concat(odds, "  ")
		offer(crate.Glyph, crate.Name, text, crate.Price, "Open", function()
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

-- Rune Carver ----------------------------------------------------------------
-- Left: your gear (worn first). Right: the chosen piece's rune and every rune you own; tap one to carve it.
-- Replacing a higher-tier rune asks first. The rune pouch is sold here too.
local RuneCfg = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Runes)
local RuneRank = {}
for index, tier in ipairs(RuneCfg.Tiers) do
	RuneRank[tier] = index
end
local lastPouch = nil -- what the last rune pouch gave
function Shops.RuneCarver(container, state, call, extra)
	extra = extra or {}
	local gear = state.Player.Gear
	local runes = state.Player.Runes or {}
	Kit.clear(container)
	local function redraw()
		Shops.RuneCarver(container, extra.State or state, call, extra)
	end

	-- top: the rune pouch
	local price = state.Player.RunePouch or 0
	local top = row(container, 44)
	Kit.label({ Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(10, 0), RichText = true, TextSize = 12, Text = ("<b>Rune pouch</b>: one random rune (80%% Common, 18%% Rare, 2%% Epic)   Gold %s\n%s"):format(Short(gold(state)), lastPouch or "Bosses, dungeons and a few frontier wins drop runes too."), Parent = top })
	local can = gold(state) >= price
	local buy = Kit.button({ Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -126, 0.5, -17), Text = "Buy " .. Short(price) .. "g", BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then C.Bg else C.Dim, Parent = top }, function()
		if can then
			local ok, got = call("BuyRunePouch")
			if ok and got then
				lastPouch = "You got: " .. tostring(got.Label)
				redraw() -- the call redrew before this line ran
			end
		end
	end)
	buy.Active = can

	-- gear list (worn first)
	local entries = {}
	for _, slotName in ipairs(Gear.WornSlots) do
		local item = gear.Equipped[slotName]
		if item then
			table.insert(entries, { Item = item, Worn = true })
		end
	end
	for _, item in ipairs(gear.Inventory) do
		table.insert(entries, { Item = item })
	end
	if #entries == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 54), Text = "\"Bring me gear and I will carve power into it.\"\nYou have no gear yet.", TextColor3 = C.Dim, Parent = container })
		return
	end
	local chosen = entries[1]
	for _, entry in ipairs(entries) do
		if entry.Item.Id == extra.CarveSel then
			chosen = entry
		end
	end
	local left = Kit.new("ScrollingFrame", { Size = UDim2.new(0.5, -6, 1, -52), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = left })
	for _, entry in ipairs(entries) do
		local item = entry.Item
		local isSel = item == chosen.Item
		local b = Kit.button({ Size = UDim2.new(1, -8, 0, 40), Text = "", BackgroundColor3 = if isSel then C.Panel else C.PanelLight, Parent = left }, function()
			extra.CarveSel, extra.CarveConfirm = item.Id, nil
			redraw()
		end)
		if isSel then
			Kit.new("UIStroke", { Color = C.Accent, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
		end
		Icons.Item(b, item, { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(4, 4) })
		local runeText = if item.Rune then Kit.tint(((RuneCfg.Stats[item.Rune.Stat] or {}).Glyph or "") .. " " .. tostring(item.Rune.Label), Kit.rarityColor(item.Rune.Tier)) else Kit.tint("no rune", C.Dim)
		Kit.label({ Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(40, 0), RichText = true, TextSize = 11, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Text = ("%s%s\n%s"):format(if entry.Worn then "[worn] " else "", nameOf(item), runeText), Parent = b })
	end

	-- right: carve onto the chosen piece
	local item = chosen.Item
	local right = Kit.frame({ Size = UDim2.new(0.5, -4, 1, -52), Position = UDim2.new(0.5, 4, 0, 52), BackgroundColor3 = C.Panel, Parent = container })
	local confirmKey = extra.CarveConfirm
	if confirmKey then
		local newRow
		for _, r in ipairs(runes) do
			if r.Key == confirmKey then
				newRow = r
			end
		end
		Kit.label({ Size = UDim2.new(1, -16, 1, -50), Position = UDim2.fromOffset(8, 6), RichText = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Text = ("%s\n%s\n\nwill be replaced by\n%s\n\nThe old rune is lost."):format(Kit.tint("Replace a higher-tier rune?", C.Bad), Kit.tint(item.Rune and item.Rune.Label or "?", Kit.rarityColor(item.Rune and item.Rune.Tier or "Common")), Kit.tint(newRow and newRow.Label or "?", Kit.rarityColor(newRow and newRow.Tier or "Common"))), Parent = right })
		Kit.button({ Size = UDim2.new(0.5, -12, 0, 30), Position = UDim2.new(0, 8, 1, -38), Text = "Replace", TextSize = 13, BackgroundColor3 = C.Bad, Parent = right }, function()
			extra.CarveConfirm = nil
			call("CarveRune", item.Id, confirmKey, true)
		end)
		Kit.button({ Size = UDim2.new(0.5, -12, 0, 30), Position = UDim2.new(0.5, 4, 1, -38), Text = "Cancel", TextSize = 13, BackgroundColor3 = C.PanelLight, Parent = right }, function()
			extra.CarveConfirm = nil
			redraw()
		end)
		return
	end
	Kit.label({ Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 4), RichText = true, TextSize = 12, Text = ("<b>%s</b>\n%s"):format(nameOf(item), if item.Rune then ("Rune: " .. Kit.tint(tostring(item.Rune.Label), Kit.rarityColor(item.Rune.Tier))) else "No rune yet. One rune per piece; a new one replaces the old."), Parent = right })
	local pick = Kit.new("ScrollingFrame", { Size = UDim2.new(1, -8, 1, -44), Position = UDim2.fromOffset(4, 40), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, Parent = right })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 3), Parent = pick })
	if #runes == 0 then
		Kit.label({ Size = UDim2.new(1, -6, 0, 40), Text = "You have no runes. Buy a pouch above, or beat bosses and dungeons.", TextSize = 11, TextColor3 = C.Dim, Parent = pick })
	end
	for _, r in ipairs(runes) do
		local b = Kit.button({ Size = UDim2.new(1, -6, 0, 30), RichText = true, Text = ("%s %s  x%d   - carve"):format(r.Glyph or "", Kit.tint(r.Label, Kit.rarityColor(r.Tier)), r.Count), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = C.PanelLight, Parent = pick }, function()
			local oldRank = item.Rune and RuneRank[item.Rune.Tier] or 0
			if oldRank > (RuneRank[r.Tier] or 0) then
				extra.CarveConfirm = r.Key
				redraw()
			else
				call("CarveRune", item.Id, r.Key, false)
			end
		end)
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = b })
	end
end

return Shops
