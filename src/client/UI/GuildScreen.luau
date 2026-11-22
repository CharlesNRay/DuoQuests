--[[
	GuildScreen (ModuleScript): the Guild window.
	  GuildScreen.Guild(container, state, call, extra)
	extra.Guild (the last GuildState reply), extra.GuildTab, extra.GuildMsg, extra.Raw(action, ...) (no redraw)

	Not in a guild: browse guilds and create one. In a guild: Overview, Members, Missions, Upgrades, Raid, Pets.
]]
local Short = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Guilds)
local PetConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Pets)
local C = Kit.Colors
local DARK = Color3.fromRGB(30, 24, 10)

local GuildScreen = {}

local REASONS = {
	NotAllowed = "Only the leader (or an officer) can do that.", NotEnoughPoints = "Not enough guild points.", MaxLevel = "Already at max level.",
	NameTaken = "That name is taken.", BadName = "Name: 3-20 letters, numbers and spaces.", BadTag = "Tag: 2-4 letters or numbers.",
	Inappropriate = "That text was filtered.", NotEnoughGold = "Not enough gold.", LevelTooLow = "Your level is too low.",
	Full = "That guild is full.", NoAttempts = "No battles left today.", Defeated = "The boss is already down.",
	NotEnoughMarks = "Not enough Guild Marks.", TooFast = "Wait a moment before sending another message.", ChatOff = "Chat is turned off for your account.", Empty = "Type a message first.", LeaderCannotLeave = "Hand over leadership first.", Unavailable = "Guild service is busy, try again.",
	AlreadyInGuild = "You are already in a guild.", NotDone = "Not finished yet.", NoShare = "You did not help with that one.",
}

