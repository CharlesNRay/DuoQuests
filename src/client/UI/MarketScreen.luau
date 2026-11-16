--[[
	MarketScreen (ModuleScript): the gold Market tab of the Store window. Daily items refresh every day, season items a few times per season.
	  MarketScreen.Market(container, state, call, extra)
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local MarketScreen = {}

local NumberFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat)
local commas = NumberFormat.Short

local REASONS = { SoldOut = "Sold out for now.", NotEnough = "Not enough gold.", Unknown = "That is not for sale." }

function MarketScreen.Market(container, state, call, extra)
	Kit.clear(container)
	local items = state.Player.Market or {}
	local gold = state.Player.Gold or 0
	local function redraw()
		MarketScreen.Market(container, extra.State or state, call, extra)
	end
	Kit.label({ Size = UDim2.new(1, -170, 0, 22), Text = "Daily items refresh every day. Season items stay for the whole season.", TextSize = 12, TextColor3 = C.Dim, Parent = container })
	Kit.label({ Size = UDim2.fromOffset(160, 22), Position = UDim2.new(1, -160, 0, 0), Text = "💰 " .. commas(gold), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = container })
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 58), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	for _, item in ipairs(items) do
		local soldOut = item.Bought >= item.Limit
		local can = not soldOut and gold >= item.Price
		local f = Kit.frame({ BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.label({ Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(6, 12), Text = item.Glyph, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = f })
		Kit.label({ Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(44, 6), Text = item.Name, TextSize = 13, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = f })
		Kit.label({ Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(44, 24), Text = ("%s  %d / %d"):format(if item.Window == "Day" then "Today" else "This season", item.Bought, item.Limit), TextSize = 11, TextColor3 = if item.Window == "Season" then C.Epic else C.Dim, TextWrapped = false, Parent = f })
		Kit.label({ Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(44, 39), Text = if soldOut then "Sold out" else "💰 " .. commas(item.Price), TextSize = 11, TextColor3 = if soldOut then C.Dim elseif can then C.Accent else C.Bad, TextWrapped = false, Parent = f })
		local b = Kit.button({ Size = UDim2.fromOffset(86, 32), Position = UDim2.new(1, -94, 0.5, -16), Text = if soldOut then "Sold out" else "Buy", TextSize = 13, BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then Color3.fromRGB(30, 22, 6) else C.Dim, Parent = f }, function()
			if not can then
				return
			end
			local ok, result = call("MarketBuy", item.Id)
			extra.MarketMsg = if ok then ("Bought: " .. table.concat(result, ", ")) else (REASONS[result] or "Could not buy that.")
			extra.MarketBad = not ok
			redraw()
		end)
		b.Active = can
	end
	if extra.MarketMsg then
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -22), Text = extra.MarketMsg, TextSize = 12, TextColor3 = if extra.MarketBad then C.Bad else C.Good, Parent = container })
	end
end

return MarketScreen
