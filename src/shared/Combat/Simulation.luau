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
	  Death   { Target }
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
	  OnBattleEnd       the Result table

	Extending without touching this file:
	  Simulation.Effects[typeName]    = function(sim, castCtx, effect) ... end
	  Simulation.Conditions[keyName]  = function(sim, caster, value) return bool end
]]

local Rng = require(script.Parent.Rng)
local Hooks = require(script.Parent.Hooks)
local Abilities = require(script.Parent.Parent.Config.Abilities)
local Statuses = require(script.Parent.Parent.Config.Statuses)
local Rarities = require(script.Parent.Parent.Config.Rarities)

local Simulation = {}
Simulation.__index = Simulation

Simulation.TICK = 0.1 -- seconds of fight time per Step
Simulation.DEFAULT_MAX_SECONDS = 180

local EPSILON = 1e-9 -- avoids float drift delaying an action by a whole tick

-- Used when an entity has no value for a stat, so modifiers can still apply.
local STAT_DEFAULTS = {
	AttackSpeed = 1,
	CritMultiplier = 1.5,
	DamageDealt = 1,
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
		if entity.Alive then
			return true
		end
	end
	return false
end

-- Power multiplier for a skill's level: the skill's own LevelBonus, else its
-- rarity's PowerPerLevel, else 10% per level.
local function levelFactor(castCtx)
	local ability = castCtx.Ability
	local rarity = Rarities[ability.Rarity]
	local bonus = ability.LevelBonus or (rarity and rarity.PowerPerLevel) or 0.1
	return 1 + bonus * (castCtx.Level - 1)
end

-- Size of a Heal or Shield effect for one target.
local function supportAmount(sim, castCtx, effect, target)
	return ((effect.Multiplier or 0) * sim:GetStat(castCtx.Caster, "Attack") + (effect.PercentMaxHealth or 0) * sim:GetStat(
		target,
		"MaxHealth"
	)) * levelFactor(castCtx)
end

-- Effect handlers ---------------------------------------------------------------
-- Each receives (sim, castCtx, effect). Register more in other modules.

Simulation.Effects = {
	Damage = function(sim, castCtx, effect)
		local caster = castCtx.Caster
		local magnitude = effect.Multiplier * levelFactor(castCtx)
		local damageType = effect.DamageType or castCtx.Ability.DamageType

		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			if target.Health > 0 then
				sim:DealDamage(caster, target, sim:GetStat(caster, "Attack") * magnitude, {
					Tag = castCtx.Ability.Id,
					DamageType = damageType,
					Element = castCtx.Ability.Element,
				})
			end
		end
	end,

	ApplyStatus = function(sim, castCtx, effect)
		for _, target in ipairs(sim:ResolveTargets(castCtx, effect.Target)) do
			sim:ApplyStatus(target, effect.Status, effect.Duration, castCtx.Caster)
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
				effect.Duration,
				castCtx.Caster,
				supportAmount(sim, castCtx, effect, target)
			)
		end
	end,
}

-- Condition checks --------------------------------------------------------------
-- Each receives (sim, caster, value) and returns true when casting is allowed.

