--[[
	FightStats (ModuleScript)
	Location: ReplicatedStorage > Shared > FightStats

	Who did the damage in a recorded fight. Pet hits (the "Pet_<id>" ability) are split from their owner's own hits, and
	summoned minions get a row of their own, so a damage meter can compare players, pets and minions.

	  FightStats.Compute(fight, upTo?) -> { Rows, Total, Duration }
	  Rows: { { Key, Kind = "Hero"|"Pet"|"Minion", OwnerId, Name, Damage, Dps, Share, Hits, Crits, Healing } }, biggest first
	  FightStats.PlayerColor(index) -> Color3 for the Nth party member (Color = that index on each row)
]]

local Pets = require(script.Parent.Pets)
local Abilities = require(script.Parent.Config.Abilities)
local Statuses = require(script.Parent.Config.Statuses)

local FightStats = {}

local PLAYER_COLORS = {
	{ 96, 165, 250 },
	{ 251, 146, 60 },
	{ 74, 222, 128 },
	{ 244, 114, 182 },
	{ 250, 204, 21 },
	{ 167, 139, 250 },
}

function FightStats.PlayerColor(index)
	local c = PLAYER_COLORS[((index or 1) - 1) % #PLAYER_COLORS + 1]
	return Color3.fromRGB(c[1], c[2], c[3])
end

function FightStats.Compute(fight, upTo)
	local teams, names, owners, petOf, order = {}, {}, {}, {}, {}
	for _, entry in ipairs(fight.Roster or {}) do
		teams[entry.Id] = entry.Team
		names[entry.Id] = entry.Name
		if entry.Team == "Party" then
			table.insert(order, entry.Id)
			petOf[entry.Id] = entry.PetId
		end
	end
	local colorIndex = {}
	for i, id in ipairs(order) do
		colorIndex[id] = i
	end
	for _, e in ipairs(fight.Events or {}) do
		if e.Type == "Spawn" and e.Entity then
			teams[e.Entity.Id] = e.Entity.Team
			names[e.Entity.Id] = e.Entity.Name
			owners[e.Entity.Id] = e.Entity.Owner
		end
	end

	local rows, byKey = {}, {}
	local function row(key, kind, ownerId, name)
		local r = byKey[key]
		if not r then
			r = { Key = key, Kind = kind, OwnerId = ownerId, Name = name, Damage = 0, Hits = 0, Crits = 0, Healing = 0, Color = colorIndex[ownerId] or 1 }
			byKey[key] = r
			table.insert(rows, r)
		end
		return r
	end
	-- every party member gets a row, even at zero, so the comparison is complete
	for _, id in ipairs(order) do
		row(id, "Hero", id, names[id] or tostring(id))
		if petOf[id] then
			local def = Pets.Defs[petOf[id]]
			row(id .. ":pet", "Pet", id, ((def and def.DisplayName) or "Pet") .. " (" .. (names[id] or "?") .. "'s pet)")
		end
	end

	local total = 0
	for _, e in ipairs(fight.Events or {}) do
		local source = e.Source
		if upTo and (e.T or 0) > upTo then
			break
		end
		if e.Type == "Damage" and not e.Sacrifice and not e.Devoured and teams[e.Target] == "Enemy" then
			local r
			if owners[source] and teams[source] == "Party" then
				r = row(owners[source] .. ":minions", "Minion", owners[source], (names[owners[source]] or "?") .. "'s minions")
			elseif teams[source] == "Party" then
				if type(e.Tag) == "string" and e.Tag:sub(1, 4) == "Pet_" then
					r = row(source .. ":pet", "Pet", source, "Pet (" .. (names[source] or "?") .. "'s pet)")
				else
					r = row(source, "Hero", source, names[source] or tostring(source))
				end
			end
			if r then
				r.Damage += e.Amount or 0
				r.Hits += 1
				if e.Crit then
					r.Crits += 1
				end
				total += e.Amount or 0
			end
		elseif e.Type == "Heal" and teams[source] == "Party" then
			local ownerId = owners[source] or source
			local r = byKey[ownerId]
			if r then
				r.Healing += e.Amount or 0
			end
		end
	end

	local duration = math.max(upTo or fight.Duration or 0, 1)
	-- drop minion rows that never existed; keep the rest
	local out = {}
	for _, r in ipairs(rows) do
		r.Damage = math.floor(r.Damage + 0.5)
		r.Healing = math.floor(r.Healing + 0.5)
		r.Dps = r.Damage / duration
		r.Share = if total > 0 then r.Damage / total else 0
		table.insert(out, r)
	end
	table.sort(out, function(a, b)
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		end
		return a.Key < b.Key
	end)
	return { Rows = out, Total = math.floor(total + 0.5), Duration = duration, Dps = total / duration }
end

-- Where ALL the damage came from: one row per (who, skill), for both sides. Basic attacks, skills, pet strikes, minions and
-- damage over time (bleeds, burns) each get their own row. Rows look like Compute's rows so the same meter can draw them
-- (Kind is "Hero" | "Pet" | "Minion" | "Enemy"; Color is the owner's party colour).
--   FightStats.Sources(fight, upTo?) -> { Rows, Total, Duration, Dps, Title }
function FightStats.Sources(fight, upTo)
	local teams, names, owners, order = {}, {}, {}, {}
	for _, entry in ipairs(fight.Roster or {}) do
		teams[entry.Id] = entry.Team
		names[entry.Id] = entry.Name
		if entry.Team == "Party" then
			table.insert(order, entry.Id)
		end
	end
	local colorIndex = {}
	for i, id in ipairs(order) do
		colorIndex[id] = i
	end
	for _, e in ipairs(fight.Events or {}) do
		if e.Type == "Spawn" and e.Entity then
			teams[e.Entity.Id] = e.Entity.Team
			names[e.Entity.Id] = e.Entity.Name
			owners[e.Entity.Id] = e.Entity.Owner
		end
	end

	local function skillName(tag)
		if tag == nil or tag == "BasicAttack" then
			return "Basic attack"
		end
		local def = Abilities[tag]
		if def then
			return def.DisplayName
		end
		local status = Statuses[tag]
		if status then
			return status.DisplayName or tag
		end
		return tostring(tag)
	end

	local rows, byKey, total = {}, {}, 0
	for _, e in ipairs(fight.Events or {}) do
		if upTo and (e.T or 0) > upTo then
			break
		end
		if e.Type == "Damage" and not e.Sacrifice and not e.Devoured and (e.Amount or 0) > 0 then
			local source = e.Source
			local ownerId = owners[source] or source
			local team = teams[source]
			local kind = if team ~= "Party" then "Enemy" elseif owners[source] then "Minion" elseif type(e.Tag) == "string" and e.Tag:sub(1, 4) == "Pet_" then "Pet" else "Hero"
			local key = tostring(source) .. "|" .. tostring(e.Tag)
			local r = byKey[key]
			if not r then
				local who = names[source] or tostring(source)
				local skill = if kind == "Minion" then "Attack" else skillName(e.Tag)
				r = { Key = key, Kind = kind, OwnerId = ownerId, Name = ("%s (%s)"):format(skill, who), Damage = 0, Hits = 0, Crits = 0, Healing = 0, Color = colorIndex[ownerId] or 1 }
				byKey[key] = r
				table.insert(rows, r)
			end
			r.Damage += e.Amount
			r.Hits += 1
			if e.Crit then
				r.Crits += 1
			end
			total += e.Amount
		end
	end
	local duration = math.max(upTo or fight.Duration or 0, 1)
	for _, r in ipairs(rows) do
		r.Damage = math.floor(r.Damage + 0.5)
		r.Dps = r.Damage / duration
		r.Share = if total > 0 then r.Damage / total else 0
	end
	table.sort(rows, function(a, b)
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		end
		return a.Key < b.Key
	end)
	return { Rows = rows, Total = math.floor(total + 0.5), Duration = duration, Dps = total / duration, Title = "All damage" }
end

return FightStats
