-- Boss probe: damage a gearless party deals to the world/season boss, as a multiple of Bosses.DamageScale (tiers are
-- multiples of it). Compares a pair with PartyScale 1 (the old game) and four heroes with the current PartyScale.
local P = require("./ProfileTemplate"); local Bosses = require("./Bosses"); local Cfg = require("./Config/Bosses"); local SC = require("./Config/Stages")
local function hero(c, lv, fr)
	local p = P.New(); p.Permanent.UnlockedClasses[c] = true; p.Season.ClassId = c; P.GrantClassStarters(p.Season, c); p.Season.Level = lv; p.Season.HighestStage = fr
	return p
end
local real = SC.PartyScale
for _, setup in ipairs({ { "pair, PartyScale 1", { "Warrior", "Cleric" }, 1 }, { "four, PartyScale " .. tostring(real), { "Warrior", "Cleric", "Mage", "Ranger" }, real } }) do
	SC.PartyScale = setup[3]
	for _, pt in ipairs({ { 10, 15 }, { 30, 40 } }) do
		for _, which in ipairs({ "World", "Season" }) do
			local total = 0
			for seed = 1, 6 do
				local team = {}
				for i, c in ipairs(setup[2]) do team[i] = { Id = tostring(i), Name = c, Profile = hero(c, pt[1], pt[2]) } end
				total += Bosses.Challenge(team, Cfg[which], pt[2], seed, false)
			end
			print(("%-22s L%d fr%d %-6s damage = %.1f x DamageScale"):format(setup[1], pt[1], pt[2], which, total / 6 / Bosses.DamageScale(pt[2])))
		end
	end
end
SC.PartyScale = real
