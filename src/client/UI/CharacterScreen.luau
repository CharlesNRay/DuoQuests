--[[
	CharacterScreen (ModuleScript): the character creator (first join) and later the Character screen.
	  CharacterScreen.Character(container, state, call, extra)
	    extra.Char    = the draft being edited { Name, ClassId, Skin, Hair, Outfit, UseAvatar } (built from the saved character)
	    extra.CharMsg = last result text, extra.CharMsgBad = true for an error

	state.Player.Character = { Created, Name, Look, UseAvatar, Renames, RenameCost, Classes, NameMin, NameMax, Skins, Hairs, Outfits }.
	Before the character exists the screen creates it (name + class + look, once). After that the look can be changed for
	free and the name changed for Sunstones. Colour options are index lists kept by the server (Config/Character).
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local GOOD = Color3.fromRGB(130, 235, 150)
local BAD = Color3.fromRGB(255, 130, 120)
local ORANGE = Color3.fromRGB(255, 165, 70)

local REASONS = {
	TooShort = "That name is too short.",
	TooLong = "That name is too long.",
	BadCharacters = "Names can only use letters, numbers, spaces, - and _.",
	Blocked = "That name is not allowed. Try another.",
	BadClass = "Pick a class you can play.",
	AlreadyCreated = "Your character already exists.",
	NotEnough = "Not enough Sunstones to rename.",
}

local CharacterScreen = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function swatchRow(parent, y, title, colors, selected, onPick)
	Kit.label({ Size = UDim2.fromOffset(70, 28), Position = UDim2.fromOffset(0, y), Text = title, TextSize = 12, TextColor3 = C.Dim, Parent = parent })
	local x = 72
	for i, color in ipairs(colors) do
		local b = Kit.button({
			Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(x, y + 1), Text = "", BackgroundColor3 = rgb(color), Parent = parent,
		}, function()
			onPick(i)
		end)
		if i == selected then
			Kit.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Parent = b })
		end
		x += 30
	end
end

-- a small paper doll of the character: legs, body, head, hair
local function preview(parent, look, char)
	local box = Kit.frame({ Size = UDim2.fromOffset(110, 170), Position = UDim2.new(1, -118, 0, 4), BackgroundColor3 = C.Panel, Parent = parent })
	local outfit = rgb(char.Outfits[look.Outfit])
	Kit.frame({ Size = UDim2.fromOffset(40, 46), Position = UDim2.fromOffset(35, 112), BackgroundColor3 = outfit:Lerp(Color3.new(0, 0, 0), 0.45), Parent = box })
	Kit.frame({ Size = UDim2.fromOffset(56, 62), Position = UDim2.fromOffset(27, 56), BackgroundColor3 = outfit, Parent = box })
	local head = Kit.frame({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(35, 16), BackgroundColor3 = rgb(char.Skins[look.Skin]), Parent = box })
	Kit.corner(20).Parent = head
	Kit.frame({ Size = UDim2.fromOffset(42, 14), Position = UDim2.fromOffset(34, 10), BackgroundColor3 = rgb(char.Hairs[look.Hair]), Parent = box })
end

