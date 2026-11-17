--[[
	Screens (ModuleScript): Skills, Passives, Ultimate and Party panels.
	Each is a function (container, state, call) that redraws itself. `call`
	is call(action, ...) -> ok, data|reason and refreshes the state after.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local Power = require(Shared.Power)
local NumberFormat = require(Shared.Util.NumberFormat)
local PassiveCfg = require(Shared.Config.Passives)
local UltCfg = require(Shared.Config.Ultimates)
local AbilityStats = require(Shared.Combat.AbilityStats)
local Passives = require(Shared.Passives)
local Skills = require(Shared.Skills)
local FightStats = require(Shared.FightStats)
local PetsLib = require(Shared.Pets)
local Zones = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Zones)
local Stages = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Stages)
local TweenService = game:GetService("TweenService")
local StageRewards = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").StageRewards)
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local C = Kit.Colors

local Screens = {}

local function list(container)
	Kit.clear(container)
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	return scroll
end

local function row(parent, height)
	return Kit.frame({ Size = UDim2.new(1, -8, 0, height or 64), BackgroundColor3 = C.PanelLight, Parent = parent })
end

-- gear numbers can be small early on: show one decimal under 10
local function num(value)
	if value < 10 then
		return ("%.1f"):format(value)
	end
	return tostring(math.floor(value + 0.5))
end

local function minutes(seconds)
	return if seconds >= 3600 then ("%.1fh"):format(seconds / 3600) else ("%d min"):format(math.ceil(seconds / 60))
end

local function statsText(ability, level)
	local parts = {}
	for _, r in ipairs(AbilityStats.Rows(ability, level)) do
		table.insert(parts, r.Label .. " " .. r.Value)
	end
	return table.concat(parts, "  |  ")
end

local function msg(container, text)
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Text = text, TextColor3 = C.Accent, Parent = container })
end

-- Skills -------------------------------------------------------------------
function Screens.Skills(container, state, call)
	local me = state.Player
	local scroll = list(container)
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Equipped (tap a skill below to swap in, order = priority)", TextColor3 = C.Dim, Parent = scroll })
	local equipped = table.clone(me.Loadout)

	for slot, id in ipairs(equipped) do
		local def = Abilities[id]
		local r = row(scroll, 70)
		local icon = Icons.Skill(r, def, { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(8, 11), Level = me.SlotLevels[slot] })
		Kit.Hover(r, function() return Tips.Skill(def, me.SlotLevels[slot], ((me.SkillInfo or {})[def.Id] or {}).Tier) end)
		Kit.label({ Size = UDim2.new(1, -210, 0, 20), Position = UDim2.fromOffset(64, 4), Text = ("%d. %s  Lv %d"):format(slot, def.DisplayName, me.SlotLevels[slot]), TextColor3 = Kit.rarityColor(def.Rarity), Font = Enum.Font.GothamBold, Parent = r })
		Kit.label({ Size = UDim2.new(1, -210, 0, 40), Position = UDim2.fromOffset(64, 24), Text = statsText(def, me.SlotLevels[slot]), TextSize = 12, TextColor3 = C.Dim, Parent = r })
		if slot > 1 then
			Kit.button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -150, 0.5, -22), Text = "Up", Parent = r }, function()
				equipped[slot], equipped[slot - 1] = equipped[slot - 1], equipped[slot]
				call("EquipSkills", equipped)
			end)
		end
	end

	-- subclass: pick a path when one is offered, otherwise show the chosen one
	local SubclassRules = require(Shared.Subclasses)
	if #(me.SubclassChoices or {}) > 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Choose your path! This is permanent for the season.", TextColor3 = C.Accent, Font = Enum.Font.GothamBold, Parent = scroll })
		for _, choice in ipairs(me.SubclassChoices) do
			local r = row(scroll, 92)
			Kit.label({ Size = UDim2.new(1, -130, 0, 20), Position = UDim2.fromOffset(8, 4), Text = choice.Name, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = r })
			Kit.label({ Size = UDim2.new(1, -130, 0, 64), Position = UDim2.fromOffset(8, 24), Text = choice.Description .. "\n" .. choice.Summary .. "\nNew skills: " .. table.concat(choice.SkillNames, ", "), TextSize = 12, TextColor3 = C.Dim, Parent = r })
			Kit.button({ Size = UDim2.fromOffset(110, 44), Position = UDim2.new(1, -118, 0.5, -22), Text = "Choose", BackgroundColor3 = C.Accent, Parent = r }, function()
				call("ChooseSubclass", choice.Id)
			end)
		end
	elseif me.SubclassId then
		local def = SubclassRules.Defs[me.SubclassId]
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("Path: %s  (%s)"):format(def.DisplayName, SubclassRules.Describe(me.SubclassId)), TextColor3 = C.Accent, TextSize = 13, Parent = scroll })
	elseif me.SubclassUnlockLevel then
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("Reach level %d to choose a subclass path."):format(me.SubclassUnlockLevel), TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
	end

	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Your skills", TextColor3 = C.Dim, Parent = scroll })
	for _, id in ipairs(Skills.Pool(me.ClassId, me.SubclassId)) do
		local def = Abilities[id]
		local isOwned = me.Owned[id] == true
		local isEquipped = table.find(equipped, id) ~= nil
		local r = row(scroll, 60)
		Icons.Skill(r, def, { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 9), Locked = not isOwned })
		Kit.Hover(r, function() return Tips.Skill(def, 1) end)
		Kit.label({ Size = UDim2.new(1, -180, 0, 20), Position = UDim2.fromOffset(58, 4), Text = def.DisplayName .. (isEquipped and "  (equipped)" or ""), TextColor3 = Kit.rarityColor(def.Rarity), Font = Enum.Font.GothamBold, Parent = r })
		Kit.label({ Size = UDim2.new(1, -180, 0, 32), Position = UDim2.fromOffset(58, 24), Text = def.Description or "", TextSize = 12, TextColor3 = C.Dim, Parent = r })
		if isOwned and not isEquipped then
			Kit.button({ Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -108, 0.5, -22), Text = "Equip in 4", Parent = r }, function()
				equipped[#equipped] = id
				call("EquipSkills", equipped)
			end)
		elseif not isOwned then
			Kit.button({ Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -108, 0.5, -22), Text = "Unlock (pick)", Parent = r }, function()
				call("UnlockSkillWithPick", id)
			end)
		end
	end
end

