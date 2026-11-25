--[[
	LiveLog (ModuleScript): a small combat log that streams alongside a fight.
	It shows when a fight starts and the player can minimize it to a bar (it stays minimized across fights).
	Views (one button cycles them): Party damage, damage by Skill, Effects (every buff/debuff on each fighter right now with
	its time left, then what each one did this fight, in words) and the written Log. The pin button holds the current fight
	so it can be read after it ends (idle fights follow each other fast); press it again to follow new fights.

	  local log = LiveLog.new(root, buildLog)
	  log:Play(fight, delay)   -- start streaming fight events, delay seconds from now
]]
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FightStats = require(Shared.FightStats)
local StatusText = require(Shared.StatusText)
local IconLooks = require(Shared.Config.IconLooks)
local C = Kit.Colors

local LiveLog = {}
LiveLog.__index = LiveLog

local OPEN_H, BAR_H, WIDTH = 178, 22, 290

function LiveLog:SetHeightScale(scale)
	self.HeightScale = scale
	self:SetOpen(self.Open)
end

function LiveLog.new(parent, buildLog, buildMeter)
	local self = setmetatable({ BuildLog = buildLog, BuildMeter = buildMeter, Mode = "Damage", Lines = {}, Times = {}, Shown = 0, Open = true }, LiveLog)
	local frame = Kit.frame({
		Name = "LiveLog", Size = UDim2.fromOffset(WIDTH, OPEN_H), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -78), BackgroundColor3 = Color3.fromRGB(14, 16, 28), BackgroundTransparency = 0.2,
		Visible = false, ZIndex = 3, Parent = parent,
	})
	Kit.label({ Size = UDim2.new(1, -150, 0, BAR_H), Position = UDim2.fromOffset(8, 0), Text = "Combat", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.Dim, TextWrapped = false, Parent = frame })
	local toggle = Kit.button({
		Size = UDim2.fromOffset(26, 18), Position = UDim2.new(1, -32, 0, 3), Text = "-", TextSize = 16, BackgroundColor3 = C.PanelLight, Parent = frame,
	}, function() self:SetOpen(not self.Open) end)
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -BAR_H - 4), Position = UDim2.fromOffset(4, BAR_H), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame,
	})
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = scroll })
	self.Frame, self.Scroll, self.Toggle = frame, scroll, toggle

	-- a live damage meter (players, pets, minions) next to the log
	local meter = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -BAR_H - 4), Position = UDim2.fromOffset(4, BAR_H), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = frame,
	})
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = meter })
	self.Meter = meter
	-- buffs and debuffs: who carries what right now, then what each one did this fight
	local effects = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -BAR_H - 4), Position = UDim2.fromOffset(4, BAR_H), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = frame,
	})
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = effects })
	self.Effects = effects
	-- one button cycles the views: party damage, damage by skill (every source, both sides), effects, and the written log
	self.MeterButton = Kit.button({
		Size = UDim2.fromOffset(70, 18), Position = UDim2.new(1, -106, 0, 2), Text = "Damage", TextSize = 11, BackgroundColor3 = C.PanelLight, Parent = frame,
	}, function()
		self.Mode = if self.Mode == "Damage" then "Skills" elseif self.Mode == "Skills" then "Effects" elseif self.Mode == "Effects" then "Log" else "Damage"
		self:_Layout()
		self:_RefreshMeter(true)
		self:_RefreshEffects(true)
	end)
	Kit.Hover(self.MeterButton, function()
		return "Switch view: Party damage, Skills, Effects (buffs and debuffs), Log"
	end)
	-- hold this fight: new fights do not replace it until pressed again
	self.PinButton = Kit.button({
		Size = UDim2.fromOffset(28, 18), Position = UDim2.new(1, -138, 0, 2), Text = "📌", TextSize = 11, BackgroundColor3 = C.PanelLight, Parent = frame,
	}, function()
		self.Pinned = not self.Pinned
		self.PinButton.BackgroundColor3 = if self.Pinned then C.Accent else C.PanelLight
		self:_RefreshEffects(true)
	end)
	Kit.Hover(self.PinButton, function()
		return if self.Pinned then "Holding this fight. Press to follow new fights again." else "Hold this fight so you can read it after it ends."
	end)

	RunService.Heartbeat:Connect(function()
		if not self.StartAt then
			return
		end
		local now = os.clock() - self.StartAt
		self:_RefreshMeter(false, now)
		self:_RefreshEffects(false, now)
		while self.Shown < #self.Lines and self.Times[self.Shown + 1] <= now do
			self.Shown += 1
			Kit.label({
				Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = self.Lines[self.Shown], TextSize = 11,
				RichText = true, LayoutOrder = self.Shown, Parent = scroll,
			})
			scroll.CanvasPosition = Vector2.new(0, 1e6)
		end
	end)
	return self
end

function LiveLog:_Layout()
	self.Scroll.Visible = self.Open and self.Mode == "Log"
	self.Meter.Visible = self.Open and (self.Mode == "Damage" or self.Mode == "Skills")
	self.Effects.Visible = self.Open and self.Mode == "Effects"
	self.MeterButton.Text = if self.Mode == "Damage" then "Party" elseif self.Mode == "Skills" then "Skills" elseif self.Mode == "Effects" then "Effects" else "Log"
end

local KIND_COLOR = {
	Buff = Color3.fromRGB(120, 220, 140), Shield = Color3.fromRGB(110, 180, 255), Debuff = Color3.fromRGB(235, 130, 110),
	Dot = Color3.fromRGB(255, 150, 80), Cc = Color3.fromRGB(255, 225, 100),
}
local function lookOf(statusId)
	local look = IconLooks.Statuses[statusId]
	return (look and look.Glyph) or "•", KIND_COLOR[look and look.Kind or "Buff"] or C.Text