function CharacterScreen.Character(container, state, call, extra)
	Kit.clear(container)
	local char = state.Player.Character
	if char == nil then
		return
	end
	if extra.Char == nil then
		extra.Char = {
			Name = char.Name, ClassId = state.Player.ClassId, Skin = char.Look.Skin, Hair = char.Look.Hair, Outfit = char.Look.Outfit, UseAvatar = char.UseAvatar,
		}
	end
	local draft = extra.Char
	local creating = not char.Created

	local area = Kit.frame({ Name = "CharacterArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local function redraw()
		CharacterScreen.Character(container, state, call, extra)
	end

	Kit.label({ Size = UDim2.new(1, -130, 0, 20), Position = UDim2.fromOffset(8, 4), Text = if creating then "Create your hero - pick a name, a class and a look." else ("Your hero: %s"):format(char.Name), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = area })

	-- name
	local box = Kit.new("TextBox", {
		Name = "NameBox", Size = UDim2.new(1, -140, 0, 36), Position = UDim2.fromOffset(8, 30), BackgroundColor3 = C.PanelLight, TextColor3 = C.Text,
		PlaceholderText = ("Name (%d-%d letters)"):format(char.NameMin, char.NameMax), PlaceholderColor3 = C.Dim, Text = draft.Name or "",
		ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0, Parent = area,
	})
	Kit.corner(8).Parent = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		draft.Name = box.Text
	end)

	-- class (chosen once, when the character is created)
	local classArea = Kit.frame({ Size = UDim2.new(1, -140, 0, 36), Position = UDim2.fromOffset(8, 72), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	local x = 0
	for _, class in ipairs(char.Classes) do
		local chosen = draft.ClassId == class.Id
		local b = Kit.button({
			Size = UDim2.fromOffset(104, 34), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = if chosen then C.Accent else C.PanelLight,
			Text = if class.Playable then class.Name else (class.Name .. " (soon)"), TextSize = 13,
			TextColor3 = if class.Playable then (if chosen then Color3.fromRGB(20, 20, 30) else C.Text) else C.Dim, Parent = classArea,
		}, function()
			if creating and class.Playable then
				draft.ClassId = class.Id
				redraw()
			end
		end)
		b.Name = "Class_" .. class.Id
		x += 108
	end

	-- look
	local looks = Kit.frame({ Size = UDim2.new(1, -140, 0, 100), Position = UDim2.fromOffset(8, 114), BackgroundTransparency = 1, NoCorner = true, Parent = area })
	swatchRow(looks, 0, "Skin", char.Skins, draft.Skin, function(i) draft.Skin = i redraw() end)
	swatchRow(looks, 32, "Hair", char.Hairs, draft.Hair, function(i) draft.Hair = i redraw() end)
	swatchRow(looks, 64, "Outfit", char.Outfits, draft.Outfit, function(i) draft.Outfit = i redraw() end)
	preview(area, draft, char)

	local avatarButton = Kit.button({
		Name = "AvatarToggle", Size = UDim2.fromOffset(240, 30), Position = UDim2.fromOffset(8, 216), TextSize = 12,
		Text = if draft.UseAvatar then "[x] Roblox avatar in fights" else "[ ] Roblox avatar in fights (off)",
		BackgroundColor3 = C.PanelLight, Parent = area,
	}, function()
		draft.UseAvatar = not draft.UseAvatar
		redraw()
	end)
	avatarButton.TextXAlignment = Enum.TextXAlignment.Left

	if extra.CharMsg then
		Kit.label({ Name = "CharMsg", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 250), Text = extra.CharMsg, TextSize = 12, TextColor3 = if extra.CharMsgBad then BAD else GOOD, Parent = area })
	end

	local look = { Skin = draft.Skin, Hair = draft.Hair, Outfit = draft.Outfit }
	if creating then
		Kit.button({ Name = "CreateButton", Size = UDim2.fromOffset(200, 40), Position = UDim2.new(1, -208, 1, -46), Text = "Create hero", BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), Parent = area }, function()
			-- call() redraws the open screen from the new state when it succeeds, so set the message first
			extra.CharMsg, extra.CharMsgBad = "Welcome, " .. (draft.Name or "hero") .. "!", false
			local ok, reason = call("CreateCharacter", draft.Name or "", draft.ClassId, look, draft.UseAvatar)
			if ok then
				extra.Char = nil
			else
				extra.CharMsg, extra.CharMsgBad = REASONS[reason] or "Could not create the hero.", true
				redraw()
			end
		end)
	else
		Kit.button({ Name = "SaveLook", Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -366, 1, -46), Text = "Save look", BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), Parent = area }, function()
			extra.CharMsg, extra.CharMsgBad = "Look saved.", false
			if not call("UpdateCharacter", look, draft.UseAvatar) then
				extra.CharMsg, extra.CharMsgBad = "Could not save.", true
				redraw()
			end
		end)
		Kit.button({ Name = "RenameButton", Size = UDim2.fromOffset(200, 40), Position = UDim2.new(1, -208, 1, -46), Text = ("Rename  🔶 %d"):format(char.RenameCost), BackgroundColor3 = ORANGE, TextColor3 = Color3.fromRGB(40, 22, 6), Parent = area }, function()
			extra.CharMsg, extra.CharMsgBad = "Renamed.", false
			local ok, reason = call("RenameCharacter", draft.Name or "")
			if ok then
				extra.Char = nil
			else
				extra.CharMsg, extra.CharMsgBad = REASONS[reason] or "Could not rename.", true
				redraw()
			end
		end)
	end
end

return CharacterScreen
