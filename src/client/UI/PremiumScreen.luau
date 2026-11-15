--[[
	PremiumScreen (ModuleScript): the Premium shop.
	  PremiumScreen.Premium(container, state, call, extra)    extra.PremiumTab = "Shop" | "Sunstones"

	Shop tab: spend Sunstones (orange) on fixed-content items. Sunstones tab: buy Sunstones with Robux (Developer Products).
	Sunstones never buy wishes, tickets or Wishstones.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local ORANGE = Color3.fromRGB(255, 165, 70)
local ORANGE_DARK = Color3.fromRGB(70, 44, 18)

local GOOD = Color3.fromRGB(130, 235, 150) -- brighter than the plain green, so it reads on the dark rows

local PremiumScreen = {}

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function listFrame(area)
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = area })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	return scroll
end

local function shopTab(area, state, call, extra, redraw)
	local me = state.Player
	local scroll = listFrame(area)
	local balance = me.Sunstones or 0
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = ("You have 🔶 %s Sunstones. Everything here has fixed contents - nothing random."):format(commas(balance)), TextSize = 12, TextColor3 = ORANGE, Parent = scroll })
	if extra.PremiumMsg then
		Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = extra.PremiumMsg, TextSize = 12, TextColor3 = GOOD, Parent = scroll })
	end
	for _, item in ipairs(me.PremiumShop or {}) do
		if not item.Hidden then
			local soldOut = item.Left ~= nil and item.Left <= 0
			local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = C.PanelLight, Parent = scroll })
			Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(10, 4), Text = item.Name, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = if soldOut then C.Dim else ORANGE, Parent = row })
			Kit.label({ Size = UDim2.new(1, -170, 0, 32), Position = UDim2.fromOffset(10, 24), Text = item.Text, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Dim, Parent = row })
			local limit = if item.Max then (if item.Per == "Account" then ("Once per account (%d/%d)"):format(item.Bought, item.Max) else ("%d/%d this season"):format(item.Bought, item.Max)) else "Unlimited"
			Kit.label({ Size = UDim2.new(1, -170, 0, 14), Position = UDim2.fromOffset(10, 54), Text = limit, TextSize = 10, TextColor3 = C.Dim, Parent = row })
			local can = item.Affordable and not soldOut
			local btn = Kit.button({ Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -150, 0.5, -22), Text = if soldOut then "Sold out" else ("🔶 " .. commas(item.Cost)), BackgroundColor3 = if can then ORANGE else ORANGE_DARK, TextColor3 = if can then Color3.fromRGB(40, 24, 6) else C.Dim, Parent = row }, function()
				if soldOut then
					return
				end
				if not item.Affordable then
					extra.PremiumTab = "Sunstones"
					extra.PremiumMsg = nil
					redraw()
					return
				end
				local ok = call("BuyPremium", item.Id)
				extra.PremiumMsg = if ok then ("Bought: " .. item.Name .. "!") else nil
				redraw()
			end)
			btn.Active = not soldOut
		end
	end
end

local function packsTab(area, state, call, extra, redraw)
	local me = state.Player
	local scroll = listFrame(area)
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = "Sunstones are bought with Robux. The first time you buy each pack you get double.", TextSize = 12, TextColor3 = ORANGE, Parent = scroll })
	for _, pack in ipairs(me.SunstonePacks or {}) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(10, 6), Text = ("🔶 %s  -  %s"):format(commas(pack.Sunstones), pack.Name), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = ORANGE, Parent = row })
		Kit.label({ Size = UDim2.new(1, -170, 0, 16), Position = UDim2.fromOffset(10, 30), Text = if pack.Bonus > 0 then ("First purchase bonus: +%s Sunstones"):format(commas(pack.Bonus)) else "Thank you!", TextSize = 11, TextColor3 = if pack.Bonus > 0 then GOOD else C.Dim, Parent = row })
		Kit.button({ Size = UDim2.fromOffset(140, 40), Position = UDim2.new(1, -150, 0.5, -20), Text = if pack.ProductId == 0 then ("R$ %d (soon)"):format(pack.Robux) else ("R$ %d"):format(pack.Robux), BackgroundColor3 = if pack.ProductId == 0 then ORANGE_DARK else ORANGE, TextColor3 = if pack.ProductId == 0 then C.Dim else Color3.fromRGB(40, 24, 6), Parent = row }, function()
			if pack.ProductId ~= 0 then
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, pack.ProductId)
			end
		end)
	end
	if RunService:IsStudio() then
		Kit.button({ Size = UDim2.new(1, -8, 0, 36), Text = "Studio only: add 1,000 Sunstones", BackgroundColor3 = C.Panel, Parent = scroll }, function()
			call("DevSunstones")
		end)
	end
end

function PremiumScreen.Premium(container, state, call, extra)
	Kit.clear(container)
	local tab = extra.PremiumTab or "Shop"
	local function redraw()
		PremiumScreen.Premium(container, extra.State or state, call, extra)
	end
	for index, name in ipairs({ "Shop", "Sunstones" }) do
		Kit.button({ Size = UDim2.fromOffset(150, 28), Position = UDim2.fromOffset((index - 1) * 156, 0), Text = if name == "Shop" then "Premium shop" else "Get Sunstones", TextSize = 13, BackgroundColor3 = if name == tab then ORANGE else C.Panel, TextColor3 = if name == tab then Color3.fromRGB(40, 24, 6) else C.Text, Parent = container }, function()
			extra.PremiumTab = name
			redraw()
		end)
	end
	Kit.label({ Size = UDim2.fromOffset(200, 28), Position = UDim2.new(1, -204, 0, 0), Text = ("🔶 %s"):format(commas((state.Player.Sunstones or 0))), TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ORANGE, Parent = container })
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	if tab == "Shop" then
		shopTab(area, state, call, extra, redraw)
	else
		packsTab(area, state, call, extra, redraw)
	end
end

return PremiumScreen
