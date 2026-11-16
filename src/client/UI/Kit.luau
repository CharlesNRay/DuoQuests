--[[
	Kit (ModuleScript) - tiny helpers for building UI in code, plain Roblox
	parts only (no image assets). Reference size is Kit.RefW x Kit.RefH; Main scales it and stretches the root to fill the screen.
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

-- Design size the UI is laid out for; the real screen is filled by stretching the root (see Main).
Kit.RefW = 860
Kit.RefH = 400

Kit.Colors = {
	Bg = Color3.fromRGB(24, 26, 38),
	Panel = Color3.fromRGB(38, 42, 60),
	PanelLight = Color3.fromRGB(54, 60, 84),
	Text = Color3.fromRGB(235, 238, 248),
	Dim = Color3.fromRGB(150, 158, 185),
	Accent = Color3.fromRGB(255, 196, 70),
	Good = Color3.fromRGB(96, 214, 130),
	Bad = Color3.fromRGB(235, 90, 90),
	Common = Color3.fromRGB(170, 176, 190),
	Uncommon = Color3.fromRGB(96, 214, 130),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 176, 48),
	Set = Color3.fromRGB(255, 150, 60),
	Up = Color3.fromRGB(36, 84, 52),
	Down = Color3.fromRGB(98, 40, 44),
	Warrior = Color3.fromRGB(220, 110, 80),
	Cleric = Color3.fromRGB(240, 220, 130),
	Mage = Color3.fromRGB(130, 130, 240),
	Ranger = Color3.fromRGB(110, 190, 100),
	Rogue = Color3.fromRGB(150, 110, 200),
	Summoner = Color3.fromRGB(100, 215, 195),
}

-- Lists sort by LayoutOrder, which defaults to 0 for everything, so every GUI object we make gets an
-- increasing LayoutOrder unless the caller sets one: lists then follow the order we wrote the code.
local orderCounter = 0

function Kit.new(className, props, children)
	local inst = Instance.new(className)
	if className == "UIListLayout" or className == "UIGridLayout" then
		-- Instance.new defaults these to SortOrder.Name (alphabetical by class!), not LayoutOrder
		inst.SortOrder = Enum.SortOrder.LayoutOrder
	end
	if inst:IsA("GuiObject") and (props == nil or props.LayoutOrder == nil) then
		orderCounter += 1
		inst.LayoutOrder = orderCounter
	end
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

function Kit.corner(radius)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Kit.frame(props, children)
	local p = { BackgroundColor3 = Kit.Colors.Panel, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do
		if k ~= "NoCorner" then
			p[k] = v
		end
	end
	local f = Kit.new("Frame", p, children)
	if props == nil or props.NoCorner ~= true then
		Kit.corner(8).Parent = f
	end
	return f
end

function Kit.label(props)
	local p = {
		BackgroundTransparency = 1,
		TextColor3 = Kit.Colors.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return Kit.new("TextLabel", p)
end

-- Button with a callback. Minimum touch size is the caller's job (>= 44).
function Kit.button(props, onClick)
	local p = {
		BackgroundColor3 = Kit.Colors.PanelLight,
		TextColor3 = Kit.Colors.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = Kit.new("TextButton", p)
	Kit.corner(8).Parent = b
	-- chunky cartoon-RPG look: a soft top-to-bottom shade and a dark rim, like the buttons in Go Go Muffin
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 192, 205)), Rotation = 90, Parent = b })
	Kit.new("UIStroke", { Color = Color3.fromRGB(14, 16, 26), Thickness = 1.5, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function Kit.clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function Kit.rarityColor(rarity)
	return Kit.Colors[rarity] or Kit.Colors.Common
end

function Kit.hex(color)
	return "#" .. color:ToHex()
end

-- Rich-text colour wrapper
function Kit.tint(text, color)
	return ('<font color="%s">%s</font>'):format(Kit.hex(color), text)
end

-- Tooltips ----------------------------------------------------------------
-- Kit.SetupTooltips(root, uiScale) once; then Kit.Hover(guiObject, function() return richText end).
-- Mouse: follows the cursor. Touch: tap shows it for a couple of seconds.
local tip = nil

function Kit.SetupTooltips(root, uiScale)
	local frame = Kit.frame({
		Name = "Tooltip", Size = UDim2.fromOffset(236, 20), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(12, 14, 24), BackgroundTransparency = 0.04, Visible = false, ZIndex = 100, Active = false, Parent = root,
	})
	Kit.new("UIStroke", { Color = Color3.fromRGB(120, 128, 160), Thickness = 1, Parent = frame })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = frame })
	local label = Kit.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, RichText = true, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 101, Parent = frame })
	tip = { Root = root, Scale = uiScale, Frame = frame, Label = label, Owner = nil, At = nil }
	RunService.Heartbeat:Connect(function()
		if not tip.Frame.Visible then
			return
		end
		local s = math.max(0.01, tip.Scale.Scale)
		local anchor
		if tip.At then
			anchor = tip.At
		else
			anchor = (UserInputService:GetMouseLocation() - root.AbsolutePosition) / s + Vector2.new(14, 16)
		end
		local size = tip.Frame.AbsoluteSize / s
		local rootSize = root.AbsoluteSize / s
		local x = math.clamp(anchor.X, 4, math.max(4, rootSize.X - size.X - 4))
		local y = anchor.Y
		if y + size.Y > rootSize.Y - 4 then
			y = math.max(4, anchor.Y - size.Y - 28)
		end
		tip.Frame.Position = UDim2.fromOffset(x, y)
	end)
end

local function showTip(owner, text, at)
	if not tip or text == nil or text == "" then
		return
	end
	tip.Owner = owner
	tip.At = at
	tip.Label.Text = text
	tip.Frame.Visible = true
end

local function hideTip(owner)
	if tip and (owner == nil or tip.Owner == owner) then
		tip.Frame.Visible = false
		tip.Owner = nil
		tip.At = nil
	end
end

function Kit.HideTip()
	hideTip(nil)
end

function Kit.Hover(inst, getText)
	inst.MouseEnter:Connect(function()
		showTip(inst, getText())
	end)
	inst.MouseLeave:Connect(function()
		hideTip(inst)
	end)
	inst.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and tip then
			local s = math.max(0.01, tip.Scale.Scale)
			local at = (inst.AbsolutePosition - tip.Root.AbsolutePosition) / s + Vector2.new(0, inst.AbsoluteSize.Y / s + 4)
			showTip(inst, getText(), at)
			task.delay(2.8, function()
				hideTip(inst)
			end)
		end
	end)
	inst.Destroying:Connect(function()
		hideTip(inst)
	end)
end

return Kit