-- Passives -----------------------------------------------------------------
function Screens.Passives(container, state, call)
	local me = state.Player
	local scroll = list(container)
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("Slots unlocked: %d of %d"):format(me.PassiveSlots, Passives.SLOTS), TextColor3 = C.Dim, Parent = scroll })
	local equipped = table.clone(me.PassiveIds)
	for slot = 1, Passives.SLOTS do
		local id = equipped[slot]
		local r = row(scroll, 56)
		if slot > me.PassiveSlots then
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "Slot " .. slot .. " locked (reach a later stage)", TextColor3 = C.Dim, Parent = r })
		else
			local def = id and PassiveCfg.Defs[id]
			local level = me.PassiveLevels[slot] or 1
			Kit.label({ Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0), Text = def and ("%d. %s  Lv %d\n%s"):format(slot, def.DisplayName, level, def.Description) or ("Slot " .. slot .. ": empty"), Parent = r })
			Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Level\n" .. require(Shared.Economy).PassiveSlotLevelCost(level) .. "g", Parent = r }, function()
				call("LevelPassiveSlot", slot)
			end)
		end
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Available (tap to put in the first free or last slot)", TextColor3 = C.Dim, Parent = scroll })
	for _, id in ipairs(Passives.Pool(me.ClassId)) do
		local def = PassiveCfg.Defs[id]
		local unlocked = Passives.IsUnlocked(id, me.Frontier)
		local r = row(scroll, 52)
		Kit.Hover(r, function() return Tips.Passive(def, 1) end)
		Kit.label({ Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s  [%s]\n%s"):format(def.DisplayName, def.Category, unlocked and def.Description or ("Unlocks at stage " .. def.UnlockStage)), TextColor3 = unlocked and C.Text or C.Dim, Parent = r })
		if unlocked and not table.find(equipped, id) then
			Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Equip", Parent = r }, function()
				local slot = math.min(#equipped + 1, me.PassiveSlots)
				equipped[slot] = id
				call("EquipPassives", equipped)
			end)
		end
	end
end

-- Gear (worn pieces + set collection) and Bag (everything acquired) ---------
local function tabs(scroll, current, options, onPick)
	local bar = row(scroll, 44)
	for index, option in ipairs(options) do
		Kit.button({
			Size = UDim2.fromOffset(150, 36), Position = UDim2.fromOffset(4 + (index - 1) * 158, 4), Text = option,
			BackgroundColor3 = if current == option then C.Accent else C.Panel, TextColor3 = if current == option then C.Bg else C.Text, Parent = bar,
		}, function()
			onPick(option)
		end)
	end
end

local VERDICT_TINT = { Up = C.Up, Down = C.Down }

local WORN_ORDER = { "Helmet", "Amulet", "Armor", "Weapon", "Pants", "Ring1", "Ring2", "Boots" }

function Screens.Gear(container, state, call)
	local gear = state.Player.Gear
	local scroll = list(container)
	for _, slotName in ipairs(WORN_ORDER) do
		local item = gear.Equipped[slotName]
		local r = row(scroll, 56)
		if item then
			Icons.Item(r, item, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 8) })
			Kit.Hover(r, function() return Tips.Item(item, gear) end)
			Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(58, 0), Text = ("%s%s   [%s]\n%s   -   IP %s"):format(item.Name, (item.Upgrade or 0) > 0 and ("  +" .. item.Upgrade) or "", slotName, item.StatText, Short(item.ItemPower or 0)), TextColor3 = Kit.rarityColor(if item.SetId then "Set" else item.Rarity), Parent = r })
			Kit.button({ Size = UDim2.fromOffset(92, 40), Position = UDim2.new(1, -100, 0.5, -20), Text = "Unequip", Parent = r }, function()
				call("UnequipGear", slotName)
			end)
		else
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = slotName .. ": empty  (open the Bag to equip something)", TextColor3 = C.Dim, Parent = r })
		end
	end
	-- set bonuses come from the set pieces you are WEARING (they are ordinary gear)
	local any = false
	for _, set in ipairs(gear.Sets or {}) do
		if set.Worn >= 1 then
			any = true
			local r = row(scroll, 62)
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s  (%d worn)\n%d pieces: %s\n%d pieces: %s"):format(set.Name, set.Worn, set.Need1, set.Bonus2, set.Need2, set.Bonus3), TextColor3 = if set.Worn >= set.Need1 then C.Set else C.Dim, TextSize = 12, Parent = r })
		end
	end
	if not any then
		Kit.label({ Size = UDim2.new(1, 0, 0, 36), Text = "Set pieces are normal gear that drops in their own zone. Wear 2 or 4 pieces of one set for bonuses.", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	end
end

-- The Stash: consumables. Select one, then use it (boost) or feed it to a pet.
local function stashTab(container, state, call, extra)
	local me = state.Player
	local rows = me.Stash or {}
	local sel = extra.StashSel
	local selRow
	for _, r in ipairs(rows) do
		if r.Id == sel then
			selRow = r
		end
	end
	if not selRow then
		selRow = rows[1]
		extra.StashSel = selRow and selRow.Id
	end

	local gridHolder = Kit.new("ScrollingFrame", {
		Size = UDim2.new(0.55, -4, 1, -36), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = container,
	})
	local detail = Kit.frame({ Size = UDim2.new(0.45, -4, 1, -36), Position = UDim2.new(0.55, 4, 0, 36), BackgroundColor3 = Color3.fromRGB(30, 33, 50), Parent = container })

	if #rows == 0 then
		detail.Visible = false
		gridHolder.Visible = false
		Kit.label({ Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 40), TextWrapped = true, Text = "Your stash is empty.\nFights, bosses and the world boss drop boosts, pet food and wish tickets. The Merchant sells supplies.", TextColor3 = C.Dim, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Parent = container })
		return
	end
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), Parent = gridHolder })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(54, 54), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = gridHolder })
	for index, r in ipairs(rows) do
		local tile = Kit.frame({ BackgroundColor3 = C.PanelLight, LayoutOrder = index, Parent = gridHolder })
		Kit.new("UIStroke", { Color = if r.Id == extra.StashSel then Color3.new(1, 1, 1) else Kit.rarityColor(r.Rarity), Thickness = if r.Id == extra.StashSel then 3 else 2, Parent = tile })
		Kit.label({ Size = UDim2.fromScale(1, 1), Text = r.Glyph, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = tile })
		Kit.label({ Size = UDim2.fromOffset(30, 14), Position = UDim2.new(1, -32, 1, -16), Text = "x" .. r.Count, TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = 3, Parent = tile })
		local click = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = tile })
		click.Activated:Connect(function()
			extra.StashSel = r.Id
			Screens.Bag(container, state, call, extra)
		end)
	end

	if not selRow then
		return
	end
	Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), Text = ("%s  %s  x%d"):format(selRow.Glyph, selRow.Name, selRow.Count), TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = Kit.rarityColor(selRow.Rarity), Parent = detail })
	Kit.label({ Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 30), Text = selRow.Description, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	if selRow.Kind == "Buff" then
		-- using a boost adds its time up to a cap: warn first so nothing is wasted
		local remaining = 0
		for _, buff in ipairs(me.Buffs or {}) do
			if buff.Id == selRow.Id then
				remaining = buff.Remaining
			end
		end
		local cap = selRow.MaxStack or 7200
		local wasted = remaining + (selRow.Duration or 0) - cap
		local confirming = extra.StashConfirm == selRow.Id
		if wasted > 0 then
			Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 1, -86), Text = ("Careful: %s of this boost would be wasted (the cap is %s)."):format(minutes(wasted), minutes(cap)), TextSize = 11, TextColor3 = C.Bad, Parent = detail })
		end
		Kit.button({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 1, -44), Text = if wasted <= 0 then "Use now" elseif confirming then "Tap again to use anyway" else "Use now (wastes time)", BackgroundColor3 = if wasted > 0 then C.Bad else C.Up, Parent = detail }, function()
			if wasted > 0 and not confirming then
				extra.StashConfirm = selRow.Id
				Screens.Bag(container, state, call, extra)
				return
			end
			extra.StashConfirm = nil
			call("UseConsumable", selRow.Id, nil, true)
		end)
	elseif selRow.Kind == "PetFood" then
		Kit.label({ Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 84), Text = "Feed to:", TextSize = 11, TextColor3 = C.Dim, Parent = detail })
		local y = 100
		for _, pet in ipairs(me.Pets or {}) do
			if pet.Owned and y < 170 then
				Kit.button({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, y), Text = ("%s  Lv %d%s"):format(pet.Name, pet.Level, pet.Level >= (pet.MaxLevel or 10) and "  (max)" or ""), TextSize = 12, Parent = detail }, function()
					call("UseConsumable", selRow.Id, pet.Id)
				end)
				y += 30
			end
		end
	else
		Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 1, -50), Text = "Spend it at the Wishing Tree in the plaza.", TextSize = 12, TextColor3 = C.Accent, Parent = detail })
	end
end

function Screens.Bag(container, state, call, extra)
	local gear = state.Player.Gear
	extra = extra or {}
	local compact = extra.BagCompact == true
	local tab = extra.BagTab or "Gear"
	Kit.clear(container)
	-- header: tabs, count, view toggle
	for index, name in ipairs({ "Gear", "Stash" }) do
		Kit.button({ Size = UDim2.fromOffset(86, 30), Position = UDim2.fromOffset((index - 1) * 92, 0), Text = name, BackgroundColor3 = if tab == name then C.Accent else C.Panel, TextColor3 = if tab == name then C.Bg else C.Text, Parent = container }, function()
			extra.BagTab = name
			Screens.Bag(container, state, call, extra)
		end)
	end
	if tab == "Stash" then
		stashTab(container, state, call, extra)
		return
	end
	Kit.label({ Size = UDim2.new(1, -470, 0, 32), Position = UDim2.fromOffset(190, 0), TextWrapped = true, Text = ("Bag %d/%d  -  strongest first.  Hover: green = better than what you wear."):format(#gear.Inventory, gear.Cap), TextColor3 = C.Dim, TextSize = 11, Parent = container })
	Kit.button({ Name = "EquipBest", Size = UDim2.fromOffset(130, 30), Position = UDim2.new(1, -266, 0, 0), Text = "Equip best", BackgroundColor3 = C.Good, TextColor3 = C.Bg, Parent = container }, function()
		call("EquipBestGear")
	end)
	Kit.button({ Size = UDim2.fromOffset(130, 30), Position = UDim2.new(1, -130, 0, 0), Text = if compact then "View: icons" else "View: list", Parent = container }, function()
		extra.BagCompact = not compact
		Screens.Bag(container, state, call, extra)
	end)
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = container,
	})
	if #gear.Inventory == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Empty. Win fights to find gear.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	if compact then
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(46, 46), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
		for index, item in ipairs(gear.Inventory) do
			local cmp = Tips.Compare(item, gear)
			local tile = Icons.Item(scroll, item, { Size = UDim2.fromOffset(46, 46), Level = item.ItemPower, LayoutOrder = index })
			if cmp.Verdict == "Up" then
				Kit.label({ Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 0), Text = "▲", TextSize = 11, TextColor3 = C.Good, TextWrapped = false, ZIndex = 3, Parent = tile })
			end
			Kit.Hover(tile, function() return Tips.Item(item, gear) end)
			local click = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = tile })
			click.Activated:Connect(function()
				call("EquipGear", item.Id)
			end)
		end
		return
	end
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	for index, item in ipairs(gear.Inventory) do
		local cmp = Tips.Compare(item, gear)
		local r = row(scroll, 52)
		r.LayoutOrder = index
		r.BackgroundColor3 = VERDICT_TINT[cmp.Verdict] or C.PanelLight
		Icons.Item(r, item, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 6) })
		Kit.Hover(r, function() return Tips.Item(item, gear) end)
		local arrow = if cmp.Verdict == "Up" then "  ▲" elseif cmp.Verdict == "Down" then "  ▼" else ""
		Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(58, 0), Text = ("%s%s%s\n%s   -   %s   -   IP %s"):format(item.Name, (item.Upgrade or 0) > 0 and ("  +" .. item.Upgrade) or "", arrow, item.Slot, item.StatText, Short(item.ItemPower or 0)), TextColor3 = C.Text, Parent = r })
		Kit.button({ Size = UDim2.fromOffset(90, 40), Position = UDim2.new(1, -104, 0.5, -20), Text = "Equip", Parent = r }, function()
			call("EquipGear", item.Id)
		end)
	end
end

-- Combat log: the last fight, with times, so a hard boss can be studied -------
local function clock(t)
	return ("%d:%04.1f"):format(math.floor(t / 60), t % 60)
end

