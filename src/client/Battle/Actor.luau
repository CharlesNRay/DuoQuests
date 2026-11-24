--[[
	Actor (ModuleScript): one fighter in the scene. Owns the model, its place
	on the ground, a health bar, and short procedural animations (lunge, flinch,
	fall, cheer) so combat reads even without authored animations.

	  Actor.new(scene, model, { Name, Facing = 1|-1, MaxHealth })
	  actor:Place(x)            put the ground position at x (z = 0)
	  actor:SetHealth(health)   updates the bar
	  actor:Lunge(towardX) / Flinch() / Fall() / Rise() / Cheer() / FadeOut() / MarkDown(on) (fallen hero outline + name tag)
	  actor:SetModel(model)     swap the body (e.g. the real avatar) keeping state
	  actor:SetAura(builder, key)  a cosmetic aura emitter that follows the body
	  actor:SetGhost(on)        see-through look for an offline partner's ghost
	  actor:Pos()               world position of the chest, for effects
	  actor:Destroy()
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StatusLook = require(script.Parent.StatusLook)
local GearVisuals = require(script.Parent.GearVisuals)

local Actor = {}
Actor.__index = Actor

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end


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

	self.Statuses = {}
	self.Pips = {}
	self.Bar = Instance.new("BillboardGui")
	self.Bar.Size = UDim2.fromOffset(92, 32)
	self.Bar.AlwaysOnTop = true
	self.Bar.MaxDistance = 70 -- far fights show no bars (they would pile up)
	self.Bar.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	-- Back > Chip (the white trail that lags behind damage) > Fill (health, glossy) > HealFlash > Shield (blue overlay)
	self.Back = Instance.new("Frame")
	self.Back.Size = UDim2.fromOffset(92, 12)
	self.Back.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
	self.Back.BorderSizePixel = 0
	self.Back.ClipsDescendants = true
	self.Back.Parent = self.Bar
	Instance.new("UICorner", self.Back).CornerRadius = UDim.new(0, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(8, 8, 14)
	stroke.Thickness = 1.5
	stroke.Parent = self.Back
	self.Chip = Instance.new("Frame")
	self.Chip.Size = UDim2.fromScale(1, 1)
	self.Chip.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
	self.Chip.BorderSizePixel = 0
	self.Chip.Parent = self.Back
	self.Fill = Instance.new("Frame")
	self.Fill.Size = UDim2.fromScale(1, 1)
	self.FillColor = if self.Facing == 1 then Color3.fromRGB(96, 214, 130) else Color3.fromRGB(235, 90, 90)
	self.Fill.BackgroundColor3 = self.FillColor
	self.Fill.BorderSizePixel = 0
	self.Fill.Parent = self.Back
	do
		local gloss = Instance.new("UIGradient")
		gloss.Rotation = 90
		gloss.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 215, 215)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)) })
		gloss.Parent = self.Fill
	end
	self.HealFlash = Instance.new("Frame")
	self.HealFlash.Size = UDim2.fromScale(0, 1)
	self.HealFlash.BackgroundColor3 = Color3.fromRGB(205, 255, 215)
	self.HealFlash.BackgroundTransparency = 1
	self.HealFlash.BorderSizePixel = 0
	self.HealFlash.Parent = self.Back
	self.Shield = Instance.new("Frame")
	self.Shield.Size = UDim2.fromScale(0, 1)
	self.Shield.BackgroundColor3 = Color3.fromRGB(80, 165, 255)
	self.Shield.BackgroundTransparency = 0.12
	self.Shield.BorderSizePixel = 0
	self.Shield.Visible = false
	self.Shield.Parent = self.Back
	do
		self.ShieldGradient = Instance.new("UIGradient") -- a bright band sweeps across the shield
		self.ShieldGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 185, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 245, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 185, 255)) })
		self.ShieldGradient.Parent = self.Shield
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(225, 242, 255)
		edge.Thickness = 1.2
		edge.Transparency = 0.1
		edge.Parent = self.Shield
	end
	self.ShieldIcon = Instance.new("TextLabel")
	self.ShieldIcon.Size = UDim2.fromOffset(16, 16)
	self.ShieldIcon.Position = UDim2.fromOffset(-14, -2)
	self.ShieldIcon.BackgroundTransparency = 1
	self.ShieldIcon.Text = "🛡"
	self.ShieldIcon.TextSize = 13
	self.ShieldIcon.Visible = false
	self.ShieldIcon.Parent = self.Bar
	self.PipRow = Instance.new("Frame")
	self.PipRow.Size = UDim2.new(1, 0, 0, 16)
	self.PipRow.Position = UDim2.fromOffset(0, 15)
	self.PipRow.BackgroundTransparency = 1
	self.PipRow.Parent = self.Bar
	do
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 3)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = self.PipRow
	end
	self.Bar.Adornee = self.Model.PrimaryPart
	self.Bar.Parent = scene.Folder

	self.Conn = RunService.Heartbeat:Connect(function()
		if self.Destroyed then
			return
		end
		local bob = if not self.Alive then 0 elseif self.Walking then math.abs(math.sin(os.clock() * 9 + self.Phase)) * 0.3 else math.sin(os.clock() * 3 + self.Phase) * 0.12
		local frame = scene.Frame or CFrame.new(scene.Origin)
		local at = frame:PointToWorldSpace(Vector3.new(self.X, self.Height + bob, self.Z or 0))
		local base = CFrame.lookAt(at, at + frame:VectorToWorldSpace(Vector3.new(self.Facing, 0, 0)))
		self.Model:PivotTo(base * self.Offset)
		self:_animate(os.clock())
		self:_animateJoints(os.clock())
		self:_tickStatuses(os.clock())
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
			rot = CFrame.Angles(-atk * 1.7 + (if self.Walking then side * math.sin(t * 9 + ph) * 0.7 else math.sin(t * 2.6 + ph + side * 1.5) * 0.28), 0, 0)
		elseif k == "Leg" then
			rot = CFrame.Angles(side * math.sin(t * (if self.Walking then 9 else 5) + ph) * (if self.Walking then 0.7 else 0.22 + atk * 0.2), 0, 0)
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

-- Avatar joints we swing by hand (R15 and R6 names) so heroes walk without animation assets.
local JOINTS = {
	RightHip = { "hip", 1 }, LeftHip = { "hip", -1 }, RightShoulder = { "arm", -1 }, LeftShoulder = { "arm", 1 },
	["Right Hip"] = { "hip", 1 }, ["Left Hip"] = { "hip", -1 }, ["Right Shoulder"] = { "arm", -1 }, ["Left Shoulder"] = { "arm", 1 },
	RightKnee = { "knee", 1 }, LeftKnee = { "knee", -1 },
}

function Actor:_collectJoints(model, rigged)
	self.Joints = {}
	self.R6 = false
	if not rigged then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.EvaluateStateMachine = false -- the body is moved by us, never by Humanoid physics
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end)
	end
	self.R6 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and JOINTS[d.Name] then
			table.insert(self.Joints, { Motor = d, Kind = JOINTS[d.Name][1], Side = JOINTS[d.Name][2] })
		end
	end
