--[[
	SeasonScreen (ModuleScript): end-of-season rewards.
	  SeasonScreen.Season(container, state, call, extra)
	    extra.SeasonData     = reply of GetSeasonRewards (Main fetches it when the screen opens)
	    extra.RefreshSeason  = function() re-fetches it and redraws

	Shows finished seasons' rewards waiting to be claimed, the player's live standing and projected Sunstones,
	and EVERY bracket (Top 10%..100%, the exact ranks, and the class awards) so everyone can see what they play for.
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

local function bracketRow(scroll, left, right, highlight)
	local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = if highlight then Color3.fromRGB(70, 58, 24) else C.PanelLight, Parent = scroll })
	Kit.label({ Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), Text = left, TextSize = 12, Font = if highlight then Enum.Font.GothamBold else Enum.Font.Gotham, TextColor3 = if highlight then ORANGE else C.Text, Parent = row })
	Kit.label({ Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Text = right, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ORANGE, Parent = row })
end

local function rewardText(r)
	local parts = { "🔶 " .. commas(r.Sunstones) }
	if r.Wishstones and r.Wishstones > 0 then
		table.insert(parts, "💎 " .. commas(r.Wishstones))
	end
	if r.Title then
		table.insert(parts, '"' .. r.Title .. '"')
	end
	return table.concat(parts, "   ")
end

function SeasonScreen.Season(container, state, call, extra)
	local data = extra.SeasonData
	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = scroll })
	if not data then
		Kit.label({ Size = UDim2.new(1, -8, 0, 30), Text = "Season rewards are loading...", TextColor3 = C.Dim, Parent = scroll })
		return
	end

	-- finished seasons waiting to be claimed
	for _, pending in ipairs(data.Pending or {}) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.fromRGB(34, 70, 44), Parent = scroll })
		local lines = {}
		for _, line in ipairs(pending.Reward.Lines) do
			table.insert(lines, ("%s +%d"):format(line.Label, line.Sunstones))
		end
		Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(10, 4), Text = (pending.Name .. " is over - your reward is ready!"), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = GOOD, Parent = row })
		Kit.label({ Size = UDim2.new(1, -170, 0, 34), Position = UDim2.fromOffset(10, 26), Text = ("%s  =  🔶 %s Sunstones, 💎 %s Wishstones"):format(table.concat(lines, ", "), commas(pending.Reward.Sunstones), commas(pending.Reward.Wishstones)), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Dim, Parent = row })
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

	-- live standing
	local live = data.Live or {}
	local days = math.max(0, math.ceil(((data.Season.EndsAt or 0) - os.time()) / 86400))
	section(scroll, ("%s  -  ends in %d day%s"):format(data.Season.Name ~= "" and data.Season.Name or "This season", days, days == 1 and "" or "s"))
	local mine
	if live.Ranked then
		local bits = { ("Furthest stage %d"):format(live.Score), ("%s of %s players"):format(live.Percentile or "?", commas(live.Players or 0)) }
		if live.Rank then
			table.insert(bits, "overall rank #" .. live.Rank)
		end
		if live.ClassRank then
			table.insert(bits, ("rank #%d as %s"):format(live.ClassRank, live.ClassId))
		end
		mine = table.concat(bits, "  -  ") .. ("\nIf the season ended now you would earn about 🔶 %s Sunstones."):format(commas(live.Projected or 0))
	else
		mine = ("Reach stage %d to be ranked (you are on stage %d). Everyone who gets there earns Sunstones at the end of the season."):format(data.MinStage, live.Score or 1)
	end
	local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = C.Panel, Parent = scroll })
	Kit.label({ Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Text = mine, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = BLUE, Parent = card })

	-- every bracket, so nobody is left guessing
	section(scroll, "Everyone who is ranked earns a share - the further you get, the more")
	for _, row in ipairs(data.Brackets.Percentiles) do
		bracketRow(scroll, row.Label, rewardText(row), live.Percentile == row.Label)
	end
	section(scroll, "Top ranks earn extra on top")
	for _, row in ipairs(data.Brackets.Ranks) do
		bracketRow(scroll, row.Label, rewardText(row), live.RankLabel == row.Label)
	end
	section(scroll, "Best of each class earn extra too (Warrior, Cleric and Mage boards)")
	for _, row in ipairs(data.Brackets.ClassRanks) do
		bracketRow(scroll, row.Label, rewardText(row), false)
	end
	Kit.label({ Size = UDim2.new(1, -8, 0, 30), Text = ("Ranked by furthest stage this season (stage %d or higher counts). Ties share a bracket. Rewards are paid in Sunstones - earned, never random."):format(data.MinStage), TextSize = 10, TextWrapped = true, TextColor3 = C.Dim, Parent = scroll })
end

return SeasonScreen
