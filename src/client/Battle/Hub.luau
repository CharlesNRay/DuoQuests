--[[
	Hub (ModuleScript): the town plaza in the middle of the world, built on each client.

	A big cobbled circle (World.PLAZA) with a fountain, lamp posts, trees and benches, wandering
	townsfolk, and the places you come here for:

	  Merchant   NPC: sell gear
	  Blacksmith NPC: upgrade gear
	  Map board, Rankings board, Daily gift chest
	  Roads running north between the player lots, and a marker on every lot nobody has taken

	  Hub.Build(handlers)       handlers = { Map, Ranks, Daily, Merchant, Blacksmith } (all functions)
	  Hub.SetDailyReady(bool)
	  Hub.SetLots(taken)        taken = { [slot] = true }: lots without a party get an "Open lot" marker
	  Hub.Update(dt)            animate the townsfolk and the fountain (called every frame by Main)

	Positions come from shared/World.luau, which the server also uses for its shop-distance check.
	Everything is client-side Parts, so it costs the server nothing. Props that face somewhere are
	built around the origin and then moved with PivotTo, with their front (-Z) toward the plaza centre.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))

local Hub = {}

local folder
local lotFolder
local chestPrompt
local walkers = {}
local waterRings = {}
local clock = 0

local STONE = Color3.fromRGB(168, 160, 146)
local STONE_DARK = Color3.fromRGB(120, 114, 104)
local WOOD = Color3.fromRGB(110, 76, 48)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- A flat disc whose top is at y + height.
local function disc(parent, centre, radius, height, y, color, material)
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(centre.X, y + height / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Cobblestone,
	})
end

local function prompt(on, action, object, handler)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = on
	pr.Triggered:Connect(function()
		handler()
	end)
	return pr
end

local function sign(on, face, text, textColor)
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
	label.TextColor3 = textColor or Color3.fromRGB(255, 236, 190)
	label.Parent = gui
end

local function nameTag(adornee, text, subtext, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 46)
	gui.StudsOffset = Vector3.new(0, height or 3.4, 0)
	gui.MaxDistance = 90
	gui.Adornee = adornee
	gui.Parent = adornee
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = text
	title.TextColor3 = color or Color3.fromRGB(255, 226, 150)
	title.TextStrokeTransparency = 0.3
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.Parent = gui
	if subtext then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 18)
		sub.Position = UDim2.fromOffset(0, 26)
		sub.BackgroundTransparency = 1
		sub.Text = subtext
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.TextStrokeTransparency = 0.4
		sub.Font = Enum.Font.GothamMedium
		sub.TextSize = 13
		sub.Parent = gui
	end
end

-- Orientation for something standing at `at`, front (-Z) toward `target`, level with the ground.
local function facing(at, target)
	return CFrame.lookAt(at, Vector3.new(target.X, at.Y, target.Z))
end

local TORSO_HEIGHT = 3.1

-- A blocky villager built around the origin (feet at y=0, front toward -Z), pivot = torso.
-- Place it with model:PivotTo(groundCFrame * CFrame.new(0, TORSO_HEIGHT, 0)).
local function villager(name, look)
	local model = Instance.new("Model")
	model.Name = name
	local skin = look.Skin or Color3.fromRGB(240, 196, 150)
	local function limb(props)
		return part(model, props)
	end
	local root = limb({ Name = "Torso", Size = Vector3.new(2, 2.2, 1), Position = Vector3.new(0, 3.1, 0), Color = look.Shirt, Material = Enum.Material.Fabric })
	limb({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), Position = Vector3.new(0, 5.05, 0), Color = skin, Material = Enum.Material.SmoothPlastic })
	limb({ Name = "Hair", Size = Vector3.new(1.8, 0.6, 1.8), Position = Vector3.new(0, 5.8, 0.1), Color = look.Hair or Color3.fromRGB(70, 46, 30), Material = Enum.Material.SmoothPlastic })
	limb({ Name = "ArmL", Size = Vector3.new(0.8, 2.2, 0.8), Position = Vector3.new(-1.45, 3.1, 0), Color = look.Shirt, Material = Enum.Material.Fabric })
	limb({ Name = "ArmR", Size = Vector3.new(0.8, 2.2, 0.8), Position = Vector3.new(1.45, 3.1, 0), Color = look.Shirt, Material = Enum.Material.Fabric })
	limb({ Name = "LegL", Size = Vector3.new(0.9, 2, 0.9), Position = Vector3.new(-0.5, 1, 0), Color = look.Pants, Material = Enum.Material.Fabric })
	limb({ Name = "LegR", Size = Vector3.new(0.9, 2, 0.9), Position = Vector3.new(0.5, 1, 0), Color = look.Pants, Material = Enum.Material.Fabric })
	if look.Hat then
		limb({ Name = "Hat", Size = Vector3.new(2.3, 0.4, 2.3), Position = Vector3.new(0, 5.95, 0), Color = look.Hat, Material = Enum.Material.Fabric })
		limb({ Name = "HatTop", Size = Vector3.new(1.4, 0.9, 1.4), Position = Vector3.new(0, 6.45, 0), Color = look.Hat, Material = Enum.Material.Fabric })
	end
	if look.Apron then
		limb({ Name = "Apron", Size = Vector3.new(1.7, 1.6, 0.2), Position = Vector3.new(0, 2.6, -0.55), Color = look.Apron, Material = Enum.Material.Fabric })
	end
	limb({ Name = "EyeL", Size = Vector3.new(0.25, 0.25, 0.1), Position = Vector3.new(-0.35, 5.15, -0.82), Color = Color3.fromRGB(30, 30, 40) })
	limb({ Name = "EyeR", Size = Vector3.new(0.25, 0.25, 0.1), Position = Vector3.new(0.35, 5.15, -0.82), Color = Color3.fromRGB(30, 30, 40) })
	model.PrimaryPart = root
	model.Parent = folder
	return model, root
