--[[
	Simulation (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > Simulation

	A fixed-timestep, deterministic fight between two teams of Entities.
	No Roblox APIs are used, so it runs anywhere and can be tested headless.

	  local sim = Simulation.new({
	      Party = { ... },          -- Entities with Team = "Party"
	      Enemies = { ... },        -- Entities with Team = "Enemy"
	      Seed = 123,               -- same seed => identical fight
	      Hooks = hooks,            -- optional; see below
	      MaxSeconds = 180,         -- optional; fight ends as a Timeout
	      RecordEvents = true,      -- optional; false saves memory on long runs
	      OnEvent = function(e) end,-- optional; stream events (e.g. to clients)
	      Ultimate = { Id = "SanctifiedCharge", Level = 5 },
	                                -- optional party ultimate (Config/Ultimates); the
	                                -- party shares a gauge and it fires automatically
	      AbilityDefs = ...,        -- optional override of Config/Abilities
	      StatusDefs = ...,         -- optional override of Config/Statuses
	  })
	  local result = sim:Run()      -- or call sim:Step() once per 0.1s tick

	Result = { Winner = "Party" | "Enemy" | "Timeout", Duration, Survivors }
	A wiped party, or both teams dying on the same tick, counts as "Enemy".

	Each tick, every combatant alive at the start of the tick:
	  1. counts down ability cooldowns and status durations
	  2. casts at most one ready ability whose Conditions are met (slot order)
	  3. performs basic attacks according to AttackSpeed
	Deaths resolve at the end of the tick, so team order never matters.

	Stats are always read through sim:GetStat(entity, name), which applies
	active status modifiers. Never read entity.Stats directly in new code.

	Events recorded (also streamed to OnEvent), all with a time T:
	  Damage  { Source, Target, Amount, Absorbed, Crit, Tag, Element, TargetHealth }
	          Amount is health lost; Absorbed was soaked by shields.
	          Tag is "BasicAttack" or the ability id
	  Heal    { Source, Target, Amount, Overheal, Tag, Element, TargetHealth }
	  Cast    { Source, Ability, Level }
	  Status  { Target, Status, Duration, Amount, Source }  applied or refreshed
	  StatusEnd { Target, Status, Reason? }       Reason "Broken" = shield used up
	  Spawn   { Source, Entity = { Id, Name, Team, DefId, MaxHealth, Owner? } }   a summoned minion joined
	  Telegraph { Source, Ability, In }   a big enemy attack lands In seconds
	  Death   { Target }
	  Revive  { Source, Target, TargetHealth }    a fallen ally returned (Resurrection)
	  Ultimate { Source, Ability }                the party ultimate fired
	  End     { Winner }

	Hooks fired (ctx is a mutable table; handlers may change it):
	  PickTarget        { Attacker, Candidates, Target }     override Target
	  OnAbilityCast     { Caster, Ability, Level, Primary, Cancelled }
	                    set Cancelled = true to stop the cast (cooldown is spent)
	  OnCalculateDamage { Source, Target, Amount, IsCrit, DamageType, Element, Tag }
	                    change Amount (elements, relics)
	  OnBeforeDamage    same ctx, after Defense is applied   set Prevented or change Amount
	  OnDamageDealt     same ctx plus Final                  react to damage that landed
	  OnHeal            { Source, Target, Amount, Tag, Element }   change Amount before it lands
	  OnApplyStatus     { Target, Source, StatusId, Duration, Amount, Prevented }
	  OnStatusExpired   { Entity, StatusId, Reason? }
	  OnDeath           { Entity }
	  OnRevive          { Source, Target }
	  OnBattleEnd       the Result table

	Extending without touching this file:
	  Simulation.Effects[typeName]    = function(sim, castCtx, effect) ... end
	  Simulation.Conditions[keyName]  = function(sim, caster, value) return bool end
]]

local Rng = require(script.Parent.Rng)
local Hooks = require(script.Parent.Hooks)
local Abilities = require(script.Parent.Parent.Config.Abilities)
local Statuses = require(script.Parent.Parent.Config.Statuses)
local Ultimates = require(script.Parent.Parent.Config.Ultimates)
local Minions = require(script.Parent.Parent.Config.Minions)
local AbilityStats = require(script.Parent.AbilityStats)
local PetConfig = require(script.Parent.Parent.Config.Pets)
local EconomyConfig = require(script.Parent.Parent.Config.Economy)
local StatCalc = require(script.Parent.StatCalc)
local EnemyConfig = require(script.Parent.Parent.Config.Enemies)

local Simulation = {}
Simulation.__index = Simulation

Simulation.TICK = 0.1 -- seconds of fight time per Step
Simulation.DEFAULT_MAX_SECONDS = 180
Simulation.MINION_AGGRO = 0.55 -- chance an enemy attack goes for a minion while any are alive

local EPSILON = 1e-9 -- avoids float drift delaying an action by a whole tick

-- Used when an entity has no value for a stat, so modifiers can still apply.
local STAT_DEFAULTS = {
	AttackSpeed = 1,
	CritMultiplier = 1.5,
	DamageDealt = 1,
	PetDamage = 1,
	MagicalDamageDealt = 1,
	PhysicalDamageDealt = 1,
	DamageTaken = 1,
	HealingDealt = 1,
	HealingTaken = 1,
}

local function livingOf(list)
	local living = {}
	for _, entity in ipairs(list) do
		if entity.Health > 0 then
			table.insert(living, entity)
		end
	end
	return living
end

local function anyAlive(list)
	for _, entity in ipairs(list) do
		if entity.Alive and not entity.Minion then
			return true
		end
	end
	return false
end

-- living minions raised by `owner`, optionally only of one kind
local function minionsOf(sim, owner, minionId)
	local out = {}
	for _, entity in ipairs(sim:_alliesOf(owner)) do
		if entity.Minion and entity.Alive and entity.Health > 0 and entity.OwnerId == owner.Id and (minionId == nil or entity.DefId == minionId) then
			table.insert(out, entity)
		end
	end
	return out
end

-- Size of a Heal or Shield effect for one target. Each skill grows its own
-- fields per level (see AbilityStats).
local function supportAmount(sim, castCtx, effect, target)
	local ability, level = castCtx.Ability, castCtx.Level
	local flat = AbilityStats.Value(ability, effect, "Multiplier", level) or 0
	local percent = AbilityStats.Value(ability, effect, "PercentMaxHealth", level) or 0
	return flat * sim:GetStat(castCtx.Caster, "Attack") + percent * sim:GetStat(target, "MaxHealth")
end

-- Percent-of-max-health damage ("PercentTargetHealth" on a Damage effect, "PercentMaxHealth" on a Dot). It is capped by the
-- attacker's Attack (capAttack x Attack) so it can never be broken against huge health pools, and bosses (StunImmune) take only
-- BOSS_PERCENT_FACTOR of it. Stage bosses and the boss-challenge dummies are both covered.
Simulation.BOSS_PERCENT_FACTOR = 0.4
local function percentDamage(sim, caster, target, fraction, capAttack)
	local value = math.min(fraction * sim:GetStat(target, "MaxHealth"), (capAttack or 0.6) * sim:GetStat(caster, "Attack"))
	if target.Flags and target.Flags.StunImmune then
		value *= Simulation.BOSS_PERCENT_FACTOR
	end
	return value
end

-- Effect handlers ---------------------------------------------------------------
-- Each receives (sim, castCtx, effect). Register more in other modules.

Simulation.Effects = {
	-- Adds minions to the caster's team mid-fight (options.SpawnEnemy, default StatCalc.NewEnemy).
	Summon = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		assert(sim.SpawnEnemy ~= nil, "Summon needs Simulation option SpawnEnemy")
		local list = if caster.Team == "Enemy" then sim.Enemies else sim.Party
		for _ = 1, effect.Count or 1 do
			sim.SummonCount += 1
			local minion = sim.SpawnEnemy("s" .. sim.SummonCount, effect.EnemyId, caster.Scale or 1)
			table.insert(list, minion)
			sim:_record({
				Type = "Spawn",
				Source = caster.Id,
				Entity = { Id = minion.Id, Name = minion.Name, Team = minion.Team, DefId = minion.DefId, MaxHealth = minion.Stats.MaxHealth, Row = sim:RowOf(minion) },
			})
		end
	end,

	-- Pays health (a fraction of max health) as the cost of a dark spell. It cannot kill the caster.
	SpendHealth = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		local fraction = AbilityStats.Value(castCtx.Ability, effect, "Fraction", castCtx.Level) or 0
		local amount = math.min(math.floor(sim:GetStat(caster, "MaxHealth") * fraction + 0.5), caster.Health - 1)
		if amount > 0 then
			caster.Health -= amount
			sim:_record({ Type = "Damage", Source = caster.Id, Target = caster.Id, Amount = amount, Absorbed = 0, Crit = false, Tag = castCtx.Ability.Id, Element = "Shadow", TargetHealth = caster.Health, Sacrifice = true })
		end
	end,

	-- Raises minions on the caster's side (see Config/Minions). Count minions, never more than Max of that kind alive.
	Raise = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		local power = (1 + sim:GetStat(caster, "MinionPower")) * (AbilityStats.Value(castCtx.Ability, effect, "Power", castCtx.Level) or 1)
		local room = (effect.Max or 99) - #minionsOf(sim, caster, effect.MinionId)
		for _ = 1, math.min(effect.Count or 1, room) do
			sim.SummonCount += 1
			local minion = StatCalc.NewMinion("m" .. sim.SummonCount, effect.MinionId, caster, function(entity, stat)
				return sim:GetStat(entity, stat)
			end, power)
			table.insert(sim:_alliesOf(caster), minion)
			sim:_record({
				Type = "Spawn",
				Source = caster.Id,
				Entity = { Id = minion.Id, Name = minion.Name, Team = minion.Team, DefId = minion.DefId, MaxHealth = minion.Stats.MaxHealth, Owner = caster.Id, Row = sim:RowOf(minion) },
			})
			if Minions[effect.MinionId].Taunt then
				sim:ApplyStatus(minion, "Taunting", 9999, caster)
			end
		end
	end,

	-- Consumes the weakest of the caster's minions: heals the caster for a share of max health plus part of the minion's remaining life.
	Devour = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		local weakest = nil
		for _, minion in ipairs(minionsOf(sim, caster)) do
			if weakest == nil or minion.Health < weakest.Health then
				weakest = minion
			end
		end
		if weakest == nil then
			return
		end
		local life = weakest.Health
		weakest.Health = 0
		sim:_record({ Type = "Damage", Source = caster.Id, Target = weakest.Id, Amount = life, Absorbed = 0, Crit = false, Tag = castCtx.Ability.Id, Element = "Shadow", TargetHealth = 0, Devoured = true })
		local percent = AbilityStats.Value(castCtx.Ability, effect, "PercentMaxHealth", castCtx.Level) or 0
		local share = AbilityStats.Value(castCtx.Ability, effect, "MinionLife", castCtx.Level) or 0
		sim:Heal(caster, caster, percent * sim:GetStat(caster, "MaxHealth") + life * share, { Tag = castCtx.Ability.Id, Element = "Shadow" })
	end,

	Damage = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		local magnitude = AbilityStats.Value(castCtx.Ability, effect, "Multiplier", castCtx.Level)
		local damageType = effect.DamageType or castCtx.Ability.DamageType

		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			if target.Health > 0 then
				local amount = sim:GetStat(caster, "Attack") * magnitude
				if effect.PercentTargetHealth then -- a small slice of the target's health on top (capped, see percentDamage)
					amount += percentDamage(sim, caster, target, effect.PercentTargetHealth * (1 + 0.05 * math.max(0, castCtx.Level - 1)), effect.PercentCap)
				end
				sim:DealDamage(caster, target, amount, {
					Tag = castCtx.Ability.Id,
					DamageType = damageType,
					Element = castCtx.Ability.Element,
				})
			end
		end
	end,

	ApplyStatus = function(sim, castCtx, effect)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			sim:ApplyStatus(
				target,
				effect.Status,
				AbilityStats.Value(castCtx.Ability, effect, "Duration", castCtx.Level),
				castCtx.Caster,
				nil,
				AbilityStats.Strength(castCtx.Ability, effect, castCtx.Level),
				effect.Stacks
			)
		end
	end,

	-- Cleanse: removes harmful statuses (damage over time, slows, curses, stuns) from allies. Few skills have it.
	Cleanse = function(sim, castCtx, effect)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			for index = #target.Statuses, 1, -1 do
				local status = target.Statuses[index]
				if Simulation.DEBUFFS[status.Id] then
					table.remove(target.Statuses, index)
					sim:_record({ Type = "StatusEnd", Target = target.Id, Status = status.Id, Reason = "Cleansed" })
				end
			end
		end
	end,

	Heal = function(sim, castCtx, effect)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			sim:Heal(castCtx.Caster, target, supportAmount(sim, castCtx, effect, target), {
				Tag = castCtx.Ability.Id,
				Element = castCtx.Ability.Element,
			})
		end
	end,

	Shield = function(sim, castCtx, effect)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			sim:ApplyStatus(
				target,
				effect.Status or "Shield",
				AbilityStats.Value(castCtx.Ability, effect, "Duration", castCtx.Level),
				castCtx.Caster,
				supportAmount(sim, castCtx, effect, target)
			)
		end
	end,

	-- Brings a fallen ally back with a fraction of max health. Combine with
	-- UsesPerCombat on the ability to limit it (Resurrection: once per fight).
	Revive = function(sim, castCtx, effect)
		local fraction = AbilityStats.Value(castCtx.Ability, effect, "HealthFraction", castCtx.Level)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			sim:Revive(castCtx.Caster, target, fraction)
		end
	end,
}

-- Condition checks --------------------------------------------------------------
-- Each receives (sim, caster, value) and returns true when casting is allowed.

Simulation.Conditions = {
	-- Living allies (self included) are at most this many. Caps summons.
	MaxAllies = function(sim, caster, value)
		return #livingOf(sim:_alliesOf(caster)) <= value
	end,

	-- Minions: at most Max living ones of kind Id (or of any kind when Id is omitted) belong to the caster.
	MinionsBelow = function(sim, caster, value)
		return #minionsOf(sim, caster, value.Id) < value.Max
	end,

	HasMinions = function(sim, caster, value)
		return (#minionsOf(sim, caster) > 0) == value
	end,

	SelfHealthAbove = function(sim, caster, value)
		return caster.Health / sim:GetStat(caster, "MaxHealth") > value
	end,

	MinEnemies = function(sim, caster, value)
		return #livingOf(sim:_opponentsOf(caster)) >= value
	end,

	SelfHealthBelow = function(sim, caster, value)
		return caster.Health / sim:GetStat(caster, "MaxHealth") < value
	end,

	SelfLacksStatus = function(sim, caster, statusId)
		return not sim:HasStatus(caster, statusId)
	end,

	-- True when at least one ally has fallen (value = true).
	AllyDead = function(sim, caster, value)
		for _, ally in ipairs(sim:_alliesOf(caster)) do
			if not ally.Alive and not ally.Minion then
				return value
			end
		end
		return not value
	end,

	-- True when any living ally has a harmful status to clean off (Cleanse skills wait for one).
	AllyHasDebuff = function(sim, caster, value)
		for _, ally in ipairs(livingOf(sim:_alliesOf(caster))) do
			for _, status in ipairs(ally.Statuses) do
				if Simulation.DEBUFFS[status.Id] then
					return value
				end
			end
		end
		return not value
	end,

	-- True when any living ally (the caster included) is below the fraction.
	AllyHealthBelow = function(sim, caster, value)
		for _, ally in ipairs(livingOf(sim:_alliesOf(caster))) do
			if ally.Health / sim:GetStat(ally, "MaxHealth") < value then
				return true
			end
		end
		return false
	end,
}

-- Construction ------------------------------------------------------------------

function Simulation.new(options)
	local party = options.Party
	local enemies = options.Enemies
	assert(#party > 0 and #enemies > 0, "Both teams need at least one entity")

	local seen = {}
	for _, list in ipairs({ party, enemies }) do
		for _, entity in ipairs(list) do
			assert(not seen[entity.Id], "Duplicate entity id: " .. tostring(entity.Id))
			seen[entity.Id] = true
		end
	end

	return setmetatable({
		Party = party,
		Enemies = enemies,
		Hooks = options.Hooks or Hooks.new(),
		Rng = Rng.new(options.Seed or 1),
		MaxSeconds = options.MaxSeconds or Simulation.DEFAULT_MAX_SECONDS,
		RecordEvents = options.RecordEvents ~= false,
		CastTimes = options.CastTimes ~= false,
		OnEvent = options.OnEvent,
		AbilityDefs = options.AbilityDefs or Abilities,
		Ultimate = if options.Ultimate and Ultimates.Defs[options.Ultimate.Id]
			then { Id = options.Ultimate.Id, Level = options.Ultimate.Level or 1, Charge = 0 }
			else nil,
		StatusDefs = options.StatusDefs or Statuses,

		SpawnEnemy = options.SpawnEnemy or StatCalc.NewEnemy,
		SummonCount = 0,
		Ticks = 0,
		Time = 0,
		Events = {},
		Result = nil,
	}, Simulation)
end

function Simulation:_record(event)
	event.T = self.Time
	if self.RecordEvents then
		table.insert(self.Events, event)
	end
	if self.OnEvent then
		self.OnEvent(event)
	end
end

function Simulation:_opponentsOf(entity)
	return if entity.Team == "Party" then self.Enemies else self.Party
end

function Simulation:_alliesOf(entity)
	return if entity.Team == "Party" then self.Party else self.Enemies
end

-- Statuses and stats ------------------------------------------------------------

function Simulation:_statusDef(statusId)
	local def = self.StatusDefs[statusId]
	assert(def ~= nil, "Unknown status: " .. tostring(statusId))
	return def
end

function Simulation:HasStatus(entity, statusId)
	for _, status in ipairs(entity.Statuses) do
		if status.Id == statusId then
			return true
		end
	end
	return false
end

function Simulation:HasFlag(entity, flagName)
	for _, status in ipairs(entity.Statuses) do
		local flags = self:_statusDef(status.Id).Flags
		if flags and flags[flagName] then
			return true
		end
	end
	return false
end

-- Base stat with every active status modifier applied: (base + adds) * mults.
function Simulation:GetStat(entity, statName)
	local base = entity.Stats[statName]
	if base == nil then
		base = STAT_DEFAULTS[statName] or 0
	end

	local add, mult = 0, 1
	for _, status in ipairs(entity.Statuses) do
		local mods = self:_statusDef(status.Id).Mods
		if mods then
			for _, mod in ipairs(mods) do
				if mod.Stat == statName then
					-- Strength scales how far a modifier moves the stat (1 = as written).
					local strength = status.Strength or 1
					if mod.Mode == "Add" then
						add += mod.Value * strength
					else
						mult *= 1 + (mod.Value - 1) * strength
					end
				end
			end
		end
	end
	return (base + add) * mult
end

-- Applies (or refreshes) a status. `amount` is the size of an Absorb shield.
-- Returns true if it was applied.
function Simulation:ApplyStatus(target, statusId, duration, source, amount, strength, stacks)
	local def = self:_statusDef(statusId)
	if target.Health <= 0 then
		return false
	end
	if def.Flags and def.Flags.Stunned and target.Flags.StunImmune then
		return false -- bosses cannot be frozen
	end

	local ctx = {
		Target = target,
		Source = source,
		StatusId = statusId,
		Duration = duration or def.Duration or 1,
		Amount = if amount then math.floor(amount + 0.5) else nil,
		Strength = strength or 1,
		Prevented = false,
	}
	self.Hooks:Fire("OnApplyStatus", ctx)
	if ctx.Prevented or ctx.Duration <= 0 then
		return false
	end

	local existing = nil
	for _, status in ipairs(target.Statuses) do
		if status.Id == statusId then
			existing = status
			break
		end
	end
	if existing then
		existing.Remaining = ctx.Duration
		existing.Source = if source then source.Id else nil
		existing.Strength = math.max(existing.Strength or 1, ctx.Strength)
		if def.Stacks then -- stackable damage over time: each application adds a stack, up to the status's Max
			existing.Stacks = math.min(def.Stacks.Max, (existing.Stacks or 1) + (stacks or 1))
		end
		if ctx.Amount then
			existing.Amount = math.max(existing.Amount or 0, ctx.Amount)
		end
	else
		table.insert(target.Statuses, {
			Id = statusId,
			Remaining = ctx.Duration,
			Source = if source then source.Id else nil,
			Amount = ctx.Amount,
			Strength = ctx.Strength,
			Stacks = if def.Stacks then math.min(def.Stacks.Max, stacks or 1) else nil,
		})
	end

	self:_record({
		Type = "Status",
		Target = target.Id,
		Status = statusId,
		Duration = ctx.Duration,
		Amount = ctx.Amount,
		Source = if source then source.Id else nil,
		Stacks = if def.Stacks then (function() for _, s in ipairs(target.Statuses) do if s.Id == statusId then return s.Stacks end end end)() else nil,
	})
	return true
end

-- Removes shields that have been used up.
function Simulation:_removeBrokenShields(entity)
	for index = #entity.Statuses, 1, -1 do
		local status = entity.Statuses[index]
		local flags = self:_statusDef(status.Id).Flags
		if flags and flags.Absorb and (status.Amount or 0) <= 0 then
			table.remove(entity.Statuses, index)
			self:_record({ Type = "StatusEnd", Target = entity.Id, Status = status.Id, Reason = "Broken" })
			self.Hooks:Fire("OnStatusExpired", { Entity = entity, StatusId = status.Id, Reason = "Broken" })
		end
	end
end

-- Targeting ---------------------------------------------------------------------

-- Rows ------------------------------------------------------------------------
-- Every fighter stands in the Front or Back row of its team. Melee fighters and all summons stand in front (summons are there to
-- tank), ranged fighters behind them. Enemy bosses and casters stand in the back, behind their minions. Melee attackers can only
-- reach the front-most row that still has someone alive; fighters in the Back row, and skills marked Reach = "Any", can pick
-- targets in other rows. Area attacks hit only the row of their main target (unless the skill is marked AllRows, which ultimates
-- and boss attacks are).
Simulation.DEBUFFS = { Chilled = true, Burning = true, Poisoned = true, Bleeding = true, Frozen = true, Stunned = true, Snared = true, Marked = true, Cursed = true }
Simulation.MAX_HASTE = 0.5 -- Haste shortens skill cooldowns by 1/(1+Haste); capped at +50%
Simulation.RANGED_REACH = 0.35 -- chance a back-row attacker's basic attack goes past the front row

function Simulation:RowOf(entity)
	if entity.Row then
		return entity.Row
	end
	local row = "Front"
	if entity.Minion then
		row = "Front"
	elseif entity.Team == "Party" then
		if entity.BasicAttack and entity.BasicAttack.Range == "Ranged" then
			row = "Back"
		end
	else
		local def = EnemyConfig[entity.DefId]
		if entity.Flags.StunImmune or (def and (def.IsBoss or def.Row == "Back" or def.DamageType == "Magical")) then
			row = "Back"
		end
	end
	entity.Row = row
	return row
end

-- the living opponents an attacker can reach right now (the front-most row that still has someone alive)
function Simulation:_frontRow(candidates)
	local front = {}
	for _, candidate in ipairs(candidates) do
		if self:RowOf(candidate) == "Front" then
			table.insert(front, candidate)
		end
	end
	return if #front > 0 then front else candidates
end

-- Chooses who an attacker hits. Default: the first living taunting opponent,
-- otherwise the first living opponent in the reachable row. `reachAny` (skills with Reach = "Any") looks at every row and goes
-- for the back row first. Hooks may override.
function Simulation:PickTarget(attacker, reachAny)
	local candidates = livingOf(self:_opponentsOf(attacker))
	local pool = candidates
	local snipe = reachAny == true
	if not snipe and self:RowOf(attacker) == "Back" and #candidates > 1 then
		snipe = self.Rng() < Simulation.RANGED_REACH
	end
	if snipe then
		for _, candidate in ipairs(candidates) do
			if self:RowOf(candidate) == "Back" then
				pool = { candidate }
				break
			end
		end
		if #pool == #candidates then
			pool = self:_frontRow(candidates)
		end
	else
		pool = self:_frontRow(candidates)
	end
	local default = pool[1]
	for _, candidate in ipairs(candidates) do
		if self:HasFlag(candidate, "Taunting") then
			default = candidate
			break
		end
	end

	-- enemies also go for the party's minions (unless something taunts): one roll picks a minion at random
	if attacker.Team == "Enemy" and default ~= nil and not self:HasFlag(default, "Taunting") then
		local minions = {}
		for _, candidate in ipairs(pool) do
			if candidate.Minion then
				table.insert(minions, candidate)
			end
		end
		if #minions > 0 then
			local roll = self.Rng()
			if roll < Simulation.MINION_AGGRO then
				default = minions[math.min(#minions, math.floor(roll / Simulation.MINION_AGGRO * #minions) + 1)]
			end
		end
	end

	local ctx = { Attacker = attacker, Candidates = candidates, Target = default }
	self.Hooks:Fire("PickTarget", ctx)
	return ctx.Target
end

-- Turns an effect's Target mode into a list of living entities.
function Simulation:ResolveTargets(castCtx, mode)
	local caster = castCtx.Caster
	if mode == "Primary" then
		return if castCtx.Primary and castCtx.Primary.Health > 0 then { castCtx.Primary } else {}
	elseif mode == "Self" then
		return { caster }
	elseif mode == "AllEnemies" then
		local all = livingOf(self:_opponentsOf(caster))
		if castCtx.AllRows or castCtx.Primary == nil or castCtx.Primary.Health <= 0 then
			return all
		end
		local row, hit = self:RowOf(castCtx.Primary), {}
		for _, target in ipairs(all) do
			if self:RowOf(target) == row then
				table.insert(hit, target)
			end
		end
		return hit
	elseif mode == "AllAllies" then
		return livingOf(self:_alliesOf(caster))
	elseif mode == "DeadAlly" then
		for _, ally in ipairs(self:_alliesOf(caster)) do
			if not ally.Alive and not ally.Minion then
				return { ally }
			end
		end
		return {}
	elseif mode == "LowestAlly" then
		-- The living ally (caster included) with the lowest health fraction.
		local best, bestRatio = nil, nil
		for _, ally in ipairs(livingOf(self:_alliesOf(caster))) do
			local ratio = ally.Health / self:GetStat(ally, "MaxHealth")
			if bestRatio == nil or ratio < bestRatio then
				best, bestRatio = ally, ratio
			end
		end
		return if best then { best } else {}
	end
	error("Unknown effect target mode: " .. tostring(mode))
end

-- Damage ------------------------------------------------------------------------

-- The single doorway for all damage, so every source (basic attacks and
-- abilities) automatically gets crits, stat modifiers, Defense and the hooks.
function Simulation:DealDamage(source, target, amount, info)
	info = info or {}
	local ctx = {
		Source = source,
		Target = target,
		Amount = amount,
		DamageType = info.DamageType or source.DamageType,
		Element = info.Element,
		Tag = info.Tag,
		IsCrit = false,
		Prevented = false,
	}

	-- One roll per damage instance keeps the random sequence predictable.
	local roll = self.Rng()
	if roll < self:GetStat(source, "CritChance") then
		ctx.IsCrit = true
		ctx.Amount *= self:GetStat(source, "CritMultiplier")
	end

	-- pets hit far harder than their raw skill numbers say (Config/Pets DamageScale); Beastmasters add PetDamage on top
	if type(ctx.Tag) == "string" and ctx.Tag:sub(1, 4) == "Pet_" then
		ctx.Amount *= PetConfig.DamageScale * self:GetStat(source, "PetDamage")
	end
	ctx.Amount *= self:GetStat(source, "DamageDealt")
	if ctx.DamageType == "Magical" then
		ctx.Amount *= self:GetStat(source, "MagicalDamageDealt")
	elseif ctx.DamageType == "Physical" then
		ctx.Amount *= self:GetStat(source, "PhysicalDamageDealt")
	end

	self.Hooks:Fire("OnCalculateDamage", ctx)

	-- Defense mitigation. (Magical damage also uses Defense for now; a
	-- separate magic resistance stat can be added later.)
	local defenseK = 100 * EconomyConfig.NumberScale
	ctx.Amount = ctx.Amount * defenseK / (defenseK + math.max(0, self:GetStat(target, "Defense")))
	ctx.Amount *= self:GetStat(target, "DamageTaken")

	self.Hooks:Fire("OnBeforeDamage", ctx)

	local final = 0
	if not ctx.Prevented and ctx.Amount > 0 then
		final = math.max(1, math.floor(ctx.Amount + 0.5))
	end

	-- Shields soak damage first, oldest shield first.
	local absorbed = 0
	if final > 0 then
		for _, status in ipairs(target.Statuses) do
			if final <= 0 then
				break
			end
			local flags = self:_statusDef(status.Id).Flags
			if flags and flags.Absorb and (status.Amount or 0) > 0 then
				local soak = math.min(status.Amount, final)
				status.Amount -= soak
				final -= soak
				absorbed += soak
			end
		end
	end

	if final >= target.Health and self:HasFlag(target, "PreventLethal") then
		final = math.max(0, target.Health - 1)
	end
	final = math.min(final, target.Health)

	ctx.Final = final
	ctx.Absorbed = absorbed
	target.Health -= final

	self:_record({
		Type = "Damage",
		Source = source.Id,
		Target = target.Id,
		Amount = final,
		Absorbed = absorbed,
		Crit = ctx.IsCrit,
		Tag = ctx.Tag,
		Element = ctx.Element,
		TargetHealth = target.Health,
	})

	if absorbed > 0 then
		self:_removeBrokenShields(target)
	end

	self.Hooks:Fire("OnDamageDealt", ctx)

	-- life drained from what was hurt: the attacker's own Lifesteal stat, and a minion's leech feeds its summoner
	if final > 0 and source ~= target then
		local steal = self:GetStat(source, "Lifesteal")
		if steal > 0 and source.Health > 0 then
			self:Heal(source, source, final * steal, { Tag = "Lifesteal", Element = "Shadow" })
		end
		if source.Minion and source.Leech then
			local owner = self:_entityById(source.OwnerId)
			if owner and owner.Health > 0 then
				self:Heal(source, owner, final * source.Leech, { Tag = "Lifesteal", Element = "Shadow" })
			end
		end
	end
	return final
end

-- Restores health, capped at max health. Returns the amount actually healed.
-- Dead combatants cannot be healed.
function Simulation:Heal(source, target, amount, info)
	info = info or {}
	if target.Health <= 0 then
		return 0
	end

	local ctx = {
		Source = source,
		Target = target,
		Amount = amount,
		Tag = info.Tag,
		Element = info.Element,
	}
	ctx.Amount *= self:GetStat(source, "HealingDealt")
	ctx.Amount *= self:GetStat(target, "HealingTaken")
	self.Hooks:Fire("OnHeal", ctx)

	local wanted = math.max(0, math.floor(ctx.Amount + 0.5))
	local final = math.min(wanted, self:GetStat(target, "MaxHealth") - target.Health)
	target.Health += final

	ctx.Final = final
	self:_record({
		Type = "Heal",
		Source = source.Id,
		Target = target.Id,
		Amount = final,
		Overheal = wanted - final,
		Tag = ctx.Tag,
		Element = ctx.Element,
		TargetHealth = target.Health,
	})
	return final
end

-- Returns a fallen combatant to the fight with `fraction` of max health.
-- Statuses are cleared; cooldowns carry on where they were.
function Simulation:Revive(source, target, fraction)
	if target.Alive then
		return false
	end
	target.Alive = true
	target.Statuses = {}
	target.AttackTimer = 0
	target.Health = math.max(1, math.floor(self:GetStat(target, "MaxHealth") * fraction + 0.5))
	self:_record({ Type = "Revive", Source = source.Id, Target = target.Id, TargetHealth = target.Health })
	self.Hooks:Fire("OnRevive", { Source = source, Target = target })
	return true
end

function Simulation:_basicAttack(attacker)
	local target = self:PickTarget(attacker)
	if target then
		self:DealDamage(attacker, target, self:GetStat(attacker, "Attack"), { Tag = "BasicAttack" })
	end
end

-- Abilities ---------------------------------------------------------------------

function Simulation:_conditionsMet(caster, def)
	if def.Conditions then
		for key, value in pairs(def.Conditions) do
			local check = Simulation.Conditions[key]
			assert(check ~= nil, "Unknown ability condition: " .. tostring(key))
			if not check(self, caster, value) then
				return false
			end
		end
	end
	return true
end

-- Casts one ability from a slot: spends the cooldown, then runs its effects.
function Simulation:Cast(caster, slot)
	local def = self.AbilityDefs[slot.Id] or Ultimates.Defs[slot.Id]
	assert(def ~= nil, "Unknown ability: " .. tostring(slot.Id))

	local needsPrimary = false
	for _, effect in ipairs(def.Effects) do
		if effect.Target == "Primary" or effect.Target == "AllEnemies" then
			needsPrimary = true
		end
	end

	local primary = nil
	if needsPrimary then
		primary = self:PickTarget(caster, def.Reach == "Any")
		if primary == nil then
			return false -- nobody to hit; keep the ability ready
		end
	end

	slot.Timer = AbilityStats.Cooldown(def, slot.Level) / (1 + math.clamp(self:GetStat(caster, "Haste"), 0, Simulation.MAX_HASTE))

	local ctx = {
		Caster = caster,
		Ability = def,
		Level = slot.Level,
		Primary = primary,
		AllRows = def.AllRows == true or slot.IsUltimate == true or caster.Flags.StunImmune == true,
		Cancelled = false,
	}
	self.Hooks:Fire("OnAbilityCast", ctx)
	if ctx.Cancelled then
		return false
	end

	slot.Uses = (slot.Uses or 0) + 1
	self:_record({ Type = "Cast", Source = caster.Id, Ability = def.Id, Level = slot.Level })
	if caster.Team == "Party" and not slot.IsUltimate and not def.NoCharge then
		self:AddUltimateCharge(Ultimates.ChargePerCast)
	end

	local castTime = if slot.IsUltimate or not self.CastTimes or caster.Team ~= "Party" then 0 else AbilityStats.CastTime(def)
	if castTime > EPSILON then
		-- winding up: effects land when the cast finishes (see _advanceCast)
		caster.Casting = { Ctx = ctx, Def = def, Remaining = castTime }
		return true
	end
	self:_resolveCast(ctx, def)
	return true
end

function Simulation:_resolveCast(ctx, def)
	for _, effect in ipairs(def.Effects) do
		local handler = Simulation.Effects[effect.Type]
		assert(handler ~= nil, "Unknown effect type: " .. tostring(effect.Type))
		handler(self, ctx, effect)
	end
end

-- Counts a wind-up down; when it ends the effects land and the caster is
-- locked out of casting for AbilityStats.AfterCastDelay seconds.
function Simulation:_advanceCast(entity)
	local casting = entity.Casting
	if casting == nil then
		return
	end
	if not entity.Alive then
		entity.Casting = nil
		return
	end
	casting.Remaining -= Simulation.TICK
	if casting.Remaining > EPSILON then
		return
	end
	entity.Casting = nil
	local ctx = casting.Ctx
	if ctx.Primary ~= nil and not ctx.Primary.Alive then
		ctx.Primary = self:PickTarget(entity, casting.Def.Reach == "Any")
	end
	local needsPrimary = false
	for _, effect in ipairs(casting.Def.Effects) do
		if effect.Target == "Primary" then
			needsPrimary = true
		end
	end
	if needsPrimary and ctx.Primary == nil then
		entity.CastLock = AbilityStats.AfterCastDelay
		return
	end
	self:_resolveCast(ctx, casting.Def)
	entity.CastLock = AbilityStats.AfterCastDelay
end

-- Party ultimate ----------------------------------------------------------------
-- The party shares one gauge. It fills with time and with every ability the
-- party casts, and the ultimate fires by itself when full (see Config/Ultimates).

function Simulation:AddUltimateCharge(amount)
	local ultimate = self.Ultimate
	if ultimate and self.Result == nil then
		ultimate.Charge = math.min(Ultimates.ChargeNeeded, ultimate.Charge + amount)
	end
end

function Simulation:_tryUltimate()
	local ultimate = self.Ultimate
	if ultimate == nil or ultimate.Charge < Ultimates.ChargeNeeded - EPSILON then
		return false
	end
	local caster = nil
	for _, member in ipairs(livingOf(self.Party)) do
		if not member.Minion then
			caster = member
			break
		end
	end
	if caster == nil then
		return false
	end
	local slot = { Id = ultimate.Id, Level = ultimate.Level, Timer = 0, Uses = 0, IsUltimate = true }
	if self:Cast(caster, slot) then
		ultimate.Charge = 0
		self:_record({ Type = "Ultimate", Source = caster.Id, Ability = ultimate.Id })
		return true
	end
	return false
end

-- Casts the first ready ability whose conditions are met (one per tick).
function Simulation:_tryCast(caster)
	if caster.Casting ~= nil or (caster.CastLock or 0) > EPSILON or self:HasFlag(caster, "Stunned") then
		return false
	end
	for _, slot in ipairs(caster.Abilities) do
		if slot.Timer <= EPSILON then
			local def = self.AbilityDefs[slot.Id]
			assert(def ~= nil, "Unknown ability: " .. tostring(slot.Id))
			local spent = def.UsesPerCombat ~= nil and (slot.Uses or 0) >= def.UsesPerCombat
			if def.Pet and def.NoCharge and tostring(def.Id):sub(1, 10) == "Pet_Strike" then
				spent = true -- the pet's own strike is cast apart from the owner's skills (see _tryPetStrike)
			end
			if not spent and self:_conditionsMet(caster, def) and self:Cast(caster, slot) then
				return true
			end
		end
	end
	return false
end

-- A pet strikes on its own timer, whatever its owner is doing (casting, stunned or busy with other skills).
function Simulation:_tryPetStrike(caster)
	for _, slot in ipairs(caster.Abilities) do
		if slot.Timer <= EPSILON then
			local def = self.AbilityDefs[slot.Id]
			if def and def.Pet and def.NoCharge and tostring(def.Id):sub(1, 10) == "Pet_Strike" then
				self:Cast(caster, slot)
				return
			end
		end
	end
end

-- Counts down cooldowns and status durations by one tick.
function Simulation:_entityById(id)
	for _, list in ipairs({ self.Party, self.Enemies }) do
		for _, e in ipairs(list) do
			if e.Id == id then
				return e
			end
		end
	end
	return nil
end

function Simulation:_tickTimers(entity)
	for _, slot in ipairs(entity.Abilities) do
		local before = slot.Timer
		slot.Timer = math.max(0, slot.Timer - Simulation.TICK)
		local def = self.AbilityDefs[slot.Id]
		-- warn the players shortly before a big enemy attack lands
		if def and def.Telegraph and entity.Team == "Enemy" and before > def.Telegraph + EPSILON and slot.Timer <= def.Telegraph + EPSILON then
			self:_record({ Type = "Telegraph", Source = entity.Id, Ability = def.Id, In = slot.Timer })
		end
	end

	for index = #entity.Statuses, 1, -1 do
		local status = entity.Statuses[index]
		-- damage over time (Burning, Poisoned): the status def has Dot = { Interval, Multiplier, DamageType, Element, Tag }
		local dot = self:_statusDef(status.Id).Dot
		if dot and entity.Health > 0 then
			status.DotClock = (status.DotClock or 0) + Simulation.TICK
			if status.DotClock >= dot.Interval - EPSILON then
				status.DotClock -= dot.Interval
				local source = (status.Source and self:_entityById(status.Source)) or entity
				local stacks = status.Stacks or 1
				local tick = self:GetStat(source, "Attack") * dot.Multiplier * (status.Strength or 1) * stacks
				if dot.PercentMaxHealth then
					tick += percentDamage(self, source, entity, dot.PercentMaxHealth * stacks * (status.Strength or 1), (dot.PercentCap or 0.3) * stacks)
				end
				self:DealDamage(source, entity, tick, {
					Tag = dot.Tag or status.Id, DamageType = dot.DamageType or "Magical", Element = dot.Element, Dot = true,
				})
			end
		end
		status.Remaining -= Simulation.TICK
		if status.Remaining <= EPSILON then
			table.remove(entity.Statuses, index)
			self:_record({ Type = "StatusEnd", Target = entity.Id, Status = status.Id })
			self.Hooks:Fire("OnStatusExpired", { Entity = entity, StatusId = status.Id })
		end
	end
end

-- Fight flow --------------------------------------------------------------------

function Simulation:_checkEnd()
	local winner = nil
	if not anyAlive(self.Party) then
		winner = "Enemy"
	elseif not anyAlive(self.Enemies) then
		winner = "Party"
	elseif self.Time >= self.MaxSeconds - EPSILON then
		winner = "Timeout"
	end
	if winner == nil then
		return
	end

	local survivors = {}
	for _, entity in ipairs(self.Party) do
		if entity.Alive and not entity.Minion then
			table.insert(survivors, entity.Id)
		end
	end

	self.Result = { Winner = winner, Duration = self.Time, Survivors = survivors }
	self:_record({ Type = "End", Winner = winner })
	self.Hooks:Fire("OnBattleEnd", self.Result)
end

-- Advances the fight by one tick.
function Simulation:Step()
	if self.Result then
		return
	end

	self.Ticks += 1
	self.Time = self.Ticks * Simulation.TICK

	-- Everyone alive at the start of the tick acts, even if killed by an
	-- earlier actor this same tick. Deaths resolve at the end, so neither
	-- team gets an advantage from list order.
	local actors = {}
	for _, list in ipairs({ self.Party, self.Enemies }) do
		for _, entity in ipairs(list) do
			if entity.Alive then
				table.insert(actors, entity)
			end
		end
	end

	for _, entity in ipairs(actors) do
		self:_tickTimers(entity)
		if entity.CastLock and entity.CastLock > 0 then
			entity.CastLock = math.max(0, entity.CastLock - Simulation.TICK)
		end
		self:_advanceCast(entity)
	end

	self:AddUltimateCharge(Ultimates.ChargePerSecond * Simulation.TICK)
	self:_tryUltimate()

	for _, entity in ipairs(actors) do
		if entity.Team == "Party" then
			self:_tryPetStrike(entity)
		end
		self:_tryCast(entity)

		entity.AttackTimer += Simulation.TICK
		if self:HasFlag(entity, "Stunned") then
			entity.AttackTimer = math.min(entity.AttackTimer, 0)
		end
		local cooldown = 1 / math.max(self:GetStat(entity, "AttackSpeed"), 0.05)
		while entity.AttackTimer >= cooldown - EPSILON do
			entity.AttackTimer -= cooldown
			self:_basicAttack(entity)
		end
	end

	-- deaths (including anything raised this tick); minions are bound to their summoner and fall with it
	for _, list in ipairs({ self.Party, self.Enemies }) do
		for _, entity in ipairs(list) do
			if entity.Minion and entity.Alive and entity.Health > 0 then
				local owner = self:_entityById(entity.OwnerId)
				if owner == nil or owner.Health <= 0 then
					entity.Health = 0
				end
			end
			if entity.Alive and entity.Health <= 0 then
				entity.Alive = false
				self:_record({ Type = "Death", Target = entity.Id })
				self.Hooks:Fire("OnDeath", { Entity = entity })
			end
		end
	end

	self:_checkEnd()
end

-- Runs the whole fight instantly and returns the Result.
function Simulation:Run()
	while not self.Result do
		self:Step()
	end
	return self.Result
end

return Simulation
