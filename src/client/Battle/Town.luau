--[[
	Town (ModuleScript): the town districts around the plaza (docs/TOWN.md, phase 1: layout and scenery only).

	  Town.Build(folder, pulsers)   builds the ring road, the spokes from the plaza, signposts and the three districts
	                                (pulsers: Hub's list of glowing parts that breathe, for the few glowing props)

	Districts (positions in shared/World.luau, World.Districts):
	  Wishing Grove (west)       the Wishing Tree (built by Hub at PlazaSpots.Tree), a fishing pond, a pet park
	  Town Gate (south)          the town gate and walls, a notice board, the tavern, a well and houses
	  Training Grounds (east)    training dummies, a sparring ring, the guild hall
	The activities themselves (fishing, bounties, dummy, ...) come in later phases: their spots carry a
	"coming soon" tag for now. Everything is client-side Parts, like the plaza. Each district is built in a frame
	whose -Z points at the plaza centre.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))

local Town = {}

local WOOD = Color3.fromRGB(110, 76, 48)
local DARK_WOOD = Color3.fromRGB(80, 56, 38)
local STONE = Color3.fromRGB(168, 160, 146)
local STONE_DARK = Color3.fromRGB(120, 114, 104)
local ROAD = Color3.fromRGB(150, 138, 116)

local folder, pulsers

local function part(props, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or folder
	return p
end

local function disc(centre, radius, height, y, color, material)
	return part({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(centre.X, y + height / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Material = material or Enum.Material.Cobblestone,
	})
end

local function sign(on, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = on
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color or Color3.fromRGB(255, 236, 190)
	label.Parent = gui
end

-- a floating label over a spot (a "coming soon" tag for the activities of later phases)
local function tag(on, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 46)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 110
	gui.Adornee = on
	gui.Parent = on
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 26)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextColor3 = color or Color3.fromRGB(255, 226, 150)
	t.TextStrokeTransparency = 0.3
	t.Font = Enum.Font.GothamBlack
	t.TextSize = 20
	t.Parent = gui
	if subtitle then
		local s = Instance.new("TextLabel")
		s.Size = UDim2.new(1, 0, 0, 18)
		s.Position = UDim2.fromOffset(0, 26)
		s.BackgroundTransparency = 1
		s.Text = subtitle
		s.TextColor3 = Color3.new(1, 1, 1)
		s.TextStrokeTransparency = 0.4
		s.Font = Enum.Font.GothamMedium
		s.TextSize = 13
		s.Parent = gui
	end
end

local function tree(position, scale)
	scale = scale or 1
	part({ Name = "Trunk", Size = Vector3.new(1.6, 6, 1.6) * scale, Position = position + Vector3.new(0, 3 * scale, 0), Color = WOOD, Material = Enum.Material.Wood })
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 8, 9) * scale, Position = position + Vector3.new(0, 8.5 * scale, 0), Color = Color3.fromRGB(70, 140, 70), Material = Enum.Material.Grass, CanCollide = false })
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6) * scale, Position = position + Vector3.new(2 * scale, 11 * scale, 1 * scale), Color = Color3.fromRGB(86, 160, 80), Material = Enum.Material.Grass, CanCollide = false })
end

