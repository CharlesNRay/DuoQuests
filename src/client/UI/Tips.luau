--[[
	Tips (ModuleScript): rich-text tooltip bodies for skills, items, passives and ultimates.
	Kit.Hover(gui, function() return Tips.Skill(def, level) end)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityStats = require(Shared.Combat.AbilityStats)
local Gear = require(Shared.Gear)
local Power = require(Shared.Power)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local C = Kit.Colors

local Tips = {}

local KIND_NAMES = { Damage = "Attack", AoE = "Area attack", Heal = "Healing", Shield = "Protection", Revive = "Revival", Taunt = "Taunt", Buff = "Buff", Ultimate = "Party ultimate" }

local function dim(text)
	return Kit.tint(text, C.Dim)
end

function Tips.Skill(def, level, tier)
	local lines = {}
	table.insert(lines, ("<b>%s</b>%s"):format(Kit.tint(def.DisplayName, Kit.rarityColor(def.Rarity)), level and ("   Lv " .. level) or ""))
	local kind = Icons.SkillKind(def)
	local meta = KIND_NAMES[kind] .. "  -  " .. (def.Rarity or "Common")
	table.insert(lines, dim(meta))
	if level then
		table.insert(lines, Kit.tint(("IP %d"):format(Power.Skill(tier or def.Rarity or "Common", level)), C.Accent))
	end
	if def.Description and def.Description ~= "" then
		table.insert(lines, def.Description)
	end
	for _, r in ipairs(AbilityStats.Rows(def, level or 1)) do
		table.insert(lines, dim(r.Label .. ": ") .. r.Value)
	end
	if def.UsesPerCombat then
		table.insert(lines, dim(("Usable %d time per fight"):format(def.UsesPerCombat)))
	end
	table.insert(lines, dim("Skills cast in slot order as soon as they are ready."))
	return table.concat(lines, "\n")
end

function Tips.Ultimate(def, level)
	local lines = { ("<b>%s</b>"):format(Kit.tint(def.DisplayName, Kit.rarityColor(def.Rarity))), dim("Party ultimate - fires on its own when the gauge is full"), def.Description or "" }
	for _, r in ipairs(AbilityStats.Rows(def, level or 1)) do
		table.insert(lines, dim(r.Label .. ": ") .. r.Value)
	end
	return table.concat(lines, "\n")
end

function Tips.Passive(def, level)
	return ("<b>%s</b>%s\n%s\n%s"):format(def.DisplayName, level and ("   Lv " .. level) or "", dim(def.Category or ""), def.Description or "")
end

local function num(value)
	if value < 10 then
		return ("%.1f"):format(value)
	end
	return tostring(math.floor(value + 0.5))
end
Tips.Num = num

-- How an item compares to what is worn in its slot. Verdict: "Up" | "Down" | "Same".
-- gear = state.Player.Gear (has Equipped and Sets).
function Tips.Compare(item, gear)
	local worn = Gear.Replaced(gear.Equipped, item.Slot)
	for _, w in pairs(gear.Equipped) do
		if w.Id == item.Id then
			return { Verdict = "Worn", Delta = 0 }
		end
	end
	if worn and worn.Id == item.Id then
		return { Verdict = "Worn", Delta = 0 }
	end
	local delta = item.Value - (worn and worn.Value or 0)
	local setGain, setLoss = nil, nil
	for _, set in ipairs(gear.Sets or {}) do
		local before = set.Worn
		local after = before
		if item.SetId == set.Id then
			after += 1
			if worn and worn.SetId == set.Id then
				after -= 1
			end
		elseif worn and worn.SetId == set.Id then
			after -= 1
		end
		if after > before and (after == (set.Need1 or 2) or after == (set.Need2 or 4)) then
			setGain = { Set = set, Count = after }
		elseif after < before and (before == (set.Need1 or 2) or before == (set.Need2 or 4)) then
			setLoss = { Set = set, Count = before }
		end
	end
	local verdict = "Same"
	if setGain and delta > -0.05 then
		verdict = "Up"
	elseif delta > 0.05 then
		verdict = if setLoss then "Same" else "Up"
	elseif delta < -0.05 then
		verdict = if setGain then "Same" else "Down"
	elseif setLoss then
		verdict = "Down"
	end
	return { Verdict = verdict, Delta = delta, SetGain = setGain, SetLoss = setLoss, Worn = worn }
end

function Tips.Item(item, gear)
	local cmp = Tips.Compare(item, gear)
	local rarity = if item.SetId then "Set" else item.Rarity
	local lines = { ("<b>%s</b>"):format(Kit.tint(item.Name, Kit.rarityColor(rarity))), dim(("%s  -  %s  -  from stage %d"):format(item.Slot, if item.SetId then "Set piece" else item.Rarity, item.Power)), Kit.tint(("IP %d"):format(item.ItemPower or 0), C.Accent) .. dim(("   Roll %d%%"):format(math.floor((item.Roll or 1) * 100 + 0.5))) }
	table.insert(lines, item.StatText or Gear.FormatStat(item.Stat, item.Value))
	if cmp.Verdict == "Worn" then
		table.insert(lines, dim("Currently worn"))
	else
		local worn = cmp.Worn
		if worn then
			local color = if cmp.Delta > 0.05 then C.Good elseif cmp.Delta < -0.05 then C.Bad else C.Dim
			local deltaText = Gear.FormatStat(item.Stat, math.abs(cmp.Delta)):gsub("^%+", if cmp.Delta < 0 then "-" else "+")
			table.insert(lines, Kit.tint(("%s compared to your %s"):format(deltaText, worn.Name), color))
		else
			table.insert(lines, Kit.tint(("Empty slot: %s"):format(item.StatText or Gear.FormatStat(item.Stat, item.Value)), C.Good))
		end
		if cmp.SetGain then
			table.insert(lines, Kit.tint(("Gains the %d-piece bonus of %s"):format(cmp.SetGain.Count, cmp.SetGain.Set.Name), C.Good))
		end
		if cmp.SetLoss then
			table.insert(lines, Kit.tint(("Loses the %d-piece bonus of %s"):format(cmp.SetLoss.Count, cmp.SetLoss.Set.Name), C.Bad))
		end
	end
	if item.SetId then
		for _, set in ipairs(gear.Sets or {}) do
			if set.Id == item.SetId then
				table.insert(lines, Kit.tint(("%s  (%d worn)"):format(set.Name, set.Worn), C.Set))
				table.insert(lines, dim(("%d pieces: "):format(set.Need1 or 2)) .. set.Bonus2)
				table.insert(lines, dim(("%d pieces: "):format(set.Need2 or 4)) .. set.Bonus3)
			end
		end
	end
	table.insert(lines, dim("Sells for " .. item.SellValue .. " gold"))
	return table.concat(lines, "\n")
end

return Tips