end

function Actor:SetWalking(on)
	self.Walking = on == true
end

-- Drives the avatar's limbs: a walk cycle while travelling, a gentle sway when idle, arms thrown forward when attacking.
function Actor:_animateJoints(t)
	if not self.Joints or #self.Joints == 0 then
		return
	end
	local target = if self.Walking and self.Alive then 1 else 0
	self.WalkAmt = (self.WalkAmt or 0) + (target - (self.WalkAmt or 0)) * 0.2
	local walk = self.WalkAmt
	local atk = self.AttackAmt or 0
	local phase = t * 9 + self.Phase
	for _, j in ipairs(self.Joints) do
		local angle = 0
		if j.Kind == "hip" then
			angle = j.Side * math.sin(phase) * 0.75 * walk
		elseif j.Kind == "knee" then
			angle = math.max(0, math.sin(phase + (if j.Side > 0 then 0 else math.pi) + 1.2)) * 0.5 * walk
		else -- arm
			angle = j.Side * math.sin(phase) * 0.8 * walk + math.sin(t * 2 + self.Phase) * 0.05 * (1 - walk) - atk * 1.6 * (if j.Side == -1 then 1 else 0.4)
		end
		if self.R6 then
			j.Motor.Transform = CFrame.Angles(0, 0, if j.Kind == "arm" then -angle else angle)
		else
			j.Motor.Transform = CFrame.Angles(angle, 0, 0)
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
	local rigged = model:FindFirstChildOfClass("Humanoid") ~= nil and model.PrimaryPart ~= nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- a Roblox avatar: only the root is anchored, so its joints (Motor6D) can swing the limbs while it moves
			d.Anchored = not rigged or d == model.PrimaryPart
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model.Parent = self.Scene.Folder
	self.Model = model
	self.Hi = nil -- the Highlight lived on the old body
	self:_collectParts(model)
	self:_collectJoints(model, rigged)
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

