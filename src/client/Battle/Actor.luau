--[[
	Actor (ModuleScript): one fighter in the scene. Owns the model, its place
	on the ground, a health bar, and short procedural animations (lunge, flinch,
	fall, cheer) so combat reads even without authored animations.

	  Actor.new(scene, model, { Name, Facing = 1|-1, MaxHealth })
	  actor:Place(x)            put the ground position at x (z = 0)
	  actor:SetHealth(health)   updates the bar
	  actor:Lunge(towardX) / Flinch() / Fall() / Rise() / Cheer() / FadeOut()
	  actor:SetModel(model)     swap the body (e.g. the real avatar) keeping state
	  actor:SetAura(builder, key)  a cosmetic aura emitter that follows the body
	  actor:SetGhost(on)        see-through look for an offline partner's ghost
	  actor:Pos()               world position of the chest, for effects
	  actor:Destroy()
]]
local RunService = game:GetService("RunService")
local GearVisuals = require(script.Parent.GearVisuals)

local Actor = {}
Actor.__index = Actor

local function anim(duration, step)
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			step(a)
			if a >= 1 then
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function measure(model)
	local boxCF, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	return pivot.Position.Y - (boxCF.Position.Y - size.Y / 2), size.Y
end

function Actor.new(scene, model, info)
	local self = setmetatable({
		Scene = scene,
		Name = info.Name,
		Facing = info.Facing or 1,
		MaxHealth = math.max(1, info.MaxHealth or 1),
		Health = info.MaxHealth or 1,
		X = 0,
		Offset = CFrame.new(),
		Alive = true,
		Phase = math.random() * 6,
		Destroyed = false,
	}, Actor)
	self:SetModel(model)

	self.Bar = Instance.new("BillboardGui")
	self.Bar.Size = UDim2.fromOffset(70, 10)
	self.Bar.AlwaysOnTop = true
	self.Bar.MaxDistance = 70 -- far fights show no bars (they would pile up)
	self.Bar.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	self.Back = Instance.new("Frame")
	self.Back.Size = UDim2.fromScale(1, 1)
	self.Back.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	self.Back.BorderSizePixel = 0
	self.Back.Parent = self.Bar
	self.Fill = Instance.new("Frame")
	self.Fill.Size = UDim2.fromScale(1, 1)
	self.Fill.BackgroundColor3 = if self.Facing == 1 then Color3.fromRGB(96, 214, 130) else Color3.fromRGB(235, 90, 90)
	self.Fill.BorderSizePixel = 0
	self.Fill.Parent = self.Back
	self.Bar.Adornee = self.Model.PrimaryPart
	self.Bar.Parent = scene.Folder

	self.Conn = RunService.Heartbeat:Connect(function()
		if self.Destroyed then
			return
		end
		local bob = if self.Alive then math.sin(os.clock() * 3 + self.Phase) * 0.12 else 0
		local base = CFrame.lookAt(Vector3.new(self.X, self.Height + bob, self.Z or 0) + scene.Origin, Vector3.new(self.X, self.Height + bob, self.Z or 0) + scene.Origin + Vector3.new(self.Facing, 0, 0))
		self.Model:PivotTo(base * self.Offset)
		self:_animate(os.clock())
	end)
	return self
end

-- Monster parts tagged by Battle/Creatures move on their own (wings flap, legs walk, tails wag, jaws open when attacking).
function Actor:_collectParts(model)
	self.AnimParts = {}
	local pivot = model:GetPivot()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("Anim")
			if kind then
				table.insert(self.AnimParts, {
					Part = d, Kind = kind, Rel = pivot:ToObjectSpace(d.CFrame), Hinge = d:GetAttribute("Hinge") or Vector3.zero,
					Side = d:GetAttribute("Side") or 1, BaseSize = d.Size,
				})
			end
		end
	end
end

