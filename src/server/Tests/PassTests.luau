--[[
	PassTests (ModuleScript): Game Pass perks (shared/Passes): ownership, perk sums and the hooks into the bag and dungeon keys.
	  require(game.ServerScriptService.Server.Tests.PassTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Passes = require(Shared.Passes), Gear = require(Shared.Gear), Activities = require(Shared.Activities), ProfileTemplate = require(Shared.ProfileTemplate), TableUtil = require(Shared.Util.TableUtil) }
	end
	local Passes, Gear, Activities, ProfileTemplate, TableUtil = m.Passes, m.Gear, m.Activities, m.ProfileTemplate, m.TableUtil
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

	local plain, vip = ProfileTemplate.New(), ProfileTemplate.New()
	check("Not owned at first", not Passes.Has(plain, "VIP"))
	check("No perks without a pass", Passes.Perks(plain).GoldGain == 0 and Passes.Perks(plain).BagSlots == 0)
	check("Grant works", Passes.Grant(vip, "VIP") and Passes.Has(vip, "VIP"))
	check("Granting twice is harmless", Passes.Grant(vip, "VIP") and Passes.Has(vip, "VIP"))
	local ok, reason = Passes.Grant(vip, "Nope")
	check("An unknown pass is refused", ok == false and reason == "BadPass")
	check("Perks apply", Passes.Perks(vip).GoldGain > 0 and Passes.Perks(vip).XPGain > 0)
	check("The bag is bigger", Gear.Cap(vip) == Gear.Cap(plain) + Passes.Perks(vip).BagSlots)
	local day = 86400 * 10
	check("More dungeon keys", Activities.Of(vip, day).MaxKeys == Activities.Of(plain, day).MaxKeys + Passes.Perks(vip).DungeonKeys)
	check("The list shows ownership", Passes.List(vip)[1].Owned and not Passes.List(plain)[1].Owned)
	print(("PassTests done: %d passed, %d failed"):format(passed, failed))
end
