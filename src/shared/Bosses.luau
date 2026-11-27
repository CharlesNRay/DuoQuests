--[[
	Bosses (ModuleScript)
	Location: ReplicatedStorage > Shared > Bosses

	Rules for the world boss and the season boss (data in Config/Bosses). Pure functions, headless-testable.

	  Bosses.Challenge(members, cfg, frontier, seed)   -> damage, seconds fought
	        a real fight with the normal auto combat, to the death or the time limit (cfg.FightSeconds); the damage dealt is the score.
	        members as StageRunner.NewParty takes them; cfg is Config.World or Config.Season
	  Bosses.DamageScale(frontier)                  -> number: the damage a typical fight deals at this frontier (tiers are multiples of it)
	  Bosses.TiersReached(cfg, damage, frontier)    -> list of tiers (every tier up to the best reached)
	  Bosses.GrantRewards(profile, rewards, stage)  -> text lines; applies gold / items / gear
	  Bosses.SeasonHealth(cfg, damageTotal, now, seasonStart, seasonEnd) -> remaining, fraction (0..1)
	  Bosses.SeasonCrossed(cfg, fraction)           -> list of threshold defs the boss has passed
	  Bosses.Record(profile, seasonId)              -> the player's Permanent.SeasonBoss row (reset on a new season)
	  Bosses.RecordBest(profile, seasonId, damage)  -> the amount added to the boss's health loss (only a new personal best counts, and only the improvement)
	  Bosses.Claimable(profile, seasonId, cfg, fraction)  -> thresholds crossed, not yet claimed, if you contributed
	  Bosses.Claim(profile, seasonId, cfg, thresholdId, fraction, stage) -> true, lines | false, reason
	  Bosses.Hatch(profile, seasonId, cfg)          -> true, petId | false, reason ("NoEgg")
	  Bosses.SeasonCfg(seasonDef)                   -> Config.Season with the season's own boss (Config/Seasons Boss: Name, DefId, Look) on top
]]

local Entity = require(script.Parent.Combat.Entity)
local Simulation = require(script.Parent.Combat.Simulation)
local StageRunner = require(script.Parent.StageRunner)
local Stages = require(script.Parent.Stages)
local Consumables = require(script.Parent.Consumables)
local ConsumableConfig = require(script.Parent.Config.Consumables)
local Gear = require(script.Parent.Gear)

local Bosses = {}

-- Each season can bring its own season boss: Config/Seasons [id].Boss overrides Name, DefId and Look (2026-11-27)
local BossConfig = require(script.Parent.Config.Bosses)
function Bosses.SeasonCfg(seasonDef)
	local over = seasonDef and seasonDef.Boss
	if not over then
		return BossConfig.Season
	end
	local cfg = table.clone(BossConfig.Season)
	for k, v in pairs(over) do
		cfg[k] = v
	end
	return cfg
end

local HUGE = 1e12

