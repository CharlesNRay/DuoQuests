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

	self.Ground = prop(self.Folder, { Name = "Ground", Size = Vector3.new(64, 1, 42), CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)) })
	self.Backdrop = prop(self.Folder, { Name = "Backdrop", Size = Vector3.new(64, 34, 1), CFrame = CFrame.new(origin + Vector3.new(0, 17, -21)), Material = Enum.Material.Neon, Transparency = 0.15 })
	self.Scenery = Instance.new("Folder")
	self.Scenery.Name = "Scenery"
	self.Scenery.Parent = self.Folder

	self.Conn = RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)
	return self
end

function Scene:_update(dt)
	if self.Walking then
		self.Scroll = (self.Scroll + dt * 9) % (SPAN * 2)
		for _, p in ipairs(self.Props) do
			local x = p.BaseX - self.Scroll
			if x < -SPAN then
				x += SPAN * 2
			end
			p.Root:PivotTo(CFrame.new(self.Origin + Vector3.new(x, 0, p.Z)))
		end
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

local BUILDERS = { Trees = tree, Pines = pine, Rocks = rock, Crystals = crystal }

function Scene:SetZone(theme)
	self.Scenery:ClearAllChildren()
	self.Props = {}
	self.Ground.Color = color(theme.Ground)
	self.Backdrop.Color = color(theme.Sky)

	local build = BUILDERS[theme.Scenery] or tree
	local rng = Random.new(7)
	for i = 1, 8 do
		local baseX = -SPAN + (i - 1) * (SPAN * 2 / 8) + rng:NextNumber(-3, 3)
		local z = -6 - rng:NextInteger(0, 2) * 4
		local model = build(self.Scenery, theme, rng:NextNumber(5, 9))
		model:PivotTo(CFrame.new(self.Origin + Vector3.new(baseX, 0, z)))
		table.insert(self.Props, { Root = model, BaseX = baseX, Z = z })
	end
end

function Scene:Destroy()
	self.Conn:Disconnect()
	self.Folder:Destroy()
end

return Scene
