--[[
	MapScreen (ModuleScript): the world map, drawn like a parchment adventure map.

	  MapScreen.Map(container, state, call, extra)
	    extra.World     latest World snapshot (every party on this server); markers come from it
	    extra.MapZone   the zone picked on the map (defaults to the one your party is in)
	    extra.MapPage   which page of ten zones is showing

	A winding dotted road links one round node per zone (coloured like the zone's ground, with
	its scenery glyph). Zones you have not reached are fogged and locked. Every player on the
	server shows as a portrait pin on the zone their party is fighting in; yours has a gold ring.
	Picking a zone fills the strip below with its ten stages (boss last); tap one to fight it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Zones)
local Stages = require(Shared.Stages)
local Classes = require(Shared.Config.Classes)
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local MapScreen = {}

local GLYPHS = {
	Trees = "🌳", Pines = "🌲", Rocks = "⛰️", Crystals = "💎", Cacti = "🌵",
	SnowPines = "❄️", LavaRocks = "🌋", DeadTrees = "🪦", Pillars = "🏛️", Clouds = "☁️",
}
local PAPER = Color3.fromRGB(226, 205, 160)
local PAPER_DARK = Color3.fromRGB(190, 164, 118)
local INK = Color3.fromRGB(94, 66, 40)
local CLASS_COLORS = { Warrior = Color3.fromRGB(214, 106, 80), Cleric = Color3.fromRGB(240, 220, 130), Mage = Color3.fromRGB(130, 130, 240), Ranger = Color3.fromRGB(110, 190, 100), Rogue = Color3.fromRGB(150, 110, 200), Summoner = Color3.fromRGB(100, 215, 195) }

local ZONES_PER_PAGE = 10
local MAP_HEIGHT = 170
MapScreen.Width = 624 -- the panel body width Main gives this screen
local MAP_WIDTH = MapScreen.Width

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function circle(parent, props)
	local f = Kit.new("Frame", props)
	f.BackgroundTransparency = props.BackgroundTransparency or 0
	Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	f.Parent = parent
	return f
end

-- Node centres along a winding road across a map of width w.
local function nodePosition(index, w)
	local margin = 44
	local x = margin + (index - 1) * ((w - margin * 2) / (ZONES_PER_PAGE - 1))
	local y = MAP_HEIGHT / 2 + math.sin((index - 1) * 1.15 + 0.4) * 44
	return Vector2.new(x, y)
end

local function pin(parent, member, own, size)
	local ring = circle(parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = if own then C.Accent else Color3.fromRGB(250, 250, 250), ZIndex = 4 })
	local face = circle(ring, { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = CLASS_COLORS[member.ClassId] or C.PanelLight, ZIndex = 5 })
	-- initial shows first; the Roblox headshot covers it once it loads
	Kit.label({ Size = UDim2.fromScale(1, 1), Text = string.upper(string.sub(member.Name or "?", 1, 1)), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.fromRGB(40, 30, 20), TextStrokeTransparency = 1, ZIndex = 6, Parent = face })
	if member.UserId and member.UserId > 0 then
		local image = Kit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(member.UserId), ZIndex = 7, Parent = face })
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = image })
	end
	return ring
end

