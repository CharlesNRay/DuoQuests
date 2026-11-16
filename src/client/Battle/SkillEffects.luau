--[[
	SkillEffects (ModuleScript): the look of skills in the fight scene, built from simple glowing parts (no assets).
	Data: Shared/Config/SkillEffects (which skill uses which kind and colours). Nothing here touches combat.

	  SkillEffects.Cast(scene, ctx)               a skill was cast: area effects, the pet's glyph pop, the caster's glyph
	      ctx = { Ability, SourcePos, AllyPositions = {Vector3}, EnemyPositions = {Vector3}, SourceIsHero, PetPos? }
	  SkillEffects.Hit(scene, ability, srcPos, tgtPos, classId?)   damage landing on one target (ability nil = basic attack)
	  SkillEffects.Heal(scene, ability, tgtPos)   a heal landing
	  SkillEffects.Status(scene, statusId, tgtPos, ability?)   a shield or buff landing (ability decides the shield's look)
	  SkillEffects.Revive(scene, pos)
	  SkillEffects.Ultimate(scene, ultimateId, ctx)   ctx = { AllyPositions, EnemyPositions }

	Every call is safe to wrap in pcall: effects must never break a fight replay.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.SkillEffects)

local SkillEffects = {}

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function colorsOf(style)
	local c1 = c3(style.Color or { 255, 255, 255 })
	return c1, if style.Color2 then c3(style.Color2) else c1:Lerp(Color3.new(1, 1, 1), 0.5)
end

local function mk(scene, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = scene.Folder
	return p
end

local function fade(part, time, goal, easing)
	goal = goal or {}
	goal.Transparency = goal.Transparency or 1
	TweenService:Create(part, TweenInfo.new(time, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, time + 0.15)
end

local function later(t, fn)
	if t <= 0 then
		fn()
	else
		task.delay(t, fn)
	end
end

local function ground(scene, pos)
	return Vector3.new(pos.X, scene.Origin.Y + 0.15, pos.Z)
end

local function ball(scene, pos, size, color, transparency)
	return mk(scene, { Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Color = color, Transparency = transparency or 0.2, Position = pos })
end

-- a flat glowing ring on the ground (or raised) that grows
local function ring(scene, pos, color, from, to, time, thickness, transparency)
	local p = mk(scene, {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness or 0.3, from, from), Color = color, Transparency = transparency or 0.25,
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
	})
	fade(p, time, { Size = Vector3.new(thickness or 0.3, to, to) })
	return p
end

-- a glowing bar of `length` at `pos`, tilted by `angle` degrees, that sweeps out and fades
local function bar(scene, pos, color, length, angle, time, thick)
	local p = mk(scene, { Size = Vector3.new(0.5, thick or 0.3, thick or 0.3), Color = color, Transparency = 0.05, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(angle)) })
	fade(p, time, { Size = Vector3.new(length, (thick or 0.3) * 0.6, (thick or 0.3) * 0.6) })
	return p
end

-- a bar between two points
local function link(scene, a, b, color, thick, time)
	local mid = (a + b) / 2
	local p = mk(scene, { Size = Vector3.new(thick, thick, (b - a).Magnitude), Color = color, Transparency = 0.05, CFrame = CFrame.lookAt(mid, b) })
	fade(p, time, { Size = Vector3.new(thick * 0.3, thick * 0.3, (b - a).Magnitude) })
	return p
end

local function glyphPop(scene, pos, text, color, size, rise, time)
	local anchor = mk(scene, { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 2, size * 2)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.Parent = gui
	time = time or 0.9
	TweenService:Create(anchor, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, rise or 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, time + 0.1)
end

local rng = Random.new()

-- Hit kinds: what lands on one target ------------------------------------------------------------
local HIT = {}

function HIT.Slash(scene, _, tgt, c1, c2, s)
	bar(scene, tgt, c1, 7 * s, 35, 0.25, 0.35 * s)
	bar(scene, tgt, c2, 5 * s, 35, 0.2, 0.18 * s)
end

function HIT.Cross(scene, _, tgt, c1, c2, s)
	bar(scene, tgt, c1, 7.5 * s, 40, 0.28, 0.4 * s)
	later(0.08, function()
		bar(scene, tgt, c2, 7.5 * s, -40, 0.28, 0.4 * s)
	end)
end

function HIT.Smash(scene, _, tgt, c1, c2, s)
	ring(scene, ground(scene, tgt), c1, 1.5, 9 * s, 0.4, 0.4)
	ring(scene, ground(scene, tgt), c2, 1, 5 * s, 0.3, 0.3)
	for _ = 1, 6 do
		local d = mk(scene, { Size = Vector3.new(0.5, 0.5, 0.5) * s, Color = c2, Transparency = 0.1, Position = ground(scene, tgt) + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1, 1)) })
		fade(d, 0.5, { Position = d.Position + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(2, 4.5), rng:NextNumber(-1.5, 1.5)) })
	end
