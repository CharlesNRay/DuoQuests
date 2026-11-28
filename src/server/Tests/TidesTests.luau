--[[
	TidesTests (ModuleScript): the draft season mechanic Elemental Tides (Shared/Tides, Config/Tides) and the draft
	season 2 (Config/Seasons Drafts) the Studio "Start next season" cheat runs.
	  require(game.ServerScriptService.Server.Tests.TidesTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Tides = require(Shared.Tides), TidesConfig = require(Shared.Config.Tides), SeasonClock = require(Shared.SeasonClock),
			Seasons = require(Shared.Config.Seasons), Zones = require(Shared.Zones), ZoneConfig = require(Shared.Config.Zones),
			Stages = require(Shared.Stages), Progression = require(Shared.Progression), ProfileTemplate = require(Shared.ProfileTemplate),
			Party = require(Shared.Party), Bosses = require(Shared.Bosses), SeasonRewards = require(Shared.SeasonRewards),
			Cosmetics = require(Shared.Cosmetics), Bonds = require(Shared.Bonds),
		}
	end
	local Tides, Config, Clock = m.Tides, m.TidesConfig, m.SeasonClock
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	-- the data
	local seen, count = {}, 0
	for id, def in pairs(Config.Elements) do
		check(id .. " is in the weekly order", table.find(Config.Order, id) ~= nil)
		for _, zone in ipairs(def.Zones) do
			check(("Zone %d belongs to one tide only"):format(zone), seen[zone] == nil)
			seen[zone] = id
			count += 1
		end
	end
	check("Every zone has a tide", count == #m.ZoneConfig)
	check("Zones past 200 loop round to the same tide", Tides.ZoneElement(21) == Tides.ZoneElement(1) and Tides.ZoneElement(27) == Tides.ZoneElement(7))

	-- off in season 1 (Bonds)
	Clock.ClearOverride()
	check("Season 1 does not run Tides", Tides.On(1) == false and Tides.Status(os.time()) == nil)
	check("No tide bonus when off", Tides.EnemyMult(65, os.time()) == 1 and Tides.Rewards(65, os.time()).GoldGain == 0 and #Tides.ClassMods("Mage", os.time()) == 0)

	-- the Studio cheat starts the draft season 2
	check("Season 2 is a draft, not on the real calendar", m.Seasons.Seasons[2] == nil and m.Seasons.Drafts[2] ~= nil)
	local start = os.time()
	local id = Clock.StartNext(start)
	check("Start next season runs the draft season 2", id == 2 and Clock.Def(2).Name == m.Seasons.Drafts[2].Name and Tides.On() == true)
	check("Bonds is off in season 2", m.Bonds.On() == false)

	-- the weekly turn
	local function stageIn(zone)
		return (zone - 1) * 10 + 5
	end
	local week = Config.Week
	local first, firstDef = Tides.Element(start)
	check("Week 1 raises the first element", first == Config.Order[1] and Tides.Week(start) == 0)
	check("Week 2 raises the second", (Tides.Element(start + week + 5)) == Config.Order[2])
	check("After the last week it comes round again", (Tides.Element(start + #Config.Order * week + 5)) == Config.Order[1])
	check("The spotlight turns weekly", Tides.Spotlight(start) == Config.Spotlight[1] and Tides.Spotlight(start + week + 1) == Config.Spotlight[2])

	local risingStage = stageIn(firstDef.Zones[1])
	local quietStage = stageIn(Config.Elements[Config.Order[2]].Zones[1])
	check("A rising zone's stage is rising", Tides.Rising(risingStage, start) == firstDef and Tides.Rising(quietStage, start) == nil)
	check("Rising enemies are tougher", math.abs(Tides.EnemyMult(risingStage, start) - (1 + Config.Power)) < 1e-9 and Tides.EnemyMult(quietStage, start) == 1)
	local plain = m.Stages.NewEnemies(risingStage)
	local tough = m.Stages.NewEnemies(risingStage, 1 + Config.Power)
	check("Stages.NewEnemies applies the tide", tough[1].Stats.MaxHealth > plain[1].Stats.MaxHealth and tough[1].Stats.Attack > plain[1].Stats.Attack)
	check("Rewards in a rising zone", Tides.Rewards(risingStage, start).GoldGain == Config.GoldGain and Tides.Rewards(quietStage, start).GoldGain == 0)
	check("The class in the spotlight gets its mods", #Tides.ClassMods(Config.Spotlight[1], start) > 0 and #Tides.ClassMods(Config.Spotlight[2], start) == 0)

	-- a win in a rising zone pays more gold than the same win a week later (when that zone is quiet)
	local function goldFor(stage)
		local p = m.ProfileTemplate.New()
		p.Season.HighestStage = stage + 5 -- a replay, so frontier rewards do not differ
		local before = p.Season.Currencies.Gold
		m.Progression.ApplyClear(p, stage, function() return 0.99 end)
		return p.Season.Currencies.Gold - before
	end
	local risingGold = goldFor(risingStage)
	local s = Tides.Status(start)
	check("Status names the tide and its zones", s ~= nil and s.Name == firstDef.Name and #s.Zones == #firstDef.Zones and s.EndsAt == start + week)
	check("A win in a rising zone pays about double gold", risingGold > 0)
	Clock.ClearOverride()
	local quietGold = goldFor(risingStage)
	check("... compared with the same win with Tides off", risingGold >= quietGold * 1.8)
	Clock.StartNext(start)

	-- a party fight in a rising zone is flagged and still runs
	local a = m.ProfileTemplate.New()
	a.Season.ClassId = "Warrior"
	a.Permanent.UnlockedClasses.Warrior = true
	local party = m.Party.NewOpen("tide", 2, 101, start, 1)
	m.Party.RefreshSnapshot(party, 101, "Ann", a, start)
	party.Stage = risingStage
	party.Frontier = risingStage
	local outcome = m.Party.OnlineTick(party, { { UserId = 101, Name = "Ann", Profile = a } }, 7, start)
	check("A party fight in a rising zone is a tide fight", outcome ~= nil and outcome.Tide == true)

	-- the draft season's own boss and prize
	local cfg = m.Bosses.SeasonCfg(Clock.Def(2))
	check("Season 2 brings The Maelstrom", cfg.Name == "The Maelstrom" and cfg.DefId == "Maelstrom" and #cfg.Look.Orbs == 4)
	local top = m.SeasonRewards.Reward({ Ranked = true, Percent = 0.1, Percentile = { Label = "Top 10%", Sunstones = 1 }, ClassId = "Mage" }, 2)
	check("Top 20% of season 2 win the Tidebound aura", table.find(top.Cosmetics, "Aura_Tidebound") ~= nil and m.Cosmetics.Def("Aura_Tidebound") ~= nil)

	Clock.ClearOverride()
	print(("TidesTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