local function buildLog(fight, everyHit)
	local names, teams, petNames = {}, {}, {}
	for _, entry in ipairs(fight.Roster or {}) do
		names[entry.Id] = entry.Name
		teams[entry.Id] = entry.Team
		local petDef = entry.PetId and PetsLib.Defs[entry.PetId]
		if petDef then
			petNames[entry.Id] = petDef.DisplayName .. " (" .. entry.Name .. "'s pet)"
		end
	end
	for _, e in ipairs(fight.Events or {}) do
		if e.Type == "Spawn" and e.Entity then
			names[e.Entity.Id] = e.Entity.Name
			teams[e.Entity.Id] = e.Entity.Team
		end
	end
	local function who(id)
		local name = names[id] or tostring(id)
		return Kit.tint(name, if teams[id] == "Party" then C.Rare else C.Bad)
	end
	-- a pet's skill is cast by its owner in the sim, but it reads as the pet acting
	local function whoFor(id, abilityId)
		if type(abilityId) == "string" and abilityId:sub(1, 4) == "Pet_" and petNames[id] then
			return Kit.tint(petNames[id], C.Good)
		end
		return who(id)
	end
	local function ability(id)
		local def = Abilities[id] or (UltCfg.Defs and UltCfg.Defs[id])
		return def and def.DisplayName or tostring(id)
	end

	local lines, bigHits, times = {}, {}, {}
	local function add(t, text)
		table.insert(times, t)
		table.insert(lines, ("%s  %s"):format(Kit.tint(clock(t), C.Dim), text))
	end
	for _, e in ipairs(fight.Events or {}) do
		local t = e.T or 0
		local kind = e.Type
		if kind == "Cast" then
			add(t, ("%s casts %s (Lv %d)"):format(whoFor(e.Source, e.Ability), Kit.tint(ability(e.Ability), C.Accent), e.Level or 1))
		elseif kind == "Telegraph" then
			table.insert(bigHits, clock(t + (e["In"] or 0)))
			add(t, ("%s  %s winds up %s - lands in %.1fs"):format(Kit.tint("WARNING", C.Bad), who(e.Source), Kit.tint(ability(e.Ability), C.Bad), e["In"] or 0))
		elseif kind == "Spawn" and e.Entity then
			add(t, ("%s summons %s"):format(who(e.Source), who(e.Entity.Id)))
		elseif kind == "Ultimate" then
			add(t, Kit.tint("ULTIMATE: " .. ability(e.Ability), Kit.Colors.Epic))
		elseif kind == "Death" then
			add(t, ("%s falls"):format(who(e.Target)))
		elseif kind == "Revive" then
			add(t, ("%s is revived"):format(who(e.Target)))
		elseif kind == "Status" and everyHit then
			add(t, ("%s gets %s (%.0fs)"):format(who(e.Target), e.Status, e.Duration or 0))
		elseif kind == "StatusEnd" and everyHit then
			add(t, ("%s loses %s%s"):format(who(e.Target), e.Status, e.Reason == "Broken" and " (shield broken)" or ""))
		elseif kind == "Damage" then
			local isBasic = e.Tag == "BasicAttack"
			local enemySource = teams[e.Source] ~= "Party"
			local fromPet = type(e.Tag) == "string" and e.Tag:sub(1, 4) == "Pet_"
			if everyHit or fromPet or (enemySource and not isBasic) then
				local absorbed = (e.Absorbed or 0) > 0 and ("  (" .. math.floor(e.Absorbed + 0.5) .. " absorbed)") or ""
				add(t, ("%s hits %s for %d%s%s%s"):format(whoFor(e.Source, e.Tag), who(e.Target), math.floor((e.Amount or 0) + 0.5), e.Crit and " CRIT" or "", isBasic and "" or (" [" .. ability(e.Tag) .. "]"), absorbed))
			end
		elseif kind == "Heal" and (everyHit or (type(e.Tag) == "string" and e.Tag:sub(1, 4) == "Pet_")) and (e.Amount or 0) > 0 then
			add(t, ("%s heals %s for %s%s"):format(whoFor(e.Source, e.Tag), who(e.Target), Short(e.Amount or 0), e.Tag and e.Tag ~= "BasicAttack" and (" [" .. ability(e.Tag) .. "]") or ""))
		elseif kind == "End" then
			add(t, Kit.tint(if e.Winner == "Party" then "Victory" else "Defeat", if e.Winner == "Party" then C.Good else C.Bad))
		end
	end
	return lines, bigHits, times
end
Screens.BuildLog = buildLog

-- Damage meter: one bar per hero, pet and minion group, players in their own colours -----
function Screens.DamageMeter(parent, stats, widthScale)
	local top = stats.Rows[1] and math.max(stats.Rows[1].Damage, 1) or 1
	Kit.label({
		Size = UDim2.new(1, -8, 0, 18), RichText = true, TextSize = 12, TextColor3 = C.Dim,
		Text = ("%s %s  -  %s DPS"):format(stats.Title or "Party damage", Kit.tint(Short(stats.Total), C.Text), Kit.tint(Short(stats.Dps), C.Accent)),
		Parent = parent, LayoutOrder = 0,
	})
	for i, r in ipairs(stats.Rows) do
		local color = FightStats.PlayerColor(r.Color)
		local fill = if r.Kind == "Enemy" then Color3.fromRGB(220, 80, 80) elseif r.Kind == "Hero" then color else color:Lerp(Color3.new(1, 1, 1), 0.35)
		local bar = Kit.frame({ Size = UDim2.new(1, -8, 0, 22), BackgroundColor3 = Color3.fromRGB(26, 30, 48), LayoutOrder = i, Parent = parent })
		Kit.frame({ Size = UDim2.new(math.max(r.Damage / top, 0.01), 0, 1, 0), BackgroundColor3 = fill, BackgroundTransparency = if r.Kind == "Hero" then 0.25 else 0.5, Parent = bar })
		local prefix = if r.Kind == "Pet" then "🐾 " elseif r.Kind == "Minion" then "💀 " elseif r.Kind == "Enemy" then "👹 " else ""
		Kit.label({ Size = UDim2.new(0.62, 0, 1, 0), Position = UDim2.fromOffset(6, 0), Text = prefix .. r.Name, TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar })
		Kit.label({ Size = UDim2.new(0.38, -8, 1, 0), Position = UDim2.new(0.62, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextWrapped = false, Text = ("%s/s  %d%%"):format(require(Shared.Util.NumberFormat).Short(r.Dps), math.floor(r.Share * 100 + 0.5)), Parent = bar })
	end
end

function Screens.Log(container, state, call, extra)
	local scroll = list(container)
	local fight = extra and extra.LastFight
	if not (fight and fight.Events) then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "No fight recorded yet. Win or lose one and it shows up here.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	local everyHit = extra.LogAll == true
	local head = row(scroll, 74)
	local result = if fight.Won then Kit.tint("Cleared", C.Good) elseif fight.TimedOut then Kit.tint("Timed out", C.Bad) else Kit.tint("Defeated", C.Bad)
	local lines, bigHits = buildLog(fight, everyHit)
	Kit.label({
		Size = UDim2.new(1, -170, 1, -6), Position = UDim2.fromOffset(8, 3), RichText = true, TextSize = 13,
		Text = ("Stage %d  -  %s  -  %s\n%s"):format(fight.Stage or 0, result, clock(fight.Duration or 0), #bigHits > 0 and ("Boss big hits land at: " .. table.concat(bigHits, ", ") .. "\nTime a shield BEFORE, a heal AFTER.") or "Skills cast in slot order as soon as they are ready."),
		Parent = head,
	})
	Kit.button({ Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -158, 0.5, -22), Text = everyHit and "Show key moments" or "Show every hit", Parent = head }, function()
		extra.LogAll = not everyHit
		Screens.Log(container, state, call, extra)
	end)
	local meter = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, NoCorner = true, Parent = scroll })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = meter })
	Screens.DamageMeter(meter, FightStats.Compute(fight))
	local sources = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, NoCorner = true, Parent = scroll })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sources })
	Screens.DamageMeter(sources, FightStats.Sources(fight))
	local shown = 0
	for _, text in ipairs(lines) do
		shown += 1
		if shown > 400 then
			Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = "... log trimmed", TextColor3 = C.Dim, Parent = scroll })
			break
		end
		Kit.label({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, RichText = true, TextSize = 12, Text = text, Parent = scroll })
	end
end

-- Daily --------------------------------------------------------------------
-- A seven day login calendar: one card per day with what it pays, ticked once claimed, today lit up. The cycle repeats and
-- missing a day starts it again at day 1.
function Screens.Daily(container, state, call)
	local daily = state.Player.Daily
	local scroll = list(container)
	local head = row(scroll, 74)
	local text = if daily.CanClaim then ("Day %d reward is ready!"):format(daily.NextDay) else ("Claimed today. Come back tomorrow for day %d."):format(daily.NextDay % #daily.Week + 1)
	Kit.label({ Size = UDim2.new(1, -190, 0, 28), Position = UDim2.fromOffset(10, 6), Text = text, TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = if daily.CanClaim then C.Accent else C.Text, Parent = head })
	Kit.label({ Size = UDim2.new(1, -190, 0, 36), Position = UDim2.fromOffset(10, 34), Text = ("Login streak: %d day%s. The week repeats; missing a day starts it again at day 1."):format(daily.Streak, daily.Streak == 1 and "" or "s"), TextSize = 12, TextColor3 = C.Dim, Parent = head })
	if daily.CanClaim then
		Kit.button({ Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -170, 0.5, -22), Text = "Claim day " .. daily.NextDay, BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = head }, function()
			call("ClaimDaily")
		end)
	end

	local grid = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, NoCorner = true, Parent = scroll })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 118), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, entry in ipairs(daily.Week) do
		local today, done = entry.State == "Today", entry.State == "Claimed"
		local card = Kit.frame({ BackgroundColor3 = if today then Color3.fromRGB(70, 58, 26) elseif done then Color3.fromRGB(26, 44, 34) else C.Panel, LayoutOrder = entry.Day, Parent = grid })
		Kit.new("UIStroke", { Color = if today then C.Accent elseif done then C.Good else Color3.fromRGB(70, 76, 104), Thickness = if today then 3 else 1, Parent = card })
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 4), Text = ("Day %d"):format(entry.Day), TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if today then C.Accent else C.Text, Parent = card })
		local lines = { ("💰 %s"):format(tostring(entry.Reward.Gold)) }
		if (entry.Reward.Wishstones or 0) > 0 then
			table.insert(lines, ("🌠 %d wishstones"):format(entry.Reward.Wishstones))
		end
		if (entry.Reward.SkillPicks or 0) > 0 then
			table.insert(lines, ("🎁 %d skill pick"):format(entry.Reward.SkillPicks))
		end
		Kit.label({ Size = UDim2.new(1, -8, 0, 62), Position = UDim2.fromOffset(4, 26), Text = table.concat(lines, "\n"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -24), Text = if done then "✔ Claimed" elseif today then "Today" else "", TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if done then C.Good else C.Accent, Parent = card })
	end
