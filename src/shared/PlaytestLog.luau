--[[
	PlaytestLog (ModuleScript): pure rules for the playtest log (server: Services/PlaytestService).

	Testers send feedback from the HUD (📝), and the game records what went wrong and how long people played, so the
	owner can read it all later from the same screen (Studio, or the live game as the place's creator).

	Kinds
	  Feedback      a tester's note: Topic (Bug | Confusing | Idea | Fun) + text
	  ServerError   a server script error or a handler that threw (ApiService)
	  ClientError   a LocalScript error a player's game reported
	  Session       one player's visit: minutes played, level and stage at join and leave

	  PlaytestLog.Clean(text, max)                 -> trimmed one-paragraph text (nil when empty)
	  PlaytestLog.Entry(kind, info, now)           -> a DataStore-safe entry { Kind, At, Text, ... }
	  PlaytestLog.Merge(list, entry, keep)         -> list with the entry added (errors with the same text are counted
	                                                  instead of repeated); oldest dropped past `keep`
	  PlaytestLog.Allow(limits, userId, kind, now) -> ok, reason   (per player: feedback 1 per 20 s and 15 a day,
	                                                  client errors 6 a minute)
	  PlaytestLog.SessionText(info)                -> "played 23 min, level 3 -> 9, stage 1 -> 12"
	  PlaytestLog.Key(kind, day)                   -> DataStore key ("Feedback:20500", "Errors:20500", "Sessions:20500")
	  PlaytestLog.Topics                           -> { "Bug", "Confusing", "Idea", "Fun" }
]]
local PlaytestLog = {}

PlaytestLog.Topics = { "Bug", "Confusing", "Idea", "Fun" }
PlaytestLog.MAX_TEXT = 500 -- feedback length
PlaytestLog.MAX_ERROR = 400 -- error message + trace length
PlaytestLog.KEEP = { Feedback = 300, Errors = 150, Sessions = 300 } -- per day key
PlaytestLog.FEEDBACK_GAP = 20
PlaytestLog.FEEDBACK_PER_DAY = 15
PlaytestLog.ERRORS_PER_MINUTE = 6

local TOPIC = {}
for _, t in ipairs(PlaytestLog.Topics) do
	TOPIC[t] = true
end

function PlaytestLog.Clean(text, max)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if text == "" then
		return nil
	end
	max = max or PlaytestLog.MAX_TEXT
	if #text > max then
		-- do not cut a multi-byte character in half
		local cut = max
		while cut > 0 and utf8.len(text:sub(1, cut)) == nil do
			cut -= 1
		end
		text = text:sub(1, cut) .. "…"
	end
	return text
end

-- which day key an entry goes to
function PlaytestLog.Bucket(kind)
	if kind == "Feedback" then
		return "Feedback"
	elseif kind == "Session" then
		return "Sessions"
	end
	return "Errors"
end

function PlaytestLog.Key(bucket, day)
	return ("%s:%d"):format(bucket, day)
end

local function num(v)
	return if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then v else nil
end

function PlaytestLog.Entry(kind, info, now)
	info = info or {}
	local entry = { Kind = kind, At = math.floor(now or 0) }
	if type(info.UserId) == "number" then
		entry.UserId = info.UserId
	end
	if type(info.Name) == "string" then
		entry.Name = info.Name:sub(1, 40)
	end
	entry.Level = num(info.Level)
	entry.Stage = num(info.Stage)
	if type(info.Class) == "string" then
		entry.Class = info.Class:sub(1, 20)
	end
	if type(info.Where) == "string" then
		entry.Where = info.Where:sub(1, 60)
	end
	if kind == "Feedback" then
		entry.Topic = if TOPIC[info.Topic] then info.Topic else "Idea"
		entry.Text = PlaytestLog.Clean(info.Text, PlaytestLog.MAX_TEXT)
	elseif kind == "Session" then
		entry.Text = PlaytestLog.SessionText(info)
		entry.Minutes = num(info.Minutes)
	else
		entry.Text = PlaytestLog.Clean(info.Text, PlaytestLog.MAX_ERROR)
		entry.Count = 1
	end
	if entry.Text == nil then
		return nil
	end
	return entry
end

function PlaytestLog.Merge(list, entry, keep)
	list = if type(list) == "table" then list else {}
	if entry.Count then
		for _, old in ipairs(list) do
			if old.Kind == entry.Kind and old.Text == entry.Text then
				old.Count = (old.Count or 1) + (entry.Count or 1)
				old.At = math.max(old.At or 0, entry.At or 0)
				return list
			end
		end
	end
	table.insert(list, entry)
	keep = keep or 300
	while #list > keep do
		table.remove(list, 1)
	end
	return list
end

function PlaytestLog.Allow(limits, userId, kind, now)
	local mine = limits[userId]
	if not mine then
		mine = { Day = -1, Sent = 0, Last = -math.huge, Errors = {} }
		limits[userId] = mine
	end
	if kind == "Feedback" then
		local day = math.floor(now / 86400)
		if mine.Day ~= day then
			mine.Day, mine.Sent = day, 0
		end
		if now - mine.Last < PlaytestLog.FEEDBACK_GAP then
			return false, "TooSoon"
		end
		if mine.Sent >= PlaytestLog.FEEDBACK_PER_DAY then
			return false, "DailyLimit"
		end
		mine.Last = now
		mine.Sent += 1
		return true
	end
	local recent = {}
	for _, t in ipairs(mine.Errors) do
		if now - t < 60 then
			table.insert(recent, t)
		end
	end
	mine.Errors = recent
	if #recent >= PlaytestLog.ERRORS_PER_MINUTE then
		return false, "TooMany"
	end
	table.insert(recent, now)
	return true
end

function PlaytestLog.SessionText(info)
	local minutes = math.max(0, math.floor((num(info.Minutes) or 0) + 0.5))
	local function span(a, b)
		a, b = num(a), num(b)
		if a and b and a ~= b then
			return ("%d -> %d"):format(a, b)
		end
		return tostring(b or a or "?")
	end
	local text = ("played %d min, level %s, stage %s"):format(minutes, span(info.LevelFrom, info.Level), span(info.StageFrom, info.Stage))
	if type(info.Extra) == "string" and info.Extra ~= "" then
		text ..= ", " .. info.Extra:sub(1, 120)
	end
	return text
end

return PlaytestLog
