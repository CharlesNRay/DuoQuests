--[[
	SkillsScreen (ModuleScript): the Skills page, icons first.

	  SkillsScreen.Skills(container, state, call, extra)
	    extra.SkillSel   { Slot = n } an equipped skill is selected, or { Id = abilityId } one from the pool;
                     { PSlot = n } a passive slot, or { PId = passiveId, Target = slot } one from the passive pool
    Passives live here too: they are skills that are always on and do not use the four skill slots.

	Tabs   You / Partner. The partner tab edits their ghost skills (reorder, swap in skills they own).
	Left   the four equipped skills (cast order, left to right; DRAG to reorder, or drag a skill from the
	       pool onto a slot), passive slots, then a scrolling pool of unlocked and locked skills
	Right  the selected skill: everything about it, plus its actions (level up, equip, unlock)
	Needs a panel of about 640 x 320 (Main gives it that).
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
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local SkillsScreen = {}

local MAIN_W, DETAIL_W = 388, 232
local GAP = 6

local function panelFrame(parent, x, w)
	return Kit.frame({ Size = UDim2.new(0, w, 1, 0), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = Color3.fromRGB(30, 33, 50), Parent = parent })
end

local lastDragEnd = 0

-- Makes an icon tile clickable and draggable. onDrop(pointer) is called with the pointer in screen
-- space when a drag ends; a click (no real movement) calls onClick.
local function attach(tile, def, selected, onClick, drag, makeGhost)
	local stroke = tile:FindFirstChildOfClass("UIStroke")
	if selected and stroke then
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
	end
	local button = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = tile })
	button.Activated:Connect(function()
		if os.clock() - lastDragEnd > 0.25 then
			onClick()
		end
	end)
	if not drag then
		return
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local function pointerOf(i)
			return Vector2.new(i.Position.X, i.Position.Y) + GuiService:GetGuiInset()
		end
		local start = pointerOf(input)
		local ghost
		local root = tile:FindFirstAncestor("Root")
		local uiScale = root and root:FindFirstChildOfClass("UIScale")
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local pointer = pointerOf(i)
			if not ghost and root and (pointer - start).Magnitude > 8 then
				ghost = if makeGhost then makeGhost(root) else Icons.Skill(root, def, { Size = UDim2.fromOffset(52, 52) })
				ghost.ZIndex = 50
				for _, d in ipairs(ghost:GetDescendants()) do
					if d:IsA("GuiObject") then
						d.ZIndex = 51
					end
				end
				ghost.BackgroundTransparency = 0.15
				tile.BackgroundTransparency = 0.6
			end
			if ghost then
				local s = uiScale and uiScale.Scale or 1
				ghost.Position = UDim2.fromOffset((pointer - root.AbsolutePosition).X / s - 26, (pointer - root.AbsolutePosition).Y / s - 26)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			moveConn:Disconnect()
			endConn:Disconnect()
			if ghost then
				ghost:Destroy()
				lastDragEnd = os.clock()
				if tile.Parent then
					tile.BackgroundTransparency = 0
				end
				drag(pointerOf(i))
			end
		end)
	end)
end

local function actionButton(parent, text, y, color, onClick)
	return Kit.button({ Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, y), Text = text, TextSize = 13, BackgroundColor3 = color or C.PanelLight, Parent = parent }, onClick)
end

local function inside(frame, point)
	if not (frame and frame.Parent) then
		return false
	end
	local p, sz = frame.AbsolutePosition, frame.AbsoluteSize
	-- AbsolutePosition ignores the top inset; pointers here include it
	local inset = GuiService:GetGuiInset()
	p += inset
	return point.X >= p.X and point.X <= p.X + sz.X and point.Y >= p.Y and point.Y <= p.Y + sz.Y
end

local function note(parent, text, y, h)
	Kit.label({ Size = UDim2.new(1, -16, 0, h or 26), Position = UDim2.new(0, 8, 1, y), Text = text, TextSize = 11, TextColor3 = C.Dim, Parent = parent })
