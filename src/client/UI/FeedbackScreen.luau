--[[
	FeedbackScreen (ModuleScript): the HUD 📝 "Feedback" panel (playtests, docs/PLAYTEST.md).

	  FeedbackScreen.Feedback(container, state, call, extra)

	"Send" view: pick a topic (Bug / Confusing / Idea / Fun), write a note, Send (handler SendFeedback; the server
	adds your name, level, stage and where you were). "Read log" view, only when state.Player.CanReadLog (Studio, or
	the place's creator in the live game): the playtest log from every server (handler PlaytestRead) in three lists:
	Feedback, Errors (server + client, repeats counted) and Sessions (one line per visit).
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local FeedbackScreen = {}

local TOPICS = {
	{ Id = "Bug", Label = "🐞 Bug", Hint = "Something broke or looks wrong" },
	{ Id = "Confusing", Label = "❓ Confusing", Hint = "I did not know what to do" },
	{ Id = "Idea", Label = "💡 Idea", Hint = "This would make it better" },
	{ Id = "Fun", Label = "⭐ Fun", Hint = "I liked this" },
}
local TOPIC_COLOR = { Bug = C.Bad, Confusing = C.Accent, Idea = C.Rare, Fun = C.Good }
local REASONS = {
	Empty = "Write something first.",
	TooSoon = "Thanks! Wait a few seconds before sending another.",
	DailyLimit = "That is plenty for today, thank you!",
	TooFast = "One moment...",
	Forbidden = "Only the game's owner can read the log.",
}

local function scroller(parent, size, position)
	local scroll = Kit.new("ScrollingFrame", { Size = size, Position = position, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = parent })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = scroll })
	return scroll
end

local function stamp(at)
	if type(at) ~= "number" then
		return "?"
	end
	return os.date("%m-%d %H:%M", at)
end

local function who(entry)
	local bits = {}
	if entry.Name then
		table.insert(bits, entry.Name)
	end
	local about = {}
	if entry.Level then
		table.insert(about, "L" .. entry.Level)
	end
	if entry.Class then
		table.insert(about, entry.Class)
	end
	if entry.Stage then
		table.insert(about, "stage " .. entry.Stage)
	end
	if #about > 0 then
		table.insert(bits, "(" .. table.concat(about, " ") .. ")")
	end
	if entry.Where then
		table.insert(bits, "at " .. entry.Where)
	end
	return table.concat(bits, " ")
end

local function sendView(body, state, call, extra, redraw)
	local draft = extra.FeedbackDraft or { Topic = "Bug", Text = "" }
	extra.FeedbackDraft = draft
	Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = "Tell us what you think. It goes straight to the developer.", TextSize = 13, TextColor3 = C.Dim, Parent = body })
	local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Parent = body })
	for i, t in ipairs(TOPICS) do
		local on = draft.Topic == t.Id
		local b = Kit.button({ Size = UDim2.new(0.25, -6, 1, 0), Position = UDim2.new((i - 1) * 0.25, 0, 0, 0), Text = t.Label, TextSize = 14, BackgroundColor3 = if on then TOPIC_COLOR[t.Id] else C.PanelLight, TextColor3 = if on then C.Bg else C.Text, Parent = row }, function()
			draft.Topic = t.Id
			redraw()
		end)
		Kit.Hover(b, function() return t.Hint end)
	end
	local box = Kit.new("TextBox", {
		Size = UDim2.new(1, -8, 0, 150), Position = UDim2.fromOffset(0, 72), BackgroundColor3 = C.Panel, TextColor3 = C.Text, PlaceholderColor3 = C.Dim,
		PlaceholderText = "What happened? What were you trying to do? (up to 500 letters)", Text = draft.Text, Font = Enum.Font.Gotham, TextSize = 14,
		ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		BorderSizePixel = 0, Parent = body,
	})
	Kit.corner(6).Parent = box
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), Parent = box })
	local count = Kit.label({ Size = UDim2.fromOffset(120, 18), Position = UDim2.new(1, -128, 0, 226), Text = "", TextSize = 11, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = body })
	local function counted()
		count.Text = ("%d / 500"):format(utf8.len(box.Text) or #box.Text)
		count.TextColor3 = if #box.Text > 500 then C.Bad else C.Dim
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		draft.Text = box.Text
		counted()
	end)
	counted()
	local msg = extra.FeedbackMsg
	Kit.label({ Size = UDim2.new(1, -170, 0, 36), Position = UDim2.fromOffset(0, 250), Text = msg and msg.Text or "We also see your level and stage, so no need to write them.", TextSize = 13, TextWrapped = true, TextColor3 = if msg then (if msg.Good then C.Good else C.Bad) else C.Dim, Parent = body })
	Kit.button({ Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -158, 0, 250), Text = "📨 Send", TextSize = 16, BackgroundColor3 = C.Accent, TextColor3 = C.Bg, Parent = body }, function()
		local ok, reason = call("SendFeedback", draft.Topic, draft.Text, extra.Where and extra.Where() or nil)
		if ok then
			extra.FeedbackMsg = { Good = true, Text = "Sent. Thank you!" }
			draft.Text = ""
		else
			extra.FeedbackMsg = { Good = false, Text = REASONS[tostring(reason)] or ("Could not send: " .. tostring(reason)) }
		end
		redraw()
	end)
