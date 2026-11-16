--[[
	Creatures (ModuleScript): the 3D bodies of monsters, built from simple parts. Parts that should move on their own are
	tagged (attributes) and Actor animates them every frame:
	  Anim   "Wing" | "Tail" | "Arm" | "Leg" | "Jaw" | "Float" | "Squish" | "Head" | "Claw" | "Flame"
	  Hinge  Vector3, where it pivots (local to the part's centre)
	  Side   1 / -1, so a pair moves in opposite phase
	Model faces -Z. Bodies stand on y = 0.

	  Creatures.Build(look) -> Model, or nil when look.Shape is not one of Creatures.Shapes
]]

local Creatures = {}

Creatures.Shapes = {
	Beast = true, Bat = true, Spider = true, Skeleton = true, Elemental = true, Golem = true, Frog = true, Scorpion = true,
	Crab = true, Wraith = true, Bird = true, Serpent = true,
}

local function part(parent, props, anim, hinge, side)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	if anim then
		p:SetAttribute("Anim", anim)
		if hinge then
			p:SetAttribute("Hinge", hinge)
		end
		if side then
			p:SetAttribute("Side", side)
		end
	end
	p.Parent = parent
	return p
end

local function ball(size, color, cf, extra)
	local props = { Shape = Enum.PartType.Ball, Size = size, Color = color, CFrame = cf }
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return props
end

local function darker(c, amount)
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(c, amount)
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

local function eyePair(model, root, y, spread, forward, size, color)
	for _, side in ipairs({ -1, 1 }) do
		part(model, ball(Vector3.new(size, size, size), color or Color3.new(0, 0, 0), root.CFrame * CFrame.new(side * spread, y, forward), color and { Material = Enum.Material.Neon } or nil))
	end
end

local B = {}

-- four legs, a snout, ears and a tail: wolves, boars, cats
function B.Beast(model, c, s, look)
	local root = part(model, { Name = "Body", Size = Vector3.new(s * 0.45, s * 0.38, s * 0.8), Color = c, CFrame = CFrame.new(0, s * 0.5, 0) })
	local head = part(model, { Name = "Head", Size = Vector3.new(s * 0.34, s * 0.32, s * 0.36), Color = lighter(c, 0.08), CFrame = CFrame.new(0, s * 0.62, -s * 0.5) }, "Head")
	part(model, { Size = Vector3.new(s * 0.2, s * 0.16, s * 0.24), Color = darker(c, 0.25), CFrame = head.CFrame * CFrame.new(0, -s * 0.05, -s * 0.28) }, "Jaw", Vector3.new(0, 0, s * 0.1))
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.1, s * 0.18, s * 0.08), Color = darker(c, 0.15), CFrame = head.CFrame * CFrame.new(side * s * 0.12, s * 0.22, s * 0.05) })
		local back = if side == 1 then 1 else -1
		part(model, { Size = Vector3.new(s * 0.12, s * 0.34, s * 0.14), Color = darker(c, 0.3), CFrame = CFrame.new(side * s * 0.15, s * 0.17, -s * 0.28) }, "Leg", Vector3.new(0, s * 0.15, 0), back)
		part(model, { Size = Vector3.new(s * 0.12, s * 0.34, s * 0.14), Color = darker(c, 0.3), CFrame = CFrame.new(side * s * 0.15, s * 0.17, s * 0.28) }, "Leg", Vector3.new(0, s * 0.15, 0), -back)
	end
	part(model, { Size = Vector3.new(s * 0.1, s * 0.1, s * 0.5), Color = lighter(c, 0.25), CFrame = CFrame.new(0, s * 0.62, s * 0.62) * CFrame.Angles(math.rad(-25), 0, 0) }, "Tail", Vector3.new(0, 0, -s * 0.22))
	if look.Tusks then
		for _, side in ipairs({ -1, 1 }) do
			part(model, { Size = Vector3.new(s * 0.04, s * 0.04, s * 0.16), Color = Color3.fromRGB(240, 235, 215), CFrame = head.CFrame * CFrame.new(side * s * 0.1, -s * 0.08, -s * 0.3) })
		end
	end
	eyePair(model, root, s * 0.7, s * 0.09, -s * 0.66, s * 0.07, Color3.fromRGB(255, 220, 80))
	return root
