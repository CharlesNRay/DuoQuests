--[[
	Backdrops (ModuleScript): the scenery behind a fight (built by Scene:_backdrop). Each zone (Config/Zones) names a
	Backdrop style; a style builds one silhouette per call (mountains, hills, mesas, a volcano, ruins, floating islands,
	glowing crystals, storms with lightning...). Scene places 5 far ones and 6 near ones on the lot's back strip and
	scrolls them slowly (parallax) while the party walks.

	  Backdrops.Build(parent, theme, rng, far, fx) -> Model   (pivot at its foot, centred; at most ~24 studs wide)
	      far  true for the back layer (paler, taller), false for the near one
	      fx(part, kind, info)  registers an animated part: "Bolt" (a lightning flash now and then; info.Parts flash together), "Wave" (glow that
	                            breathes: info.Base, info.Amp, info.Speed)

	Kept modest in size (2026-11-24 owner: the old big round hills looked like bubbles); built from parts only.
]]
local Backdrops = {}

local function color(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function prop(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function wedge(parent, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function newModel(parent)
	local m = Instance.new("Model")
	local base = prop(m, { Name = "Pivot", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	m.PrimaryPart = base
	m.Parent = parent
	return m
end

-- a triangular ridge (a mountain seen side-on): two wedges back to back, apex at (x, y + h)
local function ridge(m, x, y, w, h, d, col, material, z)
	material = material or Enum.Material.Slate
	z = z or 0
	wedge(m, { Size = Vector3.new(d, h, w / 2), CFrame = CFrame.new(x - w / 4, y + h / 2, z) * CFrame.Angles(0, math.rad(90), 0), Color = col, Material = material })
	wedge(m, { Size = Vector3.new(d, h, w / 2), CFrame = CFrame.new(x + w / 4, y + h / 2, z) * CFrame.Angles(0, math.rad(-90), 0), Color = col, Material = material })
end

-- a peak with a cap (snow, lava, gold...) on its top third
local function peak(m, x, w, h, d, col, cap, capMaterial, material)
	ridge(m, x, 0, w, h, d, col, material)
	if cap then
		ridge(m, x, h * 0.66, w * 0.34, h * 0.34, d + 0.3, cap, capMaterial or Enum.Material.Snow, 0.1)
	end
end

-- a rounded hill (the top half of a squashed ball) with little trees along its crest
local function hill(m, x, w, h, col, tuft, tufts)
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w, h * 2, 5), CFrame = CFrame.new(x, 0, 0), Color = col, Material = Enum.Material.Grass })
	for i = 1, tufts or 0 do
		local t = (i - 0.5) / tufts * 1.4 - 0.7 -- across the middle of the crest
		local hx = x + t * w / 2
		local hy = h * math.sqrt(math.max(0, 1 - t * t))
		local s = 1.6 + (i % 2) * 0.6
		prop(m, { Size = Vector3.new(0.4, s, 0.4), CFrame = CFrame.new(hx, hy + s / 2 - 0.3, 0.6), Color = Color3.fromRGB(90, 64, 44) })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.1, s * 1.1, s * 1.1), CFrame = CFrame.new(hx, hy + s, 0.6), Color = tuft, Material = Enum.Material.Grass })
	end
end

local function glow(part, colour, range)
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = range or 10
	light.Brightness = 1.2
	light.Parent = part
end

-- a jagged lightning bolt: three neon segments, hidden until it flashes
local function bolt(m, x, top, length, colour, fx)
	local y = top
	local px = x
	local parts = {}
	for i = 1, 3 do
		local seg = length / 3
		local nx = px + (if i % 2 == 1 then 1.4 else -1.2)
		local mid = Vector3.new((px + nx) / 2, y - seg / 2, 0.5)
		local part = prop(m, {
			Size = Vector3.new(0.35, seg + 0.4, 0.35), CFrame = CFrame.lookAt(mid, mid + Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, math.atan2(nx - px, seg)),
			Color = colour, Material = Enum.Material.Neon, Transparency = 1,
		})
		table.insert(parts, part)
		px, y = nx, y - seg
	end
	fx(parts[1], "Bolt", { Parts = parts }) -- the segments flash together
end