function MapScreen.Map(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local party = state.Party
	if not party then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Join or create a party to travel the map.", TextColor3 = C.Dim, Parent = container })
		return
	end

	local currentZone = Zones.IndexForStage(party.Stage)
	local maxZone = Zones.IndexForStage(party.Frontier)
	local picked = math.clamp(extra.MapZone or currentZone, 1, maxZone)
	local page = extra.MapPage or ((picked - 1) // ZONES_PER_PAGE)
	local firstZone = page * ZONES_PER_PAGE + 1
	local me = state.Player.UserId

	-- parchment ---------------------------------------------------------------
	local width = MAP_WIDTH
	local map = Kit.frame({ Size = UDim2.new(1, 0, 0, MAP_HEIGHT), BackgroundColor3 = PAPER, Parent = container })
	Kit.new("UIStroke", { Color = INK, Thickness = 2, Parent = map })
	-- soft vignette corners so it reads as old paper
	for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local v = circle(map, { Size = UDim2.fromOffset(120, 120), AnchorPoint = Vector2.new(corner[1], corner[2]), Position = UDim2.fromScale(corner[1], corner[2]), BackgroundColor3 = PAPER_DARK, BackgroundTransparency = 0.7, ZIndex = 1 })
		v.Active = false
	end
	Kit.label({ Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(10, 4), Text = "The Realm", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = INK, TextStrokeTransparency = 1, ZIndex = 2, Parent = map })

	-- the road
	for index = 1, ZONES_PER_PAGE - 1 do
		local a, b = nodePosition(index, width), nodePosition(index + 1, width)
		local reached = (firstZone + index) <= maxZone
		local steps = math.floor((b - a).Magnitude / 11)
		for step = 1, steps - 1 do
			local p = a:Lerp(b, step / steps)
			circle(map, { Size = UDim2.fromOffset(5, 5), Position = UDim2.fromOffset(p.X - 2, p.Y - 2), BackgroundColor3 = if reached then INK else PAPER_DARK, ZIndex = 2 })
		end
	end

	-- the zone nodes, with the players standing on them
	local byZone = {}
	local world = extra.World
	for _, other in ipairs(world and world.Parties or {}) do
		local zone = Zones.IndexForStage(other.Stage or 1)
		byZone[zone] = byZone[zone] or {}
		for _, member in ipairs(other.Members or {}) do
			if member.Online ~= false then
				table.insert(byZone[zone], { Member = member, Party = other })
			end
		end
	end
	if not world then
		byZone[currentZone] = byZone[currentZone] or {}
		table.insert(byZone[currentZone], { Member = { UserId = me, Name = state.Player.Name, ClassId = state.Player.ClassId, Level = state.Player.Level }, Party = { Stage = party.Stage } })
	end

	for slot = 1, ZONES_PER_PAGE do
		local zoneIndex = firstZone + slot - 1
		local centre = nodePosition(slot, width)
		local info = Zones.ForStage((zoneIndex - 1) * 10 + 1)
		local reached = zoneIndex <= maxZone
		local ground = rgb(info.Theme.Ground)
		local size = if zoneIndex == picked then 50 else 42
		local node = Kit.button({
			Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(centre.X - size / 2, centre.Y - size / 2), AnchorPoint = Vector2.new(0, 0),
			Text = if reached then GLYPHS[info.Theme.Scenery] or "●" else "🔒", TextSize = if reached then 22 else 18,
			BackgroundColor3 = if reached then ground else Color3.fromRGB(120, 112, 100), TextColor3 = C.Text, ZIndex = 3, Parent = map,
		}, function()
			if reached then
				extra.MapZone = zoneIndex
				MapScreen.Map(container, state, call, extra)
			end
		end)
		local corner = node:FindFirstChildOfClass("UICorner") or Kit.new("UICorner", { Parent = node })
		corner.CornerRadius = UDim.new(0.5, 0)
		Kit.new("UIStroke", { Color = if zoneIndex == picked then C.Accent elseif zoneIndex == currentZone then Color3.fromRGB(255, 255, 255) else INK, Thickness = if zoneIndex == picked then 3 else 2, Parent = node })
		node.Active = reached
		Kit.Hover(node, function()
			if not reached then
				return ("<b>%s</b>\nFog covers this land. Beat stage %d to reach it."):format(info.Name, info.FirstStage - 1)
			end
			return ("<b>%s</b>\nStages %d-%d%s"):format(info.Name, info.FirstStage, info.LastStage, zoneIndex == currentZone and "\nYour party is here" or "")
		end)
		if zoneIndex <= maxZone + 1 then
			Kit.label({ Size = UDim2.fromOffset(96, 14), Position = UDim2.fromOffset(centre.X - 48, centre.Y + size / 2 + 1), Text = if reached then info.Name else "???", TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = INK, TextStrokeTransparency = 1, TextWrapped = false, ZIndex = 3, Parent = map })
		end

		-- player pins above the node, mine first
		local here = byZone[zoneIndex]
		if here then
			table.sort(here, function(a, b)
				local am, bm = a.Member.UserId == me, b.Member.UserId == me
				if am ~= bm then
					return am
				end
				return (a.Member.Name or "") < (b.Member.Name or "")
			end)
			local count = math.min(#here, 4)
			for k = 1, count do
				local entry = here[k]
				local own = entry.Member.UserId == me
				local x = centre.X - (count * 22) / 2 + (k - 1) * 22 + 1
				local marker = pin(map, entry.Member, own, 22)
				marker.Position = UDim2.fromOffset(x, centre.Y - size / 2 - 26)
				Kit.Hover(marker, function()
					local classDef = Classes[entry.Member.ClassId]
					return ("<b>%s</b>%s\n%s Lv %s\nFighting stage %d"):format(entry.Member.Name or "?", own and "  (you)" or "", classDef and classDef.DisplayName or tostring(entry.Member.ClassId), tostring(entry.Member.Level or "?"), entry.Party.Stage or 1)
				end)
			end
			if #here > count then
				Kit.label({ Size = UDim2.fromOffset(24, 14), Position = UDim2.fromOffset(centre.X + count * 11 + 2, centre.Y - size / 2 - 22), Text = "+" .. (#here - count), TextSize = 10, TextColor3 = INK, TextStrokeTransparency = 1, ZIndex = 4, Parent = map })
			end
		end
	end

	-- page arrows
	if maxZone > ZONES_PER_PAGE or page > 0 then
		local pages = (maxZone - 1) // ZONES_PER_PAGE
		if page > 0 then
			Kit.button({ Size = UDim2.fromOffset(30, 26), Position = UDim2.fromOffset(4, MAP_HEIGHT - 30), Text = "<", ZIndex = 4, Parent = map }, function()
				extra.MapPage = page - 1
				extra.MapZone = (page - 1) * ZONES_PER_PAGE + 1
				MapScreen.Map(container, state, call, extra)
			end)
		end
		if page < pages then
			Kit.button({ Size = UDim2.fromOffset(30, 26), Position = UDim2.new(1, -34, 1, -30), Text = ">", ZIndex = 4, Parent = map }, function()
				extra.MapPage = page + 1
				extra.MapZone = (page + 1) * ZONES_PER_PAGE + 1
				MapScreen.Map(container, state, call, extra)
			end)
		end
	end

	-- stage strip for the picked zone -------------------------------------------
	local zone = Zones.ForStage((picked - 1) * 10 + 1)
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(2, MAP_HEIGHT + 4), Text = ("%s  -  stages %d-%d.  You are on stage %d (furthest %d). Tap a cleared stage to farm it."):format(zone.Name, zone.FirstStage, zone.LastStage, party.Stage, party.Frontier), TextSize = 12, TextColor3 = C.Dim, Parent = container })
	local strip = Kit.frame({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, MAP_HEIGHT + 26), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.1, -4, 0, 38), CellPadding = UDim2.fromOffset(4, 0), Parent = strip })
	for i = 0, 9 do
		local stage = zone.FirstStage + i
		local unlocked = stage <= party.Frontier
		local isCurrent = stage == party.Stage
		local boss = Stages.IsBoss(stage)
		local b = Kit.button({
			Text = tostring(stage) .. (boss and "\nBOSS" or ""), TextSize = 13,
			BackgroundColor3 = if isCurrent then C.Accent elseif unlocked then C.PanelLight else C.Panel,
			TextColor3 = if isCurrent then Color3.fromRGB(30, 24, 10) elseif unlocked then C.Text else C.Dim, Parent = strip,
		}, function()
			if unlocked then
				call("SetStage", stage)
			end
		end)
		b.Active = unlocked
	end
end

return MapScreen
