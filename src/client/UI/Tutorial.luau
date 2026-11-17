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
local WIDTH = 340

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
	self.StepLabel = Kit.label({ Size = UDim2.new(1, -110, 0, 16), Position = UDim2.fromOffset(14, 8), Text = "", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })
	self.SkipButton = Kit.new("TextButton", {
		Size = UDim2.fromOffset(90, 16), Position = UDim2.new(1, -98, 0, 8), BackgroundTransparency = 1, Text = "Skip tutorial", TextSize = 12,
		Font = Enum.Font.GothamMedium, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = card,
	})
	self.SkipButton.Activated:Connect(function()
		self:_run("TutorialSkip")
	end)
	self.Title = Kit.label({ Size = UDim2.new(1, -26, 0, 28), Position = UDim2.fromOffset(14, 26), Text = "", TextSize = 22, Font = Enum.Font.GothamBold, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })
	self.Body = Kit.label({ Size = UDim2.new(1, -28, 0, 44), Position = UDim2.fromOffset(14, 58), Text = "", TextSize = 17, TextColor3 = Color3.fromRGB(196, 202, 222), TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 1, ZIndex = 21, Parent = card })

	-- progress bar for "reach a stage" steps
	self.Bar = Kit.frame({ Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 1, -34), BackgroundColor3 = Color3.fromRGB(36, 40, 62), NoCorner = true, Visible = false, ZIndex = 21, Parent = card })
	self.Fill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, NoCorner = true, ZIndex = 22, Parent = self.Bar })
	self.BarText = Kit.label({ Size = UDim2.new(1, -28, 0, 14), Position = UDim2.new(0, 14, 1, -20), Text = "", TextSize = 12, TextColor3 = C.Dim, TextWrapped = false, TextStrokeTransparency = 1, Visible = false, ZIndex = 21, Parent = card })

	-- "Next", or on a step with a Go place, "Take me there" (walks the hero there; the step itself completes on its goal)
	self.Next = Kit.button({ Size = UDim2.fromOffset(150, 32), Position = UDim2.new(1, -164, 1, -42), Text = "Next", TextSize = 16, BackgroundColor3 = Color3.fromRGB(214, 160, 44), TextColor3 = Color3.fromRGB(30, 22, 6), Visible = false, ZIndex = 22, Parent = card }, function()
		local def = Tutorial.Steps[self.Step]
		if def and def.Go then
			if self.GoTo then
				self.GoTo(def.Go)
			end
			return
		end
		self:_run("TutorialAdvance", self.Step)
	end)

	-- big, obvious guidance: a bouncing arrow beside whatever the step points at, plus a glowing fill and outline on it
	-- (rebuilt when the HUD clears and redraws its widgets)
	self.Arrow = Kit.label({
		Name = "TutorialArrow", Size = UDim2.fromOffset(80, 80), AnchorPoint = Vector2.new(0.5, 0.5), Text = "▼", TextSize = 72, Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD, TextStrokeColor3 = Color3.fromRGB(40, 24, 0), TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false, Visible = false, ZIndex = 80, Parent = root,
	})
	self.Tap = Kit.label({
		Name = "TutorialTap", Size = UDim2.fromOffset(110, 24), AnchorPoint = Vector2.new(0.5, 0.5), Text = "TAP HERE", TextSize = 18, Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.fromRGB(40, 24, 0), TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false, Visible = false, ZIndex = 80, Parent = root,
	})
	RunService.Heartbeat:Connect(function()
		local wave = math.sin(os.clock() * 4) * 0.5 + 0.5
		local stroke, pulse = self.PulseStroke, self.Pulse
		if stroke and stroke.Parent then
			stroke.Transparency = 0.05 + wave * 0.4
			stroke.Thickness = 3 + wave * 3
		end
		local target = pulse and pulse.Parent
		local visible = target ~= nil and target:IsA("GuiObject") and target.AbsoluteSize.X > 0 and self.Shown
		if pulse and pulse.Parent then
			pulse.BackgroundColor3 = GOLD
			pulse.BackgroundTransparency = 0.72 + wave * 0.2
		end
		self.Arrow.Visible, self.Tap.Visible = visible, visible and self.PointsAtButton == true
		if visible then
			-- Absolute* values are screen pixels, but the arrow sits in root units (root has a UIScale), so convert:
			-- without this the arrow and "TAP HERE" drift away from targets on screens where the scale is not 1
			local scale = root.AbsoluteSize.X / math.max(1, root.Size.X.Offset)
			if scale <= 0 then
				scale = 1
			end
			local origin = root.AbsolutePosition
			local center = (target.AbsolutePosition + target.AbsoluteSize / 2 - origin) / scale
			local below = center.Y < root.AbsoluteSize.Y / scale * 0.5 -- targets in the top half get an arrow underneath, pointing up
			local bounce = math.abs(math.sin(os.clock() * 5)) * 10
			local halfH = target.AbsoluteSize.Y / scale / 2 + 42
			-- keep "TAP HERE" (110 wide, centred) on screen for buttons at the very edge; the arrow stays on the target
			local tapX = math.clamp(center.X, 60, root.AbsoluteSize.X / scale - 60)
			if below then
				self.Arrow.Text = "▲"
				self.Arrow.Position = UDim2.fromOffset(center.X, center.Y + halfH + bounce)
				self.Tap.Position = UDim2.fromOffset(tapX, center.Y + halfH + 44 + bounce)
			else
				self.Arrow.Text = "▼"
				self.Arrow.Position = UDim2.fromOffset(center.X, center.Y - halfH - bounce)
				self.Tap.Position = UDim2.fromOffset(tapX, center.Y - halfH - 44 - bounce)
			end
		end
	end)

	-- the little "tutorial complete" banner
	local done = Kit.frame({ Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0.5, -150, 0, 150), BackgroundColor3 = Color3.fromRGB(16, 19, 32), Visible = false, ZIndex = 40, Parent = root })
	Kit.new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3, Parent = done })
	self.DoneTitle = Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(12, 6), Text = "Tutorial complete", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextWrapped = false, TextStrokeTransparency = 1, ZIndex = 41, Parent = done })
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
		elseif ok and action == "TutorialComplete" then
			-- point at the next big goal so the player has something to chase
			self.DoneTitle.Text = "Tutorial complete"
			self.DoneText.Text = "Next goal: reach level 30 and choose your path!"
			self.DoneCard.Visible = true
			task.delay(6, function()
				self.DoneCard.Visible = false
			end)
		end
	end)
