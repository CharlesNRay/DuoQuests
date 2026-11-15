--[[
	HeroScreen (ModuleScript): a character sheet for you and your party partner.

	  HeroScreen.Hero(container, state, call, extra)   extra.HeroTab = "You" | "Partner"

	Left: a turntable of the character (a copy of the real avatar for a real player, built from the
	player's Roblox look for an offline partner, or the plain class model for the starter ghost),
	name, class, level, path and pet. Right: stats, skills, passives and the gear that is worn.
	Every skill, passive and item has the same hover tooltip as elsewhere.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local PassiveCfg = require(Shared.Config.Passives)
local PetConfig = require(Shared.Config.Pets)
local Classes = require(Shared.Config.Classes)
local Subclasses = require(Shared.Subclasses)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Tips = require(script.Parent.Tips)
local Models = require(script.Parent.Parent.Battle.Models)
local C = Kit.Colors

local HeroScreen = {}

local SLOTS = { "Weapon", "Armor", "Trinket" }

-- The avatar shown on the turntable ------------------------------------------
local avatarCache = {} -- [userId] = Model (kept so reopening the screen is instant)

local function stripToStatue(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function avatarFor(info)
	if info.UserId and avatarCache[info.UserId] then
		return avatarCache[info.UserId]:Clone()
	end
	local model
	if info.UserId and info.UserId > 0 then
		local player = Players:GetPlayerByUserId(info.UserId)
		if player and player.Character then
			player.Character.Archivable = true
			model = player.Character:Clone()
		end
		if not model then
			local ok, made = pcall(function()
				return Players:CreateHumanoidModelFromUserId(info.UserId)
			end)
			if ok then
				model = made
			end
		end
	end
	if not model then
		model = Models.Hero(info.ClassId)
	else
		stripToStatue(model)
		if info.UserId then
			avatarCache[info.UserId] = model:Clone()
		end
	end
	return model
end

local function turntable(parent, info, size)
	local viewport = Kit.new("ViewportFrame", {
		Size = size, BackgroundColor3 = Color3.fromRGB(34, 38, 58), BorderSizePixel = 0, Ambient = Color3.fromRGB(150, 150, 165),
		LightColor = Color3.fromRGB(255, 244, 224), LightDirection = Vector3.new(-1, -1, 1), Parent = parent,
	})
	Kit.corner(10).Parent = viewport
	local model = avatarFor(info)
	model.Parent = viewport
	local cf, extents = model:GetBoundingBox()
	local pivot = cf.Position
	model:PivotTo(model:GetPivot() * CFrame.new(-pivot.X, -pivot.Y, -pivot.Z) * CFrame.new(0, 0, 0))
	local height = math.max(extents.Y, 4)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.05, -height * 1.55), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local base = model:GetPivot()
	local angle = math.rad(200)
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			connection:Disconnect()
			return
		end
		angle += dt * 0.6
		model:PivotTo(CFrame.new(base.Position) * CFrame.Angles(0, math.sin(angle) * 0.9, 0) * base.Rotation)
	end)
	return viewport
end

-- helpers --------------------------------------------------------------------
local function section(parent, text)
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Text = text, TextColor3 = C.Accent, Font = Enum.Font.GothamBold, TextSize = 13, Parent = parent })
end

local function skillRow(parent, ids, levels)
	local holder = Kit.frame({ Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, NoCorner = true, Parent = parent })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = holder })
	for slot, id in ipairs(ids) do
		local def = Abilities[id]
		if def then
			local tile = Icons.Skill(holder, def, { Size = UDim2.fromOffset(48, 48), Level = levels[slot] or 1 })
			Kit.Hover(tile, function() return Tips.Skill(def, levels[slot] or 1) end)
		end
	end
	if #ids == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 24), Text = "No skills yet", TextColor3 = C.Dim, Parent = holder })
	end
end

local function gearTiles(parent, worn)
	local holder = Kit.frame({ Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, NoCorner = true, Parent = parent })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = holder })
	for _, slot in ipairs(SLOTS) do
		local item = worn[slot]
		local cell = Kit.frame({ Size = UDim2.new(1 / 3, -6, 0, 58), BackgroundColor3 = C.PanelLight, Parent = holder })
		if item then
			Icons.Item(cell, item, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(7, 7) })
			Kit.label({ Size = UDim2.new(1, -58, 1, 0), Position = UDim2.fromOffset(56, 0), Text = ("%s%s\n+%s %s"):format(item.Name, (item.Upgrade or 0) > 0 and (" +" .. item.Upgrade) or "", Tips.Num(item.Value), item.Stat), TextSize = 12, TextColor3 = if item.SetId then C.Set else Kit.rarityColor(item.Rarity), Parent = cell })
			Kit.Hover(cell, function() return Tips.Item(item, { Equipped = worn }) end)
		else
			Kit.label({ Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(8, 0), Text = slot .. "\nempty", TextSize = 12, TextColor3 = C.Dim, Parent = cell })
		end
	end
end