end

-- Ranks --------------------------------------------------------------------
-- extra.Board = reply of GetLeaderboard, extra.BoardCategory = "Stage"|"Level"|"Class_<class>",
-- extra.ShowBoard(categoryId) switches tabs.
function Screens.Ranks(container, _, _, extra)
	local Leaderboards = require(Shared.Leaderboards)
	local scroll = list(container)
	-- three tabs per row: Furthest stage, Highest level, then one per class
	local PER_ROW = 3
	local tabs
	for index, category in ipairs(Leaderboards.Categories) do
		local col = (index - 1) % PER_ROW
		if col == 0 then
			tabs = row(scroll, 44)
		end
		Kit.button({
			Size = UDim2.fromOffset(150, 36), Position = UDim2.fromOffset(4 + col * 158, 4), Text = category.Name,
			BackgroundColor3 = if extra.BoardCategory == category.Id then C.Accent else C.Panel, Parent = tabs,
		}, function()
			if extra.ShowBoard then
				extra.ShowBoard(category.Id)
			end
		end)
	end
	local board = extra.Board
	if not board then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	if #board.Rows == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "No scores yet. Check back in a minute.", TextColor3 = C.Dim, Parent = scroll })
	end
	for _, entry in ipairs(board.Rows) do
		local r = row(scroll, 32)
		local mine = entry.UserId == game:GetService("Players").LocalPlayer.UserId
		Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%d.  %s   %s"):format(entry.Rank, entry.Name, Leaderboards.Format(extra.BoardCategory, entry.Value)), TextColor3 = mine and C.Accent or C.Text, Parent = r })
	end
	if board.Mine and board.Mine.Value then
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("You: %s%s"):format(Leaderboards.Format(extra.BoardCategory, board.Mine.Value), board.Mine.Rank and ("  (rank " .. board.Mine.Rank .. ")") or "  (not in the top list yet)"), TextColor3 = C.Dim, Parent = scroll })
	end
end

-- Inspect ------------------------------------------------------------------
-- Public card for another player (state is not used; extra.Inspect is the reply
-- of the server's Inspect action).
function Screens.Inspect(container, _, _, extra)
	local info = extra and extra.Inspect
	local scroll = list(container)
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Nobody selected.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	local PetConfig = require(Shared.Config.Pets)
	local pet = info.PetId and PetConfig.Defs[info.PetId]
	local zone = Zones.ForStage(info.PartyStage or 1)
	local head = row(scroll, 92)
	local lines = {
		("%s  -  %s  Lv %d%s"):format(info.Name, info.ClassId, info.Level, info.Online and "" or "  (ghost)"),
		("Pet: %s"):format(pet and ("%s  Lv %d  (%s)"):format(pet.DisplayName, info.PetLevel or 1, require(Shared.Pets).Describe(info.PetId, info.PetLevel)) or "none"),
		("Party is on %s, stage %d (furthest %d)"):format(zone.Name, info.PartyStage or 1, info.PartyFrontier or 1),
		info.Partner and ("Partner: %s (%s Lv %d)"):format(info.Partner.Name, info.Partner.ClassId, info.Partner.Level) or "Partner: none",
	}
	Kit.label({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = table.concat(lines, "\n"), Parent = head })
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Skills", TextColor3 = C.Dim, Parent = scroll })
	for slot, id in ipairs(info.Loadout or {}) do
		local def = Abilities[id]
		if def then
			local r = row(scroll, 34)
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%d. %s  Lv %d"):format(slot, def.DisplayName, info.SlotLevels[slot] or 1), TextColor3 = Kit.rarityColor(def.Rarity), Parent = r })
		end
	end
	if #(info.PassiveIds or {}) > 0 then
		local names = {}
		for _, id in ipairs(info.PassiveIds) do
			table.insert(names, PassiveCfg.Defs[id] and PassiveCfg.Defs[id].DisplayName or id)
		end
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Passives: " .. table.concat(names, ", "), TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
	end
end

-- Pets ---------------------------------------------------------------------
-- Pet gear: four slots (open as the active pet levels) and the bag of pieces
function Screens.PetGear(container, state, call, extra)
	Kit.clear(container)
	local g = state.Player.PetGear
	if not g then
		return
	end
	local PetGearConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.PetGear)
	local function pieceText(piece)
		return ("%s %s\n%s"):format(Kit.tint(piece.Rarity, Kit.rarityColor(piece.Rarity)), piece.Kind, ("+%.1f%% %s"):format(piece.Value * 100, (PetGearConfig.StatUnits[piece.Stat] or {}).Label or piece.Stat))
	end
	Kit.button({ Size = UDim2.fromOffset(110, 24), Position = UDim2.fromOffset(0, 0), Text = "◀ Pets", TextSize = 12, BackgroundColor3 = C.Panel, Parent = container }, function()
		extra.PetsView = nil
		Screens.Pets(container, state, call, extra)
	end)
	Kit.label({ Size = UDim2.new(1, -120, 0, 24), Position = UDim2.fromOffset(120, 0), Text = ("Pet gear works for YOU. Your pet is Lv %d; more slots open as it levels."):format(g.PetLevel), TextSize = 12, TextColor3 = C.Dim, Parent = container })
	for slot = 1, #g.Kinds do
		local open = slot <= g.Open
		local piece = g.Equipped[slot]
		local tile = Kit.button({ Size = UDim2.new(0.25, -6, 0, 78), Position = UDim2.new((slot - 1) * 0.25, 0, 0, 30), Text = "", BackgroundColor3 = if open then C.PanelLight else C.Panel, Parent = container }, function()
			if piece then
				call("UnequipPetGear", slot)
			end
		end)
		Kit.new("UIStroke", { Color = if piece then Kit.rarityColor(piece.Rarity) else C.Dim, Thickness = if piece then 2 else 1, Transparency = if open then 0 else 0.6, Parent = tile })
		Kit.label({ Size = UDim2.new(1, -4, 0, 16), Position = UDim2.fromOffset(2, 3), Text = (PetGearConfig.KindGlyph[g.Kinds[slot]] or "") .. " " .. g.Kinds[slot], TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if open then C.Text else C.Dim, Parent = tile })
		if not open then
			Kit.label({ Size = UDim2.new(1, -4, 0, 40), Position = UDim2.fromOffset(2, 24), Text = ("🔒\nPet Lv %d"):format(g.SlotNeeds[slot]), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = tile })
		elseif piece then
			Kit.label({ Size = UDim2.new(1, -6, 0, 50), Position = UDim2.fromOffset(3, 22), RichText = true, Text = pieceText(piece) .. "\n<font size=\"9\">tap to remove</font>", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Text, Parent = tile })
		else
			Kit.label({ Size = UDim2.new(1, -4, 0, 40), Position = UDim2.fromOffset(2, 28), Text = "empty", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = tile })
		end
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 112), Text = ("Bag  %d / %d   -   buy crates at the Pet Store in the plaza; bosses sometimes drop gear"):format(#g.Bag, g.BagSize), TextSize = 12, TextColor3 = C.Dim, Parent = container })
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -136), Position = UDim2.fromOffset(0, 134), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })
	for index, piece in ipairs(g.Bag) do
		local slot
		for i, kind in ipairs(g.Kinds) do
			if kind == piece.Kind then slot = i end
		end
		local locked = slot > g.Open
		local r = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.PanelLight, LayoutOrder = index, Parent = scroll })
		Kit.new("UIStroke", { Color = Kit.rarityColor(piece.Rarity), Thickness = 1.5, Parent = r })
		Kit.label({ Size = UDim2.new(1, -190, 1, 0), Position = UDim2.fromOffset(8, 0), RichText = true, Text = ("%s %s  %s\n%s"):format(PetGearConfig.KindGlyph[piece.Kind] or "", Kit.tint(piece.Rarity .. " " .. piece.Kind, Kit.rarityColor(piece.Rarity)), if locked then "(slot locked)" else "", ("+%.1f%% %s"):format(piece.Value * 100, (PetGearConfig.StatUnits[piece.Stat] or {}).Label or piece.Stat)), TextSize = 12, TextColor3 = C.Text, Parent = r })
		local eq = Kit.button({ Size = UDim2.fromOffset(78, 30), Position = UDim2.new(1, -170, 0.5, -15), Text = "Wear", TextSize = 12, BackgroundColor3 = if locked then C.Panel else C.Accent, TextColor3 = if locked then C.Dim else Color3.fromRGB(30, 24, 10), Parent = r }, function()
			if not locked then
				call("EquipPetGear", piece.Id)
			end
		end)
		eq.Active = not locked
		Kit.button({ Size = UDim2.fromOffset(84, 30), Position = UDim2.new(1, -88, 0.5, -15), Text = "Sell " .. NumberFormat.Short(math.floor(PetGearConfig.SellBase * PetGearConfig.RarityMult[piece.Rarity])) .. "g", TextSize = 11, BackgroundColor3 = C.Panel, Parent = r }, function()
			call("SellPetGear", piece.Id)
		end)
	end
	if #g.Bag == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "No pet gear yet. Visit the Pet Store.", TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
	end
end

