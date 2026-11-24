--[[
	MainMenu (ModuleScript): the first screen. Nobody spawns until they press Play on a character.
	  local menu = MainMenu.new(root, call, extra, CharacterScreen)
	  menu:Show(state) / menu:Hide() / menu:Render(state)   menu.Visible

	A character is just a class (see Shared/Characters). Up to state.Player.Character.MaxCharacters cards: a filled card
	(class, level, stage, Play) or an empty one that opens the class picker.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local MenuBattle = require(script.Parent.Parent.Battle.MenuBattle)
local Branding = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Branding)
local C = Kit.Colors

local GOOD = Color3.fromRGB(130, 235, 150)
local BAD = Color3.fromRGB(255, 130, 120)

local MainMenu = {}
MainMenu.__index = MainMenu

local REASONS = {
	Full = "You already have the maximum number of characters.",
	BadClass = "Pick a class you can play.",
	LeavePartyFirst = "Leave your party before switching characters.",
	BadSlot = "That character no longer exists.",
}

-- The animated backdrop: a dusk sky, twinkling stars, a moon, drifting clouds, three layers of mountains and fireflies.
-- Positions are fractions of the screen so it fits any shape; everything moves in update().
local function rnd(a, b)
	return a + math.random() * (b - a)
end

local function buildBackground(parent)
	local bg = { Stars = {}, Clouds = {}, Layers = {}, Flies = {} }
	local holder = Kit.frame({ Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), NoCorner = true, ClipsDescendants = true, ZIndex = 1, Parent = parent })
	Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 12, 40)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(70, 44, 110)),
		ColorSequenceKeypoint.new(0.85, Color3.fromRGB(214, 96, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 170, 100)),
	}), Parent = holder })
	bg.Holder = holder

	for _ = 1, 70 do
		local size = rnd(1.5, 3.2)
		local star = Kit.frame({ Size = UDim2.fromOffset(size, size), Position = UDim2.fromScale(math.random(), rnd(0, 0.6)), BackgroundColor3 = Color3.fromRGB(255, 248, 225), NoCorner = true, ZIndex = 2, Parent = holder })
		table.insert(bg.Stars, { Frame = star, Phase = rnd(0, 6.3), Speed = rnd(0.8, 2.4) })
	end

	-- the moon with a soft halo
	local halo = Kit.frame({ Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.78, -75, 0.14, -75), BackgroundColor3 = Color3.fromRGB(255, 232, 190), BackgroundTransparency = 0.88, ZIndex = 2, Parent = holder })
	Kit.corner(75).Parent = halo
	local moon = Kit.frame({ Size = UDim2.fromOffset(76, 76), Position = UDim2.new(0.78, -38, 0.14, -38), BackgroundColor3 = Color3.fromRGB(255, 244, 214), ZIndex = 3, Parent = holder })
	Kit.corner(38).Parent = moon
	bg.Halo = halo

	for i = 1, 6 do
		local w = rnd(160, 320)
		local cloud = Kit.frame({ Size = UDim2.fromOffset(w, rnd(26, 44)), Position = UDim2.fromScale(math.random(), rnd(0.08, 0.5)), BackgroundColor3 = Color3.fromRGB(150, 120, 190), BackgroundTransparency = rnd(0.55, 0.8), ZIndex = 3, Parent = holder })
		Kit.corner(22).Parent = cloud
		table.insert(bg.Clouds, { Frame = cloud, X = math.random(), Speed = rnd(0.004, 0.012), Width = w })
	end

	-- mountains: rotated squares cut off at the ground line, three layers drifting at different speeds (parallax)
	local view = parent.AbsoluteSize
	local H = math.max(view.Y, 300)
	local LAYERS = {
		{ Color = Color3.fromRGB(72, 52, 120), Base = 0.82, Size = 0.34, Speed = 6, Gap = 1.5 },
		{ Color = Color3.fromRGB(44, 34, 84), Base = 0.9, Size = 0.3, Speed = 14, Gap = 1.35 },
		{ Color = Color3.fromRGB(22, 18, 48), Base = 1.0, Size = 0.26, Speed = 28, Gap = 1.2 },
	}
	for _, spec in ipairs(LAYERS) do
		local base = Kit.frame({ Size = UDim2.fromScale(1, 1 - spec.Base + 0.002), Position = UDim2.fromScale(0, spec.Base), BackgroundColor3 = spec.Color, NoCorner = true, ZIndex = 4, Parent = holder })
		local clip = Kit.frame({ Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, spec.Base - 0.5), BackgroundTransparency = 1, NoCorner = true, ClipsDescendants = true, ZIndex = 4, Parent = holder })
		local peaks, total = {}, 0
		local span = math.max(view.X, 600) * 1.4 + 400
		while total < span do
			local size = H * spec.Size * rnd(0.7, 1.25)
			local peak = Kit.frame({ Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = spec.Color, NoCorner = true, ZIndex = 4, Parent = clip })
			table.insert(peaks, { Frame = peak, X = total, Size = size })
			total += size * spec.Gap * 0.7
		end
		table.insert(bg.Layers, { Peaks = peaks, Span = total, Speed = spec.Speed, Clip = clip })
	end

	for _ = 1, 26 do
		local size = rnd(3, 6)
		local fly = Kit.frame({ Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(255, 226, 130), ZIndex = 6, Parent = holder })
		Kit.corner(size).Parent = fly
		table.insert(bg.Flies, { Frame = fly, X = math.random(), Y = rnd(0.55, 1), Sway = rnd(0, 6.3), Rise = rnd(0.01, 0.04), Speed = rnd(0.6, 1.6) })
	end
	-- the DUO: two adventurers (one warm, one cool, like the logo) standing on the near ridge, each with a light beam and motes
	bg.Heroes = {}
	local dark = Color3.fromRGB(8, 6, 20)
	local function piece(parent, x, y, w, h, color, round, rot)
		local f = Kit.frame({ Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), BackgroundColor3 = color, NoCorner = true, Rotation = rot or 0, ZIndex = 7, Parent = parent })
		if round then
			Kit.corner(round).Parent = f
		end
		return f
	end
	for index, spec in ipairs({
		{ X = 0.13, Glow = Color3.fromRGB(255, 150, 70), Rim = Color3.fromRGB(255, 190, 110), Weapon = "Sword" },
		{ X = 0.87, Glow = Color3.fromRGB(80, 190, 245), Rim = Color3.fromRGB(140, 225, 255), Weapon = "Staff" },
	}) do
		local h = H * 0.3
		local w = h * 0.62
		local beam = Kit.frame({ Size = UDim2.fromOffset(w * 0.9, H * 0.95), Position = UDim2.new(spec.X, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = spec.Glow, BackgroundTransparency = 0.8, NoCorner = true, ZIndex = 5, Parent = holder })
		Kit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 0.15) }), Parent = beam })
		local aura = Kit.frame({ Size = UDim2.fromOffset(h * 1.5, h * 1.5), Position = UDim2.new(spec.X, 0, 1, -h * 0.45), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = spec.Glow, BackgroundTransparency = 0.82, ZIndex = 5, Parent = holder })
		Kit.corner(h).Parent = aura
		local body = Kit.frame({ Size = UDim2.fromOffset(w, h), Position = UDim2.new(spec.X, 0, 1, 4), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, NoCorner = true, ZIndex = 7, Parent = holder })
		local rimmed = {}
		local function add(f)
			Kit.new("UIStroke", { Color = spec.Rim, Thickness = 1.5, Transparency = 0.35, Parent = f })
			table.insert(rimmed, f)
			return f
		end
		local facing = if index == 1 then 1 else -1
		add(piece(body, w * 0.30, h * 0.62, w * 0.16, h * 0.38, dark)) -- legs
		add(piece(body, w * 0.54, h * 0.62, w * 0.16, h * 0.38, dark))
		add(piece(body, w * 0.22, h * 0.30, w * 0.56, h * 0.36, dark, 6)) -- torso
		add(piece(body, w * 0.34, h * 0.07, w * 0.32, h * 0.22, dark, 99)) -- head
		-- cape blowing back
		add(piece(body, if index == 1 then w * 0.02 else w * 0.62, h * 0.34, w * 0.34, h * 0.5, dark, 4, if index == 1 then 8 else -8))
		if spec.Weapon == "Sword" then
			add(piece(body, if facing == 1 then w * 0.8 else w * 0.0, h * 0.0, w * 0.07, h * 0.62, dark, 3, 18 * facing)) -- raised sword
		else
			add(piece(body, if facing == 1 then w * 0.8 else w * 0.0, h * 0.0, w * 0.06, h * 0.9, dark, 3, 10 * facing)) -- staff
			add(piece(body, if facing == 1 then w * 0.74 else w * -0.07, -h * 0.04, w * 0.2, w * 0.2, spec.Glow, 99)) -- glowing orb
		end
		table.insert(bg.Heroes, { Body = body, Aura = aura, Beam = beam, BaseY = 4, Phase = index * 1.7 })
		for _ = 1, 12 do
			local size = rnd(2.5, 5)
			local mote = Kit.frame({ Size = UDim2.fromOffset(size, size), BackgroundColor3 = spec.Glow, ZIndex = 8, Parent = holder })
			Kit.corner(size).Parent = mote
			table.insert(bg.Flies, { Frame = mote, X = spec.X + rnd(-0.04, 0.04), Y = rnd(0.5, 1), Sway = rnd(0, 6.3), Rise = rnd(0.05, 0.12), Speed = rnd(0.8, 1.8), Home = spec.X })
		end
	end
	-- everything except the fireflies is the painted scenery; the live 3D battle replaces it when it is running
	local flyFrames = {}
	for _, f in ipairs(bg.Flies) do
		flyFrames[f.Frame] = true
		if f.Home then
			f.Frame.Visible = true
		end
	end
	bg.Scenic = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("GuiObject") and not flyFrames[child] then
			table.insert(bg.Scenic, child)
		end
	end
	bg.FlyFrames = flyFrames
	-- a dusk vignette that sits over the 3D world (title area dark, bottom clear)
	local vignette = Kit.frame({ Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 10, 40), NoCorner = true, Visible = false, ZIndex = 5, Parent = holder })
	Kit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.45, 0.62), NumberSequenceKeypoint.new(1, 0.45) }), Parent = vignette })
	bg.Vignette = vignette
	return bg
