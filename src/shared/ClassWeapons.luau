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

local WOOD = Color3.fromRGB(110, 76, 48)
local STEEL = Color3.fromRGB(205, 210, 225)
local GOLD = Color3.fromRGB(240, 200, 90)

-- { Size, Pos (offset from the grip), Color, Material?, Shape?, Rot? (CFrame.Angles args), Neon? }
local function recipe(classId)
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
		return {
			{ Vector3.new(0.3, 1.0, 0.3), Vector3.new(0, 0, 0), WOOD },
			{ Vector3.new(0.22, 1.7, 0.22), Vector3.new(0, 1.3, -0.35), Color3.fromRGB(135, 95, 55), nil, nil, { -0.35, 0, 0 } },
			{ Vector3.new(0.22, 1.7, 0.22), Vector3.new(0, -1.3, -0.35), Color3.fromRGB(135, 95, 55), nil, nil, { 0.35, 0, 0 } },
			{ Vector3.new(0.05, 3.7, 0.05), Vector3.new(0, 0, 0.1), Color3.fromRGB(240, 235, 210) },
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
			part.CFrame = handle.CFrame * CFrame.new(spec[2]) * CFrame.Angles(rot[1], rot[2], rot[3])
			part.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
	end
	return tool
end

return ClassWeapons
