--[[
	Sparring (ModuleScript): friendly duels in the Training Grounds sparring ring (docs/TOWN.md). Your hero against one
	other hero (a player on this server, or one of your party's companions), 1 v 1, each with its full build.

	The combat sim is not quite symmetric (the "Party" side has cast times, the "Enemy" side respects taunts), so a duel
	is two bouts with the sides swapped. A bout is won by knocking the other out, or on time by the higher share of
	health left. Win both bouts, or one and more health over both: you win. No power is at stake; the first win of
	the day pays DailyWinStones Wishstones.

	  Sparring.Duel(me, them, seed)          me / them as StageRunner.NewParty takes members ({ Id, Name, Profile | Snapshot })
	      -> { Won, Bouts = { { Won, Mine, Theirs, Seconds } x2 }, MyDamage, TheirDamage, Fight }   Mine/Theirs = health share left
	      Fight = the first bout for the client to replay: { Roster, Events, Duration } (the opponent's entries have Hero = true)
	  Sparring.Record(profile, won, day)     -> reward lines (first win of the day pays), keeps Season.Sparring { Wins, Losses, PaidDay }
	  Sparring.Stats(profile)                -> { Wins, Losses }
]]
local StageRunner = require(script.Parent.StageRunner)
local Simulation = require(script.Parent.Combat.Simulation)
local Gear = require(script.Parent.Gear)

local Sparring = {}

Sparring.Seconds = 45
Sparring.DailyWinStones = 3

local function bout(a, b, seed)
	local party = StageRunner.NewParty({ a })
	local foes = StageRunner.NewParty({ b })
	for _, entity in ipairs(foes) do
		entity.Team = "Enemy"
	end
	local sim = Simulation.new({ Party = party, Enemies = foes, Seed = seed, MaxSeconds = Sparring.Seconds, RecordEvents = true })
	-- the roster the client needs to draw both heroes (like StageRunner's, but the other side are heroes too)
	local roster = {}
	local function lookOf(member)
		local worn = if member.Profile then member.Profile.Season.Equipment and member.Profile.Season.Equipment.Equipped else member.Snapshot and member.Snapshot.Gear
		return Gear.Look(worn)
	end
	for _, pair in ipairs({ { party, a, false }, { foes, b, true } }) do
		for _, entity in ipairs(pair[1]) do
			table.insert(roster, {
				Id = entity.Id, Name = entity.Name, Team = entity.Team, DefId = entity.DefId, PetId = entity.PetId,
				Look = lookOf(pair[2]), MaxHealth = entity.Stats.MaxHealth, Row = sim:RowOf(entity),
				UserId = tonumber(entity.Id), Hero = if pair[3] then true else nil, Ghost = if pair[2].Profile then nil else true,
			})
		end
	end
	local result = sim:Run()
	local function share(list)
		local hp, max = 0, 0
		for _, e in ipairs(list) do
			if not e.Minion then
				hp += math.max(0, e.Health or 0)
				max += e.Stats.MaxHealth or 1
			end
		end
		return if max > 0 then hp / max else 0
	end
	-- damage dealt by each side (summons count for the side that raised them)
	local sideOf = {}
	for _, x in ipairs(party) do sideOf[x.Id] = "A" end
	for _, x in ipairs(foes) do sideOf[x.Id] = "B" end
	local damageBy = {}
	for _, e in ipairs(sim.Events or {}) do
		if e.Type == "Spawn" and e.Entity and e.Entity.Owner then
			sideOf[e.Entity.Id] = sideOf[e.Entity.Owner]
		elseif e.Type == "Damage" and sideOf[e.Source] and sideOf[e.Target] ~= sideOf[e.Source] then
			local side = sideOf[e.Source]
			damageBy[side] = (damageBy[side] or 0) + (e.Amount or 0)
		end
	end
	local mine, theirs = share(party), share(foes)
	local won = if result.Winner == "Party" then true elseif result.Winner == "Enemy" then false else mine >= theirs
	return { Won = won, Mine = mine, Theirs = theirs, Seconds = result.Duration or Sparring.Seconds, Fight = { Roster = roster, Events = sim.Events, Duration = result.Duration } }, damageBy.A or 0, damageBy.B or 0
end

function Sparring.Duel(me, them, seed)
	seed = seed or 1
	local first, myDamage1, theirDamage1 = bout(me, them, seed)
	local second, theirDamage2, myDamage2 = bout(them, me, seed + 1)
	-- the second bout is from their side: flip it to mine
	second = { Won = not second.Won, Mine = second.Theirs, Theirs = second.Mine, Seconds = second.Seconds }
	local fight = first.Fight
	first.Fight = nil
	local wins = (if first.Won then 1 else 0) + (if second.Won then 1 else 0)
	local won = if wins == 2 then true elseif wins == 0 then false else (first.Mine + second.Mine) >= (first.Theirs + second.Theirs)
	return { Won = won, Bouts = { first, second }, MyDamage = math.floor(myDamage1 + myDamage2), TheirDamage = math.floor(theirDamage1 + theirDamage2), Fight = fight }
end

function Sparring.Record(profile, won, day)
	local s = profile.Season.Sparring or { Wins = 0, Losses = 0 }
	profile.Season.Sparring = s
	local lines = {}
	if won then
		s.Wins += 1
		if s.PaidDay ~= day then
			s.PaidDay = day
			local c = profile.Season.Currencies
			c.Wishstones = (c.Wishstones or 0) + Sparring.DailyWinStones
			table.insert(lines, ("First win today: +%d Wishstones"):format(Sparring.DailyWinStones))
		end
	else
		s.Losses += 1
	end
	return lines
end

function Sparring.Stats(profile)
	local s = profile.Season.Sparring
	return { Wins = s and s.Wins or 0, Losses = s and s.Losses or 0 }
end

return Sparring
