--[[
	Hub (ModuleScript): the town plaza in the middle of the world, built on each client.

	A big cobbled circle (World.PLAZA) with a fountain, lamp posts, trees and benches, wandering
	townsfolk, and the places you come here for:

	  Merchant   NPC: sell gear
	  Blacksmith NPC: upgrade gear
	  Skill Trainer NPC: level skill slots
	  Pet Store NPC: eggs, pet gear, pet food
	  Rune Carver NPC: carve runes onto gear, rune pouches
	  Every stall shows what it sells (crates and coins, eggs and a cage, a training dummy, a forge, rune stones)
	  Map board, Rankings board, Daily gift chest
	  Roads running north between the player lots, and a marker on every lot nobody has taken
	  The town districts around it (Battle/Town.luau): Wishing Grove (Wishing Tree), Town Gate, Training Grounds

	  Hub.Build(handlers)       handlers = { Map, Ranks, Season, Daily, Merchant, Blacksmith, Trainer, PetStore, RuneCarver, Tree } (all functions)
	  Hub.SetDailyReady(bool)
	  Hub.SetLots(taken)        taken = { [slot] = true }: lots without a party get an "Open lot" marker
	  Hub.Update(dt)            animate the townsfolk and the fountain (called every frame by Main)

	Positions come from shared/World.luau, which the server also uses for its shop-distance check.
	Everything is client-side Parts, so it costs the server nothing. Props that face somewhere are
	built around the origin and then moved with PivotTo, with their front (-Z) toward the plaza centre.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))
local Town = require(script.Parent.Town)

local Hub = {}

