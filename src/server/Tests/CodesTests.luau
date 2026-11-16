--[[
	CodesTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > CodesTests

	  require(game.ServerScriptService.Server.Tests.CodesTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Codes = require(Shared.Codes), ProfileTemplate = require(Shared.ProfileTemplate), Premium = require(Shared.Premium),
		Consumables = require(Shared.Consumables), ConsumableConfig = require(Shared.Config.Consumables), Cosmetics = require(Shared.Cosmetics),
		CodeList = require(game:GetService("ServerScriptService").Server.Data.CodeList),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Codes, ProfileTemplate, Premium, Consumables, Cosmetics = m.Codes, m.ProfileTemplate, m.Premium, m.Consumables, m.Cosmetics
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

	local list = {
		TEST = { Rewards = { Sunstones = 25, Wishstones = 10, SkillPicks = 1, Items = { PetWish = 2 }, Titles = { "Tester" }, Cosmetics = { "Name_Gold" } } },
		LATER = { Rewards = { Sunstones = 5 }, StartsAt = 1000 },
		OLD = { Rewards = { Sunstones = 5 }, ExpiresAt = 500 },
		OFF = { Rewards = { Sunstones = 5 }, Disabled = true },
	}
	check("Normalize keeps capitals and digits only", Codes.Normalize(" te-st 1! ") == "TEST1" and Codes.Normalize(nil) == "" and #Codes.Normalize(string.rep("a", 80)) == 24)

	local p = ProfileTemplate.New()
	local before = p.Season.Currencies.Wishstones or 0
	local ok, result = Codes.Redeem(p, "  test ", 100, list)
	check("A valid code pays out (any case, with spaces)", ok == true and Premium.Sunstones(p) == 25 and (p.Season.Currencies.Wishstones or 0) == before + 10 and p.Season.Currencies.SkillPicks >= 1)
	check("Items, titles and cosmetics are granted", Consumables.Count(p, "PetWish") == 2 and Cosmetics.Owned(p, "Tester") and Cosmetics.Owned(p, "Name_Gold"))
	check("The reply lists what was won", #result.Lines == 6 and result.Lines[1]:find("25") ~= nil)
	local again, why = Codes.Redeem(p, "TEST", 200, list)
	check("A code works once per account", again == false and why == "AlreadyRedeemed" and Premium.Sunstones(p) == 25 and Codes.Redeemed(p, "TEST"))
	check("Another account can use it too", select(1, Codes.Redeem(ProfileTemplate.New(), "TEST", 100, list)) == true)
	check("Unknown, empty and disabled codes are refused", select(2, Codes.Redeem(p, "NOPE", 100, list)) == "Invalid" and select(2, Codes.Redeem(p, "   ", 100, list)) == "Empty" and select(2, Codes.Redeem(p, "OFF", 100, list)) == "Invalid")
	check("A code before its start is refused, and does not use it up", select(2, Codes.Redeem(p, "LATER", 10, list)) == "NotYet" and not Codes.Redeemed(p, "LATER") and select(1, Codes.Redeem(p, "LATER", 1000, list)) == true)
	check("An expired code is refused", select(2, Codes.Redeem(p, "OLD", 500, list)) == "Expired" and not Codes.Redeemed(p, "OLD"))
	check("A refused code pays nothing", Premium.Sunstones(p) == 30)

	-- the real list stays valid
	local realOk = m.CodeList ~= nil
	if realOk then
		for code, def in pairs(m.CodeList) do
			realOk = realOk and code == Codes.Normalize(code) and def.Rewards ~= nil
			for id in pairs(def.Rewards.Items or {}) do
				realOk = realOk and m.ConsumableConfig.Defs[id] ~= nil
			end
		end
	end
	check("Every real code is well formed", realOk)

	print(("CodesTests done: %d passed, %d failed"):format(passed, failed))
	return failed == 0
end