function Screens.Pets(container, state, call, extra)
	if extra.PetsView == "Gear" then
		return Screens.PetGear(container, state, call, extra)
	end
	Kit.clear(container)
	local pets = table.clone(state.Player.Pets or {})
	local rankOf = { Legendary = 4, Epic = 3, Rare = 2, Common = 1 }
	table.sort(pets, function(a, b)
		if a.Owned ~= b.Owned then
			return a.Owned
		end
		if a.Active ~= b.Active then
			return a.Active == true
		end
		if rankOf[a.Rarity] ~= rankOf[b.Rarity] then
			return rankOf[a.Rarity] > rankOf[b.Rarity]
		end
		return a.Name < b.Name
	end)
	local selected
	for _, pet in ipairs(pets) do
		if pet.Id == extra.PetSel and pet.Owned then
			selected = pet
		end
	end
	if not selected then
		for _, pet in ipairs(pets) do
			if pet.Active then
				selected = pet
			end
		end
		selected = selected or (pets[1] and pets[1].Owned and pets[1]) or nil
	end

	-- slim shard strip across the top
	local shards, info, coll = state.Player.PetShards or {}, state.Player.PetShardInfo or { PetCost = 30, CondenseCost = 10 }, state.Player.PetCollection
	local strip = Kit.frame({ Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = C.Panel, Parent = container })
	local parts = {}
	for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
		table.insert(parts, ("%s %d"):format(Kit.tint(rarity:sub(1, 1), Kit.rarityColor(rarity)), shards[rarity] or 0))
	end
	local bonus = if coll then ("  |  Collection +%.1f%%"):format(coll.Percent or 0) else ""
	local shardLabel = Kit.label({ Size = UDim2.new(1, -240, 1, 0), Position = UDim2.fromOffset(10, 0), RichText = true, TextSize = 12, Text = ("<b>Shards</b>  %s%s"):format(table.concat(parts, "   "), bonus), Parent = strip })
	Kit.Hover(shardLabel, function()
		return ("Spare copies of max-rank pets become shards.\n%d shards buy a pet of that rarity; %d condense into 1 of the next rarity."):format(info.PetCost, info.CondenseCost)
	end)
	Kit.button({ Size = UDim2.fromOffset(84, 22), Position = UDim2.new(1, -226, 0, 4), Text = "Pet gear", TextSize = 12, BackgroundColor3 = C.PanelLight, Parent = strip }, function()
		extra.PetsView = "Gear"
		Screens.Pets(container, state, call, extra)
	end)
	Kit.button({ Size = UDim2.fromOffset(120, 22), Position = UDim2.new(1, -130, 0, 4), Text = "Condense all", TextSize = 12, BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = strip }, function()
		call("CondensePetShards", "All")
	end)

	-- card grid on the left
	local grid = Kit.new("ScrollingFrame", { Size = UDim2.new(0.56, -8, 1, -38), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 92), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), Parent = grid })
	for index, pet in ipairs(pets) do
		local isSel = selected ~= nil and pet.Id == selected.Id
		local color = Kit.rarityColor(pet.Rarity)
		local card = Kit.button({ LayoutOrder = index, Text = "", BackgroundColor3 = if pet.Owned then C.PanelLight else C.Panel, Parent = grid }, function()
			if pet.Owned then
				extra.PetSel = pet.Id
				Screens.Pets(container, state, call, extra)
			end
		end)
		Kit.new("UIStroke", { Color = if pet.Active then C.Accent else color, Thickness = if isSel or pet.Active then 3 else 1.5, Transparency = if pet.Owned then 0 else 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		if pet.Owned then
			Icons.Pet(card, pet.Id, { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 6) })
			Kit.label({ Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(2, 54), Text = pet.Name, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = color, Parent = card })
			Kit.label({ Size = UDim2.new(1, -4, 0, 12), Position = UDim2.fromOffset(2, 70), Text = ("Lv %d  %s"):format(pet.Level, string.rep("★", pet.Rank or 1)), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = card })
			if pet.Active then
				Kit.label({ Size = UDim2.fromOffset(16, 14), Position = UDim2.fromOffset(3, 2), Text = "✔", TextSize = 12, TextColor3 = C.Accent, Parent = card })
			end
			if (pet.RankCost or 1) <= (pet.Copies or 0) and (pet.Rank or 1) < (pet.MaxRank or 1) then
				Kit.label({ Size = UDim2.fromOffset(16, 14), Position = UDim2.new(1, -19, 0, 2), Text = "▲", TextSize = 12, TextColor3 = Color3.fromRGB(130, 235, 150), Parent = card })
			end
		else
			Icons.Pet(card, pet.Id, { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 6), Locked = true, Milestone = pet.UnlockStage ~= nil, LockText = if pet.UnlockStage then ("Stg " .. pet.UnlockStage) else nil })
			Kit.label({ Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(2, 54), Text = pet.Name, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = card })
			Kit.label({ Size = UDim2.new(1, -4, 0, 12), Position = UDim2.fromOffset(2, 70), Text = if pet.UnlockStage then ("Clear stage %d"):format(pet.UnlockStage) else "Wishing Tree", TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = card })
		end
	end

	-- detail pane on the right
	local detail = Kit.frame({ Size = UDim2.new(0.44, -4, 1, -38), Position = UDim2.new(0.56, 0, 0, 36), BackgroundColor3 = C.Panel, Parent = container })
	if not selected then
		Kit.label({ Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "No pets yet. Make a wish at the Wishing Tree.", TextColor3 = C.Dim, TextSize = 13, Parent = detail })
		return
	end
	local pet = selected
	local color = Kit.rarityColor(pet.Rarity)
	Icons.Pet(detail, pet.Id, { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(10, 10) })
	Kit.label({ Size = UDim2.new(1, -78, 0, 22), Position = UDim2.fromOffset(72, 10), Text = pet.Name, TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = color, Parent = detail })
	Kit.label({ Size = UDim2.new(1, -78, 0, 16), Position = UDim2.fromOffset(72, 32), Text = ("%s  |  Lv %d / %d"):format(pet.Rarity, pet.Level, pet.MaxLevel), TextSize = 12, TextColor3 = C.Dim, Parent = detail })
	Kit.label({ Size = UDim2.new(1, -78, 0, 16), Position = UDim2.fromOffset(72, 48), Text = string.rep("★", pet.Rank or 1) .. string.rep("☆", (pet.MaxRank or 1) - (pet.Rank or 1)), TextSize = 13, TextColor3 = C.Accent, Parent = detail })
	Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 70), Text = ("IP %s"):format(NumberFormat.Short(Power.Pet(pet.Id, pet.Level, pet.Rank))), TextSize = 14, Font = Enum.Font.GothamBold, Parent = detail })
	Kit.label({ Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 90), Text = pet.Text or "", TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	if pet.Skill then
		Kit.label({ Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 136), RichText = true, TextSize = 11, TextYAlignment = Enum.TextYAlignment.Top, Text = ("<b>%s</b> (Lv %d)\n%s"):format(pet.Skill.Name, pet.Rank or 1, pet.Skill.Text), Parent = detail })
	end
	local maxed = (pet.Rank or 1) >= (pet.MaxRank or 1)
	Kit.label({ Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -86), TextSize = 11, TextColor3 = C.Dim, Text = if maxed then "Max rank - spare copies become shards" else ("Copies %d / %d for the next rank"):format(pet.Copies or 0, pet.RankCost or 1), Parent = detail })
	local canRank = not maxed and (pet.Copies or 0) >= (pet.RankCost or 1)
	local rankBtn = Kit.button({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 1, -66), Text = if maxed then "Max rank" elseif canRank then "Rank up!" else "Rank up", TextSize = 13, BackgroundColor3 = if canRank then C.Accent else C.PanelLight, TextColor3 = if canRank then Color3.fromRGB(30, 24, 10) else C.Dim, Parent = detail }, function()
		if canRank then
			call("RankUpPet", pet.Id)
		end
	end)
	rankBtn.Active = canRank
	Kit.button({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 1, -34), Text = if pet.Active then "Equipped" else "Equip", TextSize = 13, BackgroundColor3 = if pet.Active then C.PanelLight else C.Accent, TextColor3 = if pet.Active then C.Dim else Color3.fromRGB(30, 24, 10), Parent = detail }, function()
		if not pet.Active then
			call("EquipPet", pet.Id)
		end
	end)
end

-- Wishing Tree --------------------------------------------------------------
local WISH_THEMES = {
	Pet = {
		Title = "🌳  THE WISHING TREE", Sub = "Companion wishes  -  find a loyal friend  🐾", C1 = Color3.fromRGB(26, 92, 78), C2 = Color3.fromRGB(122, 196, 98),
		Card = Color3.fromRGB(24, 44, 40), Panel = Color3.fromRGB(18, 34, 32), Stroke = Color3.fromRGB(110, 214, 150), Mark = "🌳",
	},
	Skill = {
		Title = "📜  THE ARCANE ARCHIVE", Sub = "Skill wishes  -  learn a new technique  ✨", C1 = Color3.fromRGB(58, 38, 140), C2 = Color3.fromRGB(70, 140, 230),
		Card = Color3.fromRGB(34, 30, 64), Panel = Color3.fromRGB(24, 22, 48), Stroke = Color3.fromRGB(166, 146, 255), Mark = "📜",
	},
}
local WISH_RARITIES = { "Legendary", "Epic", "Rare", "Common" }

-- what a wish tier can give, grouped by the rarity of the pull: { { Rarity, Ids = {...} } }
local function wishPool(kind, tier, state)
	local groups = {}
	if kind == "Pet" then
		local PetCfg = require(Shared.Config.Pets)
		for _, rarity in ipairs(WISH_RARITIES) do
			if tier.Odds[rarity] then
				local ids = {}
				for _, id in ipairs(PetCfg.Order) do
					local def = PetCfg.Defs[id]
					if def and def.Wish and def.Rarity == rarity then
						table.insert(ids, id)
					end
				end
				table.insert(groups, { Rarity = rarity, Ids = ids })
			end
		end
	else
		local SkillsMod = require(Shared.Skills)
		local SkillProg = require(Shared.SkillProgress)
		local all = SkillsMod.Pool(state.Player.ClassId, state.Player.SubclassId)
		for _, rarity in ipairs(WISH_RARITIES) do
			if tier.Odds[rarity] then
				local ids = {}
				for _, id in ipairs(all) do
					if Abilities[id] and (SkillProg.IsSubclassSkill(id) or SkillProg.TierRank[SkillProg.BaseTier(id)] <= SkillProg.TierRank[rarity]) then
						table.insert(ids, id)
					end
				end
				table.insert(groups, { Rarity = rarity, Ids = ids })
			end
		end
	end
	return groups