end

function HIT.Orb(scene, src, tgt, c1, c2, s)
	local orb = ball(scene, src, 1.2 * s, c1, 0.05)
	TweenService:Create(orb, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = tgt }):Play()
	Debris:AddItem(orb, 0.3)
	later(0.18, function()
		local b = ball(scene, tgt, 1, c2, 0.1)
		fade(b, 0.35, { Size = Vector3.new(4.5, 4.5, 4.5) * s })
		ring(scene, tgt, c1, 1, 6 * s, 0.35, 0.2)
	end)
end

function HIT.Pillar(scene, _, tgt, c1, c2, s)
	local outer = mk(scene, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 3 * s, 3 * s), Color = c1, Transparency = 0.45, CFrame = CFrame.new(tgt + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	fade(outer, 0.5, { Size = Vector3.new(22, 0.3, 0.3) })
	local inner = mk(scene, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 1.2 * s, 1.2 * s), Color = c2, Transparency = 0.1, CFrame = outer.CFrame })
	fade(inner, 0.4, { Size = Vector3.new(22, 0.1, 0.1) })
	ring(scene, ground(scene, tgt), c1, 1, 8 * s, 0.45, 0.3)
end

function HIT.Beam(scene, src, tgt, c1, c2, s)
	local top = tgt + Vector3.new(rng:NextNumber(-2, 2), 16, 0)
	link(scene, top, tgt, c1, 2.2 * s, 0.45)
	link(scene, top, tgt, c2, 0.9 * s, 0.35)
	local f = ball(scene, tgt, 1.5, c2, 0.2)
	fade(f, 0.4, { Size = Vector3.new(5, 5, 5) * s })
end

function HIT.Lightning(scene, _, tgt, c1, c2, s)
	local points = { tgt + Vector3.new(rng:NextNumber(-2, 2), 15, 0) }
	for i = 1, 4 do
		table.insert(points, tgt + Vector3.new(rng:NextNumber(-1.8, 1.8), 15 - i * 3.2, rng:NextNumber(-0.5, 0.5)))
	end
	table.insert(points, tgt)
	for i = 1, #points - 1 do
		link(scene, points[i], points[i + 1], if i % 2 == 0 then c2 else c1, 0.5 * s, 0.3)
	end
	ring(scene, tgt, c2, 1, 5 * s, 0.25, 0.15)
end

function HIT.Shards(scene, _, tgt, c1, c2, s)
	for i = 1, 6 do
		local from = tgt + Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(9, 13), 0)
		later((i - 1) * 0.04, function()
			local sh = mk(scene, { Size = Vector3.new(0.35, 1.6, 0.35) * s, Color = if i % 2 == 0 then c1 else c2, Transparency = 0.1, Position = from })
			TweenService:Create(sh, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = tgt + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, 0) }):Play()
			fade(sh, 0.3)
		end)
	end
