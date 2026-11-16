--[[
	ClassWeapons (ModuleScript)
	Location: ReplicatedStorage > Shared > ClassWeapons

	Every class has a weapon the player wields on their own Roblox character (a Tool). It is built from simple parts so it
	needs no assets. The same builder is used by the server (the real tool, given when a class is chosen) and by the class picker
	(a local-only preview the player can wield before choosing).

	  ClassWeapons.Info(classId)   -> { Name, Text, Blurb } from Config/Classes, or nil
	  ClassWeapons.Build(classId)  -> Tool (Handle + welded parts), or nil
	  ClassWeapons.TAG             attribute set on every built tool ("ClassWeapon" = classId) so it can be found and replaced

	Weapons point along the handle's -Z axis (forward, the way a held tool points).
]]

local Classes = require(script.Parent.Config.Classes)

local ClassWeapons = {}
ClassWeapons.TAG = "ClassWeapon"

function ClassWeapons.Info(classId)
	local def = Classes[classId]
	if def == nil or def.Weapon == nil then
		return nil
	end
	return { Name = def.Weapon.Name, Text = def.Weapon.Text, Blurb = def.Blurb, Role = def.Role }
end

-- a straight piece running from point a to point b (grip space), used for curved limbs, strings and shafts
local function seg(a, b, thickness, color, material)
	local mid = (a + b) / 2
	return { Vector3.new(thickness, thickness, (b - a).Magnitude), mid, color, material, nil, nil, CFrame.lookAt(mid, b) }
end

-- { Size, Pos (offset from the grip), Color, Material?, Shape?, Rot? (CFrame.Angles args), CFrame? (replaces Pos and Rot) }
local function recipe(classId)
	local WOOD = Color3.fromRGB(110, 76, 48)
	local STEEL = Color3.fromRGB(205, 210, 225)
	local GOLD = Color3.fromRGB(240, 200, 90)
	if classId == "Warrior" then
		return {
			{ Vector3.new(0.28, 0.28, 1.2), Vector3.new(0, 0, 0), WOOD },
			{ Vector3.new(1.5, 0.28, 0.3), Vector3.new(0, 0, -0.75), GOLD, Enum.Material.Metal },
			{ Vector3.new(0.34, 0.14, 3.4), Vector3.new(0, 0, -2.5), STEEL, Enum.Material.Metal },
			{ Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 0, 0.7), GOLD, Enum.Material.Metal, Enum.PartType.Ball },
		}
	elseif classId == "Cleric" then
		return {
			{ Vector3.new(0.28, 0.28, 3.2), Vector3.new(0, 0, -0.8), WOOD },
			{ Vector3.new(1, 1, 1), Vector3.new(0, 0, -2.7), GOLD, Enum.Material.Metal, Enum.PartType.Ball },
			{ Vector3.new(1.5, 0.2, 0.2), Vector3.new(0, 0, -2.7), Color3.fromRGB(255, 245, 190), Enum.Material.Neon },
			{ Vector3.new(0.2, 1.5, 0.2), Vector3.new(0, 0, -2.7), Color3.fromRGB(255, 245, 190), Enum.Material.Neon },
		}
	elseif classId == "Mage" then
		return {
			{ Vector3.new(0.26, 0.26, 4.6), Vector3.new(0, 0, -1.2), WOOD },
			{ Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0, -3.7), Color3.fromRGB(160, 120, 255), Enum.Material.Neon, Enum.PartType.Ball },
			{ Vector3.new(0.14, 1.3, 0.14), Vector3.new(0.5, 0, -3.5), GOLD, Enum.Material.Metal },
			{ Vector3.new(0.14, 1.3, 0.14), Vector3.new(-0.5, 0, -3.5), GOLD, Enum.Material.Metal },
		}
	elseif classId == "Ranger" then
		-- a held bow stands upright in front of the archer (the handle's Y axis is up, -Z is toward the target).
		-- The grip bulges toward the target and both limbs curve back toward the archer, where the string joins the two tips.
		local LIMB = Color3.fromRGB(135, 95, 55)
		local CORD = Color3.fromRGB(240, 235, 210)
		local tipUp, tipDown = Vector3.new(0, 2.05, 0.62), Vector3.new(0, -2.05, 0.62)
		return {
			{ Vector3.new(0.3, 1.0, 0.34), Vector3.new(0, 0, 0), WOOD },
			seg(Vector3.new(0, 0.45, -0.02), Vector3.new(0, 1.3, 0.2), 0.24, LIMB),
			seg(Vector3.new(0, 1.3, 0.2), tipUp, 0.2, LIMB),
			seg(Vector3.new(0, -0.45, -0.02), Vector3.new(0, -1.3, 0.2), 0.24, LIMB),
			seg(Vector3.new(0, -1.3, 0.2), tipDown, 0.2, LIMB),
			{ Vector3.new(0.3, 0.3, 0.3), tipUp, GOLD, Enum.Material.Metal, Enum.PartType.Ball }, -- nocks on the tips hold the string
			{ Vector3.new(0.3, 0.3, 0.3), tipDown, GOLD, Enum.Material.Metal, Enum.PartType.Ball },
			seg(tipUp, tipDown, 0.05, CORD),
			-- an arrow resting on the grip, nocked on the string
			seg(Vector3.new(0.2, 0.1, 0.62), Vector3.new(0.2, 0.1, -1.4), 0.07, Color3.fromRGB(200, 170, 120)),
			{ Vector3.new(0.16, 0.16, 0.34), Vector3.new(0.2, 0.1, -1.55), STEEL, Enum.Material.Metal },
			{ Vector3.new(0.04, 0.3, 0.3), Vector3.new(0.2, 0.1, 0.45), Color3.fromRGB(210, 80, 70) },
			{ Vector3.new(0.3, 0.04, 0.3), Vector3.new(0.2, 0.1, 0.45), Color3.fromRGB(235, 235, 235) },
		}
	elseif classId == "Rogue" then
		return {
			{ Vector3.new(0.24, 0.24, 0.9), Vector3.new(0, 0, 0), Color3.fromRGB(60, 50, 80) },
			{ Vector3.new(0.9, 0.18, 0.22), Vector3.new(0, 0, -0.55), Color3.fromRGB(150, 110, 210), Enum.Material.Metal },
			{ Vector3.new(0.22, 0.1, 2.0), Vector3.new(0, 0, -1.6), Color3.fromRGB(220, 220, 235), Enum.Material.Metal },
			{ Vector3.new(0.05, 0.12, 1.7), Vector3.new(0, 0, -1.55), Color3.fromRGB(150, 110, 210), Enum.Material.Neon },
		}
	elseif classId == "Summoner" then
		return {
			{ Vector3.new(1.2, 0.2, 1.6), Vector3.new(0, 0, -0.3), Color3.fromRGB(70, 55, 100) },
			{ Vector3.new(1.05, 0.12, 1.45), Vector3.new(0, 0.12, -0.3), Color3.fromRGB(240, 235, 215) },
			{ Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 0.3, -0.3), Color3.fromRGB(110, 235, 210), Enum.Material.Neon, Enum.PartType.Ball },
			{ Vector3.new(0.14, 0.14, 1.7), Vector3.new(-0.62, 0.05, -0.3), GOLD, Enum.Material.Metal },
			{ Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 1.3, -0.3), Color3.fromRGB(150, 255, 230), Enum.Material.Neon, Enum.PartType.Ball },
		}
	end
	return nil
