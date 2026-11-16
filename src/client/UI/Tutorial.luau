--[[
	Tutorial (ModuleScript): the guided first session shown on the left of the screen.

	  local tutorial = Tutorial.new(root, hud, call, getContext)
	  tutorial:Update(state, hidden)   every redraw; hidden = a window or the main menu is covering the screen
	  tutorial:Opened("Skills")        a window was opened (some steps wait for that)

	The steps live in Shared/Tutorial. The server only remembers the step and pays the reward once.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Tutorial = require(ReplicatedStorage:WaitForChild("Shared").Tutorial)

local C = Kit.Colors
local GOLD = Color3.fromRGB(255, 196, 70)
local WIDTH = 262

local TutorialUI = {}
TutorialUI.__index = TutorialUI

-- what each step points at on the HUD
local function targetOf(hud, name)
	if name == "Party" then
		return hud.Cards
	elseif name == "Stage" then
		return hud.MapCard
	end
	return hud.Buttons and hud.Buttons[name]
end

function TutorialUI.new(root, hud, call, getContext)
	local self = setmetatable({ Hud = hud, Call = call, Opened_ = {}, Busy = false, Step = 0, Shown = false }, TutorialUI)

	local card = Kit.frame({
		Name = "Tutorial", Size = UDim2.fromOffset(WIDTH, 118), Position = UDim2.fromOffset(-WIDTH - 20, 106),
		BackgroundColor3 = Color3.fromRGB(16, 19, 32), BackgroundTransparency = 0.04, Visible = false, ZIndex = 20, Parent = root,
	})
	Kit.new("UIStroke", { Color = GOLD, Thickness = 1.2, Transparency = 0.55, Parent = card })
	Kit.frame({ Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = GOLD, NoCorner = true, ZIndex = 21, Parent = card })
	self.Card = card
	self.StepLabel = Kit.label({ Size = UDim2.new(1, -90, 0, 14), Position = UDim2.fromOffset(14, 8), Text = "", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })
	self.SkipButton = Kit.new("TextButton", {
		Size = UDim2.fromOffset(70, 14), Position = UDim2.new(1, -78, 0, 8), BackgroundTransparency = 1, Text = "Skip tutorial", TextSize = 10,
		Font = Enum.Font.GothamMedium, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = card,
	})
	self.SkipButton.Activated:Connect(function()
		self:_run("TutorialSkip")
	end)
	self.Title = Kit.label({ Size = UDim2.new(1, -26, 0, 20), Position = UDim2.fromOffset(14, 24), Text = "", TextSize = 15, Font = Enum.Font.GothamBold, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })
	self.Body = Kit.label({ Size = UDim2.new(1, -28, 0, 44), Position = UDim2.fromOffset(14, 46), Text = "", TextSize = 12, TextColor3 = Color3.fromRGB(196, 202, 222), TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })

	-- progress bar for "reach a stage" steps
	self.Bar = Kit.frame({ Size = UDim2.new(1, -28, 0, 5), Position = UDim2.new(0, 14, 1, -22), BackgroundColor3 = Color3.fromRGB(36, 40, 62), NoCorner = true, Visible = false, ZIndex = 21, Parent = card })
	self.Fill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, NoCorner = true, ZIndex = 22, Parent = self.Bar })
	self.BarText = Kit.label({ Size = UDim2.new(1, -28, 0, 12), Position = UDim2.new(0, 14, 1, -16), Text = "", TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, TextStrokeTransparency = 1, Visible = false, ZIndex = 21, Parent = card })

	self.Next = Kit.button({ Size = UDim2.fromOffset(76, 24), Position = UDim2.new(1, -90, 1, -32), Text = "Next", TextSize = 12, BackgroundColor3 = Color3.fromRGB(214, 160, 44), TextColor3 = Color3.fromRGB(30, 22, 6), Visible = false, ZIndex = 22, Parent = card }, function()
		self:_run("TutorialAdvance", self.Step)
	end)

	-- a pulsing outline on whatever the step points at
	self.Pulse = Kit.frame({ Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, -3), BackgroundTransparency = 1, NoCorner = true, Visible = false, ZIndex = 30 })
	Kit.corner(10).Parent = self.Pulse
	self.PulseStroke = Kit.new("UIStroke", { Color = GOLD, Thickness = 2.5, Parent = self.Pulse })
	RunService.Heartbeat:Connect(function()
		local wave = math.sin(os.clock() * 4) * 0.5 + 0.5
		self.PulseStroke.Transparency = 0.15 + wave * 0.6
		self.PulseStroke.Thickness = 2 + wave * 2
	end)

	-- the little "tutorial complete" banner
	local done = Kit.frame({ Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0.5, -150, 0, 150), BackgroundColor3 = Color3.fromRGB(16, 19, 32), Visible = false, ZIndex = 40, Parent = root })
	Kit.new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3, Parent = done })
	Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(12, 6), Text = "Tutorial complete", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 41, Parent = done })
	self.DoneText = Kit.label({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(12, 30), Text = "", TextSize = 12, TextColor3 = C.Text, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 41, Parent = done })
	self.DoneCard = done

	-- keeps itself current: the context is the latest state and whether a window or the menu is covering the screen
	task.spawn(function()
		while true do
			task.wait(0.4)
			local state, hidden = getContext()
			local ok, err = pcall(self.Update, self, state, hidden)
			if not ok then
				warn("[DuoQuest] tutorial: " .. tostring(err))
				task.wait(5)
			end
		end
	end)
	return self
