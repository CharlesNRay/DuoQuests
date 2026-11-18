--[[
	Scene (ModuleScript): the 3D battlefield, built on the client.

	One arena pad in the shared world (placed by World.ArenaOrigin): ground, sky
	backdrop and scenery props. It owns no camera and no lighting, so any number
	of arenas can exist at once (yours and other parties') and players can walk
	between them. See Battle/BattleCamera for the fixed side view.

	  Scene.new(origin)                 -> scene (origin = Vector3 centre of the pad)
	  scene:SetZone(theme)              rebuild scenery/colours for a Config/Zones theme
	  scene:Walk(on)                    scenery scrolls so the party looks like it travels
	  scene.Folder / scene.Origin       parent for actors and effects; world origin
	  scene:Destroy()

	Heroes stand at x < 0 (left) facing right, enemies at x > 0.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))
local TweenService = game:GetService("TweenService")

local Scene = {}
Scene.__index = Scene

local SPAN = 32 -- scenery repeats every 2*SPAN studs (the pad is 64 wide)

local function color(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function prop(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function Scene.new(origin)
	local self = setmetatable({ Origin = origin, Walking = false, Scroll = 0, Props = {} }, Scene)
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "DuoQuestArena"
	self.Folder.Parent = workspace

	self.Ground = prop(self.Folder, { Name = "Ground", Size = Vector3.new(World.ARENA_WIDTH, 1, World.ARENA_DEPTH), CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)) })
	-- (no backdrop wall: the real sky and horizon show behind the fight)
	self.Scenery = Instance.new("Folder")
	self.Scenery.Name = "Scenery"
	self.Scenery.Parent = self.Folder

	self.Conn = RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)
	return self
end

local function wrap(x)
	return (x + SPAN) % (SPAN * 2) - SPAN
end

function Scene:_update(dt)
	if self.Walking then
		self.Scroll = (self.Scroll + dt * 9) % (SPAN * 2 * 10) -- (a long period so slower layers wrap cleanly)
	end
	local now = os.clock()
	for _, p in ipairs(self.Props) do
		local x = wrap(p.BaseX - self.Scroll * (p.Par or 1) + (p.Drift or 0) * now)
		local cf = CFrame.new(self.Origin + Vector3.new(x, p.Y or 0, p.Z))
		if p.Sway then
			cf = cf * CFrame.Angles(0, 0, math.sin(now * p.Sway + p.Phase) * 0.025)
		end
		p.Root:PivotTo(cf)
	end
end

function Scene:Walk(on)
	self.Walking = on
end

local function tree(parent, theme, h)
	local m = Instance.new("Model")
	prop(m, { Size = Vector3.new(1.2, h, 1.2), Color = Color3.fromRGB(110, 76, 48), CFrame = CFrame.new(0, h / 2, 0) })
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.9, h * 0.9, h * 0.9), Color = color(theme.Accent), CFrame = CFrame.new(0, h * 1.05, 0) })
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
	return m
end

local function pine(parent, theme, h)
	local m = Instance.new("Model")
	prop(m, { Size = Vector3.new(1, h * 0.4, 1), Color = Color3.fromRGB(90, 62, 40), CFrame = CFrame.new(0, h * 0.2, 0) })
	for i = 0, 2 do
		local w = h * (0.6 - i * 0.15)
		prop(m, { Size = Vector3.new(w, h * 0.3, w), Color = color(theme.Accent), Shape = Enum.PartType.Ball, CFrame = CFrame.new(0, h * (0.45 + i * 0.25), 0) })
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
	return m
end

local function rock(parent, theme, h)
	local m = Instance.new("Model")
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 1.4, h, h * 1.1), Color = color(theme.Accent), Material = Enum.Material.Slate, CFrame = CFrame.new(0, h * 0.4, 0) })
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
	return m
end

local function crystal(parent, theme, h)
	local m = Instance.new("Model")
	for i = -1, 1 do
		prop(m, { Size = Vector3.new(1.2, h * (1 - math.abs(i) * 0.3), 1.2), Color = color(theme.Accent), Material = Enum.Material.Neon, CFrame = CFrame.new(i * 1.1, h * 0.5, 0) * CFrame.Angles(0, 0, math.rad(i * 12)) })
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
	return m
end

