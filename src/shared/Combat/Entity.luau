--[[
	Entity (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > Entity

	A combatant is a plain table, not a Roblox Instance. The server simulates
	fights on these tables and the client only draws the results.

	Entity.new{ Id, Name?, Team, DefId?, DamageType?, BasicAttack?, Stats, Abilities? }
	  Team       "Party" or "Enemy"
	  Stats      MaxHealth (required), Attack, Defense, AttackSpeed,
	             CritChance, CritMultiplier (all optional)
	  Abilities  list of { Id = "Fireball", Level = 1, Timer = 0 }, in priority order
	             (Timer = seconds before the first cast; bosses use it to schedule their attacks)
	             (slot 1 is checked first). Definitions live in Config/Abilities.

	Fields the simulation maintains while fighting:
	  Statuses   active statuses: { Id, Remaining, Source }. Read them with
	             Simulation:HasStatus / GetStat rather than directly.
	  Flags      free-form table for seasonal mechanics (markers, counters).
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local Entity = {}

function Entity.new(def)
	assert(def.Id ~= nil and def.Team ~= nil, "Entity needs Id and Team")
	assert(def.Stats ~= nil and def.Stats.MaxHealth ~= nil, "Entity needs Stats.MaxHealth")

	local stats = TableUtil.DeepCopy(def.Stats)

	local abilities = {}
	for _, slot in ipairs(def.Abilities or {}) do
		assert(slot.Id ~= nil, "Ability slot needs an Id")
		table.insert(abilities, { Id = slot.Id, Level = slot.Level or 1, Timer = slot.Timer or 0, Uses = 0 })
	end

	return {
		Id = def.Id,
		Name = def.Name or def.Id,
		Team = def.Team,
		DefId = def.DefId,
		PetId = def.PetId, -- party members: the equipped pet (display only)
		DamageType = def.DamageType or "Physical",
		BasicAttack = def.BasicAttack, -- { Id, DisplayName, Range }; presentation only

		Stats = stats,
		Health = stats.MaxHealth,
		Alive = true,
		AttackTimer = 0,

		Abilities = abilities, -- Timer = seconds until the ability is ready
		Statuses = {},
		Flags = {},
	}
end

return Entity
