--[[
	Kit (ModuleScript) - tiny helpers for building UI in code, plain Roblox
	parts only (no image assets). Reference frame is 844x390; Main scales it.
]]
local Kit = {}

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
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Warrior = Color3.fromRGB(220, 110, 80),
	Cleric = Color3.fromRGB(240, 220, 130),
}

function Kit.new(className, props, children)
	local inst = Instance.new(className)
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

return Kit