-- a crystal cluster (the Glimmer Cave look): neon shards fanned out from one root
local function crystals(m, x, h, colour, count, fx, y)
	y = y or 0
	for i = 1, count do
		local t = (i - (count + 1) / 2)
		local s = h * (1 - math.abs(t) * 0.22)
		local part = prop(m, {
			Size = Vector3.new(0.9 + (i % 2) * 0.4, s, 0.9), CFrame = CFrame.new(x + t * 0.9, y + s / 2 - 0.2, 0.3 * (i % 2)) * CFrame.Angles(0, 0, math.rad(t * 14)),
			Color = colour, Material = Enum.Material.Neon, Transparency = 0.1,
		})
		if fx and i == 1 then
			fx(part, "Wave", { Base = 0.15, Amp = 0.12, Speed = 1.3 + (x % 1) })
		end
	end
end

-- one silhouette per style ------------------------------------------------------------------------------------------
local STYLES = {}

-- rolling hills with little trees; pale mountains behind
STYLES.Hills = function(m, theme, rng, far)
	local sky = color(theme.Sky)
	if far then
		peak(m, 0, rng:NextNumber(14, 22), rng:NextNumber(9, 14), 3, color(theme.Accent):Lerp(sky, 0.55), Color3.fromRGB(245, 248, 255):Lerp(sky, 0.2))
	else
		local base = color(theme.Ground):Lerp(color(theme.Accent), 0.45)
		hill(m, 0, rng:NextNumber(14, 22), rng:NextNumber(4, 6.5), base, color(theme.Accent), rng:NextInteger(2, 4))
	end
end

-- sharp mountain ranges; the far ones snow-capped
STYLES.Peaks = function(m, theme, rng, far)
	local sky = color(theme.Sky)
	local rock = color(theme.Accent)
	if far then
		peak(m, -3, rng:NextNumber(12, 18), rng:NextNumber(10, 15), 3, rock:Lerp(sky, 0.45), Color3.fromRGB(250, 252, 255))
		peak(m, 5, rng:NextNumber(9, 13), rng:NextNumber(7, 10), 2.6, rock:Lerp(sky, 0.35), Color3.fromRGB(240, 246, 255))
	else
		peak(m, 0, rng:NextNumber(10, 16), rng:NextNumber(5, 8), 3, rock:Lerp(color(theme.Ground), 0.3), rock:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Slate)
	end
end

-- the Glimmer Cave: dark rock spires and glowing crystal clusters
STYLES.Cave = function(m, theme, rng, far, fx)
	local accent = color(theme.Accent)
	if far then
		ridge(m, -2, 0, rng:NextNumber(6, 9), rng:NextNumber(10, 15), 3, Color3.fromRGB(44, 38, 64))
		ridge(m, 4, 0, rng:NextNumber(4, 6), rng:NextNumber(7, 11), 3, Color3.fromRGB(54, 46, 78))
		crystals(m, 1, rng:NextNumber(4, 6), accent:Lerp(Color3.new(1, 1, 1), 0.15), 3, fx)
	else
		ridge(m, 0, 0, rng:NextNumber(8, 12), rng:NextNumber(3, 5), 3, Color3.fromRGB(60, 52, 86))
		crystals(m, rng:NextNumber(-2, 2), rng:NextNumber(4, 7), accent, rng:NextInteger(3, 5), fx)
		glow(m.PrimaryPart, accent, 12)
	end
end

-- desert: striped mesas far, soft dunes near
STYLES.Dunes = function(m, theme, rng, far)
	local sand = color(theme.Ground)
	if far then
		local w, h = rng:NextNumber(10, 16), rng:NextNumber(6, 10)
		local rock = Color3.fromRGB(196, 120, 80):Lerp(color(theme.Sky), 0.3)
		prop(m, { Size = Vector3.new(w, h, 4), CFrame = CFrame.new(0, h / 2, 0), Color = rock, Material = Enum.Material.Sandstone })
		prop(m, { Size = Vector3.new(w + 1.2, 1, 4.4), CFrame = CFrame.new(0, h, 0), Color = rock:Lerp(Color3.new(1, 1, 1), 0.15), Material = Enum.Material.Sandstone })
		prop(m, { Size = Vector3.new(w + 0.2, 0.8, 4.2), CFrame = CFrame.new(0, h * 0.45, 0), Color = rock:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Sandstone })
	else
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(rng:NextNumber(16, 24), rng:NextNumber(4, 7), 6), CFrame = CFrame.new(0, 0, 0), Color = sand:Lerp(Color3.fromRGB(230, 170, 100), 0.3), Material = Enum.Material.Sand })
	end
