--[[
	SkillsScreen (ModuleScript): the Skills page, icons first.

	  SkillsScreen.Skills(container, state, call, extra)
	    extra.SkillSel   { Slot = n } an equipped skill is selected, or { Id = abilityId } one from the pool;
                     { PSlot = n } a passive slot, or { PId = passiveId, Target = slot } one from the passive pool
    Passives live here too: they are skills that are always on and do not use the four skill slots.

	Left   your PARTNER (you are not listed: your own stats are on the Hero screen), with their skills
	Centre your four equipped skills as icons (cast order, left to right), then icons of the skills you
	       have unlocked, then locked ones (dim) that can still be unlocked
	Right  the selected skill: everything about it, plus its actions (move, level up, equip, unlock)
	Needs a panel of about 640 x 304 (Main gives it that).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local UltCfg = require(Shared.Config.Ultimates)
local Classes = require(Shared.Config.Classes)
local Economy = require(Shared.Economy)
local Skills = require(Shared.Skills)
local Subclasses = require(Shared.Subclasses)
local PassiveCfg = require(Shared.Config.Passives)
local Passives = require(Shared.Passives)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local C = Kit.Colors

local SkillsScreen = {}

local LEFT, CENTRE, RIGHT = 130, 250, 232
local GAP = 6

local function panelFrame(parent, x, w)
	return Kit.frame({ Size = UDim2.new(0, w, 1, 0), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = Color3.fromRGB(30, 33, 50), Parent = parent })
end

-- A skill icon that can be clicked; the selected one gets a bright frame.
local function iconButton(parent, def, props, selected, onClick)
	local tile = if props.Passive ~= nil then Icons.Passive(parent, props.Passive or nil, props) else Icons.Skill(parent, def, props)
	local stroke = tile:FindFirstChildOfClass("UIStroke")
	if selected and stroke then
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
	end
	local button = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = tile })
	button.Activated:Connect(onClick)
	return tile
end

local function actionButton(parent, text, y, color, onClick)
	return Kit.button({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, y), Text = text, TextSize = 13, BackgroundColor3 = color or C.PanelLight, Parent = parent }, onClick)
end