local function newModel(parent)
	local m = Instance.new("Model")
	local base = prop(m, { Name = "Pivot", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	m.PrimaryPart = base
	m.Parent = parent
	return m
end

local function cactus(parent, theme, h)
	local green = Color3.fromRGB(70, 140, 70)
	local m = newModel(parent)
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), Color = green, CFrame = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.35, 1, 1), Color = green, CFrame = CFrame.new(-1.6, h * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.3, 1, 1), Color = green, CFrame = CFrame.new(1.5, h * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	return m
end

local function snowPine(parent, theme, h)
	local m = newModel(parent)
	prop(m, { Size = Vector3.new(1, h * 0.35, 1), Color = Color3.fromRGB(90, 62, 40), CFrame = CFrame.new(0, h * 0.17, 0) })
	for i = 0, 2 do
		local w = h * (0.62 - i * 0.16)
		prop(m, { Size = Vector3.new(w, h * 0.26, w), Color = color(theme.Accent), Shape = Enum.PartType.Ball, CFrame = CFrame.new(0, h * (0.42 + i * 0.24), 0) })
		prop(m, { Size = Vector3.new(w * 0.7, h * 0.12, w * 0.7), Color = Color3.fromRGB(250, 252, 255), Shape = Enum.PartType.Ball, CFrame = CFrame.new(0, h * (0.5 + i * 0.24), 0) })
	end
	return m
end

local function lavaRock(parent, theme, h)
	local m = newModel(parent)
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 1.3, h, h), Color = Color3.fromRGB(46, 38, 38), Material = Enum.Material.Basalt, CFrame = CFrame.new(0, h * 0.4, 0) })
	prop(m, { Size = Vector3.new(h * 0.15, h * 0.7, 0.3), Color = color(theme.Accent), Material = Enum.Material.Neon, CFrame = CFrame.new(h * 0.1, h * 0.5, h * 0.48) * CFrame.Angles(0, 0, math.rad(20)) })
	prop(m, { Size = Vector3.new(h * 0.12, h * 0.5, 0.3), Color = color(theme.Accent), Material = Enum.Material.Neon, CFrame = CFrame.new(-h * 0.25, h * 0.45, h * 0.4) * CFrame.Angles(0, 0, math.rad(-25)) })
	return m
end

local function deadTree(parent, theme, h)
	local bark = Color3.fromRGB(70, 56, 46)
	local m = newModel(parent)
	prop(m, { Size = Vector3.new(1, h, 1), Color = bark, CFrame = CFrame.new(0, h / 2, 0) })
	prop(m, { Size = Vector3.new(0.5, h * 0.5, 0.5), Color = bark, CFrame = CFrame.new(1.2, h * 0.75, 0) * CFrame.Angles(0, 0, math.rad(-40)) })
	prop(m, { Size = Vector3.new(0.5, h * 0.4, 0.5), Color = bark, CFrame = CFrame.new(-1, h * 0.65, 0) * CFrame.Angles(0, 0, math.rad(35)) })
	return m
end

local function pillar(parent, theme, h)
	local stone = color(theme.Accent)
	local m = newModel(parent)
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2), Color = stone, Material = Enum.Material.Cobblestone, CFrame = CFrame.new(0, h / 2 - 1, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	prop(m, { Size = Vector3.new(3, 0.8, 3), Color = stone, Material = Enum.Material.Cobblestone, CFrame = CFrame.new(0, h - 0.6, 0) * CFrame.Angles(0, math.rad(15), math.rad(6)) })
	-- seaweed drape: this is the sunken part of the ruins
	prop(m, { Size = Vector3.new(0.4, h * 0.4, 0.4), Color = Color3.fromRGB(60, 130, 100), CFrame = CFrame.new(1.1, h * 0.3, 0) })
	return m
end

local function cloud(parent, theme, h)
	local m = newModel(parent)
	for i = -1, 1 do
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.8, h * 0.6, h * 0.8), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(i * h * 0.55, h * 0.8 + math.abs(i) * -0.5, 0) })
	end
	return m
end

-- small ground decoration (front of the pad, scrolls with the scenery)
local function decor(parent, kind, c, size)
	local col = Color3.fromRGB(c[1], c[2], c[3])
	local m = newModel(parent)
	if kind == "Flowers" then
		for i = -1, 1 do
			prop(m, { Size = Vector3.new(0.15, 1.2, 0.15), Color = Color3.fromRGB(70, 140, 70), CFrame = CFrame.new(i * 0.8, 0.6, i * 0.3) })
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = col, CFrame = CFrame.new(i * 0.8, 1.3, i * 0.3) })
		end
	elseif kind == "Mushrooms" then
		for i = 0, 1 do
			prop(m, { Size = Vector3.new(0.4, 0.9 + i * 0.4, 0.4), Color = Color3.fromRGB(235, 228, 210), CFrame = CFrame.new(i * 1.2, 0.5, 0) })
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 0.8, 1.4), Color = col, CFrame = CFrame.new(i * 1.2, 1 + i * 0.4, 0) })
		end
	elseif kind == "Bones" then
		prop(m, { Size = Vector3.new(2.4, 0.4, 0.4), Color = col, CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, math.rad(25), 0) })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Color = col, CFrame = CFrame.new(1.4, 0.4, 0.5) })
	elseif kind == "Embers" then
		for i = -1, 1 do
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = col, Material = Enum.Material.Neon, CFrame = CFrame.new(i * 0.9, 0.3 + math.abs(i) * 0.5, i * 0.4) })
		end
	else -- Stones
		for i = 0, 2 do
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2 - i * 0.2, 0.8, 1.1), Color = col, Material = Enum.Material.Slate, CFrame = CFrame.new(i * 1.1, 0.3, (i % 2) * 0.6) })
		end
	end
	return m
