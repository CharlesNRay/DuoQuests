--[[
	Models (ModuleScript): builds the 3D bodies used in battle.
	  Models.Hero(classId)        simple placeholder body (swapped for the player's
	                              real avatar when it loads, see Actor)
	  Models.Enemy(defId)         monster from simple shapes, looks in Config/Enemies
	  Models.Pet(petId)           small companion, looks from Config/Pets (nil = default)
	Every model is anchored, non-colliding, with a PrimaryPart. Placeholder
	shapes only: real assets replace these later without changing callers.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enemies = require(ReplicatedStorage:WaitForChild("Shared").Config.Enemies)
local PetConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.Pets)

local Models = {}

local CLASS_COLORS = {
	Warrior = Color3.fromRGB(214, 106, 80),
	Cleric = Color3.fromRGB(240, 220, 130),
}

local function part(parent, props)
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
	p.Parent = parent
	return p
end

local function eyes(model, root, offsetY, spread, forward)
	for _, side in ipairs({ -1, 1 }) do
		part(model, {
			Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = Color3.new(0, 0, 0),
			CFrame = root.CFrame * CFrame.new(side * spread, offsetY, forward),
		})
	end
end

function Models.Hero(classId)
	local model = Instance.new("Model")
	local color = CLASS_COLORS[classId] or Color3.fromRGB(200, 200, 200)
	local root = part(model, { Name = "Body", Size = Vector3.new(2, 2.4, 1), Color = color, CFrame = CFrame.new(0, 3, 0) })
	part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Color = Color3.fromRGB(245, 214, 180), CFrame = CFrame.new(0, 4.8, 0) })
	part(model, { Name = "Legs", Size = Vector3.new(1.6, 1.8, 0.9), Color = Color3.fromRGB(70, 74, 96), CFrame = CFrame.new(0, 1.0, 0) })
	model.PrimaryPart = root
	return model
end

function Models.Enemy(defId)
	local def = Enemies[defId]
	local look = (def and def.Look) or { Shape = "Ball", Color = { 200, 80, 80 }, Size = 3 }
	local c = Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3])
	local s = look.Size
	local model = Instance.new("Model")

	if look.Shape == "Biped" then
		local root = part(model, { Name = "Body", Size = Vector3.new(s * 0.45, s * 0.5, s * 0.3), Color = c, CFrame = CFrame.new(0, s * 0.55, 0) })
		part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.4, s * 0.4, s * 0.4), Color = c, CFrame = CFrame.new(0, s * 0.95, 0) })
		part(model, { Name = "Legs", Size = Vector3.new(s * 0.35, s * 0.3, s * 0.25), Color = c:Lerp(Color3.new(0, 0, 0), 0.4), CFrame = CFrame.new(0, s * 0.15, 0) })
		eyes(model, root, s * 0.4, s * 0.09, -s * 0.18)
		model.PrimaryPart = root
	elseif look.Shape == "Mushroom" then
		local root = part(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.5, s * 0.35, s * 0.35), Color = Color3.fromRGB(240, 230, 210), CFrame = CFrame.new(0, s * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.9, s * 0.6, s * 0.9), Color = c, CFrame = CFrame.new(0, s * 0.7, 0) })
		eyes(model, root, s * 0.25, s * 0.08, -s * 0.18)
		model.PrimaryPart = root
	else -- Ball (slimes)
		local root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.8, s), Color = c, Transparency = 0.1, Material = Enum.Material.Glass, CFrame = CFrame.new(0, s * 0.4, 0) })
		eyes(model, root, s * 0.1, s * 0.15, -s * 0.42)
		model.PrimaryPart = root
	end
	return model
end

function Models.Pet(petId)
	local def = petId and PetConfig.Defs[petId]
	local look = def and def.Look or { Shape = "Ball", Color = { 255, 180, 90 }, Size = 1.1 }
	local c = Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3])
	local s = look.Size
	local model = Instance.new("Model")
	local root
	if look.Shape == "Cat" then
		root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.9, s * 1.2), Color = c, CFrame = CFrame.new(0, s * 0.55, 0) })
		for _, side in ipairs({ -1, 1 }) do
			part(model, { Size = Vector3.new(s * 0.22, s * 0.4, s * 0.15), Color = c, CFrame = root.CFrame * CFrame.new(side * s * 0.28, s * 0.5, -s * 0.2) })
		end
		part(model, { Name = "Tail", Size = Vector3.new(s * 0.2, s * 0.2, s * 0.8), Color = c:Lerp(Color3.new(1, 1, 1), 0.5), CFrame = root.CFrame * CFrame.new(0, s * 0.1, s * 0.9) })
		eyes(model, root, s * 0.12, s * 0.2, -s * 0.5)
	elseif look.Shape == "Wisp" then
		root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.8, s * 0.8, s * 0.8), Color = c, Material = Enum.Material.Neon, Transparency = 0.2, CFrame = CFrame.new(0, s * 1.2, 0) })
		part(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s * 1.3, s * 1.3), Color = c, Material = Enum.Material.Neon, Transparency = 0.8, CFrame = root.CFrame })
	else
		root = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.9, s), Color = c, CFrame = CFrame.new(0, s * 0.55, 0) })
		eyes(model, root, s * 0.1, s * 0.2, -s * 0.45)
	end
	model.PrimaryPart = root
	return model
end

return Models