-- Status effects ---------------------------------------------------------------------------------------------------------

function Actor:_highlight()
	if self.Hi and self.Hi.Parent then
		return self.Hi
	end
	local h = Instance.new("Highlight")
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = self.Model
	h.Parent = self.Model
	self.Hi = h
	return h
end

-- A coloured flash over the whole body (heal, buff, hit by a debuff...).
function Actor:Tint(color, strength, time)
	local h = self:_highlight()
	self.FlashUntil = os.clock() + (time or 0.5)
	h.FillColor, h.OutlineColor = color, color:Lerp(Color3.new(1, 1, 1), 0.4)
	h.FillTransparency = 1 - (strength or 0.45)
	h.OutlineTransparency = 0.25
	tween(h, time or 0.5, { FillTransparency = 1, OutlineTransparency = 1 })
end

-- Arrows rising off the body: up for a buff, falling for a debuff.
function Actor:Chevrons(color, up)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = self:Pos()
	anchor.Parent = self.Scene.Folder
	local span = math.max(1.2, (self.Top or 4) * 0.22)
	for i = 1, 5 do
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(22, 22)
		gui.AlwaysOnTop = true
		gui.Adornee = anchor
		local startY = if up then -(self.Top or 4) * 0.35 else (self.Top or 4) * 0.45
		local endY = if up then (self.Top or 4) * 0.5 else -(self.Top or 4) * 0.3
		local x = (i - 3) * span * 0.5
		gui.StudsOffsetWorldSpace = Vector3.new(x, startY, 0)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = if up then "▲" else "▼"
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 20
		label.TextColor3 = color
		label.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.7)
		label.TextStrokeTransparency = 0.35
		label.TextTransparency = 1
		label.Parent = gui
		gui.Parent = anchor
		task.delay((i - 1) * 0.07, function()
			if gui.Parent then
				tween(label, 0.18, { TextTransparency = 0 })
				tween(gui, 0.9, { StudsOffsetWorldSpace = Vector3.new(x, endY, 0) }, Enum.EasingStyle.Sine)
				task.delay(0.55, function()
					if label.Parent then
						tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
					end
				end)
			end
		end)
	end
	Debris:AddItem(anchor, 1.6)
end

