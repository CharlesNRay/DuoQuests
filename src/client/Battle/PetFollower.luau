--[[
	PetFollower (ModuleScript): your active pet trots behind you around town.

	  PetFollower.new(getPetIds)    getPetIds() -> list of pet ids (usually one) to follow the local player
	The pets are local models (other players see no pet yet). They hide while a scripted camera is in use: the main menu,
	the boss arena, and any watched battle.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Models = require(script.Parent.Models)

local PetFollower = {}

local function prepare(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	model.PrimaryPart = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
end

function PetFollower.new(getPetIds)
	local self = { Pets = {} }
	local folder = Instance.new("Folder")
	folder.Name = "DuoQuestPets"
	folder.Parent = workspace

	local function sync(ids)
		for i = 1, math.max(#ids, #self.Pets) do
			local want, have = ids[i], self.Pets[i]
			if have and have.Id ~= want then
				have.Model:Destroy()
				self.Pets[i] = nil
				have = nil
			end
			if want and not have then
				local model = Models.Pet(want)
				prepare(model)
				model.Parent = folder
				self.Pets[i] = { Id = want, Model = model, Pos = nil, Phase = i * 1.7 }
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local ok, ids = pcall(getPetIds)
		sync(if ok and type(ids) == "table" then ids else {})
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local hidden = root == nil or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
		for index, pet in pairs(self.Pets) do
			pet.Model.Parent = if hidden then nil else folder
			if not hidden and pet.Model.PrimaryPart then
				local side = if index % 2 == 1 then 1 else -1
				local anchor = root.CFrame * CFrame.new(side * 2.6, -2.6, 3.4 + math.floor((index - 1) / 2) * 2)
				local target = Vector3.new(anchor.Position.X, anchor.Position.Y, anchor.Position.Z)
				if pet.Pos == nil or (pet.Pos - target).Magnitude > 40 then
					pet.Pos = target -- first frame, or you teleported
				end
				local before = pet.Pos
				pet.Pos = before:Lerp(target, 1 - math.exp(-dt * 5))
				local moving = (pet.Pos - before).Magnitude / math.max(dt, 1e-3)
				local bob = if moving > 1 then math.abs(math.sin(os.clock() * 11 + pet.Phase)) * 0.5 else math.sin(os.clock() * 2 + pet.Phase) * 0.05
				local look = root.Position - pet.Pos
				local face = if Vector3.new(look.X, 0, look.Z).Magnitude > 0.5 then CFrame.lookAt(pet.Pos, Vector3.new(root.Position.X, pet.Pos.Y, root.Position.Z)) * CFrame.Angles(0, math.pi, 0) else CFrame.new(pet.Pos) * (pet.Face or CFrame.new()).Rotation
				pet.Face = face
				pet.Model:PivotTo(face.Rotation + pet.Pos + Vector3.new(0, bob, 0))
			end
		end
	end)
	return self
end

return PetFollower
