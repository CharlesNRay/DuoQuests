--[[
	Hud (ModuleScript): the always-visible overlay, drawn at SCALE of the panels so it stays out of the
	way. It keeps clear of what Roblox draws on top of every game: chat / menu top-left (we start below
	it on desktop), the touch thumbstick and jump button in the bottom corners, the system top bar.

	Two layers:
	  Chrome  (always)  top-left portrait + partner card; top-right the live MAP CARD with gold / shards just left of it
	                    (zone, stage, ten stage pips, Advance button while the party is holding) and
	                    the small buttons (Plaza, Home, Fight log, Battle view); bottom-centre menu dock
	                    (Hero Skills Pets Party Gear Bag; passives live in Skills, Ranks at the plaza board)
	  Combat  (only while watching a battle) stage pill, fight timer, toast, your skill bar and the
	                    party ultimate gauge. "Hide HUD" in the watching bar hides the map card and menu dock (party and currencies stay).

	Everything is plain Frames (no art assets).

	  hud:AddButton(key, group, glyph, label, onClick) -> button   group "dock" | "mini"
	  hud.OnMap / hud.OnAdvance       callbacks for the map card and its Advance button
	  hud:SetBadge(key, bool)         red dot on a button
	  hud:Render(state)               refresh from the server state
	  hud:OnFight(info)               own fight finished: toast, timer, ultimate gauge
	  hud:SetWatching(text, onStop)   enter/leave the watching view (shows/hides the Combat layer)
	  hud:SetHudHidden(bool)          hide/show Chrome while watching
	  hud:ShowBanner(text, color)     battle callout (only while the Combat layer is showing)
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Zones)
local Power = require(Shared.Power)
local Stages = require(Shared.Stages)
local Abilities = require(Shared.Config.Abilities)
local UltCfg = require(Shared.Config.Ultimates)
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local C = Kit.Colors

local Hud = {}
local short

local MAP_GLYPHS = {
	Trees = "🌳", Pines = "🌲", Rocks = "⛰️", Crystals = "💎", Cacti = "🌵",
	SnowPines = "❄️", LavaRocks = "🌋", DeadTrees = "🪦", Pillars = "🏛️", Clouds = "☁️",
}
local INTRO = 0.8 -- matches Battle/Replay: monsters run in before the first blow

-- 1234 -> "1,234" (tooltips) and 12500 -> "12.5K" (the compact HUD pills)
local function commas(n)
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
short = function(n)
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.2fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

local function pill(parent, props)
	local f = Kit.frame({ Size = props.Size, Position = props.Position, BackgroundColor3 = Color3.fromRGB(16, 18, 30), BackgroundTransparency = 0.25, Parent = parent })
	Kit.new("UIStroke", { Color = Color3.fromRGB(90, 98, 130), Thickness = 1, Transparency = 0.4, Parent = f })
	return f
end

local SCALE = if UserInputService.KeyboardEnabled then 0.8 else 0.9 -- the HUD is drawn a little smaller than panels

function Hud.new(root)
	local self = { Buttons = {}, Dots = {}, Charge = { Points = nil, StartedAt = 0, Needed = UltCfg.ChargeNeeded or 100, Rate = UltCfg.ChargePerSecond or 1.5 } }
	-- The HUD has its own scale. Its frame is 1/SCALE of the screen so that after scaling it fills it exactly.
	local gui = Kit.frame({ Name = "Hud", Size = UDim2.fromScale(1 / SCALE, 1 / SCALE), BackgroundTransparency = 1, NoCorner = true, Parent = root })
	Kit.new("UIScale", { Scale = SCALE, Parent = gui })
	self.Gui = gui

	-- Two layers: Chrome (menus, portrait, map) and Combat (stage pill, fight timer, skill bar).
	-- Combat only shows while you are watching a battle; Chrome can be hidden while spectating.
	local chrome = Kit.frame({ Name = "Chrome", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = gui })
	local combat = Kit.frame({ Name = "Combat", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Visible = false, Parent = gui })
	self.Chrome, self.Combat = chrome, combat

	-- top-left: portrait + partner -----------------------------------------
	local safeTop = if UserInputService.KeyboardEnabled then 12 else 14 -- just under Roblox's own menu + chat buttons
	local portrait = pill(chrome, { Size = UDim2.fromOffset(220, 46), Position = UDim2.fromOffset(8, safeTop) })
	self.Badge = Kit.frame({ Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.Accent, Parent = portrait })
	Kit.corner(19).Parent = self.Badge
	self.LevelLabel = Kit.label({ Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = C.Bg, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = self.Badge })
	self.NameLabel = Kit.label({ Size = UDim2.new(1, -54, 0, 18), Position = UDim2.fromOffset(48, 3), Text = "", TextSize = 15, Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = portrait })
	local xpBack = Kit.frame({ Size = UDim2.new(1, -130, 0, 8), Position = UDim2.fromOffset(48, 30), BackgroundColor3 = Color3.fromRGB(40, 44, 64), Parent = portrait })
	self.XpFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 180, 255), Parent = xpBack })
	Kit.Hover(portrait, function()
		return self.XpText
	end)
	self.IPLabel = Kit.label({ Size = UDim2.fromOffset(70, 14), Position = UDim2.new(1, -76, 1, -17), Text = "IP 0", TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 3, Parent = portrait })
	Kit.Hover(self.IPLabel, function() return self.IPTip end)
	self.Cards = Kit.frame({ Size = UDim2.fromOffset(220, 30), Position = UDim2.fromOffset(8, safeTop + 50), BackgroundTransparency = 1, NoCorner = true, Parent = chrome })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 3), Parent = self.Cards })

	-- top-right: the map card in the very corner, gold + shards directly to its left ----------
	local right = Kit.frame({ Size = UDim2.fromOffset(296, 10), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, NoCorner = true, Parent = chrome })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })
	local topRow = Kit.frame({ Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, NoCorner = true, Parent = right })
	local money = Kit.frame({ Size = UDim2.fromOffset(100, 108), BackgroundTransparency = 1, NoCorner = true, Parent = topRow })
	local goldPill = pill(money, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 0) })
	local shardPill = pill(money, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 28), Visible = false }) -- shards have no use for now, so the pill is hidden
	local stonePill = pill(money, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 28) })
	local sunPill = pill(money, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 56) })
	self.GoldPill, self.ShardPill, self.StonePill, self.SunPill = goldPill, shardPill, stonePill, sunPill
	-- the orange premium currency: tap the pill to open the Premium shop
	self.Suns = Kit.label({ Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 165, 70), TextWrapped = false, Parent = sunPill })
	self.Stones = Kit.label({ Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(110, 185, 255), TextWrapped = false, Parent = stonePill })
	self.Gold = Kit.label({ Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, TextWrapped = false, Parent = goldPill })
	self.Shards = Kit.label({ Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 170, 255), TextWrapped = false, Parent = shardPill })

	Kit.Hover(goldPill, function()
		return ("<b>Gold</b>\n%s"):format(commas(self.GoldExact or 0))
	end)
	Kit.Hover(stonePill, function()
		return ("<b>Wishstones</b>\n%s\nSpend them at the Wishing Tree on pet or skill wishes. Earned by playing: clearing stages, quests, the season pass and daily login."):format(commas(self.StoneExact or 0))
	end)
	Kit.Hover(sunPill, function()
		return ("<b>Sunstones</b>\n%s\nThe premium currency, bought with Robux. Spend it in the Premium shop on packs, passes and upgrades. It never buys wishes."):format(commas(self.SunExact or 0))
	end)
	Kit.Hover(shardPill, function()
		return ("<b>Shards</b>\n%s"):format(commas(self.ShardExact or 0))
	end)

	-- the map card: a small live picture of where the party is. Tap it for the full map.
	local mapCard = Kit.button({ Size = UDim2.fromOffset(190, 86), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Text = "", BackgroundColor3 = Color3.fromRGB(70, 110, 70), Parent = topRow }, function()
		if self.OnMap then
			self.OnMap()
		end
	end)
	Kit.new("UIStroke", { Color = Color3.fromRGB(240, 220, 160), Thickness = 2, Transparency = 0.2, Parent = mapCard })
	self.MapCard = mapCard
	self.MapShade = Kit.frame({ Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.45), BackgroundColor3 = Color3.fromRGB(12, 14, 24), BackgroundTransparency = 0.45, Parent = mapCard })
	self.MapGlyph = Kit.label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 4), Text = "", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = mapCard })
	self.MapZone = Kit.label({ Size = UDim2.new(1, -54, 0, 18), Position = UDim2.fromOffset(52, 5), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Color3.new(1, 1, 1), Parent = mapCard })
	self.MapStage = Kit.label({ Size = UDim2.new(1, -54, 0, 24), Position = UDim2.fromOffset(52, 22), Text = "", TextSize = 20, Font = Enum.Font.GothamBlack, TextWrapped = false, TextColor3 = Color3.new(1, 1, 1), Parent = mapCard })
	self.MapPips = Kit.frame({ Size = UDim2.new(1, -12, 0, 8), Position = UDim2.fromOffset(6, 54), BackgroundTransparency = 1, NoCorner = true, Parent = mapCard })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), Parent = self.MapPips })
	self.MapNote = Kit.label({ Size = UDim2.new(1, -90, 0, 16), Position = UDim2.fromOffset(6, 66), Text = "", TextSize = 11, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = C.Accent, Parent = mapCard })
	self.AdvanceButton = Kit.button({ Size = UDim2.fromOffset(78, 20), Position = UDim2.new(1, -82, 1, -23), Text = "Advance ▶", TextSize = 11, BackgroundColor3 = C.Up, Visible = false, ZIndex = 3, Parent = mapCard }, function()
		if self.OnAdvance then
			self.OnAdvance()
		end
	end)
	Kit.Hover(self.AdvanceButton, function()
		return "Try the next stage. You stay on this stage until you advance."
	end)
	Kit.Hover(mapCard, function()
		return "World map\n" .. Kit.tint("Click to open it", C.Dim)
	end)

	local mini = Kit.frame({ Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, NoCorner = true, Parent = right })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = mini })

	-- active boosts (XP Tonic ...) with a live countdown
	self.BuffRow = Kit.frame({ Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, NoCorner = true, Parent = right })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 3), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = self.BuffRow })
	self.BuffChips = {}
	-- while watching a fight the buffs live in the combat layer (above the skill bar), so hiding the HUD keeps them
	self.CombatBuffRow = Kit.frame({ Size = UDim2.fromOffset(300, 22), Position = UDim2.new(0.5, -150, 1, -158), BackgroundTransparency = 1, NoCorner = true, Parent = combat })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 3), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = self.CombatBuffRow })
	task.spawn(function()
		while gui.Parent do
			for _, chip in ipairs(self.BuffChips) do
				local left = math.max(0, math.floor(chip.EndsAt - os.clock()))
				chip.Frame.Visible = left > 0
				chip.Label.Text = ("%s %d:%02d"):format(chip.Glyph, left // 60, left % 60)
			end
			task.wait(1)
		end
	end)

	-- bottom-centre: the menu dock -----------------------------------------------
	local dock = Kit.frame({ Size = UDim2.fromOffset(10, 48), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, NoCorner = true, Parent = chrome })
	self.Dock = dock
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = dock })
	-- bottom-left: travel (Home and Plaza), kept apart from the menu buttons
	local travel = Kit.frame({ Size = UDim2.fromOffset(10, 34), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 10, 1, -10), AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, NoCorner = true, Parent = chrome })
	self.Travel = travel
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = travel })
	self.Rails = { dock = dock, mini = mini, travel = travel }
	self.NextOrder = 0

	-- combat layer: stage pill, fight timer, toast, skill bar + ultimate -------------
	-- the same card as the map corner, so a spectated battle shows where you are and lets you Advance
	local card = Kit.frame({ Size = UDim2.fromOffset(220, 86), Position = UDim2.new(0.5, -110, 0, 36), BackgroundColor3 = Color3.fromRGB(70, 110, 70), Parent = combat })
	Kit.new("UIStroke", { Color = Color3.fromRGB(240, 220, 160), Thickness = 2, Transparency = 0.2, Parent = card })
	self.CombatCard = card
	Kit.frame({ Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.45), BackgroundColor3 = Color3.fromRGB(12, 14, 24), BackgroundTransparency = 0.45, Parent = card })
	self.CGlyph = Kit.label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 4), Text = "", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = card })
	self.Zone = Kit.label({ Size = UDim2.new(1, -54, 0, 18), Position = UDim2.fromOffset(52, 5), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Color3.new(1, 1, 1), Parent = card })
	self.Stage = Kit.label({ Size = UDim2.new(1, -54, 0, 24), Position = UDim2.fromOffset(52, 22), Text = "Stage -", TextSize = 20, Font = Enum.Font.GothamBlack, TextWrapped = false, TextColor3 = Color3.new(1, 1, 1), Parent = card })
	self.CPips = Kit.frame({ Size = UDim2.new(1, -12, 0, 8), Position = UDim2.fromOffset(6, 54), BackgroundTransparency = 1, NoCorner = true, Parent = card })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), Parent = self.CPips })
	self.CNote = Kit.label({ Size = UDim2.new(1, -96, 0, 16), Position = UDim2.fromOffset(6, 66), Text = "", TextSize = 11, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = C.Accent, Parent = card })
	self.CAdvance = Kit.button({ Size = UDim2.fromOffset(84, 20), Position = UDim2.new(1, -88, 1, -23), Text = "Advance ▶", TextSize = 11, BackgroundColor3 = C.Up, Visible = false, ZIndex = 3, Parent = card }, function()
		if self.OnAdvance then
			self.OnAdvance()
		end
	end)
	Kit.Hover(self.CAdvance, function()
		return "Try the next stage. You stay on this stage until you advance."
	end)
	self.Fight = Kit.frame({ Size = UDim2.fromOffset(180, 5), Position = UDim2.new(0.5, -90, 0, 128), BackgroundColor3 = Color3.fromRGB(16, 18, 30), Parent = combat })
	self.FightFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = self.Fight })
	self.Toast = Kit.label({ Size = UDim2.new(0, 400, 0, 20), Position = UDim2.new(0.5, -200, 0, 135), Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Accent, Parent = combat })

	self.Bar = pill(combat, { Size = UDim2.fromOffset(340, 56), Position = UDim2.new(0.5, -170, 1, -128) })
	self.Slots = Kit.frame({ Size = UDim2.fromOffset(250, 48), Position = UDim2.fromOffset(8, 4), BackgroundTransparency = 1, NoCorner = true, Parent = self.Bar })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = self.Slots })
	self.UltSlot = Kit.frame({ Size = UDim2.fromOffset(66, 48), Position = UDim2.new(1, -74, 0, 4), BackgroundTransparency = 1, NoCorner = true, Parent = self.Bar })
	self.UltIcon = nil
	self.UltBack = Kit.frame({ Size = UDim2.fromOffset(52, 6), Position = UDim2.fromOffset(7, 41), BackgroundColor3 = Color3.fromRGB(40, 44, 64), Parent = self.UltSlot })
	self.UltFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Kit.Colors.Epic, Parent = self.UltBack })

	-- the "watching" bar (top-centre): stop + hide-the-rest-of-the-HUD ---------------
	self.Watching = pill(gui, { Size = UDim2.fromOffset(420, 32), Position = UDim2.new(0.5, -210, 0, 6) })
	self.Watching.Visible = false
	self.WatchText = Kit.label({ Size = UDim2.new(1, -280, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "", TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = self.Watching })
	self.LogButton = Kit.button({ Size = UDim2.fromOffset(76, 26), Position = UDim2.new(1, -270, 0, 3), Text = "📋 Log", TextSize = 12, Parent = self.Watching }, function()
		if self.OnLog then
			self.OnLog()
		end
	end)
	self.HideButton = Kit.button({ Size = UDim2.fromOffset(86, 26), Position = UDim2.new(1, -182, 0, 3), Text = "Hide HUD", TextSize = 12, Parent = self.Watching }, function()
		self:SetHudHidden(not self.HudHidden)
	end)
	self.StopButton = Kit.button({ Size = UDim2.fromOffset(86, 26), Position = UDim2.new(1, -92, 0, 3), Text = "Stop", TextSize = 12, BackgroundColor3 = C.Bad, Parent = self.Watching })

	-- banner ------------------------------------------------------------------
	self.BannerLabel = Kit.label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0.3, 0), Text = "", TextSize = 34, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
	function self:ShowBanner(text, color)
		if not self.Combat.Visible then
			return -- battle callouts belong to the combat view
		end
		self.BannerLabel.Text = text
		self.BannerLabel.TextColor3 = color
		self.BannerLabel.TextTransparency = 0
		TweenService:Create(self.BannerLabel, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
	end

	function self:AddButton(key, side, glyph, label, onClick)
		self.NextOrder += 1
		local small = side == "mini"
		if side == "travel" then
			local pill = Kit.button({ Size = UDim2.fromOffset(86, 34), Text = "", BackgroundColor3 = Color3.fromRGB(26, 30, 48), LayoutOrder = self.NextOrder, Parent = self.Rails.travel }, onClick)
			pill.BackgroundTransparency = 0.15
			Kit.new("UIStroke", { Color = Color3.fromRGB(110, 118, 150), Thickness = 1, Transparency = 0.5, Parent = pill })
			Kit.label({ Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), Text = glyph .. "  " .. label, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextStrokeTransparency = 1, Parent = pill })
			self.Buttons[key] = pill
			self.Dots[key] = Kit.frame({ Size = UDim2.fromOffset(1, 1), Visible = false, Parent = pill })
			return pill
		end
		local button = Kit.button({ Size = if small then UDim2.fromOffset(38, 38) else UDim2.fromOffset(50, 48), Text = "", BackgroundColor3 = Color3.fromRGB(26, 30, 48), LayoutOrder = self.NextOrder, Parent = self.Rails[side] }, onClick)
		button.BackgroundTransparency = 0.15
		Kit.new("UIStroke", { Color = Color3.fromRGB(110, 118, 150), Thickness = 1, Transparency = 0.5, Parent = button })
		if small then
			Kit.label({ Size = UDim2.fromScale(1, 1), Text = glyph, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = button })
			Kit.Hover(button, function() return label end)
		else
			Kit.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 3), Text = glyph, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = button })
			Kit.label({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 31), Text = label, TextSize = 11, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextStrokeTransparency = 1, Parent = button })
		end
		local dot = Kit.frame({ Size = UDim2.fromOffset(11, 11), Position = UDim2.new(1, -8, 0, -3), BackgroundColor3 = C.Bad, Visible = false, ZIndex = 3, Parent = button })
		Kit.corner(6).Parent = dot
		self.Dots[key] = dot
		self.Buttons[key] = button
		return button
	end

	function self:SetBadge(key, on)
		local dot = self.Dots[key]
		if dot then
			dot.Visible = on == true
		end
	end

	-- label of a small (glyph-only) button, e.g. the camera toggle
	function self:SetButtonText(key, glyph, label)
		local button = self.Buttons[key]
		if button then
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("TextLabel") and glyph then
					child.Text = glyph
					break
				end
			end
		end
	end

	-- Hide / show everything that is not the battle itself (only meaningful while watching).
	function self:SetHudHidden(hidden)
		self.HudHidden = hidden
		-- the party (top-left) and the currencies (top-right) stay; only the map card and the menu dock go
		self.MapCard.Visible = not hidden
		if self.Travel then
			self.Travel.Visible = not hidden
		end
		if self.Dock then
			self.Dock.Visible = not hidden
		end
		self.HideButton.Text = if hidden then "Show HUD" else "Hide HUD"
		-- the skill bar sits above the menu dock; with the dock hidden it drops to the bottom edge
		local drop = if hidden then 66 else 0
		local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self.Bar, info, { Position = UDim2.new(0.5, -170, 1, -128 + drop) }):Play()
		TweenService:Create(self.CombatBuffRow, info, { Position = UDim2.new(0.5, -150, 1, -158 + drop) }):Play()
	end

	-- text = nil: not watching. The combat layer (skill bar, stage pill, timer) shows only while watching.
	function self:SetWatching(text, onStop)
		self.Watching.Visible = text ~= nil
		self.Combat.Visible = text ~= nil
		self.BuffRow.Visible = text == nil
		self.WatchText.Text = text or ""
		if text == nil then
			self:SetHudHidden(false)
		end
		if self.StopConn then
			self.StopConn:Disconnect()
			self.StopConn = nil
		end
		if text and onStop then
			self.StopConn = self.StopButton.Activated:Connect(onStop)
		end
	end

	-- Render ------------------------------------------------------------------
	function self:Render(state)
		local me = state.Player
		local party = state.Party
		local stage = party and party.Stage or me.Frontier
		local zone = Zones.ForStage(stage)
		-- the live map card
		local theme = zone.Theme
		local ground = Color3.fromRGB(theme.Ground[1], theme.Ground[2], theme.Ground[3])
		self.MapCard.BackgroundColor3 = ground:Lerp(Color3.new(0, 0, 0), 0.25)
		self.MapGlyph.Text = MAP_GLYPHS[theme.Scenery] or "🗺️"
		self.MapZone.Text = zone.Name
		self.MapStage.Text = ("Stage %d%s"):format(stage, Stages.IsBoss(stage) and "  👑" or "")
		Kit.clear(self.MapPips)
		local first = zone.FirstStage
		local frontier = party and party.Frontier or me.Frontier
		for i = 0, 9 do
			local s = first + i
			local color = if s == stage then C.Accent elseif s < frontier then Color3.fromRGB(120, 220, 140) else Color3.fromRGB(70, 74, 90)
			local pip = Kit.frame({ Size = UDim2.new(0.1, -3, 1, 0), BackgroundColor3 = color, Parent = self.MapPips })
			if Stages.IsBoss(s) then
				pip.BackgroundColor3 = if s == stage then C.Accent else Color3.fromRGB(200, 90, 90)
			end
		end
		local holding = party and party.Holding == true
		self.AdvanceButton.Visible = holding
		self.MapNote.Text = if holding then "Holding - tap Advance" elseif party then ("Furthest: %d"):format(frontier) else "No party yet"
		self.MapNote.Size = UDim2.new(1, if holding then -90 else -12, 0, 16)

		-- the card shown while spectating mirrors it
		self.CombatCard.BackgroundColor3 = self.MapCard.BackgroundColor3
		self.CGlyph.Text = self.MapGlyph.Text
		self.Zone.Text = zone.Name
		self.Stage.Text = self.MapStage.Text
		Kit.clear(self.CPips)
		for i = 0, 9 do
			local s2 = first + i
			local color = if s2 == stage then C.Accent elseif s2 < frontier then Color3.fromRGB(120, 220, 140) else Color3.fromRGB(70, 74, 90)
			local pip = Kit.frame({ Size = UDim2.new(0.1, -3, 1, 0), BackgroundColor3 = color, Parent = self.CPips })
			if Stages.IsBoss(s2) then
				pip.BackgroundColor3 = if s2 == stage then C.Accent else Color3.fromRGB(200, 90, 90)
			end
		end
		self.CAdvance.Visible = holding
		self.CNote.Text = if holding then "Holding" elseif party then ("Furthest: %d"):format(frontier) else "No party yet"

		self.LevelLabel.Text = tostring(me.Level)
		if me.IP then
			self.IPLabel.Text = ("IP %s"):format(Short(me.IP.Total))
			self.IPTip = ("<b>Item Power %s</b>\nLevel %s   Gear %s   Skills %s   Passives %s\nPet %s   Collection %s   Subclass %s   Titles %s   Guild %s"):format(Short(me.IP.Total), Short(me.IP.Level), Short(me.IP.Gear), Short(me.IP.Skills), Short(me.IP.Passives), Short(me.IP.Pet), Short(me.IP.Collection), Short(me.IP.Subclass), Short(me.IP.Titles), Short(me.IP.Guild))
		end
		self.Badge.BackgroundColor3 = C[me.ClassId] or C.Accent
		self.NameLabel.Text = me.Name .. "  -  " .. me.ClassId
		local frac = if me.XPNeeded and me.XPNeeded > 0 then math.clamp((me.XP or 0) / me.XPNeeded, 0, 1) else 0
		self.XpText = ("Level %d\nXP %s / %s"):format(me.Level, Short(me.XP or 0), Short(me.XPNeeded or 0))
		if me.Level >= 120 then -- level cap: the bar shows Paragon progress
			frac = math.clamp((me.ParagonXP or 0) / math.max(me.ParagonNeed or 1, 1), 0, 1)
			self.XpText = ("Paragon %d / 100\nXP %s / %s\nEach Paragon level: +0.4%% Attack, Health and Defense"):format(me.Paragon or 0, Short(me.ParagonXP or 0), Short(me.ParagonNeed or 0))
		end
		self.XpFill.Size = UDim2.fromScale(frac, 1)
		self.Gold.Text = "💰 " .. short(me.Gold)
		self.Shards.Text = "💠 " .. short(me.Shards)
		self.GoldExact, self.ShardExact = me.Gold, me.Shards
		self.Stones.Text = "💎 " .. short(me.Wishstones or 0)
		self.Suns.Text = "🔶 " .. short(me.Sunstones or 0)
		self.SunExact = me.Sunstones or 0
		self.StoneExact = me.Wishstones or 0

		Kit.clear(self.BuffRow)
		Kit.clear(self.CombatBuffRow)
		self.BuffChips = {}
		for _, buff in ipairs(me.Buffs or {}) do
			for _, rowFrame in ipairs({ self.BuffRow, self.CombatBuffRow }) do
				local f = pill(rowFrame, { Size = UDim2.fromOffset(64, 22), Position = UDim2.new() })
				local l = Kit.label({ Size = UDim2.new(1, -4, 1, 0), Position = UDim2.fromOffset(4, 0), Text = "", TextSize = 12, TextWrapped = false, Parent = f })
				Kit.Hover(f, function() return ("<b>%s</b>\n%s"):format(buff.Name, buff.Description) end)
				table.insert(self.BuffChips, { Frame = f, Label = l, Glyph = buff.Glyph, EndsAt = os.clock() + buff.Remaining })
			end
		end

		self:SetBadge("Skills", (me.SkillPicks or 0) > 0 or #(me.SubclassChoices or {}) > 0 or me.SkillReady == true)
		local petReady = false
		for _, pet in ipairs(me.Pets or {}) do
			if pet.Owned and (pet.Rank or 1) < (pet.MaxRank or 1) and (pet.Copies or 0) >= (pet.RankCost or 1) then
				petReady = true
			end
		end
		self:SetBadge("Pets", petReady)
		self:SetBadge("Party", party == nil)
		-- red dot on Quests when a quest, the daily bonus or a pass level is waiting to be claimed
		local waiting = me.Quests ~= nil and me.Quests.BonusReady == true
		for _, q in ipairs(me.Quests and me.Quests.Quests or {}) do
			waiting = waiting or (q.Done and not q.Claimed)
		end
		waiting = waiting or (me.WeeklyQuests ~= nil and me.WeeklyQuests.BonusReady == true)
		for _, q in ipairs(me.WeeklyQuests and me.WeeklyQuests.Quests or {}) do
			waiting = waiting or (q.Done and not q.Claimed)
		end
		for _, r in ipairs(me.Pass and me.Pass.Rows or {}) do
			waiting = waiting or (r.Reached and not r.Claimed) or (r.Reached and me.Pass.Premium == true and not r.PremiumClaimed)
		end
		self:SetBadge("Quests", waiting)

		-- party cards
		Kit.clear(self.Cards)
		local function card(name, classId, level, note, onClick, tip, ip)
			local f = pill(self.Cards, { Size = UDim2.fromOffset(220, 28), Position = UDim2.new() })
			local dot = Kit.frame({ Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = C[classId] or C.Accent, Parent = f })
			Kit.corner(10).Parent = dot
			Kit.label({ Size = UDim2.new(1, -if ip then 100 else 36, 1, 0), Position = UDim2.fromOffset(32, 0), Text = if classId ~= "" then ("%s  Lv %d %s%s"):format(name, level, classId, note or "") else name, TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
			if ip then
				Kit.label({ Size = UDim2.fromOffset(60, 28), Position = UDim2.new(1, -64, 0, 0), Text = ("IP %s"):format(Short(ip)), TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 3, Parent = f })
			end
			if onClick then
				local b = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4, Parent = f })
				b.Activated:Connect(onClick)
				if tip then
					Kit.Hover(b, function() return tip end)
				end
			end
		end
		if party and party.Partner then
			local p = party.Partner
			card(p.Name, p.ClassId, p.Level, p.Online and "" or "  (ghost)", function()
				if self.OnPartner then
					self.OnPartner()
				end
			end, ("<b>%s</b>  Lv %d %s\n%s\nClick for her stats, skills and gear"):format(p.Name, p.Level, p.ClassId, if p.Online then "Online" else "Fights as a ghost while away"), p.IP)
		elseif party then
			card("Waiting for partner...", "", 0, "", function()
				if self.OnParty then
					self.OnParty()
				end
			end, "Click to find a partner")
		end

		-- skill bar: equipped skills in cast order
		Kit.clear(self.Slots)
		for slot, id in ipairs(me.Loadout or {}) do
			local def = Abilities[id]
			if def then
				local icon = Icons.Skill(self.Slots, def, { Size = UDim2.fromOffset(50, 50), Level = me.SlotLevels[slot], LayoutOrder = slot })
				Kit.label({ Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(2, 0), Text = tostring(slot), TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, ZIndex = 3, Parent = icon })
				Kit.Hover(icon, function() return Tips.Skill(def, me.SlotLevels[slot], ((me.SkillInfo or {})[def.Id] or {}).Tier) end)
			end
		end

		-- ultimate (display only)
		if self.UltIcon then
			self.UltIcon:Destroy()
			self.UltIcon = nil
		end
		local ult = party and party.Ultimate
		local def = ult and ult.Chosen and UltCfg.Defs[ult.Chosen]
		self.UltIcon = Icons.Ultimate(self.UltSlot, def, { Size = UDim2.fromOffset(46, 40), Position = UDim2.fromOffset(12, 0), Locked = def == nil })
		self.UltDef = def
		Kit.Hover(self.UltIcon, function()
			if def then
				return Tips.Ultimate(def, 1) .. "\n" .. Kit.tint("Charges over time and with every skill cast by either partner.", C.Dim)
			end
			return "Party ultimate\n" .. Kit.tint("Needs a partner. Pick it in Party.", C.Dim)
		end)
	end

	-- A fight just ended: toast, timer bar, and replay the ultimate gauge.
	function self:OnFight(info)
		local text = info.Won and ("Stage " .. info.Stage .. " cleared!") or (info.TimedOut and "Time ran out - holding on the stage before" or "Defeated - holding on the stage before")
		if info.Reward then
			text ..= string.format("  +%s gold  +%s xp", Short(info.Reward.Gold or 0), Short(info.Reward.XP or 0))
			if (info.Reward.Wishstones or 0) > 0 then
				text ..= string.format("  +%d wishstone%s", info.Reward.Wishstones, if info.Reward.Wishstones > 1 then "s" else "")
			end
			if info.Reward.Item then
				text ..= "  +" .. info.Reward.Item
			end
			if info.Reward.Pets and #info.Reward.Pets > 0 then
				text ..= "  NEW PET!"
			end
		end
		self.Toast.Text = text
		self.FightFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(self.FightFill, TweenInfo.new(math.max(0.5, info.Wait or 3), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		self:_startGauge(info)
	end

	function self:Notify(text)
		self.Toast.Text = text
		local mine = text
		task.delay(6, function()
			if self.Toast.Text == mine then
				self.Toast.Text = ""
			end
		end)
	end

	-- Rebuild the shared ultimate gauge from the fight's events (same rules as the sim).
	function self:_startGauge(info)
		local teams = {}
		for _, entry in ipairs(info.Roster or {}) do
			teams[entry.Id] = entry.Team
		end
		local rate, perCast = UltCfg.ChargePerSecond or 1.5, UltCfg.ChargePerCast or 6
		local needed = UltCfg.ChargeNeeded or 100
		local points = { { T = 0, C = 0 } }
		local charge, last = 0, 0
		for _, e in ipairs(info.Events or {}) do
			local t = e.T or 0
			if e.Type == "Cast" and teams[e.Source] == "Party" then
				charge = math.min(needed, charge + rate * (t - last)) + perCast
				last = t
				table.insert(points, { T = t, C = math.min(needed, charge) })
				charge = math.min(needed, charge)
			elseif e.Type == "Ultimate" then
				charge, last = 0, t
				table.insert(points, { T = t, C = needed })
				table.insert(points, { T = t + 0.01, C = 0 })
			end
		end
		self.Charge.Points = points
		self.Charge.StartedAt = os.clock() + INTRO
		self.Charge.Needed = needed
		self.Charge.Rate = rate
		self.Charge.Pulses = {}
		for _, e in ipairs(info.Events or {}) do
			if e.Type == "Ultimate" then
				table.insert(self.Charge.Pulses, e.T)
			end
		end
	end

	local pulsed = {}
	RunService.Heartbeat:Connect(function()
		local g = self.Charge
		if not g.Points then
			return
		end
		local now = os.clock() - g.StartedAt
		if now < 0 then
			self.UltFill.Size = UDim2.fromScale(0, 1)
			return
		end
		local point = g.Points[1]
		for _, p in ipairs(g.Points) do
			if p.T <= now then
				point = p
			else
				break
			end
		end
		local value = math.min(g.Needed, point.C + g.Rate * (now - point.T))
		self.UltFill.Size = UDim2.fromScale(value / g.Needed, 1)
		for index, t in ipairs(g.Pulses or {}) do
			if now >= t and not pulsed[g.StartedAt .. ":" .. index] then
				pulsed[g.StartedAt .. ":" .. index] = true
				if self.UltIcon then
					local original = self.UltIcon.Size
					self.UltIcon.Size = UDim2.fromOffset(52, 46)
					TweenService:Create(self.UltIcon, TweenInfo.new(0.5), { Size = original }):Play()
				end
			end
		end
	end)

	return self
end

return Hud