end

-- a volcano with glowing lava far, dark cracked crags near
STYLES.Volcano = function(m, theme, rng, far, fx)
	local lava = color(theme.Accent)
	if far then
		local w, h = rng:NextNumber(16, 22), rng:NextNumber(11, 15)
		peak(m, 0, w, h, 3.2, Color3.fromRGB(52, 40, 40), lava, Enum.Material.Neon, Enum.Material.Basalt)
		local streak = prop(m, { Size = Vector3.new(0.5, h * 0.55, 0.3), CFrame = CFrame.new(w * 0.08, h * 0.42, 1.65) * CFrame.Angles(0, 0, math.rad(-18)), Color = lava, Material = Enum.Material.Neon })
		fx(streak, "Wave", { Base = 0.05, Amp = 0.25, Speed = 1.1 })
		for i = 1, 3 do -- a thin plume of smoke, widening as it rises
			local s = 1.6 + i * 1.1
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.8, s), CFrame = CFrame.new(i * 0.6, h + i * 1.8, -0.5), Color = Color3.fromRGB(80, 70, 70), Transparency = 0.45 + i * 0.12 })
		end
	else
		ridge(m, 0, 0, rng:NextNumber(8, 12), rng:NextNumber(4, 7), 3, Color3.fromRGB(44, 36, 36), Enum.Material.Basalt)
		prop(m, { Size = Vector3.new(0.3, 3, 0.3), CFrame = CFrame.new(-0.6, 1.8, 1.6) * CFrame.Angles(0, 0, math.rad(25)), Color = lava, Material = Enum.Material.Neon })
	end
end

-- swamp: low dark mounds with drooping willows, a band of mist
STYLES.Swamp = function(m, theme, rng, far)
	local mound = color(theme.Ground):Lerp(color(theme.Sky), if far then 0.45 else 0.1)
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(rng:NextNumber(12, 18), rng:NextNumber(5, 8), 5), CFrame = CFrame.new(0, 0, 0), Color = mound, Material = Enum.Material.Mud })
	local bark = Color3.fromRGB(58, 50, 42):Lerp(color(theme.Sky), if far then 0.4 else 0)
	local h = rng:NextNumber(5, 8)
	prop(m, { Size = Vector3.new(0.6, h, 0.6), CFrame = CFrame.new(2, h / 2 + 1, 0.8), Color = bark })
	for i = -1, 1 do
		prop(m, { Size = Vector3.new(0.25, h * 0.45, 0.25), CFrame = CFrame.new(2 + i * 1.3, h * 0.85, 1) * CFrame.Angles(0, 0, math.rad(i * 25)), Color = Color3.fromRGB(90, 110, 70):Lerp(color(theme.Sky), if far then 0.4 else 0) })
	end
	if not far then
		prop(m, { Size = Vector3.new(22, 2.5, 3), CFrame = CFrame.new(0, 1.2, 2.5), Color = Color3.fromRGB(190, 220, 190), Transparency = 0.75, Material = Enum.Material.SmoothPlastic })
	end
end

-- sunken ruins: an arch far, broken columns near
STYLES.Ruins = function(m, theme, rng, far)
	local stone = color(theme.Accent):Lerp(color(theme.Sky), if far then 0.35 else 0)
	if far then
		local h = rng:NextNumber(8, 11)
		for _, x in ipairs({ -4, 4 }) do
			prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.8, 1.8), CFrame = CFrame.new(x, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = stone, Material = Enum.Material.Cobblestone })
		end
		prop(m, { Size = Vector3.new(11, 1.4, 2.2), CFrame = CFrame.new(0, h + 0.6, 0), Color = stone, Material = Enum.Material.Cobblestone })
		prop(m, { Size = Vector3.new(3, 1.2, 2.2), CFrame = CFrame.new(-1, h + 1.8, 0) * CFrame.Angles(0, 0, math.rad(8)), Color = stone, Material = Enum.Material.Cobblestone })
	else
		for i = -1, 1 do
			local h = rng:NextNumber(2.5, 7)
			prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(i * 4, h / 2, (i % 2) * 0.8) * CFrame.Angles(0, 0, math.rad(90 + i * 4)), Color = stone, Material = Enum.Material.Cobblestone })
		end
	end
end