end

function ClassWeapons.Build(classId)
	local info = ClassWeapons.Info(classId)
	local parts = recipe(classId)
	if info == nil or parts == nil then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = info.Name
	tool.ToolTip = info.Text
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(ClassWeapons.TAG, classId)

	local handle
	for index, spec in ipairs(parts) do
		local part = Instance.new("Part")
		part.Size = spec[1]
		part.Color = spec[3]
		part.Material = spec[4] or Enum.Material.SmoothPlastic
		part.Shape = spec[5] or Enum.PartType.Block
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if index == 1 then
			part.Name = "Handle"
			part.Parent = tool
			handle = part
		else
			part.Name = "Part" .. index
			local rot = spec[6] or { 0, 0, 0 }
			part.CFrame = handle.CFrame * (spec[7] or (CFrame.new(spec[2]) * CFrame.Angles(rot[1], rot[2], rot[3])))
			part.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
	end
	return tool
end

-- Things worn on the back: the Ranger carries a quiver of arrows. Attached to the character's torso (replaces any earlier one).
ClassWeapons.BACK_NAME = "ClassBack"
local function backParts(classId)
	if classId == "Ranger" then
		local LEATHER = Color3.fromRGB(120, 80, 50)
		local list = {
			-- the sack: a leaning leather tube, a darker mouth ring and a strap over the shoulder
			{ Vector3.new(1.9, 0.62, 0.62), CFrame.new(0.28, 0.1, 0.75) * CFrame.Angles(0, 0, math.rad(90 + 14)), LEATHER, Enum.Material.Leather, Enum.PartType.Cylinder },
			{ Vector3.new(0.18, 0.74, 0.74), CFrame.new(0.5, 1.02, 0.75) * CFrame.Angles(0, 0, math.rad(90 + 14)), Color3.fromRGB(80, 54, 34), Enum.Material.Leather, Enum.PartType.Cylinder },
			{ Vector3.new(0.18, 2.3, 0.1), CFrame.new(0, 0.1, 0.56) * CFrame.Angles(0, 0, math.rad(-38)), Color3.fromRGB(85, 58, 38), Enum.Material.Leather },
			{ Vector3.new(0.18, 2.3, 0.1), CFrame.new(0, 0.1, -0.56) * CFrame.Angles(0, 0, math.rad(-38)), Color3.fromRGB(85, 58, 38), Enum.Material.Leather },
		}
		-- a bundle of arrows sticking out of the top: shafts with coloured fletching
		local fletch = { Color3.fromRGB(210, 80, 70), Color3.fromRGB(235, 235, 235), Color3.fromRGB(90, 160, 90), Color3.fromRGB(235, 200, 90), Color3.fromRGB(210, 80, 70), Color3.fromRGB(235, 235, 235) }
		for i = 1, 6 do
			local dx = (i - 3.5) * 0.13
			local tilt = math.rad(14 - (i - 3.5) * 5)
			local cf = CFrame.new(0.5 + dx, 1.45, 0.75 + ((i % 2) - 0.5) * 0.28) * CFrame.Angles(0, 0, tilt)
			table.insert(list, { Vector3.new(0.07, 1.0, 0.07), cf, Color3.fromRGB(205, 175, 125) })
			table.insert(list, { Vector3.new(0.28, 0.32, 0.05), cf * CFrame.new(0, 0.5, 0), fletch[i] })
		end
		return list
	end
	return nil
end

function ClassWeapons.AttachBack(character, classId, name)
	name = name or ClassWeapons.BACK_NAME
	if character == nil then
		return nil
	end
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local list = backParts(classId)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if list == nil or torso == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for index, spec in ipairs(list) do
		local part = Instance.new("Part")
		part.Name = "Piece" .. index
		part.Size = spec[1]
		part.Color = spec[3]
		part.Material = spec[4] or Enum.Material.SmoothPlastic
		part.Shape = spec[5] or Enum.PartType.Block
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = torso.CFrame * spec[2]
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, part
		weld.Parent = part
	end
	model.Parent = character
	return model
end

return ClassWeapons