end

function HIT.Flame(scene, _, tgt, c1, c2, s)
	for _ = 1, 7 do
		local f = ball(scene, tgt + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.5), rng:NextNumber(-0.6, 0.6)), 1.2 * s, c2, 0.1)
		fade(f, 0.55, { Size = Vector3.new(2.8, 2.8, 2.8) * s, Position = f.Position + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(2, 4), 0), Color = c1 })
	end
	ring(scene, ground(scene, tgt), c1, 1, 7 * s, 0.4, 0.25)
end

function HIT.Claws(scene, _, tgt, c1, c2, s)
	for i = 1, 3 do
		later((i - 1) * 0.05, function()
			bar(scene, tgt + Vector3.new(0, (i - 2) * 0.9 * s, 0), if i == 2 then c2 else c1, 5.5 * s, 28, 0.22, 0.2 * s)
		end)
	end
end

function HIT.Burst(scene, _, tgt, c1, c2, s)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local sp = ball(scene, tgt, 0.5 * s, if i % 2 == 0 then c1 else c2, 0.05)
		fade(sp, 0.3, { Position = tgt + Vector3.new(math.cos(a) * 2.4 * s, math.sin(a) * 2.4 * s, 0) })
	end
	local f = ball(scene, tgt, 1, c2, 0.3)
	fade(f, 0.25, { Size = Vector3.new(3, 3, 3) * s })
end

-- Area kinds: drawn once over a whole side ---------------------------------------------------------
local AREA = {}

local function spanOf(positions, fallback)
	local lo, hi, sum = math.huge, -math.huge, 0
	for _, p in ipairs(positions) do
		lo, hi = math.min(lo, p.X), math.max(hi, p.X)
		sum += p.X
	end
	if #positions == 0 then
		return fallback.X - 4, fallback.X + 4, fallback
	end
	return lo, hi, Vector3.new(sum / #positions, positions[1].Y, positions[1].Z)
end

function AREA.Nova(scene, ctx, c1, c2)
	local _, _, center = spanOf(ctx.Targets, ctx.SourcePos)
	local sphere = ball(scene, center, 2, c1, 0.4)
	fade(sphere, 0.55, { Size = Vector3.new(15, 15, 15) })
	ring(scene, ground(scene, center), c2, 2, 20, 0.6, 0.3)
	ring(scene, ground(scene, center), c1, 1, 12, 0.45, 0.4)
end

function AREA.Quake(scene, ctx, c1, c2)
	local lo, hi, center = spanOf(ctx.Targets, ctx.SourcePos)
	for i = 0, 3 do
		local x = lo - 2 + (hi - lo + 4) * i / 3
		later(i * 0.1, function()
			HIT.Smash(scene, nil, Vector3.new(x, center.Y, center.Z), c1, c2, 1.1)
		end)
	end
end

function AREA.Whirl(scene, ctx, c1, c2)
	local src = ctx.SourcePos
	for i = 0, 5 do
		bar(scene, src, if i % 2 == 0 then c1 else c2, 9, i * 60, 0.4, 0.35)
	end
	ring(scene, ground(scene, src), c1, 2, 13, 0.4, 0.3)
	later(0.12, function()
		ring(scene, ground(scene, src), c2, 2, 16, 0.4, 0.2)
	end)
end

function AREA.Rain(scene, ctx, c1, c2)
	local lo, hi, center = spanOf(ctx.Targets, ctx.SourcePos)
	for i = 1, 14 do
		local x = rng:NextNumber(lo - 2, hi + 2)
		later((i - 1) * 0.035, function()
			local top = Vector3.new(x, center.Y + rng:NextNumber(10, 14), center.Z + rng:NextNumber(-1, 1))
			local sh = mk(scene, { Size = Vector3.new(0.3, 1.8, 0.3), Color = if i % 2 == 0 then c1 else c2, Transparency = 0.05, Position = top })
			TweenService:Create(sh, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(x, center.Y, top.Z) }):Play()
			fade(sh, 0.3)
			later(0.22, function()
				ring(scene, ground(scene, Vector3.new(x, center.Y, top.Z)), c1, 0.5, 3, 0.25, 0.15)
			end)
		end)
	end