-- above the clouds: floating islands far, soft cloud banks near
STYLES.Sky = function(m, theme, rng, far)
	if far then
		local w, y = rng:NextNumber(8, 12), rng:NextNumber(6, 10)
		local rock = Color3.fromRGB(150, 140, 160):Lerp(color(theme.Sky), 0.3)
		-- the rocky underside is an upside-down ridge
		wedge(m, { Size = Vector3.new(3, 4, w / 2), CFrame = CFrame.new(-w / 4, y - 2, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = rock, Material = Enum.Material.Slate })
		wedge(m, { Size = Vector3.new(3, 4, w / 2), CFrame = CFrame.new(w / 4, y - 2, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180)), Color = rock, Material = Enum.Material.Slate })
		prop(m, { Size = Vector3.new(w, 0.8, 3.2), CFrame = CFrame.new(0, y + 0.4, 0), Color = Color3.fromRGB(150, 210, 140), Material = Enum.Material.Grass })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(1.5, y + 2.2, 0), Color = Color3.fromRGB(120, 190, 120) })
	else
		for i = -1, 1 do
			local s = rng:NextNumber(3, 5)
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.6, s, s), CFrame = CFrame.new(i * s * 0.9, s * 0.4 - math.abs(i) * 0.5, 0), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic })
		end
	end
end

-- Stormspire: jagged dark peaks with lightning flashing behind them
STYLES.Storm = function(m, theme, rng, far, fx)
	local rock = Color3.fromRGB(52, 56, 74):Lerp(color(theme.Sky), if far then 0.3 else 0)
	if far then
		ridge(m, -3, 0, rng:NextNumber(7, 10), rng:NextNumber(11, 15), 3, rock)
		ridge(m, 3.5, 0, rng:NextNumber(6, 8), rng:NextNumber(8, 11), 3, rock:Lerp(Color3.new(0, 0, 0), 0.1))
		bolt(m, rng:NextNumber(-4, 4), 20, rng:NextNumber(9, 14), color(theme.Accent), fx)
	else
		ridge(m, 0, 0, rng:NextNumber(6, 9), rng:NextNumber(4, 7), 3, rock)
		local tip = prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(0, 6.5, 1.4), Color = color(theme.Accent), Material = Enum.Material.Neon })
		fx(tip, "Wave", { Base = 0.1, Amp = 0.5, Speed = 3 })
	end
end

-- Tidal Deep: rock arches far, glowing coral fans and kelp near
STYLES.Reef = function(m, theme, rng, far, fx)
	if far then
		local rock = Color3.fromRGB(40, 90, 110):Lerp(color(theme.Sky), 0.25)
		local h = rng:NextNumber(7, 10)
		prop(m, { Size = Vector3.new(2.2, h, 3), CFrame = CFrame.new(-4, h / 2, 0), Color = rock, Material = Enum.Material.Slate })
		prop(m, { Size = Vector3.new(2.2, h * 0.8, 3), CFrame = CFrame.new(4, h * 0.4, 0), Color = rock, Material = Enum.Material.Slate })
		prop(m, { Size = Vector3.new(10.5, 1.8, 3), CFrame = CFrame.new(0, h * 0.85, 0) * CFrame.Angles(0, 0, math.rad(-6)), Color = rock, Material = Enum.Material.Slate })
	else
		local corals = { color(theme.Accent), Color3.fromRGB(255, 150, 90), Color3.fromRGB(120, 230, 220) }
		for i = -1, 1 do
			local c = corals[i + 2]
			local fan = prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, rng:NextNumber(2.5, 4), rng:NextNumber(2.5, 4)), CFrame = CFrame.new(i * 3.2, 2, 0.4) * CFrame.Angles(0, math.rad(90), 0), Color = c, Material = Enum.Material.Neon, Transparency = 0.25 })
			if i == 0 then
				fx(fan, "Wave", { Base = 0.2, Amp = 0.15, Speed = 0.9 })
			end
		end
		for i = 1, 3 do
			local h = rng:NextNumber(4, 7)
			prop(m, { Size = Vector3.new(0.4, h, 0.4), CFrame = CFrame.new(-5 + i * 3.4, h / 2, -0.6) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), Color = Color3.fromRGB(60, 150, 90), Material = Enum.Material.Grass })
		end
	end
end

