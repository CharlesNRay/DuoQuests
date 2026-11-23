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
	World.TownSpots.__Probe = { District = "Gate", X = 0, Z = -10 }
	local px, pz = World.TownSpot("__Probe")
	local gx, gz = World.DistrictPoint("Gate")
	World.TownSpots.__Probe = nil
	check("Local -Z in a district points at the plaza", math.abs(px - gx) < 1e-6 and pz < gz)
	check("NearSpot is true at the spot and false 30 studs away", World.NearSpot(wx, wz, "Warden") and not World.NearSpot(wx + 30, wz, "Warden"))

	-- the flow
	local profile = PT.New()
	local status = Errands.Status(profile, DAY)
	check("A fresh profile has every errand Ready and none active", status.Active == nil and status.DoneCount == 0 and status.Total == #Config.List and status.List[1].State == "Ready")
	check("Talking to nobody does nothing", select(2, Errands.Interact(profile, "Tavern", DAY, fixed(1))) == "Nothing")
	local ok, info = Errands.Interact(profile, "Mabel", DAY, fixed(3))
	check("Talking to Mabel starts The Lost Cat", ok and info.Kind == "Started" and info.Id == "LostCat")
	status = Errands.Status(profile, DAY)
	check("The cat hides at the rolled spot and the tracker names it", status.Active.Spot == "Cat3" and status.Active.Text:find(Config.CatHints[3], 1, true) ~= nil)
	check("Another giver says you are busy", select(2, Errands.Interact(profile, "Warden", DAY, fixed(1))) == "Busy")
	check("The wrong cat spot does nothing", select(2, Errands.Interact(profile, "Cat1", DAY, fixed(1))) == "Nothing")
	local before = profile.Season.Currencies.Wishstones or 0
	ok, info = Errands.Interact(profile, "Cat3", DAY, fixed(1))
	check("Picking up the cat moves to the next step and you carry it", ok and info.Kind == "Step" and Errands.Status(profile, DAY).Active.Carry == "Cat")
	ok, info = Errands.Interact(profile, "Mabel", DAY, fixed(1))
	check("Returning the cat finishes the errand and pays Wishstones", ok and info.Kind == "Done" and (profile.Season.Currencies.Wishstones or 0) == before + Config.List[1].Reward.Wishstones)
	check("The same errand cannot be done twice a day", select(2, Errands.Interact(profile, "Mabel", DAY + 100, fixed(1))) == "DoneToday")

	-- an errand that pays a ticket
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
	status = Errands.Status(profile, DAY)
	check("Two errands show Done", status.DoneCount == 2)

	-- abandon and a new day
	Errands.Interact(profile, "Guildmaster", DAY, fixed(1))
	check("Abandon drops the errand in hand", Errands.Abandon(profile, DAY) == true and Errands.Status(profile, DAY).Active == nil)
	check("Abandoning with nothing in hand is refused", select(2, Errands.Abandon(profile, DAY)) == "Nothing")
	Errands.Interact(profile, "Sergeant", DAY, fixed(1))
	status = Errands.Status(profile, DAY + 86400)
	check("A new day makes every errand Ready again and keeps the one in hand", status.DoneCount == 0 and status.Active ~= nil and status.Active.Id == "Straw")

	local total = 0
	for _, def in ipairs(Config.List) do
		total += def.Reward.Wishstones or 0
	end
	check("All errands together stay small (<= 20 Wishstones a day)", total <= 20)

	print(("ErrandTests done: %d passed, %d failed"):format(passed, failed))
end
