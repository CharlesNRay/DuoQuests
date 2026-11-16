--[[
	CosmeticsVisuals (ModuleScript): draws the cosmetics.
	  CosmeticsVisuals.Init()        name tags (title + coloured name) and auras on every player's character, from the
	                                 attributes the server sets (CosAura, CosName, CosTitle)
	  CosmeticsVisuals.SetKill(id)   the local player's kill effect (nil = none)
	  CosmeticsVisuals.KillEffect(parent, position)   a burst where an enemy fell (the fight scene calls this)

	NOT yet seen in Studio.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared").Cosmetics)

local CosmeticsVisuals = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 80)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 230, 120)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 120, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
})

local killId = nil

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function colours(def)
	if def.Rainbow then
		return RAINBOW
	end
	return ColorSequence.new(c3(def.Color), c3(def.Color2 or def.Color))
end

local function auraEmitter(def)
	local e = Instance.new("ParticleEmitter")
	e.Name = "CosAura"
	e.Texture = SPARKLE
	e.Color = colours(def)
	e.LightEmission = 1
	e.Rate = 45
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Shape = Enum.ParticleEmitterShape.Cylinder
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	return e
end

local function nameColor(def)
	return if def and not def.Rainbow then c3(def.Color) else Color3.new(1, 1, 1)
end

local function refresh(player, character)
	if not character or not character.Parent then
		return
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our own tag replaces the default name
	end
	-- name tag
	if head then
		local old = head:FindFirstChild("CosTag")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "CosTag"
		gui.Size = UDim2.fromOffset(220, 44)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 80
		gui.Adornee = head
		gui.Parent = head
		local title = player:GetAttribute("CosTitle")
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0, 22)
		nameLabel.Position = UDim2.fromOffset(0, if title then 20 else 10)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 17
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.Text = player.DisplayName
		local nameDef = Cosmetics.Def(player:GetAttribute("CosName") or "")
		nameLabel.TextColor3 = nameColor(nameDef)
		nameLabel.Parent = gui
		if nameDef and nameDef.Rainbow then
			local grad = Instance.new("UIGradient")
			grad.Color = RAINBOW
			grad.Parent = nameLabel
		end
		if title then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, 0, 18)
			t.Font = Enum.Font.Gotham
			t.TextSize = 13
			t.TextStrokeTransparency = 0.5
			t.TextColor3 = Color3.fromRGB(255, 225, 140)
			t.Text = title
			t.Parent = gui
		end
	end
	-- aura
	if root then
		local old = root:FindFirstChild("CosAura")
		if old then
			old:Destroy()
		end
		local def = Cosmetics.Def(player:GetAttribute("CosAura") or "")
		if def then
			auraEmitter(def).Parent = root
		end
	end
end

local function watch(player)
	local function redo()
		refresh(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			character:WaitForChild("Head", 5)
			refresh(player, character)
		end)
	end)
	for _, attribute in ipairs({ "CosAura", "CosName", "CosTitle" }) do
		player:GetAttributeChangedSignal(attribute):Connect(redo)
	end
	if player.Character then
		redo()
	end
end

function CosmeticsVisuals.Init()
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

function CosmeticsVisuals.SetKill(id)
	killId = id
end

function CosmeticsVisuals.KillEffect(parent, position)
	local def = killId and Cosmetics.Def(killId)
	if not def or not parent then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = colours(def)
	e.LightEmission = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = anchor
	e:Emit(if def.Id == "Kill_Soulfire" or def.Id == "Kill_Lightning" then 40 else 28)
	Debris:AddItem(anchor, 2)
end

return CosmeticsVisuals
