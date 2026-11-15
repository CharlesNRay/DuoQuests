--[[
	QuestScreen (ModuleScript): the Quests window - daily quests and the season pass.
	  QuestScreen.Quests(container, state, call, extra)    extra.QuestTab = "Daily" | "Pass"
]]
local Kit = require(script.Parent.Kit)
local Consumables = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Consumables)
local C = Kit.Colors

local QuestScreen = {}

local function rewardText(r)
	local parts = {}
	if (r.Gold or 0) > 0 then table.insert(parts, "💰 " .. r.Gold) end
	if (r.Wishstones or 0) > 0 then table.insert(parts, "✨ " .. r.Wishstones) end
	if (r.Shards or 0) > 0 then table.insert(parts, "💠 " .. r.Shards) end
	if (r.SkillPicks or 0) > 0 then table.insert(parts, "Skill pick x" .. r.SkillPicks) end
	if (r.PassXP or 0) > 0 then table.insert(parts, "Pass XP " .. r.PassXP) end
	for id, count in pairs(r.Items or r.Tickets or {}) do
		local def = Consumables.Defs[id]
		table.insert(parts, ("%s x%d"):format(def and def.DisplayName or id, count))
	end
	return table.concat(parts, "   ")
end

local function bar(parent, fraction, position, size, color)
	local back = Kit.frame({ Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(28, 30, 44), Parent = parent })
	Kit.frame({ Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color or C.Accent, Parent = back })
	return back
end

-- one list of quests with a bonus row: the daily and the weekly tabs share it
-- opts = { Data, Intro, BonusTitle, ClaimQuest, ClaimBonus, BonusButton }
local function periodTab(area, opts, call)
	local daily = opts.Data
	if not daily then
		return
	end
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = area })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = opts.Intro, TextSize = 12, TextColor3 = C.Dim, Parent = scroll })
	for _, quest in ipairs(daily.Quests) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.label({ Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(10, 4), Text = quest.Text, TextSize = 14, Font = Enum.Font.GothamBold, Parent = row })
		bar(row, quest.Progress / quest.Goal, UDim2.fromOffset(10, 28), UDim2.new(1, -170, 0, 10), if quest.Done then C.Up else C.Accent)
		Kit.label({ Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(10, 42), Text = ("%d / %d      Reward: %s"):format(quest.Progress, quest.Goal, rewardText(daily.Reward)), TextSize = 11, TextColor3 = C.Dim, Parent = row })
		if quest.Claimed then
			Kit.label({ Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0.5, -20), Text = "Claimed ✓", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Up, Parent = row })
		else
			Kit.button({ Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0.5, -20), Text = if quest.Done then "Claim" else "In progress", BackgroundColor3 = if quest.Done then C.Up else C.Panel, Parent = row }, function()
				if quest.Done then
					call(opts.ClaimQuest, quest.Index)
				end
			end)
		end
	end
	local bonus = Kit.frame({ Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = C.PanelLight, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(10, 6), Text = opts.BonusTitle, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = bonus })
	Kit.label({ Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(10, 30), Text = "Reward: " .. rewardText(daily.Bonus), TextSize = 11, TextColor3 = C.Dim, Parent = bonus })
	if daily.BonusClaimed then
		Kit.label({ Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0.5, -20), Text = "Claimed ✓", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Up, Parent = bonus })
	else
		Kit.button({ Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0.5, -20), Text = if daily.BonusReady then "Claim" else opts.BonusButton, BackgroundColor3 = if daily.BonusReady then C.Up else C.Panel, Parent = bonus }, function()
			if daily.BonusReady then
				call(opts.ClaimBonus)
			end
		end)
	end
end

local function timeLeft(seconds)
	local days, hours = seconds // 86400, (seconds % 86400) // 3600
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %dm"):format(hours, (seconds % 3600) // 60)
end

