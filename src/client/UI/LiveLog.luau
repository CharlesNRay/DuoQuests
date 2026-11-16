--[[
	LiveLog (ModuleScript): a small combat log that streams alongside a fight.
	It pops open when a fight starts and the player can minimize it to a bar.

	  local log = LiveLog.new(root, buildLog)
	  log:Play(fight, delay)   -- start streaming fight events, delay seconds from now
]]
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local FightStats = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").FightStats)
local C = Kit.Colors

local LiveLog = {}
LiveLog.__index = LiveLog

local OPEN_H, BAR_H = 150, 24

function LiveLog.new(parent, buildLog, buildMeter)
	local self = setmetatable({ BuildLog = buildLog, BuildMeter = buildMeter, MeterOn = false, Lines = {}, Times = {}, Shown = 0, Open = true }, LiveLog)
	local frame = Kit.frame({
		Name = "LiveLog", Size = UDim2.fromOffset(300, OPEN_H), AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -78), BackgroundColor3 = Color3.fromRGB(14, 16, 28), BackgroundTransparency = 0.2,
		Visible = false, ZIndex = 3, Parent = parent,
	})
	Kit.label({ Size = UDim2.new(1, -40, 0, BAR_H), Position = UDim2.fromOffset(8, 0), Text = "Combat log", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.Dim, TextWrapped = false, Parent = frame })
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
	self.MeterButton = Kit.button({
		Size = UDim2.fromOffset(52, 18), Position = UDim2.new(1, -90, 0, 3), Text = "DPS", TextSize = 12, BackgroundColor3 = C.PanelLight, Parent = frame,
	}, function()
		self.MeterOn = not self.MeterOn
		self:_Layout()
		self:_RefreshMeter(true)
	end)

	RunService.Heartbeat:Connect(function()
		if not self.StartAt then
			return
		end
		local now = os.clock() - self.StartAt
		self:_RefreshMeter(false, now)
		while self.Shown < #self.Lines and self.Times[self.Shown + 1] <= now do
			self.Shown += 1
			Kit.label({
				Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = self.Lines[self.Shown], TextSize = 12,
				RichText = true, LayoutOrder = self.Shown, Parent = scroll,
			})
			scroll.CanvasPosition = Vector2.new(0, 1e6)
		end
	end)
	return self
end

function LiveLog:_Layout()
	self.Scroll.Visible = self.Open and not self.MeterOn
	self.Meter.Visible = self.Open and self.MeterOn
	self.MeterButton.Text = if self.MeterOn then "Log" else "DPS"
end

function LiveLog:_RefreshMeter(force, now)
	if not (self.MeterOn and self.Fight and self.BuildMeter) then
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
	self.BuildMeter(self.Meter, FightStats.Compute(self.Fight, math.max(now, 1)))
end

function LiveLog:SetOpen(open)
	self.Open = open
	self:_Layout()
	self.Toggle.Text = if open then "-" else "+"
	self.Frame.Size = UDim2.fromOffset(300, if open then OPEN_H else BAR_H)
end

function LiveLog:Play(fight, delay)
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
	self:SetOpen(true)
end

return LiveLog
