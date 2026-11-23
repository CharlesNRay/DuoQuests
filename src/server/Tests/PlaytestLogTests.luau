--[[
	PlaytestLogTests (ModuleScript): the playtest log rules (Shared/PlaytestLog): feedback is cleaned and capped,
	repeated errors are counted not stored again, lists stay within their size, tester limits, session lines, and
	every entry is DataStore-safe. Headless: tools/sim/runners/extra.luau.
]]
return function(modulesOverride)
	local m = modulesOverride
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end
	print("Running PlaytestLogTests...")
	local L = m.PlaytestLog
	local DS = m.DataSafety

	check("Text is trimmed and one line", L.Clean("  hello\n\tthere   you ") == "hello there you")
	check("Empty text is nothing", L.Clean("   \n ") == nil and L.Clean(nil) == nil and L.Clean(5) == nil)
	local long = L.Clean(string.rep("a", 900), 500)
	check("Long text is capped", long ~= nil and #long <= 503 and long:sub(-3) == "…")
	local emoji = L.Clean(string.rep("é", 300), 501) -- 600 bytes, 2 each: the cut lands mid-character
	check("A cut never splits a character", emoji ~= nil and utf8.len(emoji) ~= nil)

	local now = 1800000000
	local fb = L.Entry("Feedback", { UserId = 7, Name = "Tester", Level = 9, Stage = 12, Topic = "Bug", Text = "The fish got away twice" }, now)
	check("Feedback keeps topic, text and who", fb and fb.Topic == "Bug" and fb.Text == "The fish got away twice" and fb.Level == 9 and fb.Kind == "Feedback")
	check("An unknown topic becomes Idea", L.Entry("Feedback", { Topic = "Rant", Text = "x" }, now).Topic == "Idea")
	check("Empty feedback is no entry", L.Entry("Feedback", { Topic = "Bug", Text = "  " }, now) == nil)
	check("NaN level is dropped", L.Entry("Feedback", { Text = "x", Level = 0 / 0 }, now).Level == nil)
	check("Buckets", L.Bucket("Feedback") == "Feedback" and L.Bucket("ServerError") == "Errors" and L.Bucket("ClientError") == "Errors" and L.Bucket("Session") == "Sessions")
	check("Day keys", L.Key("Errors", 20833) == "Errors:20833")

	-- errors repeat: counted, not stored again
	local list = {}
	for i = 1, 50 do
		list = L.Merge(list, L.Entry("ServerError", { Text = "attempt to index nil", Where = "handler Wish" }, now + i), 150)
	end
	list = L.Merge(list, L.Entry("ClientError", { Text = "attempt to index nil" }, now), 150)
	check("50 of the same error are one line x50", #list == 2 and list[1].Count == 50 and list[1].At == now + 50)
	check("A client error with the same text is its own line", list[2].Kind == "ClientError" and list[2].Count == 1)
	-- lists stay within their size (oldest go)
	local many = {}
	for i = 1, 320 do
		many = L.Merge(many, L.Entry("Feedback", { Text = "note " .. i }, now + i), 300)
	end
	check("A day keeps 300 feedback notes, the newest", #many == 300 and many[1].Text == "note 21" and many[300].Text == "note 320")
	check("Feedback is never merged, even if the same", #L.Merge(L.Merge({}, L.Entry("Feedback", { Text = "same" }, now), 300), L.Entry("Feedback", { Text = "same" }, now), 300) == 2)

	-- tester limits
	local limits = {}
	check("First feedback is allowed", L.Allow(limits, 7, "Feedback", now) == true)
	check("A second one 5 s later is too soon", select(2, L.Allow(limits, 7, "Feedback", now + 5)) == "TooSoon")
	check("Another player is not held up", L.Allow(limits, 8, "Feedback", now + 5) == true)
	local t = now
	for _ = 2, L.FEEDBACK_PER_DAY do
		t += L.FEEDBACK_GAP
		L.Allow(limits, 7, "Feedback", t)
	end
	check("After the daily limit: refused", select(2, L.Allow(limits, 7, "Feedback", t + L.FEEDBACK_GAP)) == "DailyLimit")
	check("Next day: allowed again", L.Allow(limits, 7, "Feedback", t + 86400) == true)
	local allowed = 0
	for i = 1, 20 do
		if L.Allow(limits, 9, "ClientError", now + i * 0.5) then
			allowed += 1
		end
	end
	check("Client errors: 6 a minute", allowed == L.ERRORS_PER_MINUTE)
	check("Client errors: allowed again a minute later", L.Allow(limits, 9, "ClientError", now + 80) == true)

	-- sessions
	local s = L.Entry("Session", { UserId = 7, Name = "Tester", Minutes = 23.4, LevelFrom = 3, Level = 9, StageFrom = 1, Stage = 12, Class = "Mage" }, now)
	check("A session line", s and s.Text == "played 23 min, level 3 -> 9, stage 1 -> 12" and s.Minutes == 23.4)
	check("A session with no change", L.SessionText({ Minutes = 2, LevelFrom = 5, Level = 5, Stage = 4 }) == "played 2 min, level 5, stage 4")

	-- everything is DataStore-safe
	local day = { fb, s }
	day = L.Merge(day, L.Entry("ServerError", { Text = "boom", Where = "x" }, now), 150)
	check("A day list is DataStore-safe", #DS.Problems(day) == 0)
	local big = {}
	for i = 1, 300 do
		big = L.Merge(big, L.Entry("Feedback", { UserId = i, Name = "Player" .. i, Level = 40, Stage = 90, Class = "Summoner", Where = "Combat Arena (-120, 150)", Topic = "Idea", Text = string.rep("w", 600) }, now + i), 300)
	end
	check(("A full day of long notes is far under the DataStore limit (%d)"):format(DS.Size(big)), DS.Size(big) < DS.LIMIT / 20)
	check("Topics", #L.Topics == 4)

	print(("PlaytestLogTests done: %d passed, %d failed"):format(passed, failed))
end
