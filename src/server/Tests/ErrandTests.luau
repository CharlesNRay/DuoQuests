--[[
	ErrandTests (ModuleScript): town errands (Shared/Errands, Config/Errands) and their spots (World.TownSpots).
	Headless: tools/sim/runners/extra.luau. In Studio: require(game.ServerScriptService.Server.Tests.ErrandTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if not m then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Errands = require(Shared.Errands), ErrandConfig = require(Shared.Config.Errands), World = require(Shared.World), ProfileTemplate = require(Shared.ProfileTemplate), Consumables = require(Shared.Consumables) }
	end
	local Errands, Config, World, PT = m.Errands, m.ErrandConfig, m.World, m.ProfileTemplate
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
	print("Running ErrandTests...")

	local DAY = 86400 * 20000
	local function fixed(n)
		return function()
			return n
		end
	end

	-- spots: every spot an errand uses exists, sits on its district's ground and is clear of the plaza and the lots
	local spotsOk, onGround, clearOfLots = true, true, true
	local used = {}
	for _, def in ipairs(Config.List) do
		used[def.Giver] = true
		for _, step in ipairs(def.Steps) do
			if step.Spot == "Cat" then
				for n = 1, #Config.CatHints do
					used["Cat" .. n] = true
				end
			else
				used[step.Spot] = true
			end
		end
	end
	used.Board = true
	for id in pairs(used) do
		local x, z = World.TownSpot(id)
		if not x then
			spotsOk = false
		else
			local spot = World.TownSpots[id]
			if spot.District then
				local dx, dz = World.DistrictPoint(spot.District)
				if math.sqrt((x - dx) ^ 2 + (z - dz) ^ 2) > World.Districts[spot.District].Size - 3 then
					onGround = false
				end
			end
			if math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2) < World.PLAZA.Radius then
				onGround = false
			end
			for slot = 1, World.MAX_LOTS do
				local ax, _, az = World.ArenaOrigin(slot)
				if math.abs(x - ax) < World.ARENA_WIDTH / 2 + 5 and math.abs(z - az) < World.ARENA_DEPTH / 2 + 5 then
					clearOfLots = false
				end
			end
		end
	end
	check("Every errand spot exists in World.TownSpots", spotsOk)
	check("District spots stand on their district's ground, none on the plaza", onGround)
	check("No errand spot is on a battle lot", clearOfLots)
	local wx, wz = World.TownSpot("Warden")
	local ax, az = World.TownSpot("Altar")
	local f = World.BossField
	check("The Warden and the offering stone are on the Boss Field", math.sqrt((wx - f.X) ^ 2 + (wz - f.Z) ^ 2) < f.Radius and math.sqrt((ax - f.X) ^ 2 + (az - f.Z) ^ 2) < f.Radius)
	-- the frame math: a spot at local (0, 0) is the district point, local -Z is toward the plaza
	World.TownSpots.__Probe = { District = "Housing", X = 0, Z = -10 }
	local px, pz = World.TownSpot("__Probe")
	local gx, gz = World.DistrictPoint("Housing")
	World.TownSpots.__Probe = nil
	local function toPlaza(x, z)
		return math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2)
	end
	check("Local -Z in a district points at the plaza", math.abs(toPlaza(gx, gz) - toPlaza(px, pz) - 10) < 1e-6)
	check("NearSpot is true at the spot and false 30 studs away", World.NearSpot(wx, wz, "Warden") and not World.NearSpot(wx + 30, wz, "Warden"))

	-- the daily pool
	local function dayWith(id, from)
		for d = from or 20000, (from or 20000) + 400 do
			if table.find(Errands.Offered(d), id) then
				return d
			end
		end
	end
	local offered = Errands.Offered(20000)
	local giversOk, givers = true, {}
	for _, id in ipairs(offered) do
		local g = Errands.Def(id).Giver
		if givers[g] then giversOk = false end
		givers[g] = true
	end
	check("A day offers PerDay errands, at most one per townsperson", #offered == Config.PerDay and giversOk)
	check("The same day always offers the same errands", table.concat(Errands.Offered(20000), ",") == table.concat(offered, ","))
	local differs = false
	for d = 20001, 20010 do
		if table.concat(Errands.Offered(d), ",") ~= table.concat(offered, ",") then differs = true end
	end
	check("Other days offer other errands", differs)
	local everyOne = true
	for _, def in ipairs(Config.List) do
		everyOne = everyOne and dayWith(def.Id) ~= nil
	end
	check("Every errand in the pool comes up within a year", everyOne)

	-- the flow, on a day the Lost Cat and Feed the Beasts are both offered
	local catDay
	for d = 20000, 21000 do
		local o = Errands.Offered(d)
		if table.find(o, "LostCat") and table.find(o, "Offering") then catDay = d break end
	end
	check("Some day offers both the Lost Cat and Feed the Beasts", catDay ~= nil)
	local DAY = (catDay or 20000) * 86400
	local profile = PT.New()
	local status = Errands.Status(profile, DAY)
	check("A fresh profile has today's errands Ready and none active", status.Active == nil and status.DoneCount == 0 and status.Total == Config.PerDay and status.List[1].State == "Ready")
	check("Talking to a spot that is nobody does nothing", select(2, Errands.Interact(profile, "Hay", DAY, fixed(1))) == "Nothing")
	local ok, info = Errands.Interact(profile, "Mabel", DAY, fixed(3))
	check("Talking to Mabel starts The Lost Cat", ok and info.Kind == "Started" and info.Id == "LostCat" and info.Line ~= nil)
	status = Errands.Status(profile, DAY)
	check("The cat hides at the rolled spot and the tracker names it", status.Active.Spot == "Cat3" and status.Active.Text:find(Config.CatHints[3], 1, true) ~= nil)
	check("Another giver says you are busy", select(2, Errands.Interact(profile, "Warden", DAY, fixed(1))) == "Busy")
	check("The wrong cat spot does nothing", select(2, Errands.Interact(profile, "Cat1", DAY, fixed(1))) == "Nothing")
	local before = profile.Season.Currencies.Wishstones or 0
	ok, info = Errands.Interact(profile, "Cat3", DAY, fixed(1))
	check("Picking up the cat moves to the next step and you carry it", ok and info.Kind == "Step" and Errands.Status(profile, DAY).Active.Carry == "Cat")
	ok, info = Errands.Interact(profile, "Mabel", DAY, fixed(1))
	check("Returning the cat finishes the errand and pays Wishstones", ok and info.Kind == "Done" and (profile.Season.Currencies.Wishstones or 0) == before + Errands.Def("LostCat").Reward.Wishstones)
	check("Mabel has nothing more that day", select(2, Errands.Interact(profile, "Mabel", DAY + 100, fixed(1))) == "DoneToday")
	local tickets = function()
		for _, row in ipairs(m.Consumables.List(profile)) do
			if row.Id == "SkillWish" then
				return row.Count or 0
			end
		end
		return 0
	end
	local t0 = tickets()
	Errands.Interact(profile, "Warden", DAY, fixed(1))
	Errands.Interact(profile, "Tavern", DAY, fixed(1))
	ok, info = Errands.Interact(profile, "Altar", DAY, fixed(1))
	check("Feed the Beasts pays a Skill Wish ticket", ok and info.Kind == "Done" and tickets() == t0 + 1)
	check("Two errands show Done", Errands.Status(profile, DAY).DoneCount == 2)

	-- Pip's parcel is in your hands from the start
	local pipDay = dayWith("Delivery")
	local p2 = PT.New()
	Errands.Interact(p2, "Courier", pipDay * 86400, fixed(1))
	check("Pip hands you the parcel straight away", Errands.Status(p2, pipDay * 86400).Active.Carry == "Parcel")
	check("Abandon drops the errand in hand", Errands.Abandon(p2, pipDay * 86400) == true and Errands.Status(p2, pipDay * 86400).Active == nil)
	check("Abandoning with nothing in hand is refused", select(2, Errands.Abandon(p2, pipDay * 86400)) == "Nothing")
	Errands.Interact(p2, "Courier", pipDay * 86400, fixed(1))
	status = Errands.Status(p2, (pipDay + 1) * 86400)
	check("A new day brings new errands and keeps the one in hand", status.DoneCount == 0 and status.Active ~= nil and status.Active.Id == "Delivery")

	-- a day's errands stay small: the richest possible day
	local worst = 0
	for d = 20000, 20400 do
		local total = 0
		for _, id in ipairs(Errands.Offered(d)) do
			total += Errands.Def(id).Reward.Wishstones or 0
		end
		worst = math.max(worst, total)
	end
	check("A day's errands pay at most 22 Wishstones", worst <= 22)

	print(("ErrandTests done: %d passed, %d failed"):format(passed, failed))
end
