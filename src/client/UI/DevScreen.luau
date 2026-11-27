--[[
	DevScreen (ModuleScript): Studio-only cheat panel (HUD 🧪 "Test"). Every test shortcut lives here.
	  DevScreen.Dev(container, state, call, extra)
	Each button calls the server handler Dev(action, n) (ApiService DEV_ACTIONS), which refuses outside Studio.
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local DevScreen = {}

local GOOD = Color3.fromRGB(130, 235, 150)
local ROWS = {
	{ Title = "Hero", Buttons = { { "+1 level", "Level", 1 }, { "+5 levels", "Level", 5 }, { "+10 levels", "Level", 10 } } },
	{ Title = "Stage (cleared like real wins)", Buttons = { { "+5 stages", "Stage", 5 }, { "+10 stages", "Stage", 10 }, { "+25 stages", "Stage", 25 } } },
	{ Title = "Currency", Buttons = { { "+50M gold", "Gold", 1 }, { "+500M gold", "Gold", 10 }, { "+1K Sunstones", "Sunstones", 1 }, { "Sunstones = 0", "ClearSunstones", 1 } } },
	{ Title = "Wishes (Wishstones + wish tickets)", Buttons = { { "+500 stones, 25 tickets", "Wishes", 1 }, { "+5K stones, 250 tickets", "Wishes", 10 } } },
	{ Title = "Items and pets", Buttons = { { "Test items", "Items", 1 }, { "Gear for my stage", "StageGear", 1 }, { "All pets, max level", "Pets", 1 } } },
	{ Title = "Timers and events", Buttons = { { "Reset dailies", "Daily", 1 }, { "Spawn world boss", "WorldBoss", 1 } } },
	{ Title = "Season (test, not saved)", Buttons = { { "Start next season", "NewSeason", 1 } } },
	{ Title = "Stress test (this screen only)", Local = true, Buttons = { { "Fill 8 lots", "Stress", 8 }, { "Fill 16 lots", "Stress", 16 }, { "Stop", "Stress", 0 } } },
	{ Title = "Passes (toggle)", Buttons = { { "Premium quest pass", "Premium", 1 }, { "+2 char slots", "SlotPass", 1 }, { "VIP pass", "VipPass", 1 } } },
}

function DevScreen.Dev(container, state, call, extra)
	Kit.clear(container)
	local p = state.Player or {}
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })
	local info = ("Studio only.  Level %s  ·  Frontier %s"):format(tostring(p.Level or "?"), tostring(p.Frontier or "?"))
	local stress = extra.StressLine and extra.StressLine()
	if stress then
		info = stress
	end
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = extra.DevMsg or info, TextSize = 12, TextColor3 = if extra.DevMsg then GOOD else C.Dim, Parent = scroll })
	for _, row in ipairs(ROWS) do
		local frame = Kit.frame({ Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.label({ Size = UDim2.fromOffset(150, 46), Position = UDim2.fromOffset(10, 0), Text = row.Title, TextSize = 12, Font = Enum.Font.GothamBold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		for i, b in ipairs(row.Buttons) do
			Kit.button({ Size = UDim2.fromOffset(140, 34), Position = UDim2.fromOffset(166 + (i - 1) * 146, 6), Text = b[1], TextSize = 12, BackgroundColor3 = C.Panel, Parent = frame }, function()
				extra.DevMsg = "Working..."
				local ok, data
				if row.Local then
					if extra.Stress then
						ok, data = extra.Stress(b[3])
					else
						ok, data = false, "not wired"
					end
				else
					ok, data = call("Dev", b[2], b[3])
				end
				extra.DevMsg = if ok then "Done: " .. tostring(data) else ("Could not: " .. tostring(data))
				DevScreen.Dev(container, extra.State or state, call, extra)
			end)
		end
	end
end

return DevScreen