local function lamp(position)
	part({ Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), Position = position + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(46, 46, 56), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = position + Vector3.new(0, 9.6, 0), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.1
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = bulb
end

-- a cottage: walls, a pitched roof (two wedges), a door and two windows; front (-Z) faces `cf`'s look direction
local function house(cf, w, d, h, wall, roof, name)
	part({ Name = "HouseWalls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = wall, Material = Enum.Material.Plaster })
	local rise = math.max(3, w * 0.35)
	for _, side in ipairs({ -1, 1 }) do
		-- each wedge slopes down toward its side: wedge's slope faces -Z/+Y by default, so turn it to face the sides
		part({ Name = "Roof", Size = Vector3.new(d + 1.2, rise, w / 2 + 0.6), CFrame = cf * CFrame.new(side * (w / 4 + 0.3), h + rise / 2, 0) * CFrame.Angles(0, math.rad(side * -90), 0), Color = roof, Material = Enum.Material.WoodPlanks }, "WedgePart")
	end
	part({ Name = "Door", Size = Vector3.new(2.6, 4.6, 0.3), CFrame = cf * CFrame.new(0, 2.3, -d / 2 - 0.1), Color = DARK_WOOD, Material = Enum.Material.Wood })
	for _, x in ipairs({ -w / 4 - 0.6, w / 4 + 0.6 }) do
		part({ Name = "Window", Size = Vector3.new(2, 2, 0.3), CFrame = cf * CFrame.new(x, h * 0.6, -d / 2 - 0.1), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
	end
	if name then
		local board = part({ Name = "HouseSign", Size = Vector3.new(math.min(w - 2, 12), 1.8, 0.3), CFrame = cf * CFrame.new(0, h - 1.2, -d / 2 - 0.25), Color = DARK_WOOD, Material = Enum.Material.Wood })
		sign(board, Enum.NormalId.Front, name)
	end
end

-- an entrance arch with the district's name on both sides
local function arch(cf, width, text, color)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "ArchPost", Size = Vector3.new(1.6, 12, 1.6), CFrame = cf * CFrame.new(side * width / 2, 6, 0), Color = WOOD, Material = Enum.Material.Wood })
		part({ Name = "ArchCap", Size = Vector3.new(2.2, 0.8, 2.2), CFrame = cf * CFrame.new(side * width / 2, 12.4, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	end
	local beam = part({ Name = "ArchBeam", Size = Vector3.new(width + 3, 3, 0.8), CFrame = cf * CFrame.new(0, 11, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	sign(beam, Enum.NormalId.Front, text)
	sign(beam, Enum.NormalId.Back, text)
end

-- a signpost with one arrow board per destination, each pointing at it
local function signpost(position, dests)
	part({ Name = "SignPost", Size = Vector3.new(0.7, 9, 0.7), Position = position + Vector3.new(0, 4.5, 0), Color = WOOD, Material = Enum.Material.Wood })
	for index, dest in ipairs(dests) do
		local y = 8.2 - (index - 1) * 1.6
		local at = position + Vector3.new(0, y, 0)
		local toward = Vector3.new(dest.Point.X, y, dest.Point.Z)
		if (toward - at).Magnitude > 1 then
			-- local +X points at the destination
			local cf = CFrame.lookAt(at, toward) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(3.4, 0, 0)
			local board = part({ Name = "Arrow", Size = Vector3.new(6.4, 1.3, 0.25), CFrame = cf, Color = Color3.fromRGB(200, 170, 110), Material = Enum.Material.Wood })
			sign(board, Enum.NormalId.Front, dest.Name .. " ▶", Color3.fromRGB(60, 40, 20))
			sign(board, Enum.NormalId.Back, "◀ " .. dest.Name, Color3.fromRGB(60, 40, 20))
		end
	end
end

local function fence(a, b, height, color)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b)
	part({ Name = "FenceRail", Size = Vector3.new(0.3, 0.35, length), CFrame = cf * CFrame.new(0, height * 0.8, 0), Color = color or WOOD, Material = Enum.Material.Wood })
	part({ Name = "FenceRail", Size = Vector3.new(0.3, 0.35, length), CFrame = cf * CFrame.new(0, height * 0.4, 0), Color = color or WOOD, Material = Enum.Material.Wood })
	local posts = math.max(1, math.floor(length / 4))
	for index = 0, posts do
		local p = a:Lerp(b, index / posts)
		part({ Name = "FencePost", Size = Vector3.new(0.5, height, 0.5), Position = Vector3.new(p.X, height / 2, p.Z), Color = color or WOOD, Material = Enum.Material.Wood })
	end
end

local function flowerBed(position, color)
	disc(position, 2.6, 0.5, 0.2, Color3.fromRGB(110, 80, 56), Enum.Material.Ground)
	for index = 1, 6 do
		local a = index * math.pi / 3
		part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Position = position + Vector3.new(math.cos(a) * 1.5, 1.1, math.sin(a) * 1.5), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
end

local function districtFrame(id)
	local x, z = World.DistrictPoint(id)
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z))
end

-- roads ----------------------------------------------------------------------
local function roads()
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local R = World.TOWN_RING
	-- the ring: from the Grove (west) through the Gate (south) to the Training Grounds (east); the lots are north
	local from, to, steps = 90, 270, 30
	for index = 0, steps - 1 do
		local a1 = math.rad(from + (to - from) * index / steps)
		local a2 = math.rad(from + (to - from) * (index + 1) / steps)
		local p1 = centre + Vector3.new(math.sin(a1) * R, 0, -math.cos(a1) * R)
		local p2 = centre + Vector3.new(math.sin(a2) * R, 0, -math.cos(a2) * R)
		local mid = (p1 + p2) / 2
		part({ Name = "RingRoad", Size = Vector3.new(9, 0.3, (p2 - p1).Magnitude + 1.5), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), p2 + Vector3.new(0, 0.15, 0)), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
	end
	-- spokes from the plaza rim to each district's edge
	for _, id in ipairs(World.DistrictOrder) do
		local d = World.Districts[id]
		local a = math.rad(d.Angle)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local r1, r2 = World.PLAZA.Radius - 1, d.Radius - d.Size + 2
		local p1, p2 = centre + dir * r1, centre + dir * r2
		local mid = (p1 + p2) / 2
		part({ Name = "Spoke", Size = Vector3.new(10, 0.32, (p2 - p1).Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.16, 0), p2 + Vector3.new(0, 0.16, 0)), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
	end
end

-- signposts where each spoke leaves the plaza, and halfway round the ring
local function signposts()
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local dests = {}
	for _, id in ipairs(World.DistrictOrder) do
		local x, z = World.DistrictPoint(id)
		table.insert(dests, { Name = World.Districts[id].Name, Point = Vector3.new(x, 0, z) })
	end
	local _, _, oz = World.ArenaOrigin(1)
	table.insert(dests, { Name = "Battle Lots", Point = Vector3.new(0, 0, oz) })
	table.insert(dests, { Name = "Plaza", Point = centre })
	local function nearOthers(selfName)
		local list = {}
		for _, d in ipairs(dests) do
			if d.Name ~= selfName then
				table.insert(list, d)
			end
		end
		return list
	end
	for _, angle in ipairs({ -90, 90, 180, 0 }) do
		local a = math.rad(angle)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		signpost(centre + dir * (World.PLAZA.Radius + 9) + side * 8, nearOthers("Plaza"))
	end
	for _, angle in ipairs({ 135, 225 }) do
		local a = math.rad(angle)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		signpost(centre + dir * (World.TOWN_RING + 9), dests)
	end
end

-- districts ------------------------------------------------------------------
local function gate()
	local d = World.Districts.Gate
	local cf = districtFrame("Gate")
	disc(cf.Position, d.Size, 0.4, 0, STONE, Enum.Material.Cobblestone)
	disc(cf.Position, d.Size - 3, 0.45, 0, Color3.fromRGB(184, 176, 160), Enum.Material.Cobblestone)
	-- the town gate at the back (away from the plaza), with walls running out to the sides
	local back = cf * CFrame.new(0, 0, d.Size - 4)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "GateTower", Size = Vector3.new(7, 17, 7), CFrame = back * CFrame.new(side * 9, 8.5, 0), Color = STONE_DARK, Material = Enum.Material.Brick })
		part({ Name = "GateTowerTop", Size = Vector3.new(8.4, 1.4, 8.4), CFrame = back * CFrame.new(side * 9, 17.7, 0), Color = STONE, Material = Enum.Material.Brick })
		for index = -1, 1 do
			part({ Name = "Merlon", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = back * CFrame.new(side * 9 + index * 3, 19.2, -3.4), Color = STONE, Material = Enum.Material.Brick })
		end
		part({ Name = "TownWall", Size = Vector3.new(26, 9, 3), CFrame = back * CFrame.new(side * (12.5 + 13), 4.5, 1), Color = STONE_DARK, Material = Enum.Material.Brick })
		part({ Name = "Banner", Size = Vector3.new(3, 6, 0.2), CFrame = back * CFrame.new(side * 9, 11, -3.6), Color = Color3.fromRGB(176, 60, 60), Material = Enum.Material.Fabric })
	end
	local lintel = part({ Name = "GateLintel", Size = Vector3.new(12, 4, 6), CFrame = back * CFrame.new(0, 13, 0), Color = STONE_DARK, Material = Enum.Material.Brick })
	sign(lintel, Enum.NormalId.Front, "DUO QUEST TOWN")
	sign(lintel, Enum.NormalId.Back, "DUO QUEST TOWN")
	-- the well in the middle
	disc(cf.Position, 3.2, 2.6, 0.4, STONE_DARK, Enum.Material.Brick)
	disc(cf.Position, 2.4, 0.2, 2.9, Color3.fromRGB(60, 110, 160), Enum.Material.Glass)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "WellPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = cf * CFrame.new(side * 2.8, 5, 0), Color = WOOD, Material = Enum.Material.Wood })
	end
	part({ Name = "WellRoof", Size = Vector3.new(7, 0.5, 4), CFrame = cf * CFrame.new(0, 7.6, 0), Color = Color3.fromRGB(150, 70, 50), Material = Enum.Material.WoodPlanks })
	-- the tavern (left as you come from the plaza) and the notice board (right)
	house(cf * CFrame.new(22, 0, 8) * CFrame.Angles(0, math.rad(-70), 0), 18, 13, 10, Color3.fromRGB(230, 214, 180), Color3.fromRGB(140, 60, 44), "THE SLEEPY GRIFFIN")
	local tavernMark = part({ Name = "TavernSpot", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(14, 0.5, 5), Transparency = 1, CanCollide = false })
	tag(tavernMark, "TAVERN", "Townsfolk errands - coming soon")
	local boardCf = cf * CFrame.new(-18, 0, 2) * CFrame.Angles(0, math.rad(60), 0)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.8, 8, 0.8), CFrame = boardCf * CFrame.new(side * 4.4, 4, 0.3), Color = WOOD, Material = Enum.Material.Wood })
	end
	local face = part({ Name = "NoticeBoard", Size = Vector3.new(10, 5.6, 0.5), CFrame = boardCf * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local notes = { Color3.fromRGB(245, 238, 210), Color3.fromRGB(255, 230, 170), Color3.fromRGB(235, 245, 255) }
	for index = 1, 5 do
		part({ Name = "Note", Size = Vector3.new(1.6, 2, 0.1), CFrame = boardCf * CFrame.new(-3.6 + index * 1.5, 5.2 + (index % 2) * 0.9, -0.3) * CFrame.Angles(0, 0, math.rad((index % 3 - 1) * 6)), Color = notes[index % 3 + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	tag(face, "NOTICE BOARD", "Town bounties - coming soon")
	-- houses and lamps round the square
	house(cf * CFrame.new(-30, 0, 22) * CFrame.Angles(0, math.rad(40), 0), 12, 10, 8, Color3.fromRGB(220, 200, 170), Color3.fromRGB(90, 110, 150))
	house(cf * CFrame.new(32, 0, 24) * CFrame.Angles(0, math.rad(-40), 0), 12, 10, 8, Color3.fromRGB(235, 225, 200), Color3.fromRGB(120, 140, 80))
	for _, off in ipairs({ { -12, -16 }, { 12, -16 }, { -24, 12 }, { 24, 12 } }) do
		lamp((cf * CFrame.new(off[1], 0.4, off[2])).Position)
	end
	for _, off in ipairs({ { -8, -8 }, { 8, -8 } }) do
		flowerBed((cf * CFrame.new(off[1], 0.2, off[2])).Position, Color3.fromRGB(255, 120, 140))
	end
end

local function grove()
	local d = World.Districts.Grove
	local cf = districtFrame("Grove")
	disc(cf.Position, d.Size, 0.35, 0, Color3.fromRGB(110, 178, 96), Enum.Material.Grass)
	-- (the Wishing Tree itself is built by Hub at PlazaSpots.Tree, the middle of the Grove)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "WISHING GROVE", Color3.fromRGB(70, 150, 120))
	-- the fishing pond (right as you come in) with a little dock
	local pondCf = cf * CFrame.new(-34, 0, 14)
	disc(pondCf.Position, 11.5, 0.6, 0.1, Color3.fromRGB(150, 140, 120), Enum.Material.Sand)
	local water = disc(pondCf.Position, 10, 0.3, 0.55, Color3.fromRGB(70, 150, 200), Enum.Material.Glass)
	water.Transparency = 0.2
	for index = 1, 3 do
		local pad = disc((pondCf * CFrame.new(-4 + index * 2.6, 0, (index % 2) * 3 - 1)).Position, 0.9, 0.1, 0.9, Color3.fromRGB(80, 160, 80), Enum.Material.Grass)
		pad.Name = "LilyPad"
	end
	local dock = part({ Name = "Dock", Size = Vector3.new(3.4, 0.4, 9), CFrame = pondCf * CFrame.new(0, 1.1, -10) * CFrame.Angles(0, math.rad(25), 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	tag(dock, "FISHING POND", "Fishing - coming soon", Color3.fromRGB(150, 210, 255))
	part({ Name = "Rod", Size = Vector3.new(0.2, 0.2, 6), CFrame = dock.CFrame * CFrame.new(1, 1.6, 4) * CFrame.Angles(math.rad(30), 0, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	-- the pet park (left) behind a low fence, with a ball, a ramp and a doghouse
	local parkCf = cf * CFrame.new(34, 0, 16)
	local h = 10
	local corners = {}
	for _, c in ipairs({ { -h, -h }, { h, -h }, { h, h }, { -h, h } }) do
		table.insert(corners, (parkCf * CFrame.new(c[1], 0, c[2])).Position)
	end
	for index = 1, 4 do
		local a, b = corners[index], corners[index % 4 + 1]
		if index == 1 then
			-- leave a gap in the side facing the plaza for the way in
			fence(a, a:Lerp(b, 0.35), 2.4)
			fence(a:Lerp(b, 0.65), b, 2.4)
		else
			fence(a, b, 2.4)
		end
	end
	disc(parkCf.Position, 9, 0.2, 0.35, Color3.fromRGB(130, 196, 110), Enum.Material.Grass)
	local ball = part({ Name = "PetBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = parkCf * CFrame.new(-3, 1.2, -2), Color = Color3.fromRGB(240, 80, 80), Material = Enum.Material.SmoothPlastic })
	tag(ball, "PET PARK", "Play with your pet - coming soon", Color3.fromRGB(255, 170, 210))
	part({ Name = "Ramp", Size = Vector3.new(4, 2, 6), CFrame = parkCf * CFrame.new(4, 1.3, 3), Color = Color3.fromRGB(200, 160, 110), Material = Enum.Material.Wood }, "WedgePart")
	local kennel = parkCf * CFrame.new(5, 0, -5)
	part({ Name = "Doghouse", Size = Vector3.new(3.4, 2.8, 3.4), CFrame = kennel * CFrame.new(0, 1.75, 0), Color = Color3.fromRGB(190, 120, 80), Material = Enum.Material.WoodPlanks })
	part({ Name = "DoghouseRoof", Size = Vector3.new(4.2, 0.4, 4.2), CFrame = kennel * CFrame.new(0, 3.35, 0), Color = Color3.fromRGB(160, 60, 50), Material = Enum.Material.WoodPlanks })
	part({ Name = "DoghouseDoor", Size = Vector3.new(1.4, 1.6, 0.1), CFrame = kennel * CFrame.new(0, 1.15, -1.72), Color = Color3.fromRGB(40, 30, 24) })
	-- trees and flowers round the edge
	for index = 0, 13 do
		local a = math.rad(index * (360 / 14) + 6)
		local p = cf.Position + Vector3.new(math.sin(a) * (d.Size - 2), 0, math.cos(a) * (d.Size - 2))
		-- no tree in the way in (the arch faces the plaza)
		if (p - (cf * CFrame.new(0, 0, -d.Size)).Position).Magnitude > 18 then
			tree(p, 0.85 + (index % 3) * 0.15)
		end
	end
	local colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 130, 160) }
	for index, off in ipairs({ { -14, -30 }, { 14, -30 }, { -26, -12 }, { 26, -12 }, { 0, 34 } }) do
		flowerBed((cf * CFrame.new(off[1], 0.2, off[2])).Position, colors[index % 3 + 1])
	end
end

local function training()
	local d = World.Districts.Training
	local cf = districtFrame("Training")
	disc(cf.Position, d.Size, 0.35, 0, Color3.fromRGB(196, 170, 120), Enum.Material.Sand)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "TRAINING GROUNDS", Color3.fromRGB(170, 80, 60))
	-- a row of training dummies
	for index = -2, 2 do
		local post = cf * CFrame.new(index * 6, 0, -22)
		part({ Name = "DummyPost", Size = Vector3.new(0.5, 5.4, 0.5), CFrame = post * CFrame.new(0, 2.7, 0), Color = WOOD, Material = Enum.Material.Wood })
		part({ Name = "DummyBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = post * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		part({ Name = "DummyArms", Size = Vector3.new(3.6, 0.4, 0.4), CFrame = post * CFrame.new(0, 4, 0), Color = WOOD, Material = Enum.Material.Wood })
		local head = part({ Name = "DummyHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = post * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		if index == 0 then
			tag(head, "TRAINING DUMMY", "Test your build - coming soon", Color3.fromRGB(255, 190, 120))
		end
	end
	-- the sparring ring
	local ringCf = cf * CFrame.new(-22, 0, 10)
	part({ Name = "RingFloor", Size = Vector3.new(20, 1.2, 20), CFrame = ringCf * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.WoodPlanks })
	part({ Name = "RingMat", Size = Vector3.new(17, 0.1, 17), CFrame = ringCf * CFrame.new(0, 1.25, 0), Color = Color3.fromRGB(70, 90, 150), Material = Enum.Material.Fabric })
	for _, c in ipairs({ { -9.5, -9.5 }, { 9.5, -9.5 }, { 9.5, 9.5 }, { -9.5, 9.5 } }) do
		part({ Name = "RingPost", Size = Vector3.new(0.8, 4.6, 0.8), CFrame = ringCf * CFrame.new(c[1], 2.3 + 1.2, c[2]), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.SmoothPlastic })
	end
	for _, y in ipairs({ 3, 4.4 }) do
		for _, e in ipairs({ { 0, -9.5, 19, 0.25 }, { 0, 9.5, 19, 0.25 }, { -9.5, 0, 0.25, 19 }, { 9.5, 0, 0.25, 19 } }) do
			part({ Name = "Rope", Size = Vector3.new(e[3], 0.25, e[4]), CFrame = ringCf * CFrame.new(e[1], y, e[2]), Color = Color3.fromRGB(240, 230, 200), Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	local ringMark = part({ Name = "RingSpot", Size = Vector3.new(1, 1, 1), CFrame = ringCf * CFrame.new(0, 3, 0), Transparency = 1, CanCollide = false })
	tag(ringMark, "SPARRING RING", "Friendly duels - coming soon", Color3.fromRGB(255, 140, 120))
	-- the guild hall, with banners
	local hallCf = cf * CFrame.new(24, 0, 16) * CFrame.Angles(0, math.rad(-35), 0)
	house(hallCf, 20, 14, 12, Color3.fromRGB(210, 200, 190), Color3.fromRGB(90, 60, 130), "GUILD HALL")
	for _, side in ipairs({ -1, 1 }) do
		local banner = part({ Name = "GuildBanner", Size = Vector3.new(2.4, 6, 0.2), CFrame = hallCf * CFrame.new(side * 7, 7, -7.3), Color = Color3.fromRGB(120, 70, 180), Material = Enum.Material.Fabric })
		local star = part({ Name = "BannerStar", Size = Vector3.new(1.2, 1.2, 0.1), CFrame = banner.CFrame * CFrame.new(0, 1, -0.15) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = star, Phase = side, Base = 0.2, Amount = 0.15 })
	end
	-- weapon racks and archery targets along the sides
	for _, side in ipairs({ -1, 1 }) do
		local rack = cf * CFrame.new(side * 34, 0, -8) * CFrame.Angles(0, math.rad(side * 90), 0)
		part({ Name = "RackFrame", Size = Vector3.new(6, 4.4, 0.4), CFrame = rack * CFrame.new(0, 2.2, 0), Color = WOOD, Material = Enum.Material.Wood })
		for index = -2, 2 do
			part({ Name = "RackWeapon", Size = Vector3.new(0.25, 3.6, 0.6), CFrame = rack * CFrame.new(index * 1.1, 2.6, -0.4), Color = Color3.fromRGB(200, 204, 214), Material = Enum.Material.Metal })
		end
		local target = cf * CFrame.new(side * 12, 0, 36)
		part({ Name = "TargetStand", Size = Vector3.new(0.5, 4, 0.5), CFrame = target * CFrame.new(0, 2, 0.6), Color = WOOD, Material = Enum.Material.Wood })
		for ring, c in ipairs({ Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 60), Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 60) }) do
			part({ Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 + ring * 0.05, 4.2 - ring * 0.9, 4.2 - ring * 0.9), CFrame = target * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0), Color = c, Material = Enum.Material.SmoothPlastic })
		end
	end
	for _, off in ipairs({ { -14, -36 }, { 14, -36 }, { -38, 24 }, { 38, -24 } }) do
		lamp((cf * CFrame.new(off[1], 0.35, off[2])).Position)
	end
end

-- houses and trees along the ring between the districts, so the walk feels like a town
local function ringside()
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local R = World.TOWN_RING
	local walls = { Color3.fromRGB(230, 214, 180), Color3.fromRGB(220, 200, 170), Color3.fromRGB(235, 225, 200), Color3.fromRGB(210, 190, 160) }
	local roofs = { Color3.fromRGB(140, 60, 44), Color3.fromRGB(90, 110, 150), Color3.fromRGB(120, 140, 80), Color3.fromRGB(150, 100, 60) }
	local index = 0
	for _, angle in ipairs({ 116, 128, 146, 158, 202, 214, 232, 244 }) do -- clear of the districts and the signposts at 135 / 225
		index += 1
		local a = math.rad(angle)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		-- outside the ring: a house facing the road; inside: trees
		local at = centre + dir * (R + 16)
		house(CFrame.lookAt(at, centre + dir * R), 11, 9, 8, walls[index % 4 + 1], roofs[index % 4 + 1])
		tree(centre + dir * (R - 14), 0.9 + (index % 3) * 0.12)
		lamp(centre + dir * (R + 6))
	end
end

function Town.Build(parentFolder, hubPulsers)
	folder = Instance.new("Folder")
	folder.Name = "Town"
	folder.Parent = parentFolder
	pulsers = hubPulsers or {}
	roads()
	gate()
	grove()
	training()
	ringside()
	signposts()
	return folder
end

return Town