local function statGrid(parent, stats)
	local holder = Kit.frame({ Size = UDim2.new(1, 0, 0, math.ceil(#stats / 3) * 30), BackgroundTransparency = 1, NoCorner = true, Parent = parent })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.333, -4, 0, 28), CellPadding = UDim2.fromOffset(4, 2), Parent = holder })
	for _, stat in ipairs(stats) do
		local cell = Kit.frame({ BackgroundColor3 = C.PanelLight, Parent = holder })
		local color = if stat.Good == true then C.Good elseif stat.Good == false then C.Bad else C.Text
		Kit.label({ Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromOffset(6, 0), Text = stat.Label, TextSize = 12, TextColor3 = C.Dim, Parent = cell })
		Kit.label({ Size = UDim2.new(0.45, -6, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = stat.Value, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = color, Parent = cell })
	end
end

-- Normalise "you" and "partner" into one shape so one drawing routine serves both -----------------
local function describe(state, which)
	if which == "You" then
		local p = state.Player
		local pet
		for _, entry in ipairs(p.Pets or {}) do
			if entry.Active then
				pet = entry
			end
		end
		return {
			UserId = p.UserId, Name = p.Name, ClassId = p.ClassId, Level = p.Level, SubclassId = p.SubclassId,
			Skills = p.Loadout, SkillLevels = p.SlotLevels, PassiveIds = p.PassiveIds, PassiveLevels = p.PassiveLevels,
			PetId = pet and pet.Id, PetLevel = pet and pet.Level, Sheet = p.Sheet, Worn = p.Gear.Equipped, Online = true,
			XP = p.XP, XPNeeded = p.XPNeeded,
		}
	end
	local partner = state.Party and state.Party.Partner
	if not partner then
		return nil
	end
	return {
		UserId = partner.UserId, Name = partner.Name, ClassId = partner.ClassId, Level = partner.Level, SubclassId = partner.SubclassId,
		Skills = partner.GhostLoadout, SkillLevels = partner.SlotLevels, PassiveIds = partner.PassiveIds, PassiveLevels = partner.PassiveLevels or {},
		PetId = partner.PetId, PetLevel = partner.PetLevel, Sheet = partner.Sheet, Worn = (partner.Sheet and partner.Sheet.Gear) or {},
		Online = partner.Online, IsCompanion = partner.IsCompanion,
	}
end

function HeroScreen.Hero(container, state, _, extra)
	Kit.clear(container)
	extra = extra or {}
	local which = extra.HeroTab or "You"
	local hero = describe(state, which)
	if not hero and which == "Partner" then
		which = "You"
		hero = describe(state, "You")
	end

	-- tabs
	local hasPartner = describe(state, "Partner") ~= nil
	for index, name in ipairs({ "You", "Partner" }) do
		local enabled = name == "You" or hasPartner
		local b = Kit.button({ Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset((index - 1) * 116, 0), Text = name, BackgroundColor3 = if name == which then C.Accent else C.Panel, TextColor3 = if enabled then C.Text else C.Dim, Parent = container }, function()
			if enabled then
				extra.HeroTab = name
				HeroScreen.Hero(container, state, nil, extra)
			end
		end)
		b.Active = enabled
	end
	if not hasPartner then
		Kit.label({ Size = UDim2.new(1, -240, 0, 32), Position = UDim2.fromOffset(236, 0), Text = "Join a party to see your partner here.", TextColor3 = C.Dim, TextSize = 12, Parent = container })
	end

	-- left: the avatar and headline facts
	local left = Kit.frame({ Size = UDim2.new(0, 190, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	turntable(left, hero, UDim2.new(1, 0, 1, -92))
	local classDef = Classes[hero.ClassId]
	local pet = hero.PetId and PetConfig.Defs[hero.PetId]
	local subclass = hero.SubclassId and Subclasses.Defs[hero.SubclassId]
	local lines = {
		("%s  -  Lv %d"):format(hero.Name, hero.Level),
		("%s%s"):format(classDef and classDef.DisplayName or hero.ClassId, subclass and ("  /  " .. subclass.DisplayName) or ""),
		pet and ("Pet: %s Lv %d"):format(pet.DisplayName, hero.PetLevel or 1) or "No pet",
	}
	local status = if hero.IsCompanion then "Starter ghost" elseif hero.Online then "Online" else "Ghost (offline)"
	Kit.label({ Size = UDim2.new(1, 0, 0, 88), Position = UDim2.new(0, 0, 1, -88), Text = table.concat(lines, "\n") .. "\n" .. status, TextSize = 13, Parent = left })

	-- right: scrolling sheet
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -200, 1, -38), Position = UDim2.fromOffset(200, 38), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = container,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })

	section(scroll, "STATS  (with gear, passives and pet)")
	if hero.Sheet then
		statGrid(scroll, hero.Sheet.Stats)
	end
	section(scroll, "SKILLS  (cast order, left to right)")
	skillRow(scroll, hero.Skills or {}, hero.SkillLevels or {})
	section(scroll, "PASSIVES")
	if #(hero.PassiveIds or {}) == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "None equipped yet", TextColor3 = C.Dim, TextSize = 12, Parent = scroll })
	end
	for index, id in ipairs(hero.PassiveIds or {}) do
		local def = PassiveCfg.Defs[id]
		if def then
			local level = (hero.PassiveLevels or {})[index] or 1
			local r = Kit.frame({ Size = UDim2.new(1, -8, 0, 26), BackgroundColor3 = C.PanelLight, Parent = scroll })
			Kit.label({ Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s   Lv %d"):format(def.DisplayName, level), TextSize = 13, TextColor3 = Kit.rarityColor(def.Rarity), Parent = r })
			Kit.Hover(r, function() return Tips.Passive(def, level) end)
		end
	end
	section(scroll, "GEAR")
	gearTiles(scroll, hero.Worn or {})
end

return HeroScreen