end

function SkillsScreen.Skills(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local me = state.Player
	local partner = state.Party and state.Party.Partner
	local tab = extra.SkillsTab or "You"
	if tab == "Partner" and not partner then
		tab = "You"
	end
	local isPartner = tab == "Partner"
	local function redraw()
		SkillsScreen.Skills(container, state, call, extra)
	end

	-- tabs
	for index, name in ipairs({ "You", "Partner" }) do
		local enabled = name == "You" or partner ~= nil
		local label = if name == "Partner" and partner then ("Partner: " .. partner.Name) else name
		local b = Kit.button({ Size = UDim2.fromOffset(if name == "You" then 80 else 150, 24), Position = UDim2.fromOffset(if name == "You" then 0 else 86, 0), Text = label, TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundColor3 = if name == tab then C.Accent else C.Panel, TextColor3 = if name == tab then Color3.fromRGB(30, 24, 10) elseif enabled then C.Text else C.Dim, Parent = container }, function()
			if enabled and name ~= tab then
				extra.SkillsTab = name
				extra.SkillSel = nil
				redraw()
			end
		end)
		b.Active = enabled
	end
	if not partner then
		Kit.label({ Size = UDim2.new(1, -250, 0, 24), Position = UDim2.fromOffset(246, 0), Text = "Join a party to edit a partner's skills.", TextSize = 11, TextColor3 = C.Dim, Parent = container })
	end
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, NoCorner = true, Parent = container })

	-- whose skills are on screen
	local equipped = table.clone(if isPartner then (partner.GhostLoadout or {}) else me.Loadout)
	local levels = if isPartner then (partner.SlotLevels or {}) else me.SlotLevels
	local ownedSet = if isPartner then (partner.Owned or {}) else me.Owned
	-- Changes show instantly (the local state is updated and the screen redrawn first); the server call
	-- follows in the background and its reply refreshes everything again.
	local function save(ids)
		if isPartner then
			partner.GhostLoadout = table.clone(ids)
		else
			me.Loadout = table.clone(ids)
		end
		redraw()
		task.spawn(function()
			if isPartner then
				call("SetGhostLoadout", ids)
			else
				call("EquipSkills", ids)
			end
		end)
	end

	local sel = extra.SkillSel
	if not sel or (sel.Slot and not equipped[sel.Slot]) then
		sel = { Slot = 1 }
		extra.SkillSel = sel
	end
	local isPassive = not isPartner and (sel.PSlot ~= nil or sel.PId ~= nil)
	local pEquipped = table.clone(me.PassiveIds or {})
	local function equipPassives()
		me.PassiveIds = table.clone(pEquipped)
		redraw()
		task.spawn(function()
			call("EquipPassives", pEquipped)
		end)
	end
	local selectedId = if sel.Slot then equipped[sel.Slot] else sel.Id
	local selectedDef = selectedId and Abilities[selectedId]

	-- LEFT: slots, passives, pool ------------------------------------------------
	local main = Kit.frame({ Size = UDim2.new(0, MAIN_W, 1, 0), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	Kit.label({ Size = UDim2.fromOffset(230, 14), Text = "CAST ORDER  (drag to reorder)", TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = main })
	local slotTiles = {}
	local passiveTiles = {}
	local function dropOnPassive(pointer)
		for slot, frame in pairs(passiveTiles) do
			if inside(frame, pointer) then
				return slot
			end
		end
	end
	local function ghostOf(pdef)
		return function(root)
			return Icons.Passive(root, pdef, { Size = UDim2.fromOffset(46, 46) })
		end
	end
	local function dropOnSlot(pointer)
		for slot, frame in pairs(slotTiles) do
			if inside(frame, pointer) then
				return slot
			end
		end
	end
	for slot, id in ipairs(equipped) do
		local def = Abilities[id]
		if def then
			local tile = Icons.Skill(main, def, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset((slot - 1) * 58, 16), Level = levels[slot] })
			slotTiles[slot] = tile
			Kit.Hover(tile, function() return Tips.Skill(def, levels[slot] or 1) end)
			attach(tile, def, sel.Slot == slot, function()
				extra.SkillSel = { Slot = slot }
				redraw()
			end, function(pointer)
				local to = dropOnSlot(pointer)
				if to and to ~= slot then
					equipped[slot], equipped[to] = equipped[to], equipped[slot]
					extra.SkillSel = { Slot = to }
					save(equipped)
				end
			end)
			Kit.label({ Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(3 + (slot - 1) * 58, 17), Text = tostring(slot), TextSize = 10, TextWrapped = false, TextColor3 = C.Dim, ZIndex = 8, Parent = main })
		end
	end

	-- passives (yours only; the partner's are shown on the Hero page)
	if not isPartner then
		Kit.label({ Size = UDim2.fromOffset(150, 14), Position = UDim2.fromOffset(244, 0), Text = "PASSIVES", TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, Parent = main })
		for slot = 1, Passives.SLOTS do
			local locked = slot > (me.PassiveSlots or 0)
			local pdef = not locked and PassiveCfg.Defs[pEquipped[slot]] or nil
			local tile = Icons.Passive(main, pdef, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(244 + (slot - 1) * 50, 20), Level = if pdef then (me.PassiveLevels or {})[slot] else nil, Locked = locked })
			if pdef then
				Kit.Hover(tile, function() return Tips.Passive(pdef, (me.PassiveLevels or {})[slot] or 1) end)
			end
			passiveTiles[slot] = tile
			attach(tile, nil, sel.PSlot == slot, function()
				extra.SkillSel = { PSlot = slot }
				redraw()
			end, if pdef then function(pointer)
				local to = dropOnPassive(pointer)
				if to and to ~= slot and to <= (me.PassiveSlots or 0) and to <= #pEquipped then
					pEquipped[slot], pEquipped[to] = pEquipped[to], pEquipped[slot]
					extra.SkillSel = { PSlot = to }
					equipPassives()
				end
			end else nil, if pdef then ghostOf(pdef) else nil)
		end
	else
		Kit.label({ Size = UDim2.fromOffset(140, 50), Position = UDim2.fromOffset(244, 18), Text = "Edits here change how your partner's ghost fights. Level-ups happen on their side.", TextSize = 10, TextColor3 = C.Dim, Parent = main })
	end

	local poolY = 72
	if not isPartner then
		if #(me.SubclassChoices or {}) > 0 then
			Kit.label({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, poolY), Text = "★ Choose your path (permanent this season)", TextSize = 11, TextColor3 = C.Accent, Font = Enum.Font.GothamBold, Parent = main })
			for index, choice in ipairs(me.SubclassChoices) do
				local b = Kit.button({ Size = UDim2.new(0.5, -3, 0, 22), Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 3, 0, poolY + 16), Text = choice.Name, TextSize = 12, BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = main }, function()
					call("ChooseSubclass", choice.Id)
				end)
				Kit.Hover(b, function()
					return ("<b>%s</b>\n%s\n%s\n%s"):format(choice.Name, choice.Description, Kit.tint(choice.Summary, C.Dim), "New skills: " .. table.concat(choice.SkillNames, ", "))
				end)
			end
			poolY += 42
		elseif me.SubclassId then
			local def = Subclasses.Defs[me.SubclassId]
			local l = Kit.label({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, poolY), Text = "Path: " .. def.DisplayName, TextSize = 11, TextColor3 = C.Accent, Parent = main })
			Kit.Hover(l, function() return def.DisplayName .. "\n" .. Subclasses.Describe(me.SubclassId) end)
			poolY += 18
		elseif me.SubclassUnlockLevel then
			Kit.label({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, poolY), Text = ("Reach level %d to choose a path"):format(me.SubclassUnlockLevel), TextSize = 11, TextColor3 = C.Dim, Parent = main })
			poolY += 18
		end
	end

	local pool = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -poolY), Position = UDim2.fromOffset(0, poolY), BackgroundColor3 = Color3.fromRGB(24, 27, 42), BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = main,
	})
	Kit.corner(8).Parent = pool
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), Parent = pool })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pool })
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function section(text)
		Kit.label({ Size = UDim2.new(1, 0, 0, 14), Text = text, TextSize = 11, TextColor3 = C.Dim, Font = Enum.Font.GothamBold, LayoutOrder = nextOrder(), Parent = pool })
	end
	local function iconGrid()
		local g = Kit.frame({ Size = UDim2.new(1, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, NoCorner = true, LayoutOrder = nextOrder(), Parent = pool })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(42, 42), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
		return g
	end

	local owned, locked = {}, {}
	if isPartner then
		for id in pairs(ownedSet) do
			if Abilities[id] and not table.find(equipped, id) then
				table.insert(owned, id)
			end
		end
		table.sort(owned)
	else
		for _, id in ipairs(Skills.Pool(me.ClassId, me.SubclassId)) do
			if Abilities[id] and not table.find(equipped, id) then
				table.insert(if ownedSet[id] then owned else locked, id)
			end
		end
	end
	section(if isPartner then "THEIR SKILLS  (drag onto a slot)" else "UNLOCKED  (drag onto a slot)")
	if #owned == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "Everything they own is equipped", TextSize = 11, TextColor3 = C.Dim, LayoutOrder = nextOrder(), Parent = pool })
	else
		local g = iconGrid()
		for _, id in ipairs(owned) do
			local def = Abilities[id]
			local tile = Icons.Skill(g, def, {})
			Kit.Hover(tile, function() return Tips.Skill(def, 1) end)
			attach(tile, def, sel.Id == id, function()
				extra.SkillSel = { Id = id, Target = sel.Slot or sel.Target }
				redraw()
			end, function(pointer)
				local to = dropOnSlot(pointer)
				if to then
					equipped[to] = id
					extra.SkillSel = { Slot = to }
					save(equipped)
				end
			end)
		end
	end
	if #locked > 0 then
		section("LOCKED")
		local g = iconGrid()
		for _, id in ipairs(locked) do
			local def = Abilities[id]
			local tile = Icons.Skill(g, def, { Locked = true })
			Kit.Hover(tile, function() return Tips.Skill(def, 1) end)
			attach(tile, def, sel.Id == id, function()
				extra.SkillSel = { Id = id }
				redraw()
			end)
		end
	end
	if not isPartner then
		section("PASSIVES")
		local g = iconGrid()
		local any = false
		for _, id in ipairs(Passives.Pool(me.ClassId)) do
			if not table.find(pEquipped, id) then
				any = true
				local pdef = PassiveCfg.Defs[id]
				local open = Passives.IsUnlocked(id, me.Frontier)
				local tile = Icons.Passive(g, pdef, { Locked = not open })
				Kit.Hover(tile, function() return Tips.Passive(pdef, 1) end)
				attach(tile, nil, sel.PId == id, function()
					extra.SkillSel = { PId = id, Target = sel.PSlot or sel.Target }
					redraw()
				end, if open then function(pointer)
					local to = dropOnPassive(pointer)
					if to and to <= (me.PassiveSlots or 0) then
						to = math.min(to, #pEquipped + 1)
						pEquipped[to] = id
						extra.SkillSel = { PSlot = to }
						equipPassives()
					end
				end else nil, ghostOf(pdef))
			end
		end
		if not any then
			Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = "Every passive is equipped", TextSize = 11, TextColor3 = C.Dim, Parent = g })
		end
	end

	-- RIGHT: the selected skill ---------------------------------------------------
	local right = panelFrame(area, MAIN_W + GAP, DETAIL_W)
	if isPassive then
		local pdef, slot
		if sel.PSlot then
			slot = sel.PSlot
			pdef = if slot <= (me.PassiveSlots or 0) then PassiveCfg.Defs[pEquipped[slot]] else nil
		else
			pdef = PassiveCfg.Defs[sel.PId]
		end
		if not pdef then
			local text = "Empty passive slot.\nPick an unlocked passive from the list to put in it."
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
			end).Position = UDim2.new(0, 8, 1, -64)
			note(right, "Pick an unlocked passive to swap it in.", -30)
		elseif Passives.IsUnlocked(pdef.Id, me.Frontier) then
			local target = math.clamp(sel.Target or (#pEquipped + 1), 1, math.min(#pEquipped + 1, math.max(me.PassiveSlots or 1, 1)))
			local swapOut = PassiveCfg.Defs[pEquipped[target]]
			actionButton(right, ("Equip in passive slot %d"):format(target), 0, C.Up, function()
				pEquipped[target] = pdef.Id
				extra.SkillSel = { PSlot = target }
				equipPassives()
			end).Position = UDim2.new(0, 8, 1, -64)
			note(right, swapOut and ("Replaces " .. swapOut.DisplayName .. ". Select a passive slot first to choose which.") or "Goes in the first free slot.", -34, 30)
		else
			note(right, ("Unlocks when you reach stage %d."):format(pdef.UnlockStage or 1), -48)
		end
		return
	end
	if not selectedDef then
		Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 8), Text = "Pick a skill to see its details.", TextColor3 = C.Dim, Parent = right })
		return
	end
	local isEquipped = sel.Slot ~= nil
	local isOwned = ownedSet[selectedId] == true
	local level = if isEquipped then (levels[sel.Slot] or 1) else 1
	Kit.label({ Size = UDim2.new(1, -16, 1, -104), Position = UDim2.fromOffset(8, 6), Text = Tips.Skill(selectedDef, level), RichText = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })

	if isEquipped then
		local slot = sel.Slot
		if not isPartner then
			local cost = Economy.SlotLevelCost(me.SlotLevels[slot])
			actionButton(right, cost and ("Level up  -  " .. cost .. "g") or "Max level", 0, C.Up, function()
				if cost then
					call("LevelSlot", slot)
				end
			end).Position = UDim2.new(0, 8, 1, -98)
		end
		local earlier = Kit.button({ Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.new(0, 8, 1, -64), Text = "◀ Earlier", TextSize = 12, Parent = right }, function()
			if slot > 1 then
				equipped[slot], equipped[slot - 1] = equipped[slot - 1], equipped[slot]
				extra.SkillSel = { Slot = slot - 1 }
				save(equipped)
			end
		end)
		local later = Kit.button({ Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.new(0.5, 4, 1, -64), Text = "Later ▶", TextSize = 12, Parent = right }, function()
			if slot < #equipped then
				equipped[slot], equipped[slot + 1] = equipped[slot + 1], equipped[slot]
				extra.SkillSel = { Slot = slot + 1 }
				save(equipped)
			end
		end)
		earlier.Active = slot > 1
		later.Active = slot < #equipped
		note(right, "Drag icons to reorder, or drag a pool skill onto this slot.", -32, 30)
	elseif isOwned then
		local target = math.clamp(sel.Target or #equipped, 1, #equipped)
		local swapOut = Abilities[equipped[target]]
		actionButton(right, ("Equip in slot %d"):format(target), 0, C.Up, function()
			equipped[target] = selectedId
			extra.SkillSel = { Slot = target }
			save(equipped)
		end).Position = UDim2.new(0, 8, 1, -64)
		note(right, swapOut and ("Replaces " .. swapOut.DisplayName .. ". Or drag the icon onto any slot.") or "", -32, 30)
	else
		local picks = me.SkillPicks or 0
		actionButton(right, ("Unlock with a pick  (%d)"):format(picks), 0, C.Up, function()
			call("UnlockSkillWithPick", selectedId)
		end).Position = UDim2.new(0, 8, 1, -98)
		note(right, ("Win it at the Wishing Tree in the plaza (you have %d shards, %d skill tickets)."):format(me.Shards or 0, ((state.Player.Wishing and state.Player.Wishing.Skill) or {}).Tickets or 0), -64, 56)
	end
end

return SkillsScreen