end

-- a small body with two big flapping wings
function B.Bat(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.32, s * 0.4, s * 0.3), Color = c, CFrame = CFrame.new(0, s * 0.7, 0) }, "Float")
	part(model, ball(Vector3.new(s * 0.26, s * 0.26, s * 0.26), c, CFrame.new(0, s * 0.95, -s * 0.05)), "Float")
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.7, s * 0.05, s * 0.4), Color = darker(c, 0.2), CFrame = CFrame.new(side * s * 0.5, s * 0.78, 0) }, "Wing", Vector3.new(-side * s * 0.35, 0, 0), side)
		part(model, { Size = Vector3.new(s * 0.08, s * 0.16, s * 0.08), Color = c, CFrame = CFrame.new(side * s * 0.08, 1.08 * s, -s * 0.04) }, "Float")
	end
	eyePair(model, root, s * 0.3, s * 0.07, -s * 0.15, s * 0.06, Color3.fromRGB(255, 80, 80))
	return root
end

-- eight legs
function B.Spider(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.5, s * 0.4, s * 0.55), Color = c, CFrame = CFrame.new(0, s * 0.42, s * 0.12) })
	part(model, ball(Vector3.new(s * 0.3, s * 0.28, s * 0.3), darker(c, 0.15), CFrame.new(0, s * 0.42, -s * 0.28)), "Head")
	for i = 1, 4 do
		for _, side in ipairs({ -1, 1 }) do
			local z = -s * 0.2 + i * s * 0.1
			local phase = if i % 2 == 0 then side else -side
			part(model, { Size = Vector3.new(s * 0.55, s * 0.06, s * 0.06), Color = darker(c, 0.35), CFrame = CFrame.new(side * s * 0.4, s * 0.3, z) * CFrame.Angles(0, 0, math.rad(side * -25)) }, "Leg", Vector3.new(-side * s * 0.25, 0, 0), phase)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.05, s * 0.05, s * 0.18), Color = Color3.fromRGB(230, 230, 230), CFrame = CFrame.new(side * s * 0.07, s * 0.3, -s * 0.46) }, "Claw", Vector3.new(0, 0, s * 0.08), side)
	end
	eyePair(model, root, s * 0.06, s * 0.08, -s * 0.46, s * 0.07, Color3.fromRGB(255, 60, 60))
	return root
end

-- bones: skeletons, mummies (wrapped), with a swinging weapon arm
function B.Skeleton(model, c, s, look)
	local root = part(model, { Name = "Body", Size = Vector3.new(s * 0.34, s * 0.4, s * 0.2), Color = c, CFrame = CFrame.new(0, s * 0.55, 0) })
	part(model, { Size = Vector3.new(s * 0.26, s * 0.06, s * 0.22), Color = darker(c, 0.15), CFrame = CFrame.new(0, s * 0.62, -s * 0.02) })
	part(model, { Size = Vector3.new(s * 0.26, s * 0.06, s * 0.22), Color = darker(c, 0.15), CFrame = CFrame.new(0, s * 0.5, -s * 0.02) })
	local head = part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.3, s * 0.3, s * 0.3), Color = lighter(c, 0.1), CFrame = CFrame.new(0, s * 0.92, 0) }, "Head")
	part(model, { Size = Vector3.new(s * 0.2, s * 0.07, s * 0.14), Color = darker(c, 0.1), CFrame = head.CFrame * CFrame.new(0, -s * 0.14, -s * 0.03) }, "Jaw", Vector3.new(0, s * 0.03, s * 0.05))
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.08, s * 0.36, s * 0.08), Color = c, CFrame = CFrame.new(side * s * 0.26, s * 0.58, 0) }, "Arm", Vector3.new(0, s * 0.16, 0), side)
		part(model, { Size = Vector3.new(s * 0.09, s * 0.34, s * 0.09), Color = darker(c, 0.1), CFrame = CFrame.new(side * s * 0.1, s * 0.17, 0) }, "Leg", Vector3.new(0, s * 0.15, 0), side)
	end
	part(model, { Size = Vector3.new(s * 0.05, s * 0.05, s * 0.5), Color = Color3.fromRGB(180, 185, 195), CFrame = CFrame.new(s * 0.26, s * 0.5, -s * 0.28) }, "Arm", Vector3.new(0, 0, s * 0.2), 1)
	if look.Wrapped then
		part(model, { Size = Vector3.new(s * 0.38, s * 0.08, s * 0.26), Color = Color3.fromRGB(220, 210, 175), CFrame = CFrame.new(0, s * 0.66, 0) })
		part(model, { Size = Vector3.new(s * 0.38, s * 0.08, s * 0.26), Color = Color3.fromRGB(220, 210, 175), CFrame = CFrame.new(0, s * 0.46, 0) })
	end
	eyePair(model, root, s * 0.96 - s * 0.55, s * 0.07, -s * 0.13, s * 0.06, Color3.fromRGB(120, 255, 200))
	return root
