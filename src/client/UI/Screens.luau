--[[
	Screens (ModuleScript): Skills, Passives, Ultimate and Party panels.
	Each is a function (container, state, call) that redraws itself. `call`
	is call(action, ...) -> ok, data|reason and refreshes the state after.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local PassiveCfg = require(Shared.Config.Passives)
local UltCfg = require(Shared.Config.Ultimates)
local AbilityStats = require(Shared.Combat.AbilityStats)
local Passives = require(Shared.Passives)
local Skills = require(Shared.Skills)
local Zones = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Zones)
local Stages = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Stages)
local Kit = require(script.Parent.Kit)
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
		Kit.label({ Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(8, 4), Text = ("%d. %s  Lv %d"):format(slot, def.DisplayName, me.SlotLevels[slot]), TextColor3 = Kit.rarityColor(def.Rarity), Font = Enum.Font.GothamBold, Parent = r })
		Kit.label({ Size = UDim2.new(1, -150, 0, 40), Position = UDim2.fromOffset(8, 24), Text = statsText(def, me.SlotLevels[slot]), TextSize = 12, TextColor3 = C.Dim, Parent = r })
		if slot > 1 then
			Kit.button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -150, 0.5, -22), Text = "Up", Parent = r }, function()
				equipped[slot], equipped[slot - 1] = equipped[slot - 1], equipped[slot]
				call("EquipSkills", equipped)
			end)
		end
		local cost = require(Shared.Economy).SlotLevelCost(me.SlotLevels[slot])
		Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = cost and ("Level\n" .. cost .. "g") or "MAX", Parent = r }, function()
			call("LevelSlot", slot)
		end)
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
		Kit.label({ Size = UDim2.new(1, -120, 0, 20), Position = UDim2.fromOffset(8, 4), Text = def.DisplayName .. (isEquipped and "  (equipped)" or ""), TextColor3 = Kit.rarityColor(def.Rarity), Font = Enum.Font.GothamBold, Parent = r })
		Kit.label({ Size = UDim2.new(1, -120, 0, 32), Position = UDim2.fromOffset(8, 24), Text = def.Description or "", TextSize = 12, TextColor3 = C.Dim, Parent = r })
		if isOwned and not isEquipped then
			Kit.button({ Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -108, 0.5, -22), Text = "Equip in 4", Parent = r }, function()
				equipped[#equipped] = id
				call("EquipSkills", equipped)
			end)
		elseif not isOwned then
			Kit.button({ Size = UDim2.fromOffset(50, 44), Position = UDim2.new(1, -164, 0.5, -22), Text = "Pick", Parent = r }, function()
				call("UnlockSkillWithPick", id)
			end)
			Kit.button({ Size = UDim2.fromOffset(50, 44), Position = UDim2.new(1, -108, 0.5, -22), Text = "Shards", Parent = r }, function()
				call("UnlockSkill", id)
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

-- Gear ---------------------------------------------------------------------
function Screens.Gear(container, state, call)
	local gear = state.Player.Gear
	local scroll = list(container)
	local order = { "Weapon", "Armor", "Trinket" }
	for _, slotName in ipairs(order) do
		local item = gear.Equipped[slotName]
		local r = row(scroll, 52)
		if item then
			Kit.label({ Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s: %s  [%s]\n+%d %s  (from stage %d)"):format(slotName, item.Name, item.Rarity, math.floor(item.Value + 0.5), item.Stat, item.Power), TextColor3 = Kit.rarityColor(item.Rarity), Parent = r })
			Kit.button({ Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -108, 0.5, -20), Text = "Unequip", Parent = r }, function()
				call("UnequipGear", slotName)
			end)
		else
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = slotName .. ": empty", TextColor3 = C.Dim, Parent = r })
		end
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = ("Bag %d/%d  (gear drops from stages; a full bag sells new drops)"):format(#gear.Inventory, gear.Cap), TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
	for _, item in ipairs(gear.Inventory) do
		local r = row(scroll, 52)
		Kit.label({ Size = UDim2.new(1, -230, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s  [%s]\n%s +%d  (stage %d)"):format(item.Name, item.Rarity, item.Slot, math.floor(item.Value + 0.5), item.Power), TextColor3 = Kit.rarityColor(item.Rarity), Parent = r })
		Kit.button({ Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -216, 0.5, -20), Text = "Equip", Parent = r }, function()
			call("EquipGear", item.Id)
		end)
		Kit.button({ Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -108, 0.5, -20), Text = "Sell " .. item.SellValue .. "g", Parent = r }, function()
			call("SellGear", item.Id)
		end)
	end
end

-- Daily --------------------------------------------------------------------
function Screens.Daily(container, state, call)
	local daily = state.Player.Daily
	local scroll = list(container)
	local r = row(scroll, 110)
	local text = if daily.CanClaim then ("Day %d reward is ready!"):format(daily.NextDay) else ("Come back tomorrow for day %d."):format(daily.NextDay)
	local reward = daily.Reward
	local lines = { text, ("Gold %d   Shards %d%s"):format(reward.Gold, reward.Shards, reward.SkillPicks > 0 and ("   Skill pick " .. reward.SkillPicks) or ""), ("Current streak: %d day(s). Missing a day restarts at day 1."):format(daily.Streak) }
	Kit.label({ Size = UDim2.new(1, -16, 0, 70), Position = UDim2.fromOffset(8, 4), Text = table.concat(lines, "\n"), Parent = r })
	if daily.CanClaim then
		Kit.button({ Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(8, 64), Text = "Claim", BackgroundColor3 = C.Accent, Parent = r }, function()
			call("ClaimDaily")
		end)
	end
end

-- Ranks --------------------------------------------------------------------
-- extra.Board = reply of GetLeaderboard, extra.BoardCategory = "Stage"|"Level",
-- extra.ShowBoard(categoryId) switches tabs.
function Screens.Ranks(container, _, _, extra)
	local Leaderboards = require(Shared.Leaderboards)
	local scroll = list(container)
	local tabs = row(scroll, 44)
	for index, category in ipairs(Leaderboards.Categories) do
		Kit.button({
			Size = UDim2.fromOffset(150, 36), Position = UDim2.fromOffset(4 + (index - 1) * 158, 4), Text = category.Name,
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
function Screens.Pets(container, state, call)
	local scroll = list(container)
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "Pets follow you and add a small bonus. You get them by clearing stages; you keep them every season.", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	for _, pet in ipairs(state.Player.Pets or {}) do
		local r = row(scroll, 60)
		if pet.Owned then
			local title = ("%s  Lv %d/%d  [%s]%s"):format(pet.Name, pet.Level, pet.MaxLevel, pet.Rarity, pet.Active and "  (equipped)" or "")
			Kit.label({ Size = UDim2.new(1, -220, 1, 0), Position = UDim2.fromOffset(8, 0), Text = title .. "\n" .. pet.Text, TextColor3 = Kit.rarityColor(pet.Rarity), Parent = r })
			if not pet.Active then
				Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -204, 0.5, -22), Text = "Equip", Parent = r }, function()
					call("EquipPet", pet.Id)
				end)
			end
			if pet.Cost then
				Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Level\n" .. pet.Cost .. "g", Parent = r }, function()
					call("LevelPet", pet.Id)
				end)
			end
		else
			Kit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s  [%s]\nClear stage %d to get this pet"):format(pet.Name, pet.Rarity, pet.UnlockStage), TextColor3 = C.Dim, Parent = r })
		end
	end
