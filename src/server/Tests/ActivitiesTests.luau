--[[
	ActivitiesTests (ModuleScript): dungeons and expeditions.
	  require(game.ServerScriptService.Server.Tests.ActivitiesTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Activities = require(Shared.Activities), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Activities, ProfileTemplate = m.Activities, m.ProfileTemplate
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

	local now = 1000000 * 86400 / 1000 -- any fixed time
	local p = ProfileTemplate.New()
	p.Season.HighestStage = 12
	local a = Activities.Of(p, now)
	check("A new player has full keys and no expedition", a.Keys == Activities.MaxKeys and a.Expedition == nil)
	local members = { { Id = "1", Name = "Tester", Profile = p } }
	local crypt = Activities.Dungeons[1]
	check("The first dungeon is open at stage 12, the third is not", Activities.Unlocked(p, crypt) and not Activities.Unlocked(p, Activities.Dungeons[3]))
	check("A locked dungeon is refused and costs no key", select(2, Activities.RunDungeon(p, members, "Abyss", 5, now, false)) == "Locked" and Activities.Of(p, now).Keys == Activities.MaxKeys)
	check("Unknown dungeons are refused", select(2, Activities.RunDungeon(p, members, "Nope", 5, now, false)) == "BadArgs")
	local gold, level, stage = p.Season.Currencies.Gold, p.Season.Level, p.Season.HighestStage
	local ok, result = Activities.RunDungeon(p, members, "Crypt", 5, now, true)
	check("A run works and costs one key", ok == true and Activities.Of(p, now).Keys == Activities.MaxKeys - 1)
	check("The run reports floors and a replay of the last fight", ok and result.Floors == Activities.FloorsPerDungeon and result.Cleared >= 0 and result.Fight ~= nil and #result.Fight.Events > 0)
	check("Clearing floors pays, losing everything pays nothing", ok and ((result.Cleared > 0 and p.Season.Currencies.Gold > gold) or (result.Cleared == 0 and p.Season.Currencies.Gold == gold)))
	check("Floors never pay the normal stage rewards", p.Season.Level == level and p.Season.HighestStage == stage)
	for _ = 1, 5 do
		Activities.RunDungeon(p, members, "Crypt", 9, now, false)
	end
	check("Keys run out", select(2, Activities.RunDungeon(p, members, "Crypt", 9, now, false)) == "NoKeys")
	check("Keys refill the next day", Activities.Of(p, now + 86400).Keys == Activities.MaxKeys)

	local q = ProfileTemplate.New()
	q.Season.HighestStage = 12
	check("Collecting with nothing out is refused", select(2, Activities.CollectExpedition(q, now)) == "None")
	check("An expedition starts", Activities.StartExpedition(q, "Scout", now) == true and Activities.Of(q, now).Expedition.Id == "Scout")
	check("Only one at a time", select(2, Activities.StartExpedition(q, "Patrol", now)) == "Busy")
	check("It cannot be collected early", select(2, Activities.CollectExpedition(q, now + 60)) == "NotReady")
	local before = q.Season.Currencies.Gold
	local okC, lines = Activities.CollectExpedition(q, now + Activities.Expeditions[1].Seconds)
	check("It pays when it is back and frees the slot", okC == true and #lines > 0 and q.Season.Currencies.Gold > before and Activities.Of(q, now).Expedition == nil)
	check("Longer expeditions pay more", (function()
		local a1, a2 = ProfileTemplate.New(), ProfileTemplate.New()
		a1.Season.HighestStage, a2.Season.HighestStage = 12, 12
		Activities.StartExpedition(a1, "Scout", now)
		Activities.StartExpedition(a2, "Voyage", now)
		local g1, g2 = a1.Season.Currencies.Gold, a2.Season.Currencies.Gold
		Activities.CollectExpedition(a1, now + 1e6)
		Activities.CollectExpedition(a2, now + 1e6)
		return a2.Season.Currencies.Gold - g2 > a1.Season.Currencies.Gold - g1
	end)())

	print(("ActivitiesTests done: %d passed, %d failed"):format(passed, failed))
end