-- Phoenix Pyre: flame-shaped spires (red outside, yellow heart)
STYLES.Pyre = function(m, theme, rng, far, fx)
	local h = if far then rng:NextNumber(9, 13) else rng:NextNumber(4, 7)
	local w = h * 0.55
	ridge(m, 0, 0, w, h, 2.4, Color3.fromRGB(70, 30, 26):Lerp(color(theme.Sky), if far then 0.25 else 0), Enum.Material.Basalt)
	ridge(m, 0, h * 0.15, w * 0.6, h * 0.75, 2.6, color(theme.Accent), Enum.Material.Neon, 0.1)
	ridge(m, 0, h * 0.3, w * 0.3, h * 0.45, 2.8, Color3.fromRGB(255, 225, 120), Enum.Material.Neon, 0.2)
	if not far then
		glow(m.PrimaryPart, color(theme.Accent), 10)
	end
end

-- Glowshroom Hollow: giant mushrooms with glowing spots
STYLES.Fungal = function(m, theme, rng, far, fx)
	local h = if far then rng:NextNumber(8, 12) else rng:NextNumber(4, 6.5)
	local capW = h * 0.9
	local stem = Color3.fromRGB(220, 210, 190):Lerp(color(theme.Sky), if far then 0.35 else 0)
	local cap = color(theme.Accent):Lerp(color(theme.Sky), if far then 0.3 else 0)
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, h * 0.16, h * 0.16), CFrame = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = stem })
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(capW, h * 0.42, capW * 0.6), CFrame = CFrame.new(0, h, 0), Color = cap })
	for i = -1, 1 do
		local spot = prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.1, h * 0.1, h * 0.1), CFrame = CFrame.new(i * capW * 0.25, h + h * 0.12 - math.abs(i) * h * 0.05, capW * 0.28), Color = Color3.fromRGB(200, 255, 180), Material = Enum.Material.Neon })
		if i == 0 then
			fx(spot, "Wave", { Base = 0.05, Amp = 0.4, Speed = 1.6 })
		end
	end
	if not far then
		glow(m.PrimaryPart, cap, 10)
	end
end

-- Aurora Wastes: ice peaks under rippling aurora ribbons
STYLES.Aurora = function(m, theme, rng, far, fx)
	local ice = Color3.fromRGB(170, 210, 240)
	if far then
		peak(m, 0, rng:NextNumber(12, 18), rng:NextNumber(8, 12), 3, ice:Lerp(color(theme.Sky), 0.4), Color3.fromRGB(255, 255, 255))
		-- an aurora curtain: thin glowing strips hanging from a wavy line, each breathing a little out of step
		local colours = { color(theme.Accent), Color3.fromRGB(120, 200, 255), Color3.fromRGB(160, 120, 255) }
		local phase = rng:NextNumber(0, 6)
		for i = 1, 9 do
			local x = -8 + i * 1.7
			local top = 22 + math.sin(phase + i * 0.7) * 1.6
			local len = 4 + math.sin(phase * 1.3 + i * 1.1) * 1.5
			local strip = prop(m, { Size = Vector3.new(1.5, len, 0.15), CFrame = CFrame.new(x, top - len / 2, -1), Color = colours[(i % 3) + 1], Material = Enum.Material.Neon, Transparency = 0.55 })
			fx(strip, "Wave", { Base = 0.6, Amp = 0.25, Speed = 0.8 + (i % 3) * 0.25 })
		end
	else
		for i = -1, 1 do
			local h = rng:NextNumber(3, 6)
			ridge(m, i * 3, 0, h * 0.5, h, 1.6, ice, Enum.Material.Glacier)
		end
	end
end

