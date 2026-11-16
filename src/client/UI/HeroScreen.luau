--[[
	HeroScreen (ModuleScript): a character sheet for you and your party partner.

	  HeroScreen.Hero(container, state, call, extra)   extra.HeroTab = "You" | "Partner"

	Left: a turntable of the character (a copy of the real avatar for a real player, built from the
	player's Roblox look for an offline partner, or the plain class model for the starter ghost),
	name, class, level, path and pet. The worn gear is drawn on the avatar (weapon by the hand, armour on the chest, trinket at the neck). Right: stats, skills and passives.
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

local SLOTS = { "Helmet", "Amulet", "Armor", "Pants", "Weapon", "Ring1", "Ring2", "Boots" }

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
	-- the clone keeps the real character's world position and facing: bring it to the origin, facing the camera
	model:PivotTo(CFrame.new(0, 0, 0))
	-- frame the body only (accessories and tools can stretch the bounding box and push the hero away)
	local minV, maxV
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Accessory") and not d:FindFirstAncestorOfClass("Tool") and d.Name ~= "HumanoidRootPart" then
			local half = d.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						minV = if minV then Vector3.new(math.min(minV.X, corner.X), math.min(minV.Y, corner.Y), math.min(minV.Z, corner.Z)) else corner
						maxV = if maxV then Vector3.new(math.max(maxV.X, corner.X), math.max(maxV.Y, corner.Y), math.max(maxV.Z, corner.Z)) else corner
					end
				end
			end
		end
	end
	if not minV then
		local cf0, ext0 = model:GetBoundingBox()
		minV, maxV = cf0.Position - ext0 / 2, cf0.Position + ext0 / 2
	end
	local center = (minV + maxV) / 2
	model:PivotTo(model:GetPivot() - center)
	local height = math.clamp(maxV.Y - minV.Y, 2, 12)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -height * 2.1), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- the equipped pet stands beside the hero, so changing pets changes what you see
	local petModel
	if info.PetId then
		petModel = Models.Pet(info.PetId)
		petModel.Parent = viewport
		local bcf, ext = petModel:GetBoundingBox()
		petModel:PivotTo(CFrame.new(height * 0.42, -height / 2 + ext.Y / 2, -height * 0.12) * CFrame.Angles(0, math.rad(200), 0) * bcf:ToObjectSpace(petModel:GetPivot()))
	end
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

-- Worn gear sits around the avatar, head to feet: armour pieces down the left, weapon, rings and
-- boots down the right. Tiles are children of the viewport, so they float over the turntable.
local DOLL = {
	Helmet = { UDim2.new(0, 6, 0, 6), "Helmet" }, Amulet = { UDim2.new(0, 6, 0, 50), "Amulet" },
	Armor = { UDim2.new(0, 6, 0, 94), "Armor" }, Pants = { UDim2.new(0, 6, 0, 138), "Pants" },
	Weapon = { UDim2.new(1, -44, 0, 6), "Weapon" }, Ring1 = { UDim2.new(1, -44, 0, 50), "Ring" },
	Ring2 = { UDim2.new(1, -44, 0, 94), "Ring" }, Boots = { UDim2.new(1, -44, 0, 138), "Boots" },
}

local function gearOnDoll(viewport, worn)
	for _, slot in ipairs(SLOTS) do
		local spot = DOLL[slot]
		local item = worn[slot]
		if item then
			local tile = Icons.Item(viewport, item, { Size = UDim2.fromOffset(38, 38), Position = spot[1], Level = item.ItemPower })
			tile.ZIndex = 4
			Kit.Hover(tile, function() return Tips.Item(item, { Equipped = worn }) end)
		else
			local empty = Kit.frame({ Size = UDim2.fromOffset(38, 38), Position = spot[1], BackgroundColor3 = Color3.fromRGB(24, 26, 40), BackgroundTransparency = 0.3, ZIndex = 4, Parent = viewport })
			Kit.new("UIStroke", { Color = Color3.fromRGB(90, 98, 130), Thickness = 1, Parent = empty })
			Kit.label({ Size = UDim2.fromScale(1, 1), Text = spot[2], TextSize = 9, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 5, Parent = empty })
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

	-- left: the avatar with its gear around it
	local left = Kit.frame({ Size = UDim2.new(0, 250, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local viewport = turntable(left, hero, UDim2.new(1, 0, 1, 0))
	gearOnDoll(viewport, hero.Worn or {})
	local classDef = Classes[hero.ClassId]
	local pet = hero.PetId and PetConfig.Defs[hero.PetId]
	local subclass = hero.SubclassId and Subclasses.Defs[hero.SubclassId]
	local status = if hero.IsCompanion then "Starter ghost" elseif hero.Online then "Online" else "Ghost (offline)"

	-- right: scrolling sheet
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -260, 1, -38), Position = UDim2.fromOffset(260, 38), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = container,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, Text = ("%s  -  Lv %d  %s%s\n%s   -   %s"):format(hero.Name, hero.Level, classDef and classDef.DisplayName or hero.ClassId, subclass and ("  /  " .. subclass.DisplayName) or "", pet and ("Pet: %s Lv %d"):format(pet.DisplayName, hero.PetLevel or 1) or "No pet", status), TextSize = 13, Parent = scroll })

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
end

return HeroScreen