end

-- The Effects view. Live part: each fighter with its statuses and seconds left. Then every status this fight: how often,
-- on whom, and what it does in numbers. Rebuilt about once a second while the fight runs, then left still (hover a row
-- for the full words, and who put it on whom).
function LiveLog:_RefreshEffects(force, now)
	if not (self.Mode == "Effects" and self.Fight and self.Open) then
		return
	end
	now = now or (os.clock() - (self.StartAt or os.clock()))
	local duration = self.Fight.Duration or 0
	local over = now > duration + 0.3
	if not force then
		if over and self.EffectsFinal == self.Fight then
			return
		end
		if os.clock() - (self.LastEffects or 0) < 1 then
			return
		end
	end
	self.LastEffects = os.clock()
	self.EffectsFinal = if over then self.Fight else nil
	for _, child in ipairs(self.Effects:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(text, size, hover)
		order += 1
		local l = Kit.label({
			Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = size or 11, RichText = true,
			TextWrapped = true, LayoutOrder = order, Parent = self.Effects,
		})
		if hover then
			l.Active = true
			Kit.Hover(l, hover)
		end
		return l
	end
	local t = math.max(0, math.min(now, duration))
	if self.Pinned then
		line(Kit.tint("📌 Held fight" .. (if over then " (over)" else ""), C.Accent), 11)
	end
	-- now
	line(if over then "<b>At the end</b>" else ("<b>Now</b>  " .. Kit.tint(("%.0f s"):format(t), C.Dim)), 12)
	local active = StatusText.ActiveAt(self.Fight, t)
	local any = false
	for _, entry in ipairs(self.Fight.Roster or {}) do
		local list = active[entry.Id]
		if list and #list > 0 then
			any = true
			local chips = {}
			for _, st in ipairs(list) do
				local glyph, color = lookOf(st.Status)
				local d = StatusText.Describe(st.Status)
				table.insert(chips, Kit.tint(glyph .. " " .. d.Name .. (if st.Stacks and st.Stacks > 1 then " x" .. st.Stacks else "") .. (" %ds"):format(math.ceil(st.Left)), color))
			end
			local who = Kit.tint(entry.Name or "?", if entry.Team == "Party" then Color3.fromRGB(150, 200, 255) else Color3.fromRGB(255, 160, 150))
			line(who .. ": " .. table.concat(chips, ", "), 11, function()
				local lines = {}
				for _, st in ipairs(list) do
					local glyph = lookOf(st.Status)
					local d = StatusText.Describe(st.Status)
					table.insert(lines, ("<b>%s %s</b>: %s"):format(glyph, d.Name, d.Text))
				end
				return table.concat(lines, "\n")
			end)
		end
	end
	if not any then
		line(Kit.tint("nothing on anyone", C.Dim), 11)
	end
	-- this fight
	line("<b>This fight</b>", 12)
	local rows = StatusText.Summary(self.Fight, t)
	if #rows == 0 then
		line(Kit.tint("no buffs or debuffs yet", C.Dim), 11)
	end
	for _, row in ipairs(rows) do
		local glyph, color = lookOf(row.Status)
		local on = if row.OnHeroes > 0 and row.OnEnemies > 0 then "both sides" elseif row.OnHeroes > 0 then "heroes" else "monsters"
		local head = Kit.tint(glyph .. " " .. row.Name, color) .. Kit.tint(("  x%d on %s, %.0f s up"):format(row.Applied, on, row.Uptime), C.Dim)
		line(head .. "\n" .. Kit.tint(row.Text, Color3.fromRGB(205, 210, 225)), 11, function()
			return ("<b>%s %s</b>\n%s\nBy: %s\nOn: %s"):format(glyph, row.Name, row.Text, table.concat(row.By, ", "), table.concat(row.On, ", "))
		end)
	end
end

function LiveLog:_RefreshMeter(force, now)
	if not (self.Mode ~= "Log" and self.Fight and self.BuildMeter) then
		return
	end
	now = now or (os.clock() - (self.StartAt or os.clock()))
	if not force and os.clock() - (self.LastMeter or 0) < 0.5 then
		return
	end
	self.LastMeter = os.clock()
	for _, child in ipairs(self.Meter:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local upTo = math.max(now, 1)
	self.BuildMeter(self.Meter, if self.Mode == "Skills" then FightStats.Sources(self.Fight, upTo) else FightStats.Compute(self.Fight, upTo))
end

function LiveLog:SetOpen(open)
	self.Open = open
	self:_Layout()
	self.Toggle.Text = if open then "-" else "+"
	-- with a bigger HUD (Settings) the log is drawn larger, so it gets fewer rows and stays clear of the
	-- (also bigger) corner buttons above it
	-- touch screens: the log sits higher and is shorter, so it never covers Roblox's jump button (bottom-right)
	local lift = if Kit.Touch then 70 else 0
	self.Frame.Position = UDim2.new(1, -10, 1, -78 - lift)
	self.Frame.Size = UDim2.fromOffset(WIDTH, if open then math.max(BAR_H + 60, math.floor(OPEN_H / (self.HeightScale or 1) ^ 2) - lift) else BAR_H)
end

function LiveLog:Play(fight, delay)
	if self.Pinned then
		return -- holding a fight: this one is skipped here (the 3D fight still plays)
	end
	for _, child in ipairs(self.Scroll:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local lines, _, times = self.BuildLog(fight, true)
	self.Lines, self.Times, self.Shown = lines, times, 0
	self.Fight = fight
	self.StartAt = os.clock() + (delay or 0)
	self.Frame.Visible = true
	self:SetOpen(self.Open) -- keep it minimized if the player minimized it (it used to reopen every fight)
end

return LiveLog
