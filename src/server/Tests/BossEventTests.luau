--[[
	BossEventTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > BossEventTests
	  require(game.ServerScriptService.Server.Tests.BossEventTests)()
	World boss + season boss rules (shared/Bosses).
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Bosses = require(Shared.Bosses), BossConfig = require(Shared.Config.Bosses), Consumables = require(Shared.Consumables),
		ProfileTemplate = require(Shared.ProfileTemplate),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Bosses, Cfg, Consumables, ProfileTemplate = m.Bosses, m.BossConfig, m.Consumables, m.ProfileTemplate
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

	local p = ProfileTemplate.New()
	local damage = Bosses.Strike({ { Id = "1", Name = "A", Profile = p } }, Cfg.World, 1, 1)
	check("A strike deals damage", damage > 0)
	check("A strike is repeatable (same seed, same damage)", damage == Bosses.Strike({ { Id = "1", Name = "A", Profile = p } }, Cfg.World, 1, 1))

	local scale = Bosses.DamageScale(1)
	check("No damage reaches no tier", #Bosses.TiersReached(Cfg.World, 0, 1) == 0)
	local reached = Bosses.TiersReached(Cfg.World, scale * 6.5, 1)
	check("Tiers are cumulative", #reached == 3 and reached[1].Id == 1 and reached[3].Id == 3)
	check("Everything reached at huge damage", #Bosses.TiersReached(Cfg.World, scale * 1000, 1) == #Cfg.World.Tiers)
	check("Higher frontier raises the bar", #Bosses.TiersReached(Cfg.World, scale * 6.5, 30) < 3)

	local lines = Bosses.GrantRewards(p, Cfg.World.Tiers[3].Rewards, 5)
	check("Rewards land in the stash", Consumables.Count(p, "SkillWish") == 1 and Consumables.Count(p, "PowerElixir") == 1 and #lines == 2)
	Bosses.GrantRewards(p, Cfg.World.Tiers[6].Rewards, 5)
	check("Top tier gives gear", #p.Season.Equipment.Inventory >= 1)

	-- season health
	local S = Cfg.Season
	local start, finish = 0, 1000
	local hp, frac = Bosses.SeasonHealth(S, 0, 0, start, finish)
	check("Full health at the start", hp == S.MaxHealth and frac == 1)
	hp, frac = Bosses.SeasonHealth(S, S.MaxHealth * 0.4, 100, start, finish)
	check("Damage is permanent", math.abs(frac - 0.6) < 1e-9)
	hp, frac = Bosses.SeasonHealth(S, 0, 700, start, finish)
	check("No wither before the finale", frac == 1)
	hp, frac = Bosses.SeasonHealth(S, 0, 900, start, finish)
	check("The finale withers it", frac < 1 and frac > 0)
	hp, frac = Bosses.SeasonHealth(S, 0, 1000, start, finish)
	check("It is dead at the season's end with no help", hp == 0)
	hp, frac = Bosses.SeasonHealth(S, 0, 5000, start, finish)
	check("Past the end stays dead", hp == 0)
	check("Thresholds cross in order", #Bosses.SeasonCrossed(S, 0.8) == 1 and #Bosses.SeasonCrossed(S, 0.2) == 4 and #Bosses.SeasonCrossed(S, 0) == 6)

	-- charges
	local q = ProfileTemplate.New()
	local c = Bosses.Charges(q, 1, 1000, 100, 3)
	check("Fresh player has full charges", c == 3)
	check("Spend a charge", Bosses.SpendCharge(q, 1, 1000, 100, 3) == true and Bosses.Charges(q, 1, 1000, 100, 3) == 2)
	Bosses.SpendCharge(q, 1, 1000, 100, 3) Bosses.SpendCharge(q, 1, 1000, 100, 3)
	check("Out of charges is refused", select(2, Bosses.SpendCharge(q, 1, 1000, 100, 3)) == "NoCharges")
	local cc, wait = Bosses.Charges(q, 1, 1040, 100, 3)
	check("Next charge countdown", cc == 0 and math.abs(wait - 60) < 1e-6)
	check("A charge regenerates", Bosses.Charges(q, 1, 1105, 100, 3) == 1)
	check("Charges cap at max", Bosses.Charges(q, 1, 99999, 100, 3) == 3)

	-- claims
	local r = ProfileTemplate.New()
	check("Nothing claimable without contributing", #Bosses.Claimable(r, 1, S, 0.5) == 0)
	check("Claim refused without contribution", select(2, Bosses.Claim(r, 1, S, "p90", 0.5, 5)) == "NoContribution")
	Bosses.Record(r, 1).Strikes = 1
	check("Claimable after contributing", #Bosses.Claimable(r, 1, S, 0.5) == 3)
	check("Claim a crossed threshold", Bosses.Claim(r, 1, S, "p90", 0.5, 5) == true and Consumables.Count(r, "PetFood") == 3)
	check("No double claim", select(2, Bosses.Claim(r, 1, S, "p90", 0.5, 5)) == "AlreadyClaimed")
	check("Uncrossed threshold refused", select(2, Bosses.Claim(r, 1, S, "p25", 0.5, 5)) == "NotReached")
	check("Unknown threshold refused", select(2, Bosses.Claim(r, 1, S, "zzz", 0.5, 5)) == "Unknown")
	check("No egg before death", select(2, Bosses.Hatch(r, 1, S)) == "NoEgg")
	check("Death claim gives an egg", Bosses.Claim(r, 1, S, "dead", 0, 5) == true and Bosses.Record(r, 1).Egg == true)
	local ok, pet = Bosses.Hatch(r, 1, S)
	check("The egg hatches into the baby boss", ok == true and pet == S.EggPet and r.Permanent.Pets[S.EggPet] == true and Bosses.Record(r, 1).Egg == false)
	check("A new season resets the record", Bosses.Record(r, 2).Strikes == 0 and next(Bosses.Record(r, 2).Claimed) == nil)

	print(("BossEventTests done: %d passed, %d failed"):format(passed, failed))
end
