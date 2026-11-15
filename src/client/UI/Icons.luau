--[[
	Icons (ModuleScript): small generated icons, no image assets.

	  Icons.SkillKind(def)                  -> "Damage"|"AoE"|"Heal"|"Shield"|"Revive"|"Taunt"|"Buff"
	  Icons.Skill(parent, def, props)       -> Frame: coloured tile + glyph, rarity border,
	                                           optional level badge. props: Size, Position, Level,
	                                           Locked (greys it out)
	  Icons.Ultimate(parent, def, props)    -> same look for a party ultimate
	  Icons.Item(parent, item, props)       -> tile for a gear piece (slot glyph, rarity/set border)
]]
local Statuses = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Statuses)
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
local KIND_GLYPHS = { Damage = "⚔", AoE = "💥", Heal = "💚", Shield = "🛡", Revive = "✨", Taunt = "📣", Buff = "▲", Ultimate = "★" }
local SLOT_GLYPHS = { Weapon = "⚔", Armor = "🛡", Helmet = "⛑", Pants = "👖", Boots = "👢", Ring = "💍", Amulet = "📿" }

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
		local status = Statuses[first.Status]
		if status and status.Flags and status.Flags.Taunting then
			return "Taunt"
		end
		for _, mod in ipairs(status and status.Mods or {}) do
			if mod.Stat == "Defense" or mod.Stat == "DamageTaken" or mod.Stat == "MaxHealth" then
				return "Shield"
			end
		end
		return "Buff"
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


-- every skill has its own glyph and colour so they can be told apart at a glance
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local SKILL_LOOK = {
	ShieldBash = { rgb(170, 120, 60), "🔨" }, Taunt = { rgb(150, 80, 60), "📣" }, IronSkin = { rgb(110, 120, 140), "⛓" },
	Whirlwind = { rgb(70, 150, 170), "🌀" }, ShieldWall = { rgb(60, 100, 180), "🧱" }, CrushingBlow = { rgb(160, 60, 50), "💢" },
	LastStand = { rgb(190, 90, 50), "💪" }, RallyingCry = { rgb(200, 150, 50), "🚩" }, Smite = { rgb(230, 200, 90), "⚡" },
	Heal = { rgb(60, 170, 100), "➕" }, Blessing = { rgb(220, 190, 120), "🙏" }, RadiantBurst = { rgb(240, 210, 110), "☀" },
	DivineShield = { rgb(110, 170, 230), "🔰" }, GroupHeal = { rgb(90, 190, 130), "💞" }, GuardianAngel = { rgb(200, 210, 240), "👼" },
	Judgment = { rgb(220, 180, 70), "⚖" }, Resurrection = { rgb(170, 230, 190), "🕊" }, Fireball = { rgb(220, 90, 40), "🔥" },
	Blizzard = { rgb(100, 180, 230), "❄" }, LightningBolt = { rgb(230, 220, 70), "🌩" }, ArcaneSurge = { rgb(150, 90, 210), "🔮" },
	BloodFrenzy = { rgb(170, 30, 50), "🩸" }, Cleave = { rgb(190, 90, 80), "🪓" }, ExecutionerStrike = { rgb(110, 40, 60), "☠" },
	Bulwark = { rgb(90, 110, 150), "🏰" }, Retribution = { rgb(210, 120, 60), "🔁" }, UnbreakableVow = { rgb(180, 170, 130), "💍" },
	Sanctuary = { rgb(120, 200, 190), "⛪" }, Renewal = { rgb(120, 200, 120), "🌿" }, HolyAegis = { rgb(150, 190, 240), "✝" },
	HolyWrath = { rgb(240, 170, 60), "✴" }, DivineSmite = { rgb(250, 230, 150), "🌟" }, SlimeSplit = { rgb(100, 200, 110), "🟢" },
	Enrage = { rgb(200, 50, 40), "😡" }, SporeBurst = { rgb(150, 120, 190), "🍄" }, SporeCall = { rgb(120, 150, 100), "🌱" },
}
function Icons.Skill(parent, def, props)
	local kind = Icons.SkillKind(def)
	local own = SKILL_LOOK[def.Id]
	return tile(parent, if own then own[1] else KIND_COLORS[kind], if own then own[2] else KIND_GLYPHS[kind], Kit.rarityColor(def.Rarity), props)
end

-- Passives: tinted by category, with a plain glyph. A nil def is an empty slot.
local PASSIVE_LOOK = {
	Damage = { Color3.fromRGB(190, 80, 70), "⚔" }, Defense = { Color3.fromRGB(80, 120, 190), "🛡" },
	Healing = { Color3.fromRGB(80, 170, 110), "✚" }, Gold = { Color3.fromRGB(200, 165, 60), "💰" },
	XP = { Color3.fromRGB(120, 100, 200), "★" }, Rarity = { Color3.fromRGB(190, 110, 170), "✦" },
}
function Icons.Passive(parent, def, props)
	local look = PASSIVE_LOOK[def and def.Category or ""] or { Color3.fromRGB(70, 74, 96), "+" }
	return tile(parent, look[1], look[2], if def then Color3.fromRGB(235, 225, 190) else Color3.fromRGB(110, 116, 140), props)
end

-- Pets: a tile tinted by the pet's colour with a glyph for its shape; border = rarity.
local PET_GLYPHS = { Ball = "●", Cat = "🦊", Wisp = "✦", Bunny = "🐰", Bird = "🐦", Turtle = "🐢", Drake = "🐉", Golem = "🗿" }
function Icons.Pet(parent, petId, props)
	local PetConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Pets)
	local def = PetConfig.Defs[petId]
	local look = def and def.Look or { Shape = "Ball", Color = { 120, 120, 130 } }
	local color = Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3])
	return tile(parent, color, PET_GLYPHS[look.Shape] or "●", Kit.rarityColor(def and def.Rarity), props)
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