-- A hex-patterned bubble that pops up around a shielded fighter, holds a moment and fades (Overwatch-style barrier).
function Actor:Bubble(color, quick)
	local size = math.max(5, (self.Top or 5) * 1.35)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = color
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
	ball.Transparency = 1
	ball.Size = Vector3.new(size * 0.35, size * 0.35, size * 0.35)
	ball.Position = self:Pos()
	ball.Parent = self.Scene.Folder
	local glow = Instance.new("Part") -- a soft inner glow so it reads in daylight too
	glow.Shape = Enum.PartType.Ball
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Transparency = 1
	glow.Size = ball.Size
	glow.Position = ball.Position
	glow.Parent = self.Scene.Folder
	local grow = if quick then 0.12 else 0.28
	local hold = if quick then 0.12 else 0.7
	tween(ball, grow, { Size = Vector3.new(size, size, size), Transparency = if quick then 0.55 else 0.3 }, Enum.EasingStyle.Back)
	tween(glow, grow, { Size = Vector3.new(size * 0.97, size * 0.97, size * 0.97), Transparency = if quick then 0.9 else 0.82 }, Enum.EasingStyle.Back)
	local alive = true
	task.spawn(function()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not alive or self.Destroyed then
				conn:Disconnect()
				return
			end
			ball.Position = self:Pos()
			glow.Position = ball.Position
		end)
	end)
	task.delay(grow + hold, function()
		tween(ball, 0.4, { Transparency = 1, Size = Vector3.new(size * 1.08, size * 1.08, size * 1.08) })
		tween(glow, 0.4, { Transparency = 1 })
		task.delay(0.45, function()
			alive = false
			ball:Destroy()
			glow:Destroy()
		end)
	end)
	-- a ring on the ground
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(Vector3.new(self:Pos().X, self.Scene.Origin.Y + 0.2, self:Pos().Z)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = self.Scene.Folder
	tween(ring, 0.6, { Size = Vector3.new(0.2, size * 1.1, size * 1.1), Transparency = 1 })
	Debris:AddItem(ring, 0.7)
end

-- The shield was used up: it bursts into shards.
function Actor:ShatterShield(color)
	self.Shield.BackgroundColor3 = Color3.new(1, 1, 1)
	task.delay(0.12, function()
		if self.Shield.Parent then
			self.Shield.BackgroundColor3 = Color3.fromRGB(80, 165, 255)
		end
	end)
	local origin = self:Pos()
	for _ = 1, 9 do
		local shard = Instance.new("Part")
		shard.Material = Enum.Material.Neon
		shard.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
		shard.Anchored, shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow = true, false, false, false, false
		shard.Size = Vector3.new(0.25, 0.7, 0.25)
		shard.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		shard.Parent = self.Scene.Folder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, (math.random() - 0.5) * 0.6).Unit * (2.5 + math.random() * 2)
		tween(shard, 0.6, { Position = origin + dir + Vector3.new(0, 0.5, 0), Transparency = 1, Size = Vector3.new(0.05, 0.2, 0.05) })
		Debris:AddItem(shard, 0.7)
	end
	self:Tint(color, 0.5, 0.4)
end

-- A status arrived (or was refreshed). info = { Duration, Amount, Stacks }.
function Actor:AddStatus(id, info)
	local look = StatusLook.Of(id)
	local st = self.Statuses[id]
	local fresh = st == nil
	if fresh then
		st = { Id = id, Kind = look.Kind, Color = look.Color, Glyph = look.Glyph, Combo = look.Combo }
		self.Statuses[id] = st
	end
	local amountBefore = st.Amount or 0
	st.Duration = math.max(0.1, info.Duration or 1)
	st.EndsAt = os.clock() + st.Duration
	st.Stacks = info.Stacks
	if st.Kind == "Shield" then
		st.Amount = math.max(st.Amount or 0, info.Amount or 0)
	end
	self:_updatePip(st, fresh)
	if st.Kind == "Shield" then
		self:_layoutShield(true)
		if fresh or st.Amount > amountBefore then
			self:Bubble(look.Color)
			self:Tint(look.Color, 0.4, 0.6)
		end
	elseif st.Kind == "Buff" then
		if fresh then
			self:Chevrons(look.Color, true)
			self:Tint(look.Color, 0.35, 0.6)
		end
	elseif fresh then -- a debuff, damage over time or crowd control landed
		self:Chevrons(look.Color, false)
		self:Tint(look.Color, 0.5, 0.55)
	end
	return fresh
end

