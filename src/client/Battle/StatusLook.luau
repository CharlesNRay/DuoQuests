--[[
	StatusLook (ModuleScript): how each status looks in battle: its kind, colour and glyph. Used by the health bar pips,
	the model tint and the apply / expire effects.

	  StatusLook.Of(statusId) -> { Kind = "Shield" | "Buff" | "Debuff" | "Dot" | "Cc", Color, Glyph }
	Kinds: Shield (soaks damage, blue bubble), Buff (gold / themed, rising arrows), Debuff (purple / themed, falling arrows),
	Dot (damage over time: burn, poison, bleed), Cc (stun, freeze).
]]
local Statuses = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Statuses)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local StatusLook = {}

local LOOK = {
	Burning = { "Dot", rgb(255, 130, 50), "🔥" }, Poisoned = { "Dot", rgb(130, 225, 90), "☠" }, Bleeding = { "Dot", rgb(225, 55, 65), "🩸" },
	Chilled = { "Debuff", rgb(130, 210, 255), "❄" }, Snared = { "Debuff", rgb(190, 150, 95), "⛓" }, Marked = { "Debuff", rgb(255, 95, 95), "🎯" },
	Cursed = { "Debuff", rgb(175, 95, 225), "💀" }, Shadowed = { "Debuff", rgb(120, 100, 170), "🌑" },
	Frozen = { "Cc", rgb(175, 230, 255), "❄" }, Stunned = { "Cc", rgb(255, 235, 90), "💫" },
	Taunting = { "Buff", rgb(240, 120, 80), "📣" }, Fortified = { "Buff", rgb(120, 160, 230), "🛡" }, IronSkin = { "Buff", rgb(150, 165, 195), "🛡" },
	Unbreakable = { "Buff", rgb(110, 170, 240), "🛡" }, LastStand = { "Buff", rgb(235, 110, 70), "💪" }, GuardianAngel = { "Buff", rgb(255, 245, 200), "✨" },
	Rallied = { "Buff", rgb(250, 200, 80), "🚩" }, Blessed = { "Buff", rgb(255, 235, 150), "✨" }, ArcaneSurge = { "Buff", rgb(170, 110, 235), "🔮" },
	Frenzied = { "Buff", rgb(235, 70, 80), "💢" }, Enraged = { "Buff", rgb(235, 70, 60), "💢" }, Hasted = { "Buff", rgb(120, 225, 235), "💨" },
	Evasive = { "Buff", rgb(110, 215, 190), "🌀" }, DeadEye = { "Buff", rgb(245, 185, 70), "🎯" }, Emboldened = { "Buff", rgb(245, 150, 70), "⚔" },
}

local SHIELD = { "Shield", rgb(90, 175, 255), "🛡" }

function StatusLook.Of(statusId)
	local def = Statuses[statusId]
	if def and def.Flags and def.Flags.Absorb then
		return { Kind = SHIELD[1], Color = SHIELD[2], Glyph = SHIELD[3] }
	end
	local own = LOOK[statusId]
	if own then
		return { Kind = own[1], Color = own[2], Glyph = own[3] }
	end
	if def and def.Dot then
		return { Kind = "Dot", Color = rgb(230, 120, 80), Glyph = "☠" }
	end
	return { Kind = "Buff", Color = rgb(245, 205, 90), Glyph = "▲" }
end

-- a damage-over-time tag (e.g. "Burning") -> its look, or nil for anything else
function StatusLook.DotTag(tag)
	local own = tag and LOOK[tag]
	if own and own[1] == "Dot" then
		return { Kind = own[1], Color = own[2], Glyph = own[3] }
	end
	return nil
end

return StatusLook