end

-- on = the live 3D battle is showing behind the menu: hide the painted scenery and show the vignette
local function setWorldMode(bg, on)
	bg.Holder.BackgroundTransparency = if on then 1 else 0
	if bg.Holder.Parent and bg.Holder.Parent:IsA("GuiObject") then
		bg.Holder.Parent.BackgroundTransparency = if on then 1 else 0 -- the menu frame itself must let the 3D world through
	end
	for _, frame in ipairs(bg.Scenic) do
		frame.Visible = not on
	end
	for _, f in ipairs(bg.Flies) do
		if f.Home then
			f.Frame.Visible = not on
		end
	end
	bg.Vignette.Visible = on
end

local function updateBackground(bg, t, dt, view)
	for _, s in ipairs(bg.Stars) do
		s.Frame.BackgroundTransparency = 0.15 + (math.sin(t * s.Speed + s.Phase) * 0.5 + 0.5) * 0.7
	end
	bg.Halo.BackgroundTransparency = 0.86 + math.sin(t * 0.6) * 0.04
	for _, c in ipairs(bg.Clouds) do
		c.X -= c.Speed * dt
		if c.X < -c.Width / view.X then
			c.X = 1.05
		end
		c.Frame.Position = UDim2.new(c.X, 0, c.Frame.Position.Y.Scale, 0)
	end
	for _, layer in ipairs(bg.Layers) do
		for _, p in ipairs(layer.Peaks) do
			p.X -= layer.Speed * dt
			if p.X < -p.Size then
				p.X += layer.Span
			end
			p.Frame.Position = UDim2.new(0, p.X, 1, 0)
		end
	end
	for _, hero in ipairs(bg.Heroes) do
		hero.Body.Position = UDim2.new(hero.Body.Position.X.Scale, 0, 1, hero.BaseY + math.sin(t * 1.4 + hero.Phase) * 2)
		hero.Aura.BackgroundTransparency = 0.8 + math.sin(t * 1.1 + hero.Phase) * 0.05
		hero.Beam.BackgroundTransparency = 0.78 + math.sin(t * 0.8 + hero.Phase) * 0.05
	end
	for _, f in ipairs(bg.Flies) do
		f.Y -= f.Rise * dt
		if f.Y < (if f.Home then 0.3 else 0.5) then
			f.Y = 1.02
			f.X = if f.Home then f.Home + rnd(-0.04, 0.04) else math.random()
		end
		f.Frame.Position = UDim2.new(f.X + math.sin(t * f.Speed + f.Sway) * 0.02, 0, f.Y, 0)
		f.Frame.BackgroundTransparency = 0.2 + (math.sin(t * 3 * f.Speed + f.Sway) * 0.5 + 0.5) * 0.6
	end
