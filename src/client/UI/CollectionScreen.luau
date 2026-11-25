--[[
	CollectionScreen (ModuleScript): the permanent collections, kept every season.
	  Bestiary (state.Player.Bestiary = Shared/Bestiary.Status): zones on the left, the picked zone's monsters on the right
	           with kills, tier and the kills to the next tier. Party kills count for everyone.
	  Mastery  (state.Player.Mastery = Shared/ClassMastery.Status): one card per class: level, XP bar, perk, title.

	  CollectionScreen.Collection(container, state, call, extra)    extra.CollectionTab, extra.BestiaryZone
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short

local CollectionScreen = {}

local TIER_COLORS = {
	[0] = Color3.fromRGB(70, 74, 96), Color3.fromRGB(120, 170, 120), Color3.fromRGB(90, 150, 230), Color3.fromRGB(190, 120, 240), Color3.fromRGB(255, 196, 70),
}

local function stars(tier)
	return string.rep("★", tier) .. string.rep("☆", 4 - tier)
end

local function pct(v)
	return ("%g%%"):format(math.floor(v * 1000 + 0.5) / 10)
end

local function bar(parent, frac, color, props)
	local back = Kit.frame({ Size = props.Size, Position = props.Position, BackgroundColor3 = Color3.fromRGB(28, 30, 44), Parent = parent })
	Kit.frame({ Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = color, Parent = back })
	return back
end

local function bestiary(area, state, extra, redraw)
	local info = state.Player.Bestiary
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", TextColor3 = C.Dim, Parent = area })
		return
	end
	local bonus = info.Bonus or {}
	Kit.label({
		Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 0),
		Text = ("Hunt every monster of a zone (★★) for its title and +0.5%% attack and health. Now: +%s attack, +%s health (max %s). Party kills count for everyone; kills are kept every season."):format(pct(bonus.Attack or 0), pct(bonus.MaxHealth or 0), pct(info.Cap or 0.1)),
		TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Parent = area,
	})
	-- zones
	local list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(0, 210, 1, -28), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = area,
	})
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = list })
	local pick = extra.BestiaryZone or 1
	for _, zone in ipairs(info.Zones) do
		local on = zone.Index == pick
		local row = Kit.button({
			Size = UDim2.new(1, -8, 0, 30), Text = "", BackgroundColor3 = if on then Color3.fromRGB(56, 62, 98) else C.Panel, LayoutOrder = zone.Index, Parent = list,
		}, function()
			extra.BestiaryZone = zone.Index
			redraw()
		end)
		Kit.label({ Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%d. %s"):format(zone.Index, zone.Name), TextSize = 12, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = row })
		Kit.label({ Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -64, 0, 0), Text = stars(zone.Tier), TextSize = 12, TextColor3 = TIER_COLORS[zone.Tier], TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = row })
	end
	-- the picked zone
	local zone = info.Zones[pick] or info.Zones[1]
	local detail = Kit.frame({ Size = UDim2.new(1, -218, 1, -28), Position = UDim2.fromOffset(218, 26), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = zone.Name, TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, Parent = detail })
	local titleText = if zone.Tier >= 4 then ("Titles: %s, %s"):format(zone.Hunter, zone.Master) elseif zone.Tier >= 2 then ("Title earned: %s. Every monster at ★★★★: %s"):format(zone.Hunter, zone.Master) else ("Every monster at ★★: the title %s"):format(zone.Hunter)
	Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 22), Text = titleText, TextSize = 11, TextColor3 = C.Dim, TextWrapped = false, Parent = detail })
	local grid = Kit.frame({ Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, NoCorner = true, Parent = detail })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0.5, -4), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for index, mon in ipairs(zone.Monsters) do
		local seen = mon.Tier > 0
		local card = Kit.frame({ BackgroundColor3 = if seen then Color3.fromRGB(40, 44, 70) else Color3.fromRGB(28, 30, 44), LayoutOrder = index, Parent = grid })
		Kit.new("UIStroke", { Color = TIER_COLORS[mon.Tier], Thickness = if mon.Tier >= 4 then 2 else 1, Parent = card })
		local name = if seen then mon.Name else "???"
		if mon.Boss then
			name = "👑 " .. name
		end
		if mon.Id == info.Hunt then
			name ..= "  🎯 weekly hunt (x2)"
		end
		Kit.label({ Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 6), Text = name, TextSize = 13, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = card })
		Kit.label({ Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(8, 28), Text = stars(mon.Tier) .. "  " .. (if mon.Tier > 0 then info.TierNames[mon.Tier] else "Not seen yet"), TextSize = 12, TextColor3 = TIER_COLORS[mon.Tier], TextWrapped = false, Parent = card })
		local nextText = if mon.NextAt then ("%s / %s kills"):format(Short(mon.Kills), Short(mon.NextAt)) else ("%s kills - complete"):format(Short(mon.Kills))
		Kit.label({ Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 8, 1, -34), Text = nextText, TextSize = 11, TextColor3 = C.Dim, TextWrapped = false, Parent = card })
		bar(card, if mon.NextAt then mon.Kills / mon.NextAt else 1, TIER_COLORS[math.max(1, mon.Tier)], { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.new(0, 8, 1, -14) })
	end