Simulation.Conditions = {
	MinEnemies = function(sim, caster, value)
		return #livingOf(sim:_opponentsOf(caster)) >= value
	end,

	SelfHealthBelow = function(sim, caster, value)
		return caster.Health / sim:GetStat(caster, "MaxHealth") < value
	end,

	SelfLacksStatus = function(sim, caster, statusId)
		return not sim:HasStatus(caster, statusId)
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
		OnEvent = options.OnEvent,
		AbilityDefs = options.AbilityDefs or Abilities,
		StatusDefs = options.StatusDefs or Statuses,

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
					if mod.Mode == "Add" then
						add += mod.Value
					else
						mult *= mod.Value
					end
				end
			end
		end
	end
	return (base + add) * mult
end

-- Applies (or refreshes) a status. `amount` is the size of an Absorb shield.
-- Returns true if it was applied.
function Simulation:ApplyStatus(target, statusId, duration, source, amount)
	local def = self:_statusDef(statusId)
	if target.Health <= 0 then
		return false
	end

	local ctx = {
		Target = target,
		Source = source,
		StatusId = statusId,
		Duration = duration or def.Duration or 1,
		Amount = if amount then math.floor(amount + 0.5) else nil,
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
		if ctx.Amount then
			existing.Amount = math.max(existing.Amount or 0, ctx.Amount)
		end
	else
		table.insert(target.Statuses, {
			Id = statusId,
			Remaining = ctx.Duration,
			Source = if source then source.Id else nil,
			Amount = ctx.Amount,
		})
	end

	self:_record({
		Type = "Status",
		Target = target.Id,
		Status = statusId,
		Duration = ctx.Duration,
		Amount = ctx.Amount,
		Source = if source then source.Id else nil,
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

-- Chooses who an attacker hits. Default: the first living taunting opponent,
-- otherwise the first living opponent. Hooks may override.
function Simulation:PickTarget(attacker)
	local candidates = livingOf(self:_opponentsOf(attacker))
	local default = candidates[1]
	for _, candidate in ipairs(candidates) do
		if self:HasFlag(candidate, "Taunting") then
			default = candidate
			break
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
		return livingOf(self:_opponentsOf(caster))
	elseif mode == "AllAllies" then
		return livingOf(self:_alliesOf(caster))
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

	ctx.Amount *= self:GetStat(source, "DamageDealt")
	if ctx.DamageType == "Magical" then
		ctx.Amount *= self:GetStat(source, "MagicalDamageDealt")
	elseif ctx.DamageType == "Physical" then
		ctx.Amount *= self:GetStat(source, "PhysicalDamageDealt")
	end

	self.Hooks:Fire("OnCalculateDamage", ctx)

	-- Defense mitigation. (Magical damage also uses Defense for now; a
	-- separate magic resistance stat can be added later.)
	ctx.Amount = ctx.Amount * 100 / (100 + math.max(0, self:GetStat(target, "Defense")))
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
	local def = self.AbilityDefs[slot.Id]
	assert(def ~= nil, "Unknown ability: " .. tostring(slot.Id))

	local needsPrimary = false
	for _, effect in ipairs(def.Effects) do
		if effect.Target == "Primary" then
			needsPrimary = true
		end
	end

	local primary = nil
	if needsPrimary then
		primary = self:PickTarget(caster)
		if primary == nil then
			return false -- nobody to hit; keep the ability ready
		end
	end

	slot.Timer = def.Cooldown

	local ctx = {
		Caster = caster,
		Ability = def,
		Level = slot.Level,
		Primary = primary,
		Cancelled = false,
	}
	self.Hooks:Fire("OnAbilityCast", ctx)
	if ctx.Cancelled then
		return false
	end

	self:_record({ Type = "Cast", Source = caster.Id, Ability = def.Id, Level = slot.Level })

	for _, effect in ipairs(def.Effects) do
		local handler = Simulation.Effects[effect.Type]
		assert(handler ~= nil, "Unknown effect type: " .. tostring(effect.Type))
		handler(self, ctx, effect)
	end
	return true
end

-- Casts the first ready ability whose conditions are met (one per tick).
function Simulation:_tryCast(caster)
	for _, slot in ipairs(caster.Abilities) do
		if slot.Timer <= EPSILON then
			local def = self.AbilityDefs[slot.Id]
			assert(def ~= nil, "Unknown ability: " .. tostring(slot.Id))
			if self:_conditionsMet(caster, def) and self:Cast(caster, slot) then
				return true
			end
		end
	end
	return false
end

-- Counts down cooldowns and status durations by one tick.
function Simulation:_tickTimers(entity)
	for _, slot in ipairs(entity.Abilities) do
		slot.Timer = math.max(0, slot.Timer - Simulation.TICK)
	end

	for index = #entity.Statuses, 1, -1 do
		local status = entity.Statuses[index]
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
		if entity.Alive then
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
	end

	for _, entity in ipairs(actors) do
		self:_tryCast(entity)

		entity.AttackTimer += Simulation.TICK
		local cooldown = 1 / math.max(self:GetStat(entity, "AttackSpeed"), 0.05)
		while entity.AttackTimer >= cooldown - EPSILON do
			entity.AttackTimer -= cooldown
			self:_basicAttack(entity)
		end
	end

	for _, entity in ipairs(actors) do
		if entity.Alive and entity.Health <= 0 then
			entity.Alive = false
			self:_record({ Type = "Death", Target = entity.Id })
			self.Hooks:Fire("OnDeath", { Entity = entity })
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
