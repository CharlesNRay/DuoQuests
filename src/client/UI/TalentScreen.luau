--[[
	TalentScreen (ModuleScript): spend level-up points (state.Player.Talents = Shared/Talents.Status).
	Every level gives a point; each talent has 10 ranks. Auto spends by your class's role; Reset is free.
	The bottom row is Mastery (purple): four talents that open at level 81 (info.MasteryLevel).

	  TalentScreen.Talents(container, state, call, extra)
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local TalentScreen = {}

function TalentScreen.Talents(container, state, call)
	Kit.clear(container)
	local info = state.Player.Talents
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", TextColor3 = C.Dim, Parent = container })
		return
	end
	local head = Kit.frame({ Size = UDim2.new(1, -8, 0, 50), BackgroundColor3 = C.PanelLight, Parent = container })
	Kit.label({
		Size = UDim2.new(1, -260, 0, 24), Position = UDim2.fromOffset(10, 4),
		Text = if info.Free > 0 then ("✨ %d talent point%s to spend!"):format(info.Free, if info.Free == 1 then "" else "s") else "All talent points spent",
		TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = if info.Free > 0 then C.Accent else C.Text, Parent = head,
	})
	Kit.label({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(10, 28), Text = ("You get 1 point every level (%d earned). Reset is free."):format(info.Total), TextSize = 12, TextColor3 = C.Dim, Parent = head })
	Kit.button({ Size = UDim2.fromOffset(110, 36), Position = UDim2.new(1, -236, 0.5, -18), Text = "Auto-spend", BackgroundColor3 = if info.Free > 0 then C.Accent else C.Panel, TextColor3 = if info.Free > 0 then Color3.fromRGB(30, 24, 10) else C.Text, Parent = head }, function()
		call("AutoTalents")
	end)
	Kit.button({ Size = UDim2.fromOffset(110, 36), Position = UDim2.new(1, -118, 0.5, -18), Text = "Reset", BackgroundColor3 = C.Panel, Parent = head }, function()
		call("ResetTalents")
	end)

	local grid = Kit.frame({ Size = UDim2.new(1, -8, 1, -58), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local rows = math.ceil(#info.List / 4)
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 1 / rows, -6), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local MASTERY = Color3.fromRGB(176, 120, 255)
	for index, t in ipairs(info.List) do
		local maxed = t.Rank >= t.MaxRank
		local card = Kit.frame({ BackgroundColor3 = if t.Locked then Color3.fromRGB(30, 28, 44) elseif t.Rank > 0 then Color3.fromRGB(46, 52, 84) elseif t.Mastery then Color3.fromRGB(40, 34, 64) else C.Panel, LayoutOrder = index, Parent = grid })
		Kit.new("UIStroke", { Color = if maxed then C.Good elseif t.Mastery then MASTERY elseif t.Rank > 0 then C.Accent else Color3.fromRGB(70, 76, 104), Thickness = if t.Rank > 0 or t.Mastery then 2 else 1, Transparency = if t.Locked then 0.5 else 0, Parent = card })
		Kit.Hover(card, function()
			return ("<b>%s%s</b>\n%s each rank, up to %d ranks.%s"):format(t.Name, if t.Mastery then " (Mastery)" else "", t.Next or t.Now, t.MaxRank, if t.Locked then ("\nOpens at level %d."):format(t.Unlock or 81) else "")
		end)
		Kit.label({ Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 2), Text = t.Glyph .. " " .. t.Name, TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		-- rank pips
		local pips = Kit.frame({ Size = UDim2.new(1, -16, 0, 8), Position = UDim2.fromOffset(8, 24), BackgroundTransparency = 1, NoCorner = true, Parent = card })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), Parent = pips })
		for r = 1, t.MaxRank do
			Kit.frame({ Size = UDim2.new(1 / t.MaxRank, -2, 1, 0), BackgroundColor3 = if r <= t.Rank then C.Accent else Color3.fromRGB(90, 96, 128), Parent = pips })
		end
		Kit.label({ Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 34), Text = ("%d/%d   %s"):format(t.Rank, t.MaxRank, if t.Rank > 0 then t.Now else ((t.Next or "") .. " each")), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = if t.Rank > 0 then C.Good else C.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, Parent = card })
		if t.Locked then
			Kit.label({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), Text = ("🔒 Mastery: level %d"):format(t.Unlock or 81), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = MASTERY, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		elseif not maxed then
			Kit.button({ Size = UDim2.new(0.5, -8, 0, 24), Position = UDim2.new(0, 6, 1, -28), Text = "+1", BackgroundColor3 = if info.Free > 0 then C.Accent else C.Panel, TextColor3 = if info.Free > 0 then Color3.fromRGB(30, 24, 10) else C.Dim, Parent = card }, function()
				call("SpendTalent", t.Id, 1)
			end)
			Kit.button({ Size = UDim2.new(0.5, -8, 0, 24), Position = UDim2.new(0.5, 2, 1, -28), Text = "+5", BackgroundColor3 = if info.Free > 1 then C.PanelLight else C.Panel, TextColor3 = if info.Free > 1 then C.Text else C.Dim, Parent = card }, function()
				call("SpendTalent", t.Id, 5)
			end)
		else
			Kit.label({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), Text = "MAX", TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		end
	end
end

return TalentScreen