end

local function readView(body, state, call, extra, redraw)
	local view = extra.LogView or { List = "Feedback", Days = 1 }
	extra.LogView = view
	local bar = Kit.frame({ Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1, Parent = body })
	local data = extra.LogData
	local lists = { "Feedback", "Errors", "Sessions" }
	for i, id in ipairs(lists) do
		local n = data and data[id] and #data[id] or 0
		Kit.button({ Size = UDim2.fromOffset(110, 28), Position = UDim2.fromOffset((i - 1) * 114, 0), Text = ("%s (%d)"):format(id, n), TextSize = 13, BackgroundColor3 = if view.List == id then C.Accent else C.PanelLight, TextColor3 = if view.List == id then C.Bg else C.Text, Parent = bar }, function()
			view.List = id
			redraw()
		end)
	end
	local function load()
		local ok, reply = call("PlaytestRead", view.Days)
		if ok then
			extra.LogData = reply
			extra.LogMsg = nil
		else
			extra.LogMsg = REASONS[tostring(reply)] or ("Could not read the log: " .. tostring(reply))
		end
		redraw()
	end
	Kit.button({ Size = UDim2.fromOffset(96, 28), Position = UDim2.new(1, -200, 0, 0), Text = if view.Days == 1 then "Today" else "Last 3 days", TextSize = 12, BackgroundColor3 = C.PanelLight, Parent = bar }, function()
		view.Days = if view.Days == 1 then 3 else 1
		load()
	end)
	Kit.button({ Size = UDim2.fromOffset(96, 28), Position = UDim2.new(1, -100, 0, 0), Text = "🔄 Refresh", TextSize = 12, BackgroundColor3 = C.PanelLight, Parent = bar }, load)
	local scroll = scroller(body, UDim2.new(1, -8, 1, -38), UDim2.fromOffset(0, 36))
	if extra.LogMsg then
		Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = extra.LogMsg, TextColor3 = C.Bad, TextSize = 13, Parent = scroll })
	end
	if not data then
		Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = "Loading...", TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
		if not extra.LogLoading then
			extra.LogLoading = true
			task.spawn(function()
				load()
				extra.LogLoading = false
			end)
		end
		return
	end
	if data.Memory then
		Kit.label({ Size = UDim2.new(1, -8, 0, 18), Text = "Studio without API access: this is only this test session's log.", TextColor3 = C.Accent, TextSize = 12, Parent = scroll })
	end
	local rows = data[view.List] or {}
	if #rows == 0 then
		Kit.label({ Size = UDim2.new(1, -8, 0, 20), Text = "Nothing yet.", TextColor3 = C.Dim, TextSize = 13, Parent = scroll })
	end
	for _, entry in ipairs(rows) do
		local head, color
		if entry.Kind == "Feedback" then
			head, color = ("[%s] %s"):format(tostring(entry.Topic), who(entry)), TOPIC_COLOR[entry.Topic] or C.Text
		elseif entry.Kind == "Session" then
			head, color = who({ Name = entry.Name, Class = entry.Class }), C.Text
		else
			head = ("%s%s %s"):format(if entry.Kind == "ClientError" then "Client" else "Server", if (entry.Count or 1) > 1 then " x" .. entry.Count else "", who(entry))
			color = C.Bad
		end
		local card = Kit.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.PanelLight, Parent = scroll })
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = card })
		Kit.new("UIListLayout", { Padding = UDim.new(0, 2), Parent = card })
		Kit.label({ Size = UDim2.new(1, 0, 0, 16), Text = stamp(entry.At) .. "   " .. head, TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		Kit.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(entry.Text), TextSize = 12, TextWrapped = true, TextColor3 = C.Text, Parent = card })
	end
end

function FeedbackScreen.Feedback(container, state, call, extra)
	Kit.clear(container)
	local function redraw()
		FeedbackScreen.Feedback(container, extra.State or state, call, extra)
	end
	local canRead = state.Player and state.Player.CanReadLog
	local tab = if canRead then (extra.FeedbackTab or "Send") else "Send"
	local top = 0
	if canRead then
		for i, id in ipairs({ "Send", "Read log" }) do
			Kit.button({ Size = UDim2.fromOffset(120, 28), Position = UDim2.fromOffset((i - 1) * 124, 0), Text = id, TextSize = 13, BackgroundColor3 = if tab == id then C.Accent else C.PanelLight, TextColor3 = if tab == id then C.Bg else C.Text, Parent = container }, function()
				extra.FeedbackTab = id
				redraw()
			end)
		end
		top = 34
	end
	local body = Kit.new("Frame", { Size = UDim2.new(1, 0, 1, -top), Position = UDim2.fromOffset(0, top), BackgroundTransparency = 1, Parent = container })
	if tab == "Send" then
		sendView(body, state, call, extra, redraw)
	else
		readView(body, state, call, extra, redraw)
	end
end

return FeedbackScreen
