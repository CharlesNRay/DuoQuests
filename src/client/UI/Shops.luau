--[[
	Shops (ModuleScript): the two plaza NPC screens. The server only accepts these actions while
	you stand near the NPC (World.SHOP_RANGE), and Main closes the panel when you walk away.

	  Shops.Merchant(container, state, call, extra)   sell bagged gear, one piece or in bulk
	  Shops.Blacksmith(container, state, call, extra) upgrade worn or bagged gear with gold
]]
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
	local scroll = list(container, 44)
	Kit.label({ Size = UDim2.new(0.3, 0, 0, 40), Text = ("Gold: %d\nBag %d/%d"):format(gold(state), #gear.Inventory, gear.Cap), TextColor3 = C.Accent, TextSize = 13, Parent = container })
	for index, name in ipairs({ "Sell", "Supplies" }) do
		Kit.button({ Size = UDim2.fromOffset(78, 38), Position = UDim2.new(0.3, (index - 1) * 82, 0, 0), Text = name, BackgroundColor3 = if tab == name then C.Accent else C.Panel, TextColor3 = if tab == name then C.Bg else C.Text, Parent = container }, function()
			extra.MerchantTab = name
			Shops.Merchant(container, state, call, extra)
		end)
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

	Kit.button({ Size = UDim2.new(0.2, -4, 0, 38), Position = UDim2.new(0.6, 0, 0, 0), Text = "Sell Common", TextSize = 12, Parent = container }, function()
		call("SellBulk", "Common")
	end)
	Kit.button({ Size = UDim2.new(0.2, -4, 0, 38), Position = UDim2.new(0.8, 0, 0, 0), Text = "Sell worse", TextSize = 12, Parent = container }, function()
		call("SellBulk", "Worse")
	end)

	local shown = 0
	for _, item in ipairs(gear.Inventory) do
		shown += 1
		local cmp = Tips.Compare(item, gear)
		local r = row(scroll, 54)
		r.LayoutOrder = shown
		Icons.Item(r, item, { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 6) })
		Kit.Hover(r, function() return Tips.Item(item, gear) end)
		local mark = if cmp.Verdict == "Up" then "  ▲ better than worn" elseif cmp.Verdict == "Down" then "  ▼ worse than worn" else ""
		Kit.label({ Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(60, 0), Text = ("%s%s\n%s  %s  (Item Power %d)"):format(nameOf(item), mark, item.Slot, item.StatText, item.ItemPower or 0), TextColor3 = if cmp.Verdict == "Up" then C.Good else C.Text, TextSize = 13, Parent = r })
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
	Kit.label({ Size = UDim2.new(1, 0, 0, 24), Text = ("Gold: %d   -   each level adds %d%% of the base stat; costs climb quickly"):format(gold(state), 6), TextColor3 = C.Accent, TextSize = 13, Parent = container })

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

return Shops