function Bosses.Challenge(members, cfg, frontier, seed, record)
	local reference = Stages.NewEnemies(math.max(1, frontier))[1]
	local boss = Entity.new({
		Id = "boss", Name = cfg.Name or "Boss", Team = "Enemy", DefId = cfg.DefId or "Boss",
		Stats = {
			MaxHealth = HUGE,
			Attack = reference.Stats.Attack * cfg.AttackMult,
			Defense = reference.Stats.Defense * cfg.DefenseMult,
			AttackSpeed = cfg.AttackSpeed,
			CritChance = 0,
		},
		Abilities = cfg.Abilities, -- telegraphed big hits, a party-wide stomp and a berserk phase make it a real fight
	})
	boss.Flags.StunImmune = true
	local sim = Simulation.new({
		Party = StageRunner.NewParty(members),
		Enemies = { boss },
		Seed = seed or 1,
		MaxSeconds = cfg.FightSeconds, -- the party fights until it falls or this runs out
		RecordEvents = record == true,
		SpawnEnemy = require(script.Parent.Combat.StatCalc).NewEnemy,
	})
	local result = sim:Run()
	local damage = math.floor(HUGE - boss.Health + 0.5)
	local fight
	if record then
		local ghosts, looks = {}, {}
		for _, member in ipairs(members) do
			if member.Profile == nil then
				ghosts[member.Id] = true
			end
			local worn = if member.Profile then (member.Profile.Season.Equipment and member.Profile.Season.Equipment.Equipped) else member.Snapshot.Gear
			looks[member.Id] = Gear.Look(worn)
		end
		local roster = {}
		for _, team in ipairs({ sim.Party, sim.Enemies }) do
			for _, entity in ipairs(team) do
				-- the boss's bar is drawn against a few typical fights' worth of damage so it visibly drains
				local maxHealth = entity.Stats.MaxHealth
				if entity.Team == "Enemy" then
					maxHealth = math.max(1, math.floor(Bosses.DamageScale(frontier) * 3))
				end
				table.insert(roster, {
					Id = entity.Id, Name = entity.Name, Team = entity.Team, DefId = entity.DefId, PetId = entity.PetId,
					Ghost = ghosts[entity.Id] or nil, Look = looks[entity.Id], MaxHealth = maxHealth, Row = sim:RowOf(entity),
					UserId = if entity.Team == "Party" then tonumber(entity.Id) else nil,
				})
			end
		end
		local displayMax = math.max(1, math.floor(Bosses.DamageScale(frontier) * 3))
		for _, event in ipairs(sim.Events) do
			local target = event.Target
			if event.TargetHealth and (target == "boss" or (type(target) == "table" and target.Id == "boss")) then
				event.TargetHealth = math.max(0, displayMax - (HUGE - event.TargetHealth))
			end
		end
		fight = { Roster = roster, Events = sim.Events, Duration = result.Duration, Won = result.Winner == "Party" }
	end
	return damage, result.Duration, fight
end

-- what a typical party deals in one fight at this frontier (see Config.World.Tiers: thresholds are multiples of it)
function Bosses.DamageScale(frontier)
	-- 520 (was 260) since 2026-11-18: four heroes per fight deal about twice as much (abl.sh BOSSDMG lines: ~10x at L20-30 before)
	-- past stage 35 party power grows much faster than the frontier (BOSSDMG at L40: 3-34x, median ~14), so the scale
	-- grows 2% more per stage there (2026-11-19: L40 median ~8.5x, the top tier 20x a stretch; L10-30 barely move)
	local late = 1 + math.max(0, frontier - 35) * 0.03 -- 0.03 (was 0.02) and base 600 (was 520) since the 2026-11-19 skill rework
	return 600 * require(script.Parent.Config.Economy).NumberScale * (1 + math.max(0, frontier - 1) * 0.22) * late
end

function Bosses.TiersReached(cfg, damage, frontier)
	local scale = Bosses.DamageScale(frontier)
	local reached = {}
	for _, tier in ipairs(cfg.Tiers) do
		if damage >= tier.Damage * scale then
			table.insert(reached, tier)
		end
	end
	return reached
end

