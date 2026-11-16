--[[
	StoreScreen (ModuleScript): the one Store window. Tabs: the Premium shop (and Sunstone packs), Cosmetics, and Redeem a code.
	  StoreScreen.Store(container, state, call, extra)    extra.StoreTab = "Premium" | "Cosmetics" | "Codes"
	Each tab is the existing screen, drawn into the area under the tab row.
]]
local Kit = require(script.Parent.Kit)
local PremiumScreen = require(script.Parent.PremiumScreen)
local CosmeticsScreen = require(script.Parent.CosmeticsScreen)
local CodesScreen = require(script.Parent.CodesScreen)
local Market = require(script.Parent.MarketScreen)
local C = Kit.Colors

local TABS = {
	{ Id = "Market", Text = "🪙 Market" },
	{ Id = "Premium", Text = "🔶 Premium shop" },
	{ Id = "Cosmetics", Text = "🎨 Cosmetics" },
	{ Id = "Codes", Text = "🎁 Redeem a code" },
}

local StoreScreen = {}

function StoreScreen.Store(container, state, call, extra)
	Kit.clear(container)
	local tab = extra.StoreTab or "Premium"
	local function redraw()
		StoreScreen.Store(container, extra.State or state, call, extra)
	end
	for index, def in ipairs(TABS) do
		Kit.button({
			Name = "Tab_" .. def.Id, Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset((index - 1) * 156, 0), Text = def.Text, TextSize = 13,
			BackgroundColor3 = if def.Id == tab then C.Accent else C.Panel, TextColor3 = if def.Id == tab then Color3.fromRGB(30, 24, 10) else C.Text, Parent = container,
		}, function()
			extra.StoreTab = def.Id
			if def.Id == "Codes" then
				extra.CodeResult = nil
			end
			redraw()
		end)
	end
	local area = Kit.frame({ Name = "StoreArea", Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	if tab == "Market" then
		Market.Market(area, state, call, extra)
	elseif tab == "Cosmetics" then
		CosmeticsScreen.Cosmetics(area, state, call, extra)
	elseif tab == "Codes" then
		CodesScreen.Codes(area, state, call, extra)
	else
		PremiumScreen.Premium(area, state, call, extra)
	end
end

return StoreScreen