-- Astral Expanse: ringed planets and floating rocks
STYLES.Astral = function(m, theme, rng, far, fx)
	if far then
		local s = rng:NextNumber(4, 7)
		local planet = prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(0, rng:NextNumber(14, 20), 0), Color = color(theme.Accent):Lerp(Color3.fromRGB(255, 160, 120), rng:NextNumber(0, 1)), Material = Enum.Material.SmoothPlastic })
		prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, s * 1.9, s * 1.9), CFrame = planet.CFrame * CFrame.Angles(0, 0, math.rad(70)) * CFrame.Angles(math.rad(20), 0, 0), Color = Color3.fromRGB(230, 220, 255), Material = Enum.Material.Neon, Transparency = 0.45 })
	else
		local y = rng:NextNumber(3, 7)
		local rock = Color3.fromRGB(70, 64, 100)
		wedge(m, { Size = Vector3.new(2.6, 3, 2.5), CFrame = CFrame.new(-1.25, y - 1.5, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = rock, Material = Enum.Material.Slate })
		wedge(m, { Size = Vector3.new(2.6, 3, 2.5), CFrame = CFrame.new(1.25, y - 1.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180)), Color = rock, Material = Enum.Material.Slate })
		prop(m, { Size = Vector3.new(5, 0.6, 2.6), CFrame = CFrame.new(0, y + 0.3, 0), Color = rock:Lerp(Color3.new(1, 1, 1), 0.15), Material = Enum.Material.Slate })
		crystals(m, 0.5, 2.2, color(theme.Accent), 2, fx, y + 0.6)
	end
end

-- Void Rift: black spikes with purple cracks, floating void shards
STYLES.Void = function(m, theme, rng, far, fx)
	local black = Color3.fromRGB(26, 20, 36):Lerp(color(theme.Sky), if far then 0.25 else 0)
	local purple = color(theme.Accent)
	if far then
		for i = -1, 1 do
			ridge(m, i * 3.4, 0, rng:NextNumber(3, 5), rng:NextNumber(8, 15), 2.5, black)
		end
		local crack = prop(m, { Size = Vector3.new(0.3, 7, 0.3), CFrame = CFrame.new(0.4, 4.5, 1.4) * CFrame.Angles(0, 0, math.rad(8)), Color = purple, Material = Enum.Material.Neon })
		fx(crack, "Wave", { Base = 0.05, Amp = 0.5, Speed = 2.2 })
	else
		ridge(m, 0, 0, rng:NextNumber(4, 6), rng:NextNumber(4, 7), 2.4, black)
		for i = 1, 2 do
			local shard = prop(m, { Size = Vector3.new(0.7, 2.2, 0.7), CFrame = CFrame.new(-3 + i * 2.5, rng:NextNumber(6, 9), 0.5) * CFrame.Angles(math.rad(20), 0, math.rad(rng:NextNumber(-30, 30))), Color = purple, Material = Enum.Material.Neon, Transparency = 0.15 })
			fx(shard, "Wave", { Base = 0.1, Amp = 0.35, Speed = 1.4 + i * 0.4 })
		end
	end
end

-- Radiant Sanctum: golden domed towers with beams of light
STYLES.Radiant = function(m, theme, rng, far, fx)
	local gold = Color3.fromRGB(230, 190, 90):Lerp(color(theme.Sky), if far then 0.25 else 0)
	local h = if far then rng:NextNumber(9, 13) else rng:NextNumber(4, 6)
	local w = if far then 3 else 1.8
	prop(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, w, w), CFrame = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(245, 238, 220):Lerp(color(theme.Sky), if far then 0.25 else 0), Material = Enum.Material.Marble })
	prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w * 1.4, w * 1.4, w * 1.4), CFrame = CFrame.new(0, h + w * 0.2, 0), Color = gold, Material = Enum.Material.Foil })
	if far then
		local beam = prop(m, { Size = Vector3.new(1.4, 16, 0.2), CFrame = CFrame.new(0, h + 9, -0.5), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon, Transparency = 0.6 })
		fx(beam, "Wave", { Base = 0.6, Amp = 0.25, Speed = 0.7 })
	end
end

-- Gale Heights: floating islands with wind ribbons streaming past
STYLES.Gale = function(m, theme, rng, far, fx)
	STYLES.Sky(m, theme, rng, far)
	local ribbon = prop(m, { Size = Vector3.new(rng:NextNumber(8, 14), 0.25, 0.2), CFrame = CFrame.new(0, rng:NextNumber(4, 12), 1) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Neon, Transparency = 0.5 })
	fx(ribbon, "Wave", { Base = 0.5, Amp = 0.4, Speed = 1.2 })
end