end

-- Ultimate -----------------------------------------------------------------
function Screens.Ultimate(container, state, call)
	local scroll = list(container)
	local info = state.Party and state.Party.Ultimate
	if not info then
		Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Join a party to unlock a party ultimate.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	for _, id in ipairs(info.Options) do
		local def = UltCfg.Defs[id]
		local unlocked = info.Frontier >= def.UnlockStage
		local r = row(scroll, 64)
		Kit.label({ Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s%s\n%s"):format(def.DisplayName, info.Chosen == id and "  (equipped)" or "", unlocked and def.Description or ("Unlocks at stage " .. def.UnlockStage)), TextColor3 = Kit.rarityColor(def.Rarity), Parent = r })
		if unlocked and info.Chosen ~= id then
			Kit.button({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -100, 0.5, -22), Text = "Equip", Parent = r }, function()
				call("SetUltimate", id)
			end)
		end
	end
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
		Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%d. %s  Lv %d"):format(slot, def.DisplayName, partner.SlotLevels[slot] or 1), TextColor3 = Kit.rarityColor(def.Rarity), Parent = rr })
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
end

-- Map ----------------------------------------------------------------------
-- Zones as rows; the zone you are in (or picked with the arrows) shows its ten
-- stages. Cleared and current stages can be fought again; the rest are locked.
function Screens.Map(container, state, call, extra)
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

	for i = 0, 9 do
		local stage = zone.FirstStage + i
		local unlocked = stage <= party.Frontier
		local isCurrent = stage == party.Stage
		local label = tostring(stage) .. (Stages.IsBoss(stage) and "\nBOSS" or "")
		local button = Kit.button({
			Size = UDim2.fromOffset(84, 60),
			Position = UDim2.fromOffset((i % 5) * 92, 48 + (i // 5) * 68),
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
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 188), Text = ("Fighting stage %d. Furthest: %d. Pick an earlier stage to farm it."):format(party.Stage, party.Frontier), TextColor3 = C.Dim, TextSize = 13, Parent = container })
end

Screens.Msg = msg
return Screens
