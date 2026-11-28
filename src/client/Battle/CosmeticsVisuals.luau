--[[
	CosmeticsVisuals (ModuleScript): draws the cosmetics.
	  CosmeticsVisuals.Init()        name tags (title + coloured name) and auras on every player's character, from the
	                                 attributes the server sets (CosAura, CosName, CosTitle)
	  CosmeticsVisuals.SetKill(id)   the local player's kill effect (nil = none)
	  CosmeticsVisuals.KillEffect(parent, position)   a burst where an enemy fell (the fight scene calls this)
	  CosmeticsVisuals.TryOn(slot, id, seconds)       try a cosmetic on for a while, seen only by you (2026-11-22):
	                                 Aura/Name/Title set the attribute on your own Player locally (never replicates),
	                                 Kill overrides the kill effect; afterwards the real one comes back

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

-- Aura rigs: an Attachment named CosAura holding several layered emitters (flames, sparks, mist, halo...) so each themed aura
-- looks different in shape and motion, not just in colour. Built-in particle textures only.
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local RunService = game:GetService("RunService")

local function numseq(list)
	if #list == 1 then
		return NumberSequence.new(list[1])
	end
	local points = {}
	for i, v in ipairs(list) do
		table.insert(points, NumberSequenceKeypoint.new((i - 1) / (#list - 1), v))
	end
	return NumberSequence.new(points)
end

local function colseq(list)
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local points = {}
	for i, v in ipairs(list) do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#list - 1), v))
	end
	return ColorSequence.new(points)
end

-- o: Color (Color3 | list | ColorSequence), Rate, Life = {min,max}, Speed = {min,max}, Size = list, Alpha = list, Accel = Vector3,
--    Spread = degrees, Rot = {min,max}, Spin = {min,max}, Glow = 0..1, Shape, Style, Drag
local function layer(parent, texture, o)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Layer"
	e.Texture = texture
	local col = o.Color
	e.Color = if typeof(col) == "ColorSequence" then col elseif typeof(col) == "table" then colseq(col) else ColorSequence.new(col or Color3.new(1, 1, 1))
	e.LightEmission = o.Glow or 1
	e.Rate = o.Rate or 20
	local life = o.Life or { 1, 1.6 }
	e.Lifetime = NumberRange.new(life[1], life[2])
	local speed = o.Speed or { 0.5, 2 }
	e.Speed = NumberRange.new(speed[1], speed[2])
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Size = numseq(o.Size or { 0.8, 0 })
	e.Transparency = numseq(o.Alpha or { 0.1, 0.1, 1 })
	local rot = o.Rot or { 0, 360 }
	e.Rotation = NumberRange.new(rot[1], rot[2])
	local spin = o.Spin or { -90, 90 }
	e.RotSpeed = NumberRange.new(spin[1], spin[2])
	e.Acceleration = o.Accel or Vector3.zero
	e.Drag = o.Drag or 0
	e.Shape = o.Shape or Enum.ParticleEmitterShape.Cylinder
	e.ShapeStyle = o.Style or Enum.ParticleEmitterShapeStyle.Volume
	if o.Inward then
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	e.Parent = parent
	return e
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local UP = Vector3.new(0, 1, 0)

-- themed aura recipes, by cosmetic id
local RECIPES = {
	Aura_Flame = function(a)
		layer(a, FIRE, { Color = { rgb(255, 230, 120), rgb(255, 120, 30), rgb(120, 20, 10) }, Rate = 34, Life = { 0.7, 1.2 }, Speed = { 1, 3 }, Size = { 0.4, 2.4, 0 }, Alpha = { 0.2, 0.3, 1 }, Accel = UP * 5, Spread = 25 })
		layer(a, SPARKLE, { Color = rgb(255, 170, 60), Rate = 14, Life = { 1, 1.8 }, Speed = { 4, 8 }, Size = { 0.5, 0 }, Accel = UP * 3, Spread = 30 })
	end,
	Aura_Frost = function(a)
		layer(a, SPARKLE, { Color = { rgb(255, 255, 255), rgb(150, 220, 255) }, Rate = 34, Life = { 2, 3 }, Speed = { 0.5, 1.5 }, Size = { 0.7, 0.4, 0 }, Accel = UP * -1.5 })
		layer(a, SMOKE, { Color = rgb(190, 235, 255), Rate = 7, Life = { 1.8, 2.6 }, Speed = { 0.3, 1 }, Size = { 2, 4.5 }, Alpha = { 0.85, 0.9, 1 }, Glow = 0.4, Accel = UP * 0.6 })
		layer(a, SPARKLE, { Color = rgb(255, 255, 255), Rate = 6, Life = { 0.4, 0.8 }, Speed = { 0, 0.2 }, Size = { 0, 2.2, 0 }, Spin = { -200, 200 } })
	end,
	Aura_Nature = function(a)
		layer(a, SPARKLE, { Color = { rgb(220, 255, 150), rgb(110, 220, 90) }, Rate = 22, Life = { 1.5, 2.4 }, Speed = { 1, 2 }, Size = { 0.6, 0 }, Accel = UP * 1.2 })
		layer(a, SPARKLE, { Color = { rgb(150, 230, 90), rgb(60, 150, 50) }, Rate = 8, Life = { 3, 4 }, Speed = { 0.5, 1.5 }, Size = { 0.5, 1.1, 0.8 }, Accel = Vector3.new(0.6, -0.8, 0), Spin = { -220, 220 }, Glow = 0.3 })
		layer(a, SMOKE, { Color = rgb(150, 255, 120), Rate = 4, Life = { 2, 3 }, Speed = { 0.2, 0.6 }, Size = { 2, 4 }, Alpha = { 0.88, 0.9, 1 }, Glow = 0.5 })
	end,
	Aura_Void = function(a)
		layer(a, SMOKE, { Color = { rgb(90, 30, 150), rgb(12, 4, 24) }, Rate = 16, Life = { 1.2, 1.8 }, Speed = { -4, -2 }, Size = { 3.5, 0.5 }, Alpha = { 0.5, 0.4, 1 }, Glow = 0.2, Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface })
		layer(a, SPARKLE, { Color = { rgb(220, 150, 255), rgb(120, 50, 220) }, Rate = 24, Life = { 0.8, 1.4 }, Speed = { -5, -2 }, Size = { 0.6, 0 }, Shape = Enum.ParticleEmitterShape.Sphere, Style = Enum.ParticleEmitterShapeStyle.Surface })
	end,
	Aura_Starlight = function(a)
		layer(a, SPARKLE, { Color = { rgb(255, 255, 255), rgb(255, 235, 150) }, Rate = 60, Life = { 1.2, 2 }, Speed = { 0.5, 2.5 }, Size = { 0.9, 0.3, 0 }, Spin = { -120, 120 } })
		layer(a, SPARKLE, { Color = rgb(255, 250, 200), Rate = 5, Life = { 0.6, 1.1 }, Speed = { 0, 0.3 }, Size = { 0, 2.8, 0 }, Spin = { 60, 180 }, Alpha = { 0, 0, 1 } })
	end,
	Aura_Rainbow = function(a)
		layer(a, SPARKLE, { Color = RAINBOW, Rate = 70, Life = { 1.2, 2 }, Speed = { 0.8, 3 }, Size = { 1, 0 } })
		layer(a, SMOKE, { Color = RAINBOW, Rate = 10, Life = { 1.5, 2.2 }, Speed = { 0.5, 1.5 }, Size = { 1.5, 4 }, Alpha = { 0.75, 0.85, 1 }, Accel = UP * 1.5, Spin = { -60, 60 } })
	end,
	Aura_Ocean = function(a)
		layer(a, SPARKLE, { Color = { rgb(200, 245, 255), rgb(60, 170, 255) }, Rate = 16, Life = { 1.8, 2.6 }, Speed = { 2, 4 }, Size = { 0.35, 0.6, 0 }, Accel = UP * 1.5, Spread = 35, Glow = 0.6 })
		layer(a, SMOKE, { Color = rgb(70, 170, 255), Rate = 6, Life = { 1.8, 2.5 }, Speed = { 0.3, 1 }, Size = { 2.5, 5 }, Alpha = { 0.85, 0.9, 1 }, Glow = 0.5, Accel = UP * 0.8 })
		layer(a, SPARKLE, { Color = rgb(255, 255, 255), Rate = 10, Life = { 0.5, 1 }, Speed = { 0, 0.5 }, Size = { 0, 0.9, 0 } })
	end,
	Aura_Blossom = function(a)
		layer(a, SPARKLE, { Color = { rgb(255, 235, 245), rgb(255, 140, 190) }, Rate = 18, Life = { 3, 4 }, Speed = { 0.5, 2 }, Size = { 0.8, 1.2, 0.8 }, Accel = Vector3.new(0.5, -1.2, 0.3), Spin = { -180, 180 }, Glow = 0.35 })
		layer(a, SPARKLE, { Color = rgb(255, 190, 220), Rate = 14, Life = { 1.2, 2 }, Speed = { 1, 2.5 }, Size = { 0.5, 0 } })
		layer(a, SMOKE, { Color = rgb(255, 180, 215), Rate = 4, Life = { 2, 3 }, Speed = { 0.2, 0.6 }, Size = { 2.5, 4.5 }, Alpha = { 0.88, 0.92, 1 }, Glow = 0.5 })
	end,
	Aura_Storm = function(a)
		layer(a, SMOKE, { Color = { rgb(90, 95, 140), rgb(40, 42, 70) }, Rate = 9, Life = { 1.5, 2.2 }, Speed = { 0.3, 1 }, Size = { 2.5, 4.5 }, Alpha = { 0.6, 0.65, 1 }, Glow = 0.1, Accel = UP * 1 })
		layer(a, SPARKLE, { Color = { rgb(255, 255, 210), rgb(255, 235, 90) }, Rate = 6, Life = { 0.12, 0.28 }, Speed = { 0, 1 }, Size = { 2.4, 3.2, 0 }, Spin = { -400, 400 }, Alpha = { 0, 0, 1 } })
		layer(a, SPARKLE, { Color = rgb(255, 245, 130), Rate = 26, Life = { 0.2, 0.4 }, Speed = { 6, 11 }, Size = { 0.45, 0 }, Drag = 2 })
	end,
	Aura_Ember = function(a)
		layer(a, FIRE, { Color = { rgb(255, 160, 60), rgb(200, 50, 20), rgb(40, 14, 10) }, Rate = 14, Life = { 0.9, 1.5 }, Speed = { 0.5, 1.5 }, Size = { 0.3, 1.2, 0 }, Alpha = { 0.3, 0.4, 1 }, Accel = UP * 3, Spread = 30 })
		layer(a, SPARKLE, { Color = { rgb(255, 210, 120), rgb(255, 80, 30) }, Rate = 24, Life = { 1.6, 2.4 }, Speed = { 3, 7 }, Size = { 0.4, 0 }, Accel = UP * 3, Spread = 55 })
		layer(a, SMOKE, { Color = rgb(30, 22, 22), Rate = 5, Life = { 1.5, 2.2 }, Speed = { 0.5, 1 }, Size = { 1.5, 3.5 }, Alpha = { 0.7, 0.8, 1 }, Glow = 0, Accel = UP * 2 })
	end,
	-- season 1 (Bonds) prize: a rose ribbon and a gold ribbon spiral round the hero, always opposite each other
	Aura_Kindred = function(a)
		local ribbon = { Rate = 46, Life = { 1.1, 1.5 }, Speed = { 0, 0.15 }, Size = { 0.55, 0.35, 0 }, Alpha = { 0, 0.2, 1 }, Spread = 0, Spin = { -40, 40 } }
		local function with(colour)
			local o = table.clone(ribbon)
			o.Color = colour
			return o
		end
		layer(a, SPARKLE, with({ rgb(255, 200, 225), rgb(255, 110, 165) }))
		local twin = Instance.new("Attachment")
		twin.Name = "CosAuraTwin"
		layer(twin, SPARKLE, with({ rgb(255, 245, 200), rgb(255, 200, 90) }))
		-- a soft shared glow where the ribbons meet
		layer(a, SMOKE, { Color = rgb(255, 170, 190), Rate = 3, Life = { 2, 2.8 }, Speed = { 0.1, 0.3 }, Size = { 2.5, 4 }, Alpha = { 0.9, 0.93, 1 }, Glow = 0.6 })
		local base, started, conn = nil, false, nil
		local function stop()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			twin:Destroy()
		end
		conn = RunService.Heartbeat:Connect(function()
			local parent = a.Parent
			if parent and parent:IsA("BasePart") then
				if not started then
					started, base = true, a.Position
				end
				if twin.Parent ~= parent then
					twin.Parent = parent
				end
				local t = os.clock() * 2.6
				local offset = Vector3.new(math.cos(t) * 1.7, math.sin(t * 1.6) * 1.3, math.sin(t) * 1.7)
				a.Position = base + offset
				twin.Position = base - offset
			elseif started then
				stop() -- the aura was taken off
			end
		end)
		a.Destroying:Connect(stop)
	end,
	-- draft season 2 "Tidebound" prize: four sparks, one per tide (fire, storm, frost, void), circling the hero in a ring
	Aura_Tidebound = function(a)
		local colours = {
			{ rgb(255, 210, 120), rgb(255, 110, 40) }, -- fire
			{ rgb(220, 240, 255), rgb(120, 190, 255) }, -- storm
			{ rgb(255, 255, 255), rgb(180, 225, 255) }, -- frost
			{ rgb(230, 180, 255), rgb(170, 70, 255) }, -- void
		}
		local spark = { Rate = 34, Life = { 0.7, 1.1 }, Speed = { 0, 0.2 }, Size = { 0.5, 0.3, 0 }, Alpha = { 0, 0.25, 1 }, Spread = 0, Spin = { -60, 60 } }
		local points = { a }
		for index = 2, 4 do
			local extraPoint = Instance.new("Attachment")
			extraPoint.Name = "CosAuraTide" .. index
			points[index] = extraPoint
		end
		for index, point in ipairs(points) do
			local o = table.clone(spark)
			o.Color = colours[index]
			layer(point, SPARKLE, o)
		end
		layer(a, SMOKE, { Color = rgb(150, 170, 255), Rate = 2, Life = { 2, 2.8 }, Speed = { 0.1, 0.3 }, Size = { 2.5, 4 }, Alpha = { 0.92, 0.95, 1 }, Glow = 0.5 })
		local base, started, conn = nil, false, nil
		local function stop()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			for index = 2, 4 do
				points[index]:Destroy()
			end
		end
		conn = RunService.Heartbeat:Connect(function()
			local parent = a.Parent
			if parent and parent:IsA("BasePart") then
				if not started then
					started, base = true, a.Position
				end
				local t = os.clock() * 1.9
				for index, point in ipairs(points) do
					if point.Parent ~= parent then
						point.Parent = parent
					end
					local angle = t + (index - 1) * math.pi / 2
					point.Position = base + Vector3.new(math.cos(angle) * 2.1, math.sin(t * 2 + index) * 0.35, math.sin(angle) * 2.1)
				end
			elseif started then
				stop() -- the aura was taken off
			end
		end)
		a.Destroying:Connect(stop)
	end,
	Aura_Gilded = function(a)
		layer(a, SPARKLE, { Color = { rgb(255, 250, 200), rgb(255, 205, 70) }, Rate = 44, Life = { 1.2, 2 }, Speed = { 0.8, 2.6 }, Size = { 0.8, 0 } })
		layer(a, SPARKLE, { Color = rgb(255, 215, 90), Rate = 7, Life = { 0.8, 1.4 }, Speed = { 0.2, 1 }, Size = { 0, 1.9, 0 }, Spin = { 120, 360 } })
		layer(a, SMOKE, { Color = rgb(255, 215, 110), Rate = 4, Life = { 2, 2.8 }, Speed = { 0.2, 0.6 }, Size = { 3, 5 }, Alpha = { 0.88, 0.92, 1 }, Glow = 0.6 })
	end,
}

-- Season prizes: a column of fire-light, a rising shower, a ring halo and a glow, all in the prize's two colours.
local function prizeAura(a, def, power)
	local c1, c2 = c3(def.Color), c3(def.Color2 or def.Color)
	layer(a, FIRE, { Color = { c2, c1, c1:Lerp(Color3.new(0, 0, 0), 0.6) }, Rate = 30 * power, Life = { 0.8, 1.4 }, Speed = { 1, 3 }, Size = { 0.5, 2.8, 0 }, Alpha = { 0.25, 0.35, 1 }, Accel = UP * 7, Spread = 20 })
	layer(a, SPARKLE, { Color = { c2, c1 }, Rate = 50 * power, Life = { 1.2, 2.2 }, Speed = { 5, 10 }, Size = { 0.7, 0 }, Accel = UP * 2, Spread = 28, Drag = 1 })
	layer(a, SPARKLE, { Color = { c2, c1 }, Rate = 26, Life = { 1.6, 2 }, Speed = { 0, 0.1 }, Size = { 0.7, 0.9, 0 }, Spin = { -60, 60 }, Style = Enum.ParticleEmitterShapeStyle.Surface })
	layer(a, SMOKE, { Color = c1, Rate = 6, Life = { 2, 3 }, Speed = { 0.2, 0.6 }, Size = { 3.5, 6.5 }, Alpha = { 0.82, 0.9, 1 }, Glow = 0.7, Accel = UP * 1.5 })
	if power > 1 then
		layer(a, SPARKLE, { Color = RAINBOW, Rate = 30, Life = { 1, 1.6 }, Speed = { 2, 5 }, Size = { 0.5, 0 }, Accel = UP * 2 })
		layer(a, SPARKLE, { Color = c2, Rate = 4, Life = { 0.5, 0.9 }, Speed = { 0, 0.3 }, Size = { 0, 3.4, 0 }, Spin = { 90, 240 }, Alpha = { 0, 0, 1 } })
	end
end

local function auraRig(def)
	local a = Instance.new("Attachment")
	a.Name = "CosAura"
	local recipe = RECIPES[def.Id]
	if recipe then
		recipe(a)
	elseif def.Source == "Season" then
		prizeAura(a, def, if def.Id == "Aura_Champion" then 1.6 elseif def.Id == "Aura_Elite" then 1.3 else 1)
	else
		local e = Instance.new("ParticleEmitter")
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
		e.Parent = a
	end
	return a
end

-- A function that builds the aura emitter for a cosmetic id (nil when there is none), for the fight scene's heroes.
function CosmeticsVisuals.AuraBuilder(id)
	local def = id and Cosmetics.Def(id)
	if not def then
		return nil
	end
	return function()
		return auraRig(def)
	end
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
			auraRig(def).Parent = root
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

local tryKill, tryKillUntil = nil, 0
local ATTRIBUTE = { Aura = "CosAura", Name = "CosName", Title = "CosTitle" }
local tryToken = {}
function CosmeticsVisuals.TryOn(slot, id, seconds)
	seconds = seconds or 60
	if slot == "Kill" then
		tryKill, tryKillUntil = id, os.clock() + seconds
		return
	end
	local attribute = ATTRIBUTE[slot]
	local me = Players.LocalPlayer
	if not attribute or not me then
		return
	end
	-- remember what the server gave us (only the first time: trying a second item keeps the real one to restore)
	if tryToken[slot] == nil then
		tryToken[slot] = { Real = me:GetAttribute(attribute) }
	end
	local token = {}
	tryToken[slot].Current = token
	me:SetAttribute(attribute, id)
	task.delay(seconds, function()
		local t = tryToken[slot]
		if t and t.Current == token then
			tryToken[slot] = nil
			if me:GetAttribute(attribute) == id then
				me:SetAttribute(attribute, t.Real)
			end
		end
	end)
end

function CosmeticsVisuals.KillEffect(parent, position)
	local useId = if tryKill and os.clock() < tryKillUntil then tryKill else killId
	local def = useId and Cosmetics.Def(useId)
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