end

function AREA.Wave(scene, ctx, c1, c2)
	local lo, hi, center = spanOf(ctx.Targets, ctx.SourcePos)
	local dir = if ctx.SourceIsHero then 1 else -1
	local startX = ctx.SourcePos.X + dir * 2
	local endX = (if dir == 1 then hi else lo) + dir * 3
	local wall = mk(scene, { Size = Vector3.new(0.6, 5, 7), Color = c1, Transparency = 0.25, Position = Vector3.new(startX, center.Y, center.Z) })
	TweenService:Create(wall, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = Vector3.new(endX, center.Y, center.Z) }):Play()
	fade(wall, 0.55, { Size = Vector3.new(0.3, 6, 9) })
	local core = mk(scene, { Size = Vector3.new(0.3, 3, 5), Color = c2, Transparency = 0.1, Position = wall.Position })
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = Vector3.new(endX, center.Y, center.Z) }):Play()
	fade(core, 0.55)
end

function AREA.Starfall(scene, ctx, c1, c2)
	local lo, hi, center = spanOf(ctx.Targets, ctx.SourcePos)
	for i = 1, 9 do
		local x = lo - 2 + (hi - lo + 4) * (i - 1) / 8
		later((i - 1) * 0.06, function()
			local from = Vector3.new(x - 6, center.Y + 14, center.Z)
			local star = ball(scene, from, 1, c2, 0.05)
			TweenService:Create(star, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(x, center.Y, center.Z) }):Play()
			fade(star, 0.35)
			link(scene, from, Vector3.new(x, center.Y, center.Z), c1, 0.35, 0.3)
			later(0.28, function()
				local f = ball(scene, Vector3.new(x, center.Y, center.Z), 1.2, c1, 0.1)
				fade(f, 0.3, { Size = Vector3.new(4, 4, 4) })
			end)
		end)
	end
end

-- Heal kinds ---------------------------------------------------------------------------------------
local HEAL = {}

function HEAL.Rings(scene, tgt, c1, c2)
	for i = 0, 2 do
		later(i * 0.12, function()
			local r = ring(scene, ground(scene, tgt) + Vector3.new(0, i * 0.2, 0), c1, 4, 2.5, 0.5, 0.2)
			TweenService:Create(r, TweenInfo.new(0.5), { Position = r.Position + Vector3.new(0, 4, 0) }):Play()
		end)
	end
	for _ = 1, 6 do
		local sp = ball(scene, tgt + Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(-2, 0), rng:NextNumber(-0.5, 0.5)), 0.4, c2, 0.1)
		fade(sp, 0.7, { Position = sp.Position + Vector3.new(0, rng:NextNumber(3, 5), 0) })
	end
end

function HEAL.Spiral(scene, tgt, c1, c2)
	for i = 1, 14 do
		later(i * 0.03, function()
			local a = i * 0.75
			local sp = ball(scene, tgt + Vector3.new(math.cos(a) * 1.6, -2 + i * 0.32, math.sin(a) * 0.8), 0.5, if i % 2 == 0 then c1 else c2, 0.05)
			fade(sp, 0.45, { Size = Vector3.new(0.1, 0.1, 0.1) })
		end)
	end
end

function HEAL.Bloom(scene, tgt, c1, c2)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local petal = ball(scene, tgt, 0.8, if i % 2 == 0 then c1 else c2, 0.1)
		fade(petal, 0.6, { Position = tgt + Vector3.new(math.cos(a) * 2.6, 1 + math.sin(a) * 1.2, 0), Size = Vector3.new(1.4, 1.4, 1.4) })
	end
	local f = ball(scene, tgt, 1, c2, 0.3)
	fade(f, 0.4, { Size = Vector3.new(4, 4, 4) })