end

local function wishPoolOverlay(container, kind, tier, state, theme, onClose)
	local overlay = Kit.frame({ Name = "WishPool", Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.Panel, ZIndex = 20, Parent = container })
	Kit.new("UIStroke", { Color = theme.Stroke, Thickness = 2, Parent = overlay })
	Kit.label({ Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(10, 4), Text = ("%s can give:"):format(tier.Name), TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = theme.Stroke, ZIndex = 21, Parent = overlay })
	Kit.button({ Size = UDim2.fromOffset(70, 26), Position = UDim2.new(1, -78, 0, 4), Text = "Back", TextSize = 13, ZIndex = 21, Parent = overlay }, onClose)
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -36), Position = UDim2.fromOffset(8, 32), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ZIndex = 21, Parent = overlay })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	if kind == "Skill" then
		Kit.label({ Size = UDim2.new(1, -8, 0, 28), Text = "A pull at a rarity can be any of these skills, received at that rarity. Subclass skills can always come up.", TextSize = 11, TextColor3 = C.Dim, ZIndex = 22, Parent = scroll })
	end
	for _, group in ipairs(wishPool(kind, tier, state)) do
		Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = ("%s  -  %s%%"):format(group.Rarity, tostring(tier.Odds[group.Rarity])), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Kit.rarityColor(group.Rarity), ZIndex = 22, Parent = scroll })
		local grid = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), BackgroundTransparency = 1, NoCorner = true, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(44, 44), CellPadding = UDim2.fromOffset(5, 5), Parent = grid })
		if #group.Ids == 0 then
			Kit.label({ Size = UDim2.new(1, 0, 0, 18), Text = "Nothing at this rarity yet.", TextSize = 11, TextColor3 = C.Dim, ZIndex = 22, Parent = grid })
		end
		for _, id in ipairs(group.Ids) do
			local cell = Kit.frame({ BackgroundTransparency = 1, NoCorner = true, ZIndex = 22, Parent = grid })
			if kind == "Pet" then
				local def = require(Shared.Config.Pets).Defs[id]
				local tile = Icons.Pet(cell, id, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new() })
				Kit.Hover(tile, function() return ("<b>%s</b>\n%s: %s"):format(def.DisplayName, (def.Skill and def.Skill.Name) or "Skill", (def.Skill and def.Skill.Text) or "") end)
			else
				local def = Abilities[id]
				local tile = Icons.Skill(cell, def, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(), Tier = group.Rarity })
				Kit.Hover(tile, function() return Tips.Skill(def, 1) end)
			end
		end
	end
end

local ODDS_SHORT = { Common = "C", Rare = "R", Epic = "E", Legendary = "L" }
function Screens.Wish(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local kind = extra.WishKind or "Pet"
	local info = state.Player.Wishing and state.Player.Wishing[kind]
	if not info then
		return
	end
	local function redraw()
		Screens.Wish(container, extra.State or state, call, extra)
	end
	for index, name in ipairs({ "Pet", "Skill" }) do
		Kit.button({ Size = UDim2.fromOffset(130, 28), Position = UDim2.fromOffset((index - 1) * 136, 0), Text = name .. " wishes", TextSize = 13, BackgroundColor3 = if name == kind then C.Accent else C.Panel, TextColor3 = if name == kind then Color3.fromRGB(30, 24, 10) else C.Text, Parent = container }, function()
			extra.WishKind = name
			extra.WishResults = nil
			extra.WishPool = nil
			redraw()
		end)
	end
	local pay = extra.WishPay or "Ticket"
	Kit.label({ Size = UDim2.fromOffset(120, 28), Position = UDim2.fromOffset(280, 0), Text = "Pay with:", TextSize = 12, TextColor3 = C.Dim, Parent = container })
	for index, method in ipairs({ "Ticket", "Currency" }) do
		local text = if method == "Ticket" then ("%s tickets (%d)"):format(kind, info.Tickets) else ("%s (%d)"):format(info.CurrencyName, info.Currency)
		Kit.button({ Size = UDim2.fromOffset(110, 28), Position = UDim2.fromOffset(336 + (index - 1) * 116, 0), Text = text, TextSize = 12, TextWrapped = false, BackgroundColor3 = if method == pay then C.Up else C.Panel, Parent = container }, function()
			extra.WishPay = method
			redraw()
		end)
	end

	-- the banner: it matches the side you are on (green and leafy for pets, violet and starry for skills)
	local theme = WISH_THEMES[kind]
	local banner = Kit.frame({ Name = "WishBanner", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = container })
	local gradient = Kit.new("UIGradient", { Color = ColorSequence.new(theme.C1, theme.C2), Parent = banner })
	Kit.new("UIStroke", { Color = theme.Stroke, Thickness = 2, Transparency = 0.2, Parent = banner })
	TweenService:Create(gradient, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.35, 0) }):Play()
	Kit.label({ Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromOffset(14, 0), Text = theme.Title, TextSize = 19, Font = Enum.Font.GothamBlack, TextWrapped = false, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, Parent = banner })
	Kit.label({ Size = UDim2.new(0.45, -14, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = theme.Sub, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, TextColor3 = Color3.fromRGB(240, 250, 240), TextStrokeTransparency = 0.6, Parent = banner })
	for i, glyph in ipairs({ "✦", "✧", "✦" }) do
		Kit.label({ Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0.5 + (i - 2) * 0.12, 0, 0, 4 + (i % 2) * 14), Text = glyph, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 220), TextTransparency = 0.35, TextStrokeTransparency = 1, Parent = banner })
	end

	-- left: the three tiers
	local left = Kit.frame({ Size = UDim2.new(0, 330, 1, -80), Position = UDim2.fromOffset(0, 80), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local function wish(tier, count)
		extra.WishResults = nil
		if extra.WishAnim and extra.WishAnim.Parent then
			extra.WishAnim:Destroy()
		end
		local ok, data = call("Wish", kind, tier.Id, pay, count)
		if ok then
			-- the results are stored first, so any redraw shows them; the animation plays over the panel and lifts to reveal them
			extra.WishResults = { Kind = kind, Rows = data.Results }
			redraw()
			local panel = container.Parent
			if panel and not extra.WishAnimOff then
				extra.WishAnim = require(script.Parent.WishAnim).Play(panel, kind, data.Results, function()
					extra.WishAnim = nil
				end)
			end
		end
	end
	for index, tier in ipairs(info.Tiers) do
		local card = Kit.frame({ Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, (index - 1) * 68), BackgroundColor3 = theme.Card, Parent = left })
		Kit.new("UIStroke", { Color = theme.Stroke, Thickness = 1, Transparency = 0.55, Parent = card })
		local odds = {}
		for _, r in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
			if tier.Odds[r] then
				table.insert(odds, Kit.tint(("%s %d%%"):format(ODDS_SHORT[r], tier.Odds[r]), Kit.rarityColor(r)))
			end
		end
		local cost = if pay == "Ticket" then ("%d ticket"):format(tier.Tickets) else ("%s %s"):format(Short(tier.Cost), info.CurrencyName)
		Kit.button({ Name = "PoolButton", Size = UDim2.fromOffset(56, 20), Position = UDim2.new(1, -206, 0, 5), Text = "📖 Pool", TextSize = 11, BackgroundColor3 = theme.C1, Parent = card }, function()
			extra.WishPool = tier.Id
			redraw()
		end)
		Kit.label({ Size = UDim2.new(1, -214, 0, 20), Position = UDim2.fromOffset(8, 4), Text = tier.Name, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = if tier.Unlocked then C.Text else C.Dim, Parent = card })
		Kit.label({ Size = UDim2.new(1, -150, 0, 34), Position = UDim2.fromOffset(8, 24), RichText = true, TextSize = 11, Text = if tier.Unlocked then (table.concat(odds, "  ") .. "\n" .. cost .. " each") else ("Reach stage %d to unlock"):format(tier.UnlockStage), TextColor3 = C.Dim, Parent = card })
		if not tier.Unlocked then
			card.BackgroundColor3 = Color3.fromRGB(22, 23, 34)
			Kit.label({ Size = UDim2.fromOffset(60, 50), Position = UDim2.new(1, -66, 0.5, -25), Text = "🔒", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = Color3.fromRGB(255, 190, 170), Parent = card })
		end
		if tier.Unlocked then
			local canOne = (pay == "Ticket" and info.Tickets >= tier.Tickets) or (pay == "Currency" and info.Currency >= tier.Cost)
			local canTen = (pay == "Ticket" and info.Tickets >= tier.Tickets * 10) or (pay == "Currency" and info.Currency >= tier.Cost * 10)
			local b1 = Kit.button({ Size = UDim2.fromOffset(64, 46), Position = UDim2.new(1, -140, 0.5, -23), Text = "Wish\nx1", TextSize = 12, BackgroundColor3 = if canOne then C.Up else C.Panel, Parent = card }, function()
				wish(tier, 1)
			end)
			local b10 = Kit.button({ Size = UDim2.fromOffset(64, 46), Position = UDim2.new(1, -70, 0.5, -23), Text = "Wish\nx10", TextSize = 12, BackgroundColor3 = if canTen then C.Accent else C.Panel, TextColor3 = if canTen then Color3.fromRGB(30, 24, 10) else C.Text, Parent = card }, function()
				wish(tier, 10)
			end)
			b1.Active, b10.Active = canOne, canTen
		end
	end
	if extra.WishPool then
		for _, tier in ipairs(info.Tiers) do
			if tier.Id == extra.WishPool then
				wishPoolOverlay(container, kind, tier, extra.State or state, theme, function()
					extra.WishPool = nil
					redraw()
				end)
			end
		end
	end
	local pityText = ("Guaranteed: Rare+ within %d wishes, Epic+ within %d%s"):format(info.LeftRare, info.LeftEpic, info.LeftLegendary and (", Legendary within " .. info.LeftLegendary) or "")
	if kind == "Skill" then
		pityText ..= ("\n%d skills not found yet - spare copies become skill XP"):format(info.Remaining or 0)
	end
	
	-- right: what you just got
	local right = Kit.frame({ Size = UDim2.new(1, -338, 1, -80), Position = UDim2.fromOffset(338, 80), BackgroundColor3 = theme.Panel, ClipsDescendants = true, Parent = container })
	Kit.new("UIStroke", { Color = theme.Stroke, Thickness = 1, Transparency = 0.5, Parent = right })
	Kit.label({ Size = UDim2.fromOffset(150, 150), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, 10), Text = theme.Mark, TextSize = 110, TextTransparency = 0.88, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = right })
	Kit.label({ Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 1, -32), Text = pityText, TextSize = 10, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Bottom, Parent = right })
	local res = extra.WishResults
	if not res or res.Kind ~= kind then
		Kit.label({ Size = UDim2.new(1, -16, 0, 80), Position = UDim2.fromOffset(8, 8), Text = if kind == "Pet" then "Wish for a companion. A duplicate is saved as a copy - spend copies on the Pets page to rank a pet up." else "Wish for skills. A copy at a higher rarity than yours waits for you to Upgrade it; spare copies become XP to rank a skill up (Skills page).", TextColor3 = C.Dim, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
		return
	end
	local grid = Kit.frame({ Size = UDim2.new(1, -12, 1, -46), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, NoCorner = true, Parent = right })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(48, 68), CellPadding = UDim2.fromOffset(3, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for index, rowData in ipairs(res.Rows) do
		local cell = Kit.frame({ BackgroundTransparency = 1, NoCorner = true, LayoutOrder = index, Parent = grid })
		local tile
		if kind == "Pet" then
			tile = Icons.Pet(cell, rowData.Id, { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(0, 0) })
		else
			local def = Abilities[rowData.Id]
			tile = Icons.Skill(cell, def, { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(0, 0), Tier = rowData.Rarity })
			Kit.Hover(tile, function() return Tips.Skill(def, 1) end)
		end
		local shown = if kind == "Pet" then (require(Shared.Config.Pets).Defs[rowData.Id] or {}).DisplayName else (Abilities[rowData.Id] or {}).DisplayName
		Kit.label({ Size = UDim2.new(1, 4, 0, 10), Position = UDim2.fromOffset(-2, 46), Text = shown or "", TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = cell })
		tile.BackgroundTransparency = 1
		TweenService:Create(tile, TweenInfo.new(0.25 + index * 0.06), { BackgroundTransparency = 0 }):Play()
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 55), Text = if rowData.New then "NEW!" elseif rowData.Upgrade then ("▲ " .. rowData.Rarity) elseif rowData.Copies then "+1 copy" elseif rowData.Shard then "+1 shard" else ("+%s xp"):format(Short(rowData.DupXP or 0)), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextColor3 = if rowData.New or rowData.Upgrade then Kit.rarityColor(rowData.Rarity) else C.Dim, Font = Enum.Font.GothamBold, Parent = cell })
	end