end

-- a floating core ringed by orbiting flames/crystals
function B.Elemental(model, c, s, look)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.5, s * 0.5, s * 0.5), Color = c, Material = Enum.Material.Neon, Transparency = 0.1, CFrame = CFrame.new(0, s * 0.6, 0) }, "Float")
	part(model, ball(Vector3.new(s * 0.75, s * 0.75, s * 0.75), c, CFrame.new(0, s * 0.6, 0), { Material = Enum.Material.Neon, Transparency = 0.8 }), "Float")
	for i = 1, 4 do
		local ang = i * math.pi / 2
		part(model, { Size = Vector3.new(s * 0.14, s * 0.3, s * 0.14), Color = lighter(c, 0.3), Material = Enum.Material.Neon, CFrame = CFrame.new(math.cos(ang) * s * 0.4, s * 0.6 + math.sin(ang) * s * 0.3, 0) * CFrame.Angles(0, 0, ang) }, "Flame", Vector3.new(0, 0, 0), if i % 2 == 0 then 1 else -1)
	end
	if look.Hat then
		part(model, { Size = Vector3.new(s * 0.2, s * 0.3, s * 0.2), Color = lighter(c, 0.5), Material = Enum.Material.Neon, CFrame = CFrame.new(0, s * 1.0, 0) }, "Float")
	end
	eyePair(model, root, 0, s * 0.1, -s * 0.23, s * 0.09, Color3.new(1, 1, 1))
	return root
end

-- a big blocky rock man with heavy swinging arms
function B.Golem(model, c, s, look)
	local rockMat = Enum.Material.Slate
	local root = part(model, { Name = "Body", Size = Vector3.new(s * 0.5, s * 0.45, s * 0.34), Color = c, Material = rockMat, CFrame = CFrame.new(0, s * 0.55, 0) })
	part(model, { Name = "Head", Size = Vector3.new(s * 0.28, s * 0.24, s * 0.26), Color = lighter(c, 0.1), Material = rockMat, CFrame = CFrame.new(0, s * 0.9, -s * 0.02) }, "Head")
	part(model, { Size = Vector3.new(s * 0.2, s * 0.15, s * 0.2), Color = darker(c, 0.2), Material = rockMat, CFrame = CFrame.new(0, s * 0.34, 0) })
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.2, s * 0.5, s * 0.2), Color = darker(c, 0.1), Material = rockMat, CFrame = CFrame.new(side * s * 0.38, s * 0.5, 0) }, "Arm", Vector3.new(0, s * 0.2, 0), side)
		part(model, { Size = Vector3.new(s * 0.22, s * 0.3, s * 0.22), Color = darker(c, 0.25), Material = rockMat, CFrame = CFrame.new(side * s * 0.14, s * 0.15, 0) }, "Leg", Vector3.new(0, s * 0.12, 0), side)
	end
	if look.Fur then
		part(model, { Size = Vector3.new(s * 0.54, s * 0.12, s * 0.38), Color = Color3.fromRGB(240, 245, 250), CFrame = CFrame.new(0, s * 0.74, 0) })
	end
	eyePair(model, root, s * 0.35, s * 0.07, -s * 0.15, s * 0.06, Color3.fromRGB(150, 255, 150))
	return root
end