-- Damage that a shield soaked: the shield shrinks, rippling, and bursts when empty.
function Actor:Absorb(amount)
	if not amount or amount <= 0 then
		return
	end
	local shields = {}
	for _, st in pairs(self.Statuses) do
		if st.Kind == "Shield" then
			table.insert(shields, st)
		end
	end
	if #shields == 0 then
		return
	end
	table.sort(shields, function(a, b)
		return (a.EndsAt or 0) < (b.EndsAt or 0)
	end)
	local left, color = amount, shields[1].Color
	for _, st in ipairs(shields) do
		local take = math.min(left, st.Amount or 0)
		st.Amount = (st.Amount or 0) - take
		left -= take
		if left <= 0 then
			break
		end
	end
	self:Bubble(color, true) -- the bubble flickers where it was hit
	self:_layoutShield(false)
	if self:_shieldTotal() <= 0 then
		self:ShatterShield(color)
	end
end

function Actor:RemoveStatus(id, reason)
	local st = self.Statuses[id]
	if not st then
		return
	end
	self.Statuses[id] = nil
	local pip = self.Pips[id]
	if pip then
		self.Pips[id] = nil
		tween(pip.Frame, 0.2, { BackgroundTransparency = 1 })
		Debris:AddItem(pip.Frame, 0.25)
	end
	if st.Kind == "Shield" then
		self:_layoutShield(false)
		if reason ~= "Broken" and self:_shieldTotal() <= 0 and self.Alive then
			self:Tint(st.Color, 0.25, 0.4) -- it simply wore off
		end
	end
	if reason == "Cleansed" and self.Alive then
		self:Tint(Color3.fromRGB(255, 250, 210), 0.55, 0.6)
		self:Chevrons(Color3.fromRGB(255, 250, 200), true)
	end
end

function Actor:ClearStatuses()
	for id in pairs(table.clone(self.Statuses)) do
		self.Statuses[id] = nil
	end
	for id, pip in pairs(self.Pips) do
		pip.Frame:Destroy()
		self.Pips[id] = nil
	end
	self.Shield.Visible = false
	self.Shield.Size = UDim2.fromScale(0, 1)
	self.ShieldIcon.Visible = false
	if self.Hi then
		self.Hi.FillTransparency, self.Hi.OutlineTransparency = 1, 1
	end
end

function Actor:_updatePip(st, fresh)
	local pip = self.Pips[st.Id]
	if not pip then
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(15, 15)
		frame.BackgroundColor3 = st.Color:Lerp(Color3.new(0, 0, 0), 0.55)
		frame.BorderSizePixel = 0
		frame.LayoutOrder = (self.PipOrder or 0) + 1
		self.PipOrder = (self.PipOrder or 0) + 1
		frame.Parent = self.PipRow
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)
		local edge = Instance.new("UIStroke")
		edge.Color = st.Color
		edge.Thickness = 1.3
		edge.Parent = frame
		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.Text = st.Glyph
		glyph.TextSize = 10
		glyph.TextColor3 = st.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		glyph.Parent = frame
		local drain = Instance.new("Frame")
		drain.Size = UDim2.new(1, 0, 0, 2)
		drain.Position = UDim2.new(0, 0, 1, -2)
		drain.BackgroundColor3 = st.Color
		drain.BorderSizePixel = 0
		drain.Parent = frame
		local count = Instance.new("TextLabel")
		count.Size = UDim2.fromOffset(9, 9)
		count.Position = UDim2.new(1, -7, 1, -8)
		count.BackgroundTransparency = 1
		count.TextSize = 9
		count.Font = Enum.Font.GothamBlack
		count.TextColor3 = Color3.new(1, 1, 1)
		count.TextStrokeTransparency = 0.2
		count.Text = ""
		count.Parent = frame
		pip = { Frame = frame, Drain = drain, Count = count }
		self.Pips[st.Id] = pip
		frame.Size = UDim2.fromOffset(6, 6)
		tween(frame, 0.22, { Size = UDim2.fromOffset(15, 15) }, Enum.EasingStyle.Back)
	end
	-- combo layers show their count from 1 (players watch them build up); other stacks from 2
	pip.Count.Text = if st.Stacks and (st.Stacks > 1 or st.Combo) then tostring(st.Stacks) else ""
end

