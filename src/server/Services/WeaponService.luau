--[[
	WeaponService (ModuleScript)
	Location: ServerScriptService > Server > Services > WeaponService

	Gives a player the weapon of their chosen class as a Tool on their Roblox character.
	  WeaponService.Give(player, classId)   replaces any class weapon they hold; a copy in StarterGear keeps it after respawning
	  WeaponService.Clear(player)
]]

local ClassWeapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ClassWeapons)

local WeaponService = {}

local function isWeapon(child)
	return child:IsA("Tool") and child:GetAttribute(ClassWeapons.TAG) ~= nil
end

local function holders(player)
	return { player:FindFirstChildOfClass("Backpack"), player:FindFirstChild("StarterGear"), player.Character }
end

-- the class's back item (a Ranger's quiver) on the character; called every time, since a respawn gives a fresh character
function WeaponService.Wear(player, classId)
	if player.Character then
		ClassWeapons.AttachBack(player.Character, classId)
	end
end

function WeaponService.Clear(player)
	for _, holder in ipairs(holders(player)) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if isWeapon(child) then
					child:Destroy()
				end
			end
		end
	end
end

function WeaponService.Give(player, classId)
	-- already holding the right one: nothing to do
	local have = false
	for _, holder in ipairs(holders(player)) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if isWeapon(child) and child:GetAttribute(ClassWeapons.TAG) == classId then
					have = true
				end
			end
		end
	end
	WeaponService.Wear(player, classId)
	if have then
		return true
	end
	WeaponService.Clear(player)
	local backpackTool = ClassWeapons.Build(classId)
	if backpackTool == nil then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack == nil then
		backpackTool:Destroy()
		return false
	end
	backpackTool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(backpackTool) -- wield it straight away
	end
	local gear = player:FindFirstChild("StarterGear")
	if gear then
		local copy = ClassWeapons.Build(classId)
		if copy then
			copy.Parent = gear
		end
	end
	return true
end

return WeaponService