local function span(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then return ("%dd %dh"):format(seconds // 86400, seconds % 86400 // 3600) end
	if seconds >= 3600 then return ("%dh %dm"):format(seconds // 3600, seconds % 3600 // 60) end
	return ("%dm"):format(seconds // 60)
end

local function bar(parent, fraction, position, size, color)
	local back = Kit.frame({ Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(28, 30, 44), Parent = parent })
	Kit.frame({ Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color or C.Accent, Parent = back })
	return back
end

local function rewardText(r)
	local parts = {}
	if (r.GoldClears or r.Gold or 0) > 0 then table.insert(parts, "💰 gold") end
	if (r.Wishstones or 0) > 0 then table.insert(parts, "💎 " .. r.Wishstones) end
	if (r.Marks or 0) > 0 then table.insert(parts, "🏅 " .. r.Marks .. " marks") end
	return table.concat(parts, "   ")
end

local function scroller(parent, size, position)
	local scroll = Kit.new("ScrollingFrame", { Size = size or UDim2.fromScale(1, 1), Position = position or UDim2.new(), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = parent })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = scroll })
	return scroll
end

local function input(parent, props)
	local box = Kit.new("TextBox", {
		BackgroundColor3 = C.Panel, TextColor3 = C.Text, PlaceholderColor3 = C.Dim, Font = Enum.Font.Gotham, TextSize = 13,
		ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
	for k, v in pairs(props) do box[k] = v end
	Kit.corner(6).Parent = box
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = box })
	return box
end

function GuildScreen.Guild(container, state, call, extra)
	Kit.clear(container)
	local data = extra.Guild
	local function redraw()
		GuildScreen.Guild(container, extra.State or state, call, extra)
	end
	local function act(action, ...)
		local ok, reply = call(action, ...)
		if ok then
			extra.Guild = reply
			extra.GuildMsg = nil
		else
			extra.GuildMsg = REASONS[tostring(reply)] or ("Could not do that: " .. tostring(reply))
		end
		redraw()
		return ok, reply
	end
	if data == nil then
		Kit.label({ Size = UDim2.fromScale(1, 0.5), Text = "Loading your guild...", TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = container })
		return
	end
	local msg = extra.GuildMsg
	if msg then
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), Text = msg, TextSize = 12, TextColor3 = C.Accent, ZIndex = 6, Parent = container })
	end

	---------------------------------------------------------------- not in a guild
	local g = data.Guild
	if g == nil then
		local left = Kit.frame({ Size = UDim2.new(0.58, -4, 1, -18), BackgroundTransparency = 1, NoCorner = true, Parent = container })
		local search = input(left, { Size = UDim2.new(1, -80, 0, 28), PlaceholderText = "Search guilds by name or tag", Text = extra.GuildQuery or "" })
		local function runSearch()
			extra.GuildQuery = search.Text
			local ok, result = extra.Raw("GuildSearch", search.Text)
			extra.GuildResults = if ok then result.Guilds else {}
			redraw()
		end
		search.FocusLost:Connect(function(enter) if enter then runSearch() end end)
		Kit.button({ Size = UDim2.fromOffset(72, 28), Position = UDim2.new(1, -72, 0, 0), Text = "Search", TextSize = 12, Parent = left }, runSearch)
		if extra.GuildResults == nil then
			local ok, result = extra.Raw("GuildSearch", "")
			extra.GuildResults = if ok then result.Guilds else {}
		end
		local list = scroller(left, UDim2.new(1, 0, 1, -34), UDim2.fromOffset(0, 34))
		if #extra.GuildResults == 0 then
			Kit.label({ Size = UDim2.new(1, -8, 0, 40), Text = "No guilds found. Start your own!", TextColor3 = C.Dim, Parent = list })
		end
		for _, row in ipairs(extra.GuildResults) do
			local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = C.PanelLight, Parent = list })
			Kit.label({ Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(8, 3), Text = ("[%s] %s"):format(row.Tag, row.Name), TextSize = 14, Font = Enum.Font.GothamBold, Parent = card })
			Kit.label({ Size = UDim2.new(1, -110, 0, 26), Position = UDim2.fromOffset(8, 23), Text = ("%d/%d members  ·  %s%s"):format(row.Count, row.Capacity, if row.Open then "Open" else "Request", if row.MinLevel > 1 then ("  ·  Lv %d+"):format(row.MinLevel) else "") .. (if row.Desc ~= "" then "\n" .. row.Desc else ""), TextSize = 10, TextColor3 = C.Dim, Parent = card })
			Kit.button({ Size = UDim2.fromOffset(84, 30), Position = UDim2.new(1, -92, 0.5, -15), Text = if row.Open then "Join" else "Request", TextSize = 12, BackgroundColor3 = C.Up, Parent = card }, function()
				local ok, reply = act("GuildJoin", row.Id)
				if ok and reply.Joined == "Requested" then
					extra.GuildMsg = "Request sent. A guild officer has to accept it."
					redraw()
				end
			end)
		end
		-- create
		local right = Kit.frame({ Size = UDim2.new(0.42, -4, 1, -18), Position = UDim2.new(0.58, 4, 0, 0), BackgroundColor3 = C.Panel, Parent = container })
		Kit.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), Text = "Found a guild", TextSize = 16, Font = Enum.Font.GothamBold, Parent = right })
		local nameBox = input(right, { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 34), PlaceholderText = "Guild name", Text = extra.GuildNewName or "" })
		local tagBox = input(right, { Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.fromOffset(8, 68), PlaceholderText = "TAG", Text = extra.GuildNewTag or "" })
		local open = extra.GuildNewOpen ~= false
		Kit.button({ Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.new(0.5, 4, 0, 68), Text = if open then "Open to all" else "Request only", TextSize = 12, Parent = right }, function()
			extra.GuildNewName, extra.GuildNewTag, extra.GuildNewOpen = nameBox.Text, tagBox.Text, not open
			redraw()
		end)
		Kit.label({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 102), Text = ("Costs %s gold. You need level %d.\nMembers share missions and a weekly raid boss, and you choose the guild upgrades together."):format(Short(data.Create.Gold), data.Create.MinLevel), TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
		Kit.button({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 1, -42), Text = "Create guild", BackgroundColor3 = C.Accent, TextColor3 = DARK, Parent = right }, function()
			extra.GuildNewName, extra.GuildNewTag = nil, nil
			act("GuildCreate", nameBox.Text, tagBox.Text, open)
		end)
		return
	end

	---------------------------------------------------------------- in a guild
	local isLeader, canManage = g.Rank == "Leader", g.Rank == "Leader" or g.Rank == "Officer"
	local tab = extra.GuildTab or "Overview"
	local waiting = { Missions = false, Raid = g.Raid.CanClaim or g.Raid.PrevClaim or (g.Raid.Attempts > 0 and not g.Raid.Defeated), Members = #g.Requests > 0 }
	for _, kind in ipairs({ g.Daily, g.Weekly }) do
		for _, row in ipairs(kind.Rows) do
			if row.CanClaim then waiting.Missions = true end
		end
	end
	local names = { "Overview", "Members", "Missions", "Upgrades", "Raid", "Pets", "Chat" }
	for index, name in ipairs(names) do
		local b = Kit.button({ Size = UDim2.fromOffset(84, 28), Position = UDim2.fromOffset((index - 1) * 88, 0), Text = name, TextSize = 13, BackgroundColor3 = if name == tab then C.Accent else C.Panel, TextColor3 = if name == tab then DARK else C.Text, Parent = container }, function()
			extra.GuildTab = name
			extra.GuildMsg = nil
			redraw()
		end)
		if waiting[name] then
			Kit.corner(7).Parent = Kit.frame({ Name = "RedDot", Size = UDim2.fromOffset(13, 13), Position = UDim2.new(1, -9, 0, -4), BackgroundColor3 = C.Bad, ZIndex = 4, Parent = b })
		end
	end
	Kit.label({ Size = UDim2.new(1, -620, 0, 28), Position = UDim2.fromOffset(618, 0), Text = ("🏅 %d marks   ✨ %d pts"):format(data.Marks, g.Points), TextSize = 12, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = container })
	local area = Kit.frame({ Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })

	if tab == "Overview" then
		local left = Kit.frame({ Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), Text = ("[%s] %s"):format(g.Tag, g.Name), TextSize = 18, Font = Enum.Font.GothamBlack, Parent = left })
		Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 32), Text = (if g.Desc ~= "" then g.Desc else "No description yet.") .. ("\n%d / %d members  ·  %s  ·  you are %s"):format(g.Count, g.Capacity, if g.Open then "Open" else "Request only", g.Rank), TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
		local y = 76
		if canManage then
			local desc = input(left, { Size = UDim2.new(1, -92, 0, 26), Position = UDim2.fromOffset(8, y), PlaceholderText = "Description", Text = g.Desc })
			Kit.button({ Size = UDim2.fromOffset(72, 26), Position = UDim2.new(1, -80, 0, y), Text = "Save", TextSize = 12, Parent = left }, function() act("GuildInfo", { Desc = desc.Text }) end)
			Kit.button({ Size = UDim2.new(0.5, -12, 0, 26), Position = UDim2.fromOffset(8, y + 32), Text = if g.Open then "Open to all" else "Request only", TextSize = 12, Parent = left }, function() act("GuildInfo", { Open = not g.Open }) end)
			Kit.button({ Size = UDim2.new(0.5, -12, 0, 26), Position = UDim2.new(0.5, 4, 0, y + 32), Text = ("Min level: %d (+5)"):format(g.MinLevel), TextSize = 12, Parent = left }, function() act("GuildInfo", { MinLevel = if g.MinLevel >= 50 then 1 else g.MinLevel + 5 }) end)
			y += 64
		end
		local leaving = g.Count > 1 and isLeader
		Kit.button({ Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -36), Text = if extra.GuildConfirm == "Leave" then "Tap again to confirm" elseif g.Count == 1 then "Disband guild" else "Leave guild", TextSize = 12, BackgroundColor3 = if extra.GuildConfirm == "Leave" then C.Down else C.Panel, Parent = left }, function()
			if leaving then
				extra.GuildMsg = "Hand leadership to someone (Members tab) before you leave."
				redraw()
			elseif extra.GuildConfirm == "Leave" then
				extra.GuildConfirm = nil
				extra.GuildTab = "Overview"
				act("GuildLeave")
			else
				extra.GuildConfirm = "Leave"
				redraw()
			end
		end)
		local right = Kit.frame({ Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 6), Text = "Guild perks (active for every member)", TextSize = 13, Font = Enum.Font.GothamBold, Parent = right })
		local lines = {}
		for _, up in ipairs(g.Upgrades) do
			if up.Level > 0 then
				table.insert(lines, if up.Plain then ("%s: +%d slots"):format(up.Name, up.Value) else ("%s: +%.1f%% %s"):format(up.Name, up.Value * 100, up.Text))
			end
		end
		Kit.label({ Size = UDim2.new(1, -16, 0, 96), Position = UDim2.fromOffset(8, 28), Text = if #lines > 0 then table.concat(lines, "\n") else "No upgrades yet. Finish missions to earn guild points, then the leader spends them.", TextSize = 11, TextColor3 = C.Text, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
		local log = {}
		for index, entry in ipairs(g.Log) do
			if index > 5 then break end
			table.insert(log, "• " .. entry.Text)
		end
		Kit.label({ Size = UDim2.new(1, -16, 0, 80), Position = UDim2.new(0, 8, 1, -84), Text = "Recent\n" .. table.concat(log, "\n"), TextSize = 10, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
	elseif tab == "Members" then
		local list = scroller(area)
		if #g.Requests > 0 then
			for _, r in ipairs(g.Requests) do
				local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = Color3.fromRGB(34, 62, 44), Parent = list })
				Kit.label({ Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("Request: %s (Lv %d)"):format(r.Name, r.Level), TextSize = 12, Parent = row })
				Kit.button({ Size = UDim2.fromOffset(70, 26), Position = UDim2.new(1, -150, 0.5, -13), Text = "Accept", TextSize = 11, BackgroundColor3 = C.Up, Parent = row }, function() act("GuildApprove", r.UserId, true) end)
				Kit.button({ Size = UDim2.fromOffset(70, 26), Position = UDim2.new(1, -76, 0.5, -13), Text = "Decline", TextSize = 11, Parent = row }, function() act("GuildApprove", r.UserId, false) end)
			end
		end
		local me = game:GetService("Players").LocalPlayer.UserId
		for _, m in ipairs(g.Members) do
			local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = C.PanelLight, Parent = list })
			local away = if m.SecondsAgo < 600 then "online" else span(m.SecondsAgo) .. " ago"
			Kit.label({ Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(8, 0), Text = ("%s%s  Lv %d"):format(if m.Rank == "Leader" then "👑 " elseif m.Rank == "Officer" then "⭐ " else "", m.Name, m.Level), TextSize = 12, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = row })
			Kit.label({ Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.42, 0, 0, 0), Text = ("%s · gave %d"):format(away, m.Gave), TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, Parent = row })
			local x = -8
			local function mini(text, color, fn)
				local w = 56
				Kit.button({ Size = UDim2.fromOffset(w, 24), Position = UDim2.new(1, x - w, 0.5, -12), Text = text, TextSize = 10, BackgroundColor3 = color or C.Panel, Parent = row }, fn)
				x -= w + 4
			end
			if m.UserId ~= me and m.Rank ~= "Leader" then
				if isLeader then
					local key = "Lead" .. m.UserId
					mini(if extra.GuildConfirm == key then "Sure?" else "Lead", if extra.GuildConfirm == key then C.Down else nil, function()
						if extra.GuildConfirm == key then extra.GuildConfirm = nil act("GuildTransfer", m.UserId) else extra.GuildConfirm = key redraw() end
					end)
					mini(if m.Rank == "Officer" then "Demote" else "Promote", nil, function() act("GuildRank", m.UserId, if m.Rank == "Officer" then "Member" else "Officer") end)
				end
				if canManage and (isLeader or m.Rank == "Member") then
					local key = "Kick" .. m.UserId
					mini(if extra.GuildConfirm == key then "Sure?" else "Kick", C.Down, function()
						if extra.GuildConfirm == key then extra.GuildConfirm = nil act("GuildKick", m.UserId) else extra.GuildConfirm = key redraw() end
					end)
				end
			end
		end
		Kit.label({ Size = UDim2.new(1, -8, 0, 30), Text = ("If the leader is away for %d days, leadership passes to the next officer or top contributor who has been online in the last %d days."):format(Config.InactiveDays, Config.SuccessorDays), TextSize = 10, TextColor3 = C.Dim, Parent = list })
	elseif tab == "Missions" then
		local list = scroller(area)
		for _, section in ipairs({ { "Daily", g.Daily, "Daily" }, { "Weekly", g.Weekly, "Weekly" } }) do
			Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = ("%s missions - everyone's progress adds up  (resets in %s)"):format(section[1], span(section[2].SecondsLeft)), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = list })
			for _, row in ipairs(section[2].Rows) do
				local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = if row.CanClaim then Color3.fromRGB(34, 62, 44) else C.PanelLight, Parent = list })
				Kit.label({ Size = UDim2.new(1, -130, 0, 18), Position = UDim2.fromOffset(8, 3), Text = row.Text, TextSize = 13, Font = Enum.Font.GothamBold, Parent = card })
				bar(card, row.Progress / row.Goal, UDim2.fromOffset(8, 24), UDim2.new(1, -140, 0, 9), if row.Done then C.Good else C.Accent)
				Kit.label({ Size = UDim2.new(1, -130, 0, 16), Position = UDim2.fromOffset(8, 36), Text = ("%d / %d  ·  you added %d  ·  %s"):format(row.Progress, row.Goal, row.Mine, rewardText(section[2].Reward)), TextSize = 10, TextColor3 = C.Dim, Parent = card })
				local label = if row.Claimed then "Claimed" elseif row.CanClaim then "Claim" elseif row.Done then "Not helped" else "Open"
				local b = Kit.button({ Size = UDim2.fromOffset(100, 30), Position = UDim2.new(1, -108, 0.5, -15), Text = label, TextSize = 12, BackgroundColor3 = if row.CanClaim then C.Up else C.Panel, Parent = card }, function()
					if row.CanClaim then act("GuildClaimMission", section[3], row.Index) end
				end)
				b.Active = row.CanClaim
			end
		end
		Kit.label({ Size = UDim2.new(1, -8, 0, 28), Text = ("Finishing a mission earns the guild points (the leader spends them). Finishing all of a set gives +%d (daily) / +%d (weekly) base points."):format(g.Daily.Bonus, g.Weekly.Bonus), TextSize = 10, TextColor3 = C.Dim, Parent = list })
	elseif tab == "Upgrades" then
		local list = scroller(area)
		Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = if isLeader then ("You decide: %d guild points to spend. Upgrades help every member."):format(g.Points) else ("Only the leader spends points (%d available). Every upgrade helps all members."):format(g.Points), TextSize = 12, TextColor3 = C.Dim, Parent = list })
		for _, up in ipairs(g.Upgrades) do
			local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = C.PanelLight, Parent = list })
			Kit.label({ Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(8, 3), Text = ("%s  Lv %d / %d"):format(up.Name, up.Level, up.Max), TextSize = 13, Font = Enum.Font.GothamBold, Parent = card })
			local now = if up.Plain then ("+%d slots"):format(up.Value) else ("+%.1f%% %s"):format(up.Value * 100, up.Text)
			local nextText = if up.Plain then ("+%d slots"):format(up.PerLevel) else ("+%.1f%%"):format(up.PerLevel * 100)
			Kit.label({ Size = UDim2.new(1, -140, 0, 16), Position = UDim2.fromOffset(8, 24), Text = ("%s   (each level %s)"):format(now, nextText), TextSize = 10, TextColor3 = C.Dim, Parent = card })
			local maxed = up.Cost == nil
			local canBuy = isLeader and not maxed and g.Points >= up.Cost
			local b = Kit.button({ Size = UDim2.fromOffset(120, 32), Position = UDim2.new(1, -128, 0.5, -16), Text = if maxed then "Maxed" else ("✨ %d"):format(up.Cost), TextSize = 13, BackgroundColor3 = if canBuy then C.Up else C.Panel, Parent = card }, function()
				if canBuy then act("GuildBuy", up.Id) end
			end)
			b.Active = canBuy
		end
	elseif tab == "Raid" then
		local r = g.Raid
		local left = Kit.frame({ Size = UDim2.new(0.55, -4, 1, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), Text = "Raid: " .. r.Boss.Name, TextSize = 18, Font = Enum.Font.GothamBlack, Parent = left })
		Kit.label({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 30), Text = ("%s  ·  changes in %s"):format(r.Boss.Blurb, span(r.SecondsLeft)), TextSize = 11, TextColor3 = C.Dim, Parent = left })
		bar(left, r.Health / r.MaxHealth, UDim2.fromOffset(8, 56), UDim2.new(1, -16, 0, 18), if r.Defeated then C.Good else C.Bad)
		Kit.label({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 56), Text = if r.Defeated then "DEFEATED" else ("%s / %s"):format(Short(r.Health), Short(r.MaxHealth)), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = left })
		Kit.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 80), Text = ("Battles today: %d / %d  ·  your damage this week: %s\nYour party fights it in the boss arena while you watch."):format(r.Attempts, r.PerDay, Short(r.MyDamage)), TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
		local strike = Kit.button({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 122), Text = if r.Defeated then "Boss defeated" elseif r.Attempts <= 0 then "No battles left today" else "Battle", BackgroundColor3 = if r.Attempts > 0 and not r.Defeated then C.Accent else C.Panel, TextColor3 = if r.Attempts > 0 and not r.Defeated then DARK else C.Text, Parent = left }, function()
			if r.Attempts > 0 and not r.Defeated then
				act("GuildRaid")
			end
		end)
		strike.Active = r.Attempts > 0 and not r.Defeated
		local claim = r.CanClaim or r.PrevClaim
		local claimButton = Kit.button({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 162), Text = if claim then "Claim raid rewards" else "Rewards: damage share, bigger when it falls", TextSize = 12, BackgroundColor3 = if claim then C.Up else C.PanelLight, Parent = left }, function()
			if claim then
				local ok, reply = act("GuildRaidClaim", if r.CanClaim then "Current" else "Prev")
				if ok and reply.Reward then
					extra.GuildMsg = ("%s! %s"):format(reply.Reward.Tier, rewardText(reply.Reward))
					redraw()
				end
			end
		end)
		claimButton.Active = claim
		local right = Kit.frame({ Size = UDim2.new(0.45, -4, 1, 0), Position = UDim2.new(0.55, 4, 0, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 6), Text = "Damage this week", TextSize = 13, Font = Enum.Font.GothamBold, Parent = right })
		local board = {}
		for _, m in ipairs(g.Members) do if m.Dealt > 0 then table.insert(board, m) end end
		table.sort(board, function(a, b) return a.Dealt > b.Dealt end)
		local list = scroller(right, UDim2.new(1, -8, 1, -32), UDim2.fromOffset(4, 28))
		for index, m in ipairs(board) do
			Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = ("%d. %s  -  %d"):format(index, m.Name, m.Dealt), TextSize = 11, Parent = list })
		end
		if #board == 0 then Kit.label({ Size = UDim2.new(1, -8, 0, 30), Text = "No battles yet this week.", TextSize = 11, TextColor3 = C.Dim, Parent = list }) end
	elseif tab == "Chat" then
		-- guild chat (2026-11-22): the last 30 messages; other servers' messages show within ~15 s (the guild cache)
		local panel = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, Parent = area })
		local list = scroller(panel, UDim2.new(1, -8, 1, -46), UDim2.fromOffset(4, 4))
		local rows = g.Chat or {}
		if #rows == 0 then
			Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = "No messages yet. Say hello to your guild!", TextSize = 12, TextColor3 = C.Dim, Parent = list })
		end
		for index, row in ipairs(rows) do
			local ago = if row.SecondsAgo < 60 then "now" else span(row.SecondsAgo) .. " ago"
			local line = Kit.frame({ Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = if row.UserId == state.Player.UserId then C.PanelLight else C.Panel, LayoutOrder = index, Parent = list })
			Kit.label({ Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 2), Text = ("%s  ·  %s"):format(row.Name, ago), TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, TextWrapped = false, Parent = line })
			Kit.label({ Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 16), Text = row.Text, TextSize = 12, TextColor3 = C.Text, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = line })
		end
		task.defer(function()
			list.CanvasPosition = Vector2.new(0, math.huge) -- newest at the bottom, in view
		end)
		local box = input(panel, { Size = UDim2.new(1, -184, 0, 30), Position = UDim2.new(0, 8, 1, -38), PlaceholderText = ("Message your guild (max %d)"):format(Config.ChatMax), Text = extra.GuildDraft or "" })
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > Config.ChatMax then box.Text = box.Text:sub(1, Config.ChatMax) end
			extra.GuildDraft = box.Text
		end)
		local function send()
			local text = box.Text
			if text:match("^%s*$") then return end
			local ok = act("GuildChat", text)
			if ok then
				extra.GuildDraft = ""
				redraw()
			end
		end
		box.FocusLost:Connect(function(enter) if enter then send() end end)
		Kit.button({ Size = UDim2.fromOffset(80, 30), Position = UDim2.new(1, -168, 1, -38), Text = "Send", TextSize = 13, BackgroundColor3 = C.Up, Parent = panel }, send)
		Kit.button({ Size = UDim2.fromOffset(80, 30), Position = UDim2.new(1, -84, 1, -38), Text = "Refresh", TextSize = 12, Parent = panel }, function() act("GuildState") end)
	elseif tab == "Pets" then
		local w = data.Wish
		local left = Kit.frame({ Size = UDim2.new(0.45, -4, 1, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), Text = "Guild Wish", TextSize = 18, Font = Enum.Font.GothamBlack, Parent = left })
		Kit.label({ Size = UDim2.new(1, -16, 0, 52), Position = UDim2.fromOffset(8, 32), Text = ("Spend Guild Marks (from guild missions and the raid) on pets found nowhere else.\nYou have %d marks. %d per wish.\nEpic+ guaranteed in %d, Legendary in %d."):format(w.Marks, w.Cost, w.LeftEpic, w.LeftLegendary), TextSize = 11, TextColor3 = C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
		for index, count in ipairs({ 1, 10 }) do
			local can = w.Marks >= w.Cost * count
			local b = Kit.button({ Size = UDim2.new(0.5, -12, 0, 40), Position = UDim2.new((index - 1) * 0.5, if index == 1 then 8 else 4, 0, 96), Text = ("Wish x%d\n🏅 %d"):format(count, w.Cost * count), TextSize = 12, BackgroundColor3 = if can then (if count == 1 then C.Up else C.Accent) else C.Panel, TextColor3 = if can and count == 10 then DARK else C.Text, Parent = left }, function()
				if can then
					local ok, reply = act("GuildWish", count)
					if ok then
						local parts = {}
						for _, row in ipairs(reply.Results) do
							table.insert(parts, ("%s%s"):format(PetConfig.Defs[row.Id].DisplayName, if row.New then " (NEW)" elseif row.Shard then " (shard)" else " (+copy)"))
						end
						extra.GuildMsg = "You got: " .. table.concat(parts, ", ")
						redraw()
					end
				end
			end)
			b.Active = can
		end
		Kit.label({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 144), Text = extra.GuildMsg and ("Last wish:\n" .. extra.GuildMsg) or "", TextSize = 11, TextColor3 = C.Text, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
		extra.GuildMsg = nil
		local right = Kit.frame({ Size = UDim2.new(0.55, -4, 1, 0), Position = UDim2.new(0.45, 4, 0, 0), BackgroundColor3 = C.Panel, Parent = area })
		Kit.label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 6), Text = "Guild pets", TextSize = 13, Font = Enum.Font.GothamBold, Parent = right })
		local list = scroller(right, UDim2.new(1, -8, 1, -32), UDim2.fromOffset(4, 28))
		for _, row in ipairs(w.Pool) do
			local def = PetConfig.Defs[row.Id]
			local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.PanelLight, Parent = list })
			Icons.Pet(card, row.Id, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(5, 5) })
			Kit.label({ Size = UDim2.new(1, -60, 0, 18), Position = UDim2.fromOffset(46, 3), Text = ("%s  (%s)%s"):format(row.Name, row.Rarity, if row.Owned then "  ✓" else ""), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = Kit.rarityColor(row.Rarity), Parent = card })
			Kit.label({ Size = UDim2.new(1, -60, 0, 18), Position = UDim2.fromOffset(46, 22), Text = def.Skill.Name .. ": " .. def.Skill.Text, TextSize = 10, TextColor3 = C.Dim, TextWrapped = false, Parent = card })
		end
	end
end

return GuildScreen
