--[[
	Bestiary (ModuleScript): the permanent monster book (Config/Bestiary).

	  Bestiary.Zones()                       -> { { Index, Name, Monsters = { enemyId x3 }, Boss = enemyId } } for the 20 zones
	  Bestiary.TierOf(enemyId, kills)        -> 0..4
	  Bestiary.CountKills(events, roster)    -> { [enemyId] = kills } from a recorded fight (summoned adds included)
	  Bestiary.KillsForStage(stage, fights)  -> { [enemyId] = kills } for fights won away (no events)
	  Bestiary.Record(profile, counts, now)  -> { { EnemyId, Tier } } tiers newly reached; zone titles are granted here
	  Bestiary.HuntOf(now)                   -> the weekly hunt's enemy id (its kills count double)
	  Bestiary.Mods(profile)                 -> { { Stat, Mode, Value } } the zone bonuses (ExtraMods)
	  Bestiary.Status(profile, now)          -> everything the Bestiary screen shows

	Kills live in Permanent.Bestiary.Kills[enemyId] (string keys: safe to save).
]]
local Config = require(script.Parent.Config.Bestiary)
local StageConfig = require(script.Parent.Config.Stages)
local ZoneConfig = require(script.Parent.Config.Zones)
local Enemies = require(script.Parent.Config.Enemies)
local Stages = require(script.Parent.Stages)

local Bestiary = {}

local zones = nil
function Bestiary.Zones()
	if zones then
		return zones
	end
	zones = {}
	for index, pool in ipairs(StageConfig.ZonePools) do
		local zone = ZoneConfig[index]
		local boss = zone and zone.Boss or StageConfig.BossPool[(index - 1) % #StageConfig.BossPool + 1]
		table.insert(zones, { Index = index, Name = zone and zone.Name or ("Zone " .. index), Monsters = table.clone(pool), Boss = boss })
	end
	return zones
end

local function isBoss(enemyId)
	local def = Enemies[enemyId]
	return def ~= nil and def.IsBoss == true
end

function Bestiary.TierOf(enemyId, kills)
	local tiers = if isBoss(enemyId) then Config.Tiers.Boss else Config.Tiers.Regular
	local tier = 0
	for i, need in ipairs(tiers) do
		if (kills or 0) >= need then
			tier = i
		end
	end
	return tier
end

function Bestiary.NextAt(enemyId, kills)
	local tiers = if isBoss(enemyId) then Config.Tiers.Boss else Config.Tiers.Regular
	for _, need in ipairs(tiers) do
		if (kills or 0) < need then
			return need
		end
	end
	return nil
end

function Bestiary.CountKills(events, roster)
	local defOf = {}
	for _, entry in ipairs(roster or {}) do
		if entry.Team == "Enemy" then
			defOf[entry.Id] = entry.DefId
		end
	end
	local counts = {}
	for _, e in ipairs(events or {}) do
		if e.Type == "Spawn" and e.Entity and e.Entity.Team == "Enemy" then
			defOf[e.Entity.Id] = e.Entity.DefId
		elseif e.Type == "Death" then
			local def = defOf[e.Target]
			if def and Enemies[def] and not Enemies[def].EventOnly then
				counts[def] = (counts[def] or 0) + 1
			end
		end
	end
	return counts
end

function Bestiary.KillsForStage(stage, fights)
	local counts = {}
	if fights <= 0 then
		return counts
	end
	for _, entry in ipairs(Stages.Build(stage).Enemies) do
		counts[entry.EnemyId] = (counts[entry.EnemyId] or 0) + fights
	end
	return counts
end

local function allMonsters()
	local list, seen = {}, {}
	for _, zone in ipairs(Bestiary.Zones()) do
		for _, id in ipairs(zone.Monsters) do
			if not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	return list
end

function Bestiary.HuntOf(now)
	local list = allMonsters()
	local week = (now or os.time()) // (7 * 86400)
	return list[week % #list + 1]
end

local function book(profile)
	local perm = profile.Permanent
	perm.Bestiary = perm.Bestiary or { Kills = {} }
	perm.Bestiary.Kills = perm.Bestiary.Kills or {}
	return perm.Bestiary
end

local function zoneTier(kills, zone)
	local low = math.huge
	for _, id in ipairs(zone.Monsters) do
		low = math.min(low, Bestiary.TierOf(id, kills[id]))
	end
	return math.min(low, Bestiary.TierOf(zone.Boss, kills[zone.Boss]))
end

local function titles(zone)
	return zone.Name .. " Hunter", zone.Name .. " Master"
end

function Bestiary.Record(profile, counts, now)
	local b = book(profile)
	local hunt = Bestiary.HuntOf(now)
	local reached = {}
	for id, n in pairs(counts or {}) do
		if n > 0 then
			local before = b.Kills[id] or 0
			local gain = if id == hunt then n * Config.WeeklyHunt.Factor else n
			b.Kills[id] = before + gain
			local tierBefore, tierAfter = Bestiary.TierOf(id, before), Bestiary.TierOf(id, before + gain)
			if tierAfter > tierBefore then
				table.insert(reached, { EnemyId = id, Tier = tierAfter })
			end
		end
	end
	if #reached > 0 then
		profile.Permanent.Titles = profile.Permanent.Titles or {}
		for _, zone in ipairs(Bestiary.Zones()) do
			local tier = zoneTier(b.Kills, zone)
			local hunter, master = titles(zone)
			if tier >= Config.ZoneTier then
				profile.Permanent.Titles[hunter] = true
			end
			if tier >= Config.MasterTier then
				profile.Permanent.Titles[master] = true
			end
		end
	end
	return reached
end

function Bestiary.Bonus(profile)
	local kills = book(profile).Kills
	local total = {}
	for _, zone in ipairs(Bestiary.Zones()) do
		local tier = zoneTier(kills, zone)
		if tier >= Config.ZoneTier then
			for stat, v in pairs(Config.ZoneBonus) do
				total[stat] = (total[stat] or 0) + v
			end
		end
		if tier >= Config.MasterTier then
			for stat, v in pairs(Config.MasterBonus) do
				total[stat] = (total[stat] or 0) + v
			end
		end
	end
	for stat, v in pairs(total) do
		total[stat] = math.min(v, Config.Cap)
	end
	return total
end

function Bestiary.Mods(profile)
	local mods = {}
	for stat, v in pairs(Bestiary.Bonus(profile)) do
		if v > 0 then
			table.insert(mods, { Stat = stat, Mode = "Mul", Value = v })
		end
	end
	return mods
end

function Bestiary.Status(profile, now)
	local kills = book(profile).Kills
	local out = { Zones = {}, Hunt = Bestiary.HuntOf(now), Bonus = Bestiary.Bonus(profile), Cap = Config.Cap, TierNames = Config.TierNames }
	local function entry(id)
		local def = Enemies[id] or {}
		local k = kills[id] or 0
		return { Id = id, Name = def.DisplayName or id, Kills = k, Tier = Bestiary.TierOf(id, k), NextAt = Bestiary.NextAt(id, k), Boss = isBoss(id) }
	end
	for _, zone in ipairs(Bestiary.Zones()) do
		local monsters = {}
		for _, id in ipairs(zone.Monsters) do
			table.insert(monsters, entry(id))
		end
		table.insert(monsters, entry(zone.Boss))
		local hunter, master = titles(zone)
		table.insert(out.Zones, { Index = zone.Index, Name = zone.Name, Monsters = monsters, Tier = zoneTier(kills, zone), Hunter = hunter, Master = master })
	end
	return out
end

return Bestiary
