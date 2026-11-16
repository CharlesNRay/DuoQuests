--[[
	MainMenu (ModuleScript): the first screen. Nobody spawns until they press Play on a character.
	  local menu = MainMenu.new(root, call, extra, CharacterScreen)
	  menu:Show(state) / menu:Hide() / menu:Render(state)   menu.Visible

	A character is just a class (see Shared/Characters). Up to state.Player.Character.MaxCharacters cards: a filled card
	(class, level, stage, Play) or an empty one that opens the class picker.
]]
local Kit = require(script.Parent.Kit)
local Branding = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Branding)
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
	self.Frame = Kit.frame({ Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 28), NoCorner = true, Visible = false, Active = true, ZIndex = 60, Parent = root })
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

local STAGE_W, STAGE_H = 700, 380

local function divider(parent, y, z)
	Kit.frame({ Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, y), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.75, NoCorner = true, ZIndex = z, Parent = parent })
end

-- one "Label ........ value" row inside a card
local function statRow(parent, y, label, value, z)
	Kit.label({ Size = UDim2.new(0.5, -14, 0, 18), Position = UDim2.fromOffset(14, y), Text = label, TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z, Parent = parent })
	Kit.label({ Size = UDim2.new(0.5, -14, 0, 18), Position = UDim2.new(0.5, 0, 0, y), Text = value, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = z, Parent = parent })
end

function MainMenu:Render(state)
	if not self.Visible or not state then
		return
	end
	Kit.clear(self.Body)
	local char = state.Player.Character
	-- everything sits in one centered stage so the spacing is the same on any screen shape
	local stage = Kit.frame({ Name = "Stage", Size = UDim2.fromOffset(STAGE_W, STAGE_H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = self.Body })

	if self.Creating then
		self.Extra.MenuCreate = true
		Kit.button({ Size = UDim2.fromOffset(90, 30), Position = UDim2.fromOffset(30, 0), Text = "< Back", TextSize = 13, ZIndex = 63, Parent = stage }, function()
			self.Creating = false
			self.Extra.MenuCreate = false
			self.Extra.CharMsg = nil
			self:Render(self.Extra.State)
		end)
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "NEW CHARACTER", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })
		local holder = Kit.frame({ Size = UDim2.fromOffset(640, 340), Position = UDim2.new(0.5, -320, 0, 38), BackgroundTransparency = 1, NoCorner = true, ZIndex = 62, Parent = stage })
		self.CharacterScreen.Character(holder, state, self.Call, self.Extra)
		return
	end
	self.Extra.MenuCreate = false

	-- title block
	if Branding.LogoImage ~= "" then
		Kit.new("ImageLabel", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0.5, -26, 0, -6), BackgroundTransparency = 1, Image = Branding.LogoImage, ScaleType = Enum.ScaleType.Fit, ZIndex = 62, Parent = stage })
	end
	Kit.label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, if Branding.LogoImage ~= "" then 44 else 0), Text = "DUO QUEST", TextSize = if Branding.LogoImage ~= "" then 28 else 38, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })
	Kit.label({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 46), Text = "SELECT A CHARACTER", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })

	local max = char and char.MaxCharacters or 2
	local list = char and char.Characters or {}
	local classes = {}
	for _, class in ipairs(char and char.Classes or {}) do
		classes[class.Id] = class
	end
	local cardW, cardH, gap, top = 290, 236, 28, 80
	local total = max * cardW + (max - 1) * gap
	local inGame = char and char.InGame
	for index = 1, max do
		local x = (STAGE_W - total) / 2 + (index - 1) * (cardW + gap)
		local entry = list[index]
		local card = Kit.frame({ Name = "Slot" .. index, Size = UDim2.fromOffset(cardW, cardH), Position = UDim2.fromOffset(x, top), BackgroundColor3 = C.Panel, ZIndex = 62, Parent = stage })
		if entry then
			local class = classes[entry.ClassId] or { Name = entry.ClassId }
			local color = C[entry.ClassId] or C.Accent
			local playing = entry.Active and inGame
			Kit.new("UIStroke", { Color = color, Thickness = 2, Parent = card })
			Kit.frame({ Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = color, NoCorner = true, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 22), Text = class.Name, TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 63, Parent = card })
			if playing then
				Kit.label({ Size = UDim2.fromOffset(80, 16), Position = UDim2.new(1, -94, 0, 22), Text = "PLAYING", TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = GOOD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 63, Parent = card })
			end
			divider(card, 66, 63)
			local path
			for _, p in ipairs(class.Paths or {}) do
				if p.Id == entry.SubclassId then
					path = p.Name
				end
			end
			statRow(card, 90, "Level", tostring(entry.Level), 63)
			statRow(card, 114, "Furthest stage", tostring(entry.HighestStage), 63)
			statRow(card, 138, "Path", path or "At level 30", 63)
			Kit.button({
				Name = "Play" .. index, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 1, -54), Text = if playing then "CONTINUE" else "PLAY",
				BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), TextSize = 16, ZIndex = 63, Parent = card,
			}, function()
				if playing then
					self:Hide()
				else
					self:Play(entry.Slot)
				end
			end)
		else
			Kit.new("UIStroke", { Color = C.Dim, Thickness = 1.5, Transparency = 0.6, Parent = card })
			card.BackgroundTransparency = 0.35
			Kit.label({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 38), Text = "+", TextSize = 54, Font = Enum.Font.GothamBlack, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 104), Text = "Empty slot", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.label({ Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(20, 126), Text = "A character is just a class.\nPick one to begin.", TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Parent = card })
			Kit.button({
				Name = "Create" .. index, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 1, -54), Text = "CREATE CHARACTER", TextSize = 14, ZIndex = 63, Parent = card,
			}, function()
				self.Creating = true
				self.Message = nil
				self.Extra.PickClass = nil
				self.Extra.CharMsg = nil
				self:Render(self.Extra.State)
			end)
		end
	end

	-- footer
	local foot = if self.Message then self.Message else ("Up to %d characters per account. Each keeps its own progress."):format(max)
	Kit.label({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, top + cardH + 14), Text = foot, TextSize = 12, TextColor3 = if self.Message then BAD else C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = stage })
end

return MainMenu