end

-- Floating things in the air of each zone: fireflies, leaves, dust, snow, embers, bubbles...
local AMBIENT = {
	Trees = { Color = { 255, 240, 140 }, Rate = 5, Size = 0.35, Speed = 0.6, Life = 6, Accel = Vector3.new(0, 0.1, 0), Light = 1 }, -- fireflies
	Pines = { Color = { 120, 190, 100 }, Rate = 4, Size = 0.5, Speed = 1.2, Life = 7, Accel = Vector3.new(-1.2, -0.6, 0), Light = 0.1 }, -- drifting leaves
	Rocks = { Color = { 210, 200, 185 }, Rate = 5, Size = 0.3, Speed = 1.5, Life = 6, Accel = Vector3.new(-1.5, 0, 0), Light = 0 }, -- dust
	Crystals = { Color = { 190, 150, 255 }, Rate = 8, Size = 0.3, Speed = 0.8, Life = 5, Accel = Vector3.new(0, 0.8, 0), Light = 1 }, -- sparkles rising
	Cacti = { Color = { 235, 205, 150 }, Rate = 12, Size = 0.35, Speed = 4, Life = 5, Accel = Vector3.new(-6, 0, 0), Light = 0 }, -- blown sand
	SnowPines = { Color = { 255, 255, 255 }, Rate = 22, Size = 0.35, Speed = 1, Life = 8, Accel = Vector3.new(-0.8, -3, 0), Light = 0.3 }, -- snowfall
	LavaRocks = { Color = { 255, 140, 50 }, Rate = 10, Size = 0.3, Speed = 1.5, Life = 5, Accel = Vector3.new(0.5, 2.2, 0), Light = 1 }, -- embers rising
	DeadTrees = { Color = { 160, 210, 120 }, Rate = 4, Size = 1.4, Speed = 0.4, Life = 8, Accel = Vector3.new(0, 0.1, 0), Light = 0.4, Soft = true }, -- swamp mist
	Pillars = { Color = { 190, 235, 245 }, Rate = 6, Size = 0.35, Speed = 0.8, Life = 6, Accel = Vector3.new(0, 1.2, 0), Light = 0.5 }, -- bubbles
	Clouds = { Color = { 255, 255, 255 }, Rate = 7, Size = 0.4, Speed = 0.7, Life = 7, Accel = Vector3.new(0, 0.3, 0), Light = 1 }, -- sparkles
}

