--[[
	BattleScreen (ModuleScript): the Battle window, one place for everything combat related that is not the stage climb.
	  BattleScreen.Battle(container, state, call, extra)    extra.BattleTab = nil (the menu) | "Dungeons" | "Expeditions"
	Cards open the world boss, season boss, dungeons, expeditions and the guild raid.
]]
local Kit = require(script.Parent.Kit)
local Activities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Activities)
local C = Kit.Colors

local BattleScreen = {}

local function clock(t)
	t = math.max(0, math.floor(t))
	if t >= 3600 then
		return ("%dh %02dm"):format(t // 3600, (t % 3600) // 60)
	end
	return ("%d:%02d"):format(t // 60, t % 60)
end

local DUNGEON_REASONS = { Locked = "Not unlocked yet.", NoKeys = "No keys left today.", BadArgs = "Could not enter." }

local function card(parent, index, cols, title, glyph, status, statusColor, buttonText, onClick, enabled)
	local w, h, gap = 1 / cols, 108, 8
	local col, rowIndex = (index - 1) % cols, (index - 1) // cols
	local f = Kit.frame({ Size = UDim2.new(w, -gap, 0, h), Position = UDim2.new(w * col, if col == 0 then 0 else gap / 2, 0, rowIndex * (h + gap)), BackgroundColor3 = C.PanelLight, Parent = parent })
	Kit.new("UIStroke", { Color = Color3.fromRGB(12, 14, 24), Thickness = 1.5, Parent = f })
	Kit.label({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 8), Text = glyph, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Parent = f })
	Kit.label({ Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(52, 8), Text = title, TextSize = 15, Font = Enum.Font.GothamBold, TextWrapped = false, Parent = f })
	Kit.label({ Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(52, 30), Text = status, TextSize = 11, TextColor3 = statusColor or C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
	local b = Kit.button({ Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -36), Text = buttonText, TextSize = 13, BackgroundColor3 = if enabled == false then C.Panel else C.Accent, TextColor3 = if enabled == false then C.Dim else Color3.fromRGB(30, 22, 6), Parent = f }, onClick)
	b.Active = enabled ~= false
	return f
end

local function backButton(container, extra, redraw)
	Kit.button({ Size = UDim2.fromOffset(80, 26), Position = UDim2.fromOffset(0, 0), Text = "< Back", TextSize = 12, BackgroundColor3 = C.PanelLight }, function()
		extra.BattleTab, extra.BattleMsg = nil, nil
		redraw()
	end).Parent = container
end

local function dungeons(container, state, call, extra, redraw)
	local act = state.Player.Activities or { Keys = 0, MaxKeys = 3 }
	backButton(container, extra, redraw)
	Kit.label({ Size = UDim2.new(1, -100, 0, 26), Position = UDim2.fromOffset(90, 0), Text = ("Dungeons    Keys %d / %d  (refill daily)"):format(act.Keys, act.MaxKeys), TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = container })
	local list = Kit.frame({ Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local frontier = state.Player.HighestStage or state.Player.Frontier or 1
	for i, d in ipairs(Activities.Dungeons) do
		local open = frontier >= d.Unlock
		local f = Kit.frame({ Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, (i - 1) * 62), BackgroundColor3 = C.PanelLight, Parent = list })
		Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(12, 6), Text = d.Name, TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = if open then C.Text else C.Dim, Parent = f })
		Kit.label({ Size = UDim2.new(1, -170, 0, 32), Position = UDim2.fromOffset(12, 26), Text = if open then ("Recommended level %d  ·  %d waves, then a boss. No healing between waves.\n%s %s"):format(d.Level, d.Waves, d.Blurb, if act.Daily and act.Daily[d.Id] then "Daily bonus taken - back tomorrow." else "Daily bonus ready: clear it today for 2 skill + 2 pet wishes.") else ("Recommended level %d  ·  reach stage %d to unlock."):format(d.Level, d.Unlock), TextSize = 11, TextColor3 = if open and (state.Player.Level or 1) < d.Level then C.Bad else C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
		local can = open and act.Keys > 0
		Kit.button({ Size = UDim2.fromOffset(130, 36), Position = UDim2.new(1, -142, 0.5, -18), Text = if not open then "Locked" elseif act.Keys <= 0 then "No keys" else "Enter", TextSize = 14, BackgroundColor3 = if can then C.Accent else C.Panel, TextColor3 = if can then Color3.fromRGB(30, 22, 6) else C.Dim, Parent = f }, function()
			if not can then
				return
			end
			local ok, result = call("DungeonRun", d.Id)
			extra.BattleMsg = if ok then nil else (DUNGEON_REASONS[result] or "Could not enter.")
			if not ok then
				redraw()
			end
		end)
	end
	if extra.BattleMsg then
		Kit.label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -28), Text = extra.BattleMsg, TextSize = 12, TextColor3 = C.Bad, Parent = container })
	end
end

local function expeditionMessage(container, text)
	Kit.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -32), Text = text, TextSize = 12, TextColor3 = C.Good, TextWrapped = true, Parent = container })
end

