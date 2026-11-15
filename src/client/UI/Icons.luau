--[[
	Icons (ModuleScript): small generated icons, no image assets.

	  Icons.SkillKind(def)                  -> "Damage"|"AoE"|"Heal"|"Shield"|"Revive"|"Taunt"|"Buff"
	  Icons.Skill(parent, def, props)       -> Frame: coloured tile + glyph, rarity border,
	                                           optional level badge. props: Size, Position, Level,
	                                           Locked (greys it out)
	  Icons.Ultimate(parent, def, props)    -> same look for a party ultimate
	  Icons.Item(parent, item, props)       -> tile for a gear piece (slot glyph, rarity/set border)
]]
local Kit = require(script.Parent.Kit)

local Icons = {}

local KIND_COLORS = {
	Damage = Color3.fromRGB(176, 66, 60),
	AoE = Color3.fromRGB(206, 108, 48),
	Heal = Color3.fromRGB(56, 156, 98),
	Shield = Color3.fromRGB(58, 108, 190),
	Revive = Color3.fromRGB(190, 176, 100),
	Taunt = Color3.fromRGB(140, 86, 60),
	Buff = Color3.fromRGB(160, 130, 48),
	Ultimate = Color3.fromRGB(120, 70, 190),
}
local KIND_GLYPHS = { Damage = "⚔", AoE = "✹", Heal = "✚", Shield = "⛨", Revive = "✦", Taunt = "!", Buff = "▲", Ultimate = "★" }
local SLOT_GLYPHS = { Weapon = "⚔", Armor = "⛨", Trinket = "✦" }

function Icons.SkillKind(def)
	local first = def.Effects and def.Effects[1]
	if not first then
		return "Buff"
	end
	local kind = first.Type
	if kind == "Damage" then
		return if first.Target == "AllEnemies" then "AoE" else "Damage"
	elseif kind == "Heal" then
		return "Heal"
	elseif kind == "Shield" then
		return "Shield"
	elseif kind == "Revive" then
		return "Revive"
	elseif kind == "ApplyStatus" then
		return if first.Status == "Taunt" then "Taunt" else "Buff"
	end
	return "Buff"
end

function Icons.KindColor(kind)
	return KIND_COLORS[kind] or KIND_COLORS.Buff
end

local function tile(parent, color, glyph, border, props)
	props = props or {}
	local f = Kit.frame({
		Size = props.Size or UDim2.fromOffset(40, 40), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = if props.Locked then Color3.fromRGB(60, 62, 74) else color, LayoutOrder = props.LayoutOrder or 0, Parent = parent,
	})
	Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = f })
	Kit.new("UIStroke", { Color = border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	Kit.label({
		Size = UDim2.fromScale(1, 1), Text = glyph, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack,
		TextScaled = true, TextTransparency = if props.Locked then 0.5 else 0, Parent = f,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 8, Parent = f:FindFirstChildOfClass("TextLabel") })
	if props.Level then
		Kit.label({
			Size = UDim2.fromOffset(22, 14), Position = UDim2.new(1, -22, 1, -14), Text = tostring(props.Level), TextSize = 11,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 2, Parent = f,
		})
	end
	return f
end

function Icons.Skill(parent, def, props)
	local kind = Icons.SkillKind(def)
	return tile(parent, KIND_COLORS[kind], KIND_GLYPHS[kind], Kit.rarityColor(def.Rarity), props)
end

function Icons.Ultimate(parent, def, props)
	return tile(parent, KIND_COLORS.Ultimate, KIND_GLYPHS.Ultimate, Kit.rarityColor(def and def.Rarity or "Epic"), props)
end

function Icons.Item(parent, item, props)
	local color = Kit.Colors.PanelLight
	local border = if item.SetId then Kit.Colors.Set else Kit.rarityColor(item.Rarity)
	return tile(parent, color, SLOT_GLYPHS[item.Slot] or "?", border, props)
end

return Icons