-- Per-frame: expire timed-out statuses, drain the little duration bars, shimmer the shield, pulse the damage-over-time tint.
function Actor:_tickStatuses(now)
	for id, st in pairs(self.Statuses) do
		local left = (st.EndsAt or now) - now
		if left <= 0 then
			self:RemoveStatus(id, "Expired")
		else
			local pip = self.Pips[id]
			if pip then
				pip.Drain.Size = UDim2.new(math.clamp(left / st.Duration, 0, 1), 0, 0, 2)
			end
		end
	end
	if self.Shield.Visible then
		self.ShieldGradient.Offset = Vector2.new(((now * 0.9) % 2) - 1, 0)
	end
	if self.Hi and now > (self.FlashUntil or 0) or (not self.Hi and next(self.Statuses) ~= nil) then
		local persist
		for _, st in pairs(self.Statuses) do
			if st.Kind == "Dot" or st.Kind == "Cc" then
				persist = st.Color
				if st.Kind == "Cc" then
					break
				end
			end
		end
		if persist and self.Alive then
			local h = self:_highlight()
			h.FillColor, h.OutlineColor = persist, persist
			h.FillTransparency = 0.78 + math.sin(now * 5) * 0.08
			h.OutlineTransparency = 0.55
		elseif self.Hi then
			self.Hi.FillTransparency, self.Hi.OutlineTransparency = 1, 1
		end
	end
end

-- Healing: the body glows green and crosses rise (the bar itself reacts in SetHealth).
function Actor:HealFx()
	self:Tint(Color3.fromRGB(110, 240, 150), 0.4, 0.6)
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

-- Health: the bar glides to the new value. Damage leaves a pale trail that catches up a moment later; healing lights up the
-- gained part of the bar, brightens it and throws a few green crosses. `snap` jumps straight there (fight setup).
function Actor:SetHealth(health, snap)
	local old = self.Health
	local new = math.clamp(health, 0, self.MaxHealth)
	self.Health = new
	local frac = new / self.MaxHealth
	local oldFrac = math.clamp((old or new) / self.MaxHealth, 0, 1)
	self.ChipToken = (self.ChipToken or 0) + 1
	local token = self.ChipToken
	if snap or old == nil then
		self.Fill.Size = UDim2.fromScale(frac, 1)
		self.Chip.Size = UDim2.fromScale(frac, 1)
	elseif new < old then
		tween(self.Fill, 0.16, { Size = UDim2.fromScale(frac, 1) })
		self.Chip.Size = UDim2.fromScale(math.max(oldFrac, self.Chip.Size.X.Scale), 1) -- the trail stays where the health was
		task.delay(0.45, function()
			if token == self.ChipToken and not self.Destroyed then
				tween(self.Chip, 0.4, { Size = UDim2.fromScale(frac, 1) })
			end
		end)
		-- a quick white flicker on hit
		self.Fill.BackgroundColor3 = Color3.new(1, 1, 1)
		tween(self.Fill, 0.2, { BackgroundColor3 = self.FillColor })
	elseif new > old then
		self.Chip.Size = UDim2.fromScale(frac, 1)
		tween(self.Fill, 0.35, { Size = UDim2.fromScale(frac, 1) }, Enum.EasingStyle.Quad)
		self.HealFlash.Position = UDim2.fromScale(oldFrac, 0)
		self.HealFlash.Size = UDim2.fromScale(math.max(0.04, frac - oldFrac), 1)
		self.HealFlash.BackgroundTransparency = 0.05
		tween(self.HealFlash, 0.9, { BackgroundTransparency = 1 })
		self.Fill.BackgroundColor3 = Color3.fromRGB(190, 255, 205)
		tween(self.Fill, 0.7, { BackgroundColor3 = self.FillColor })
		self:_barSparkles(oldFrac, frac)
	end
	self:_layoutShield()
end

