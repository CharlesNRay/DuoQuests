--[[
	CosmeticsScreen (ModuleScript): wardrobe and cosmetics shop.
	  CosmeticsScreen.Cosmetics(container, state, call, extra)    extra.CosmeticSlot = "Aura" | "Kill" | "Name" | "Title"

	state.Player.Cosmetics = { Equipped, Lists = { [slot] = rows }, Slots, Labels } (server: Shared/Cosmetics).
	Shop items cost Sunstones; season prizes show locked until won. Looks only, never power.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local C = Kit.Colors
local Classes = require(ReplicatedStorage:WaitForChild("Shared").Config.Classes)

local ORANGE = Color3.fromRGB(255, 165, 70)
local ORANGE_DARK = Color3.fromRGB(70, 44, 18)
local GOOD = Color3.fromRGB(130, 235, 150)

local CosmeticsScreen = {}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 80)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 230, 120)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 120, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
})

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function swatch(parent, row)
	local box = Kit.frame({ Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(row.Color and row.Color[1] or 90, row.Color and row.Color[2] or 90, row.Color and row.Color[3] or 110), Parent = parent })
	if row.Rainbow then
		Kit.new("UIGradient", { Color = RAINBOW, Parent = box })
	elseif row.Color2 then
		Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(row.Color[1], row.Color[2], row.Color[3]), Color3.fromRGB(row.Color2[1], row.Color2[2], row.Color2[3])), Rotation = 45, Parent = box })
	end
end

function CosmeticsScreen.Cosmetics(container, state, call, extra)
	Kit.clear(container)
	local data = state.Player.Cosmetics
	if not data then
		return
	end
	local slot = extra.CosmeticSlot or data.Slots[1]
	local function redraw()
		CosmeticsScreen.Cosmetics(container, extra.State or state, call, extra)
	end
	for index, name in ipairs(data.Slots) do
		Kit.button({ Size = UDim2.fromOffset(112, 28), Position = UDim2.fromOffset((index - 1) * 118, 0), Text = data.Labels[name], TextSize = 12, BackgroundColor3 = if name == slot then ORANGE else C.Panel, TextColor3 = if name == slot then Color3.fromRGB(40, 24, 6) else C.Text, Parent = container }, function()
			extra.CosmeticSlot = name
			extra.CosmeticMsg = nil
			redraw()
		end)
	end
	Kit.label({ Size = UDim2.fromOffset(160, 28), Position = UDim2.new(1, -164, 0, 0), Text = ("🔶 %s"):format(commas(state.Player.Sunstones or 0)), TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ORANGE, Parent = container })
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = area })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = extra.CosmeticMsg or "Looks only - they never change your power. Buy with Sunstones or win them as season prizes.", TextSize = 12, TextColor3 = if extra.CosmeticMsg then GOOD else C.Dim, Parent = scroll })

	for _, row in ipairs(data.Lists[slot] or {}) do
		local classDef = row.Class and Classes[row.Class]
		if not (classDef and classDef.Locked) then -- a class that is not playable yet shows its prizes when it launches
			local frame = Kit.frame({ Size = UDim2.new(1, -8, 0, 50), BackgroundColor3 = C.PanelLight, Parent = scroll })
			if slot ~= "Title" then
				swatch(frame, row)
			end
			local left = if slot == "Title" then 10 else 52
			Kit.label({ Size = UDim2.new(1, -left - 150, 0, 22), Position = UDim2.fromOffset(left, 5), Text = row.Name, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = if row.Owned then C.Text else C.Dim, Parent = frame })
			local sub = if row.Equipped then "Equipped" elseif row.Owned then "Owned" elseif row.Source == "Season" then "Season prize - win it at the end of a season" else "For sale"
			Kit.label({ Size = UDim2.new(1, -left - 150, 0, 16), Position = UDim2.fromOffset(left, 28), Text = sub, TextSize = 11, TextColor3 = if row.Equipped then GOOD else C.Dim, Parent = frame })
			local text, enabled, color
			if row.Equipped then
				text, enabled, color = "Take off", true, C.Panel
			elseif row.Owned then
				text, enabled, color = "Equip", true, GOOD
			elseif row.Source == "Season" then
				text, enabled, color = "Locked", false, ORANGE_DARK
			else
				text, enabled, color = "🔶 " .. commas(row.Cost), row.Affordable, if row.Affordable then ORANGE else ORANGE_DARK
			end
			local btn = Kit.button({ Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -140, 0.5, -17), Text = text, BackgroundColor3 = color, TextColor3 = if enabled and color ~= C.Panel then Color3.fromRGB(30, 24, 8) else C.Text, Parent = frame }, function()
				if row.Equipped then
					call("EquipCosmetic", slot, nil)
				elseif row.Owned then
					extra.CosmeticMsg = nil
					call("EquipCosmetic", slot, row.Id)
				elseif row.Source == "Shop" then
					if call("BuyCosmetic", row.Id) then
						extra.CosmeticMsg = "Bought: " .. row.Name .. "! Equip it to wear it."
					else
						extra.CosmeticMsg = nil
					end
				end
				redraw()
			end)
			btn.Active = enabled
		end
	end
end

return CosmeticsScreen
