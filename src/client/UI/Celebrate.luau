--[[
	Celebrate (ModuleScript): a big centred moment that shows in the town and in battle alike (the HUD toast and banner
	only show while watching a fight). Used for level-ups and finished errands.

	  Celebrate.Show(root, title, subtitle, color)   root = the main UI frame; the card pops, glows, then fades
	  Celebrate.Sparkle()                             a burst of sparkles round the player's character
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Celebrate = {}

local active = nil

function Celebrate.Show(root, title, subtitle, color)
	if active then
		active:Destroy()
	end
	color = color or Color3.fromRGB(255, 214, 90)
	local holder = Instance.new("Frame")
	holder.Name = "Celebration"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromOffset(460, 110)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 40
	holder.Parent = root
	active = holder
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = holder
	-- a soft glow behind the words
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.1, 1)
	glow.BackgroundColor3 = Color3.fromRGB(20, 16, 40)
	glow.BackgroundTransparency = 0.25
	glow.ZIndex = 40
	glow.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = glow
	local big = Instance.new("TextLabel")
	big.Size = UDim2.new(1, 0, 0, 62)
	big.Position = UDim2.fromOffset(0, 8)
	big.BackgroundTransparency = 1
	big.Text = title
	big.TextColor3 = color
	big.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
	big.TextStrokeTransparency = 0
	big.Font = Enum.Font.GothamBlack
	big.TextScaled = true
	big.ZIndex = 41
	big.Parent = holder
	local small = Instance.new("TextLabel")
	small.Size = UDim2.new(1, -20, 0, 30)
	small.Position = UDim2.fromOffset(10, 72)
	small.BackgroundTransparency = 1
	small.Text = subtitle or ""
	small.TextColor3 = Color3.new(1, 1, 1)
	small.TextStrokeTransparency = 0.4
	small.Font = Enum.Font.GothamBold
	small.TextSize = 18
	small.TextWrapped = true
	small.ZIndex = 41
	small.Parent = holder
	-- a long subtitle wraps: grow the card so the second line is not cut off (the all-relics line was)
	local okSize, bounds = pcall(function()
		return game:GetService("TextService"):GetTextSize(small.Text, 18, Enum.Font.GothamBold, Vector2.new(440, 1000))
	end)
	if okSize and bounds.Y > 30 then
		small.Size = UDim2.new(1, -20, 0, bounds.Y + 4)
		holder.Size = UDim2.fromOffset(460, 80 + bounds.Y + 8)
	end
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3.2, function()
		if active ~= holder then
			return
		end
		local info = TweenInfo.new(0.6)
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(scale, info, { Scale = 1.15 }):Play()
		task.delay(0.7, function()
			holder:Destroy()
			if active == holder then
				active = nil
			end
		end)
	end)
end

-- a burst of little stars from the mouse (or the middle of the screen), for claiming and buying things
local burstGui = nil
function Celebrate.Burst(color, count)
	local UserInputService = game:GetService("UserInputService")
	if not burstGui or not burstGui.Parent then
		burstGui = Instance.new("ScreenGui")
		burstGui.Name = "IdlePartyBursts"
		burstGui.IgnoreGuiInset = true
		burstGui.ResetOnSpawn = false
		burstGui.DisplayOrder = 80
		burstGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	local at = UserInputService:GetMouseLocation()
	if at.Magnitude < 1 then
		local cam = workspace.CurrentCamera
		at = cam and cam.ViewportSize / 2 or Vector2.new(400, 300)
	end
	color = color or Color3.fromRGB(255, 214, 90)
	for i = 1, count or 14 do
		local star = Instance.new("TextLabel")
		star.BackgroundTransparency = 1
		star.Text = if i % 3 == 0 then "✨" else "★"
		star.TextColor3 = if i % 2 == 0 then color else Color3.new(1, 1, 1)
		star.TextStrokeTransparency = 0.5
		star.Font = Enum.Font.GothamBlack
		star.TextSize = 22 + (i % 4) * 6
		star.Size = UDim2.fromOffset(44, 44)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromOffset(at.X, at.Y)
		star.Parent = burstGui
		local a = (i / (count or 14)) * math.pi * 2 + math.random() * 0.4
		local dist = 70 + math.random() * 90
		local info = TweenInfo.new(0.6 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(star, info, { Position = UDim2.fromOffset(at.X + math.cos(a) * dist, at.Y + math.sin(a) * dist - 20), TextTransparency = 1, TextStrokeTransparency = 1, Rotation = math.random(-90, 90) }):Play()
		Debris:AddItem(star, 1)
	end
end

function Celebrate.Sparkle(color)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local at = Instance.new("Attachment")
	at.Parent = root
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 255, 255))
	burst.LightEmission = 1
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -10, 0)
	burst.Rate = 0
	burst.Parent = at
	burst:Emit(60)
	-- a rising ring of light
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = color or Color3.fromRGB(255, 220, 110)
	beam.Transparency = 0.3
	beam.Size = Vector3.new(0.3, 4, 4)
	beam.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(1.1), { Size = Vector3.new(0.3, 14, 14), Transparency = 1, CFrame = beam.CFrame + Vector3.new(0, 6, 0) }):Play()
	Debris:AddItem(beam, 1.2)
	Debris:AddItem(at, 2)
end

return Celebrate
