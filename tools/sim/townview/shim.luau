-- Minimal Roblox stand-ins so client/Battle/Hub.luau and Town.luau can build headless; dumps every part.
-- Used by tools/sim/townview/render.py (a top-down picture of the plaza and town).

local V = {}
V.__index = V
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) if m == 0 then return vec() end return vec(t.X / m, t.Y / m, t.Z / m) end
	return V[k]
end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Cross(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = vec, zero = vec(), one = vec(1, 1, 1), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1) }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }

-- CFrame: rotation columns (right r, up u, back b) + position p
local CF = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r or vec(1, 0, 0), u = u or vec(0, 1, 0), b = b or vec(0, 0, 1) }, CF)
end
local function rot(c, v) return c.r * v.X + c.u * v.Y + c.b * v.Z end
CF.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "X" then return t.p.X end
	if k == "Y" then return t.p.Y end
	if k == "Z" then return t.p.Z end
	if k == "Rotation" then return cf(vec(), t.r, t.u, t.b) end
	if k == "LookVector" then return -t.b end
	if k == "RightVector" then return t.r end
	if k == "UpVector" then return t.u end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V then return a.p + rot(a, b) end
	return cf(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
end
CF.__add = function(a, v) return cf(a.p + v, a.r, a.u, a.b) end
CF.__sub = function(a, v) return cf(a.p - v, a.r, a.u, a.b) end
function CF.Inverse(c)
	-- transpose the rotation
	local r = vec(c.r.X, c.u.X, c.b.X)
	local u = vec(c.r.Y, c.u.Y, c.b.Y)
	local b = vec(c.r.Z, c.u.Z, c.b.Z)
	local inv = cf(vec(), r, u, b)
	return cf(-(rot(inv, c.p)), r, u, b)
end
function CF.ToWorldSpace(a, b) return a * b end
local function rx(a) return cf(vec(), vec(1, 0, 0), vec(0, math.cos(a), math.sin(a)), vec(0, -math.sin(a), math.cos(a))) end
local function ry(a) return cf(vec(), vec(math.cos(a), 0, -math.sin(a)), vec(0, 1, 0), vec(math.sin(a), 0, math.cos(a))) end
local function rz(a) return cf(vec(), vec(math.cos(a), math.sin(a), 0), vec(-math.sin(a), math.cos(a), 0), vec(0, 0, 1)) end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then return cf(x) end
		return cf(vec(x or 0, y or 0, z or 0))
	end,
	Angles = function(a, b, c) return rx(a) * ry(b) * rz(c) end,
	fromEulerAnglesXYZ = function(a, b, c) return rx(a) * ry(b) * rz(c) end,
	lookAt = function(at, target)
		local look = (target - at).Unit
		local right = look:Cross(vec(0, 1, 0)).Unit
		if right.Magnitude < 0.5 then right = vec(1, 0, 0) end
		local up = right:Cross(look)
		return cf(at, right, up, -look)
	end,
}

Color3 = {}
local C3 = {}
C3.__index = C3
function C3.Lerp(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3) end
Color3.new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end }
UDim = { new = function() return {} end }
ColorSequence = { new = function() return {} end }
ColorSequenceKeypoint = { new = function() return {} end }
NumberSequence = { new = function() return {} end }
NumberSequenceKeypoint = { new = function() return {} end }
NumberRange = { new = function() return {} end }
TweenInfo = { new = function() return {} end }

local function enumOf(path)
	return setmetatable({ __path = path }, { __index = function(t, k) return enumOf(path .. "." .. k) end, __tostring = function() return path end })
end
Enum = enumOf("Enum")

-- instances
local all = {}
local Inst = {}
local EVENTS = { Triggered = true, MouseClick = true, Changed = true, Activated = true }
local function isPart(c) return c == "Part" or c == "WedgePart" or c == "MeshPart" or c == "TrussPart" or c == "SpawnLocation" end
local function new(class)
	local data = { ClassName = class, Name = class, Children = {}, Transparency = 0 }
	if isPart(class) then
		data.CFrame = cf(vec())
		data.Size = vec(4, 1, 2)
	end
	local obj = setmetatable({}, Inst)
	rawset(obj, "__d", data)
	table.insert(all, obj)
	return obj
end
Inst.__index = function(t, k)
	local d = rawget(t, "__d")
	if k == "Position" and d.CFrame and isPart(d.ClassName) then return d.CFrame.p end
	if d[k] ~= nil then return d[k] end
	if EVENTS[k] then return { Connect = function() return { Disconnect = function() end } end } end
	if Inst[k] then return Inst[k] end
	for _, c in ipairs(d.Children) do
		if c.Name == k then return c end
	end
	return nil
end
Inst.__newindex = function(t, k, v)
	local d = rawget(t, "__d")
	if k == "Parent" then
		if d.Parent then
			local list = rawget(d.Parent, "__d").Children
			for i, c in ipairs(list) do if c == t then table.remove(list, i) break end end
		end
		d.Parent = v
		if v then table.insert(rawget(v, "__d").Children, t) end
		return
	end
	if k == "Position" and isPart(d.ClassName) then
		local old = d.CFrame or cf(vec())
		d.CFrame = cf(v, old.r, old.u, old.b)
		return
	end
	d[k] = v
