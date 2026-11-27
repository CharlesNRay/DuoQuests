--[[
	StressTest (ModuleScript): Studio-only full-server look (docs/RELEASE.md "Performance with a full server").

	Fills the free lots with fake parties (copies of your own party, companion-style negative ids) and keeps replaying
	your party's latest fight on each of them, so this client draws what a 16-player server would show. The real
	distance rule still applies (Arenas WATCH_DISTANCE): only lots near the camera animate. Every 5 s it prints
	  STRESS lots=N animating=A frame avg=..ms p95=..ms worst=..ms fps=.. mem=..MB parts=..
	and keeps the last line in StressTest.Last (the Test cheats panel shows it).

	  StressTest.Start(n, deps)   deps = { Arenas, GetWorld, GetFight, ApplyWorld, UserId }
	  StressTest.Stop()
	  StressTest.Merge(snapshot)  -> the snapshot plus the fake parties (Main's applyWorld runs every snapshot through it)
	  StressTest.Active()
]]
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local World = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").World)

local StressTest = {}

local state = nil -- { Lots, Fake = { [slot] = party }, Deps, Conn, Samples, Token }
StressTest.Last = nil

function StressTest.Active()
	return state ~= nil
end

local function myParty(snapshot, userId)
	for _, party in ipairs(snapshot and snapshot.Parties or {}) do
		for _, member in ipairs(party.Members or {}) do
			if member.UserId == userId then
				return party
			end
		end
	end
	return nil
end

local function buildFakes(n, snapshot, userId)
	local template = myParty(snapshot, userId)
	if not template then
		return nil, "no party of yours in the world snapshot yet"
	end
	local taken = {}
	for _, party in ipairs(snapshot.Parties or {}) do
		taken[party.Slot] = true
	end
	local fakes = {}
	local count = #(snapshot.Parties or {})
	local maxSlots = World.MAX_PLAYERS or World.LOT_LIMIT or 16
	for slot = 1, maxSlots do
		if count >= n then
			break
		end
		if not taken[slot] then
			local members = {}
			for i, member in ipairs(template.Members) do
				local copy = table.clone(member)
				copy.UserId = -(1000 + slot * 10 + i) -- negative = companion style: no headshot request, never "you"
				copy.Name = ("Stress%d-%d"):format(slot, i)
				copy.Online = i == 1
				table.insert(members, copy)
			end
			local party = table.clone(template)
			party.Slot = slot
			party.PartyId = "stress" .. slot
			party.Members = members
			fakes[slot] = party
			count += 1
		end
	end
	return fakes
end

-- Main reports how long each world snapshot took to apply
function StressTest.Note(dt)
	if state then
		state.Slow.World = math.max(state.Slow.World or 0, dt)
	end
end

function StressTest.Merge(snapshot)
	if not state or not snapshot then
		return snapshot
	end
	local taken = {}
	for _, party in ipairs(snapshot.Parties or {}) do
		taken[party.Slot] = true
	end
	local merged = table.clone(snapshot)
	merged.Parties = table.clone(snapshot.Parties or {})
	for slot, party in pairs(state.Fake) do
		if not taken[slot] then
			table.insert(merged.Parties, party)
		end
	end
	return merged
end

local function countParts()
	local parts, all = 0, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		all += 1
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts, all
end

local function report()
	local samples = state.Samples
	state.Samples = {}
	if #samples == 0 then
		return
	end
	table.sort(samples)
	local sum = 0
	for _, s in ipairs(samples) do
		sum += s
	end
	local avg = sum / #samples
	local p95 = samples[math.max(1, math.ceil(#samples * 0.95))]
	local worst = samples[#samples]
	local animating = 0
	for _, arena in pairs(state.Deps.Arenas.BySlot) do
		if arena.Fighting then
			animating += 1
		end
	end
	local parts, all = countParts()
	local lots = 0
	for _ in pairs(state.Deps.Arenas.BySlot) do
		lots += 1
	end
	local slow = state.Slow
	state.Slow = { Play = 0, Event = 0, EventType = "", World = 0 }
	local line = ("STRESS lots=%d animating=%d frame avg=%.1fms p95=%.1fms worst=%.1fms fps=%.0f mem=%.0fMB parts=%d instances=%d slowest start=%.1fms event=%.1fms (%s) world=%.1fms"):format(
		lots, animating, avg * 1000, p95 * 1000, worst * 1000, 1 / avg, Stats:GetTotalMemoryUsageMb(), parts, all, slow.Play * 1000, slow.Event * 1000, slow.EventType, (slow.World or 0) * 1000)
	StressTest.Last = line
	print(line)
end

function StressTest.Start(n, deps)
	StressTest.Stop()
	local fakes, why = buildFakes(n, deps.GetWorld(), deps.UserId)
	if not fakes then
		return false, why
	end
	if not deps.GetFight() then
		return false, "wait for one of your own fights first"
	end
	state = { Lots = n, Fake = fakes, Deps = deps, Samples = {}, Token = {}, Slow = { Play = 0, Event = 0, EventType = "" } }
	local token = state.Token
	deps.ApplyWorld(deps.GetWorld())
	-- time the synchronous work of each fight start and each fight event on every lot (where do the hitches come from?)
	for _, arena in pairs(deps.Arenas.BySlot) do
		local replay = arena.Replay
		if replay and not replay.StressTimed then
			replay.StressTimed = true
			local play, event = replay.Play, replay._event
			replay.Play = function(self, ...)
				local t = os.clock()
				local r = play(self, ...)
				if state then
					state.Slow.Play = math.max(state.Slow.Play, os.clock() - t)
				end
				return r
			end
			replay._event = function(self, e, ...)
				local t = os.clock()
				local r = event(self, e, ...)
				local dt = os.clock() - t
				if state and dt > state.Slow.Event then
					state.Slow.Event, state.Slow.EventType = dt, tostring(e and e.Type) .. ":" .. tostring(e and (e.Ability or e.Status) or "")
				end
				return r
			end
		end
	end
	state.Conn = RunService.RenderStepped:Connect(function(dt)
		table.insert(state.Samples, dt)
	end)
	-- keep every fake lot fighting: replay your latest fight there whenever it is idle
	task.spawn(function()
		while state and state.Token == token do
			local fight = deps.GetFight()
			for slot in pairs(state.Fake) do
				local arena = deps.Arenas.BySlot[slot]
				if fight and arena and not arena.Fighting then
					local info = table.clone(fight)
					info.Slot = slot
					deps.Arenas:Play(slot, info)
				end
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		while state and state.Token == token do
			task.wait(5)
			if state and state.Token == token then
				report()
			end
		end
	end)
	return true, ("%d fake parties added"):format((function()
		local c = 0
		for _ in pairs(fakes) do
			c += 1
		end
		return c
	end)())
end

function StressTest.Stop()
	if not state then
		return
	end
	local deps = state.Deps
	if state.Conn then
		state.Conn:Disconnect()
	end
	state = nil
	deps.ApplyWorld(deps.GetWorld()) -- Arenas:Apply drops the lots no real party uses
end

return StressTest