end

function TutorialUI:_celebrate(reward)
	self.DoneText.Text = ("+%d Pet Wishes   +%d Skill Wishes"):format(reward.PetWish or 0, reward.SkillWish or 0)
	self.DoneTitle.Text = "First boss beaten!"
	self.DoneCard.Visible = true
	task.delay(5, function()
		self.DoneCard.Visible = false
	end)
end

function TutorialUI:_point(target)
	local pulse = self.Pulse
	if target == nil or not target.Parent then
		if pulse then
			pulse:Destroy()
			self.Pulse, self.PulseStroke = nil, nil
		end
		return
	end
	if pulse and pulse.Parent == target then
		return
	end
	if pulse then
		pulse:Destroy()
	end
	pulse = Kit.frame({ Name = "TutorialPulse", Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), BackgroundColor3 = GOLD, BackgroundTransparency = 0.8, NoCorner = true, ZIndex = 30 })
	Kit.corner(10).Parent = pulse
	self.PulseStroke = Kit.new("UIStroke", { Color = GOLD, Thickness = 3, Parent = pulse })
	pulse.Parent = target
	self.Pulse = pulse
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
	-- an "open" goal only counts once its step is current (watching a battle by accident earlier must not skip a step)
	if t.Step ~= self.CountedStep then
		self.CountedStep = t.Step
		self.Opened_ = {}
		self.LoadoutAtStart = table.concat(player.Loadout or {}, ",") -- the "equip" step waits for this to change
	end
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
		local equipDone = false
		if def and def.Kind == "equip" then
			-- done once the equipped skills changed during this step, or when every owned skill is already equipped
			local equipped, spare = {}, false
			for _, id in ipairs(player.Loadout or {}) do
				equipped[id] = true
			end
			for id in pairs(player.Owned or {}) do
				if not equipped[id] then
					spare = true
				end
			end
			equipDone = table.concat(player.Loadout or {}, ",") ~= self.LoadoutAtStart or not spare
		end
		if def and ((def.Kind == "frontier" and frontier >= def.Goal) or (def.Kind == "open" and self.Opened_[def.Goal]) or equipDone) then
			self:_run(if t.Step >= #Tutorial.Steps then "TutorialComplete" else "TutorialAdvance", t.Step)
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
	self.Next.Visible = def.Kind == "next" or def.Go ~= nil
	self.Next.Text = def.GoText or "Next"
	local showBar = def.Kind == "frontier"
	self.Bar.Visible, self.BarText.Visible = showBar, showBar
	if showBar then
		local frac = math.clamp((frontier - 1) / math.max(def.Goal - 1, 1), 0, 1)
		self.Fill.Size = UDim2.fromScale(frac, 1)
		self.BarText.Text = ("Stage %d of %d"):format(math.min(frontier, def.Goal), def.Goal)
	end
	local lines = math.ceil(#def.Text / 32)
	self.Body.Size = UDim2.new(1, -28, 0, lines * 22)
	self.Card.Size = UDim2.fromOffset(WIDTH, 62 + lines * 22 + (if self.Next.Visible then 48 elseif showBar then 40 else 12))
	self.PointsAtButton = def.Kind == "open" or def.Kind == "equip"
	self:_slide(not hidden)
	self:_point(if hidden then nil elseif def.Target == "Go" then self.Next else targetOf(self.Hud, def.Target))
end

return TutorialUI
