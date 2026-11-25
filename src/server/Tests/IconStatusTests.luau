--[[
	IconStatusTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > IconStatusTests

	- every skill a hero can own, every status, ultimate, pet skill and passive has its own icon (Config/IconLooks),
	  and no glyph is used twice (talents, runes and consumables included);
	- StatusText spells out every status and summarises a recorded fight (the combat log's Effects view);
	- Simulation metrics (balance tools) add up to the damage events;
	- the late-game guards: enemy scale keeps growing past LateGrowth.From, percent gear stats flatten past PercentSoft.From.
	require(...IconStatusTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			IconLooks = require(Shared.Config.IconLooks), Abilities = require(Shared.Config.Abilities), Classes = require(Shared.Config.Classes),
			SubclassConfig = require(Shared.Config.Subclasses), Statuses = require(Shared.Config.Statuses), UltimateConfig = require(Shared.Config.Ultimates),
			PetConfig = require(Shared.Config.Pets), PassiveConfig = require(Shared.Config.Passives), TalentConfig = require(Shared.Config.Talents),
			RunesConfig = require(Shared.Config.Runes), ConsumableConfig = require(Shared.Config.Consumables), StatusText = require(Shared.StatusText),
			StageRunner = require(Shared.StageRunner), ProfileTemplate = require(Shared.ProfileTemplate), Stages = require(Shared.Stages),
			StageConfig = require(Shared.Config.Stages), Gear = require(Shared.Gear), GearConfig = require(Shared.Config.Gear),
		}
	end
	local Looks = m.IconLooks
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("IconStatusTests")

	-- icons: everything a player sees has its own
	local missing = {}
	for classId, class in pairs(m.Classes) do
		if type(class) == "table" and class.AbilityPool then
			for _, id in ipairs(class.AbilityPool) do
				if not Looks.Skills[id] then table.insert(missing, classId .. ":" .. id) end
			end
		end
	end
	for _, list in pairs(m.SubclassConfig.Paths or m.SubclassConfig) do
		if type(list) == "table" then
			for _, path in pairs(list) do
				if type(path) == "table" and path.Skills then
					for _, id in ipairs(path.Skills) do
						if not Looks.Skills[id] then table.insert(missing, "path:" .. id) end
					end
				end
			end
		end
	end
	check("every class and path skill has an icon (missing: " .. table.concat(missing, ", ") .. ")", #missing == 0)
	missing = {}
	for id in pairs(m.Statuses) do
		if not Looks.Statuses[id] then table.insert(missing, id) end
	end
	check("every status has an icon (missing: " .. table.concat(missing, ", ") .. ")", #missing == 0)
	missing = {}
	for id in pairs(m.UltimateConfig.Defs or m.UltimateConfig) do
		if type(id) == "string" and not Looks.Ultimates[id] then table.insert(missing, id) end
	end
	check("every ultimate has an icon (missing: " .. table.concat(missing, ", ") .. ")", #missing == 0)
	missing = {}
	for _, def in pairs(m.PetConfig.Defs) do
		if def.Skill and not Looks.PetSkills[def.Skill.Name] then table.insert(missing, def.Skill.Name) end
	end
	check("every pet skill has an icon (missing: " .. table.concat(missing, ", ") .. ")", #missing == 0)
	missing = {}
	for id in pairs(m.PassiveConfig.Defs) do
		if not Looks.Passives[id] then table.insert(missing, id) end
	end
	check("every passive has an icon (missing: " .. table.concat(missing, ", ") .. ")", #missing == 0)

	local seen, dupes = {}, {}
	local function see(glyph, who)
		local g = glyph:gsub("\239\184\143", "") -- ignore the emoji variation selector (U+FE0F)
		if seen[g] then table.insert(dupes, who .. "=" .. seen[g]) else seen[g] = who end
	end
	for _, group in ipairs({ "Skills", "Statuses", "Ultimates", "PetSkills", "Passives" }) do
		for id, look in pairs(Looks[group]) do see(look.Glyph, group .. "." .. id) end
	end
	for id, def in pairs(m.TalentConfig.Defs) do see(def.Glyph, "Talent." .. id) end
	for id, def in pairs(m.RunesConfig.Stats) do see(def.Glyph, "Rune." .. id) end
	for _, def in pairs(m.ConsumableConfig.Defs or m.ConsumableConfig) do
		if type(def) == "table" and def.Glyph then see(def.Glyph, "Item." .. tostring(def.Id)) end
	end
	check("no icon glyph is used twice (" .. table.concat(dupes, ", ") .. ")", #dupes == 0)

	-- status words
	local blank = {}
	for id in pairs(m.Statuses) do
		local d = m.StatusText.Describe(id)
		if d.Text == "" or d.Name == "" then table.insert(blank, id) end
	end
	check("every status has words (blank: " .. table.concat(blank, ", ") .. ")", #blank == 0)
	check("Fortified spells out its number", m.StatusText.Describe("Fortified").Text:find("+50%% Defense") ~= nil)
	check("Marked says it takes more damage", m.StatusText.Describe("Marked").Text:find("30%% more damage") ~= nil)

	-- a recorded fight: summary and the live view
	local p = m.ProfileTemplate.New()
	p.Permanent.UnlockedClasses.Cleric = true
	p.Season.ClassId = "Cleric"
	m.ProfileTemplate.GrantClassStarters(p.Season, "Cleric")
	p.Season.Level, p.Season.HighestStage = 20, 20
	local q = m.ProfileTemplate.New()
	q.Permanent.UnlockedClasses.Warrior = true
	q.Season.ClassId = "Warrior"
	m.ProfileTemplate.GrantClassStarters(q.Season, "Warrior")
	q.Season.Level, q.Season.HighestStage = 20, 20
	local team = { { Id = "1", Name = "Cleo", Profile = p }, { Id = "2", Name = "Wade", Profile = q } }
	local outcome = m.StageRunner.Run(team, 12, 7, nil, true, { NoRewards = true })
	local fight = { Events = outcome.Events, Roster = outcome.Roster, Duration = outcome.Duration }
	local summary = m.StatusText.Summary(fight)
	check("the fight's effects are summarised", #summary > 0)
	local sane = true
	for _, row in ipairs(summary) do
		if row.Applied < 1 or row.Uptime < 0 or row.Uptime > outcome.Duration * 8 + 1 or row.Text == nil then sane = false end
	end
	check("summary rows have counts, uptime and words", sane)
	local any = false
	for t = 0.5, outcome.Duration, 0.5 do
		for _, list in pairs(m.StatusText.ActiveAt(fight, t)) do
			for _, st in ipairs(list) do
				if st.Left > 0 then any = true end
			end
		end
	end
	check("some status is active during the fight", any)
	check("no reward was paid for a NoRewards fight", p.Season.HighestStage == 20)

	-- metrics add up
	local withMetrics = m.StageRunner.Run(team, 12, 7, nil, true, { Metrics = true, NoRewards = true })
	local dealt, logged = 0, 0
	for _, row in pairs(withMetrics.Metrics.Entities) do dealt += row.Dealt or 0 end
	for _, e in ipairs(withMetrics.Events) do if e.Type == "Damage" then logged += e.Amount end end
	check(("metrics damage equals the damage events (%d vs %d)"):format(dealt, logged), dealt == logged)
	check("metrics do not change the fight", withMetrics.Duration == outcome.Duration and withMetrics.Won == outcome.Won)

	-- late-game guards
	local late = m.StageConfig.LateGrowth
	if late then
		local function power(stage) -- health x attack of a monster at this stage
			return m.Stages.Scale(stage) ^ 2 * m.Stages.HealthMult(stage)
		end
		local bands = late.Bands or { { From = late.From, Rate = late.Rate } }
		local last = bands[#bands]
		local a, b = power(last.From + 50), power(last.From + 51)
		check("past the last LateGrowth band each stage is at least its Rate harder (health x attack)", b / a >= (1 + last.Rate) ^ 2)
		check("late growth goes more to health than to attack", m.Stages.HealthMult(last.From + 51) / m.Stages.HealthMult(last.From + 50) > 1)
	end
	local soft = m.GearConfig.PercentSoft
	if soft then
		local _, at = m.Gear.StatOf({ Slot = "Boots", Rarity = "Legendary", Power = soft.From, Roll = 1 })
		local _, far = m.Gear.StatOf({ Slot = "Boots", Rarity = "Legendary", Power = 200, Roll = 1 })
		local _, atk60 = m.Gear.StatOf({ Slot = "Weapon", Rarity = "Legendary", Power = soft.From, Roll = 1 })
		local _, atk200 = m.Gear.StatOf({ Slot = "Weapon", Rarity = "Legendary", Power = 200, Roll = 1 })
		check("percent gear stats flatten late", far / at < 1.5)
		check("flat gear stats keep growing", atk200 / atk60 > 2.5)
	end

	print(("IconStatusTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
