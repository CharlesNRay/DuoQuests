--[[
	SparScreen (ModuleScript): the sparring ring. extra.SparList = opponents { Key, Name, ClassId, Level, Kind }
	(handler SparList), extra.SparResult = the last duel (handler SparFight) or { Pending } / { Error };
	extra.RunSpar(key) fights.

	  SparScreen.Spar(container, state, call, extra)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Short = require(ReplicatedStorage:WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local SparScreen = {}

function SparScreen.Spar(container, state, _, extra)
	Kit.clear(container)
	local stats = state.Player.Sparring or { Wins = 0, Losses = 0 }
	local head = Kit.frame({ Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = C.PanelLight, Parent = container })
	Kit.label({ Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 3), Text = ("⚔ Friendly duels   (record: %d won, %d lost)"):format(stats.Wins, stats.Losses), TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = head })
	Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 25), Text = "Your hero against theirs, one on one, two bouts (one from each side). The first win each day pays 3 Wishstones.", TextSize = 11, TextColor3 = C.Dim, Parent = head })

	local result = extra.SparResult
	local listTop = 52
	if result then
		local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 84), Position = UDim2.fromOffset(0, 52), BackgroundColor3 = if result.Won then Color3.fromRGB(40, 70, 46) elseif result.Pending or result.Error then C.Panel else Color3.fromRGB(80, 40, 40), Parent = container })
		listTop = 142
		if result.Pending then
			Kit.label({ Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "⚔ The duel is on...", TextSize = 18, Font = Enum.Font.GothamBold, Parent = card })
		elseif result.Error then
			Kit.label({ Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = result.Error, TextSize = 15, TextColor3 = C.Bad, Parent = card })
		else
			Kit.label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 4), Text = (if result.Won then "🏆 VICTORY over " else "💀 Defeated by ") .. tostring(result.Opponent), TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = if result.Won then C.Good else Color3.fromRGB(255, 120, 110), Parent = card })
			local bouts = {}
			for i, b in ipairs(result.Bouts or {}) do
				table.insert(bouts, ("Bout %d: %s (%d%% vs %d%% health left, %ds)"):format(i, if b.Won then "won" else "lost", math.floor(b.Mine * 100 + 0.5), math.floor(b.Theirs * 100 + 0.5), math.floor(b.Seconds + 0.5)))
			end
			Kit.label({ Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 34), Text = table.concat(bouts, "\n"), TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
			Kit.label({ Size = UDim2.new(0.5, -10, 0, 16), Position = UDim2.new(0.5, 0, 0, 34), Text = ("Damage: you %s, them %s"):format(Short(result.MyDamage or 0), Short(result.TheirDamage or 0)), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
			if result.Lines and #result.Lines > 0 then
				Kit.label({ Size = UDim2.new(0.5, -10, 0, 16), Position = UDim2.new(0.5, 0, 0, 52), Text = table.concat(result.Lines, "  "), TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
			end
		end
	end

	local scroll = Kit.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -listTop), Position = UDim2.fromOffset(0, listTop), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = scroll })
	local list = extra.SparList
	if not list then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Looking for opponents...", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	if #list == 0 then
		Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Nobody to spar with right now.", TextColor3 = C.Dim, Parent = scroll })
		return
	end
	for _, o in ipairs(list) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.Panel, Parent = scroll })
		Kit.label({ Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(10, 2), Text = o.Name, TextSize = 15, Font = Enum.Font.GothamBold, Parent = row })
		Kit.label({ Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(10, 23), Text = ("Lv %d %s  -  %s"):format(o.Level or 1, tostring(o.ClassId), o.Kind), TextSize = 12, TextColor3 = C.Dim, Parent = row })
		Kit.button({ Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -128, 0.5, -17), Text = "Duel", BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = row }, function()
			if extra.RunSpar then
				extra.RunSpar(o.Key)
			end
		end)
	end
end

return SparScreen