end

function MainMenu.new(root, call, extra, CharacterScreen)
	local self = setmetatable({ Visible = false, Creating = false, Message = nil }, MainMenu)
	self.Call, self.Extra, self.CharacterScreen = call, extra, CharacterScreen
	self.Root = root
	-- its own ScreenGui that ignores the top bar inset, so the backdrop really covers the whole screen
	local gui = Kit.new("ScreenGui", { Name = "DuoQuestMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	self.Gui = gui
	self.Frame = Kit.frame({ Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 28), NoCorner = true, Active = true, ZIndex = 1, Parent = gui })
	self.Bg = buildBackground(self.Frame)
	local scale = Kit.new("UIScale", {})
	self.Body = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, ZIndex = 10, Parent = self.Frame })
	scale.Parent = self.Body
	local function fit()
		local view = gui.AbsoluteSize
		local s = math.clamp(math.min(view.X / 800, view.Y / 470), 0.5, 2)
		scale.Scale = s
		self.Body.Size = UDim2.fromOffset(view.X / s, view.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		if not self.Visible then
			return
		end
		updateBackground(self.Bg, now, dt, gui.AbsoluteSize)
		-- the title floats and its gold / blue shine sweeps across
		if self.TitleHolder and self.TitleHolder.Parent then
			self.TitleHolder.Position = UDim2.fromOffset(0, math.sin(now * 1.6) * 3)
			local sweep = (now * 0.35) % 2 - 0.5
			for _, g in ipairs(self.TitleGradients or {}) do
				g.Offset = Vector2.new(sweep * 1.6 - 0.8, 0)
			end
		end
	end)
	extra.PlaySlot = function(slot)
		return self:Play(slot)
	end
	return self
