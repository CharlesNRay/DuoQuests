--[[
	SeasonScreen (ModuleScript): end-of-season rewards.
	  SeasonScreen.Season(container, state, call, extra)
	    extra.SeasonData     = reply of GetSeasonRewards (Main fetches it when the screen opens)
	    extra.RefreshSeason  = function() re-fetches it and redraws

	Shows finished seasons' rewards waiting to be claimed, the player's live standing and projected Sunstones,
	and every bracket (Top 10%..100%, the exact ranks, and the class awards). Only the season title is shown as text; a "?" icon
	explains how the rewards add up.
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local ORANGE = Color3.fromRGB(255, 165, 70)
local GOOD = Color3.fromRGB(130, 235, 150)
local BLUE = Color3.fromRGB(120, 190, 255)

local SeasonScreen = {}

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function section(scroll, text)
	Kit.label({ Size = UDim2.new(1, -8, 0, 22), Text = text, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = scroll })
end

local function bracketRow(scroll, left, right, highlight, extras)
	local hasExtras = extras ~= nil and #extras > 0
	local row = Kit.frame({ Size = UDim2.new(1, -8, 0, if hasExtras then 38 else 24), BackgroundColor3 = if highlight then Color3.fromRGB(70, 58, 24) else C.PanelLight, Parent = scroll })
	Kit.label({ Size = UDim2.new(0.5, -10, 0, 24), Position = UDim2.fromOffset(10, 0), Text = left, TextSize = 12, Font = if highlight then Enum.Font.GothamBold else Enum.Font.Gotham, TextColor3 = if highlight then ORANGE else C.Text, Parent = row })
	Kit.label({ Size = UDim2.new(0.5, -10, 0, 24), Position = UDim2.new(0.5, 0, 0, 0), Text = right, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ORANGE, Parent = row })
	if hasExtras then
		Kit.label({ Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 22), Text = table.concat(extras, "  -  "), TextSize = 10, TextColor3 = BLUE, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	end
end

local function rewardText(r)
	local parts = { "🔶 " .. commas(r.Sunstones) }
	if r.Wishstones and r.Wishstones > 0 then
		table.insert(parts, "💎 " .. commas(r.Wishstones))
	end
	return table.concat(parts, "   ")
end

function SeasonScreen.Season(container, state, call, extra)
	Kit.clear(container)
	local data = extra.SeasonData
	local area = Kit.frame({ Name = "SeasonArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = area })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = scroll })
	if not data then
		Kit.label({ Size = UDim2.new(1, -8, 0, 30), Text = "Season rewards are loading...", TextColor3 = C.Dim, Parent = scroll })
		return
	end

	-- finished seasons waiting to be claimed
	for _, pending in ipairs(data.Pending or {}) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 74), BackgroundColor3 = Color3.fromRGB(34, 70, 44), Parent = scroll })
		local lines = {}
		for _, line in ipairs(pending.Reward.Lines) do
			table.insert(lines, ("%s +%d"):format(line.Label, line.Sunstones))
		end
		Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(10, 4), Text = (pending.Name .. " is over - your reward is ready!"), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = GOOD, Parent = row })
		Kit.label({ Size = UDim2.new(1, -170, 0, 34), Position = UDim2.fromOffset(10, 26), Text = ("🔶 %s Sunstones, 💎 %s Wishstones"):format(commas(pending.Reward.Sunstones), commas(pending.Reward.Wishstones)) .. (if #pending.Reward.Extras > 0 then "  +  " .. table.concat(pending.Reward.Extras, ", ") else ""), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Dim, Parent = row })
		Kit.button({ Size = UDim2.fromOffset(140, 40), Position = UDim2.new(1, -150, 0.5, -20), Text = "Claim", BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), Parent = row }, function()
			if call("ClaimSeasonRewards", pending.SeasonId) then
				extra.SeasonMsg = "Claimed! Sunstones added to your balance."
			else
				extra.SeasonMsg = "Could not claim yet - try again in a moment."
			end
			extra.RefreshSeason()
		end)
	end
	if extra.SeasonMsg then
		Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = extra.SeasonMsg, TextSize = 12, TextColor3 = GOOD, Parent = scroll })
	end

	-- title row: the season and a "?" that explains how rewards add up
	local live = data.Live or {}
	local days = math.max(0, math.ceil(((data.Season.EndsAt or 0) - os.time()) / 86400))
	local head = Kit.frame({ Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1, NoCorner = true, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -44, 1, 0), Text = ("%s  -  ends in %d day%s"):format(data.Season.Name ~= "" and data.Season.Name or "This season", days, days == 1 and "" or "s"), TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = head })
	local help = Kit.button({ Name = "HelpIcon", Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -30, 0, 1), Text = "?", TextSize = 16, BackgroundColor3 = C.PanelLight, Parent = head })
	Kit.corner(14).Parent = help
	local helpText = ("<b>How season rewards work</b>\nRewards are cumulative: you earn your Top %% bracket, plus every rank row at or above your rank (rank 1 earns all of them), plus your class bracket on top.\nRanking is your furthest stage this season (stage %d or higher counts). Everything is paid in Sunstones, Wishstones, pets and cosmetics - earned, never random."):format(data.MinStage)
	Kit.Hover(help, function()
		return helpText
	end)
	help.Activated:Connect(function() -- clicking (or tapping) opens the explanation right on the page, and again closes it
		Kit.HideTip()
		extra.SeasonHelp = not extra.SeasonHelp
		SeasonScreen.Season(container, state, call, extra)
	end)
	if extra.SeasonHelp then
		local box = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })
		Kit.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, RichText = true, Text = helpText, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = box })
	end
	local mine
	if live.Ranked then
		local bits = { ("Furthest stage %d"):format(live.Score), ("%s of %s players"):format(live.Percentile or "?", commas(live.Players or 0)) }
		if live.Rank then
			table.insert(bits, "overall rank #" .. live.Rank)
		end
		if live.ClassRank then
			table.insert(bits, ("rank #%d as %s"):format(live.ClassRank, live.ClassId))
		end
		mine = table.concat(bits, "  -  ") .. ("  -  about 🔶 %s now"):format(commas(live.Projected or 0))
	else
		mine = ("Reach stage %d to be ranked (you are on stage %d)."):format(data.MinStage, live.Score or 1)
	end
	local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 28), BackgroundColor3 = C.Panel, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = mine, TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = BLUE, Parent = card })

	-- every bracket, so nobody is left guessing
	for _, row in ipairs(data.Brackets.Percentiles) do
		bracketRow(scroll, row.Label, rewardText(row), live.Percentile == row.Label, row.Extras)
	end
	for _, row in ipairs(data.Brackets.Ranks) do
		bracketRow(scroll, row.Label, rewardText(row), live.RankLabel == row.Label, row.Extras)
	end
	for _, row in ipairs(data.Brackets.ClassRanks) do
		bracketRow(scroll, row.Label, rewardText(row), false, row.Extras)
	end
end

return SeasonScreen