function Actor:_animate(t)
	local parts = self.AnimParts
	if not parts or #parts == 0 then
		return
	end
	local pivot = self.Model:GetPivot()
	local atk = self.AttackAmt or 0
	local alive = self.Alive
	for _, info in ipairs(parts) do
		local k, side, ph = info.Kind, info.Side, self.Phase
		local rot, move, size = CFrame.identity, Vector3.zero, nil
		if not alive then
			-- limp
		elseif k == "Wing" then
			rot = CFrame.Angles(0, 0, side * math.sin(t * 13 + ph) * 0.75)
		elseif k == "Tail" then
			rot = CFrame.Angles(0, math.sin(t * 4 + ph + side) * 0.45 * side, 0)
		elseif k == "Arm" then
			rot = CFrame.Angles(-atk * 1.7 + math.sin(t * 2.6 + ph + side * 1.5) * 0.28, 0, 0)
		elseif k == "Leg" then
			rot = CFrame.Angles(side * math.sin(t * 5 + ph) * (0.22 + atk * 0.2), 0, 0)
		elseif k == "Jaw" then
			rot = CFrame.Angles(atk * 0.7 + math.max(0, math.sin(t * 2 + ph)) * 0.08, 0, 0)
		elseif k == "Head" then
			rot = CFrame.Angles(math.sin(t * 2.2 + ph) * 0.07 - atk * 0.3, math.sin(t * 1.3 + ph) * 0.18, 0)
		elseif k == "Claw" then
			rot = CFrame.Angles(0, side * (math.sin(t * 3 + ph) * 0.15 + atk * 0.6), 0)
		elseif k == "Float" then
			move = Vector3.new(0, math.sin(t * 2.4 + ph) * 0.25, 0)
		elseif k == "Flame" then
			rot = CFrame.Angles(0, 0, side * math.sin(t * 6 + ph) * 0.5)
			move = Vector3.new(0, math.sin(t * 5 + ph + side) * 0.18, 0)
		elseif k == "Squish" then
			local f = math.sin(t * 3.2 + ph) * 0.09 - atk * 0.15
			size = Vector3.new(info.BaseSize.X * (1 - f), info.BaseSize.Y * (1 + f), info.BaseSize.Z * (1 - f))
		end
		info.Part.CFrame = pivot * info.Rel * CFrame.new(move) * CFrame.new(info.Hinge) * rot * CFrame.new(-info.Hinge)
		if size then
			info.Part.Size = size
		end
	end
end

local GHOST_FADE = 0.55

local function applyGhost(model, on)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if on then
				if d:GetAttribute("OrigTransparency") == nil then
					d:SetAttribute("OrigTransparency", d.Transparency)
				end
				d.Transparency = math.max(d.Transparency, GHOST_FADE)
			elseif d:GetAttribute("OrigTransparency") ~= nil then
				d.Transparency = d:GetAttribute("OrigTransparency")
				d:SetAttribute("OrigTransparency", nil)
			end
		end
	end
end

function Actor:SetGhost(on)
	self.Ghost = on == true
	applyGhost(self.Model, self.Ghost)
end

-- worn-gear look (Gear.Look data from the fight roster); redrawn whenever the body is swapped
function Actor:SetLook(look)
	self.Look = look
	GearVisuals.Apply(self.Model, look)
	for _, d in ipairs(self.Model:GetDescendants()) do
		if d.Name == "GearVisual" and d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

function Actor:SetModel(model)
	local old = self.Model
	local height, top = measure(model)
	self.Height = height
	if self.Look then
		GearVisuals.Apply(model, self.Look)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model.Parent = self.Scene.Folder
	self.Model = model
	self:_collectParts(model)
	if self.Ghost then
		applyGhost(model, true)
	end
	if self.AuraBuilder then
		self.AuraBuilder().Parent = model.PrimaryPart -- the aura follows the body when it is swapped
	end
	if self.Bar then
		self.Bar.Adornee = model.PrimaryPart
	end
	self.Top = top
	if self.Bar then
		self.Bar.StudsOffsetWorldSpace = Vector3.new(0, top / 2 + 1, 0)
	end
	if old then
		old:Destroy()
	end
end

-- A cosmetic aura (a function that builds a ParticleEmitter, or nil for none); kept across body swaps.
function Actor:SetAura(builder, key)
	if self.AuraKey == key then
		return
	end
	self.AuraKey = key
	self.AuraBuilder = builder
	local root = self.Model.PrimaryPart
	if root then
		local old = root:FindFirstChild("CosAura")
		if old then
			old:Destroy()
		end
		if builder then
			builder().Parent = root
		end
	end
end

function Actor:Place(x, z)
	self.X = x
	if z ~= nil then
		self.Z = z
	end
	if self.Bar then
		self.Bar.StudsOffsetWorldSpace = Vector3.new(0, self.Top / 2 + 1, 0)
	end
end

function Actor:SetHealth(health)
	self.Health = math.clamp(health, 0, self.MaxHealth)
	self.Fill.Size = UDim2.fromScale(self.Health / self.MaxHealth, 1)
end