end

local CLASS_GLYPH = { Warrior = "🛡", Cleric = "✝", Mage = "🔮", Ranger = "🏹", Rogue = "🗡", Summoner = "💀" }

local function mastery(area, state)
	local info = state.Player.Mastery
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", TextColor3 = C.Dim, Parent = area })
		return
	end
	Kit.label({
		Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 0),
		Text = ("Each class has its own mastery, kept every season. XP: new stage +%d, first boss kill of the season +%d, a dungeon's first full clear of the day +%d. Every %d levels: +%s attack, health and defense for that class (max level %d)."):format(info.XP.Frontier, info.XP.Boss, info.XP.Dungeon, info.PerkEvery, pct(info.PerkValue), info.MaxLevel),
		TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Parent = area,
	})
	local grid = Kit.frame({ Size = UDim2.new(1, -4, 1, -38), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0.5, -6), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for index, row in ipairs(info.Classes) do
		local color = Kit.Colors[row.ClassId] or C.Accent
		local card = Kit.frame({ BackgroundColor3 = if row.Current then Color3.fromRGB(46, 52, 84) else C.Panel, LayoutOrder = index, Parent = grid })
		Kit.new("UIStroke", { Color = color, Thickness = if row.Current then 2 else 1, Parent = card })
		Kit.label({ Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(8, 6), Text = (CLASS_GLYPH[row.ClassId] or "") .. " " .. row.Name .. (if row.Current then "  (playing)" else ""), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = color, TextWrapped = false, Parent = card })
		Kit.label({ Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 30), Text = ("Mastery %d / %d"):format(row.Level, info.MaxLevel), TextSize = 14, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = card })
		local frac = if row.Need then row.XP / row.Need else 1
		bar(card, frac, color, { Size = UDim2.new(1, -16, 0, 8), Position = UDim2.fromOffset(8, 54) })
		Kit.label({ Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(8, 64), Text = if row.Need then ("%d / %d XP"):format(row.XP, row.Need) else "Mastered", TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, Parent = card })
		Kit.label({ Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(8, 82), Text = if row.Perk > 0 then ("+%s attack, health, defense"):format(pct(row.Perk)) else "No perk yet (level 10)", TextSize = 11, TextColor3 = if row.Perk > 0 then C.Good else C.Dim, TextWrapped = false, Parent = card })
		Kit.label({ Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(8, 100), Text = if row.Title then ("Title: %s"):format(row.Title) else "Title at level 10", TextSize = 11, TextColor3 = if row.Title then C.Accent else C.Dim, TextWrapped = false, Parent = card })
	end
end

function CollectionScreen.Collection(container, state, call, extra)
	extra = extra or {}
	local function redraw()
		CollectionScreen.Collection(container, state, call, extra)
	end
	Kit.clear(container)
	local tab = extra.CollectionTab or "Bestiary"
	for index, name in ipairs({ "Bestiary", "Mastery" }) do
		local on = name == tab
		Kit.button({
			Size = UDim2.fromOffset(110, 26), Position = UDim2.fromOffset((index - 1) * 116, 0), Text = (if name == "Bestiary" then "🐾 " else "🏅 ") .. name, TextSize = 13,
			BackgroundColor3 = if on then C.Accent else C.Panel, TextColor3 = if on then Color3.fromRGB(30, 24, 10) else C.Text, Parent = container,
		}, function()
			extra.CollectionTab = name
			redraw()
		end)
	end
	Kit.label({ Size = UDim2.new(1, -250, 0, 26), Position = UDim2.fromOffset(240, 0), Text = "Kept every season", TextSize = 11, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = container })
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -32), Position = UDim2.fromOffset(0, 32), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	if tab == "Mastery" then
		mastery(area, state)
	else
		bestiary(area, state, extra, redraw)
	end
end

return CollectionScreen