local function passTab(area, state, call, extra, redraw)
	local pass = state.Player.Pass
	if not pass then
		return
	end
	Kit.label({ Size = UDim2.new(1, -160, 0, 20), Text = ("Season Pass   Level %d / %d"):format(pass.Level, pass.MaxLevel), TextSize = 15, Font = Enum.Font.GothamBold, Parent = area })
	bar(area, pass.XPInLevel / pass.XPPerLevel, UDim2.fromOffset(0, 24), UDim2.new(1, -160, 0, 10))
	Kit.label({ Size = UDim2.new(1, -160, 0, 14), Position = UDim2.fromOffset(0, 38), Text = ("%d / %d XP to the next level - earn Pass XP from quests and clearing stages"):format(pass.XPInLevel, pass.XPPerLevel), TextSize = 10, TextColor3 = C.Dim, Parent = area })
	local claimable = 0
	for _, r in ipairs(pass.Rows) do
		if r.Reached and not r.Claimed then
			claimable += 1
		end
		if r.Reached and pass.Premium and not r.PremiumClaimed then
			claimable += 1
		end
	end
	Kit.button({ Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -150, 0, 6), Text = if claimable > 0 then ("Claim all (%d)"):format(claimable) else "Nothing to claim", BackgroundColor3 = if claimable > 0 then C.Up else C.Panel, Parent = area }, function()
		if claimable > 0 then
			call("ClaimPass", "All")
		end
	end)
	-- column headers
	Kit.label({ Size = UDim2.fromOffset(100, 14), Position = UDim2.fromOffset(70, 56), Text = "FREE", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = C.Dim, Parent = area })
	Kit.label({ Size = UDim2.fromOffset(200, 14), Position = UDim2.new(0.5, 4, 0, 56), Text = if pass.Premium then "PREMIUM ★" else "PREMIUM ★ (locked)", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 200, 90), Parent = area })
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -74), Position = UDim2.fromOffset(0, 74), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = area })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })
	local gold = Color3.fromRGB(255, 200, 90)
	for _, r in ipairs(pass.Rows) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = if r.Reached then C.PanelLight else C.Panel, Parent = scroll })
		Kit.label({ Size = UDim2.fromOffset(60, 44), Position = UDim2.fromOffset(8, 0), Text = "Lv " .. r.Level, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = if r.Reached then C.Accent else C.Dim, Parent = row })
		-- free column
		Kit.label({ Size = UDim2.new(0.5, -170, 1, 0), Position = UDim2.fromOffset(70, 0), Text = rewardText(r.Reward), TextSize = 11, TextWrapped = true, TextColor3 = if r.Reached then C.Text else C.Dim, Parent = row })
		if r.Claimed then
			Kit.label({ Size = UDim2.fromOffset(70, 44), Position = UDim2.new(0.5, -96, 0, 0), Text = "Claimed ✓", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Up, Parent = row })
		elseif r.Reached then
			Kit.button({ Size = UDim2.fromOffset(70, 26), Position = UDim2.new(0.5, -96, 0.5, -13), Text = "Claim", TextSize = 11, BackgroundColor3 = C.Up, Parent = row }, function()
				call("ClaimPass", r.Level, "Free")
			end)
		end
		-- premium column
		Kit.label({ Size = UDim2.new(0.5, -110, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), Text = rewardText(r.PremiumReward), TextSize = 11, TextWrapped = true, TextColor3 = if pass.Premium and r.Reached then gold else C.Dim, Parent = row })
		if r.PremiumClaimed then
			Kit.label({ Size = UDim2.fromOffset(80, 44), Position = UDim2.new(1, -84, 0, 0), Text = "Claimed ✓", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Up, Parent = row })
		elseif not pass.Premium then
			Kit.label({ Size = UDim2.fromOffset(80, 44), Position = UDim2.new(1, -84, 0, 0), Text = "🔒", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, Parent = row })
		elseif r.Reached then
			Kit.button({ Size = UDim2.fromOffset(80, 26), Position = UDim2.new(1, -84, 0.5, -13), Text = "Claim", TextSize = 11, BackgroundColor3 = gold, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = row }, function()
				call("ClaimPass", r.Level, "Premium")
			end)
		end
	end
end

function QuestScreen.Quests(container, state, call, extra)
	Kit.clear(container)
	local tab = extra.QuestTab or "Daily"
	local function redraw()
		QuestScreen.Quests(container, extra.State or state, call, extra)
	end
	for index, name in ipairs({ "Daily", "Weekly", "Pass" }) do
		Kit.button({ Size = UDim2.fromOffset(150, 28), Position = UDim2.fromOffset((index - 1) * 156, 0), Text = if name == "Daily" then "Daily quests" elseif name == "Weekly" then "Weekly quests" else "Season pass", TextSize = 13, BackgroundColor3 = if name == tab then C.Accent else C.Panel, TextColor3 = if name == tab then Color3.fromRGB(30, 24, 10) else C.Text, Parent = container }, function()
			extra.QuestTab = name
			redraw()
		end)
	end
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	if tab == "Daily" then
		periodTab(area, { Data = state.Player.Quests, Intro = "New quests every day. Finish all three for a bonus.", BonusTitle = "Daily bonus", ClaimQuest = "ClaimQuest", ClaimBonus = "ClaimQuestBonus", BonusButton = "Finish all 3" }, call)
	elseif tab == "Weekly" then
		local weekly = state.Player.WeeklyQuests
		periodTab(area, { Data = weekly, Intro = weekly and ("Bigger quests that reset every Monday (%s left). Finish all four for a bonus."):format(timeLeft(weekly.SecondsLeft)) or "", BonusTitle = "Weekly bonus", ClaimQuest = "ClaimWeeklyQuest", ClaimBonus = "ClaimWeeklyBonus", BonusButton = "Finish all 4" }, call)
	else
		passTab(area, state, call, extra, redraw)
	end
end

return QuestScreen