function SkillsScreen.Skills(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local me = state.Player
	local equipped = table.clone(me.Loadout)
	local function redraw()
		SkillsScreen.Skills(container, state, call, extra)
	end

	-- default selection: your first equipped skill
	local sel = extra.SkillSel
	if not sel or (sel.Slot and not equipped[sel.Slot]) then
		sel = { Slot = 1 }
		extra.SkillSel = sel
	end
	local isPassive = sel.PSlot ~= nil or sel.PId ~= nil
	local pEquipped = table.clone(me.PassiveIds or {})
	local selectedId = if sel.Slot then equipped[sel.Slot] else sel.Id
	local selectedDef = selectedId and Abilities[selectedId]

	-- LEFT: the partner ------------------------------------------------------
	local left = panelFrame(container, 0, LEFT)
	Kit.label({ Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(6, 4), Text = "PARTY", TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, Parent = left })
	local partner = state.Party and state.Party.Partner
	if not partner then
		Kit.label({ Size = UDim2.new(1, -12, 0, 60), Position = UDim2.fromOffset(6, 24), Text = "No partner yet.\nOpen Party to invite one.", TextSize = 12, TextColor3 = C.Dim, Parent = left })
	else
		local dot = Kit.frame({ Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(6, 24), BackgroundColor3 = C[partner.ClassId] or C.Accent, Parent = left })
		Kit.corner(15).Parent = dot
		Kit.label({ Size = UDim2.fromScale(1, 1), Text = tostring(partner.Level), TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = C.Bg, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = dot })
		local classDef = Classes[partner.ClassId]
		Kit.label({ Size = UDim2.new(1, -44, 0, 16), Position = UDim2.fromOffset(40, 24), Text = partner.Name, TextSize = 12, Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = left })
		Kit.label({ Size = UDim2.new(1, -44, 0, 14), Position = UDim2.fromOffset(40, 40), Text = classDef and classDef.DisplayName or partner.ClassId, TextSize = 11, TextColor3 = C.Dim, TextWrapped = false, Parent = left })
		Kit.label({ Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 60), Text = if partner.IsCompanion then "Starter ghost" elseif partner.Online then "Online" else "Ghost (offline)", TextSize = 11, TextColor3 = if partner.Online then C.Good else C.Dim, TextWrapped = false, Parent = left })
		Kit.label({ Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 80), Text = "Their skills", TextSize = 11, TextColor3 = C.Dim, Parent = left })
		local grid = Kit.frame({ Size = UDim2.new(1, -12, 0, 100), Position = UDim2.fromOffset(6, 96), BackgroundTransparency = 1, NoCorner = true, Parent = left })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(52, 44), CellPadding = UDim2.fromOffset(4, 4), Parent = grid })
		for slot, id in ipairs(partner.GhostLoadout or {}) do
			local def = Abilities[id]
			if def then
				local tile = Icons.Skill(grid, def, { Level = partner.SlotLevels[slot] or 1 })
				Kit.Hover(tile, function() return Tips.Skill(def, partner.SlotLevels[slot] or 1) end)
			end
		end
		local ult = state.Party.Ultimate
		local ultDef = ult and ult.Chosen and UltCfg.Defs[ult.Chosen]
		if ultDef then
			local tile = Icons.Ultimate(left, ultDef, { Size = UDim2.fromOffset(52, 30), Position = UDim2.new(0, 6, 1, -36) })
			Kit.Hover(tile, function() return Tips.Ultimate(ultDef, 1) end)
			Kit.label({ Size = UDim2.new(1, -64, 0, 30), Position = UDim2.new(0, 62, 1, -36), Text = "Party ultimate", TextSize = 11, TextColor3 = C.Dim, Parent = left })
		end
	end

	-- CENTRE: equipped, unlocked, locked ----------------------------------------------
	local centre = panelFrame(container, LEFT + GAP, CENTRE)
	centre.BackgroundTransparency = 1
	Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, 0), Text = "EQUIPPED  (cast order)", TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, Parent = centre })
	for slot, id in ipairs(equipped) do
		local def = Abilities[id]
		if def then
			iconButton(centre, def, { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(2 + (slot - 1) * 62, 18), Level = me.SlotLevels[slot] }, sel.Slot == slot, function()
				extra.SkillSel = { Slot = slot }
				redraw()
			end)
			Kit.label({ Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(4 + (slot - 1) * 62, 18), Text = tostring(slot), TextSize = 10, TextWrapped = false, TextColor3 = C.Dim, ZIndex = 4, Parent = centre })
		end
	end

	-- subclass line
	local subY = 78
	if #(me.SubclassChoices or {}) > 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, subY), Text = "★ Choose your path (permanent this season)", TextSize = 11, TextColor3 = C.Accent, Font = Enum.Font.GothamBold, Parent = centre })
		for index, choice in ipairs(me.SubclassChoices) do
			local b = Kit.button({ Size = UDim2.new(0.5, -3, 0, 24), Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 3, 0, subY + 18), Text = choice.Name, TextSize = 12, BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = centre }, function()
				call("ChooseSubclass", choice.Id)
			end)
			Kit.Hover(b, function()
				return ("<b>%s</b>\n%s\n%s\n%s"):format(choice.Name, choice.Description, Kit.tint(choice.Summary, C.Dim), "New skills: " .. table.concat(choice.SkillNames, ", "))
			end)
		end
		subY += 46
	elseif me.SubclassId then
		local def = Subclasses.Defs[me.SubclassId]
		local l = Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, subY), Text = "Path: " .. def.DisplayName, TextSize = 11, TextColor3 = C.Accent, Parent = centre })
		Kit.Hover(l, function() return def.DisplayName .. "\n" .. Subclasses.Describe(me.SubclassId) end)
		subY += 20
	elseif me.SubclassUnlockLevel then
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, subY), Text = ("Reach level %d to choose a path"):format(me.SubclassUnlockLevel), TextSize = 11, TextColor3 = C.Dim, Parent = centre })
		subY += 20
	end

	-- passive slots: always-on skills that do not take a primary slot
	Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, subY), Text = "PASSIVES  (always on)", TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, Parent = centre })
	for slot = 1, Passives.SLOTS do
		local locked = slot > (me.PassiveSlots or 0)
		local pdef = not locked and PassiveCfg.Defs[pEquipped[slot]] or nil
		iconButton(centre, nil, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(2 + (slot - 1) * 50, subY + 16), Level = if pdef then (me.PassiveLevels or {})[slot] else nil, Locked = locked, Passive = pdef or false }, sel.PSlot == slot, function()
			extra.SkillSel = { PSlot = slot }
			redraw()
		end)
	end
	subY += 64

	local pool = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -subY), Position = UDim2.fromOffset(0, subY), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = centre,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = pool })
	local function section(text)
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = text, TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, Parent = pool })
	end
	local function iconGrid()
		local g = Kit.frame({ Size = UDim2.new(1, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, NoCorner = true, Parent = pool })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(44, 44), CellPadding = UDim2.fromOffset(6, 6), Parent = g })
		return g
	end

	local owned, locked = {}, {}
	for _, id in ipairs(Skills.Pool(me.ClassId, me.SubclassId)) do
		if Abilities[id] and not table.find(equipped, id) then
			table.insert(if me.Owned[id] then owned else locked, id)
		end
	end
	section("UNLOCKED")
	if #owned == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "Everything you own is equipped", TextSize = 11, TextColor3 = C.Dim, Parent = pool })
	else
		local g = iconGrid()
		for _, id in ipairs(owned) do
			iconButton(g, Abilities[id], {}, sel.Id == id, function()
				extra.SkillSel = { Id = id, Slot = nil, Target = sel.Slot or extra.SkillTarget }
				extra.SkillTarget = sel.Slot or extra.SkillTarget
				redraw()
			end)
		end
	end
	if #locked > 0 then
		section("LOCKED  (unlock with a pick or shards)")
		local g = iconGrid()
		for _, id in ipairs(locked) do
			iconButton(g, Abilities[id], { Locked = true }, sel.Id == id, function()
				extra.SkillSel = { Id = id }
				redraw()
			end)
		end
	end

	section("PASSIVES")
	do
		local g = iconGrid()
		local any = false
		for _, id in ipairs(Passives.Pool(me.ClassId)) do
			if not table.find(pEquipped, id) then
				any = true
				local pdef = PassiveCfg.Defs[id]
				local open = Passives.IsUnlocked(id, me.Frontier)
				iconButton(g, nil, { Passive = pdef, Locked = not open }, sel.PId == id, function()
					extra.SkillSel = { PId = id, Target = sel.PSlot or sel.Target }
					redraw()
				end)
			end
		end
		if not any then
			Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "Every passive is equipped", TextSize = 11, TextColor3 = C.Dim, Parent = g })
		end
	end

	-- RIGHT: the selected skill ---------------------------------------------------
	local right = panelFrame(container, LEFT + CENTRE + GAP * 2, RIGHT)
	if isPassive then
		local pdef, slot
		if sel.PSlot then
			slot = sel.PSlot
			pdef = if slot <= (me.PassiveSlots or 0) then PassiveCfg.Defs[pEquipped[slot]] else nil
		else
			pdef = PassiveCfg.Defs[sel.PId]
		end
		local function note(text, y)
			Kit.label({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 1, y), Text = text, TextSize = 11, TextColor3 = C.Dim, Parent = right })
		end
		if not pdef then
			local text = "Empty passive slot.\nPick an unlocked passive below to put in it."
			if slot and slot > (me.PassiveSlots or 0) then
				local unlock
				for _, u in ipairs(PassiveCfg.SlotUnlocks) do
					if u.Slots >= slot and not unlock then
						unlock = u.Stage
					end
				end
				text = ("Passive slot %d is locked.\nReach stage %s to open it."):format(slot, tostring(unlock or "?"))
			end
			Kit.label({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 8), Text = text, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
			return
		end
		local plevel = if slot then (me.PassiveLevels or {})[slot] or 1 else 1
		local lines = { Tips.Passive(pdef, plevel) }
		for _, r in ipairs(Passives.Rows(pdef.Id, plevel)) do
			table.insert(lines, Kit.tint(r.Label .. ": ", C.Dim) .. tostring(r.Value))
		end
		Kit.label({ Size = UDim2.new(1, -16, 1, -72), Position = UDim2.fromOffset(8, 6), Text = table.concat(lines, "\n"), RichText = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
		if slot then
			local cost = Economy.PassiveSlotLevelCost(plevel)
			actionButton(right, cost and ("Level up  -  " .. cost .. "g") or "Max level", 0, C.Up, function()
				if cost then
					call("LevelPassiveSlot", slot)
				end
			end).Position = UDim2.new(0, 8, 1, -66)
			note("Tap an unlocked passive to swap it in for this one.", -32)
		elseif Passives.IsUnlocked(pdef.Id, me.Frontier) then
			local target = math.clamp(sel.Target or (#pEquipped + 1), 1, math.min(#pEquipped + 1, math.max(me.PassiveSlots or 1, 1)))
			local swapOut = PassiveCfg.Defs[pEquipped[target]]
			actionButton(right, ("Equip in passive slot %d"):format(target), 0, C.Up, function()
				pEquipped[target] = pdef.Id
				extra.SkillSel = { PSlot = target }
				call("EquipPassives", pEquipped)
			end).Position = UDim2.new(0, 8, 1, -66)
			note(swapOut and ("Replaces " .. swapOut.DisplayName .. ". Select a passive slot first to choose which.") or "Goes in the first free slot.", -34)
		else
			note(("Unlocks when you reach stage %d."):format(pdef.UnlockStage or 1), -48)
		end
		return
	end
	if not selectedDef then
		Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 8), Text = "Pick a skill to see its details.", TextColor3 = C.Dim, Parent = right })
		return
	end
	local isEquipped = sel.Slot ~= nil
	local isOwned = me.Owned[selectedId] == true
	local level = if isEquipped then me.SlotLevels[sel.Slot] else 1
	local text = Tips.Skill(selectedDef, level)
	Kit.label({ Size = UDim2.new(1, -16, 1, -104), Position = UDim2.fromOffset(8, 6), Text = text, RichText = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })

	if isEquipped then
		local slot = sel.Slot
		local cost = Economy.SlotLevelCost(me.SlotLevels[slot])
		local lvl = actionButton(right, cost and ("Level up  -  " .. cost .. "g") or "Max level", 0, C.Up, function()
			if cost then
				call("LevelSlot", slot)
			end
		end)
		lvl.Position = UDim2.new(0, 8, 1, -100)
		local left2 = Kit.button({ Size = UDim2.new(0.5, -12, 0, 30), Position = UDim2.new(0, 8, 1, -66), Text = "◀ Earlier", TextSize = 12, Parent = right }, function()
			if slot > 1 then
				equipped[slot], equipped[slot - 1] = equipped[slot - 1], equipped[slot]
				extra.SkillSel = { Slot = slot - 1 }
				call("EquipSkills", equipped)
			end
		end)
		local right2 = Kit.button({ Size = UDim2.new(0.5, -12, 0, 30), Position = UDim2.new(0.5, 4, 1, -66), Text = "Later ▶", TextSize = 12, Parent = right }, function()
			if slot < #equipped then
				equipped[slot], equipped[slot + 1] = equipped[slot + 1], equipped[slot]
				extra.SkillSel = { Slot = slot + 1 }
				call("EquipSkills", equipped)
			end
		end)
		left2.Active = slot > 1
		right2.Active = slot < #equipped
		Kit.label({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -32), Text = "Tap an unlocked skill to swap it in for this one.", TextSize = 11, TextColor3 = C.Dim, Parent = right })
	elseif isOwned then
		local target = sel.Target or #equipped
		target = math.clamp(target, 1, #equipped)
		local swapOut = Abilities[equipped[target]]
		actionButton(right, ("Equip in slot %d"):format(target), 0, C.Up, function()
			equipped[target] = selectedId
			extra.SkillSel = { Slot = target }
			call("EquipSkills", equipped)
		end).Position = UDim2.new(0, 8, 1, -66)
		Kit.label({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 1, -34), Text = swapOut and ("Replaces " .. swapOut.DisplayName .. ". Select an equipped icon first to choose the slot.") or "", TextSize = 11, TextColor3 = C.Dim, Parent = right })
	else
		local picks = me.SkillPicks or 0
		actionButton(right, ("Unlock with a pick  (%d)"):format(picks), 0, C.Up, function()
			call("UnlockSkillWithPick", selectedId)
		end).Position = UDim2.new(0, 8, 1, -100)
		actionButton(right, "Unlock with shards", 0, C.PanelLight, function()
			call("UnlockSkill", selectedId)
		end).Position = UDim2.new(0, 8, 1, -66)
		Kit.label({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -32), Text = ("You have %d shards."):format(me.Shards or 0), TextSize = 11, TextColor3 = C.Dim, Parent = right })
	end
end

return SkillsScreen