end

function HEAL.Cross(scene, tgt, c1, c2)
	local center = tgt + Vector3.new(0, 1.5, 0)
	for _, size in ipairs({ Vector3.new(0.5, 2.8, 0.4), Vector3.new(2.8, 0.5, 0.4) }) do
		local p = mk(scene, { Size = size, Color = c1, Transparency = 0.05, Position = center })
		fade(p, 0.75, { Position = center + Vector3.new(0, 2.5, 0) })
	end
	local f = ball(scene, center, 1, c2, 0.3)
	fade(f, 0.4, { Size = Vector3.new(4.5, 4.5, 4.5) })
end

-- Shield kinds -------------------------------------------------------------------------------------
local SHIELD = {}

function SHIELD.Dome(scene, tgt, c1, c2)
	local dome = ball(scene, tgt, 1, c1, 0.7)
	TweenService:Create(dome, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(7, 7, 7), Transparency = 0.55 }):Play()
	task.delay(0.35, function()
		fade(dome, 0.45)
	end)
	Debris:AddItem(dome, 1.2)
	ring(scene, ground(scene, tgt), c2, 3, 8, 0.5, 0.2)
end

function SHIELD.Barrier(scene, tgt, c1, c2)
	local face = if tgt.X < 0 then 1 else -1 -- the slab stands between the hero and the monsters
	for i = 1, 3 do
		local slab = mk(scene, { Size = Vector3.new(0.4, 0.2, 4.5), Color = if i == 2 then c2 else c1, Transparency = 0.4, Position = tgt + Vector3.new(face * 2.2, -1.5 + i * 1.4, 0) })
		TweenService:Create(slab, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, 1.4, 4.5) }):Play()
		task.delay(0.4, function()
			fade(slab, 0.4)
		end)
		Debris:AddItem(slab, 1.1)
	end
	ring(scene, ground(scene, tgt), c1, 2, 6, 0.4, 0.2)
end

function SHIELD.Bubble(scene, tgt, c1, c2)
	local bub = ball(scene, tgt, 1, c1, 0.6)
	TweenService:Create(bub, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(5, 5, 5) }):Play()
	task.delay(0.3, function()
		fade(bub, 0.4)
	end)
	Debris:AddItem(bub, 1)
	for _ = 1, 5 do
		local b = ball(scene, tgt + Vector3.new(rng:NextNumber(-1.5, 1.5), -1.5, 0), 0.5, c2, 0.3)
		fade(b, 0.7, { Position = b.Position + Vector3.new(0, rng:NextNumber(2.5, 4), 0) })
	end
end

-- Buff kinds ---------------------------------------------------------------------------------------
local BUFF = {}

function BUFF.Chevrons(scene, tgt, c1)
	for i = 0, 2 do
		later(i * 0.1, function()
			glyphPop(scene, tgt + Vector3.new(0, -1.5 + i * 0.4, 0), "▲", c1, 30, 3.2, 0.6)
		end)
	end
	ring(scene, ground(scene, tgt), c1, 3, 6, 0.4, 0.15)
end

function BUFF.Glyph(scene, tgt, c1, _, glyph)
	glyphPop(scene, tgt + Vector3.new(0, 2.5, 0), glyph or "✦", c1, 40, 2.5, 0.9)
	ring(scene, ground(scene, tgt), c1, 2, 7, 0.45, 0.15)
end

function BUFF.Pulse(scene, tgt, c1)
	local f = ball(scene, tgt, 1.5, c1, 0.4)
	fade(f, 0.5, { Size = Vector3.new(6, 6, 6) })
	ring(scene, ground(scene, tgt), c1, 2, 9, 0.5, 0.25)
	ring(scene, ground(scene, tgt), c1, 4, 6, 0.35, 0.15)
end