end

-- Ultimate -----------------------------------------------------------------
local function ultimateRows(scroll, state, call)
	local info = state.Party and state.Party.Ultimate
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Join a party to unlock a party ultimate.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	for _, id in ipairs(info.Options) do
		local def = UltCfg.Defs[id]
		local unlocked = info.Frontier >= def.UnlockStage
		local r = row(scroll, 64)
		Icons.Ultimate(r, def, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 10), Locked = not unlocked })
		Kit.Hover(r, function() return Tips.Ultimate(def, 1) end)
		Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(60, 0), Text = ("%s%s\n%s"):format(def.DisplayName, info.Chosen == id and "  (equipped)" or "", unlocked and def.Description or ("Unlocks at stage " .. def.UnlockStage)), TextColor3 = Kit.rarityColor(def.Rarity), Parent = r })
		if unlocked and info.Chosen ~= id then
			Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Equip", Parent = r }, function()
				call("SetUltimate", id)
			end)
		end
	end
end

function Screens.Ultimate(container, state, call)
	ultimateRows(list(container), state, call)
end

-- Party --------------------------------------------------------------------
function Screens.Party(container, state, call, extra)
	local scroll = list(container)
	local party = state.Party
	if not party then
		local r = row(scroll, 150)
		Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 4), Text = "Play with a partner: make a code and share it, or enter theirs.", Parent = r })
		Kit.button({ Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(8, 50), Text = "Create code", Parent = r }, function()
			call("CreateCode")
		end)
		local box = Kit.new("TextBox", { Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(8, 100), PlaceholderText = "Enter code", Text = "", BackgroundColor3 = C.Panel, TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 16, ClearTextOnFocus = false, Parent = r })
		Kit.corner(8).Parent = box
		Kit.button({ Size = UDim2.fromOffset(90, 44), Position = UDim2.fromOffset(166, 100), Text = "Join", Parent = r }, function()
			call("JoinByCode", box.Text)
		end)
		Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(270, 100), Text = "Friend invites and random matchmaking: coming soon", TextColor3 = C.Dim, TextSize = 12, Parent = r })
		return
	end

	local r = row(scroll, 60)
	local codeText = extra and extra.Code and ("Your code: " .. extra.Code .. "\n") or ""
	Kit.label({ Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0), Text = codeText .. ("Stage %d   Frontier %d"):format(party.Stage, party.Frontier), Parent = r })
	Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Leave", BackgroundColor3 = C.Bad, Parent = r }, function()
		call("Leave")
	end)
	if party.IsOpen then
		Kit.button({ Size = UDim2.fromOffset(150, 44), Parent = scroll, Text = "Show join code" }, function()
			local ok, code = call("CreateCode")
			if ok and extra then extra.Code = code end
		end)
	end

	local partner = party.Partner
	if not partner then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Waiting for a partner to join.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("Partner: %s (%s Lv %d) %s"):format(partner.Name, partner.ClassId, partner.Level, partner.IsCompanion and "starter ghost - a real partner replaces her" or (partner.Online and "online" or "ghost")), TextColor3 = C.Accent, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Their passives: " .. (#partner.PassiveIds > 0 and table.concat(partner.PassiveIds, ", ") or "none"), TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Their skills (you can reorder/swap; everything else is view-only)", TextColor3 = C.Dim, Parent = scroll })

	local ghost = table.clone(partner.GhostLoadout or {})
	for slot, id in ipairs(ghost) do
		local def = Abilities[id]
		local rr = row(scroll, 52)
		Icons.Skill(rr, def, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 6), Level = partner.SlotLevels[slot] or 1 })
		Kit.Hover(rr, function() return Tips.Skill(def, partner.SlotLevels[slot] or 1) end)
		Kit.label({ Size = UDim2.new(1, -230, 1, 0), Position = UDim2.fromOffset(56, 0), Text = ("%d. %s  Lv %d"):format(slot, def.DisplayName, partner.SlotLevels[slot] or 1), TextColor3 = Kit.rarityColor(def.Rarity), Parent = rr })
		if slot > 1 then
			Kit.button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -160, 0.5, -22), Text = "Up", Parent = rr }, function()
				ghost[slot], ghost[slot - 1] = ghost[slot - 1], ghost[slot]
				call("SetGhostLoadout", ghost)
			end)
		end
		-- swap with any other skill the partner owns
		Kit.button({ Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -108, 0.5, -22), Text = "Swap", Parent = rr }, function()
			local owned = {}
			for ownedId in pairs(partner.Owned or {}) do
				if not table.find(ghost, ownedId) then table.insert(owned, ownedId) end
			end
			table.sort(owned)
			if owned[1] then
				ghost[slot] = owned[1]
				call("SetGhostLoadout", ghost)
			end
		end)
	end
	if partner.CanRevert then
		Kit.button({ Size = UDim2.fromOffset(160, 44), Parent = scroll, Text = "Undo partner's edit" }, function()
			call("RevertMyGhost")
		end)
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Party ultimate (fires on its own when the shared gauge fills)", TextColor3 = C.Dim, Parent = scroll })
	ultimateRows(scroll, state, call)
end