local function expeditions(container, state, call, extra, redraw)
	local act = state.Player.Activities or {}
	local running = act.Expedition
	backButton(container, extra, redraw)
	Kit.label({ Size = UDim2.new(1, -100, 0, 26), Position = UDim2.fromOffset(90, 0), Text = "Expeditions    send the party away, then collect", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = container })
	local list = Kit.frame({ Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	local now = os.time()
	for i, e in ipairs(Activities.Expeditions) do
		local f = Kit.frame({ Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, (i - 1) * 68), BackgroundColor3 = C.PanelLight, Parent = list })
		Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(12, 6), Text = e.Name, TextSize = 15, Font = Enum.Font.GothamBold, Parent = f })
		local mine = running ~= nil and running.Id == e.Id
		local status = if mine then (if running.EndsAt <= now then "Returned! Collect your haul." else ("Away for %s more"):format(clock(running.EndsAt - now))) else ("Takes %s. Pays gold, tonics, pet food and more."):format(clock(e.Seconds))
		Kit.label({ Size = UDim2.new(1, -170, 0, 32), Position = UDim2.fromOffset(12, 26), Text = status, TextSize = 11, TextColor3 = if mine and running.EndsAt <= now then C.Good else C.Dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
		local text, enabled
		if mine then
			text, enabled = (if running.EndsAt <= now then "Collect" else "Away"), running.EndsAt <= now
		else
			text, enabled = "Send", running == nil
		end
		Kit.button({ Size = UDim2.fromOffset(130, 36), Position = UDim2.new(1, -142, 0.5, -18), Text = text, TextSize = 14, BackgroundColor3 = if enabled then C.Accent else C.Panel, TextColor3 = if enabled then Color3.fromRGB(30, 22, 6) else C.Dim, Parent = f }, function()
			if not enabled then
				return
			end
			-- on success call() has already redrawn this screen with the NEW state; redrawing here would
			-- put the old state back (the expedition looked like it never started). Only redraw on failure.
			local ok, result
			if mine then
				ok, result = call("ExpeditionCollect")
				extra.BattleMsg = if ok then ("Collected: " .. table.concat(result, ", ")) else "Not ready yet."
			else
				ok = call("ExpeditionStart", e.Id)
				extra.BattleMsg = if ok then nil else "Already on an expedition."
			end
			if not ok then
				redraw()
			elseif extra.BattleMsg then
				expeditionMessage(container, extra.BattleMsg) -- the fresh screen was drawn before the message existed
			end
		end)
	end
	if extra.BattleMsg then
		expeditionMessage(container, extra.BattleMsg)
	end
end

function BattleScreen.Battle(container, state, call, extra)
	Kit.clear(container)
	extra = extra or {}
	local function redraw()
		BattleScreen.Battle(container, state, call, extra)
	end
	if extra.BattleTab == "Dungeons" then
		return dungeons(container, state, call, extra, redraw)
	elseif extra.BattleTab == "Expeditions" then
		return expeditions(container, state, call, extra, redraw)
	end
	local boss = extra.Boss
	local age = os.clock() - (extra.BossAt or os.clock())
	local act = state.Player.Activities or { Keys = 0, MaxKeys = 3 }
	local grid = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = container })

	local worldStatus, worldColor = "Loading...", C.Dim
	if boss then
		local w = boss.World
		if w.Active then
			worldStatus, worldColor = ("%s is in the plaza!  Ends in %s"):format(w.Name, clock(w.EndsIn - age)), C.Good
		else
			worldStatus = ("Next boss in about %s"):format(clock(w.NextIn - age))
		end
	end
	local seasonStatus = "Loading..."
	if boss then
		local s = boss.Season
		seasonStatus = if s.Dead then (s.Name .. " has fallen") else ("%s  %d%% health left"):format(s.Name, math.ceil(s.Fraction * 100))
	end
	local function openBoss(tab)
		return function()
			extra.BossTab, extra.Boss = tab, nil
			extra.OpenPanel("Boss", "Bosses")
		end
	end
	local exp = act.Expedition
	local expStatus = if exp then (if exp.Ready then "Your party has returned!" else ("Away. Back in %s"):format(clock(exp.EndsAt - os.time()))) else "Send the party away for gold and supplies."
	card(grid, 1, 3, "World Boss", "👹", worldStatus, worldColor, "Open", openBoss("World"))
	card(grid, 2, 3, "Season Boss", "🗿", seasonStatus, C.Dim, "Open", openBoss("Season"))
	card(grid, 3, 3, "Guild Raid", "🛡️", "Raid with your guild for shared rewards.", C.Dim, "Open", function()
		extra.Guild, extra.GuildMsg, extra.GuildResults = nil, nil, nil
		extra.OpenPanel("Guild", "Guild")
	end)
	card(grid, 4, 3, "Dungeons", "🏰", ("Keys %d / %d. Tough floors, big chests."):format(act.Keys, act.MaxKeys), C.Dim, "Enter", function()
		extra.BattleTab = "Dungeons"
		redraw()
	end)
	card(grid, 5, 3, "Expeditions", "🧭", expStatus, if exp and exp.Ready then C.Good else C.Dim, if exp and exp.Ready then "Collect" else "Open", function()
		extra.BattleTab = "Expeditions"
		redraw()
	end)
end

return BattleScreen