function Actor:Pos()
	return self.Scene.Origin + Vector3.new(self.X, self.Height + self.Top * 0.2, self.Z or 0)
end

function Actor:Lunge(towardX)
	local dir = if towardX > self.X then 1 else -1
	anim(0.28, function(a)
		self.Offset = CFrame.new(0, 0, -dir * self.Facing * 3.2 * math.sin(math.pi * a))
	end)
end

-- One attack animation. style: "Lunge" (default), "Slam" (jump and crash down), "Pounce" (an arc at the target),
-- "Shoot" (rear back, recoil), "Cast" (rise and glow), "Bite" (short snap), "Spin".
function Actor:Attack(style, towardX)
	local dir = if towardX and towardX > self.X then 1 else -1
	local fwd = -dir * self.Facing
	if style == nil or style == "Lunge" then
		self.AttackAmt = 1
		anim(0.28, function(a)
			self.Offset = CFrame.new(0, 0, fwd * 3.2 * math.sin(math.pi * a))
			self.AttackAmt = math.sin(math.pi * a)
		end)
	elseif style == "Slam" then
		anim(0.55, function(a)
			local up = if a < 0.45 then math.sin(a / 0.45 * math.pi / 2) else math.cos((a - 0.45) / 0.55 * math.pi / 2)
			self.Offset = CFrame.new(0, 2.4 * up, fwd * 1.5 * math.sin(math.pi * a)) * CFrame.Angles(math.rad(-18) * up, 0, 0)
			self.AttackAmt = if a < 0.45 then a / 0.45 else math.max(0, 1 - (a - 0.45) / 0.3)
		end)
	elseif style == "Pounce" then
		anim(0.4, function(a)
			self.Offset = CFrame.new(0, 3 * math.sin(math.pi * a), fwd * 5.5 * math.sin(math.pi * a))
			self.AttackAmt = math.sin(math.pi * a)
		end)
	elseif style == "Bite" then
		anim(0.24, function(a)
			self.Offset = CFrame.new(0, 0, fwd * 1.8 * math.sin(math.pi * a))
			self.AttackAmt = math.sin(math.pi * math.min(1, a * 1.4))
		end)
	elseif style == "Shoot" then
		anim(0.4, function(a)
			self.Offset = CFrame.new(0, 0.4 * math.sin(math.pi * a), -fwd * 1.1 * math.sin(math.pi * math.min(1, a * 1.3)))
			self.AttackAmt = math.sin(math.pi * a)
		end)
	elseif style == "Cast" then
		anim(0.7, function(a)
			self.Offset = CFrame.new(0, 1.6 * math.sin(math.pi * a), 0)
			self.AttackAmt = math.sin(math.pi * a)
		end)
	elseif style == "Spin" then
		anim(0.5, function(a)
			self.Offset = CFrame.new(0, 0.6 * math.sin(math.pi * a), fwd * 1.5 * math.sin(math.pi * a)) * CFrame.Angles(0, math.pi * 2 * a, 0)
			self.AttackAmt = math.sin(math.pi * a)
		end)
	else
		self:Lunge(towardX)
	end
end

function Actor:Flinch()
	anim(0.2, function(a)
		self.Offset = CFrame.new((1 - a) * -self.Facing * 0.8, 0, 0)
	end)
end

function Actor:Cheer()
	anim(0.6, function(a)
		self.Offset = CFrame.new(0, math.abs(math.sin(a * math.pi * 2)) * 1.6, 0)
	end)
end

function Actor:Fall()
	self.Alive = false
	self.AttackAmt = 0
	anim(0.4, function(a)
		self.Offset = CFrame.new(0, -self.Height * 0.6 * a, 0) * CFrame.Angles(0, 0, math.rad(80) * a * -self.Facing)
	end)
end

function Actor:Rise()
	self.Alive = true
	anim(0.4, function(a)
		self.Offset = CFrame.new(0, -self.Height * 0.6 * (1 - a), 0) * CFrame.Angles(0, 0, math.rad(80) * (1 - a) * -self.Facing)
	end)
end

function Actor:FadeOut()
	self:Fall()
	anim(0.6, function(a)
		for _, d in ipairs(self.Model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = math.max(d.Transparency, a)
			end
		end
		self.Bar.Enabled = a < 0.3
	end)
end

function Actor:Destroy()
	self.Destroyed = true
	self.Conn:Disconnect()
	self.Model:Destroy()
	self.Bar:Destroy()
end

return Actor
