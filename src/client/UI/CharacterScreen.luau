--[[
	CharacterScreen (ModuleScript): the class picker (first join) and later a "Your class" card.
	  CharacterScreen.Character(container, state, call, extra)
	    extra.PickClass = the class being previewed (before a class is chosen)
	    extra.CharMsg   = last result text, extra.CharMsgBad = true for an error

	state.Player.Character = { Created, Classes = { { Id, Name, Role, Blurb, WeaponName, WeaponText, Playable } } }.
	A player only picks a class: their Roblox name and avatar are used. Selecting a class previews its weapon (a local-only tool
	wielded on their own character, plus a small 3D view) and says what the class does. "Choose" saves it once and starts combat.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local ClassWeapons = require(ReplicatedStorage:WaitForChild("Shared").ClassWeapons)
local C = Kit.Colors

local GOOD = Color3.fromRGB(130, 235, 150)
local BAD = Color3.fromRGB(255, 130, 120)

local REASONS = {
	BadClass = "Pick a class you can play.",
	AlreadyCreated = "You already chose your class.",
	Full = "You already have the maximum number of characters.",
}

local CharacterScreen = {}

local previewTool = nil -- the local-only weapon being previewed

local function clearPreviewTool()
	if previewTool then
		pcall(function()
			previewTool:Destroy()
		end)
		previewTool = nil
	end
	local character = Players.LocalPlayer.Character
	local back = character and character:FindFirstChild("ClassBackPreview")
	if back then
		back:Destroy()
	end
end

-- Wield the class weapon on the player's own character (local only; the server gives the real one when the class is chosen).
local function wield(classId)
	clearPreviewTool()
	local player = Players.LocalPlayer
	local tool = ClassWeapons.Build(classId)
	if not tool then
		return
	end
	tool.Name = tool.Name .. " (preview)"
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		tool:Destroy()
		return
	end
	tool.Parent = backpack
	previewTool = tool
	ClassWeapons.AttachBack(player.Character, classId, "ClassBackPreview")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
end

-- A small 3D view of the weapon.
local function weaponView(parent, classId, size, position)
	local frame = Kit.new("ViewportFrame", {
		Size = size, Position = position, BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = parent,
		Ambient = Color3.fromRGB(190, 190, 200), LightColor = Color3.new(1, 1, 1),
	})
	Kit.corner(10).Parent = frame
	local tool = ClassWeapons.Build(classId)
	if not tool then
		return frame
	end
	local model = Instance.new("Model")
	for _, child in ipairs(tool:GetChildren()) do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	model.Parent = frame
	tool:Destroy()
	local cf, extent = model:GetBoundingBox()
	local radius = math.max(extent.X, extent.Y, extent.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(radius * 1.5, radius * 0.5, radius * 0.7), cf.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
	return frame
end

function CharacterScreen.Character(container, state, call, extra)
	Kit.clear(container)
	local char = state.Player.Character
	if char == nil then
		return
	end
	local classes = char.Classes
	local mine = state.Player.ClassId
	local creating = not char.Created or extra.MenuCreate == true
	local pick = if creating then extra.PickClass else mine
	if pick == nil then
		pick = if creating then classes[1].Id else mine
	end
	local selected
	for _, class in ipairs(classes) do
		if class.Id == pick then
			selected = class
		end
	end
	selected = selected or classes[1]

	local area = Kit.frame({ Name = "CharacterArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local function redraw()
		CharacterScreen.Character(container, state, call, extra)
	end

	Kit.label({
		Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 2), TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = area,
		Text = if creating then "Choose your class. Tap one to try its weapon." else ("Your class: %s"):format(selected.Name),
	})

	-- the class list
	local list = Kit.frame({ Size = UDim2.fromOffset(150, 252), Position = UDim2.fromOffset(8, 28), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	for index, class in ipairs(classes) do
		local isPick = class.Id == selected.Id
		local color = C[class.Id] or C.Accent
		local b = Kit.button({
			Name = "Class_" .. class.Id, Size = UDim2.fromOffset(150, 38), Position = UDim2.fromOffset(0, (index - 1) * 42),
			BackgroundColor3 = if isPick then color else C.PanelLight, TextSize = 14,
			TextColor3 = if isPick then Color3.fromRGB(20, 20, 30) else C.Text, Text = class.Name, Parent = list,
		}, function()
			if creating then
				extra.PickClass = class.Id
				wield(class.Id)
				redraw()
			end
		end)
		b.TextXAlignment = Enum.TextXAlignment.Left
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = b })
	end

	-- details
	local details = Kit.frame({ Size = UDim2.new(1, -176, 0, 292), Position = UDim2.fromOffset(168, 28), BackgroundColor3 = C.Panel, Parent = area })
	Kit.label({ Size = UDim2.new(1, -170, 0, 26), Position = UDim2.fromOffset(12, 8), Text = selected.Name, TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = C[selected.Id] or C.Accent, Parent = details })
	local blurb = (selected.Blurb or ""):gsub("%s*Paths:.*$", "")
	Kit.label({ Size = UDim2.new(1, -170, 0, 52), Position = UDim2.fromOffset(12, 34), Text = blurb, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
	-- the two paths, as their own cards so the choice is easy to see
	local classColor = C[selected.Id] or C.Accent
	Kit.label({ Size = UDim2.new(1, -170, 0, 16), Position = UDim2.fromOffset(12, 88), Text = "CHOOSE A PATH AT LEVEL 30", TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = classColor, Parent = details })
	local paths = selected.Paths or {}
	local cardW = if #paths > 0 then 1 / #paths else 1
	local holder = Kit.frame({ Size = UDim2.new(1, -170, 0, 66), Position = UDim2.fromOffset(12, 106), BackgroundTransparency = 1, NoCorner = true, Parent = details })
	for index, path in ipairs(paths) do
		local card = Kit.frame({ Size = UDim2.new(cardW, -4, 1, 0), Position = UDim2.new(cardW * (index - 1), if index == 1 then 0 else 4, 0, 0), BackgroundColor3 = C.PanelLight, Parent = holder })
		Kit.new("UIStroke", { Color = classColor, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		Kit.frame({ Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = classColor, NoCorner = true, Parent = card })
		Kit.label({ Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(6, 7), Text = path.Name, TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = classColor, Parent = card })
		Kit.label({ Size = UDim2.new(1, -10, 1, -26), Position = UDim2.fromOffset(6, 25), Text = path.Text or "", TextSize = 10, TextColor3 = C.Dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	end
	Kit.label({ Size = UDim2.new(1, -170, 0, 30), Position = UDim2.fromOffset(12, 176), Text = ("<b>Weapon: %s</b>  %s"):format(selected.WeaponName or "?", selected.WeaponText or ""), RichText = true, TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
	weaponView(details, selected.Id, UDim2.fromOffset(150, 150), UDim2.new(1, -160, 0, 8))

	if extra.CharMsg then
		Kit.label({ Name = "CharMsg", Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(12, 206), Text = extra.CharMsg, TextSize = 12, TextColor3 = if extra.CharMsgBad then BAD else GOOD, Parent = details })
	end

	if creating then
		Kit.button({
			Name = "ChooseButton", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 1, -54), Text = ("Choose %s"):format(selected.Name),
			BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), TextSize = 16, Parent = details,
		}, function()
			-- call() redraws the open screen from the new state when it succeeds
			extra.CharMsg, extra.CharMsgBad = ("You are a %s!"):format(selected.Name), false
			local ok, reason = call("MakeCharacter", selected.Id)
			if ok and extra.PlaySlot then
				clearPreviewTool() -- the server hands over the real weapon
				extra.PickClass = nil
				extra.MenuCreate = false
				-- the new character is the last slot
				local fresh = extra.State and extra.State.Player.Character.Characters or {}
				extra.PlaySlot(#fresh)
			else
				extra.CharMsg, extra.CharMsgBad = REASONS[reason] or "Could not choose that class.", true
				redraw()
			end
		end)
	else
		Kit.label({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.new(0, 12, 1, -50), Text = "Your weapon is in your backpack (press its number to wield it). Each character is one class.", TextSize = 12, TextColor3 = C.Dim, Parent = details })
		if extra.OpenMenu then
			Kit.button({ Name = "MainMenuButton", Size = UDim2.fromOffset(120, 30), Position = UDim2.new(1, -132, 0, 168), Text = "Main menu", TextSize = 13, Parent = details }, function()
				extra.OpenMenu()
			end)
		end
	end
end

return CharacterScreen