local folder
local lotFolder
local chestPrompt
local walkers = {}
local waterRings = {}
local orbiters = {} -- circling lanterns around the Wishing Tree
local pulsers = {} -- glowing parts that breathe
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
	if look.Robe then
		limb({ Name = "Robe", Size = Vector3.new(2.2, 2.6, 1.3), Position = Vector3.new(0, 1.3, 0), Color = look.Robe, Material = Enum.Material.Fabric })
		limb({ Name = "RobeTrim", Size = Vector3.new(2.3, 0.3, 1.4), Position = Vector3.new(0, 0.15, 0), Color = look.Trim or look.Robe, Material = Enum.Material.Fabric })
	end
	if look.Hood then
		limb({ Name = "HoodTop", Size = Vector3.new(2.1, 0.5, 2.1), Position = Vector3.new(0, 6.0, 0.05), Color = look.Hood, Material = Enum.Material.Fabric })
		limb({ Name = "HoodBack", Size = Vector3.new(2.1, 2.0, 0.45), Position = Vector3.new(0, 5.1, 0.85), Color = look.Hood, Material = Enum.Material.Fabric })
		limb({ Name = "HoodSideL", Size = Vector3.new(0.3, 1.8, 1.8), Position = Vector3.new(-0.95, 5.1, 0.1), Color = look.Hood, Material = Enum.Material.Fabric })
		limb({ Name = "HoodSideR", Size = Vector3.new(0.3, 1.8, 1.8), Position = Vector3.new(0.95, 5.1, 0.1), Color = look.Hood, Material = Enum.Material.Fabric })
		limb({ Name = "HoodTip", Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(0, 6.45, 0.45), Color = look.Hood, Material = Enum.Material.Fabric })
	end
	if look.Held == "Hammer" then
		limb({ Name = "HammerHandle", Size = Vector3.new(0.25, 2.4, 0.25), Position = Vector3.new(1.45, 2.4, -0.7), Color = Color3.fromRGB(110, 76, 48), Material = Enum.Material.Wood })
		limb({ Name = "HammerHead", Size = Vector3.new(0.7, 0.6, 1.3), Position = Vector3.new(1.45, 3.6, -0.7), Color = Color3.fromRGB(70, 70, 78), Material = Enum.Material.Metal })
	elseif look.Held == "Staff" then
		limb({ Name = "Staff", Size = Vector3.new(0.25, 6.4, 0.25), Position = Vector3.new(1.55, 3.2, -0.6), Color = Color3.fromRGB(80, 56, 40), Material = Enum.Material.Wood })
		limb({ Name = "StaffGem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Position = Vector3.new(1.55, 6.6, -0.6), Color = look.Glow or Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon })
	elseif look.Held == "Scroll" then
		limb({ Name = "Scroll", Size = Vector3.new(0.35, 1.4, 0.35), Position = Vector3.new(1.45, 2.3, -0.7), Color = Color3.fromRGB(240, 228, 196), Material = Enum.Material.SmoothPlastic })
	elseif look.Held == "Coin" then
		limb({ Name = "CoinPurse", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(1.45, 1.9, -0.4), Color = Color3.fromRGB(150, 110, 60), Material = Enum.Material.Fabric })
	elseif look.Held == "Egg" then
		limb({ Name = "HeldEgg", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 1.0, 0.8), Position = Vector3.new(1.3, 2.4, -0.8), Color = Color3.fromRGB(250, 240, 220), Material = Enum.Material.SmoothPlastic })
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

-- The Wishing Tree: a glowing tree on a little island with a spring around it.
local function wishingTree(position, lookAt, handler)
	local K = 1.45 -- the tree is big: it is the heart of the plaza's magic
	local model = Instance.new("Model")
	model.Name = "Wishing Tree"
	model.Parent = folder
	local glow = Color3.fromRGB(70, 190, 230)
	local pink = Color3.fromRGB(230, 110, 190)
	local gold = Color3.fromRGB(255, 226, 140)
	-- a raised stone planter set into the paving, with a starlit pool around the roots
	disc(model, position, 12 * K, 1.1, 0.2, STONE_DARK, Enum.Material.Slate)
	disc(model, position, 11 * K, 0.5, 1.2, Color3.fromRGB(80, 160, 215), Enum.Material.Glass)
	disc(model, position, 4.6 * K, 1, 1.3, Color3.fromRGB(90, 130, 80), Enum.Material.Grass)
	-- glowing rune rings on the paving around it (they breathe)
	for index, r in ipairs({ 14.5 * K, 16.5 * K }) do
		local ring = disc(model, position, r, 0.12, 0.42 + index * 0.02, if index == 1 then glow else pink, Enum.Material.Neon)
		ring.Transparency = 0.55
		table.insert(pulsers, { Part = ring, Phase = index * 1.7 })
	end
	for index = 1, 8 do
		local a = math.rad(index * 45)
		local stone = part(model, { Name = "RuneStone", Size = Vector3.new(1.6, 4.5, 1.6), CFrame = CFrame.new(position + Vector3.new(math.sin(a) * 15.5 * K, 2.4, math.cos(a) * 15.5 * K)) * CFrame.Angles(0, a, math.rad(4)), Color = Color3.fromRGB(120, 120, 135), Material = Enum.Material.Slate })
		local rune = part(model, { Name = "Rune", Size = Vector3.new(0.9, 1.6, 0.1), CFrame = stone.CFrame * CFrame.new(0, 0.6, -0.85), Color = glow, Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = rune, Phase = index })
	end
	local trunk = part(model, { Name = "Trunk", Size = Vector3.new(2.8 * K, 9.5 * K, 2.8 * K), Position = position + Vector3.new(0, 5.5 * K + 1, 0), Color = Color3.fromRGB(120, 86, 76), Material = Enum.Material.Wood })
	for index = 1, 5 do
		local a = math.rad(index * 72)
		part(model, { Name = "Root", Size = Vector3.new(1 * K, 1 * K, 5 * K), CFrame = CFrame.new(position + Vector3.new(math.sin(a) * 2.8 * K, 1.8, math.cos(a) * 2.8 * K)) * CFrame.Angles(math.rad(-22), a, 0), Color = Color3.fromRGB(105, 78, 68), Material = Enum.Material.Wood })
	end
	for index = 1, 4 do -- crooked boughs
		local a = math.rad(index * 90 + 20)
		part(model, { Name = "Bough", Size = Vector3.new(1 * K, 1 * K, 7 * K), CFrame = CFrame.new(position + Vector3.new(math.sin(a) * 2.6 * K, 12 * K, math.cos(a) * 2.6 * K)) * CFrame.Angles(math.rad(-38), a, 0), Color = Color3.fromRGB(115, 82, 72), Material = Enum.Material.Wood })
	end
	local canopy = {
		{ Vector3.new(0, 15, 0), 12, glow }, { Vector3.new(5, 12.5, 2), 8, pink }, { Vector3.new(-5, 13, -1), 8.5, glow },
		{ Vector3.new(1, 19, -2), 7, pink }, { Vector3.new(-2, 11.5, 5), 6.5, pink }, { Vector3.new(3, 17, 4), 6, glow },
		{ Vector3.new(-4, 17.5, -4), 6, pink }, { Vector3.new(6, 15, -4), 5, gold },
	}
	local first
	for _, c in ipairs(canopy) do
		local size = c[2] * K
		local ball = part(model, { Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.85, size), Position = position + c[1] * K + Vector3.new(0, 0.5, 0), Color = c[3], Material = Enum.Material.SmoothPlastic, Transparency = 0.1, CanCollide = false })
		first = first or ball
		table.insert(pulsers, { Part = ball, Phase = size, Base = 0.1, Amount = 0.08 })
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 46
	light.Brightness = 0.7
	light.Parent = first
	local function emitter(parent, rate, c1, c2, size, speed, accel)
		local e = Instance.new("ParticleEmitter")
		e.Rate = rate
		e.Lifetime = NumberRange.new(3, 6)
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c1, c2)
		e.LightEmission = 1
		e.Acceleration = accel
		e.Parent = parent
		return e
	end
	emitter(first, 30, glow, pink, 0.7, 4, Vector3.new(0, 1.5, 0))
	-- falling blossoms drifting down from the canopy
	local blossoms = emitter(first, 12, Color3.fromRGB(255, 190, 230), Color3.fromRGB(255, 255, 255), 0.6, 1.5, Vector3.new(0, -2.2, 0))
	blossoms.Shape = Enum.ParticleEmitterShape.Sphere
	blossoms.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	blossoms.Lifetime = NumberRange.new(5, 8)
	-- fireflies and motes rising from the pool
	local pool = part(model, { Name = "PoolGlow", Size = Vector3.new(2, 0.2, 2), Position = position + Vector3.new(0, 1.6, 0), Transparency = 1, CanCollide = false })
	local motes = emitter(pool, 22, gold, glow, 0.45, 2.5, Vector3.new(0, 3, 0))
	motes.Shape = Enum.ParticleEmitterShape.Disc
	motes.Lifetime = NumberRange.new(4, 7)
	-- a beam of light rising from the crown
	local beam = part(model, { Name = "Beam", Size = Vector3.new(1.2, 70, 1.2), Position = position + Vector3.new(0, 24 * K + 30, 0), Color = glow, Material = Enum.Material.Neon, Transparency = 0.85, CanCollide = false })
	table.insert(pulsers, { Part = beam, Phase = 0.5, Base = 0.85, Amount = 0.1 })
	-- wish lanterns and star-orbs circling the tree
	for index = 1, 10 do
		local lantern = part(model, { Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.6, 1.3), Position = position, Color = if index % 3 == 0 then pink else gold, Material = Enum.Material.Neon, CanCollide = false })
		local lamp = Instance.new("PointLight")
		lamp.Range = 12
		lamp.Brightness = 0.6
		lamp.Color = lantern.Color
		lamp.Parent = lantern
		table.insert(orbiters, { Part = lantern, Centre = position, Radius = (9 + (index % 4) * 2.2) * K, Height = (6 + (index % 5) * 2.6) * K, Speed = (0.25 + (index % 3) * 0.08) * (if index % 2 == 0 then 1 else -1), Phase = index * 0.63 })
	end
	-- crystals hanging from the boughs
	for index = 1, 7 do
		local a = math.rad(index * 51)
		local crystal = part(model, { Name = "Crystal", Size = Vector3.new(0.7, 2, 0.7), CFrame = CFrame.new(position + Vector3.new(math.sin(a) * 7 * K, 10.5 * K, math.cos(a) * 7 * K)) * CFrame.Angles(0, a, 0), Color = if index % 2 == 0 then glow else pink, Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
		table.insert(pulsers, { Part = crystal, Phase = index * 0.9, Base = 0.2, Amount = 0.25 })
	end
	nameTag(trunk, "WISHING TREE", "Wish for pets & skills", Color3.fromRGB(160, 235, 255), 27 * K) -- above the canopy, not inside it
	prompt(trunk, "Make a wish", "Wishing Tree", handler).MaxActivationDistance = 26
	return model
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

local stallDecor -- below: what each stall sells
-- A market stall: the NPC stands behind a counter under an awning, all facing the plaza centre.
local function shopNpc(name, subtitle, spotName, look, action, handler, centre, accent)
	local at = pointOf(spotName)
	local lx, lz = World.ShopLook(spotName) -- Market stalls face the middle of the Market square
	local cf = facing(at, Vector3.new(lx, at.Y, lz))
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
	stallDecor(spotName, cf)
	return cf
end

-- What each stall sells, on and around its counter, so you can tell the shops apart from across the plaza.
function stallDecor(kind, cf)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	if kind == "Merchant" then
		-- crates, sacks and a gold pile: buys your loot, sells supplies
		for index, x in ipairs({ -6.6, -6.6, 6.6 }) do
			part(folder, { Name = "Crate", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = at(x, 1.2 + (if index == 2 then 2.4 else 0), 0.5), Color = Color3.fromRGB(160, 116, 70), Material = Enum.Material.WoodPlanks })
		end
		for _, x in ipairs({ 6.2, 7.4 }) do
			part(folder, { Name = "Sack", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 2.2, 1.8), CFrame = at(x, 1.1, -2.2), Color = Color3.fromRGB(196, 176, 130), Material = Enum.Material.Fabric })
		end
		for index = 1, 5 do
			part(folder, { Name = "Coins", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.9, 0.9), CFrame = at(-2 + index * 0.35, 3.1 + index * 0.06, -3.2) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal })
		end
		part(folder, { Name = "Scale", Size = Vector3.new(0.2, 1.6, 0.2), CFrame = at(2, 3.8, -3), Color = Color3.fromRGB(200, 170, 80), Material = Enum.Material.Metal })
		part(folder, { Name = "ScaleBeam", Size = Vector3.new(2.2, 0.15, 0.15), CFrame = at(2, 4.6, -3), Color = Color3.fromRGB(200, 170, 80), Material = Enum.Material.Metal })
		-- a sword and shield on display behind the counter
		part(folder, { Name = "DisplaySword", Size = Vector3.new(0.3, 3.4, 0.8), CFrame = at(-3, 5.4, 2.3) * CFrame.Angles(0, 0, math.rad(20)), Color = Color3.fromRGB(210, 214, 225), Material = Enum.Material.Metal })
		part(folder, { Name = "DisplayShield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6), CFrame = at(3, 5.4, 2.3) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(80, 110, 170), Material = Enum.Material.Metal })
	elseif kind == "PetStore" then
		-- eggs on the counter, a cage and a paw sign
		local eggColors = { Color3.fromRGB(250, 236, 200), Color3.fromRGB(170, 220, 255), Color3.fromRGB(255, 190, 220), Color3.fromRGB(190, 240, 170) }
		for index, c in ipairs(eggColors) do
			local egg = part(folder, { Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1.15, 0.9), CFrame = at(-2.7 + index * 1.1, 3.55, -3.1), Color = c, Material = Enum.Material.SmoothPlastic })
			part(folder, { Name = "EggSpot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = egg.CFrame * CFrame.new(0.2, 0.2, -0.33), Color = c:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.SmoothPlastic })
		end
		part(folder, { Name = "Nest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 4.8, 1.8), CFrame = at(0, 3.2, -3) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(170, 130, 80), Material = Enum.Material.Grass })
		part(folder, { Name = "CageBase", Size = Vector3.new(3, 0.3, 3), CFrame = at(-6.8, 0.15, -1), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
		part(folder, { Name = "CageTop", Size = Vector3.new(3, 0.3, 3), CFrame = at(-6.8, 3.2, -1), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
		for _, off in ipairs({ { -1.35, -1.35 }, { 1.35, -1.35 }, { -1.35, 1.35 }, { 1.35, 1.35 }, { 0, -1.35 }, { 0, 1.35 } }) do
			part(folder, { Name = "CageBar", Size = Vector3.new(0.15, 2.9, 0.15), CFrame = at(-6.8 + off[1], 1.65, -1 + off[2]), Color = Color3.fromRGB(210, 200, 170), Material = Enum.Material.Metal })
		end
		local critter = part(folder, { Name = "Critter", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.1, 1.3), CFrame = at(-6.8, 0.85, -1), Color = Color3.fromRGB(255, 180, 90), Material = Enum.Material.SmoothPlastic })
		for _, side in ipairs({ -1, 1 }) do
			part(folder, { Name = "CritterEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = critter.CFrame * CFrame.new(side * 0.25, 0.15, -0.58), Color = Color3.new(0, 0, 0) })
		end
		local paw = part(folder, { Name = "PawSign", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 0.3), CFrame = at(0, 10.8, -4.6), Color = Color3.fromRGB(255, 160, 200), Material = Enum.Material.SmoothPlastic })
		for index = -1, 1 do
			part(folder, { Name = "PawToe", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.3), CFrame = paw.CFrame * CFrame.new(index * 0.75, 1.2 - math.abs(index) * 0.25, 0), Color = Color3.fromRGB(255, 160, 200), Material = Enum.Material.SmoothPlastic })
		end
	elseif kind == "Trainer" then
		-- a training dummy, scrolls and a book: a teacher of skills
		local post = at(7, 0, -1.5)
		part(folder, { Name = "DummyPost", Size = Vector3.new(0.5, 5.4, 0.5), CFrame = post * CFrame.new(0, 2.7, 0), Color = WOOD, Material = Enum.Material.Wood })
		part(folder, { Name = "DummyBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = post * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		part(folder, { Name = "DummyArms", Size = Vector3.new(3.6, 0.4, 0.4), CFrame = post * CFrame.new(0, 4, 0), Color = WOOD, Material = Enum.Material.Wood })
		part(folder, { Name = "DummyHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = post * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(214, 190, 120), Material = Enum.Material.Fabric })
		part(folder, { Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1, 1), CFrame = post * CFrame.new(0, 3.6, -0.95) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(220, 60, 60), Material = Enum.Material.SmoothPlastic })
		for index = 1, 3 do
			part(folder, { Name = "Scroll", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.4, 0.4), CFrame = at(-2.6 + index * 0.55, 3.25, -3 + (index - 2) * 0.3) * CFrame.Angles(0, math.rad(80), 0), Color = Color3.fromRGB(240, 228, 196), Material = Enum.Material.SmoothPlastic })
		end
		part(folder, { Name = "Book", Size = Vector3.new(1.6, 0.35, 1.2), CFrame = at(1.8, 3.2, -3), Color = Color3.fromRGB(70, 90, 160), Material = Enum.Material.SmoothPlastic })
		local glyph = part(folder, { Name = "SkillGlyph", Size = Vector3.new(0.9, 0.05, 0.6), CFrame = at(1.8, 3.4, -3), Color = Color3.fromRGB(140, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(pulsers, { Part = glyph, Phase = 0.3, Base = 0.3, Amount = 0.25 })
	elseif kind == "Blacksmith" then
		-- a weapon rack beside the forge (the anvil and forge are added by Build)
		part(folder, { Name = "RackFrame", Size = Vector3.new(0.4, 4.4, 4), CFrame = at(7.6, 2.2, -4.2), Color = WOOD, Material = Enum.Material.Wood })
		for index = -1, 1 do
			part(folder, { Name = "RackBlade", Size = Vector3.new(0.25, 3.6, 0.6), CFrame = at(7.2, 2.6, -4.2 + index * 1.2), Color = Color3.fromRGB(200, 204, 214), Material = Enum.Material.Metal })
		end
		part(folder, { Name = "Ingots", Size = Vector3.new(1.6, 0.4, 0.8), CFrame = at(-1.6, 3.2, -3), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal })
	elseif kind == "RuneCarver" then
		-- glowing rune stones on the counter and a carved standing stone with motes drifting round it
		local runeColors = { Color3.fromRGB(150, 110, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 255, 190) }
		for index, c in ipairs(runeColors) do
			local stone = part(folder, { Name = "RuneStone", Size = Vector3.new(0.9, 0.35, 1.1), CFrame = at(-2.6 + index * 1.05, 3.2, -3) * CFrame.Angles(0, math.rad(index * 23), 0), Color = Color3.fromRGB(80, 78, 90), Material = Enum.Material.Slate })
			local mark = part(folder, { Name = "RuneMark", Size = Vector3.new(0.55, 0.05, 0.12), CFrame = stone.CFrame * CFrame.new(0, 0.2, 0), Color = c, Material = Enum.Material.Neon, CanCollide = false })
			part(folder, { Name = "RuneMark", Size = Vector3.new(0.12, 0.05, 0.6), CFrame = stone.CFrame * CFrame.new(0, 0.2, 0), Color = c, Material = Enum.Material.Neon, CanCollide = false })
			table.insert(pulsers, { Part = mark, Phase = index * 1.3, Base = 0.15, Amount = 0.15 })
		end
		local menhir = at(-7.4, 0, -1)
		part(folder, { Name = "Menhir", Size = Vector3.new(2.6, 8, 1.8), CFrame = menhir * CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(4)), Color = Color3.fromRGB(96, 94, 108), Material = Enum.Material.Slate })
		for index, y in ipairs({ 2.4, 4.4, 6.4 }) do
			local glow = part(folder, { Name = "MenhirRune", Size = Vector3.new(1.2, 1.2, 0.1), CFrame = menhir * CFrame.new(0, y, -0.95) * CFrame.Angles(0, 0, math.rad(45)), Color = runeColors[index], Material = Enum.Material.Neon, CanCollide = false })
			table.insert(pulsers, { Part = glow, Phase = index * 0.9, Base = 0.2, Amount = 0.2 })
		end
		for index = 1, 3 do
			local mote = part(folder, { Name = "RuneMote", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = menhir.Position, Color = runeColors[index], Material = Enum.Material.Neon, CanCollide = false })
			table.insert(orbiters, { Part = mote, Centre = menhir.Position, Radius = 2.6, Height = 3 + index, Speed = 0.8 + index * 0.2, Phase = index * 2.1 })
		end
		for _, x in ipairs({ -3.6, 3.6 }) do
			part(folder, { Name = "Candle", Size = Vector3.new(0.35, 0.8, 0.35), CFrame = at(x, 3.4, -3.4), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.SmoothPlastic })
			local flame = part(folder, { Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.45, 0.3), CFrame = at(x, 4.0, -3.4), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false })
			table.insert(pulsers, { Part = flame, Phase = x, Base = 0.1, Amount = 0.1 })
		end
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(160, 120, 255)
		light.Range = 18
		light.Brightness = 0.9
		light.Parent = folder:FindFirstChild("Menhir")
	end
end

function Hub.Build(handlers)
	if folder then
		folder:Destroy()
	end
	table.clear(walkers)
	table.clear(waterRings)
	table.clear(orbiters)
	table.clear(pulsers)
	folder = Instance.new("Folder")
	folder.Name = "DuoQuestPlaza"
	folder.Parent = workspace

	local centre = Vector3.new(World.PLAZA.X, 0, World.PLAZA.Z)
	local R = World.PLAZA.Radius

	-- ground: a cobble disc, a lighter ring, an inner circle
	disc(folder, centre, R + 1.5, 0.3, 0, STONE_DARK, Enum.Material.Slate).Name = "Rim"
	disc(folder, centre, R, 0.4, 0, STONE)
	disc(folder, centre, R - 3, 0.45, 0, Color3.fromRGB(184, 176, 160))
	disc(folder, centre, 32, 0.5, 0, Color3.fromRGB(150, 140, 126))
	disc(folder, centre, 30.5, 0.55, 0, Color3.fromRGB(196, 188, 170))

	fountain(centre)

	-- lamps and trees around the edge, benches in the inner ring
	-- between the spokes (roads leave the plaza every 45 degrees): lamps on the rim, trees just outside it
	for index = 0, 7 do
		local a = math.rad(index * 45 + 22.5)
		lamp(centre + Vector3.new(math.sin(a) * (R - 3), 0.4, -math.cos(a) * (R - 3)))
		tree(centre + Vector3.new(math.sin(a) * (R + 8), 0, -math.cos(a) * (R + 8)), 0.9 + (index % 3) * 0.15)
	end
	for _, angle in ipairs({ 0, 72, 144, 216, 288 }) do
		local a = math.rad(angle + 36)
		bench(centre + Vector3.new(math.sin(a) * 24, 0.6, -math.cos(a) * 24), centre)
	end

	-- shops
	shopNpc("Merchant", "Sell gear & supplies", "Merchant", { Shirt = Color3.fromRGB(70, 130, 80), Pants = Color3.fromRGB(80, 64, 50), Hat = Color3.fromRGB(150, 110, 50), Apron = Color3.fromRGB(235, 225, 190), Held = "Coin" }, "Sell gear", handlers.Merchant, centre, Color3.fromRGB(70, 150, 90))
	shopNpc("Pet Store", "Eggs & pet gear", "PetStore", { Shirt = Color3.fromRGB(200, 120, 160), Pants = Color3.fromRGB(70, 60, 80), Hair = Color3.fromRGB(120, 70, 40), Apron = Color3.fromRGB(250, 235, 235), Held = "Egg" }, "Browse", handlers.PetStore, centre, Color3.fromRGB(240, 140, 180))
	shopNpc("Trainer", "Level skill slots", "Trainer", { Shirt = Color3.fromRGB(70, 90, 160), Pants = Color3.fromRGB(44, 44, 70), Hair = Color3.fromRGB(200, 200, 210), Robe = Color3.fromRGB(60, 80, 150), Trim = Color3.fromRGB(230, 200, 90), Held = "Scroll" }, "Train skills", handlers.Trainer, centre, Color3.fromRGB(110, 150, 240))
	local forgeCf = shopNpc("Blacksmith", "Upgrade gear", "Blacksmith", { Shirt = Color3.fromRGB(110, 60, 52), Pants = Color3.fromRGB(50, 50, 58), Hair = Color3.fromRGB(30, 24, 20), Apron = Color3.fromRGB(60, 60, 66), Held = "Hammer" }, "Upgrade gear", handlers.Blacksmith, centre, Color3.fromRGB(200, 100, 60))
	if handlers.Store then
		local storeCf = shopNpc("Store", "Sunstones, packs & cosmetics", "Store", { Shirt = Color3.fromRGB(240, 190, 70), Pants = Color3.fromRGB(90, 60, 40), Hair = Color3.fromRGB(60, 40, 30), Hat = Color3.fromRGB(200, 60, 60), Apron = Color3.fromRGB(255, 240, 200), Held = "Coin" }, "Browse", handlers.Store, centre, Color3.fromRGB(240, 170, 50))
		-- an open treasure chest and glowing sun gems on the counter
		part(folder, { Name = "Chest", Size = Vector3.new(2.6, 1.6, 1.8), CFrame = storeCf * CFrame.new(-2, 3.8, -3), Color = Color3.fromRGB(150, 90, 50), Material = Enum.Material.WoodPlanks })
		part(folder, { Name = "ChestLid", Size = Vector3.new(2.6, 0.3, 1.8), CFrame = storeCf * CFrame.new(-2, 5.1, -2.2) * CFrame.Angles(math.rad(-60), 0, 0), Color = Color3.fromRGB(170, 110, 60), Material = Enum.Material.WoodPlanks })
		local gold = part(folder, { Name = "ChestGold", Size = Vector3.new(2.3, 0.3, 1.5), CFrame = storeCf * CFrame.new(-2, 4.65, -3), Color = Color3.fromRGB(255, 210, 80), Material = Enum.Material.Neon })
		table.insert(pulsers, { Part = gold, Phase = 1, Base = 0.1, Amount = 0.15 })
		for index = 1, 3 do
			local gem = part(folder, { Name = "SunGem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = storeCf * CFrame.new(1 + index * 0.9, 3.4, -3), Color = Color3.fromRGB(255, 150, 40), Material = Enum.Material.Neon })
			table.insert(pulsers, { Part = gem, Phase = index, Base = 0.05, Amount = 0.2 })
		end
	end
	if handlers.RuneCarver then
		shopNpc("Rune Carver", "Carve runes onto gear", "RuneCarver", { Shirt = Color3.fromRGB(60, 40, 90), Pants = Color3.fromRGB(40, 30, 60), Skin = Color3.fromRGB(220, 200, 190), Robe = Color3.fromRGB(70, 46, 110), Trim = Color3.fromRGB(150, 110, 255), Hood = Color3.fromRGB(56, 36, 92), Held = "Staff", Glow = Color3.fromRGB(150, 110, 255) }, "Carve runes", handlers.RuneCarver, centre, Color3.fromRGB(110, 70, 180))
	end
	part(folder, { Name = "Anvil", Size = Vector3.new(1.4, 1.6, 2.6), CFrame = forgeCf * CFrame.new(6.4, 1, -2), Color = Color3.fromRGB(56, 56, 64), Material = Enum.Material.Metal })
	part(folder, { Name = "Forge", Size = Vector3.new(3, 2.4, 3), CFrame = forgeCf * CFrame.new(-7, 1.3, 0.5), Color = Color3.fromRGB(90, 84, 80), Material = Enum.Material.Slate })
	local coals = part(folder, { Name = "Coals", Size = Vector3.new(2.2, 0.4, 2.2), CFrame = forgeCf * CFrame.new(-7, 2.6, 0.5), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon })
	local fire = Instance.new("PointLight")
	fire.Color = Color3.fromRGB(255, 140, 60)
	fire.Range = 16
	fire.Parent = coals

	wishingTree(pointOf("Tree"), centre, handlers.Tree)
	Town.Build(folder, pulsers, { villager = villager, nameTag = nameTag, TORSO_HEIGHT = TORSO_HEIGHT }) -- the districts round the plaza (Wishing Grove, Town Gate, Training Grounds) and the roads to them

	-- boards and the daily chest
	board(pointOf("Map"), centre, "WORLD MAP", Color3.fromRGB(40, 90, 150), "Open map", handlers.Map)
	board(pointOf("Rankings"), centre, "RANKINGS", Color3.fromRGB(110, 50, 140), "View leaderboards", handlers.Ranks)
	if handlers.Season then
		board(pointOf("Season"), centre, "SEASON REWARDS", Color3.fromRGB(176, 120, 30), "View season rewards", handlers.Season)
	end
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
		-- townsfolk never shove or block a player: nothing about them is solid
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		model:PivotTo(CFrame.new(start + Vector3.new(0, TORSO_HEIGHT, 0)))
		walkers[index] = { Model = model, Pos = start, Target = start, Wait = math.random() * 3, Speed = 4 + math.random() * 2, Phase = math.random() * 6 }
	end

	-- the battle lots ("player homes"): a 2 x 2 block south-east of the plaza on a packed-earth yard with paths
	-- between the lots (the road from the plaza is built by Town)
	lotFolder = Instance.new("Folder")
	lotFolder.Name = "Lots"
	lotFolder.Parent = folder
	-- the homes street (the road itself is built by Town): a "PLAYER HOMES" sign beside it where it leaves the plaza
	local sx, sz, dx, dz = World.HomesStreet()
	local signAt = Vector3.new(sx + dx * 6 - dz * 10, 0, sz + dz * 6 + dx * 10)
	local homes = part(folder, { Name = "HomesSign", Size = Vector3.new(14, 3, 0.4), CFrame = CFrame.lookAt(signAt + Vector3.new(0, 6, 0), centre + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(80, 60, 40), Material = Enum.Material.Wood })
	sign(homes, Enum.NormalId.Front, "PLAYER HOMES", Color3.fromRGB(255, 230, 170))
	part(folder, { Name = "HomesSignPost", Size = Vector3.new(0.6, 6, 0.6), Position = signAt + Vector3.new(0, 3, 0), Color = WOOD, Material = Enum.Material.Wood })
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
			local x, _, z, yaw = World.ArenaOrigin(slot)
			local lot = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
			part(lotFolder, { Name = "OpenLot", Size = Vector3.new(World.ARENA_WIDTH, 0.2, World.ARENA_DEPTH), CFrame = lot * CFrame.new(0, 0.12, 0), Color = Color3.fromRGB(120, 168, 104), Material = Enum.Material.Grass, CanCollide = false })
			local post = part(lotFolder, { Name = "LotSign", Size = Vector3.new(7, 3.4, 0.4), CFrame = lot * CFrame.new(-World.ARENA_WIDTH / 2 + 6, 5, World.ARENA_DEPTH / 2 + 3) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(60, 52, 40), Material = Enum.Material.Wood })
			part(lotFolder, { Name = "LotPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = lot * CFrame.new(-World.ARENA_WIDTH / 2 + 6, 2.5, World.ARENA_DEPTH / 2 + 3), Color = WOOD, Material = Enum.Material.Wood })
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
	for _, o in ipairs(orbiters) do
		if o.Part.Parent then
			local a = o.Phase + clock * o.Speed
			o.Part.Position = o.Centre + Vector3.new(math.sin(a) * o.Radius, o.Height + math.sin(clock * 1.3 + o.Phase * 3) * 0.9, math.cos(a) * o.Radius)
		end
	end
	for _, p in ipairs(pulsers) do
		if p.Part.Parent then
			p.Part.Transparency = math.clamp((p.Base or 0.55) + math.sin(clock * 1.8 + p.Phase) * (p.Amount or 0.2), 0, 0.95)
		end
	end
	local reach = World.PLAZA.Radius - 8
	-- where the local player is, so a villager that meets them stops and heads another way
	local me = game:GetService("Players").LocalPlayer
	local root = me and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local mine = if root then Vector3.new(root.Position.X, 0, root.Position.Z) else nil
	for _, w in ipairs(walkers) do
		if w.Model.Parent then
			w.Cool = (w.Cool or 0) - dt
			if mine and w.Cool <= 0 and (w.Pause or 0) <= 0 then
				local away = Vector3.new(w.Pos.X - mine.X, 0, w.Pos.Z - mine.Z)
				if away.Magnitude < 5 then
					-- bumped into the player: stop, then wander off in a direction away from them
					local dir = if away.Magnitude > 0.05 then away.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
					local turn = (math.random() - 0.5) * math.rad(100)
					local c, s = math.cos(turn), math.sin(turn)
					dir = Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
					local goal = w.Pos + dir * (10 + math.random() * 8)
					local fromCentre = Vector3.new(goal.X - World.PLAZA.X, 0, goal.Z - World.PLAZA.Z)
					if fromCentre.Magnitude > reach then
						goal = Vector3.new(World.PLAZA.X, 0.4, World.PLAZA.Z) + fromCentre.Unit * reach
					end
					w.Target = Vector3.new(goal.X, 0.4, goal.Z)
					w.Wait = 0
					w.Pause = 0.5
					w.Cool = 3
				end
			end
			if w.Pause and w.Pause > 0 then
				w.Pause -= dt
				w.Wait = math.max(w.Wait, 0)
				continue
			end
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