end

function MainMenu:Show(state)
	self.Visible = true
	self.Creating = false
	self.Gui.Enabled = true
	local hud = self.Root and (if self.Root:IsA("ScreenGui") then self.Root else self.Root:FindFirstAncestorOfClass("ScreenGui"))
	if hud and hud ~= self.Gui then
		self.HudGui = hud
		hud.Enabled = false -- the game UI stays out of sight while the menu (and its 3D battle) is up
	end
	-- a live (fake) auto battle plays behind the menu; the painted backdrop is the fallback if it cannot start
	local ok, started = pcall(MenuBattle.Start)
	self.World3D = ok and started == true
	setWorldMode(self.Bg, self.World3D)
	self:Render(state)
end

function MainMenu:Hide()
	self.Visible = false
	self.Gui.Enabled = false
	if self.HudGui then
		self.HudGui.Enabled = true
	end
	self.Extra.MenuCreate = false
	pcall(MenuBattle.Stop)
end

function MainMenu:Play(slot)
	local ok, reason = self.Call("PlayCharacter", slot)
	if ok then
		self:Hide()
		return true
	end
	self.Message = REASONS[reason] or "Could not play that character."
	self:Render(self.Extra.State)
	return false, reason
end

local STAGE_W, STAGE_H = 700, 376