-- true when the skill has a look of its own (the replay then skips its old generic bolt)
function SkillEffects.HasStyle(ability)
	return ability ~= nil and Config.Abilities[ability] ~= nil
end

-- public -------------------------------------------------------------------------------------------
function SkillEffects.Hit(scene, ability, srcPos, tgtPos, classId)
	local style
	local scale = 1
	if ability == nil then
		style = Config.Basic[classId or "Enemy"] or Config.Basic.Enemy
		scale = 0.55
	else
		style = Config.Abilities[ability]
		-- a skill that hits an area draws that once on Cast, so each target only gets a small spark
		if style and style.Area and not style.Hit then
			style = { Hit = "Burst", Color = style.Color, Color2 = style.Color2 }
			scale = 0.8
		end
	end
	if not style or not style.Hit then
		return
	end
	local c1, c2 = colorsOf(style)
	local fn = HIT[style.Hit]
	if fn then
		fn(scene, srcPos, tgtPos, c1, c2, scale)
	end
end

function SkillEffects.Heal(scene, ability, tgtPos)
	local style = ability and Config.Abilities[ability]
	if not style or not style.Heal then
		style = { Heal = "Rings", Color = { 110, 235, 140 }, Color2 = { 220, 255, 220 } }
	end
	local c1, c2 = colorsOf(style)
	local fn = HEAL[style.Heal]
	if fn then
		fn(scene, tgtPos, c1, c2)
	end
end

function SkillEffects.Status(scene, statusId, tgtPos, ability)
	local status = Config.Statuses[statusId]
	if not status then
		return
	end
	local abilityStyle = ability and Config.Abilities[ability]
	if status.Shield then
		local style = abilityStyle and abilityStyle.Shield and abilityStyle or status
		local kind = if abilityStyle and abilityStyle.Shield then abilityStyle.Shield else status.Shield
		local c1, c2 = colorsOf(style)
		local fn = SHIELD[kind]
		if fn then
			fn(scene, tgtPos, c1, c2)
		end
	elseif status.Buff then
		local style = abilityStyle and abilityStyle.Buff and abilityStyle or status
		local kind = if abilityStyle and abilityStyle.Buff then abilityStyle.Buff else status.Buff
		local c1, c2 = colorsOf(style)
		local fn = BUFF[kind]
		if fn then
			fn(scene, tgtPos, c1, c2, style.Glyph or status.Glyph)
		end
	end
end

function SkillEffects.Revive(scene, pos)
	local c1, c2 = c3({ 255, 240, 150 }), c3({ 255, 255, 255 })
	HIT.Pillar(scene, nil, pos, c1, c2, 1)
	for i = 1, 8 do
		local sp = ball(scene, ground(scene, pos) + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, 0), 0.6, c2, 0.1)
		fade(sp, 0.9, { Position = sp.Position + Vector3.new(0, rng:NextNumber(4, 8), 0) })
	end
	glyphPop(scene, pos + Vector3.new(0, 3, 0), "✚", c1, 44, 3, 1)
end

function SkillEffects.Cast(scene, ctx)
	local style = Config.Abilities[ctx.Ability]
	if not style then
		return
	end
	local c1, c2 = colorsOf(style)
	-- area skills: one show over the side they hit (monsters cast on the party, the party on the monsters)
	if style.Area then
		local fn = AREA[style.Area]
		if fn then
			fn(scene, { SourcePos = ctx.SourcePos, SourceIsHero = ctx.SourceIsHero, Targets = (if ctx.SourceIsHero then ctx.EnemyPositions else ctx.AllyPositions) or {} }, c1, c2)
		end
	end
	-- pet skills: the pet's own symbol pops up over the pet
	if style.Glyph and ctx.PetPos then
		glyphPop(scene, ctx.PetPos + Vector3.new(0, 2.5, 0), style.Glyph, c1, 46, 3, 1.1)
		ring(scene, ground(scene, ctx.PetPos), c1, 1, 5, 0.5, 0.2)
	end