function Bosses.GrantRewards(profile, rewards, stage)
	local lines = {}
	if rewards.Gold then
		profile.Season.Currencies.Gold += rewards.Gold
		table.insert(lines, ("%d gold"):format(rewards.Gold))
	end
	for id, count in pairs(rewards.Items or {}) do
		if ConsumableConfig.Defs[id] then
			Consumables.Grant(profile, id, count)
			table.insert(lines, ("%dx %s"):format(count, ConsumableConfig.Defs[id].DisplayName))
		end
	end
	if rewards.Gear then
		local item = Gear.Grant(profile, (stage or 1) + (rewards.Gear.Bonus or 0), { Slot = Gear.Types[(((stage or 1) + 2) % #Gear.Types) + 1], Rarity = rewards.Gear.Rarity })
		table.insert(lines, Gear.Name(item, profile.Season.ClassId))
	end
	return lines
end

-- text lines for a rewards table (no granting)
function Bosses.Describe(rewards)
	local lines = {}
	if rewards.Gold then
		table.insert(lines, ("%d gold"):format(rewards.Gold))
	end
	for _, id in ipairs(ConsumableConfig.Order) do
		local count = (rewards.Items or {})[id]
		if count then
			table.insert(lines, ("%dx %s"):format(count, ConsumableConfig.Defs[id].DisplayName))
		end
	end
	if rewards.Gear then
		table.insert(lines, rewards.Gear.Rarity .. " gear")
	end
	if rewards.Egg then
		table.insert(lines, "Season Boss Egg")
	end
	return lines
end

-- Season boss ------------------------------------------------------------------------------------

-- remaining health: permanent damage plus the Finale wither (which reaches the whole bar at the season's end)
function Bosses.SeasonHealth(cfg, damageTotal, now, seasonStart, seasonEnd)
	local progress = 0
	if seasonEnd > seasonStart then
		progress = math.clamp((now - seasonStart) / (seasonEnd - seasonStart), 0, 1)
	end
	local start = 1 - cfg.FinaleShare
	local wither = 0
	if progress >= 1 then
		wither = cfg.MaxHealth
	elseif progress > start then
		local t = (progress - start) / cfg.FinaleShare
		wither = cfg.MaxHealth * t * t
	end
	local remaining = math.max(0, cfg.MaxHealth - damageTotal - wither)
	return remaining, remaining / cfg.MaxHealth
end

function Bosses.SeasonCrossed(cfg, fraction)
	local crossed = {}
	for _, threshold in ipairs(cfg.Thresholds) do
		if (threshold.Pct > 0 and fraction <= threshold.Pct) or (threshold.Pct == 0 and fraction <= 0) then
			table.insert(crossed, threshold)
		end
	end
	return crossed
end

function Bosses.Record(profile, seasonId)
	local perm = profile.Permanent
	local record = perm.SeasonBoss
	if record == nil or record.SeasonId ~= seasonId then
		record = { SeasonId = seasonId, Best = 0, Challenges = 0, Claimed = {}, Egg = false, Hatched = false }
		perm.SeasonBoss = record
	end
	return record
end

-- A finished challenge. Only your highest damage ever counts against the boss's health: beat your best and the boss loses the
-- difference, otherwise it loses nothing. Returns how much health the boss loses.
function Bosses.RecordBest(profile, seasonId, damage)
	local record = Bosses.Record(profile, seasonId)
	record.Challenges += 1
	local gain = math.max(0, damage - record.Best)
	record.Best += gain
	return gain
end

function Bosses.Claimable(profile, seasonId, cfg, fraction)
	local record = Bosses.Record(profile, seasonId)
	local out = {}
	if record.Challenges < cfg.MinContribution then
		return out
	end
	for _, threshold in ipairs(Bosses.SeasonCrossed(cfg, fraction)) do
		if not record.Claimed[threshold.Id] then
			table.insert(out, threshold)
		end
	end
	return out
end

function Bosses.Claim(profile, seasonId, cfg, thresholdId, fraction, stage)
	local record = Bosses.Record(profile, seasonId)
	if record.Challenges < cfg.MinContribution then
		return false, "NoContribution"
	end
	local threshold
	for _, t in ipairs(cfg.Thresholds) do
		if t.Id == thresholdId then
			threshold = t
		end
	end
	if threshold == nil then
		return false, "Unknown"
	end
	local crossed = false
	for _, t in ipairs(Bosses.SeasonCrossed(cfg, fraction)) do
		crossed = crossed or t.Id == thresholdId
	end
	if not crossed then
		return false, "NotReached"
	end
	if record.Claimed[thresholdId] then
		return false, "AlreadyClaimed"
	end
	record.Claimed[thresholdId] = true
	local lines = Bosses.GrantRewards(profile, threshold.Rewards, stage)
	if threshold.Rewards.Egg then
		record.Egg = true
		table.insert(lines, "Season Boss Egg")
	end
	return true, lines
end

function Bosses.Hatch(profile, seasonId, cfg)
	local record = Bosses.Record(profile, seasonId)
	if not record.Egg then
		return false, "NoEgg"
	end
	record.Egg = false
	record.Hatched = true
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	profile.Permanent.Pets[cfg.EggPet] = true
	return true, cfg.EggPet
end

return Bosses
