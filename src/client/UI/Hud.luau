--[[
	Hud (ModuleScript): the always-visible battle view. Placeholder blocks for
	heroes, pets and enemies; a stage banner, party cards, ultimate hint and
	fight toast. Everything is built from plain Frames (no art assets).
]]
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Zones = require(ReplicatedStorage:WaitForChild("Shared").Zones)
local Stages = require(ReplicatedStorage:WaitForChild("Shared").Stages)
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local Hud = {}

local function block(parent, color, size, pos, text)
	local f = Kit.frame({ BackgroundColor3 = color, Size = size, Position = pos, Parent = parent })
	if text then
		Kit.label({ Size = UDim2.fromScale(1, 1), Text = text, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 12, Parent = f })
	end
	return f
end

local function bob(inst, amount, time)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(inst, info, { Position = inst.Position - UDim2.fromOffset(0, amount) }):Play()
end

function Hud.new(root)
	local self = {}
	local gui = Kit.frame({ Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = root })

	-- stage + toast
	self.Stage = Kit.label({ Size = UDim2.new(0, 420, 0, 28), Position = UDim2.new(0.5, -210, 0, 6), Text = "Stage -", TextSize = 20, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = gui })
	self.Toast = Kit.label({ Size = UDim2.new(0, 360, 0, 22), Position = UDim2.new(0.5, -180, 0, 34), Text = "", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Accent, Parent = gui })
	self.Fight = Kit.frame({ Size = UDim2.new(0, 260, 0, 6), Position = UDim2.new(0.5, -130, 0, 58), BackgroundColor3 = C.Panel, Parent = gui })
	self.FightFill = Kit.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = self.Fight })

	-- party cards (bottom left) and resources (top left)
	self.Cards = Kit.frame({ Size = UDim2.new(0, 360, 0, 74), Position = UDim2.new(0, 10, 1, -84), BackgroundTransparency = 0.2, Parent = gui })
	self.Res = Kit.label({ Size = UDim2.new(0, 260, 0, 40), Position = UDim2.new(0, 10, 0, 6), Text = "", Parent = gui })
	self.Ult = Kit.label({ Size = UDim2.new(0, 220, 0, 40), Position = UDim2.new(1, -230, 1, -84), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Parent = gui })

	self.Banner = Kit.label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0.3, 0), Text = "", TextSize = 36, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
	function self:ShowBanner(text, color)
		self.Banner.Text = text
		self.Banner.TextColor3 = color
		self.Banner.TextTransparency = 0
		TweenService:Create(self.Banner, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
	end

	self.Gui = gui
	self.Nav = Kit.frame({ Size = UDim2.new(0, 790, 0, 46), Position = UDim2.new(0.5, -395, 1, -54), BackgroundTransparency = 1, NoCorner = true, Parent = gui })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = self.Nav })

	function self:AddNav(text, onClick)
		return Kit.button({ Size = UDim2.new(0, 72, 0, 46), TextSize = 13, Text = text, Parent = self.Nav }, onClick)
	end

	function self:Render(state)
		local me = state.Player
		local party = state.Party
		local stage = party and party.Stage or me.Frontier
		local zone = Zones.ForStage(stage)
		self.Stage.Text = ("%s  -  Stage %d%s"):format(zone.Name, stage, Stages.IsBoss(stage) and "  BOSS" or "")
		self.Res.Text = string.format("Lv %d   Gold %d   Shards %d   Picks %d", me.Level, me.Gold, me.Shards, me.SkillPicks)

		Kit.clear(self.Cards)
		local lines = { me.Name .. " (" .. me.ClassId .. ")" }
		if party and party.Partner then
			local p = party.Partner
			table.insert(lines, p.Name .. " (" .. p.ClassId .. ") " .. (p.Online and "online" or "ghost"))
		elseif party then
			table.insert(lines, "Waiting for a partner...")
		else
			table.insert(lines, "No party - open Party")
		end
		Kit.label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = table.concat(lines, "\n"), Parent = self.Cards })

		local ult = party and party.Ultimate
		self.Ult.Text = if ult and ult.Chosen then "Ultimate: " .. tostring(ult.Chosen) else "Ultimate: needs a partner"
	end

	-- A fight just ended: show result and animate the wait bar.
	function self:OnFight(info)
		local text = info.Won and ("Stage " .. info.Stage .. " cleared!") or (info.TimedOut and "Time ran out - back a stage" or "Defeated - back a stage")
		if info.Reward then
			text ..= string.format("  +%d gold  +%d xp", info.Reward.Gold or 0, info.Reward.XP or 0)
			if info.Reward.Item then
				text ..= "  +" .. info.Reward.Item
			end
			if info.Reward.Pets and #info.Reward.Pets > 0 then
				text ..= "  NEW PET!"
			end
		end
		self.Toast.Text = text
		self.FightFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(self.FightFill, TweenInfo.new(math.max(0.5, info.Wait or 3), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	end

	return self
end

return Hud
