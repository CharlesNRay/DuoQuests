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

local function flowerBed(position, color)
	disc(position, 2.6, 0.5, 0.2, Color3.fromRGB(110, 80, 56), Enum.Material.Ground)
	for index = 1, 6 do
		local a = index * math.pi / 3
		part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Position = position + Vector3.new(math.cos(a) * 1.5, 1.1, math.sin(a) * 1.5), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false })
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
	house(facing(cf, 27, 8), 22, 16, 13, Color3.fromRGB(230, 214, 180), Color3.fromRGB(140, 60, 44), "THE SLEEPY GRIFFIN")
	-- (the tavern sign names it; Greta the barkeep stands at its door, see errands())
	local boardCf = facing(cf, -18, 2)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.8, 8, 0.8), CFrame = boardCf * CFrame.new(side * 4.4, 4, 0.3), Color = WOOD, Material = Enum.Material.Wood })
	end
	local face = part({ Name = "NoticeBoard", Size = Vector3.new(10, 5.6, 0.5), CFrame = boardCf * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local notes = { Color3.fromRGB(245, 238, 210), Color3.fromRGB(255, 230, 170), Color3.fromRGB(235, 245, 255) }
	for index = 1, 5 do
		part({ Name = "Note", Size = Vector3.new(1.6, 2, 0.1), CFrame = boardCf * CFrame.new(-3.6 + index * 1.5, 5.2 + (index % 2) * 0.9, -0.3) * CFrame.Angles(0, 0, math.rad((index % 3 - 1) * 6)), Color = notes[index % 3 + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	tag(face, "NOTICE BOARD", "Town errands")
	-- houses and lamps round the square
	house(facing(cf, -28, 24), 16, 13, 11, Color3.fromRGB(220, 200, 170), Color3.fromRGB(90, 110, 150))
	house(facing(cf, -32, -8), 14, 12, 10, Color3.fromRGB(235, 225, 200), Color3.fromRGB(120, 140, 80))
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
	local hallCf = facing(cf, 24, 20)
	house(hallCf, 24, 17, 15, Color3.fromRGB(210, 200, 190), Color3.fromRGB(90, 60, 130), "GUILD HALL")
	for _, side in ipairs({ -1, 1 }) do
		local banner = part({ Name = "GuildBanner", Size = Vector3.new(2.4, 6, 0.2), CFrame = hallCf * CFrame.new(side * 10, 8, -8.75), Color = Color3.fromRGB(120, 70, 180), Material = Enum.Material.Fabric })
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

-- the Boss Field outside the Town Gate: trampled ground, a path from the gate, an arch and a few rocks
-- (the bosses themselves are server models at World.BossSpots)
local function bossField()
	local f = World.BossField
	local centre = Vector3.new(f.X, 0, f.Z)
	disc(centre, f.Radius, 0.3, 0, Color3.fromRGB(150, 130, 96), Enum.Material.Ground)
	local gx, gz = World.DistrictPoint("Gate")
	local from = Vector3.new(gx, 0, gz + World.Districts.Gate.Size - 2)
	local to = Vector3.new(f.X, 0, f.Z - f.Radius + 4)
	part({ Name = "FieldPath", Size = Vector3.new(10, 0.32, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.16, 0), to + Vector3.new(0, 0.16, 0)), Color = ROAD, Material = Enum.Material.Pebble, CanCollide = false })
	arch(CFrame.lookAt(to, centre) * CFrame.new(0, 0, 3), 14, "BOSS FIELD", Color3.fromRGB(150, 50, 50))
	for index = 1, 9 do
		local a = math.rad(index * 40 + 15)
		local r = f.Radius - 6 - (index % 3) * 4
		local p = centre + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if p.Z > f.Z - f.Radius + 14 or math.abs(p.X - f.X) > 16 then
			part({ Name = "Rock", Size = Vector3.new(4 + index % 3 * 2, 3 + index % 2 * 2, 4 + index % 2 * 2), CFrame = CFrame.new(p + Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(index * 7), math.rad(index * 31), 0), Color = Color3.fromRGB(110, 104, 98), Material = Enum.Material.Slate })
		end
	end
end

-- houses and trees along the ring between the districts, so the walk feels like a town
local function ringside()
	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local R = World.TOWN_RING
	local walls = { Color3.fromRGB(230, 214, 180), Color3.fromRGB(220, 200, 170), Color3.fromRGB(235, 225, 200), Color3.fromRGB(210, 190, 160) }
	local roofs = { Color3.fromRGB(140, 60, 44), Color3.fromRGB(90, 110, 150), Color3.fromRGB(120, 140, 80), Color3.fromRGB(150, 100, 60) }
	local index = 0
	for _, angle in ipairs({ 116, 128, 146, 158, 202, 214, 232, 244 }) do -- clear of the districts
		index += 1
		local a = math.rad(angle)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		-- outside the ring: a house facing the road; inside: trees
		local at = centre + dir * (R + 18)
		house(CFrame.lookAt(at, centre + dir * R), 16, 13, 11, walls[index % 4 + 1], roofs[index % 4 + 1])
		tree(centre + dir * (R - 14), 0.9 + (index % 3) * 0.12)
		lamp(centre + dir * (R + 6))
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

local CARRY_LOOKS = {
	Boar = function(model)
		local base = part({ Name = "Platter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.6, 2.6), CFrame = CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = model, CanCollide = false })
		part({ Name = "Roast", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.2, 2.2), CFrame = CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(150, 80, 40), Parent = model, CanCollide = false })
		part({ Name = "Apple", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(0, 0.9, -1.1), Color = Color3.fromRGB(220, 40, 40), Parent = model, CanCollide = false })
		return base
	end,
	Keg = function(model)
		local keg = part({ Name = "Keg", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.6, 1.6), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks, Parent = model, CanCollide = false })
		for _, x in ipairs({ -0.6, 0.6 }) do
			part({ Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.7, 1.7), CFrame = CFrame.new(0, 0, x) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal, Parent = model, CanCollide = false })
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
	local main = CARRY_LOOKS[kind](model)
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
	pickup("Tavern", barRoot, "Collect", "Greta")
	spots.Tavern.Marker.Parent.StudsOffset = Vector3.new(0, 7.6, 0)
	for index, y in ipairs({ 1.3, 3.5 }) do
		part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = barCf * CFrame.new(3.4, y, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = if index == 1 then Color3.fromRGB(150, 100, 60) else Color3.fromRGB(140, 92, 54), Material = Enum.Material.WoodPlanks })
	end
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

function Town.Build(parentFolder, hubPulsers, hubKit)
	folder = Instance.new("Folder")
	folder.Name = "Town"
	folder.Parent = parentFolder
	pulsers = hubPulsers or {}
	kit = hubKit
	roads()
	gate()
	grove()
	training()
	ringside()
	bossField()
	if kit then
		errands()
	end
	return folder
end

return Town
