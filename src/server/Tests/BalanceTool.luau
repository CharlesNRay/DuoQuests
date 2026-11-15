--[[
	BalanceTool (ModuleScript)
	Location: ServerScriptService > Server > Tests > BalanceTool

	A simulated "auto-player" for checking pacing. It plays a Warrior + Cleric
	party through the real stage, reward and spending code on a game clock
	(fight length + a short pause between fights) and records a snapshot at
	chosen hours. Used by PacingTests; also handy when tuning Config/Economy and
	Config/Stages.

	The auto-player is deliberately simple: fight the stage the party is on,
	then spend everything (unlock the cheapest skill it can afford, level its
	lowest slot, equip the best skills it owns). Real players will do better
	and worse, so treat the output as a guide, not a prediction.

	BalanceTool.Run(m, options) -> { snapshots }
	  m                 the module table (ProfileTemplate, StageRunner, Skills, Economy, Classes)
	  options.Hours     list of hours to snapshot at, e.g. { 0.25, 2, 14 }
	  options.Intermission  seconds between fights (default 2)

	Each snapshot: { Hours, Frontier, Level, SlotAverage, Owned (Warrior skills owned),
	                 Fights }
]]

local BalanceTool = {}

local function spend(m, profile, classId)
	local progressed = true
	while progressed do
		progressed = false
		for _, abilityId in ipairs(m.Skills.Pool(classId)) do
			if not profile.Season.OwnedAbilities[abilityId] and m.Economy.UnlockAbility(profile, classId, abilityId) then
				progressed = true
				break
			end
		end
		local lowest, lowestLevel = 1, math.huge
		for index, level in ipairs(profile.Season.SlotLevels[classId]) do
			if level < lowestLevel then
				lowest, lowestLevel = index, level
			end
		end
		if m.Economy.LevelSlot(profile, classId, lowest) then
			progressed = true
		end
	end
end

local function equipBest(m, profile, classId)
	local owned = {}
	for _, abilityId in ipairs(m.Skills.Pool(classId)) do
		if profile.Season.OwnedAbilities[abilityId] then
			table.insert(owned, abilityId)
		end
	end
	local best = {}
	for index = #owned, math.max(1, #owned - m.Skills.SLOTS + 1), -1 do
		table.insert(best, owned[index])
	end
	m.Economy.Equip(profile, classId, best)
end

-- Pets: level the equipped pet whenever it costs under 30% of the gold on hand.
local function spendPets(m, profile)
	local petId = m.Pets.Active(profile)
	while petId do
		local level = m.Pets.Level(profile, petId)
		if level >= m.Pets.MaxLevel or m.Pets.LevelCost(level) > profile.Season.Currencies.Gold * 0.3 then
			break
		end
		m.Pets.LevelUp(profile, petId)
	end
end

-- Gear: wear the strongest item of each slot, sell the rest.
local function equipGear(m, profile)
	local equipment = profile.Season.Equipment
	local progressed = true
	while progressed do
		progressed = false
		for _, item in ipairs(equipment.Inventory) do
			local _, value = m.Gear.StatOf(item)
			local worn = equipment.Equipped[item.Slot]
			local _, wornValue = if worn then m.Gear.StatOf(worn) else nil, 0
			if value > (wornValue or 0) then
				m.Gear.Equip(profile, item.Id)
				progressed = true
				break
			end
		end
	end
	for index = #equipment.Inventory, 1, -1 do
		m.Gear.Sell(profile, equipment.Inventory[index].Id)
	end
end

function BalanceTool.Run(m, options)
	local hours = options.Hours
	local intermission = options.Intermission or 2
	local last = hours[#hours] * 3600

	local warrior, cleric = m.ProfileTemplate.New(), m.ProfileTemplate.New()
	cleric.Season.ClassId = "Cleric"
	local team = {
		{ Id = "p1", Name = "Warrior", Profile = warrior },
		{ Id = "p2", Name = "Cleric", Profile = cleric },
	}
	if options.Solo then
		team = { team[1] }
	end

	local clock, stage, seed, fights = 0, 1, 1, 0
	local snapshots, nextSnapshot = {}, 1

	while clock < last do
		seed += 1
		fights += 1
		local outcome = m.StageRunner.Run(team, stage, seed)
		clock += outcome.Duration + intermission
		stage = outcome.NextStage
		for _, member in ipairs(team) do
			local classId = member.Profile.Season.ClassId
			if options.Pets then
				spendPets(m, member.Profile)
			end
			if options.Gear then
				equipGear(m, member.Profile)
			end
			spend(m, member.Profile, classId)
			equipBest(m, member.Profile, classId)
		end

		while hours[nextSnapshot] and clock >= hours[nextSnapshot] * 3600 do
			local owned = 0
			for _, abilityId in ipairs(m.Classes.Warrior.AbilityPool) do
				if warrior.Season.OwnedAbilities[abilityId] then
					owned += 1
				end
			end
			local total = 0
			for _, level in ipairs(warrior.Season.SlotLevels.Warrior) do
				total += level
			end
			snapshots[nextSnapshot] = {
				Hours = hours[nextSnapshot],
				Frontier = warrior.Season.HighestStage,
				Level = warrior.Season.Level,
				SlotAverage = total / #warrior.Season.SlotLevels.Warrior,
				Owned = owned,
				Fights = fights,
			}
			nextSnapshot += 1
		end
	end
	return snapshots
end

return BalanceTool