end

-- Ultimates: big shows -----------------------------------------------------------------------------
local ULT = {}

function ULT.Charge(scene, ctx, c1, c2)
	local fromX = (ctx.AllyPositions[1] and ctx.AllyPositions[1].X) or -9
	for i, p in ipairs(ctx.EnemyPositions) do
		later(0.15 * i, function()
			HIT.Pillar(scene, nil, p, c1, c2, 1.6)
			ring(scene, ground(scene, p), c2, 2, 14, 0.6, 0.3)
		end)
	end
	local center = ctx.EnemyPositions[1] or Vector3.new(fromX + 16, 0, 0)
	AREA.Wave(scene, { SourcePos = Vector3.new(fromX, center.Y, center.Z), SourceIsHero = true, Targets = ctx.EnemyPositions }, c1, c2)
	for _, p in ipairs(ctx.AllyPositions) do
		HEAL.Rings(scene, p, c1, c2)
	end
end

function ULT.Dawn(scene, ctx, c1, c2)
	local lo, hi, center = spanOf(ctx.AllyPositions, Vector3.new(-11, 3, 0))
	local mid = Vector3.new((lo + hi) / 2, center.Y + 1, center.Z)
	local dome = ball(scene, mid, 2, c1, 0.7)
	TweenService:Create(dome, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(17, 17, 17), Transparency = 0.6 }):Play()
	task.delay(1.2, function()
		fade(dome, 0.6)
	end)
	Debris:AddItem(dome, 2.4)
	local sun = ball(scene, mid + Vector3.new(0, 11, 0), 3, c2, 0.05)
	fade(sun, 1.4, { Size = Vector3.new(5, 5, 5) })
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local ray = mk(scene, { Size = Vector3.new(0.3, 0.3, 0.3), Color = c2, Transparency = 0.2, CFrame = CFrame.lookAt(sun.Position, sun.Position + Vector3.new(math.cos(a), math.sin(a), 0)) })
		fade(ray, 1.2, { Size = Vector3.new(0.3, 0.3, 14) })
	end
	for _, p in ipairs(ctx.AllyPositions) do
		SHIELD.Barrier(scene, p, c1, c2)
		BUFF.Chevrons(scene, p, c1)
	end
	ring(scene, ground(scene, mid), c1, 4, 26, 0.9, 0.4)
end

function ULT.Judgment(scene, ctx, c1, c2)
	for i, p in ipairs(ctx.EnemyPositions) do
		later(0.2 * (i - 1), function()
			HIT.Beam(scene, nil, p, c1, c2, 2.4)
			ring(scene, ground(scene, p), c1, 2, 18, 0.7, 0.35)
		end)
	end
	later(0.5, function()
		AREA.Starfall(scene, { SourcePos = Vector3.new(0, 3, 0), SourceIsHero = true, Targets = ctx.EnemyPositions }, c1, c2)
		AREA.Nova(scene, { SourcePos = Vector3.new(0, 3, 0), SourceIsHero = true, Targets = ctx.EnemyPositions }, c1, c2)
	end)
end

function ULT.Generic(scene, ctx, c1, c2)
	for _, p in ipairs(ctx.AllyPositions) do
		BUFF.Pulse(scene, p, c1)
	end
	AREA.Nova(scene, { SourcePos = Vector3.new(0, 3, 0), SourceIsHero = true, Targets = ctx.EnemyPositions }, c1, c2)
end

function SkillEffects.Ultimate(scene, ultimateId, ctx)
	local style = Config.Ultimates[ultimateId] or Config.DefaultUltimate
	local fn = ULT[style.Kind] or ULT.Generic
	local c1, c2 = colorsOf(style)
	fn(scene, { AllyPositions = ctx.AllyPositions or {}, EnemyPositions = ctx.EnemyPositions or {} }, c1, c2)
end

return SkillEffects
