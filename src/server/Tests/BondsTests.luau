--[[
	BondsTests (ModuleScript): the season mechanic Bonds (Shared/Bonds, Party.OnlineTick).
	  require(game.ServerScriptService.Server.Tests.BondsTests)()
]]

return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = {
			Bonds = require(Shared.Bonds), BondsConfig = require(Shared.Config.Bonds), Party = require(Shared.Party),
			ProfileTemplate = require(Shared.ProfileTemplate), DataSafety = require(Shared.Util.DataSafety), SeasonClock = require(Shared.SeasonClock),
		}
	end
	local Bonds, Config, Party, ProfileTemplate = m.Bonds, m.BondsConfig, m.Party, m.ProfileTemplate
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

	-- levels
	check("No XP is level 0", Bonds.Level(0) == 0 and Bonds.Level(nil) == 0)
	check("Level 1 needs XPBase", Bonds.Level(Config.XPBase - 1) == 0 and Bonds.Level(Config.XPBase) == 1)
	local lv, into, need = Bonds.Level(Config.XPBase * 4 + 10)
	check("Progress into a level", lv == 2 and into == 10 and need == Config.XPBase * 5)
	check("Max level stops", Bonds.Level(1e9) == Config.MaxLevel and select(3, Bonds.Level(1e9)) == nil)

	-- keys
	check("Players key by user id", Bonds.KeyOf({ Id = "123", Name = "Bob" }) == "123")
	check("Companions key by name", Bonds.KeyOf({ Id = "-2", Name = "Mira" }) == "c:Mira")

	-- gains
	local p = ProfileTemplate.New()
	local keys = { "1", "2", "c:Mira" }
	local ups = {}
	for _ = 1, Config.XPBase do
		for _, up in ipairs(Bonds.Gain(p, "1", keys, { ["2"] = "Bob", ["c:Mira"] = "Mira" })) do
			table.insert(ups, up)
		end
	end
	check("A player bond levels after XPBase wins", Bonds.Level(p.Season.Bonds["2"]) == 1 and #ups == 1 and ups[1].Key == "2")
	check("A companion bonds at half speed", p.Season.Bonds["c:Mira"] == Config.XPBase * Config.CompanionShare)
	check("No bond with yourself", p.Season.Bonds["1"] == nil)
	check("Player names are kept", p.Season.BondNames["2"] == "Bob" and p.Season.BondNames["c:Mira"] == nil)
	local rows = Bonds.List(p)
	check("List: best bond first, names", #rows == 2 and rows[1].Name == "Bob" and rows[1].Level == 1 and rows[2].Name == "Mira" and rows[2].Companion)

	-- titles
	local t = ProfileTemplate.New()
	t.Season.Bonds = { ["2"] = Config.XPBase * 25 - 1 }
	Bonds.Gain(t, "1", { "1", "2" })
	check("Bond level 5 grants its title", Bonds.Level(t.Season.Bonds["2"]) == 5 and t.Permanent.Titles[Config.Titles[5]] == true)

	-- mods
	check("No bonds, no mods", #Bonds.Mods(nil, "1", keys) == 0 and #Bonds.Mods({}, "1", keys) == 0)
	local mods = Bonds.Mods({ ["2"] = Config.XPBase * 9, ["c:Mira"] = Config.XPBase }, "1", keys)
	check("Mods add every bonded hero in the fight", #mods == 2 and math.abs(mods[1].Value - Config.PerLevel * 4) < 1e-9)
	check("Heroes not in the fight do not count", #Bonds.Mods({ ["9"] = Config.XPBase * 100 }, "1", keys) == 0)

	-- the season switch
	check("Season 1 runs Bonds", Bonds.On(1) == true)

	-- a real party fight: the bonus reaches the fight and a win builds the bond
	local a, b = ProfileTemplate.New(), ProfileTemplate.New()
	a.Season.ClassId, b.Season.ClassId = "Warrior", "Cleric"
	a.Permanent.UnlockedClasses.Warrior, b.Permanent.UnlockedClasses.Cleric = true, true
	local now = 86400 * 20000
	local party = Party.New("bondparty", 1, 101, 202, now)
	Party.RefreshSnapshot(party, 101, "Ann", a, now)
	Party.RefreshSnapshot(party, 202, "Bob", b, now)
	local won = false
	for i = 1, 20 do
		local outcome = Party.OnlineTick(party, { { UserId = 101, Name = "Ann", Profile = a }, { UserId = 202, Name = "Bob", Profile = b } }, i, now)
		if outcome and outcome.Won then
			won = true
		end
	end
	check("Party wins build bonds both ways", won and (a.Season.Bonds or {})["202"] ~= nil and (b.Season.Bonds or {})["101"] ~= nil)
	local companionBond = false
	for heroKey in pairs(a.Season.Bonds or {}) do
		if heroKey:sub(1, 2) == "c:" then
			companionBond = true
		end
	end
	check("Companions in the party fight count too", companionBond and #(party.Companions or {}) > 0)
	Party.RefreshSnapshot(party, 101, "Ann", a, now)
	check("A ghost keeps its bonds", party.Snapshots["101"].Bonds ~= nil and party.Snapshots["101"].Bonds["202"] == a.Season.Bonds["202"])
	if m.DataSafety then
		check("Bond data is save-safe", #m.DataSafety.Problems(a) == 0)
	end

	print(("BondsTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