end

local function lamp(position)
	part(folder, { Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), Position = position + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(46, 46, 56), Material = Enum.Material.Metal })
	local bulb = part(folder, { Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = position + Vector3.new(0, 9.6, 0), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = bulb
end

local function tree(position, scale)
	scale = scale or 1
	part(folder, { Name = "Trunk", Size = Vector3.new(1.6 * scale, 6 * scale, 1.6 * scale), Position = position + Vector3.new(0, 3 * scale, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(folder, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9 * scale, 8 * scale, 9 * scale), Position = position + Vector3.new(0, 8.5 * scale, 0), Color = Color3.fromRGB(70, 140, 70), Material = Enum.Material.Grass, CanCollide = false })
	part(folder, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(6 * scale, 6 * scale, 6 * scale), Position = position + Vector3.new(2 * scale, 11 * scale, 1 * scale), Color = Color3.fromRGB(86, 160, 80), Material = Enum.Material.Grass, CanCollide = false })
end

local function bench(position, lookAt)
	local m = Instance.new("Model")
	m.Name = "Bench"
	local seat = part(m, { Size = Vector3.new(6, 0.5, 1.8), Position = Vector3.new(0, 1.6, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(m, { Size = Vector3.new(6, 1.6, 0.4), Position = Vector3.new(0, 2.6, 0.8), Color = WOOD, Material = Enum.Material.Wood })
	part(m, { Size = Vector3.new(0.5, 1.6, 1.6), Position = Vector3.new(-2.6, 0.8, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	part(m, { Size = Vector3.new(0.5, 1.6, 1.6), Position = Vector3.new(2.6, 0.8, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	m.PrimaryPart = seat
	m.Parent = folder
	m:PivotTo(facing(position, lookAt) * CFrame.new(0, 1.6, 0))
end

local function board(position, lookAt, title, color, action, handler)
	local model = Instance.new("Model")
	model.Name = title
	part(model, { Name = "PostL", Size = Vector3.new(0.8, 8, 0.8), Position = Vector3.new(-3.6, 4, 0.4), Color = WOOD, Material = Enum.Material.Wood })
	part(model, { Name = "PostR", Size = Vector3.new(0.8, 8, 0.8), Position = Vector3.new(3.6, 4, 0.4), Color = WOOD, Material = Enum.Material.Wood })
	local face = part(model, { Name = "Face", Size = Vector3.new(9, 5, 0.6), Position = Vector3.new(0, 6, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	sign(face, Enum.NormalId.Front, title)
	sign(face, Enum.NormalId.Back, title)
	prompt(face, action, title, handler)
	model.PrimaryPart = face
	model.Parent = folder
	model:PivotTo(facing(position, lookAt) * CFrame.new(0, 6, 0))
end

local function pointOf(name)
	local x, z = World.PlazaPoint(name)
	return Vector3.new(x, 0.2, z)
end

local function fountain(centre)
	disc(folder, centre, 9, 1.4, 0.2, STONE_DARK)
	disc(folder, centre, 7.6, 0.3, 1.6, Color3.fromRGB(70, 150, 200), Enum.Material.Glass)
	part(folder, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 2.4, 2.4), CFrame = CFrame.new(centre.X, 4, centre.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Marble })
	disc(folder, centre + Vector3.new(0, 4.5, 0), 3.6, 0.7, 1, STONE, Enum.Material.Marble)
	local spout = part(folder, { Name = "Spout", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = centre + Vector3.new(0, 7.4, 0), Color = Color3.fromRGB(150, 210, 245), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	table.insert(waterRings, spout)
	for index = 1, 4 do
		local a = math.rad(index * 90 + 45)
		part(folder, { Name = "Jet", Size = Vector3.new(0.5, 3, 0.5), Position = centre + Vector3.new(math.sin(a) * 2.6, 5.4, math.cos(a) * 2.6), Color = Color3.fromRGB(150, 210, 245), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
	end
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Color = Color3.fromRGB(150, 210, 245)
	light.Brightness = 0.6
	light.Parent = spout
end

-- A market stall: the NPC stands behind a counter under an awning, all facing the plaza centre.
local function shopNpc(name, subtitle, spotName, look, action, handler, centre, accent)
	local at = pointOf(spotName)
	local cf = facing(at, centre)
	local model, root = villager(name, look)
	model:PivotTo(cf * CFrame.new(0, TORSO_HEIGHT, 0))
	nameTag(root, name:upper(), subtitle, accent, 4.6)
	prompt(root, action, name, handler)
	part(folder, { Name = "Counter", Size = Vector3.new(7, 2.6, 2), CFrame = cf * CFrame.new(0, 1.3, -3), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(folder, { Name = "CounterTop", Size = Vector3.new(7.6, 0.4, 2.6), CFrame = cf * CFrame.new(0, 2.8, -3), Color = Color3.fromRGB(150, 104, 64), Material = Enum.Material.Wood })
	part(folder, { Name = "StallPostL", Size = Vector3.new(0.6, 10, 0.6), CFrame = cf * CFrame.new(-4.6, 5, 2.4), Color = WOOD, Material = Enum.Material.Wood })
	part(folder, { Name = "StallPostR", Size = Vector3.new(0.6, 10, 0.6), CFrame = cf * CFrame.new(4.6, 5, 2.4), Color = WOOD, Material = Enum.Material.Wood })
	part(folder, { Name = "StallPostFL", Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(-4.6, 4.5, -4.2), Color = WOOD, Material = Enum.Material.Wood })
	part(folder, { Name = "StallPostFR", Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(4.6, 4.5, -4.2), Color = WOOD, Material = Enum.Material.Wood })
	part(folder, { Name = "Awning", Size = Vector3.new(11, 0.6, 8), CFrame = cf * CFrame.new(0, 9.6, -0.9) * CFrame.Angles(math.rad(-6), 0, 0), Color = accent or Color3.fromRGB(190, 70, 60), Material = Enum.Material.Fabric })
	part(folder, { Name = "Rug", Size = Vector3.new(9, 0.1, 9), CFrame = cf * CFrame.new(0, 0.05, -1), Color = Color3.fromRGB(110, 60, 60), Material = Enum.Material.Fabric, CanCollide = false })
	return cf
end

function Hub.Build(handlers)
	if folder then
		folder:Destroy()
	end
	table.clear(walkers)
	table.clear(waterRings)
	folder = Instance.new("Folder")
	folder.Name = "DuoQuestPlaza"
	folder.Parent = workspace

	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local R = World.PLAZA.Radius

	-- ground: a cobble disc, a lighter ring, an inner circle
	disc(folder, centre, R + 1.5, 0.3, 0, STONE_DARK, Enum.Material.Slate).Name = "Rim"
	disc(folder, centre, R, 0.4, 0, STONE)
	disc(folder, centre, R - 3, 0.45, 0, Color3.fromRGB(184, 176, 160))
	disc(folder, centre, 22, 0.5, 0, Color3.fromRGB(150, 140, 126))
	disc(folder, centre, 20.5, 0.55, 0, Color3.fromRGB(196, 188, 170))

	fountain(centre)

	-- lamps and trees around the edge, benches in the inner ring
	for index = 0, 11 do
		local a = math.rad(index * 30 + 15)
		lamp(centre + Vector3.new(math.sin(a) * (R - 3), 0.4, -math.cos(a) * (R - 3)))
	end
	for index = 0, 9 do
		local a = math.rad(index * 36 + 8)
		tree(centre + Vector3.new(math.sin(a) * (R + 7), 0, -math.cos(a) * (R + 7)), 0.9 + (index % 3) * 0.15)
	end
	for _, angle in ipairs({ 0, 72, 144, 216, 288 }) do
		local a = math.rad(angle + 36)
		bench(centre + Vector3.new(math.sin(a) * 15, 0.6, -math.cos(a) * 15), centre)
	end

	-- shops
	shopNpc("Merchant", "Sell gear", "Merchant", { Shirt = Color3.fromRGB(70, 130, 80), Pants = Color3.fromRGB(80, 64, 50), Hat = Color3.fromRGB(150, 110, 50), Apron = Color3.fromRGB(235, 225, 190) }, "Sell gear", handlers.Merchant, centre, Color3.fromRGB(70, 150, 90))
	local forgeCf = shopNpc("Blacksmith", "Upgrade gear", "Blacksmith", { Shirt = Color3.fromRGB(110, 60, 52), Pants = Color3.fromRGB(50, 50, 58), Hair = Color3.fromRGB(30, 24, 20), Apron = Color3.fromRGB(60, 60, 66) }, "Upgrade gear", handlers.Blacksmith, centre, Color3.fromRGB(200, 100, 60))
	part(folder, { Name = "Anvil", Size = Vector3.new(1.4, 1.6, 2.6), CFrame = forgeCf * CFrame.new(6.4, 1, -2), Color = Color3.fromRGB(56, 56, 64), Material = Enum.Material.Metal })
	part(folder, { Name = "Forge", Size = Vector3.new(3, 2.4, 3), CFrame = forgeCf * CFrame.new(-7, 1.3, 0.5), Color = Color3.fromRGB(90, 84, 80), Material = Enum.Material.Slate })
	local coals = part(folder, { Name = "Coals", Size = Vector3.new(2.2, 0.4, 2.2), CFrame = forgeCf * CFrame.new(-7, 2.6, 0.5), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon })
	local fire = Instance.new("PointLight")
	fire.Color = Color3.fromRGB(255, 140, 60)
	fire.Range = 16
	fire.Parent = coals

	-- boards and the daily chest
	board(pointOf("Map"), centre, "WORLD MAP", Color3.fromRGB(40, 90, 150), "Open map", handlers.Map)
	board(pointOf("Rankings"), centre, "RANKINGS", Color3.fromRGB(110, 50, 140), "View leaderboards", handlers.Ranks)
	local chest = Instance.new("Model")
	chest.Name = "Daily Gift"
	local base = part(chest, { Name = "Base", Size = Vector3.new(4, 2.4, 3), Position = Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(150, 100, 56), Material = Enum.Material.Wood })
	part(chest, { Name = "Lid", Size = Vector3.new(4.2, 1, 3.2), Position = Vector3.new(0, 2.9, 0), Color = Color3.fromRGB(255, 196, 70), Material = Enum.Material.Metal })
	chest.PrimaryPart = base
	chest.Parent = folder
	chest:PivotTo(facing(pointOf("Daily"), centre) * CFrame.new(0, 1.2, 0))
	chestPrompt = prompt(base, "Daily gift", "Daily Login", handlers.Daily)
	nameTag(base, "DAILY GIFT", nil, Color3.fromRGB(255, 210, 90), 3.4)

	-- townsfolk wandering the plaza
	local looks = {
		{ Shirt = Color3.fromRGB(200, 90, 90), Pants = Color3.fromRGB(60, 60, 90) },
		{ Shirt = Color3.fromRGB(90, 120, 200), Pants = Color3.fromRGB(70, 60, 50), Hat = Color3.fromRGB(200, 170, 70) },
		{ Shirt = Color3.fromRGB(220, 190, 90), Pants = Color3.fromRGB(80, 80, 90), Hair = Color3.fromRGB(200, 160, 80) },
		{ Shirt = Color3.fromRGB(150, 90, 180), Pants = Color3.fromRGB(50, 50, 60) },
		{ Shirt = Color3.fromRGB(90, 170, 150), Pants = Color3.fromRGB(110, 90, 70), Hat = Color3.fromRGB(70, 110, 100) },
	}
	local names = { "Townsfolk", "Traveller", "Villager", "Bard", "Child" }
	for index, look in ipairs(looks) do
		local a = math.rad(index * 72 + 20)
		local start = centre + Vector3.new(math.sin(a) * 26, 0.4, -math.cos(a) * 26)
		local model = villager(names[index], look)
		model:PivotTo(CFrame.new(start + Vector3.new(0, TORSO_HEIGHT, 0)))
		walkers[index] = { Model = model, Pos = start, Target = start, Wait = math.random() * 3, Speed = 4 + math.random() * 2, Phase = math.random() * 6 }
	end

	-- roads between the lot columns, running north from the plaza, plus a cross road per row
	lotFolder = Instance.new("Folder")
	lotFolder.Name = "Lots"
	lotFolder.Parent = folder
	local lastRow = (World.MAX_LOTS - 1) // World.PER_ROW
	local roadEnd = World.FIRST_ROW_Z - lastRow * World.SPACING_Z - 20
	local roadStart = World.PLAZA.Z - R + 2
	for col = 0, World.PER_ROW do
		local x = (col - World.PER_ROW / 2) * World.SPACING_X
		part(folder, { Name = "Road", Size = Vector3.new(10, 0.3, roadStart - roadEnd), Position = Vector3.new(x, 0.15, (roadStart + roadEnd) / 2), Color = Color3.fromRGB(150, 138, 116), Material = Enum.Material.Pebble, CanCollide = false })
	end
	for row = 0, lastRow do
		local z = World.FIRST_ROW_Z - row * World.SPACING_Z + World.SPACING_Z / 2
		part(folder, { Name = "CrossRoad", Size = Vector3.new(World.PER_ROW * World.SPACING_X, 0.3, 8), Position = Vector3.new(0, 0.16, z), Color = Color3.fromRGB(150, 138, 116), Material = Enum.Material.Pebble, CanCollide = false })
	end
end

function Hub.SetDailyReady(ready)
	if chestPrompt then
		chestPrompt.ObjectText = if ready then "Daily Login - ready!" else "Daily Login"
	end
end

-- Mark every lot nobody has taken, so the world looks ready for more players.
function Hub.SetLots(taken)
	if not lotFolder then
		return
	end
	for _, child in ipairs(lotFolder:GetChildren()) do
		child:Destroy()
	end
	for slot = 1, World.MAX_LOTS do
		if not taken[slot] then
			local x, _, z = World.ArenaOrigin(slot)
			part(lotFolder, { Name = "OpenLot", Size = Vector3.new(World.ARENA_WIDTH, 0.2, World.ARENA_DEPTH), Position = Vector3.new(x, 0.12, z), Color = Color3.fromRGB(120, 168, 104), Material = Enum.Material.Grass, CanCollide = false })
			local post = part(lotFolder, { Name = "LotSign", Size = Vector3.new(7, 3.4, 0.4), Position = Vector3.new(x, 5, z + World.ARENA_DEPTH / 2 + 2), Color = Color3.fromRGB(60, 52, 40), Material = Enum.Material.Wood })
			part(lotFolder, { Name = "LotPost", Size = Vector3.new(0.6, 5, 0.6), Position = Vector3.new(x, 2.5, z + World.ARENA_DEPTH / 2 + 2), Color = WOOD, Material = Enum.Material.Wood })
			sign(post, Enum.NormalId.Back, ("LOT %d\nopen"):format(slot), Color3.fromRGB(240, 230, 190))
			sign(post, Enum.NormalId.Front, ("LOT %d\nopen"):format(slot), Color3.fromRGB(240, 230, 190))
		end
	end
end

function Hub.Update(dt)
	clock += dt
	for _, ring in ipairs(waterRings) do
		ring.Size = Vector3.new(2.4, 2.4, 2.4) * (1 + math.sin(clock * 3) * 0.08)
	end
	local reach = World.PLAZA.Radius - 8
	for _, w in ipairs(walkers) do
		if w.Model.Parent then
			if w.Wait > 0 then
				w.Wait -= dt
				if w.Wait <= 0 then
					local a = math.random() * math.pi * 2
					local r = 14 + math.random() * (reach - 14)
					w.Target = Vector3.new(World.PLAZA.X + math.sin(a) * r, 0.4, World.PLAZA.Z - math.cos(a) * r)
				end
			else
				local delta = w.Target - w.Pos
				delta = Vector3.new(delta.X, 0, delta.Z)
				if delta.Magnitude < 0.6 then
					w.Wait = 2 + math.random() * 5
				else
					local dir = delta.Unit
					w.Pos += dir * math.min(delta.Magnitude, w.Speed * dt)
					w.Phase += dt * 9
					local at = w.Pos + Vector3.new(0, TORSO_HEIGHT + math.abs(math.sin(w.Phase)) * 0.25, 0)
					w.Model:PivotTo(CFrame.lookAt(at, at + dir))
				end
			end
		end
	end
end

return Hub