-- Map ----------------------------------------------------------------------
-- Zones as rows; the zone you are in (or picked with the arrows) shows its ten
-- stages. Cleared and current stages can be fought again; the rest are locked.
function Screens.Map(container, state, call, extra)
	Kit.clear(container)
	local party = state.Party
	if not party then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Join or create a party to travel the map.", TextColor3 = C.Dim, Parent = container })
		return
	end
	extra = extra or {}
	local current = Zones.ForStage(party.Stage)
	local zoneIndex = extra.MapZone or current.Index
	local maxZone = Zones.IndexForStage(party.Frontier)
	zoneIndex = math.clamp(zoneIndex, 1, maxZone)
	local zone = Zones.ForStage((zoneIndex - 1) * 10 + 1)

	Kit.button({ Size = UDim2.fromOffset(44, 36), Position = UDim2.fromOffset(0, 0), Text = "<", Parent = container }, function()
		extra.MapZone = math.max(1, zoneIndex - 1)
		Screens.Map(Kit.clear(container) or container, state, call, extra)
	end)
	Kit.label({ Size = UDim2.new(1, -100, 0, 36), Position = UDim2.fromOffset(50, 0), Text = ("%s  (zone %d)"):format(zone.Name, zoneIndex), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, Font = Enum.Font.GothamBold, Parent = container })
	Kit.button({ Size = UDim2.fromOffset(44, 36), Position = UDim2.new(1, -44, 0, 0), Text = ">", Parent = container }, function()
		extra.MapZone = math.min(maxZone, zoneIndex + 1)
		Screens.Map(Kit.clear(container) or container, state, call, extra)
	end)

	-- the stages already cleared this season leave a reward to claim (the Shared StageRewards rules; the server pays it)
	local claimed = state.Player.StageClaims or {}
	local function status(stage)
		if claimed[stage] then
			return "Claimed"
		end
		return if stage < party.Frontier then "Ready" else "Locked"
	end
	local function readyCount()
		local n = 0
		for stage = 1, party.Frontier - 1 do
			if not claimed[stage] then
				n += 1
			end
		end
		return n
	end
	local function redraw()
		Screens.Map(Kit.clear(container) or container, state, call, extra)
	end

	for i = 0, 9 do
		local stage = zone.FirstStage + i
		local unlocked = stage <= party.Frontier
		local isCurrent = stage == party.Stage
		local label = tostring(stage) .. (Stages.IsBoss(stage) and "\nBOSS" or "")
		local px, py = (i % 5) * 92, 48 + (i // 5) * 68
		local button = Kit.button({
			Size = UDim2.fromOffset(84, 60),
			Position = UDim2.fromOffset(px, py),
			Text = label,
			BackgroundColor3 = if isCurrent then C.Accent elseif unlocked then C.PanelLight else C.Panel,
			TextColor3 = if unlocked then C.Text else C.Dim,
			Parent = container,
		}, function()
			if unlocked then
				call("SetStage", stage)
			end
		end)
		button.Active = unlocked
		local st = status(stage)
		if st ~= "Locked" then
			local ready = st == "Ready"
			local badge = Kit.button({
				Size = UDim2.fromOffset(28, 22), Position = UDim2.fromOffset(px + 58, py - 4), Text = if ready then "🎁" else "✔", TextSize = 14, ZIndex = 5,
				BackgroundColor3 = if ready then C.Accent else C.Panel, TextColor3 = if ready then Color3.fromRGB(30, 24, 10) else C.Good, Parent = container,
			}, function()
				if ready then
					call("ClaimStage", stage)
				end
			end)
			Kit.Hover(badge, function()
				return ("<b>Stage %d reward</b>\n%s\n%s"):format(stage, StageRewards.Text(stage), if ready then "Tap to claim" else "Claimed")
			end)
		elseif unlocked then
			Kit.Hover(button, function()
				return ("<b>Stage %d reward</b>\n%s\nClear this stage to unlock it"):format(stage, StageRewards.Text(stage))
			end)
		end
	end
	local waiting = readyCount()
	Kit.label({ Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(0, 188), Text = ("Fighting stage %d. Furthest: %d. Pick an earlier stage to farm it."):format(party.Stage, party.Frontier), TextColor3 = C.Dim, TextSize = 13, Parent = container })
	local claimAll = Kit.button({
		Size = UDim2.fromOffset(140, 26), Position = UDim2.new(1, -140, 0, 185), Text = if waiting > 0 then ("🎁 Claim all (%d)"):format(waiting) else "All claimed", TextSize = 13,
		BackgroundColor3 = if waiting > 0 then C.Accent else C.Panel, TextColor3 = if waiting > 0 then Color3.fromRGB(30, 24, 10) else C.Dim, Parent = container,
	}, function()
		if waiting > 0 then
			call("ClaimAllStages")
		end
	end)
	claimAll.Active = waiting > 0
end

Screens.Msg = msg
-- Bosses: the timed world boss (this server) and the season boss (every server) ---------------------
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then
		return ("%dd %dh"):format(seconds // 86400, (seconds % 86400) // 3600)
	elseif seconds >= 3600 then
		return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

function Screens.Boss(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local boss = extra.Boss
	if not boss then
		Kit.label({ Size = UDim2.fromScale(1, 1), Text = "Loading...", TextColor3 = C.Dim, Parent = container })
		return
	end
	local age = os.clock() - (extra.BossAt or os.clock())
	local tab = extra.BossTab or "World"
	local function redraw()
		Screens.Boss(container, state, call, extra)
	end
	local function refresh()
		if extra.RefreshBoss then
			extra.RefreshBoss()
		end
		redraw()
	end
	for index, name in ipairs({ "World", "Season" }) do
		local label = if name == "World" then "World boss" else "Season boss"
		Kit.button({ Size = UDim2.fromOffset(130, 28), Position = UDim2.fromOffset((index - 1) * 136, 0), Text = label, TextSize = 13, BackgroundColor3 = if name == tab then C.Accent else C.Panel, TextColor3 = if name == tab then Color3.fromRGB(30, 24, 10) else C.Text, Parent = container }, function()
			extra.BossTab = name
			extra.BossMsg = nil
			redraw()
		end)
	end

	local left = Kit.frame({ Size = UDim2.new(0, 250, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = C.PanelLight, Parent = container })
	local right = Kit.frame({ Size = UDim2.new(1, -258, 1, -34), Position = UDim2.fromOffset(258, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = right,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })
	local function tierRow(name, rewards, status, color)
		local r = Kit.frame({ Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = Color3.fromRGB(30, 33, 50), Parent = scroll })
		Kit.label({ Size = UDim2.new(1, -90, 0, 18), Position = UDim2.fromOffset(8, 3), Text = name, TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = color, Parent = r })
		Kit.label({ Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(8, 21), Text = table.concat(rewards, ", "), TextSize = 10, TextColor3 = C.Dim, TextWrapped = true, Parent = r })
		return r, status
	end
	local msg = extra.BossMsg
	local function note(text, y)
		Kit.label({ Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, y or -50), Text = text or "", TextSize = 11, TextColor3 = C.Accent, TextWrapped = true, Parent = left })
	end

	if tab == "World" then
		local w = boss.World
		Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), Text = "👹 " .. w.Name, TextSize = 16, Font = Enum.Font.GothamBold, Parent = left })
		if w.Active then
			local left_s = w.EndsIn - age
			Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 30), Text = ("It is roaming the plaza!\nEnds in %s"):format(clock(left_s)), TextSize = 12, TextColor3 = C.Good, TextWrapped = true, Parent = left })
			Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 68), Text = ("Your best fight: %s damage\nChallenges: %d"):format(Short(w.Damage), w.Challenges), TextSize = 12, Parent = left })
			local wait = math.max(0, w.CooldownLeft - age)
			local can = wait <= 0
			local text = if wait > 0 then ("Ready in %ds"):format(math.ceil(wait)) else "Challenge!"
			local b = Kit.button({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 110), Text = text, TextSize = 15, BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then Color3.fromRGB(30, 24, 10) else C.Text, Parent = left }, function()
				local ok, data = call("BossChallenge", "World")
				extra.BossMsg = if ok then nil else ("Could not challenge: " .. tostring(data))
				refresh()
			end)
			b.Active = can
			Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 156), Text = "A very hard fight in your arena: your party battles it until it falls. Only your best fight counts. Rewards arrive when the timer ends.", TextSize = 10, TextColor3 = C.Dim, TextWrapped = true, Parent = left })
		else
			Kit.label({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 34), Text = ("Not here right now.\nNext one in about %s"):format(clock(w.NextIn - age)), TextSize = 13, TextColor3 = C.Dim, TextWrapped = true, Parent = left })
		end
		note(msg)
		for _, tier in ipairs(w.Tiers) do
			local reached = tier.Id <= w.Reached
			tierRow(("%s  -  %s damage"):format(tier.Name, Short(tier.Need)), tier.Rewards, reached, if reached then C.Good else C.Text)
		end
	else
		local s = boss.Season
		Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), Text = "🗿 " .. s.Name, TextSize = 16, Font = Enum.Font.GothamBold, Parent = left })
		local bar = Kit.frame({ Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 32), BackgroundColor3 = Color3.fromRGB(20, 22, 30), Parent = left })
		Kit.frame({ Size = UDim2.fromScale(math.clamp(s.Fraction, 0, 1), 1), BackgroundColor3 = if s.Dead then C.Dim else C.Good, Parent = bar })
		Kit.label({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 52), Text = if s.Dead then "Defeated! Thank you, everyone." else ("%d%% health  -  all servers\nIt withers away in %s"):format(math.ceil(s.Fraction * 100), clock(s.EndsIn - age)), TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Parent = left })
		Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 84), Text = ("Your best fight: %s damage\nChallenges: %d  (need %s to share rewards)"):format(Short(s.Damage), s.Challenges, Short(s.MinContribution)), TextSize = 11, TextWrapped = true, Parent = left })
		local wait = math.max(0, s.CooldownLeft - age)
		local can = wait <= 0 and not s.Dead
		local text = if s.Dead then "Defeated" elseif wait > 0 then ("Ready in %ds"):format(math.ceil(wait)) else "Challenge!"
		local b = Kit.button({ Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 124), Text = text, TextSize = 14, BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then Color3.fromRGB(30, 24, 10) else C.Text, Parent = left }, function()
			local ok, data = call("BossChallenge", "Season")
			extra.BossMsg = if ok then nil else ("Could not challenge: " .. tostring(data))
			refresh()
		end)
		b.Active = can
		if s.Egg then
			Kit.button({ Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 166), Text = "🥚 Hatch the Colossus Egg", TextSize = 13, BackgroundColor3 = C.Up, Parent = left }, function()
				local ok, data = call("BossHatch")
				extra.BossMsg = if ok then ("It hatched: " .. tostring(data) .. "! Find it in Pets.") else ("Could not hatch: " .. tostring(data))
				refresh()
			end)
		end
		note(msg, -44)
		for _, t in ipairs(s.Thresholds) do
			local status = if t.Claimed then "Claimed" elseif t.Reached then "Ready" else "Locked"
			local color = if t.Claimed then C.Dim elseif t.Reached then C.Good else C.Text
			local r = tierRow(("%s  -  %s"):format(t.Name, status), t.Rewards, t.Reached, color)
			if t.Reached and not t.Claimed then
				local btn = Kit.button({ Size = UDim2.fromOffset(64, 30), Position = UDim2.new(1, -72, 0.5, -15), Text = "Claim", TextSize = 12, BackgroundColor3 = if s.Challenges >= s.MinContribution then C.Accent else C.Panel, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = r }, function()
					local ok, data = call("BossClaim", t.Id)
					extra.BossMsg = if ok then ("Claimed: " .. table.concat(data, ", ")) else (if data == "NoContribution" then "Challenge the boss at least once to share the rewards." else "Could not claim: " .. tostring(data))
					refresh()
				end)
				btn.Active = true
			end
		end
	end
end


return Screens