function Scene:_ambient(theme)
	if self.AmbientPart then
		self.AmbientPart:Destroy()
		self.AmbientPart = nil
	end
	local spec = AMBIENT[theme.Scenery]
	if not spec then
		return
	end
	local emitterPart = prop(self.Folder, { Name = "Ambient", Size = Vector3.new(60, 14, 30), Transparency = 1, CFrame = CFrame.new(self.Origin + Vector3.new(0, 8, 4)) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color(spec.Color))
	e.LightEmission = spec.Light
	e.Rate = spec.Rate
	e.Lifetime = NumberRange.new(spec.Life * 0.7, spec.Life)
	e.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = spec.Accel
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, spec.Size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, if spec.Soft then 0.7 else 0.1), NumberSequenceKeypoint.new(0.8, if spec.Soft then 0.7 else 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = emitterPart
	self.AmbientPart = emitterPart
end

-- distant hills (or dunes, peaks...) behind the fight; they scroll slower than the near scenery
function Scene:_backdrop(theme, rng)
	local ground, sky = color(theme.Ground), color(theme.Sky)
	local far = sky:Lerp(ground, 0.35)
	local near = sky:Lerp(ground, 0.6)
	local isCave = theme.Scenery == "Crystals"
	for layer = 1, 2 do
		local count = if layer == 1 then 5 else 6
		for i = 1, count do
			local h = rng:NextNumber(10, 22) * (if layer == 1 then 1.1 else 0.8)
			local w = h * rng:NextNumber(1.8, 2.8)
			local m = newModel(self.Scenery)
			local z = if layer == 1 then -46 else -34
			local col = if layer == 1 then far else near
			if theme.Scenery == "Pillars" or theme.Scenery == "LavaRocks" or isCave then
				prop(m, { Size = Vector3.new(w * 0.4, h * 1.3, w * 0.4), Color = col, Material = Enum.Material.Slate, CFrame = CFrame.new(0, h * 0.5, 0) })
			elseif theme.Scenery == "Clouds" then
				prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w, h * 0.5, h * 0.8), Color = Color3.new(1, 1, 1), CFrame = CFrame.new(0, h * 0.3, 0) })
			else
				prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w, h * 1.2, w * 0.7), Color = col, CFrame = CFrame.new(0, h * 0.1, 0) })
			end
			local baseX = -SPAN + (i - 1) * (SPAN * 2 / count) + rng:NextNumber(-4, 4)
			table.insert(self.Props, { Root = m, BaseX = baseX, Z = z, Par = if layer == 1 then 0.1 else 0.3, Phase = 0 })
		end
	end
	-- a few slow clouds
	if theme.Scenery ~= "Crystals" then
		for i = 1, 4 do
			local m = newModel(self.Scenery)
			local h = rng:NextNumber(3, 5)
			for j = -1, 1 do
				prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 1.4, h * 0.7, h), Color = if theme.Scenery == "LavaRocks" then Color3.fromRGB(90, 55, 50) else Color3.fromRGB(255, 255, 255), Transparency = 0.15, CFrame = CFrame.new(j * h * 0.9, math.abs(j) * -0.3, 0) })
			end
			table.insert(self.Props, { Root = m, BaseX = -SPAN + (i - 1) * (SPAN * 2 / 4), Z = -49, Y = rng:NextNumber(26, 38), Par = 0.1, Drift = rng:NextNumber(0.3, 0.8), Phase = 0 })
		end
	end
end

local BUILDERS = {
	Trees = tree, Pines = pine, Rocks = rock, Crystals = crystal,
	Cacti = cactus, SnowPines = snowPine, LavaRocks = lavaRock, DeadTrees = deadTree, Pillars = pillar, Clouds = cloud,
}

function Scene:SetZone(theme)
	self.Scenery:ClearAllChildren()
	self.Props = {}
	self.Ground.Color = color(theme.Ground)
	if not self.Apron then
		-- more ground behind the fight, so the distant hills stand on something
		self.Apron = prop(self.Folder, { Name = "Apron", Size = Vector3.new(World.ARENA_WIDTH, 1, 24), CFrame = CFrame.new(self.Origin + Vector3.new(0, -0.5, -37)) })
	end
	self.Apron.Color = color(theme.Ground):Lerp(color(theme.Sky), 0.1)
	local sky = color(theme.Sky)
	local okMaterial, material = pcall(function()
		return Enum.Material[theme.Material or "Grass"]
	end)
	self.Ground.Material = if okMaterial and material then material else Enum.Material.Grass
	self.Apron.Material = self.Ground.Material

	local build = BUILDERS[theme.Scenery] or tree
	local rng = Random.new(7)
	for i = 1, 8 do
		local baseX = -SPAN + (i - 1) * (SPAN * 2 / 8) + rng:NextNumber(-3, 3)
		local z = -11 - rng:NextInteger(0, 2) * 4 -- behind the back lane of a full four-hero row
		local model = build(self.Scenery, theme, rng:NextNumber(5, 9))
		model:PivotTo(CFrame.new(self.Origin + Vector3.new(baseX, 0, z)))
		table.insert(self.Props, { Root = model, BaseX = baseX, Z = z, Sway = rng:NextNumber(0.8, 1.6), Phase = rng:NextNumber(0, 6) })
	end
	self:_backdrop(theme, rng)
	self:_ambient(theme)
	-- foreground decoration: flowers, mushrooms, bones...
	if theme.Decor then
		for i = 1, 10 do
			local baseX = -SPAN + (i - 1) * (SPAN * 2 / 10) + rng:NextNumber(-2, 2)
			local z = rng:NextNumber(13, 22)
			local model = decor(self.Scenery, theme.Decor.Kind, theme.Decor.Color, 1)
			model:PivotTo(CFrame.new(self.Origin + Vector3.new(baseX, 0, z)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			table.insert(self.Props, { Root = model, BaseX = baseX, Z = z })
		end
	end
end

function Scene:Destroy()
	if self.AmbientPart then
		self.AmbientPart:Destroy()
	end
	self.Conn:Disconnect()
	self.Folder:Destroy()
end

return Scene
