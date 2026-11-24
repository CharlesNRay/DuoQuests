--[[
	Town (ModuleScript): the town districts around the plaza (docs/TOWN.md, phase 1: layout and scenery only).

	  Town.Build(folder, pulsers, kit)   builds the ring road, the spokes from the plaza, the three districts and the
	                                     errand NPCs (pulsers: Hub's glowing parts that breathe; kit: Hub's villager helpers)
	  Town.SetErrands(status), Town.Say(spotId, text), Town.OnErrand(spotId), Town.OnBoard()   town errands (phase 2)

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
local function tag(on, title, subtitle, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 46)
	gui.StudsOffset = Vector3.new(0, height or 4, 0)
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
	part({ Name = "Door", Size = Vector3.new(3.4, 6.4, 0.3), CFrame = cf * CFrame.new(0, 3.2, -d / 2 - 0.1), Color = DARK_WOOD, Material = Enum.Material.Wood })
	for _, x in ipairs({ -w / 4 - 0.6, w / 4 + 0.6 }) do
		part({ Name = "Window", Size = Vector3.new(2.6, 2.6, 0.3), CFrame = cf * CFrame.new(x, h * 0.55, -d / 2 - 0.1), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
	end
	if name then
		local board = part({ Name = "HouseSign", Size = Vector3.new(math.min(w - 4, 14), 2.2, 0.3), CFrame = cf * CFrame.new(0, h - 1.6, -d / 2 - 0.25), Color = DARK_WOOD, Material = Enum.Material.Wood })
		sign(board, Enum.NormalId.Front, name)
	end
end

-- an entrance arch with the district's name on both sides
local function arch(cf, width, text, color)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "ArchPost", Size = Vector3.new(1.4, 14, 1.4), CFrame = cf * CFrame.new(side * (width / 2 + 2), 7, 0), Color = WOOD, Material = Enum.Material.Wood })
		part({ Name = "ArchCap", Size = Vector3.new(2, 0.8, 2), CFrame = cf * CFrame.new(side * (width / 2 + 2), 14.4, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	end
	-- the name board hangs between the posts, thicker than them so they never poke through the text
	local beam = part({ Name = "ArchBeam", Size = Vector3.new(width + 2.6, 3.4, 1.8), CFrame = cf * CFrame.new(0, 12, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	sign(beam, Enum.NormalId.Front, text)
	sign(beam, Enum.NormalId.Back, text)
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

-- a flower bed: soil and flowers on stems (petals round a yellow middle), so it reads as flowers
-- (the 4 round leaf balls around it looked like odd spheres; removed after a playtest report 2026-11-23)
local function flowerBed(position, color)
	disc(position, 2.6, 0.4, 0.2, Color3.fromRGB(110, 80, 56), Enum.Material.Ground)
	for index = 1, 7 do
		local a = index * math.pi * 2 / 7
		local r = if index % 2 == 0 then 1.6 else 0.8
		local h = 1.4 + (index % 3) * 0.25
		local base = position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		part({ Name = "Stem", Size = Vector3.new(0.12, h, 0.12), Position = base + Vector3.new(0, 0.4 + h / 2, 0), Color = Color3.fromRGB(60, 130, 60), Material = Enum.Material.Grass, CanCollide = false })
		local top = base + Vector3.new(0, 0.45 + h, 0)
		for petal = 1, 5 do
			local pa = petal * math.pi * 2 / 5 + index
			part({ Name = "Petal", Size = Vector3.new(0.32, 0.08, 0.2), CFrame = CFrame.new(top + Vector3.new(math.cos(pa) * 0.22, 0, math.sin(pa) * 0.22)) * CFrame.Angles(0, -pa, 0), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
		part({ Name = "FlowerMiddle", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), Position = top + Vector3.new(0, 0.04, 0), Color = Color3.fromRGB(255, 210, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
end

-- a frame at (x, z) in district frame `cf`, with its front (-Z) toward the district point (tx, tz)
local function facing(cf, x, z, tx, tz)
	return cf * CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(tx or 0, 0, tz or 0))
end

local function districtFrame(id)
	local x, z = World.DistrictPoint(id)
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z))
end

-- roads ----------------------------------------------------------------------
local function road(from, to, width, name)
	local mid = (from + to) / 2
	return part({ Name = name or "Road", Size = Vector3.new(width or 10, 0.32, (to - from).Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.16, 0), to + Vector3.new(0, 0.16, 0)), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
end

local function polar(angle, radius)
	local a = math.rad(angle)
	return Vector3.new(World.PLAZA.X + math.sin(a) * radius, 0, World.PLAZA.Z - math.cos(a) * radius)
end

local function roads()
	-- spokes from the plaza rim to each district's edge
	for _, id in ipairs(World.DistrictOrder) do
		local d = World.Districts[id]
		road(polar(d.Angle, World.PLAZA.Radius - 1), polar(d.Angle, d.Radius - d.Size + 2), 10, "Spoke")
	end
	-- the high road south to the main gate
	road(polar(180, World.PLAZA.Radius - 1), polar(180, World.TOWN_WALL.Radius + 6), 14, "HighRoad")
	-- to the battle lots (player homes), south-east
	-- the homes street: lots on both sides face it (World.HOMES_STREET)
	do
		local sx, sz, dx, dz, length = World.HomesStreet()
		road(Vector3.new(sx, 0, sz), Vector3.new(sx + dx * length, 0, sz + dz * length), World.HOMES_STREET.Width, "HomesStreet")
	end
	-- through the Wishing Grove to the Giant Bosses gate (north-east)
	local grove = World.Districts.Grove
	road(polar(grove.Angle, grove.Radius + grove.Size - 4), polar(38, World.TOWN_WALL.Radius + 6), 9, "BossRoad")
end

-- trees: one on each side of a district's way in, and rows filling the green between the districts and the wall
local function clearOfEverything(p, margin)
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	if (p - centre).Magnitude < World.PLAZA.Radius + 8 then
		return false
	end
	for _, id in ipairs(World.DistrictOrder) do
		local x, z = World.DistrictPoint(id)
		if (p - Vector3.new(x, 0, z)).Magnitude < World.Districts[id].Size + margin then
			return false
		end
	end
	for slot = 1, World.MAX_LOTS do
		local ax, _, az, yaw = World.ArenaOrigin(slot)
		-- into the lot's own (turned) frame; the strip behind it (apron, 24 deep) counts too
		local dx, dz = p.X - ax, p.Z - az
		local c, s = math.cos(yaw), math.sin(yaw)
		local lx, lz = dx * c - dz * s, dx * s + dz * c
		if math.abs(lx) < World.ARENA_WIDTH / 2 + margin and lz < World.ARENA_DEPTH / 2 + 8 + margin and lz > -World.ARENA_DEPTH / 2 - World.APRON_DEPTH - margin then
			return false
		end
	end
	local dx, dz = World.TownSpot("DungeonGate")
	if (p - Vector3.new(dx, 0, dz)).Magnitude < 36 + margin then
		return false
	end
	-- not on a road: the angle of every spoke, the high road and the lot road
	local a = math.deg(math.atan2(p.X - centre.X, -(p.Z - centre.Z))) % 360
	local r = (p - centre).Magnitude
	local roadAngles = { 180, World.HOMES_STREET.Angle, 38 }
	for _, id in ipairs(World.DistrictOrder) do
		table.insert(roadAngles, World.Districts[id].Angle % 360)
	end
	for _, ra in ipairs(roadAngles) do
		local diff = math.abs(((a - ra + 180) % 360) - 180)
		if math.rad(diff) * r < 9 + margin then
			return false
		end
	end
	return r < World.TOWN_WALL.Radius - 10
end

local function greenery()
	for _, ring in ipairs({ { R = 105, Step = 15 }, { R = 240, Step = 7 }, { R = 270, Step = 6 } }) do
		for deg = 0, 359, ring.Step do
			local p = polar(deg + (ring.R % 7), ring.R)
			if clearOfEverything(p, 6) then
				tree(p, 0.85 + ((deg // ring.Step) % 3) * 0.15)
			end
		end
	end
end

-- districts ------------------------------------------------------------------
-- Old Town (north-west): the square with the well, the Sleepy Griffin, Old Mabel's cottage, the notice board, Pip
local function housing()
	local d = World.Districts.Housing
	local cf = districtFrame("Housing")
	disc(cf.Position, d.Size, 0.4, 0, STONE, Enum.Material.Cobblestone)
	disc(cf.Position, d.Size - 3, 0.45, 0, Color3.fromRGB(184, 176, 160), Enum.Material.Cobblestone)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "OLD TOWN", Color3.fromRGB(140, 90, 60))
	-- the well in the middle
	disc(cf.Position, 3.2, 2.6, 0.4, STONE_DARK, Enum.Material.Brick)
	disc(cf.Position, 2.4, 0.2, 2.9, Color3.fromRGB(60, 110, 160), Enum.Material.Glass)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "WellPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = cf * CFrame.new(side * 2.8, 5, 0), Color = WOOD, Material = Enum.Material.Wood })
	end
	part({ Name = "WellRoof", Size = Vector3.new(7, 0.5, 4), CFrame = cf * CFrame.new(0, 7.6, 0), Color = Color3.fromRGB(150, 70, 50), Material = Enum.Material.WoodPlanks })
	-- the tavern (Greta stands at its door, see errands())
	house(facing(cf, 27, 8), 22, 16, 13, Color3.fromRGB(230, 214, 180), Color3.fromRGB(140, 60, 44), "THE SLEEPY GRIFFIN")
	local bx, bz = -14, -28 -- World.TownSpots.Board: beside the road in, clear of the houses
	local boardCf = facing(cf, bx, bz, 0, -46) -- faces people walking in from the plaza
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.8, 8, 0.8), CFrame = boardCf * CFrame.new(side * 4.4, 4, 0.3), Color = WOOD, Material = Enum.Material.Wood })
	end
	local face = part({ Name = "NoticeBoard", Size = Vector3.new(10, 5.6, 0.5), CFrame = boardCf * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local notes = { Color3.fromRGB(245, 238, 210), Color3.fromRGB(255, 230, 170), Color3.fromRGB(235, 245, 255) }
	for index = 1, 5 do
		part({ Name = "Note", Size = Vector3.new(1.6, 2, 0.1), CFrame = boardCf * CFrame.new(-3.6 + index * 1.5, 5.2 + (index % 2) * 0.9, -0.3) * CFrame.Angles(0, 0, math.rad((index % 3 - 1) * 6)), Color = notes[index % 3 + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	tag(face, "NOTICE BOARD", "Town errands")
	-- cottages round the square (Old Mabel's is the one at (-28, 24)), each facing the well
	house(facing(cf, -28, 24), 16, 13, 11, Color3.fromRGB(220, 200, 170), Color3.fromRGB(90, 110, 150))
	house(facing(cf, -32, -8), 14, 12, 10, Color3.fromRGB(235, 225, 200), Color3.fromRGB(120, 140, 80))
	house(facing(cf, 8, 38), 14, 12, 10, Color3.fromRGB(225, 210, 185), Color3.fromRGB(150, 100, 60))
	house(facing(cf, 32, -24), 13, 11, 10, Color3.fromRGB(215, 195, 170), Color3.fromRGB(120, 70, 60))
	for _, off in ipairs({ { -12, -16 }, { 12, -16 }, { -38, 6 }, { 40, 6 } }) do -- beside the houses, not before their doors
		lamp((cf * CFrame.new(off[1], 0.4, off[2])).Position)
	end
	for _, off in ipairs({ { -20, 4 }, { 20, -6 } }) do
		flowerBed((cf * CFrame.new(off[1], 0.2, off[2])).Position, Color3.fromRGB(255, 120, 140))
	end
end

-- the Wishing Grove (north-east): the Wishing Tree (built by Hub at PlazaSpots.Tree), flowers, trees round the edge
local function grove()
	local d = World.Districts.Grove
	local cf = districtFrame("Grove")
	disc(cf.Position, d.Size, 0.35, 0, Color3.fromRGB(110, 178, 96), Enum.Material.Grass)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "WISHING GROVE", Color3.fromRGB(70, 150, 120))
	for index = 0, 13 do
		local a = math.rad(index * (360 / 14) + 6)
		local p = cf.Position + Vector3.new(math.sin(a) * (d.Size - 2), 0, math.cos(a) * (d.Size - 2))
		-- no tree in the way in (the arch faces the plaza) or on the road out to the Giant Bosses
		local inWay = (p - (cf * CFrame.new(0, 0, -d.Size)).Position).Magnitude < 18 or (p - (cf * CFrame.new(0, 0, d.Size)).Position).Magnitude < 16
		if not inWay then
			tree(p, 0.85 + (index % 3) * 0.15)
		end
	end
	local colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 130, 160) }
	for index, off in ipairs({ { -14, -30 }, { 14, -30 }, { -26, -12 }, { 26, -12 }, { -22, 26 } }) do
		flowerBed((cf * CFrame.new(off[1], 0.2, off[2])).Position, colors[index % 3 + 1])
	end
end

-- the Pet Area (west): the pet park behind a fence, the fishing pond with its dock, trees
local function petArea()
	local d = World.Districts.PetArea
	local cf = districtFrame("PetArea")
	disc(cf.Position, d.Size, 0.35, 0, Color3.fromRGB(120, 186, 100), Enum.Material.Grass)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "PET AREA", Color3.fromRGB(220, 120, 160))
	-- the fishing pond (left as you come in) with a little dock
	local pondCf = cf * CFrame.new(-18, 0, 8)
	disc(pondCf.Position, 11.5, 0.6, 0.1, Color3.fromRGB(150, 140, 120), Enum.Material.Sand)
	local water = disc(pondCf.Position, 10, 0.3, 0.55, Color3.fromRGB(70, 150, 200), Enum.Material.Glass)
	water.Transparency = 0.2
	for index = 1, 3 do
		local pad = disc((pondCf * CFrame.new(-4 + index * 2.6, 0, (index % 2) * 3 - 1)).Position, 0.9, 0.1, 0.9, Color3.fromRGB(80, 160, 80), Enum.Material.Grass)
		pad.Name = "LilyPad"
	end
	local dock = part({ Name = "Dock", Size = Vector3.new(3.4, 0.4, 9), CFrame = pondCf * CFrame.new(0, 1.1, -12) * CFrame.Angles(0, math.rad(15), 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	tag(dock, "FISHING POND", "Catch fish for pet snacks", Color3.fromRGB(150, 210, 255))
	dock:SetAttribute("PlaceId", "Pond")
	local bob = part({ Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = pondCf * CFrame.new(2, 1.25, -5), Color = Color3.fromRGB(230, 60, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false, Transparency = 1 })
	bob:SetAttribute("Bobber", true)
	part({ Name = "Rod", Size = Vector3.new(0.2, 0.2, 6), CFrame = dock.CFrame * CFrame.new(1, 1.6, 4) * CFrame.Angles(math.rad(30), 0, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	-- the pet park (right) behind a low fence, with a ball, a ramp and a doghouse
	local parkCf = cf * CFrame.new(16, 0, 4)
	local h = 12
	local corners = {}
	for _, c in ipairs({ { -h, -h }, { h, -h }, { h, h }, { -h, h } }) do
		table.insert(corners, (parkCf * CFrame.new(c[1], 0, c[2])).Position)
	end
	for index = 1, 4 do
		local a, b = corners[index], corners[index % 4 + 1]
		if index == 1 then
			fence(a, a:Lerp(b, 0.35), 2.4) -- the gap in the side facing the plaza is the way in
			fence(a:Lerp(b, 0.65), b, 2.4)
		else
			fence(a, b, 2.4)
		end
	end
	disc(parkCf.Position, 11, 0.2, 0.35, Color3.fromRGB(130, 196, 110), Enum.Material.Grass)
	local ball = part({ Name = "PetBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = parkCf * CFrame.new(-3, 1.2, -2), Color = Color3.fromRGB(240, 80, 80), Material = Enum.Material.SmoothPlastic })
	tag(ball, "PET PARK", "Play with your pet once a day", Color3.fromRGB(255, 170, 210))
	ball:SetAttribute("PlaceId", "PetPark")
	part({ Name = "Ramp", Size = Vector3.new(4, 2, 6), CFrame = parkCf * CFrame.new(4, 1.3, 5), Color = Color3.fromRGB(200, 160, 110), Material = Enum.Material.Wood }, "WedgePart")
	local kennel = parkCf * CFrame.new(6, 0, -6)
	part({ Name = "Doghouse", Size = Vector3.new(3.4, 2.8, 3.4), CFrame = kennel * CFrame.new(0, 1.75, 0), Color = Color3.fromRGB(190, 120, 80), Material = Enum.Material.WoodPlanks })
	part({ Name = "DoghouseRoof", Size = Vector3.new(4.2, 0.4, 4.2), CFrame = kennel * CFrame.new(0, 3.35, 0), Color = Color3.fromRGB(160, 60, 50), Material = Enum.Material.WoodPlanks })
	part({ Name = "DoghouseDoor", Size = Vector3.new(1.4, 1.6, 0.1), CFrame = kennel * CFrame.new(0, 1.15, -1.72), Color = Color3.fromRGB(40, 30, 24) })
	local sign2 = part({ Name = "PawSign", Size = Vector3.new(4, 3, 0.3), CFrame = cf * CFrame.new(-10, 4, -d.Size + 8), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.WoodPlanks })
	sign(sign2, Enum.NormalId.Front, "PAWS", Color3.fromRGB(70, 140, 90))
	part({ Name = "PawSignPost", Size = Vector3.new(0.4, 3, 0.4), CFrame = cf * CFrame.new(-10, 1.5, -d.Size + 8), Color = DARK_WOOD, Material = Enum.Material.Wood })
	for index = 0, 11 do
		local a = math.rad(index * 30 + 10)
		local p = cf.Position + Vector3.new(math.sin(a) * (d.Size - 2), 0, math.cos(a) * (d.Size - 2))
		if (p - (cf * CFrame.new(0, 0, -d.Size)).Position).Magnitude > 18 then
			tree(p, 0.85 + (index % 3) * 0.15)
		end
	end
end

-- the Combat Arena (south-west): the sparring ring in the middle, training dummies, weapon racks, archery targets
local function training()
	local d = World.Districts.Training
	local cf = districtFrame("Training")
	disc(cf.Position, d.Size, 0.35, 0, Color3.fromRGB(196, 170, 120), Enum.Material.Sand)
	arch(cf * CFrame.new(0, 0, -d.Size + 3), 14, "COMBAT ARENA", Color3.fromRGB(170, 80, 60))
	-- a fence of banners round the arena, open towards the plaza
	for index = 0, 17 do
		local a = index * 20 + 10
		if math.abs(((a - 180 + 180) % 360) - 180) > 22 then -- leave the way in (local -Z, toward the plaza)
			local p = cf * CFrame.new(math.sin(math.rad(a)) * (d.Size - 4), 0, math.cos(math.rad(a)) * (d.Size - 4))
			part({ Name = "ArenaPost", Size = Vector3.new(0.8, 6, 0.8), CFrame = p * CFrame.new(0, 3, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
			part({ Name = "ArenaBanner", Size = Vector3.new(0.2, 3, 2), CFrame = p * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(a), 0), Color = if index % 2 == 0 then Color3.fromRGB(190, 50, 50) else Color3.fromRGB(230, 190, 70), Material = Enum.Material.Fabric })
		end
	end
	-- a row of training dummies
	for index = -2, 2 do
		local post = cf * CFrame.new(index * 6, 0, -24)
		part({ Name = "DummyPost", Size = Vector3.new(0.5, 5.4, 0.5), CFrame = post * CFrame.new(0, 2.7, 0), Color = WOOD, Material = Enum.Material.Wood })
		part({ Name = "DummyBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = post * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		part({ Name = "DummyArms", Size = Vector3.new(3.6, 0.4, 0.4), CFrame = post * CFrame.new(0, 4, 0), Color = WOOD, Material = Enum.Material.Wood })
		local head = part({ Name = "DummyHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = post * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		if index == 0 then
			tag(head, "TRAINING DUMMY", "Test your party's damage", Color3.fromRGB(255, 190, 120))
			head:SetAttribute("PlaceId", "Dummy")
		end
	end
	-- the sparring ring in the middle
	local ringCf = cf * CFrame.new(0, 0, 8)
	local S = 24
	part({ Name = "RingFloor", Size = Vector3.new(S, 1.2, S), CFrame = ringCf * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.WoodPlanks })
	part({ Name = "RingMat", Size = Vector3.new(S - 3, 0.1, S - 3), CFrame = ringCf * CFrame.new(0, 1.25, 0), Color = Color3.fromRGB(70, 90, 150), Material = Enum.Material.Fabric })
	local e = S / 2 - 0.5
	for _, c in ipairs({ { -e, -e }, { e, -e }, { e, e }, { -e, e } }) do
		part({ Name = "RingPost", Size = Vector3.new(0.8, 4.6, 0.8), CFrame = ringCf * CFrame.new(c[1], 2.3 + 1.2, c[2]), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.SmoothPlastic })
	end
	for _, y in ipairs({ 3, 4.4 }) do
		for _, r in ipairs({ { 0, -e, S - 1, 0.25 }, { 0, e, S - 1, 0.25 }, { -e, 0, 0.25, S - 1 }, { e, 0, 0.25, S - 1 } }) do
			part({ Name = "Rope", Size = Vector3.new(r[3], 0.25, r[4]), CFrame = ringCf * CFrame.new(r[1], y, r[2]), Color = Color3.fromRGB(240, 230, 200), Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	for _, side in ipairs({ -1, 1 }) do -- torches at the ring
		local flame = part({ Name = "RingTorch", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.5, 1.2), CFrame = ringCf * CFrame.new(side * (e + 3), 6.5, -e), Color = Color3.fromRGB(255, 150, 50), Material = Enum.Material.Neon, CanCollide = false })
		part({ Name = "RingTorchPost", Size = Vector3.new(0.6, 6, 0.6), CFrame = ringCf * CFrame.new(side * (e + 3), 3, -e), Color = DARK_WOOD, Material = Enum.Material.Wood })
		table.insert(pulsers, { Part = flame, Phase = side, Base = 0.05, Amount = 0.2 })
	end
	local ringMark = part({ Name = "RingSpot", Size = Vector3.new(1, 1, 1), CFrame = ringCf * CFrame.new(0, 3, 0), Transparency = 1, CanCollide = false })
	tag(ringMark, "SPARRING RING", "Duel another hero", Color3.fromRGB(255, 140, 120))
	ringMark:SetAttribute("PlaceId", "Ring")
	-- weapon racks and archery targets along the sides
	for _, side in ipairs({ -1, 1 }) do
		local rack = cf * CFrame.new(side * 34, 0, -8) * CFrame.Angles(0, math.rad(side * 90), 0)
		part({ Name = "RackFrame", Size = Vector3.new(6, 4.4, 0.4), CFrame = rack * CFrame.new(0, 2.2, 0), Color = WOOD, Material = Enum.Material.Wood })
		for index = -2, 2 do
			part({ Name = "RackWeapon", Size = Vector3.new(0.25, 3.6, 0.6), CFrame = rack * CFrame.new(index * 1.1, 2.6, -0.4), Color = Color3.fromRGB(200, 204, 214), Material = Enum.Material.Metal })
		end
		local target = cf * CFrame.new(side * 12, 0, 38)
		part({ Name = "TargetStand", Size = Vector3.new(0.5, 4, 0.5), CFrame = target * CFrame.new(0, 2, 0.6), Color = WOOD, Material = Enum.Material.Wood })
		for ring, c in ipairs({ Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 60), Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 60) }) do
			part({ Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 + ring * 0.05, 4.2 - ring * 0.9, 4.2 - ring * 0.9), CFrame = target * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0), Color = c, Material = Enum.Material.SmoothPlastic })
		end
	end
	for _, off in ipairs({ { -14, -40 }, { 14, -40 } }) do
		lamp((cf * CFrame.new(off[1], 0.35, off[2])).Position)
	end
end

-- the Guild (north): a small castle against the town wall, with towers and banners
local function guild()
	local d = World.Districts.Guild
	local cf = districtFrame("Guild")
	disc(cf.Position, d.Size, 0.4, 0, STONE, Enum.Material.Cobblestone)
	disc(cf.Position, d.Size - 3, 0.45, 0, Color3.fromRGB(176, 170, 160), Enum.Material.Cobblestone)
	local hall = cf * CFrame.new(0, 0, 22) -- the keep, its door facing the plaza
	local W, D, H = 36, 22, 18
	local WALL = Color3.fromRGB(150, 150, 165)
	part({ Name = "Keep", Size = Vector3.new(W, H, D), CFrame = hall * CFrame.new(0, H / 2, 0), Color = WALL, Material = Enum.Material.Brick })
	for i = -4, 4 do -- crenellations along the front
		part({ Name = "KeepMerlon", Size = Vector3.new(2.4, 2, 2.4), CFrame = hall * CFrame.new(i * 4, H + 1, -D / 2 + 1.2), Color = WALL, Material = Enum.Material.Brick })
	end
	-- a blue roof and a central spire
	part({ Name = "KeepRoof", Size = Vector3.new(W - 6, 1.2, D - 6), CFrame = hall * CFrame.new(0, H + 0.6, 2), Color = Color3.fromRGB(60, 80, 170), Material = Enum.Material.Slate })
	part({ Name = "Spire", Size = Vector3.new(8, 14, 8), CFrame = hall * CFrame.new(0, H + 7, 4), Color = WALL, Material = Enum.Material.Brick })
	part({ Name = "SpireRoof", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 8, 10), CFrame = hall * CFrame.new(0, H + 15, 4), Color = Color3.fromRGB(60, 80, 170), Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		local tower = hall * CFrame.new(side * (W / 2 + 3), 0, -2)
		part({ Name = "KeepTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(H + 8, 10, 10), CFrame = tower * CFrame.new(0, (H + 8) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = WALL, Material = Enum.Material.Brick })
		part({ Name = "KeepTowerRoof", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 7, 11), CFrame = tower * CFrame.new(0, H + 9, 0), Color = Color3.fromRGB(60, 80, 170), Material = Enum.Material.Slate })
		local banner = part({ Name = "GuildBanner", Size = Vector3.new(3, 8, 0.2), CFrame = hall * CFrame.new(side * 9, H - 6, -D / 2 - 0.15), Color = Color3.fromRGB(50, 70, 170), Material = Enum.Material.Fabric })
		local star = part({ Name = "BannerStar", Size = Vector3.new(1.4, 1.4, 0.1), CFrame = banner.CFrame * CFrame.new(0, 1.5, -0.15) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = star, Phase = side, Base = 0.2, Amount = 0.15 })
	end
	part({ Name = "KeepDoor", Size = Vector3.new(6, 9, 0.4), CFrame = hall * CFrame.new(0, 4.5, -D / 2 - 0.2), Color = DARK_WOOD, Material = Enum.Material.Wood })
	local signBoard = part({ Name = "KeepSign", Size = Vector3.new(14, 2.6, 0.3), CFrame = hall * CFrame.new(0, 11, -D / 2 - 0.3), Color = Color3.fromRGB(40, 50, 110), Material = Enum.Material.Wood })
	sign(signBoard, Enum.NormalId.Front, "GUILD HALL", Color3.fromRGB(255, 220, 120))
	-- a low fence round the courtyard, open at the front
	for _, side in ipairs({ -1, 1 }) do
		fence((cf * CFrame.new(side * 40, 0, -10)).Position, (cf * CFrame.new(side * 40, 0, 30)).Position, 2.6)
		fence((cf * CFrame.new(side * 40, 0, -10)).Position, (cf * CFrame.new(side * 18, 0, -30)).Position, 2.6)
	end
	for _, off in ipairs({ { -10, -24 }, { 10, -24 } }) do
		lamp((cf * CFrame.new(off[1], 0.4, off[2])).Position)
	end
end

-- the Market (east): the shop stalls stand in a ring round the square facing its middle (built by Hub at PlazaSpots,
-- World.MARKET_RING); this is the ground, a maypole in the middle with bunting out to every stall, and barrels and
-- lamps in the gaps. Angles round the square: 0 = toward the plaza (the way in), clockwise from above.
local function market()
	local d = World.Districts.Market
	local cf = districtFrame("Market")
	disc(cf.Position, d.Size, 0.38, 0, Color3.fromRGB(176, 160, 136), Enum.Material.Cobblestone)
	local function at(angle, radius)
		local a = math.rad(angle)
		return cf * CFrame.new(math.sin(a) * radius, 0, -math.cos(a) * radius)
	end
	local colors = { Color3.fromRGB(220, 70, 70), Color3.fromRGB(240, 200, 70), Color3.fromRGB(70, 140, 220), Color3.fromRGB(90, 190, 110) }
	-- the maypole, and a string of flags from its top to each stall's awning
	local top = cf * CFrame.new(0, 14, 0)
	part({ Name = "MarketPole", Size = Vector3.new(0.8, 14.5, 0.8), CFrame = cf * CFrame.new(0, 7.2, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	part({ Name = "MarketPoleTop", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = top * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(240, 200, 70), Material = Enum.Material.SmoothPlastic })
	for _, name in ipairs({ "Merchant", "PetStore", "Trainer", "Blacksmith", "RuneCarver", "Store" }) do
		local spot = World.PlazaSpots[name]
		local stall = at(spot.Market, World.MARKET_RING - 3) * CFrame.new(0, 10, 0)
		local from, to = top.Position, stall.Position
		local length = (to - from).Magnitude
		part({ Name = "BuntingLine", Size = Vector3.new(0.1, 0.1, length), CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to), Color = Color3.fromRGB(80, 60, 40), CanCollide = false })
		local side = (to - from):Cross(Vector3.yAxis)
		for index = 1, 5 do
			local p = from:Lerp(to, index / 6) - Vector3.new(0, 0.9, 0)
			part({ Name = "Bunting", Size = Vector3.new(1.4, 1.6, 0.1), CFrame = CFrame.lookAt(p, p + side) * CFrame.Angles(0, 0, math.rad(180)), Color = colors[index % 4 + 1], Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	-- barrels and crates in the side gaps between the stalls, lamps at both ways in
	for index, angle in ipairs({ 65, 115, 245, 295 }) do
		local p = at(angle, World.MARKET_RING + 2)
		part({ Name = "MarketBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.2, 2.2), CFrame = p * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks })
		part({ Name = "MarketCrate", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = p * CFrame.new(2.8, 1.1, 0.6) * CFrame.Angles(0, math.rad(index * 17), 0), Color = Color3.fromRGB(170, 126, 80), Material = Enum.Material.WoodPlanks })
	end
	for _, angle in ipairs({ -14, 14, 166, 194 }) do
		lamp(at(angle, World.MARKET_RING + 6).Position)
	end
end

-- the Giant Bosses (outside the north-east gate): a scorched field with rocks and a skull rock behind it
-- (the bosses themselves are server models at World.BossSpots)
local function bossField()
	local f = World.BossField
	local centre = Vector3.new(f.X, 0, f.Z)
	disc(centre, f.Radius, 0.3, 0, Color3.fromRGB(130, 110, 90), Enum.Material.Ground)
	local gate = polar(38, World.TOWN_WALL.Radius + 6)
	local toTown = (Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z) - centre).Unit
	local edge = centre + toTown * (f.Radius - 4)
	road(gate, edge, 10, "FieldPath")
	arch(CFrame.lookAt(edge, centre) * CFrame.new(0, 0, 3), 16, "GIANT BOSSES", Color3.fromRGB(150, 50, 50))
	for index = 1, 10 do
		local a = math.rad(index * 36 + 15)
		local r = f.Radius - 5 - (index % 3) * 4
		local p = centre + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if (p - edge).Magnitude > 16 then
			part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 4, 5) * (1 + index % 3 * 0.4), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)), Color = Color3.fromRGB(110, 104, 98), Material = Enum.Material.Slate })
		end
	end
	-- the skull rock looming behind the field (away from town)
	local back = centre - toTown * (f.Radius + 12)
	local skullCf = CFrame.lookAt(back, centre)
	part({ Name = "SkullRock", Shape = Enum.PartType.Ball, Size = Vector3.new(40, 34, 30), CFrame = skullCf * CFrame.new(0, 12, 0), Color = Color3.fromRGB(90, 86, 94), Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		local eye = part({ Name = "SkullEye", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 5, 2), CFrame = skullCf * CFrame.new(side * 7, 18, -14), Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = eye, Phase = side, Base = 0.05, Amount = 0.25 })
	end
end

-- the town wall: a ring round the whole town (plaza, districts, lots) with the main gate to the south and small gates
-- where the roads leave for the Dungeon Gate and the Expedition Camp (World.TOWN_WALL)
local function townWall()
	local w = World.TOWN_WALL
	local R = w.Radius
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local function point(deg, r)
		local a = math.rad(deg)
		return centre + Vector3.new(math.sin(a) * (r or R), 0, -math.cos(a) * (r or R))
	end
	local function nearGate(deg, extra)
		for _, g in ipairs(w.Gates) do
			local half = math.deg((g.Width / 2 + (extra or 0)) / R)
			local diff = math.abs(((deg - g.Angle + 180) % 360) - 180)
			if diff < half then
				return true
			end
		end
		return false
	end
	local HEIGHT = 12
	local STEP = 3
	for deg = 0, 360 - STEP, STEP do
		local mid = deg + STEP / 2
		if not nearGate(mid, 6) then
			local p1, p2 = point(deg), point(deg + STEP)
			local m = (p1 + p2) / 2
			local cf = CFrame.lookAt(m + Vector3.new(0, HEIGHT / 2, 0), p2 + Vector3.new(0, HEIGHT / 2, 0))
			part({ Name = "TownWall", Size = Vector3.new(3, HEIGHT, (p2 - p1).Magnitude + 0.6), CFrame = cf, Color = STONE_DARK, Material = Enum.Material.Brick })
			part({ Name = "Merlon", Size = Vector3.new(3.2, 1.6, 2), CFrame = cf * CFrame.new(0, HEIGHT / 2 + 0.8, 0), Color = STONE, Material = Enum.Material.Brick })
		end
	end
	-- towers round the ring
	for deg = 15, 345, 30 do
		if not nearGate(deg, 14) then
			local at = point(deg)
			part({ Name = "WallTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(HEIGHT + 6, 9, 9), CFrame = CFrame.new(at + Vector3.new(0, (HEIGHT + 6) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE_DARK, Material = Enum.Material.Brick })
			part({ Name = "WallTowerTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 10.4, 10.4), CFrame = CFrame.new(at + Vector3.new(0, HEIGHT + 6.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Brick })
		end
	end
	-- the gates: two towers and a named lintel; the main gate is bigger and has banners
	for _, g in ipairs(w.Gates) do
		if g.Hill then
			continue -- the Dungeon's hill stands in the wall here (dungeonGate)
		end
		local cf = CFrame.lookAt(point(g.Angle), centre) -- front (-Z) faces into town
		local big = g.Main == true
		local tw = if big then 8 else 6
		local th = if big then HEIGHT + 9 else HEIGHT + 5
		local off = g.Width / 2 + tw / 2
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "GateTower", Size = Vector3.new(tw, th, tw), CFrame = cf * CFrame.new(side * off, th / 2, 0), Color = STONE_DARK, Material = Enum.Material.Brick })
			part({ Name = "GateTowerTop", Size = Vector3.new(tw + 1.4, 1.4, tw + 1.4), CFrame = cf * CFrame.new(side * off, th + 0.7, 0), Color = STONE, Material = Enum.Material.Brick })
			if big then
				for _, face in ipairs({ -1, 1 }) do
					part({ Name = "Banner", Size = Vector3.new(3.4, 7, 0.2), CFrame = cf * CFrame.new(side * off, th - 6, face * (tw / 2 + 0.15)), Color = Color3.fromRGB(176, 60, 60), Material = Enum.Material.Fabric })
				end
			end
		end
		local lintel = part({ Name = "GateLintel", Size = Vector3.new(g.Width + 2, if big then 4.5 else 3.4, tw - 1), CFrame = cf * CFrame.new(0, th - (if big then 3 else 2.4), 0), Color = STONE_DARK, Material = Enum.Material.Brick })
		sign(lintel, Enum.NormalId.Front, g.Name)
		sign(lintel, Enum.NormalId.Back, g.Name)
		-- the road through the gate
		part({ Name = "GateRoad", Size = Vector3.new(g.Width - 4, 0.34, tw + 10), CFrame = cf * CFrame.new(0, 0.17, 0), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
	end
end

-- Town errands (docs/TOWN.md phase 2, Shared/Errands) --------------------------------------------------------
-- NPCs and pick-up spots at World.TownSpots, each with a prompt. Town.OnErrand(spotId) / Town.OnBoard() are set by
-- Main; Town.SetErrands(status) shows who has an errand (!) or waits for you (?), the cat, and what you carry;
-- Town.Say(spotId, text) puts a speech bubble over a spot for a few seconds.
local Players = game:GetService("Players")
local ErrandConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Errands"))

Town.OnErrand = nil
Town.OnBoard = nil
local spots = {} -- [spotId] = { Anchor = part, Prompt = ProximityPrompt, Marker = TextLabel, Kind = "Giver"|"Pickup"|"Cat"|"Board" }
local cat = nil
local kit = nil -- Hub's villager / nameTag helpers

local function spotPos(id)
	local x, z = World.TownSpot(id)
	return Vector3.new(x, 0, z)
end

-- a frame at the spot, facing its district's centre (or the Boss Field arch for the field spots)
local function spotFrame(id)
	local spot = World.TownSpots[id]
	local at = spotPos(id)
	local tx, tz
	if spot.District then
		tx, tz = World.DistrictPoint(spot.District)
	else
		tx, tz = World.BossField.X, World.BossField.Z - World.BossField.Radius
	end
	if (Vector3.new(tx, 0, tz) - at).Magnitude < 1 then
		tx, tz = World.PLAZA.X, World.PLAZA.Z
	end
	return CFrame.lookAt(at, Vector3.new(tx, 0, tz))
end

local function marker(on, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	gui.Adornee = on
	gui.Parent = on
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "!"
	t.TextColor3 = Color3.fromRGB(255, 214, 60)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Visible = false
	t.Parent = gui
	return t
end

local function errandPrompt(on, id, action, object)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = on
	pr.Triggered:Connect(function()
		if id == "Board" then
			if Town.OnBoard then
				Town.OnBoard()
			end
		elseif Town.OnErrand then
			Town.OnErrand(id)
		end
	end)
	return pr
end

local function npc(id, name, subtitle, look, accent)
	local cf = spotFrame(id)
	local model, root = kit.villager(name, look)
	model.Parent = folder
	model:PivotTo(cf * CFrame.new(0, kit.TORSO_HEIGHT, 0))
	kit.nameTag(root, name:upper(), subtitle, accent, 4.6)
	spots[id] = { Anchor = root, Prompt = errandPrompt(root, id, "Talk", name), Marker = marker(root, 7.6), Kind = "Giver" }
	return cf
end

local function pickup(id, anchor, action, object)
	spots[id] = { Anchor = anchor, Prompt = errandPrompt(anchor, id, action, object), Marker = marker(anchor, 5), Kind = "Pickup" }
	spots[id].Prompt.Enabled = false
end

-- small carried / placed props --------------------------------------------------------------------------------
local function catModel(parent)
	local model = Instance.new("Model")
	model.Name = "Whiskers"
	local fur, dark = Color3.fromRGB(236, 150, 70), Color3.fromRGB(190, 104, 44)
	local function p(props)
		props.Parent = model
		props.CanCollide = false
		props.Material = props.Material or Enum.Material.SmoothPlastic
		return part(props)
	end
	local body = p({ Name = "Body", Size = Vector3.new(1.1, 1, 2), CFrame = CFrame.new(0, 0.7, 0), Color = fur })
	p({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(0, 1.35, -1.05), Color = fur })
	for _, s in ipairs({ -1, 1 }) do
		p({ Name = "Ear", Size = Vector3.new(0.3, 0.4, 0.2), CFrame = CFrame.new(s * 0.3, 1.95, -1.05) * CFrame.Angles(0, 0, math.rad(s * -15)), Color = dark })
		p({ Name = "Eye", Size = Vector3.new(0.14, 0.18, 0.05), CFrame = CFrame.new(s * 0.22, 1.42, -1.58), Color = Color3.fromRGB(40, 120, 40), Material = Enum.Material.Neon })
		for _, z in ipairs({ -0.7, 0.7 }) do
			p({ Name = "Leg", Size = Vector3.new(0.3, 0.5, 0.3), CFrame = CFrame.new(s * 0.35, 0.25, z), Color = fur })
		end
	end
	p({ Name = "Tail", Size = Vector3.new(0.22, 0.22, 1.4), CFrame = CFrame.new(0, 1.3, 1.3) * CFrame.Angles(math.rad(-50), 0, 0), Color = dark })
	p({ Name = "Stripe", Size = Vector3.new(1.12, 0.2, 0.3), CFrame = CFrame.new(0, 1.12, 0.3), Color = dark })
	model.PrimaryPart = body
	model.Parent = parent
	return model, body
end

local function looseParts(model, list)
	for _, props in ipairs(list) do
		props.Parent = model
		props.CanCollide = false
		part(props)
	end
end

local CARRY_LOOKS = {
	Flowers = function(model)
		looseParts(model, {
			{ Name = "Wrap", Size = Vector3.new(0.7, 1.2, 0.7), CFrame = CFrame.new(0, -0.3, 0), Color = Color3.fromRGB(240, 230, 200), Material = Enum.Material.Fabric },
			{ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(-0.3, 0.5, 0), Color = Color3.fromRGB(255, 120, 160) },
			{ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(0.3, 0.55, 0.1), Color = Color3.fromRGB(200, 120, 255) },
			{ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(0, 0.7, -0.25), Color = Color3.fromRGB(255, 210, 80) },
		})
	end,
	Bones = function(model)
		for i = 1, 3 do
			looseParts(model, { { Name = "Bone", Size = Vector3.new(1.8, 0.25, 0.25), CFrame = CFrame.new(0, (i - 2) * 0.3, 0) * CFrame.Angles(0, math.rad(i * 40), 0), Color = Color3.fromRGB(235, 230, 215), Material = Enum.Material.SmoothPlastic } })
		end
	end,
	Crate = function(model)
		looseParts(model, {
			{ Name = "Crate", Size = Vector3.new(1.8, 1.4, 1.4), CFrame = CFrame.new(), Color = Color3.fromRGB(170, 126, 80), Material = Enum.Material.WoodPlanks },
			{ Name = "Strap", Size = Vector3.new(1.85, 0.2, 1.45), CFrame = CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Fabric },
		})
	end,
	Arrows = function(model)
		looseParts(model, { { Name = "Quiver", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.6, 0.6), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Fabric } })
		for i = 1, 4 do
			looseParts(model, { { Name = "Arrow", Size = Vector3.new(0.08, 1.2, 0.08), CFrame = CFrame.new((i - 2.5) * 0.12, 0.9, 0), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.SmoothPlastic } })
		end
	end,
	Fish = function(model)
		looseParts(model, {
			{ Name = "FishBody", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 0.7, 0.5), CFrame = CFrame.new(), Color = Color3.fromRGB(120, 170, 220), Material = Enum.Material.SmoothPlastic },
			{ Name = "FishTail", Size = Vector3.new(0.1, 0.6, 0.5), CFrame = CFrame.new(0.8, 0, 0), Color = Color3.fromRGB(90, 140, 200), Material = Enum.Material.SmoothPlastic },
		})
	end,
	Bucket = function(model)
		looseParts(model, {
			{ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks },
			{ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.95, 0.95), CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 160, 220), Material = Enum.Material.Glass },
		})
	end,
	Parcel = function(model)
		looseParts(model, {
			{ Name = "Parcel", Size = Vector3.new(1.4, 1, 1.2), CFrame = CFrame.new(), Color = Color3.fromRGB(190, 150, 100), Material = Enum.Material.Cardboard },
			{ Name = "String", Size = Vector3.new(1.45, 1.05, 0.12), CFrame = CFrame.new(), Color = Color3.fromRGB(180, 40, 40), Material = Enum.Material.Fabric },
		})
	end,
	Boar = function(model)
		local base = part({ Name = "Platter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.6, 2.6), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = model, CanCollide = false })
		part({ Name = "Roast", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.2, 2.2), CFrame = CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(150, 80, 40), Parent = model, CanCollide = false })
		part({ Name = "Apple", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(0, 0.9, -1.1), Color = Color3.fromRGB(220, 40, 40), Parent = model, CanCollide = false })
		return base
	end,
	Keg = function(model)
		-- standing upright in your arms (a cylinder's length runs along X, so tip it onto Y)
		local keg = part({ Name = "Keg", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.6, 1.6), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks, Parent = model, CanCollide = false })
		for _, y in ipairs({ -0.6, 0.6 }) do
			part({ Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.7, 1.7), CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal, Parent = model, CanCollide = false })
		end
		return keg
	end,
	Straw = function(model)
		local bale = part({ Name = "Straw", Size = Vector3.new(2, 1.2, 1.4), Color = Color3.fromRGB(226, 196, 100), Material = Enum.Material.Grass, Parent = model, CanCollide = false })
		part({ Name = "Twine", Size = Vector3.new(0.15, 1.25, 1.45), CFrame = CFrame.new(-0.5, 0, 0), Color = Color3.fromRGB(120, 80, 40), Parent = model, CanCollide = false })
		part({ Name = "Twine", Size = Vector3.new(0.15, 1.25, 1.45), CFrame = CFrame.new(0.5, 0, 0), Color = Color3.fromRGB(120, 80, 40), Parent = model, CanCollide = false })
		return bale
	end,
	Cat = function(model)
		local m, body = catModel(model)
		m:PivotTo(CFrame.new(0, -0.7, 0) * CFrame.Angles(0, math.rad(90), 0)) -- lying across your arms
		return body
	end,
}

-- hold `kind` in front of the local player's chest (nil = nothing); welded, so it walks with you
local function setCarry(kind)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = character:FindFirstChild("ErrandCarry")
	if old and old:GetAttribute("Kind") == kind then
		return
	end
	if old then
		old:Destroy()
	end
	if not kind or not CARRY_LOOKS[kind] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "ErrandCarry"
	model:SetAttribute("Kind", kind)
	-- an invisible, unrotated handle carries everything: pivoting by a rotated visual part (the platter, the keg)
	-- used to throw away its own rotation and hold it sideways
	CARRY_LOOKS[kind](model)
	local main = part({ Name = "CarryHandle", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(), Transparency = 1, CanCollide = false, Parent = model })
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			if d ~= main then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = main, d
				w.Parent = d
			end
		end
	end
	model.PrimaryPart = main
	model:PivotTo(root.CFrame * CFrame.new(0, 0.4, -1.7))
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, main
	weld.Parent = main
	model.Parent = character
end

function Town.Say(id, text)
	local spot = spots[id]
	if not spot or not text then
		return
	end
	local old = spot.Anchor:FindFirstChild("SpeechBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, if spot.Kind == "Giver" then 10 else 7, 0)
	gui.MaxDistance = 80
	gui.Adornee = spot.Anchor
	gui.Parent = spot.Anchor
	local box = Instance.new("TextLabel")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	box.BackgroundTransparency = 0.05
	box.TextColor3 = Color3.fromRGB(40, 32, 24)
	box.Font = Enum.Font.GothamMedium
	box.TextSize = 14
	box.TextWrapped = true
	box.Text = text
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = box
	task.delay(7, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

function Town.SetErrands(status)
	if not status then
		return
	end
	local active = status.Active
	local stateOf = {}
	for _, e in ipairs(status.List or {}) do
		stateOf[e.Giver] = e.State
	end
	for id, spot in pairs(spots) do
		if spot.Kind == "Giver" then
			local turnIn = active ~= nil and active.Spot == id
			local ready = active == nil and stateOf[id] == "Ready"
			spot.Marker.Visible = turnIn or ready
			spot.Marker.Text = if turnIn then "?" else "!"
			spot.Prompt.ActionText = if turnIn then active.Prompt else "Talk"
		elseif spot.Kind == "Pickup" or spot.Kind == "Cat" then
			local need = active ~= nil and active.Spot == id
			spot.Prompt.Enabled = need
			spot.Marker.Visible = need
			spot.Marker.Text = "?"
			if need then
				spot.Prompt.ActionText = active.Prompt
			end
		end
	end
	-- the cat sits at today's hiding place only while you are looking for it
	if cat then
		local hide = active ~= nil and active.Spot ~= nil and active.Spot:sub(1, 3) == "Cat" and spots[active.Spot] ~= nil
		cat.Model.Parent = if hide then folder else nil
		if hide then
			cat.Model:PivotTo(CFrame.new(spots[active.Spot].Anchor.Position - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(40), 0))
		end
	end
	setCarry(active and active.Carry)
end

local function errands()
	-- townsfolk with errands
	npc("Mabel", "Old Mabel", "Townsfolk", { Shirt = Color3.fromRGB(150, 110, 170), Pants = Color3.fromRGB(90, 70, 100), Hair = Color3.fromRGB(220, 220, 225), Skin = Color3.fromRGB(236, 200, 170), Apron = Color3.fromRGB(240, 236, 220) }, Color3.fromRGB(190, 140, 220))
	npc("Warden", "Warden Hale", "Keeper of the Boss Field", { Shirt = Color3.fromRGB(90, 60, 50), Pants = Color3.fromRGB(50, 44, 40), Hair = Color3.fromRGB(60, 40, 30), Hood = Color3.fromRGB(70, 50, 40), Held = "Staff", Glow = Color3.fromRGB(255, 120, 60) }, Color3.fromRGB(200, 90, 70))
	npc("Guildmaster", "Guildmaster Orin", "Guild Hall", { Shirt = Color3.fromRGB(90, 60, 130), Pants = Color3.fromRGB(50, 40, 70), Hair = Color3.fromRGB(110, 110, 120), Robe = Color3.fromRGB(100, 70, 150), Trim = Color3.fromRGB(255, 220, 120), Held = "Scroll" }, Color3.fromRGB(150, 110, 220))
	npc("Sergeant", "Sergeant Brask", "Drill sergeant", { Shirt = Color3.fromRGB(150, 50, 44), Pants = Color3.fromRGB(60, 56, 50), Hair = Color3.fromRGB(40, 30, 24), Hat = Color3.fromRGB(110, 90, 60), Held = "Hammer" }, Color3.fromRGB(220, 110, 80))
	-- the barkeep at the tavern hands out the boar and the keg (only while an errand needs them)
	local barCf = spotFrame("Tavern")
	local barModel, barRoot = kit.villager("Greta", { Shirt = Color3.fromRGB(180, 80, 60), Pants = Color3.fromRGB(70, 50, 40), Hair = Color3.fromRGB(170, 90, 40), Apron = Color3.fromRGB(245, 240, 225) })
	barModel.Parent = folder
	barModel:PivotTo(barCf * CFrame.new(0, kit.TORSO_HEIGHT, 0))
	kit.nameTag(barRoot, "GRETA", "Barkeep, the Sleepy Griffin", Color3.fromRGB(230, 140, 90), 4.6)
	-- Greta gives errands of her own and hands out the boar and the keg
	spots.Tavern = { Anchor = barRoot, Prompt = errandPrompt(barRoot, "Tavern", "Talk", "Greta"), Marker = marker(barRoot, 7.6), Kind = "Giver" }
	for index, y in ipairs({ 1.3, 3.5 }) do
		part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = barCf * CFrame.new(3.4, y, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = if index == 1 then Color3.fromRGB(150, 100, 60) else Color3.fromRGB(140, 92, 54), Material = Enum.Material.WoodPlanks })
	end
	npc("Elder", "Elder Thessaly", "Keeper of the Wishing Tree", { Shirt = Color3.fromRGB(70, 130, 110), Pants = Color3.fromRGB(50, 80, 70), Hair = Color3.fromRGB(235, 235, 240), Skin = Color3.fromRGB(230, 200, 175), Robe = Color3.fromRGB(80, 150, 120), Trim = Color3.fromRGB(200, 240, 220), Held = "Staff", Glow = Color3.fromRGB(110, 230, 200) }, Color3.fromRGB(110, 210, 170))
	npc("Courier", "Pip the Courier", "Parcels and letters", { Shirt = Color3.fromRGB(60, 110, 190), Pants = Color3.fromRGB(70, 60, 50), Hair = Color3.fromRGB(200, 120, 50), Hat = Color3.fromRGB(50, 90, 160), Held = "Scroll" }, Color3.fromRGB(110, 160, 240))
	-- small props at the new pick-up spots (their prompts only show while an errand needs them)
	local function propSpot(id, action, object, build)
		local cf = spotFrame(id)
		local anchor = build(cf)
		pickup(id, anchor, action, object)
	end
	propSpot("Flowers", "Pick flowers", "Flower bed", function(cf)
		return part({ Name = "FlowerAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 1.5, 0), Transparency = 1, CanCollide = false })
	end)
	propSpot("Shallows", "Scoop a fish", "Pond shallows", function(cf)
		part({ Name = "Net", Size = Vector3.new(0.15, 4, 0.15), CFrame = cf * CFrame.new(1.2, 1.6, 0) * CFrame.Angles(0, 0, math.rad(25)), Color = DARK_WOOD, Material = Enum.Material.Wood })
		return part({ Name = "FishBasket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1.6, 1.6), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(170, 130, 80), Material = Enum.Material.Fabric })
	end)
	propSpot("Well", "Fill the bucket", "Town well", function(cf)
		return part({ Name = "WellBucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	end)
	propSpot("Crates", "Lift a crate", "Supply crates", function(cf)
		for i = 0, 2 do
			part({ Name = "SupplyCrate", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = cf * CFrame.new((i % 2) * 2.4 - 1.2, 1.1 + (if i == 2 then 2.2 else 0), 0) * CFrame.Angles(0, math.rad(i * 8), 0), Color = Color3.fromRGB(170, 126, 80), Material = Enum.Material.WoodPlanks })
		end
		return part({ Name = "CrateAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 2, 0), Transparency = 1, CanCollide = false })
	end)
	propSpot("Arrows", "Collect arrows", "Stray arrows", function(cf)
		for i = 1, 5 do
			part({ Name = "StrayArrow", Size = Vector3.new(0.1, 1.6, 0.1), CFrame = cf * CFrame.new((i - 3) * 0.9, 0.6, (i % 2) * 0.8) * CFrame.Angles(math.rad(20 + i * 6), math.rad(i * 30), 0), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
		return part({ Name = "ArrowAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false })
	end)
	propSpot("Bones", "Gather bones", "Bone pile", function(cf)
		for i = 1, 6 do
			part({ Name = "PileBone", Size = Vector3.new(1.8, 0.3, 0.3), CFrame = cf * CFrame.new((i % 3) * 0.6 - 0.6, 0.2 + (i // 3) * 0.3, (i % 2) * 0.5) * CFrame.Angles(0, math.rad(i * 47), 0), Color = Color3.fromRGB(235, 230, 215), Material = Enum.Material.SmoothPlastic })
		end
		part({ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 0.9, 1), CFrame = cf * CFrame.new(0.9, 0.5, -0.6), Color = Color3.fromRGB(240, 236, 220), Material = Enum.Material.SmoothPlastic })
		return part({ Name = "BoneAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false })
	end)
	propSpot("CampDrop", "Drop off the crate", "Camp stores", function(cf)
		part({ Name = "StoresTarp", Size = Vector3.new(5, 0.2, 4), CFrame = cf * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(110, 120, 80), Material = Enum.Material.Fabric })
		return part({ Name = "StoresAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 1, 0), Transparency = 1, CanCollide = false })
	end)
	-- the hay pile beside the pet park
	local hayCf = spotFrame("Hay")
	local hay = part({ Name = "HayPile", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = hayCf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(226, 196, 100), Material = Enum.Material.Grass })
	part({ Name = "HayBale", Size = Vector3.new(3, 1.8, 2), CFrame = hayCf * CFrame.new(3.8, 0.9, 1.4) * CFrame.Angles(0, math.rad(20), 0), Color = Color3.fromRGB(214, 184, 90), Material = Enum.Material.Grass })
	part({ Name = "Pitchfork", Size = Vector3.new(0.2, 5, 0.2), CFrame = hayCf * CFrame.new(-2.8, 2.4, 0.4) * CFrame.Angles(0, 0, math.rad(18)), Color = WOOD, Material = Enum.Material.Wood })
	pickup("Hay", hay, "Grab straw", "Hay pile")
	-- the offering stone on the Boss Field
	local altarCf = spotFrame("Altar")
	local altar = part({ Name = "OfferingStone", Size = Vector3.new(7, 2.4, 4.4), CFrame = altarCf * CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(96, 88, 84), Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Brazier", Size = Vector3.new(1, 3.4, 1), CFrame = altarCf * CFrame.new(side * 5, 1.7, 0), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Metal })
		local fire = part({ Name = "Fire", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.4, 1.2), CFrame = altarCf * CFrame.new(side * 5, 3.9, 0), Color = Color3.fromRGB(255, 130, 40), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = fire, Phase = side * 2, Base = 0.1, Amount = 0.25 })
	end
	tag(altar, "OFFERING STONE", "Feed the beasts", Color3.fromRGB(255, 150, 90))
	pickup("Altar", altar, "Make the offering", "Offering stone")
	spots.Altar.Marker.Parent.StudsOffset = Vector3.new(0, 8, 0)
	-- the cat's hiding places: an invisible anchor at each, the cat itself moves to today's
	for n = 1, #ErrandConfig.CatHints do
		local id = "Cat" .. n
		local anchor = part({ Name = id, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(spotPos(id) + Vector3.new(0, 0.6, 0)), Transparency = 1, CanCollide = false })
		spots[id] = { Anchor = anchor, Prompt = errandPrompt(anchor, id, "Pick up Whiskers", "Whiskers"), Marker = marker(anchor, 3.4), Kind = "Cat" }
		spots[id].Prompt.Enabled = false
	end
	local model = catModel(nil)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	cat = { Model = model }
	-- the notice board opens the errand list
	local boardFace = folder:FindFirstChild("NoticeBoard")
	if boardFace then
		spots.Board = { Anchor = boardFace, Prompt = errandPrompt(boardFace, "Board", "Read errands", "Notice Board"), Marker = marker(boardFace, 5), Kind = "Board" }
	end
end

-- Places that open a screen (2026-11-23, owner: "a location for the dungeons outside of the town, a spot for the guild,
-- for expeditions"): the Dungeon Gate west of the Wishing Grove, the Expedition Camp outside the town wall (south-east),
-- the guild board at the Guild Hall. Town.OnPlace(id) is set by Main ("DungeonGate" | "ExpeditionCamp" | "GuildBoard").
Town.OnPlace = nil

local function placePrompt(on, id, action, object)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = on
	pr.Triggered:Connect(function()
		if Town.OnPlace then
			Town.OnPlace(id)
		end
	end)
	spots[id] = { Anchor = on, Prompt = pr, Kind = "Place" }
	return pr
end

local function path(from, to, width)
	local mid = (from + to) / 2
	part({ Name = "Path", Size = Vector3.new(width or 9, 0.3, (to - from).Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), to + Vector3.new(0, 0.15, 0)), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
end

local function torch(position)
	part({ Name = "TorchPost", Size = Vector3.new(0.6, 6, 0.6), Position = position + Vector3.new(0, 3, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	local flame = part({ Name = "TorchFlame", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.5, 1.2), Position = position + Vector3.new(0, 6.5, 0), Color = Color3.fromRGB(255, 150, 50), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Parent = flame
	table.insert(pulsers, { Part = flame, Phase = position.X % 6, Base = 0.05, Amount = 0.2 })
end

-- the Dungeon Gate: a rocky hill with a glowing portal, west of the Wishing Grove, at the end of a path out of town
local function dungeonGate()
	local at = spotPos("DungeonGate")
	local toTown = (Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z) - at).Unit
	-- a path from the Market to the cave mouth (it stays north of the battle lots)
	local mx, mz = World.DistrictPoint("Market")
	local market = Vector3.new(mx, 0, mz)
	path(market + (at - market).Unit * (World.Districts.Market.Size - 4), at + toTown * 12, 9)
	local cf = CFrame.lookAt(at, at + toTown) -- front (-Z) faces the town
	disc(at, 30, 0.3, 0, Color3.fromRGB(96, 88, 82), Enum.Material.Ground)
	-- the hill: a few big rocks behind and around the mouth
	for index, r in ipairs({ { 0, 12, 26, 18, 16 }, { -15, 8, 14, 13, 14 }, { 15, 8, 14, 13, 14 }, { -9, 16, 12, 9, 10 }, { 10, 18, 12, 8, 11 } }) do
		part({ Name = "HillRock", Shape = Enum.PartType.Ball, Size = Vector3.new(r[3], r[3], r[3]) * 1.3, CFrame = cf * CFrame.new(r[1], r[4] * 0.35, r[2] + 12), Color = Color3.fromRGB(92 + index * 4, 86 + index * 3, 84), Material = Enum.Material.Slate })
	end
	-- the stone frame and the portal
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "GatePillar", Size = Vector3.new(2.6, 14, 2.6), CFrame = cf * CFrame.new(side * 6.5, 7, 2), Color = Color3.fromRGB(70, 66, 76), Material = Enum.Material.Basalt })
		torch((cf * CFrame.new(side * 10, 0, -2)).Position)
	end
	local lintel = part({ Name = "GateLintel", Size = Vector3.new(16.5, 3, 3.2), CFrame = cf * CFrame.new(0, 15, 2), Color = Color3.fromRGB(60, 56, 66), Material = Enum.Material.Basalt })
	sign(lintel, Enum.NormalId.Front, "DUNGEONS", Color3.fromRGB(200, 160, 255))
	local portal = part({ Name = "DungeonPortal", Size = Vector3.new(10.4, 13, 0.6), CFrame = cf * CFrame.new(0, 6.6, 2.4), Color = Color3.fromRGB(110, 50, 200), Material = Enum.Material.Neon, Transparency = 0.25 })
	table.insert(pulsers, { Part = portal, Phase = 0, Base = 0.2, Amount = 0.2 })
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(Color3.fromRGB(190, 140, 255), Color3.fromRGB(90, 40, 180))
	swirl.LightEmission = 1
	swirl.Rate = 14
	swirl.Lifetime = NumberRange.new(1.2, 2)
	swirl.Speed = NumberRange.new(1, 2.5)
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Parent = portal
	tag(portal, "DUNGEON GATE", "Crypt, Foundry, Abyss, Spire", Color3.fromRGB(200, 160, 255), 11.5)
	placePrompt(portal, "DungeonGate", "Enter dungeons", "Dungeon Gate")
	-- a few bones and a warning sign by the path
	local warn = part({ Name = "WarningSign", Size = Vector3.new(5, 2.4, 0.3), CFrame = cf * CFrame.new(-9, 3.4, -12) * CFrame.Angles(0, math.rad(20), 0), Color = Color3.fromRGB(170, 140, 100), Material = Enum.Material.WoodPlanks })
	sign(warn, Enum.NormalId.Front, "Daily keys only!", Color3.fromRGB(70, 30, 20))
	part({ Name = "WarningPost", Size = Vector3.new(0.5, 3, 0.5), CFrame = cf * CFrame.new(-9, 1.5, -12), Color = DARK_WOOD, Material = Enum.Material.Wood })
	for index = 1, 3 do
		part({ Name = "Bone", Size = Vector3.new(0.4, 0.4, 2), CFrame = cf * CFrame.new(6 + index, 0.4, -8 - index) * CFrame.Angles(0, math.rad(index * 50), 0), Color = Color3.fromRGB(235, 230, 215), Material = Enum.Material.SmoothPlastic })
	end
end

-- the Expedition Camp: tents, a map table and a loaded cart outside the town wall, on a path off the ring road
local function expeditionCamp()
	local at = spotPos("ExpeditionCamp")
	-- outside the main gate: a path from the gate road to the camp
	local gate = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z + World.TOWN_WALL.Radius + 14)
	path(gate, at + (gate - at).Unit * 12, 8)
	local cf = CFrame.lookAt(at, gate) -- front faces the road in
	disc(at, 24, 0.3, 0, Color3.fromRGB(160, 140, 100), Enum.Material.Ground)
	-- tents: a wedge roof over each side
	for _, t in ipairs({ { -12, 8, Color3.fromRGB(200, 120, 70) }, { 12, 8, Color3.fromRGB(80, 130, 170) }, { 0, 15, Color3.fromRGB(150, 170, 90) } }) do
		local tentCf = cf * CFrame.new(t[1], 0, t[2]) * CFrame.Angles(0, math.rad(t[1] * 2), 0)
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Tent", Size = Vector3.new(8, 6, 4), CFrame = tentCf * CFrame.new(side * 2, 3, 0) * CFrame.Angles(0, math.rad(side * -90), 0), Color = t[3], Material = Enum.Material.Fabric }, "WedgePart")
		end
	end
	-- the map table in the middle: you plan expeditions here
	local tableCf = cf * CFrame.new(0, 0, -2)
	local top = part({ Name = "MapTable", Size = Vector3.new(7, 0.5, 4.4), CFrame = tableCf * CFrame.new(0, 3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, c in ipairs({ { -3, -1.8 }, { 3, -1.8 }, { -3, 1.8 }, { 3, 1.8 } }) do
		part({ Name = "TableLeg", Size = Vector3.new(0.4, 3, 0.4), CFrame = tableCf * CFrame.new(c[1], 1.5, c[2]), Color = DARK_WOOD, Material = Enum.Material.Wood })
	end
	part({ Name = "Map", Size = Vector3.new(5.6, 0.05, 3.4), CFrame = tableCf * CFrame.new(0, 3.28, 0) * CFrame.Angles(0, math.rad(4), 0), Color = Color3.fromRGB(236, 220, 170), Material = Enum.Material.SmoothPlastic })
	part({ Name = "MapPin", Size = Vector3.new(0.3, 0.7, 0.3), CFrame = tableCf * CFrame.new(1.2, 3.6, 0.6), Color = Color3.fromRGB(220, 50, 50), Material = Enum.Material.Neon })
	tag(top, "EXPEDITION CAMP", "Send your party out for loot", Color3.fromRGB(255, 210, 130))
	placePrompt(top, "ExpeditionCamp", "Plan an expedition", "Expedition Camp")
	-- a cart with crates and a flag
	local cartCf = cf * CFrame.new(-14, 0, -6) * CFrame.Angles(0, math.rad(30), 0)
	part({ Name = "CartBed", Size = Vector3.new(4, 0.6, 7), CFrame = cartCf * CFrame.new(0, 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, z in ipairs({ -2.4, 2.4 }) do
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.6, 2.6), CFrame = cartCf * CFrame.new(side * 2.2, 1.3, z), Color = DARK_WOOD, Material = Enum.Material.Wood })
		end
	end
	for index = 1, 2 do
		part({ Name = "Crate", Size = Vector3.new(2, 2, 2), CFrame = cartCf * CFrame.new(0, 3.3, index * 2.4 - 3.6), Color = Color3.fromRGB(170, 126, 80), Material = Enum.Material.WoodPlanks })
	end
	part({ Name = "FlagPole", Size = Vector3.new(0.4, 12, 0.4), CFrame = cf * CFrame.new(9, 6, -6), Color = DARK_WOOD, Material = Enum.Material.Wood })
	part({ Name = "Flag", Size = Vector3.new(0.1, 2.6, 4), CFrame = cf * CFrame.new(9, 10.6, -4), Color = Color3.fromRGB(70, 140, 200), Material = Enum.Material.Fabric })
	torch((cf * CFrame.new(-5, 0, -8)).Position)
	torch((cf * CFrame.new(5, 0, -8)).Position)
end

-- the guild board beside the Guild Hall door (Guildmaster Orin stands at the other side)
local function guildBoard()
	local cf = spotFrame("GuildBoard")
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.6, 7, 0.6), CFrame = cf * CFrame.new(side * 3.2, 3.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	end
	local face = part({ Name = "GuildBoard", Size = Vector3.new(7, 4.4, 0.4), CFrame = cf * CFrame.new(0, 4.6, 0), Color = Color3.fromRGB(90, 60, 130), Material = Enum.Material.WoodPlanks })
	sign(face, Enum.NormalId.Front, "GUILD", Color3.fromRGB(255, 220, 120))
	tag(face, "GUILD BOARD", "Join or run a guild", Color3.fromRGB(190, 150, 255))
	placePrompt(face, "GuildBoard", "Open guild", "Guild Board")
end

local function places()
	dungeonGate()
	expeditionCamp()
	guildBoard()
	-- the training dummy and the fishing dock (built with their districts) get their prompts here
	for _, d in ipairs(folder:GetDescendants()) do
		local id = d:GetAttribute("PlaceId")
		if id == "Dummy" then
			placePrompt(d, "Dummy", "Test your build", "Training Dummy")
		elseif id == "Pond" then
			placePrompt(d, "Pond", "Fish", "Fishing Pond")
		elseif id == "PetPark" then
			placePrompt(d, "PetPark", "Play with your pet", "Pet Park")
		elseif id == "Ring" then
			placePrompt(d, "Ring", "Spar", "Sparring Ring")
		end
	end
	-- hidden relics: small glowing crystals; found ones disappear (Town.SetRelics)
	local n = 1
	while World.TownSpots["Relic" .. n] do
		local id = "Relic" .. n
		local at = spotPos(id)
		local crystal = part({ Name = id, Size = Vector3.new(0.9, 1.8, 0.9), CFrame = CFrame.new(at + Vector3.new(0, 1.3, 0)) * CFrame.Angles(math.rad(12), math.rad(n * 37), math.rad(8)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.1 })
		table.insert(pulsers, { Part = crystal, Phase = n, Base = 0.1, Amount = 0.3 })
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(120, 230, 255)
		light.Parent = crystal
		local pr = placePrompt(crystal, id, "Pick up", "Glowing relic")
		pr.MaxActivationDistance = 10
		n += 1
	end
end

-- hide the relics this player has already found (found = { [relicId] = true })
function Town.SetRelics(found)
	for id, spot in pairs(spots) do
		if id:sub(1, 5) == "Relic" then
			-- taken ones leave the world (the glow pulse would keep a see-through one visible)
			local taken = found and found[id] == true
			spot.Anchor.Parent = if taken then nil else folder
		end
	end
end

-- the bobber on the pond while you fish: "wait" floats it, "bite" dunks it, nil hides it
function Town.Bobber(mode)
	local bob
	for _, d in ipairs(folder:GetDescendants()) do
		if d:GetAttribute("Bobber") then
			bob = d
			break
		end
	end
	if not bob then
		return
	end
	local home = bob:GetAttribute("Home") or bob.Position
	bob:SetAttribute("Home", home)
	bob.Transparency = if mode then 0 else 1
	bob.Position = if mode == "bite" then home - Vector3.new(0, 0.55, 0) else home
end

function Town.Build(parentFolder, hubPulsers, hubKit)
	folder = Instance.new("Folder")
	folder.Name = "Town"
	folder.Parent = parentFolder
	pulsers = hubPulsers or {}
	kit = hubKit
	roads()
	housing()
	grove()
	petArea()
	training()
	guild()
	market()
	bossField()
	townWall()
	greenery()
	if kit then
		errands()
	end
	places()
	return folder
end

return Town
