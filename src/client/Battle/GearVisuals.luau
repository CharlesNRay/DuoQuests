--[[
	GearVisuals (ModuleScript): dresses a hero model with what its owner wears.
	  GearVisuals.Apply(model, look)   look = Gear.Look(equipped): { Weapon?, Armor?, Helmet?, Boots?, Amulet?, SetId?, SetCount? }
	Adds simple parts (blade, shoulder pads, helm crest, boots trim) tinted by rarity, and a set aura
	(sparkles at 2 pieces, plus glow and light at 3). Everything is parented to the model so it moves with it.
	Parts are tagged "GearVisual" and cleared before each Apply, so calling it again is safe.
]]
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Config.Rarities)

local GearVisuals = {}

local SET_COLORS = {
	Color3.fromRGB(120, 220, 110), Color3.fromRGB(90, 170, 90), Color3.fromRGB(170, 170, 180), Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 200, 90), Color3.fromRGB(130, 210, 255), Color3.fromRGB(255, 110, 60), Color3.fromRGB(90, 150, 90),
	Color3.fromRGB(80, 170, 220), Color3.fromRGB(235, 245, 255),
}

local function rarityColor(rarity)
	local def = Rarities[rarity] or Rarities.Common
	local c = def.Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function shiny(rarity)
	return rarity == "Epic" or rarity == "Legendary"
end

local function find(model, ...)
	for _, name in ipairs({ ... }) do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

local function add(model, anchor, offset, size, color, rarity, shape)
	local p = Instance.new("Part")
	p.Name = "GearVisual"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Shape = shape or Enum.PartType.Block
	p.Material = if shiny(rarity) then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = anchor.CFrame * offset
	p.Parent = model
	return p
end

function GearVisuals.Apply(model, look)
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "GearVisual" then
			child:Destroy()
		end
	end
	if look == nil then
		return
	end
	local torso = find(model, "UpperTorso", "Torso", "Body")
	local head = find(model, "Head")
	local hand = find(model, "RightHand", "Right Arm", "RightArm")
	local feet = { find(model, "LeftFoot", "Left Leg"), find(model, "RightFoot", "Right Leg") }
	if torso == nil then
		return
	end
	if look.Weapon and hand then
		local color = rarityColor(look.Weapon)
		local wood, steel = Color3.fromRGB(110, 78, 46), Color3.fromRGB(190, 195, 205)
		local rarity = look.Weapon
		local glow
		local class = look.ClassId
		if class == "Ranger" then
			-- a bow held upright: curved limbs, a string, grip in the hand
			add(model, hand, CFrame.new(0, -0.2, -0.6) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(0.18, 1.5, 0.18), wood, "Common")
			add(model, hand, CFrame.new(0, 0.55, -0.35) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(0.18, 1.3, 0.18), wood, "Common")
			add(model, hand, CFrame.new(0, -0.95, -0.35) * CFrame.Angles(math.rad(25), 0, 0), Vector3.new(0.18, 1.3, 0.18), wood, "Common")
			glow = add(model, hand, CFrame.new(0, -0.2, -0.05), Vector3.new(0.06, 3.3, 0.06), color, rarity)
		elseif class == "Mage" or class == "Summoner" then
			add(model, hand, CFrame.new(0, -0.2, -0.2), Vector3.new(0.2, 0.2, 3.4), wood, "Common")
			glow = add(model, hand, CFrame.new(0, -0.2, -2.1), Vector3.new(0.55, 0.55, 0.55), color, rarity, Enum.PartType.Ball)
		elseif class == "Cleric" then
			add(model, hand, CFrame.new(0, -0.2, -0.4), Vector3.new(0.22, 0.22, 2.2), wood, "Common")
			glow = add(model, hand, CFrame.new(0, -0.2, -1.7), Vector3.new(0.6, 0.6, 0.6), color, rarity, Enum.PartType.Ball)
		elseif class == "Rogue" then
			glow = add(model, hand, CFrame.new(0, -0.2, -0.8), Vector3.new(0.15, 0.4, 1.4), color, rarity)
			add(model, hand, CFrame.new(0, -0.2, 0), Vector3.new(0.3, 0.3, 0.3), wood, "Common")
			add(model, hand, CFrame.new(0.5, -0.2, -0.6), Vector3.new(0.12, 0.35, 1.1), color, rarity)
		else
			glow = add(model, hand, CFrame.new(0, -0.2, -1.6), Vector3.new(0.25, 0.25, 3.2), color, rarity)
			add(model, hand, CFrame.new(0, -0.2, -0.1), Vector3.new(0.9, 0.3, 0.3), Color3.fromRGB(90, 70, 50), "Common")
		end
		if shiny(look.Weapon) and glow then
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = color, 7, 1.2
			light.Parent = glow
		end
		_ = steel
	end
	if look.Armor then
		local color = rarityColor(look.Armor)
		local w = torso.Size.X / 2 + 0.35
		add(model, torso, CFrame.new(-w, torso.Size.Y / 2 - 0.2, 0), Vector3.new(0.9, 0.5, 1.3), color, look.Armor, nil)
		add(model, torso, CFrame.new(w, torso.Size.Y / 2 - 0.2, 0), Vector3.new(0.9, 0.5, 1.3), color, look.Armor, nil)
		add(model, torso, CFrame.new(0, 0, torso.Size.Z / 2 + 0.1), Vector3.new(torso.Size.X * 0.7, torso.Size.Y * 0.45, 0.2), color, look.Armor)
	end
	if look.Helmet and head then
		add(model, head, CFrame.new(0, head.Size.Y / 2 + 0.25, 0), Vector3.new(0.35, 0.6, head.Size.Z * 0.9), rarityColor(look.Helmet), look.Helmet)
	end
	if look.Boots then
		for _, foot in ipairs(feet) do
			if foot then
				add(model, foot, CFrame.new(0, -foot.Size.Y / 2 + 0.15, 0), Vector3.new(foot.Size.X + 0.15, 0.3, foot.Size.Z + 0.15), rarityColor(look.Boots), look.Boots)
			end
		end
	end
	if look.Amulet then
		add(model, torso, CFrame.new(0, torso.Size.Y / 2 - 0.5, -torso.Size.Z / 2 - 0.1), Vector3.new(0.4, 0.4, 0.2), rarityColor(look.Amulet), look.Amulet, Enum.PartType.Ball)
	end
	if look.SetId and (look.SetCount or 0) >= 2 then
		local color = SET_COLORS[((look.SetId - 1) % #SET_COLORS) + 1]
		local aura = add(model, torso, CFrame.new(), Vector3.new(1, 1, 1), color, "Common", Enum.PartType.Ball)
		aura.Transparency = 1
		local fx = Instance.new("ParticleEmitter")
		fx.Color = ColorSequence.new(color)
		fx.LightEmission = 0.8
		fx.Rate = if look.SetCount >= 3 then 22 else 10
		fx.Lifetime = NumberRange.new(1, 1.8)
		fx.Speed = NumberRange.new(0.5, 1.5)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		fx.Parent = aura
		if look.SetCount >= 3 then
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = color, 10, 1.5
			light.Parent = aura
		end
	end
end

return GearVisuals