end

function TutorialUI:_run(action, ...)
	if self.Busy then
		return
	end
	self.Busy = true
	local args = table.pack(...)
	task.spawn(function()
		local ok, result = self.Call(action, table.unpack(args, 1, args.n))
		self.Busy = false
		if ok and action == "TutorialFinish" and type(result) == "table" then
			self:_celebrate(result)
		end
	end)
end

function TutorialUI:_celebrate(reward)
	self.DoneText.Text = ("+%d Wishstones   +%d Skill Pick"):format(reward.Wishstones or 0, reward.SkillPicks or 0)
	self.DoneCard.Visible = true
	task.delay(5, function()
		self.DoneCard.Visible = false
	end)
end

function TutorialUI:_point(target)
	if self.Target == target then
		return
	end
	self.Target = target
	if target == nil or not target.Parent then
		self.Pulse.Visible = false
		self.Pulse.Parent = nil
		return
	end
	self.Pulse.Parent = target
	self.Pulse.Visible = true
end

function TutorialUI:_slide(show)
	if self.Shown == show then
		return
	end
	self.Shown = show
	if show then
		self.Card.Visible = true
		TweenService:Create(self.Card, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(8, 106) }):Play()
	else
		local tween = TweenService:Create(self.Card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(-WIDTH - 20, 106) })
		tween:Play()
		tween.Completed:Connect(function()
			if not self.Shown then
				self.Card.Visible = false
			end
		end)
	end
end

function TutorialUI:Opened(name)
	self.Opened_[name] = true
end

function TutorialUI:Update(state, hidden)
	local player = state and state.Player
	local t = player and player.Tutorial
	if not t or t.Done then
		self:_slide(false)
		self:_point(nil)
		return
	end
	local frontier = player.Frontier or 1
	if not self.Busy then
		if frontier > Tutorial.BossStage and not t.Rewarded then
			-- somebody who is already past the first boss never needed the tutorial; one who just beat it gets the reward
			if t.Step <= 1 then
				self:_run("TutorialSkip")
			else
				self:_run("TutorialFinish")
			end
			return
		end
		local def = Tutorial.Steps[t.Step]
		if def and ((def.Kind == "frontier" and frontier >= def.Goal) or (def.Kind == "open" and self.Opened_[def.Goal])) then
			self:_run("TutorialAdvance", t.Step)
			return
		end
	end
	local def = Tutorial.Steps[t.Step]
	if not def then
		return
	end
	self.Step = t.Step
	self.StepLabel.Text = ("STEP %d OF %d"):format(t.Step, #Tutorial.Steps)
	self.Title.Text = def.Title
	self.Body.Text = def.Text
	self.Next.Visible = def.Kind == "next"
	local showBar = def.Kind == "frontier"
	self.Bar.Visible, self.BarText.Visible = showBar, showBar
	if showBar then
		local from = if def.Goal > 5 then 1 else 1
		local frac = math.clamp((frontier - from) / math.max(def.Goal - from, 1), 0, 1)
		self.Fill.Size = UDim2.fromScale(frac, 1)
		self.BarText.Text = ("Stage %d of %d"):format(math.min(frontier, def.Goal), def.Goal)
	end
	self.Card.Size = UDim2.fromOffset(WIDTH, if def.Kind == "next" then 132 elseif showBar then 126 else 112)
	self:_slide(not hidden)
	self:_point(if hidden then nil else targetOf(self.Hud, def.Target))
end

return TutorialUI