-- a hopper with a throat sac and long hind legs
function B.Frog(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.7, s * 0.5, s * 0.8), Color = c, CFrame = CFrame.new(0, s * 0.3, 0) }, "Squish")
	part(model, ball(Vector3.new(s * 0.3, s * 0.2, s * 0.26), lighter(c, 0.4), CFrame.new(0, s * 0.2, -s * 0.34)), "Squish")
	for _, side in ipairs({ -1, 1 }) do
		part(model, ball(Vector3.new(s * 0.2, s * 0.2, s * 0.2), lighter(c, 0.3), CFrame.new(side * s * 0.18, s * 0.58, -s * 0.28)), "Head")
		part(model, { Size = Vector3.new(s * 0.14, s * 0.12, s * 0.4), Color = darker(c, 0.2), CFrame = CFrame.new(side * s * 0.38, s * 0.1, s * 0.25) }, "Leg", Vector3.new(0, 0, -s * 0.15), side)
	end
	eyePair(model, root, s * 0.28, s * 0.18, -s * 0.3, s * 0.1, Color3.fromRGB(255, 230, 90))
	return root
end

-- pincers and a stinging tail
function B.Scorpion(model, c, s)
	local root = part(model, { Name = "Body", Size = Vector3.new(s * 0.5, s * 0.22, s * 0.7), Color = c, CFrame = CFrame.new(0, s * 0.25, 0) })
	for i = 1, 4 do
		part(model, ball(Vector3.new(s * (0.18 - i * 0.02), s * (0.18 - i * 0.02), s * 0.2), darker(c, 0.1), CFrame.new(0, s * (0.35 + i * 0.1), s * (0.3 + i * 0.05))), "Tail", Vector3.new(0, -s * 0.1, 0), 1)
	end
	part(model, { Size = Vector3.new(s * 0.05, s * 0.18, s * 0.05), Color = Color3.fromRGB(240, 240, 230), CFrame = CFrame.new(0, s * 0.8, s * 0.55) }, "Tail", Vector3.new(0, -s * 0.2, 0), 1)
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.2, s * 0.1, s * 0.34), Color = lighter(c, 0.1), CFrame = CFrame.new(side * s * 0.34, s * 0.25, -s * 0.45) }, "Claw", Vector3.new(0, 0, s * 0.12), side)
		for i = 1, 3 do
			part(model, { Size = Vector3.new(s * 0.3, s * 0.04, s * 0.04), Color = darker(c, 0.3), CFrame = CFrame.new(side * s * 0.34, s * 0.14, -s * 0.15 + i * s * 0.14) }, "Leg", Vector3.new(-side * s * 0.12, 0, 0), if i % 2 == 0 then side else -side)
		end
	end
	eyePair(model, root, s * 0.14, s * 0.1, -s * 0.34, s * 0.06, Color3.fromRGB(255, 80, 80))
	return root
end

-- wide and flat with snapping claws, sidewalking
function B.Crab(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.7, s * 0.34, s * 0.5), Color = c, CFrame = CFrame.new(0, s * 0.3, 0) })
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.1, s * 0.1, s * 0.3), Color = darker(c, 0.1), CFrame = CFrame.new(side * s * 0.4, s * 0.4, -s * 0.25) })
		part(model, ball(Vector3.new(s * 0.28, s * 0.2, s * 0.3), lighter(c, 0.1), CFrame.new(side * s * 0.42, s * 0.48, -s * 0.42)), "Claw", Vector3.new(0, 0, s * 0.12), side)
		for i = 1, 3 do
			part(model, { Size = Vector3.new(s * 0.3, s * 0.05, s * 0.05), Color = darker(c, 0.3), CFrame = CFrame.new(side * s * 0.45, s * 0.15, -s * 0.1 + i * s * 0.1) }, "Leg", Vector3.new(-side * s * 0.12, 0, 0), if i % 2 == 0 then side else -side)
		end
		part(model, ball(Vector3.new(s * 0.08, s * 0.08, s * 0.08), Color3.new(0, 0, 0), CFrame.new(side * s * 0.12, s * 0.52, -s * 0.2)))
	end
	return root
end