-- a cute face on a slime: two shiny eyes and a little smile, on the side facing the fight
local function face(m, x, y, z, s)
	for side = -1, 1, 2 do
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.16, s * 0.22, s * 0.1), CFrame = CFrame.new(x + side * s * 0.16, y, z), Color = Color3.fromRGB(30, 24, 40) })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.06, s * 0.06, s * 0.05), CFrame = CFrame.new(x + side * s * 0.16 + s * 0.03, y + s * 0.05, z + s * 0.04), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	end
	prop(m, { Size = Vector3.new(s * 0.14, s * 0.04, s * 0.05), CFrame = CFrame.new(x, y - s * 0.13, z), Color = Color3.fromRGB(30, 24, 40) })
	for side = -1, 1, 2 do -- rosy cheeks
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.1, s * 0.06, s * 0.04), CFrame = CFrame.new(x + side * s * 0.3, y - s * 0.08, z - s * 0.01), Color = Color3.fromRGB(255, 140, 170), Transparency = 0.2 })
	end
end

-- Slime Meadows: big wobbly jelly hills with happy faces, little slimes in front, a candy-coloured sky
local SLIME_COLOURS = { { 120, 230, 140 }, { 255, 150, 200 }, { 130, 190, 255 }, { 255, 210, 110 }, { 190, 150, 255 } }
STYLES.Slime = function(m, theme, rng, far, fx)
	local c = SLIME_COLOURS[rng:NextInteger(1, #SLIME_COLOURS)]
	local col = Color3.fromRGB(c[1], c[2], c[3])
	if far then
		local w, h = rng:NextNumber(10, 15), rng:NextNumber(5, 8)
		col = col:Lerp(color(theme.Sky), 0.2)
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w, h * 2, 6), CFrame = CFrame.new(0, 0, 0), Color = col, Material = Enum.Material.Glass, Transparency = 0.15 })
		prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.25, h * 0.35, 0.5), CFrame = CFrame.new(-w * 0.22, h * 0.72, 2.6), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.35 }) -- shine
		face(m, w * 0.08, h * 0.45, 3, h * 1.3)
	else
		for i = -1, 1, 2 do
			local s = rng:NextNumber(2.2, 3.4)
			local cc = SLIME_COLOURS[rng:NextInteger(1, #SLIME_COLOURS)]
			local body = prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.2, s, s), CFrame = CFrame.new(i * 3.5, s * 0.42, 0), Color = Color3.fromRGB(cc[1], cc[2], cc[3]), Material = Enum.Material.Glass, Transparency = 0.1 })
			prop(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.3, s * 0.2, 0.2), CFrame = CFrame.new(i * 3.5 - s * 0.25, s * 0.72, s * 0.42), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.3 })
			face(m, i * 3.5 + s * 0.05, s * 0.5, s * 0.5, s)
			if i == 1 then
				fx(body, "Wave", { Base = 0.1, Amp = 0.08, Speed = 2 })
			end
		end
	end
end

-- Arcane Archive: floating rune stones and open books
STYLES.Arcane = function(m, theme, rng, far, fx)
	local rune = color(theme.Accent)
	local stone = Color3.fromRGB(70, 74, 100):Lerp(color(theme.Sky), if far then 0.3 else 0)
	local h = if far then rng:NextNumber(7, 10) else rng:NextNumber(3.5, 5)
	local y = if far then rng:NextNumber(2, 6) else rng:NextNumber(1, 3)
	prop(m, { Size = Vector3.new(h * 0.45, h, 1.2), CFrame = CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Color = stone, Material = Enum.Material.Slate })
	for i = 1, 3 do
		local band = prop(m, { Size = Vector3.new(h * 0.3, 0.25, 0.2), CFrame = CFrame.new(0, y + h * (0.25 + i * 0.18), 0.65), Color = rune, Material = Enum.Material.Neon })
		if i == 2 then
			fx(band, "Wave", { Base = 0.05, Amp = 0.45, Speed = 1.5 })
		end
	end
	if not far then
		-- an open book floating beside it
		for side = -1, 1, 2 do
			prop(m, { Size = Vector3.new(1.1, 0.1, 1.4), CFrame = CFrame.new(3 + side * 0.5, y + h * 0.8, 0.5) * CFrame.Angles(0, 0, math.rad(side * 18)), Color = Color3.fromRGB(240, 230, 205) })
		end
		glow(m.PrimaryPart, rune, 9)
	end
end

function Backdrops.Build(parent, theme, rng, far, fx)
	local m = newModel(parent)
	local style = STYLES[theme.Backdrop or "Hills"] or STYLES.Hills
	style(m, theme, rng, far, fx or function() end)
	return m
end

Backdrops.Styles = STYLES -- (for tests: every zone's Backdrop must exist)

return Backdrops
