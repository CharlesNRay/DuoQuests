--[[
	StatusText (ModuleScript): plain words for buffs and debuffs, and what they did in a recorded fight.
	Used by the combat log's "Effects" view, so players can read what was on whom, also after a fast fight.

	  StatusText.Describe(statusId)  -> { Name, Text }   Text spells out the numbers ("+50% Defense. Cannot die.")
	  StatusText.ActiveAt(fight, t)  -> { [entityId] = { { Status, Left, Stacks } } }   what each fighter carries at time t
	  StatusText.Summary(fight, upTo) -> { { Status, Name, Text, Applied, Uptime, OnHeroes, By = { names }, On = { names } } }
	                                     every status seen in the fight (up to upTo seconds), most applied first
]]
local Statuses = require(script.Parent.Config.Statuses)

local StatusText = {}

local STAT_WORDS = {
	Attack = "Attack", Defense = "Defense", MaxHealth = "Max health", AttackSpeed = "Attack speed",
	CritChance = "Crit chance", CritMultiplier = "Crit damage", DamageDealt = "Damage dealt",
	MagicalDamageDealt = "Magic damage", PhysicalDamageDealt = "Physical damage", HealingDealt = "Healing done",
	HealingTaken = "Healing received", Haste = "Cooldown speed", Lifesteal = "Lifesteal", CritResist = "Crit resistance",
}

local function pct(x)
	return ("%d%%"):format(math.floor(math.abs(x) * 100 + 0.5))
end

local function modText(mod)
	local stat, value = mod.Stat, mod.Value
	if stat == "DamageTaken" then
		if mod.Mode == "Add" then
			return (if value >= 0 then "Takes " .. pct(value) .. " more damage" else "Takes " .. pct(value) .. " less damage")
		end
		return (if value >= 1 then "Takes " .. pct(value - 1) .. " more damage" else "Takes " .. pct(1 - value) .. " less damage")
	end
	local word = STAT_WORDS[stat] or stat
	if mod.Mode == "Add" then
		local shown = if stat == "Haste" or stat == "CritChance" or stat == "CritMultiplier" or stat == "Lifesteal" or stat == "CritResist" then pct(value) else tostring(value)
		return (if value >= 0 then "+" else "-") .. shown .. " " .. word
	end
	return (if value >= 1 then "+" .. pct(value - 1) else "-" .. pct(1 - value)) .. " " .. word
end

function StatusText.Describe(statusId)
	local def = Statuses[statusId]
	if not def then
		return { Name = tostring(statusId), Text = "" }
	end
	local parts = {}
	for _, mod in ipairs(def.Mods or {}) do
		table.insert(parts, modText(mod))
	end
	local flags = def.Flags or {}
	if flags.Absorb then
		table.insert(parts, "Soaks damage until it breaks")
	end
	if flags.Taunting then
		table.insert(parts, "Enemies must attack it")
	end
	if flags.PreventLethal then
		table.insert(parts, "Cannot drop below 1 health")
	end
	if flags.Stunned then
		table.insert(parts, "Cannot attack or cast")
	end
	if def.Dot then
		local d = def.Dot
		local text = ("Takes %d%% of the caster's Attack"):format(math.floor(d.Multiplier * 100 + 0.5))
		if d.PercentMaxHealth then
			text ..= (" + %.1f%% of its max health"):format(d.PercentMaxHealth * 100)
		end
		text ..= (" every %s"):format(if (d.Interval or 1) == 1 then "second" else tostring(d.Interval) .. " s")
		table.insert(parts, text)
	end
	if def.Stacks then
		table.insert(parts, ("Stacks up to %d"):format(def.Stacks.Max))
	end
	local text = table.concat(parts, ". ")
	if def.Combo or #parts == 0 then
		-- combo layers and anything without numbers: the hand-written description says it best
		text = (def.Description or "") .. (if #parts > 0 and not def.Combo then " " .. text else "")
	end
	return { Name = def.DisplayName or statusId, Text = text }
end

-- replay the fight's Status / StatusEnd / Death events up to time t
local function walk(fight, upTo, onOpen, onClose)
	local active = {} -- [target][status] = { Start, Ends, Stacks, Source }
	for _, e in ipairs(fight.Events or {}) do
		local t = e.T or 0
		if upTo and t > upTo then
			break
		end
		if e.Type == "Status" then
			active[e.Target] = active[e.Target] or {}
			local st = active[e.Target][e.Status]
			if st and st.Ends > t then
				st.Ends = t + (e.Duration or 1)
				st.Stacks = e.Stacks
			else
				if st then
					onClose(e.Target, e.Status, st, st.Ends)
				end
				st = { Start = t, Ends = t + (e.Duration or 1), Stacks = e.Stacks, Source = e.Source }
				active[e.Target][e.Status] = st
			end
			onOpen(e.Target, e.Status, e.Source)
		elseif e.Type == "StatusEnd" then
			local list = active[e.Target]
			local st = list and list[e.Status]
			if st then
				onClose(e.Target, e.Status, st, math.min(t, st.Ends))
				list[e.Status] = nil
			end
		elseif e.Type == "Death" then
			for id, st in pairs(active[e.Target] or {}) do
				onClose(e.Target, id, st, math.min(t, st.Ends))
			end
			active[e.Target] = nil
		end
	end
	return active
end

function StatusText.ActiveAt(fight, t)
	local active = walk(fight, t, function() end, function() end)
	local out = {}
	for target, list in pairs(active) do
		for id, st in pairs(list) do
			if st.Ends > t then
				out[target] = out[target] or {}
				table.insert(out[target], { Status = id, Left = st.Ends - t, Stacks = st.Stacks })
			end
		end
	end
	for _, list in pairs(out) do
		table.sort(list, function(a, b)
			return a.Status < b.Status
		end)
	end
	return out
end

function StatusText.Summary(fight, upTo)
	local names, teams = {}, {}
	for _, entry in ipairs(fight.Roster or {}) do
		names[entry.Id] = entry.Name
		teams[entry.Id] = entry.Team
	end
	local rows, order = {}, {}
	local function rowOf(id)
		local row = rows[id]
		if not row then
			local d = StatusText.Describe(id)
			row = { Status = id, Name = d.Name, Text = d.Text, Applied = 0, Uptime = 0, OnHeroes = 0, OnEnemies = 0, By = {}, On = {}, ByNames = {}, OnNames = {} }
			rows[id] = row
			table.insert(order, row)
		end
		return row
	end
	local function add(set, list, name)
		if name and not set[name] then
			set[name] = true
			table.insert(list, name)
		end
	end
	local active = walk(fight, upTo, function(target, id, source)
		local row = rowOf(id)
		row.Applied += 1
		if teams[target] == "Party" then
			row.OnHeroes += 1
		else
			row.OnEnemies += 1
		end
		add(row.ByNames, row.By, source and names[source])
		add(row.OnNames, row.On, names[target])
	end, function(_, id, st, ends)
		rowOf(id).Uptime += math.max(0, ends - st.Start)
	end)
	local stop = upTo or (fight.Duration or 0)
	for _, list in pairs(active) do
		for id, st in pairs(list) do
			rowOf(id).Uptime += math.max(0, math.min(st.Ends, stop) - st.Start)
		end
	end
	for _, row in ipairs(order) do
		row.ByNames, row.OnNames = nil, nil
	end
	table.sort(order, function(a, b)
		return a.Applied > b.Applied
	end)
	return order
end

return StatusText
