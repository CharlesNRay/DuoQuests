--[[
	Hud (ModuleScript): the always-visible overlay, laid out like a Roblox game
	rather than one crowded block:

	  top-left     portrait (level, name, XP) with gold / shards pills under it
	  top-centre   zone + stage, fight timer, toast, "watching" bar
	  left rail    character buttons (Skills, Passives, Pets, Party)
	  right rail   world buttons (Map, Gear, Bag, Daily, Ranks)
	  bottom-right Log and Battle view
	  bottom-left  party cards
	  bottom-centre skill bar: your four skills in cast order plus the party
	               ultimate gauge. The ultimate is NOT a button: it fires itself.

	Everything is plain Frames (no art assets).

	  hud:AddButton(key, side, glyph, label, onClick) -> button  ("left"|"right"|"corner")
	  hud:SetBadge(key, bool)         red dot on a button
	  hud:Render(state)               refresh from the server state
	  hud:OnFight(info)               own fight finished: toast, timer, ultimate gauge
	  hud:SetWatching(text, onStop)   show/hide the "watching another battle" bar
	  hud:ShowBanner(text, color)
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Zones)
local Stages = require(Shared.Stages)
local Abilities = require(Shared.Config.Abilities)
local UltCfg = require(Shared.Config.Ultimates)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local C = Kit.Colors

local Hud = {}

local INTRO = 0.8 -- matches Battle/Replay: monsters run in before the first blow

local function pill(parent, props)
	local f = Kit.frame({ Size = props.Size, Position = props.Position, BackgroundColor3 = Color3.fromRGB(16, 18, 30), BackgroundTransparency = 0.25, Parent = parent })
	Kit.new("UIStroke", { Color = Color3.fromRGB(90, 98, 130), Thickness = 1, Transparency = 0.4, Parent = f })
	return f
end

function Hud.new(root)
	local self = { Buttons = {}, Charge = { Points = nil, StartedAt = 0, Needed = UltCfg.ChargeNeeded or 100, Rate = UltCfg.ChargePerSecond or 1.5 } }
	local gui = Kit.frame({ Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = root })
	self.Gui = gui

	-- top-left: portrait ---------------------------------------------------
	local portrait = pill(gui, { Size = UDim2.fromOffset(212, 46), Position = UDim2.fromOffset(8, 6) })
	self.Badge = Kit.frame({ Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.Accent, Parent = portrait })
	Kit.corner(19).Parent = self.Badge
	self.LevelLabel = Kit.label({ Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = C.Bg, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = self.Badge })
	self.NameLabel = Kit.label({ Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(48, 4), Text = "", TextSize = 14, Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = portrait })
	local xpBack = Kit.frame({ Size = UDim2.new(1, -56, 0, 8), Position = UDim2.fromOffset(48, 28), BackgroundColor3 = Color3.fromRGB(40, 44, 64), Parent = portrait })
	self.XpFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 180, 255), Parent = xpBack })
	Kit.Hover(portrait, function()
		return self.XpText
	end)

	self.Gold = Kit.label({ Size = UDim2.fromOffset(100, 22), Position = UDim2.fromOffset(8, 56), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = gui })
	self.Shards = Kit.label({ Size = UDim2.fromOffset(100, 22), Position = UDim2.fromOffset(112, 56), Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 210, 255), Parent = gui })

	-- top-centre: zone, stage, fight timer ---------------------------------
	local top = pill(gui, { Size = UDim2.fromOffset(280, 44), Position = UDim2.new(0.5, -140, 0, 6) })
	self.Zone = Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 3), Text = "", TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = top })
	self.Stage = Kit.label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 17), Text = "Stage -", TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, Parent = top })
	self.Fight = Kit.frame({ Size = UDim2.fromOffset(200, 5), Position = UDim2.new(0.5, -100, 0, 54), BackgroundColor3 = Color3.fromRGB(16, 18, 30), Parent = gui })
	self.FightFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = self.Fight })
	self.Toast = Kit.label({ Size = UDim2.new(0, 400, 0, 20), Position = UDim2.new(0.5, -200, 0, 62), Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Accent, Parent = gui })

	self.Watching = pill(gui, { Size = UDim2.fromOffset(300, 34), Position = UDim2.new(0.5, -150, 0, 86) })
	self.Watching.Visible = false
	self.WatchText = Kit.label({ Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "", TextSize = 13, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = self.Watching })
	self.StopButton = Kit.button({ Size = UDim2.fromOffset(92, 28), Position = UDim2.new(1, -98, 0, 3), Text = "Stop", TextSize = 13, BackgroundColor3 = C.Bad, Parent = self.Watching })

	-- rails -----------------------------------------------------------------
	local function rail(position, anchor)
		local f = Kit.frame({ Size = UDim2.fromOffset(50, 10), AutomaticSize = Enum.AutomaticSize.Y, Position = position, AnchorPoint = anchor or Vector2.new(0, 0), BackgroundTransparency = 1, NoCorner = true, Parent = gui })
		Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = if anchor and anchor.Y == 1 then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top, Parent = f })
		return f
	end
	self.Rails = {
		left = rail(UDim2.fromOffset(8, 92)),
		right = rail(UDim2.fromOffset(786, 6)),
		corner = rail(UDim2.fromOffset(786, 384), Vector2.new(0, 1)),
	}

	-- bottom-left: party cards ---------------------------------------------
	self.Cards = Kit.frame({ Size = UDim2.fromOffset(168, 62), Position = UDim2.fromOffset(8, 322), BackgroundTransparency = 1, NoCorner = true, Parent = gui })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 3), Parent = self.Cards })

	-- bottom-centre: skill bar + ultimate gauge ----------------------------
	self.Bar = pill(gui, { Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0.5, -150, 1, -62) })
	self.Slots = Kit.frame({ Size = UDim2.fromOffset(212, 48), Position = UDim2.fromOffset(6, 4), BackgroundTransparency = 1, NoCorner = true, Parent = self.Bar })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = self.Slots })
	self.UltSlot = Kit.frame({ Size = UDim2.fromOffset(64, 48), Position = UDim2.new(1, -70, 0, 4), BackgroundTransparency = 1, NoCorner = true, Parent = self.Bar })
	self.UltIcon = nil
	self.UltBack = Kit.frame({ Size = UDim2.fromOffset(52, 6), Position = UDim2.fromOffset(6, 40), BackgroundColor3 = Color3.fromRGB(40, 44, 64), Parent = self.UltSlot })
	self.UltFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Kit.Colors.Epic, Parent = self.UltBack })

	-- banner ------------------------------------------------------------------
	self.BannerLabel = Kit.label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0.3, 0), Text = "", TextSize = 36, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
	function self:ShowBanner(text, color)
		self.BannerLabel.Text = text
		self.BannerLabel.TextColor3 = color
		self.BannerLabel.TextTransparency = 0
		TweenService:Create(self.BannerLabel, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
	end

	function self:AddButton(key, side, glyph, label, onClick)
		local button = Kit.button({ Size = UDim2.fromOffset(50, 46), Text = "", BackgroundColor3 = Color3.fromRGB(26, 30, 48), Parent = self.Rails[side] }, onClick)
		button.BackgroundTransparency = 0.15
		Kit.new("UIStroke", { Color = Color3.fromRGB(110, 118, 150), Thickness = 1, Transparency = 0.5, Parent = button })
		Kit.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 2), Text = glyph, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = button })
		Kit.label({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 29), Text = label, TextSize = 10, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextStrokeTransparency = 1, Parent = button })
		local dot = Kit.frame({ Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -9, 0, -3), BackgroundColor3 = C.Bad, Visible = false, ZIndex = 3, Parent = button })
		Kit.corner(6).Parent = dot
		button.Dot = dot
		self.Buttons[key] = button
		return button
	end

	function self:SetBadge(key, on)
		local button = self.Buttons[key]
		if button then
			button.Dot.Visible = on == true
		end
	end

	function self:SetButtonText(key, glyph, label)
		local button = self.Buttons[key]
		if button then
			local labels = {}
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("TextLabel") then
					table.insert(labels, child)
				end
			end
			table.sort(labels, function(a, b) return a.Position.Y.Offset < b.Position.Y.Offset end)
			if labels[1] and glyph then labels[1].Text = glyph end
			if labels[2] and label then labels[2].Text = label end
		end
	end

	function self:SetWatching(text, onStop)
		self.Watching.Visible = text ~= nil
		self.WatchText.Text = text or ""
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
		self.Zone.Text = ("%s  -  %d/%d"):format(zone.Name, Zones.StageInZone(stage), require(Shared.Config.Stages).BossEvery)
		self.Stage.Text = ("Stage %d%s"):format(stage, Stages.IsBoss(stage) and "  BOSS" or "")
		self.Stage.TextColor3 = if Stages.IsBoss(stage) then C.Bad else C.Text

		self.LevelLabel.Text = tostring(me.Level)
		self.Badge.BackgroundColor3 = C[me.ClassId] or C.Accent
		self.NameLabel.Text = me.Name .. "  -  " .. me.ClassId
		local frac = if me.XPNeeded and me.XPNeeded > 0 then math.clamp((me.XP or 0) / me.XPNeeded, 0, 1) else 0
		self.XpFill.Size = UDim2.fromScale(frac, 1)
		self.XpText = ("Level %d\nXP %d / %d"):format(me.Level, me.XP or 0, me.XPNeeded or 0)
		self.Gold.Text = "Gold  " .. me.Gold
		self.Shards.Text = "Shards  " .. me.Shards

		self:SetBadge("Skills", (me.SkillPicks or 0) > 0 or #(me.SubclassChoices or {}) > 0)
		self:SetBadge("Daily", me.Daily ~= nil and me.Daily.CanClaim == true)
		self:SetBadge("Party", party == nil)

		-- party cards
		Kit.clear(self.Cards)
		local function card(name, classId, level, note)
			local f = pill(self.Cards, { Size = UDim2.fromOffset(168, 28), Position = UDim2.new() })
			local dot = Kit.frame({ Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = C[classId] or C.Accent, Parent = f })
			Kit.corner(9).Parent = dot
			Kit.label({ Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(28, 0), Text = ("%s  Lv %d%s"):format(name, level, note or ""), TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
		end
		card(me.Name, me.ClassId, me.Level)
		if party and party.Partner then
			local p = party.Partner
			card(p.Name, p.ClassId, p.Level, p.Online and "" or "  (ghost)")
		elseif party then
			card("Waiting for partner...", "", 0, "")
		end

		-- skill bar: equipped skills in cast order
		Kit.clear(self.Slots)
		for slot, id in ipairs(me.Loadout or {}) do
			local def = Abilities[id]
			if def then
				local icon = Icons.Skill(self.Slots, def, { Size = UDim2.fromOffset(44, 44), Level = me.SlotLevels[slot], LayoutOrder = slot })
				Kit.label({ Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(2, 0), Text = tostring(slot), TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, ZIndex = 3, Parent = icon })
				Kit.Hover(icon, function() return Tips.Skill(def, me.SlotLevels[slot]) end)
			end
		end

		-- ultimate (display only)
		if self.UltIcon then
			self.UltIcon:Destroy()
			self.UltIcon = nil
		end
		local ult = party and party.Ultimate
		local def = ult and ult.Chosen and UltCfg.Defs[ult.Chosen]
		self.UltIcon = Icons.Ultimate(self.UltSlot, def, { Size = UDim2.fromOffset(40, 36), Position = UDim2.fromOffset(12, 0), Locked = def == nil })
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
		local text = info.Won and ("Stage " .. info.Stage .. " cleared!") or (info.TimedOut and "Time ran out - back a stage" or "Defeated - back a stage")
		if info.Reward then
			text ..= string.format("  +%d gold  +%d xp", info.Reward.Gold or 0, info.Reward.XP or 0)
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