-- a hooded drifting spirit with a ragged tail of cloth
function B.Wraith(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.5, s * 0.6, s * 0.4), Color = c, Transparency = 0.25, CFrame = CFrame.new(0, s * 0.75, 0) }, "Float")
	part(model, { Size = Vector3.new(s * 0.46, s * 0.55, s * 0.34), Color = darker(c, 0.2), Transparency = 0.4, CFrame = CFrame.new(0, s * 0.4, 0) }, "Float")
	for i = 1, 3 do
		part(model, { Size = Vector3.new(s * 0.12, s * 0.3, s * 0.06), Color = darker(c, 0.3), Transparency = 0.5, CFrame = CFrame.new((i - 2) * s * 0.17, s * 0.13, 0) }, "Tail", Vector3.new(0, s * 0.15, 0), if i % 2 == 0 then 1 else -1)
	end
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.08, s * 0.3, s * 0.08), Color = lighter(c, 0.2), Transparency = 0.3, CFrame = CFrame.new(side * s * 0.34, s * 0.7, -s * 0.05) }, "Arm", Vector3.new(0, s * 0.12, 0), side)
	end
	eyePair(model, root, s * 0.05, s * 0.09, -s * 0.18, s * 0.07, Color3.fromRGB(190, 255, 240))
	return root
end

-- a hovering bird of prey / harpy
function B.Bird(model, c, s)
	local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.36, s * 0.42, s * 0.5), Color = c, CFrame = CFrame.new(0, s * 0.7, 0) }, "Float")
	part(model, ball(Vector3.new(s * 0.24, s * 0.24, s * 0.24), lighter(c, 0.15), CFrame.new(0, s * 0.98, -s * 0.2)), "Float")
	part(model, { Size = Vector3.new(s * 0.08, s * 0.06, s * 0.2), Color = Color3.fromRGB(255, 170, 60), CFrame = CFrame.new(0, s * 0.96, -s * 0.38) }, "Float")
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Size = Vector3.new(s * 0.8, s * 0.05, s * 0.4), Color = lighter(c, 0.25), CFrame = CFrame.new(side * s * 0.55, s * 0.78, 0) }, "Wing", Vector3.new(-side * s * 0.4, 0, 0), side)
		part(model, { Size = Vector3.new(s * 0.06, s * 0.22, s * 0.06), Color = Color3.fromRGB(255, 170, 60), CFrame = CFrame.new(side * s * 0.1, s * 0.4, 0) }, "Leg", Vector3.new(0, s * 0.1, 0), side)
	end
	part(model, { Size = Vector3.new(s * 0.2, s * 0.05, s * 0.4), Color = darker(c, 0.1), CFrame = CFrame.new(0, s * 0.62, s * 0.4) }, "Tail", Vector3.new(0, 0, -s * 0.18), 1)
	eyePair(model, root, s * 0.36, s * 0.08, -s * 0.3, s * 0.06, Color3.fromRGB(255, 240, 120))
	return root
end

-- a long body that coils and sways
function B.Serpent(model, c, s)
	local root
	for i = 1, 6 do
		local seg = part(model, ball(Vector3.new(s * (0.34 - i * 0.025), s * (0.34 - i * 0.025), s * (0.34 - i * 0.025)), if i % 2 == 0 then lighter(c, 0.1) else c, CFrame.new(0, s * 0.2, s * (i - 1) * 0.16)), "Tail", Vector3.new(0, 0, -s * 0.15), if i % 2 == 0 then 1 else -1)
		root = root or seg
	end
	local head = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.36, s * 0.3, s * 0.4), Color = c, CFrame = CFrame.new(0, s * 0.6, -s * 0.1) }, "Head")
	part(model, { Size = Vector3.new(s * 0.2, s * 0.5, s * 0.2), Color = c, CFrame = CFrame.new(0, s * 0.35, -s * 0.05) })
	eyePair(model, head, s * 0.06, s * 0.1, -s * 0.16, s * 0.06, Color3.fromRGB(255, 220, 60))
	return head
end

function Creatures.Build(look)
	local builder = B[look.Shape]
	if not builder then
		return nil
	end
	local c = Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3])
	local model = Instance.new("Model")
	local root = builder(model, c, look.Size, look)
	model.PrimaryPart = root
	return model
end

return Creatures