-- little green crosses rising off the healed part of the bar
function Actor:_barSparkles(fromFrac, toFrac)
	for i = 1, 4 do
		task.delay((i - 1) * 0.09, function()
			if self.Destroyed then
				return
			end
			local x = (fromFrac + (toFrac - fromFrac) * math.random()) * 92
			local cross = Instance.new("TextLabel")
			cross.Size = UDim2.fromOffset(14, 14)
			cross.AnchorPoint = Vector2.new(0.5, 0.5)
			cross.Position = UDim2.fromOffset(x, 6)
			cross.BackgroundTransparency = 1
			cross.Text = "✚"
			cross.TextSize = 13
			cross.Font = Enum.Font.GothamBlack
			cross.TextColor3 = Color3.fromRGB(150, 255, 175)
			cross.TextStrokeColor3 = Color3.fromRGB(10, 60, 30)
			cross.TextStrokeTransparency = 0.3
			cross.Parent = self.Bar
			tween(cross, 0.8, { Position = UDim2.fromOffset(x + math.random(-6, 6), -16), TextTransparency = 1, TextStrokeTransparency = 1 })
			Debris:AddItem(cross, 0.9)
		end)
	end
end

-- Shield overlay: sits at the right end of the health (clamped to the bar), width = shield / max health.
function Actor:_shieldTotal()
	local total = 0
	for _, st in pairs(self.Statuses) do
		if st.Kind == "Shield" then
			total += st.Amount or 0
		end
	end
	return total
end

function Actor:_layoutShield(grow)
	local total = self:_shieldTotal()
	local show = total > 0
	local frac = math.clamp(total / self.MaxHealth, 0.03, 1)
	local hp = math.clamp((self.Health or self.MaxHealth) / self.MaxHealth, 0, 1)
	local start = math.min(hp, 1 - frac)
	self.ShieldIcon.Visible = show
	if show and not self.Shield.Visible then
		self.Shield.Visible = true
		self.Shield.Position = UDim2.fromScale(start, 0)
		self.Shield.Size = UDim2.fromScale(0, 1)
	end
	if show then
		tween(self.Shield, if grow then 0.35 else 0.18, { Size = UDim2.fromScale(frac, 1), Position = UDim2.fromScale(start, 0) }, if grow then Enum.EasingStyle.Back else Enum.EasingStyle.Quad)
	elseif self.Shield.Visible then
		local t = tween(self.Shield, 0.25, { BackgroundTransparency = 1 })
		t.Completed:Connect(function()
			if self.Shield.Parent and self:_shieldTotal() <= 0 then
				self.Shield.Visible = false
				self.Shield.BackgroundTransparency = 0.12
				self.Shield.Size = UDim2.fromScale(0, 1)
			end
		end)
	end
end

function Actor:Pos()
	local frame = self.Scene.Frame or CFrame.new(self.Scene.Origin)
	return frame:PointToWorldSpace(Vector3.new(self.X, self.Height + self.Top * 0.2, self.Z or 0))
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
	self:ClearStatuses()
	self.AttackAmt = 0
	anim(0.4, function(a)
		self.Offset = CFrame.new(0, -self.Height * 0.6 * a, 0) * CFrame.Angles(0, 0, math.rad(80) * a * -self.Facing)
	end)
end

-- A fallen hero is easy to spot: a red outline on the body and a "💀 Name" tag above it until it rises.
function Actor:MarkDown(on)
	if self.DownMark then
		self.DownMark:Destroy()
		self.DownMark = nil
	end
	if self.DownTag then
		self.DownTag:Destroy()
		self.DownTag = nil
	end
	if not on or self.Destroyed then
		return
	end
	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(200, 30, 30)
	glow.FillTransparency = 0.55
	glow.OutlineColor = Color3.fromRGB(255, 70, 70)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = self.Model
	glow.Parent = self.Model
	self.DownMark = glow
	local root = self.Model.PrimaryPart
	if root then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(170, 26)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 90
		tag.Adornee = root
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "💀 " .. tostring(self.Name or "Ally") .. " is down"
		label.TextColor3 = Color3.fromRGB(255, 110, 100)
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 15
		label.Parent = tag
		tag.Parent = root
		self.DownTag = tag
	end
end

function Actor:Rise()
	self:MarkDown(false)
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
	self:MarkDown(false)
	self.Conn:Disconnect()
	self.Model:Destroy()
	self.Bar:Destroy()
end

return Actor