end
function Inst.GetChildren(t) return table.clone(rawget(t, "__d").Children) end
function Inst.GetDescendants(t)
	local out = {}
	local function walk(o)
		for _, c in ipairs(rawget(o, "__d").Children) do table.insert(out, c) walk(c) end
	end
	walk(t)
	return out
end
function Inst.FindFirstChild(t, name)
	for _, c in ipairs(rawget(t, "__d").Children) do if c.Name == name then return c end end
	return nil
end
function Inst.FindFirstChildWhichIsA(t, class)
	for _, c in ipairs(rawget(t, "__d").Children) do if c:IsA(class) then return c end end
	return nil
end
function Inst.FindFirstChildOfClass(t, class) return Inst.FindFirstChildWhichIsA(t, class) end
function Inst.WaitForChild(t, name) return Inst.FindFirstChild(t, name) end
function Inst.IsA(t, class)
	local c = rawget(t, "__d").ClassName
	if class == "BasePart" then return isPart(c) end
	return c == class
end
function Inst.Destroy(t) t.Parent = nil rawget(t, "__d").Destroyed = true end
function Inst.SetAttribute(t, k, v) local d = rawget(t, "__d") d.Attrs = d.Attrs or {} d.Attrs[k] = v end
function Inst.GetAttribute(t, k) local a = rawget(t, "__d").Attrs return a and a[k] end
function Inst.ClearAllChildren(t) for _, c in ipairs(t:GetChildren()) do c:Destroy() end end
function Inst.GetPivot(t)
	local d = rawget(t, "__d")
	if d.CFrame then return d.CFrame end
	if d.PrimaryPart then return d.PrimaryPart.CFrame end
	return cf(vec())
end
function Inst.PivotTo(t, target)
	local d = rawget(t, "__d")
	if d.CFrame then d.CFrame = target return end
	local pivot = Inst.GetPivot(t)
	local delta = target * pivot:Inverse()
	for _, p in ipairs(t:GetDescendants()) do
		local pd = rawget(p, "__d")
		if pd.CFrame then pd.CFrame = delta * pd.CFrame end
	end
end
Instance = { new = function(class, parent) local o = new(class) if parent then o.Parent = parent end return o end }

-- services and modules
local root = new("DataModel")
local workspaceObj = new("Workspace")
workspace = workspaceObj
rawget(workspaceObj, "__d").CurrentCamera = { CFrame = cf(vec()), CameraType = Enum.CameraType.Custom }
local function marker(name)
	return setmetatable({ __mod = name }, { __index = function(t, k)
		if k == "WaitForChild" or k == "FindFirstChild" then return function(_, n) return marker(n) end end
		if k == "Parent" then return marker("Parent") end
		return marker(k)
	end })
end
local services = {}
game = {
	GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = { Character = nil, GetAttribute = function() return nil end } } end
		if name == "RunService" then return { Heartbeat = { Connect = function() end }, IsStudio = function() return true end } end
		services[name] = services[name] or marker(name)
		return services[name]
	end,
}
task = { spawn = function(f, ...) f(...) end, delay = function() end, wait = function() end }
tick = os.clock

MODULES = {}
LOADERS = {}
function require(m)
	local name = type(m) == "table" and m.__mod or m
	if MODULES[name] == nil then
		assert(LOADERS[name], "no module " .. tostring(name))
		MODULES[name] = LOADERS[name]()
	end
	return MODULES[name]
end
script = marker("script")

function DUMP()
	local function fmt(n) return string.format("%.3f", n) end
	for _, o in ipairs(all) do
		local d = rawget(o, "__d")
		if d.CFrame and d.Size and isPart(d.ClassName) and not d.Destroyed and d.Parent then
			local c = d.CFrame
			local text = ""
			for _, g in ipairs(d.Children) do
				local gd = rawget(g, "__d")
				if gd.ClassName == "SurfaceGui" or gd.ClassName == "BillboardGui" then
					for _, l in ipairs(gd.Children) do
						local ld = rawget(l, "__d")
						if ld.Text then text = text .. (gd.ClassName == "SurfaceGui" and ("S:" .. tostring(gd.Face) .. ":") or "B:") .. ld.Text:gsub("[\t\n|]", " ") .. "|" end
					end
				end
			end
			local shape = d.Shape and tostring(d.Shape) or ""
			local col = d.Color or Color3.new(0.5, 0.5, 0.5)
			print(table.concat({ "P", d.ClassName, d.Name, shape,
				fmt(c.p.X), fmt(c.p.Y), fmt(c.p.Z),
				fmt(c.r.X), fmt(c.r.Y), fmt(c.r.Z), fmt(c.u.X), fmt(c.u.Y), fmt(c.u.Z), fmt(c.b.X), fmt(c.b.Y), fmt(c.b.Z),
				fmt(d.Size.X), fmt(d.Size.Y), fmt(d.Size.Z),
				fmt(col.R), fmt(col.G), fmt(col.B), fmt(d.Transparency or 0), text }, "\t"))
		end
	end
end
