--[[
	Errands (ModuleScript): daily town errands (docs/TOWN.md phase 2, Config/Errands). Pure: the caller passes `now`
	and an rng, and the server checks the player stands at the spot (World.NearSpot) before calling Interact.

	Each day Errands.Offered(day) picks Config.PerDay errands from the pool (at most one per townsperson; the same for
	every player that day). Each offered errand can be done once that day; one errand in hand at a time.

	Season.Errands = { Day, Done = { [errandId] = true }, Active = { Id, Step, Cat } | nil }   (made on first use)

	  Errands.Offered(day)                         -> list of errand ids offered that day
	  Errands.Status(profile, now)                 -> { Active = { Id, Name, Step, Steps, Text, Spot, Prompt, Carry } | nil,
	                                                    List = { { Id, Name, Giver, GiverName, Blurb, Reward = {lines}, State } },
	                                                    DoneCount, Total }   State = "Ready" | "Active" | "Done"
	  Errands.Interact(profile, spotId, now, rng)  -> true, { Kind = "Started"|"Step"|"Done", Id, Text, Line?, Reward = {lines}? }
	                                                | false, "Busy" | "DoneToday" | "Nothing"
	  Errands.Abandon(profile, now)                -> true | false, "Nothing"
	  Errands.ActiveSpot(profile, now)             -> the spot id the active step needs (Cat resolved to Cat<n>) or nil
	  Errands.Def(id)                              -> the config entry
]]
local Config = require(script.Parent.Config.Errands)
local Consumables = require(script.Parent.Consumables)
local ConsumableConfig = require(script.Parent.Config.Consumables)

local Errands = {}

local byId = {}
for _, def in ipairs(Config.List) do
	byId[def.Id] = def
end

local function dayOf(now)
	return math.floor(now / 86400)
end

function Errands.Def(id)
	return byId[id]
end

-- a small seeded shuffle, so a day's errands are the same on every server
function Errands.Offered(day)
	local seed = (day * 2654435761) % 4294967296
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local order = {}
	for i, def in ipairs(Config.List) do
		order[i] = def
	end
	for i = #order, 2, -1 do
		local j = math.floor(rand() * i) + 1
		order[i], order[j] = order[j], order[i]
	end
	local picked, givers = {}, {}
	for _, def in ipairs(order) do
		if #picked >= Config.PerDay then
			break
		end
		if not givers[def.Giver] then
			givers[def.Giver] = true
			table.insert(picked, def.Id)
		end
	end
	return picked
end

local function state(profile, now)
	local season = profile.Season
	local s = season.Errands
	local today = dayOf(now)
	if not s or s.Day ~= today then
		-- a new day: new errands; an errand still in hand carries over
		s = { Day = today, Done = {}, Active = s and s.Active or nil }
		season.Errands = s
	end
	return s
end

local function stepSpot(active, step)
	if step.Spot == "Cat" then
		return "Cat" .. tostring(active.Cat or 1)
	end
	return step.Spot
end

local function stepText(active, step)
	if step.Spot == "Cat" then
		return step.Text:format(Config.CatHints[active.Cat or 1] or "somewhere in town")
	end
	return step.Text
end

function Errands.RewardLines(reward)
	local lines = {}
	if reward.Wishstones then
		table.insert(lines, ("%d Wishstones"):format(reward.Wishstones))
	end
	for _, id in ipairs(ConsumableConfig.Order) do
		local n = (reward.Items or {})[id]
		if n then
			table.insert(lines, ("%dx %s"):format(n, ConsumableConfig.Defs[id].DisplayName))
		end
	end
	return lines
end

local function grant(profile, reward)
	local c = profile.Season.Currencies
	c.Wishstones = (c.Wishstones or 0) + (reward.Wishstones or 0)
	for id, n in pairs(reward.Items or {}) do
		Consumables.Grant(profile, id, n)
	end
end

function Errands.ActiveSpot(profile, now)
	local active = state(profile, now).Active
	local def = active and byId[active.Id]
	if not def then
		return nil
	end
	return stepSpot(active, def.Steps[active.Step])
end

function Errands.Status(profile, now)
	local s = state(profile, now)
	local offered = Errands.Offered(s.Day)
	local out = { List = {}, DoneCount = 0, Total = #offered }
	local active = s.Active
	local activeDef = active and byId[active.Id]
	if activeDef then
		local step = activeDef.Steps[active.Step]
		out.Active = {
			Id = active.Id, Name = activeDef.Name, Step = active.Step, Steps = #activeDef.Steps,
			Text = stepText(active, step), Spot = stepSpot(active, step), Prompt = step.Prompt,
			Carry = if active.Step > 1 then activeDef.Steps[active.Step - 1].Carry else activeDef.StartCarry,
		}
	end
	for _, id in ipairs(offered) do
		local def = byId[id]
		local st = if s.Done[id] then "Done" elseif active and active.Id == id then "Active" else "Ready"
		if st == "Done" then
			out.DoneCount += 1
		end
		table.insert(out.List, {
			Id = id, Name = def.Name, Giver = def.Giver, GiverName = Config.Givers[def.Giver].Name,
			Blurb = def.Blurb, Reward = Errands.RewardLines(def.Reward), State = st,
		})
	end
	return out
end

function Errands.Interact(profile, spotId, now, rng)
	local s = state(profile, now)
	local active = s.Active
	local def = active and byId[active.Id]
	if def then
		local step = def.Steps[active.Step]
		if stepSpot(active, step) == spotId then
			if active.Step < #def.Steps then
				active.Step += 1
				return true, { Kind = "Step", Id = def.Id, Text = stepText(active, def.Steps[active.Step]) }
			end
			s.Active = nil
			s.Done[def.Id] = true
			grant(profile, def.Reward)
			return true, { Kind = "Done", Id = def.Id, Text = def.Name .. " done!", Reward = Errands.RewardLines(def.Reward) }
		end
	end
	-- a townsperson: today's errand from them, if any
	local mine, doneMine = nil, false
	for _, id in ipairs(Errands.Offered(s.Day)) do
		if byId[id].Giver == spotId then
			if s.Done[id] then
				doneMine = true
			else
				mine = id
			end
		end
	end
	if not mine then
		return false, if doneMine then "DoneToday" else "Nothing"
	end
	if def then
		return false, "Busy"
	end
	local new = byId[mine]
	s.Active = { Id = mine, Step = 1, Cat = if rng then rng(1, #Config.CatHints) else 1 }
	return true, { Kind = "Started", Id = mine, Text = stepText(s.Active, new.Steps[1]), Line = new.Line }
end

function Errands.Abandon(profile, now)
	local s = state(profile, now)
	if not s.Active then
		return false, "Nothing"
	end
	s.Active = nil
	return true
end

return Errands
