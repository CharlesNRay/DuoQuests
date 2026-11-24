--[[
	LiveLog (ModuleScript): a small combat log that streams alongside a fight.
	It shows when a fight starts and the player can minimize it to a bar (it stays minimized across fights).

	  local log = LiveLog.new(root, buildLog)
	  log:Play(fight, delay)   -- start streaming fight events, delay seconds from now
]]
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local FightStats = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").FightStats)
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
	Kit.label({ Size = UDim2.new(1, -40, 0, BAR_H), Position = UDim2.fromOffset(8, 0), Text = "Combat", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.Dim, TextWrapped = false, Parent = frame })
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
	-- one button cycles the three views: party damage, damage by skill (every source, both sides), and the written log
	self.MeterButton = Kit.button({
		Size = UDim2.fromOffset(70, 18), Position = UDim2.new(1, -106, 0, 2), Text = "Damage", TextSize = 11, BackgroundColor3 = C.PanelLight, Parent = frame,
	}, function()
		self.Mode = if self.Mode == "Damage" then "Skills" elseif self.Mode == "Skills" then "Log" else "Damage"
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
	self.Meter.Visible = self.Open and self.Mode ~= "Log"
	self.MeterButton.Text = if self.Mode == "Damage" then "Party" elseif self.Mode == "Skills" then "Skills" else "Log"
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
	self.Frame.Size = UDim2.fromOffset(WIDTH, if open then math.floor(OPEN_H / (self.HeightScale or 1) ^ 2) else BAR_H)
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
	self:SetOpen(self.Open) -- keep it minimized if the player minimized it (it used to reopen every fight)
end

return LiveLog
