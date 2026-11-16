--[[
	MainMenu (ModuleScript): the first screen. Nobody spawns until they press Play on a character.
	  local menu = MainMenu.new(root, call, extra, CharacterScreen)
	  menu:Show(state) / menu:Hide() / menu:Render(state)   menu.Visible

	A character is just a class (see Shared/Characters). Up to state.Player.Character.MaxCharacters cards: a filled card
	(class, level, stage, Play) or an empty one that opens the class picker.
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local GOOD = Color3.fromRGB(130, 235, 150)
local BAD = Color3.fromRGB(255, 130, 120)

local MainMenu = {}
MainMenu.__index = MainMenu

local REASONS = {
	Full = "You already have the maximum number of characters.",
	BadClass = "Pick a class you can play.",
	LeavePartyFirst = "Leave your party before switching characters.",
	BadSlot = "That character no longer exists.",
}

function MainMenu.new(root, call, extra, CharacterScreen)
	local self = setmetatable({ Visible = false, Creating = false, Message = nil }, MainMenu)
	self.Call, self.Extra, self.CharacterScreen = call, extra, CharacterScreen
	self.Frame = Kit.frame({ Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 28), NoCorner = true, Visible = false, ZIndex = 60, Parent = root })
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 60, 120), Color3.fromRGB(14, 16, 28)), Rotation = 90, Parent = self.Frame })
	self.Body = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, ZIndex = 61, Parent = self.Frame })
	extra.PlaySlot = function(slot)
		return self:Play(slot)
	end
	return self
end

function MainMenu:Show(state)
	self.Visible = true
	self.Creating = false
	self.Frame.Visible = true
	self:Render(state)
end

function MainMenu:Hide()
	self.Visible = false
	self.Frame.Visible = false
	self.Extra.MenuCreate = false
end

function MainMenu:Play(slot)
	local ok, reason = self.Call("PlayCharacter", slot)
	if ok then
		self:Hide()
		return true
	end
	self.Message = REASONS[reason] or "Could not play that character."
	self:Render(self.Extra.State)
	return false, reason
end

function MainMenu:Render(state)
	if not self.Visible or not state then
		return
	end
	Kit.clear(self.Body)
	local char = state.Player.Character
	local body = self.Body
	Kit.label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 18), Text = "DUO QUEST", TextSize = 40, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = body })

	if self.Creating then
		self.Extra.MenuCreate = true
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 66), Text = "Create a character: pick your class", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, ZIndex = 62, Parent = body })
		local holder = Kit.frame({ Size = UDim2.fromOffset(640, 340), Position = UDim2.new(0.5, -320, 0, 92), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = body })
		self.CharacterScreen.Character(holder, state, self.Call, self.Extra)
		Kit.button({ Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset(16, 18), Text = "< Back", ZIndex = 63, Parent = body }, function()
			self.Creating = false
			self.Extra.MenuCreate = false
			self.Extra.CharMsg = nil
			self:Render(self.Extra.State)
		end)
		return
	end
	self.Extra.MenuCreate = false

	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 66), Text = "Choose a character to play", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, ZIndex = 62, Parent = body })
	local max = char and char.MaxCharacters or 2
	local list = char and char.Characters or {}
	local classes = {}
	for _, class in ipairs(char and char.Classes or {}) do
		classes[class.Id] = class
	end
	local cardW, gap = 230, 24
	local total = max * cardW + (max - 1) * gap
	for index = 1, max do
		local x = -total / 2 + (index - 1) * (cardW + gap)
		local entry = list[index]
		local card = Kit.frame({ Name = "Slot" .. index, Size = UDim2.fromOffset(cardW, 250), Position = UDim2.new(0.5, x, 0, 104), BackgroundColor3 = C.Panel, ZIndex = 62, Parent = body })
		if entry then
			local class = classes[entry.ClassId] or { Name = entry.ClassId }
			local color = C[entry.ClassId] or C.Accent
			Kit.new("UIStroke", { Color = color, Thickness = 2, Parent = card })
			Kit.frame({ Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = color, NoCorner = true, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 16), Text = class.Name, TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = color, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 48), Text = class.Role or "", TextSize = 12, TextColor3 = C.Dim, ZIndex = 63, Parent = card })
			local path
			for _, p in ipairs(class.Paths or {}) do
				if p.Id == entry.SubclassId then
					path = p.Name
				end
			end
			Kit.label({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 82), Text = ("Level %d"):format(entry.Level), TextSize = 18, Font = Enum.Font.GothamBold, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 106), Text = ("Furthest stage %d"):format(entry.HighestStage), TextSize = 13, TextColor3 = C.Dim, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 126), Text = path and ("Path: " .. path) or "Path: chosen at level 30", TextSize = 13, TextColor3 = C.Dim, ZIndex = 63, Parent = card })
			if entry.Active and state.Player.Character.InGame then
				Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 150), Text = "Playing now", TextSize = 12, TextColor3 = GOOD, ZIndex = 63, Parent = card })
			end
			Kit.button({
				Name = "Play" .. index, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 1, -56), Text = if entry.Active and state.Player.Character.InGame then "Continue" else "Play",
				BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), TextSize = 18, ZIndex = 63, Parent = card,
			}, function()
				if entry.Active and state.Player.Character.InGame then
					self:Hide()
				else
					self:Play(entry.Slot)
				end
			end)
		else
			Kit.new("UIStroke", { Color = C.Dim, Thickness = 2, Transparency = 0.5, Parent = card })
			Kit.label({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 62), Text = "+", TextSize = 60, Font = Enum.Font.GothamBlack, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 130), Text = "Empty slot.\nCreating a character is just picking a class.", TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.button({
				Name = "Create" .. index, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 1, -56), Text = "Create character", TextSize = 16, ZIndex = 63, Parent = card,
			}, function()
				self.Creating = true
				self.Message = nil
				self.Extra.PickClass = nil
				self.Extra.CharMsg = nil
				self:Render(self.Extra.State)
			end)
		end
	end
	if self.Message then
		Kit.label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 362), Text = self.Message, TextSize = 13, TextColor3 = BAD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = body })
	end
end

return MainMenu