local function divider(parent, y, z)
	Kit.frame({ Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, y), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.75, NoCorner = true, ZIndex = z, Parent = parent })
end

-- one "Label ........ value" row inside a card
local function statRow(parent, y, label, value, z)
	Kit.label({ Size = UDim2.new(0.5, -14, 0, 18), Position = UDim2.fromOffset(14, y), Text = label, TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z, Parent = parent })
	Kit.label({ Size = UDim2.new(0.5, -14, 0, 18), Position = UDim2.new(0.5, 0, 0, y), Text = value, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = z, Parent = parent })
end

function MainMenu:Render(state)
	if not self.Visible or not state then
		return
	end
	Kit.clear(self.Body)
	local char = state.Player.Character
	-- everything sits in one centered stage so the spacing is the same on any screen shape
	local stage = Kit.frame({ Name = "Stage", Size = UDim2.fromOffset(STAGE_W, STAGE_H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = self.Body })

	if self.Creating then
		self.Extra.MenuCreate = true
		Kit.button({ Size = UDim2.fromOffset(90, 30), Position = UDim2.fromOffset(30, 0), Text = "< Back", TextSize = 13, ZIndex = 63, Parent = stage }, function()
			self.Creating = false
			self.Extra.MenuCreate = false
			self.Extra.CharMsg = nil
			self:Render(self.Extra.State)
		end)
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "NEW CHARACTER", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })
		local holder = Kit.frame({ Size = UDim2.fromOffset(640, 340), Position = UDim2.new(0.5, -320, 0, 38), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = stage })
		self.CharacterScreen.Character(holder, state, self.Call, self.Extra)
		return
	end
	self.Extra.MenuCreate = false

	-- title block: IDLE PARTY (gold) and QUEST (blue) with crossed swords between, a drop shadow, a stroke and a moving shine
	local holder = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = stage })
	self.TitleHolder = holder
	self.TitleGradients = {}
	if Branding.LogoImage ~= "" then
		Kit.new("ImageLabel", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, -32, 0, 17), BackgroundTransparency = 1, Image = Branding.LogoImage, ScaleType = Enum.ScaleType.Fit, ZIndex = 63, Parent = holder })
	else
		Kit.label({ Size = UDim2.fromOffset(50, 54), Position = UDim2.new(0.5, -25, 0, 22), Text = "⚔", TextSize = 34, TextYAlignment = Enum.TextYAlignment.Center, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 232, 150), TextWrapped = false, ZIndex = 64, Parent = holder })
	end
	local function word(text, anchorRight, warm)
		local function make(color, dx, dy, z, stroke)
			local l = Kit.label({
				Size = UDim2.fromOffset(320, 54), AnchorPoint = Vector2.new(if anchorRight then 1 else 0, 0), Position = UDim2.new(0.5, (if anchorRight then -30 else 30) + dx, 0, 22 + dy),
				Text = text, TextSize = 42, Font = Enum.Font.GothamBlack, TextColor3 = color, TextXAlignment = if anchorRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
				TextWrapped = false, TextStrokeTransparency = 1, ZIndex = z, Parent = holder,
			})
			if stroke then
				Kit.new("UIStroke", { Color = Color3.fromRGB(12, 8, 30), Thickness = 4, Parent = l })
			end
			return l
		end
		make(Color3.fromRGB(8, 6, 20), 3, 5, 62, false).TextTransparency = 0.45 -- shadow
		local face = make(Color3.new(1, 1, 1), 0, 0, 63, true)
		local gradient = Kit.new("UIGradient", {
			Rotation = 90, Color = ColorSequence.new(
				if warm then { ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 170)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 176, 60)), ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 86, 44)) }
				else { ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 255, 245)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 235)), ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 110, 226)) }),
			Parent = face,
		})
		table.insert(self.TitleGradients, gradient)
	end
	word("IDLE PARTY", true, true)
	word("QUEST", false, false)
	Kit.label({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 80), Text = "SELECT A CHARACTER", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 205, 245), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })

	local max = char and char.MaxCharacters or 2
	local list = char and char.Characters or {}
	local classes = {}
	for _, class in ipairs(char and char.Classes or {}) do
		classes[class.Id] = class
	end
	local cardW, cardH, gap, top = 290, 236, 28, 108
	local total = max * cardW + (max - 1) * gap
	local inGame = char and char.InGame
	for index = 1, max do
		local x = (STAGE_W - total) / 2 + (index - 1) * (cardW + gap)
		local entry = list[index]
		local card = Kit.frame({ Name = "Slot" .. index, Size = UDim2.fromOffset(cardW, cardH), Position = UDim2.fromOffset(x, top), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.12, ZIndex = 62, Parent = stage })
		if entry then
			local class = classes[entry.ClassId] or { Name = entry.ClassId }
			local color = C[entry.ClassId] or C.Accent
			local playing = entry.Active and inGame
			Kit.new("UIStroke", { Color = color, Thickness = 2, Parent = card })
			Kit.frame({ Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = color, NoCorner = true, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 22), Text = class.Name, TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 63, Parent = card })
			if playing then
				Kit.label({ Size = UDim2.fromOffset(80, 16), Position = UDim2.new(1, -94, 0, 22), Text = "PLAYING", TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = GOOD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 63, Parent = card })
			end
			divider(card, 66, 63)
			local path
			for _, p in ipairs(class.Paths or {}) do
				if p.Id == entry.SubclassId then
					path = p.Name
				end
			end
			statRow(card, 90, "Level", tostring(entry.Level), 63)
			statRow(card, 114, "Furthest stage", tostring(entry.HighestStage), 63)
			statRow(card, 138, "Path", path or "At level 30", 63)
			Kit.button({
				Name = "Play" .. index, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 1, -54), Text = if playing then "CONTINUE" else "PLAY",
				BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), TextSize = 16, ZIndex = 63, Parent = card,
			}, function()
				if playing then
					self:Hide()
				else
					self:Play(entry.Slot)
				end
			end)
		else
			Kit.new("UIStroke", { Color = C.Dim, Thickness = 1.5, Transparency = 0.6, Parent = card })
			card.BackgroundTransparency = 0.4
			Kit.label({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 38), Text = "+", TextSize = 54, Font = Enum.Font.GothamBlack, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 104), Text = "Empty slot", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(20, 126), Text = "A character is just a class.\nPick one to begin.", TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.button({
				Name = "Create" .. index, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 1, -54), Text = "CREATE CHARACTER", TextSize = 14, ZIndex = 63, Parent = card,
			}, function()
				self.Creating = true
				self.Message = nil
				self.Extra.PickClass = nil
				self.Extra.CharMsg = nil
				self:Render(self.Extra.State)
			end)
		end
	end

	-- footer
	local foot = if self.Message then self.Message else ("Up to %d characters per account. Each keeps its own progress."):format(max)
	Kit.label({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, top + cardH + 14), Text = foot, TextSize = 12, TextColor3 = if self.Message then BAD else C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })
end

return MainMenu
