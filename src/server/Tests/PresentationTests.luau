--[[
	PresentationTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PresentationTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PresentationTests)()

	Checks the pure data the 3D presentation depends on: zones, and the event
	log plus roster that a fight sends to the client for replay.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		Zones = require(Shared.Zones),
		ZoneConfig = require(Shared.Config.Zones),
		Enemies = require(Shared.Config.Enemies),
		Stages = require(Shared.Stages),
		StageRunner = require(Shared.StageRunner),
		Party = require(Shared.Party),
		ProfileTemplate = require(Shared.ProfileTemplate),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local Zones, ZoneConfig, Enemies, Stages, StageRunner, ProfileTemplate = m.Zones, m.ZoneConfig, m.Enemies, m.Stages, m.StageRunner, m.ProfileTemplate
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

	print("Running PresentationTests...")

	-- Zones ----------------------------------------------------------------------
	check("Stages 1-10 are zone 1 and 11-20 are zone 2", Zones.IndexForStage(1) == 1 and Zones.IndexForStage(10) == 1 and Zones.IndexForStage(11) == 2)
	check("The boss is the last stage of a zone", Zones.StageInZone(10) == 10 and Zones.StageInZone(11) == 1 and Stages.IsBoss(10))
	local z = Zones.ForStage(15)
	check("A zone reports its first and last stage", z.FirstStage == 11 and z.LastStage == 20)
	local count = Zones.Count()
	check("Zones loop after the authored list with a loop number", Zones.ForStage(count * 10 + 1).Loop == 2 and Zones.ForStage(1).Loop == 1)
	check("Every zone theme has the fields the scene needs", (function()
		for _, theme in ipairs(ZoneConfig) do
			if not (theme.Name and theme.Ground and theme.Sky and theme.Accent and theme.Scenery and theme.Brightness) then
				return false
			end
		end
		return true
	end)())

	-- Enemy looks ----------------------------------------------------------------
	local looksOk = true
	for _, def in pairs(Enemies) do
		if not (def.Look and def.Look.Shape and def.Look.Color and def.Look.Size) then
			looksOk = false
		end
	end
	check("Every enemy has a Look (shape, colour, size)", looksOk)

	-- Replay data from a fight ---------------------------------------------------
	local function newMembers()
		local list = {
			{ Id = "1", Name = "Warrior", Profile = ProfileTemplate.New() },
			{ Id = "2", Name = "Cleric", Profile = ProfileTemplate.New() },
		}
		list[2].Profile.Season.ClassId = "Cleric"
		return list
	end
	local members = newMembers()
	local outcome = StageRunner.Run(members, 1, 7, nil, true)
	check("A recorded fight returns events and a roster", outcome.Events ~= nil and #outcome.Events > 0 and outcome.Roster ~= nil)
	local partyCount, enemyCount, hasUser = 0, 0, true
	for _, entry in ipairs(outcome.Roster) do
		if entry.Team == "Party" then
			partyCount += 1
			hasUser = hasUser and entry.UserId ~= nil
		else
			enemyCount += 1
		end
		if not (entry.Id and entry.Name and entry.DefId and entry.MaxHealth) then
			hasUser = false
		end
	end
	check("The roster lists both heroes (with user ids) and the enemies", partyCount == 2 and enemyCount >= 1 and hasUser)
	local idsKnown, endsOnce = true, 0
	local known = {}
	for _, entry in ipairs(outcome.Roster) do
		known[entry.Id] = true
	end
	for _, event in ipairs(outcome.Events) do
		if event.Type == "Damage" and not (known[event.Source] and known[event.Target]) then
			idsKnown = false
		end
		if event.Type == "End" then
			endsOnce += 1
		end
	end
	check("Event sources and targets all appear in the roster", idsKnown)
	check("The log ends exactly once", endsOnce == 1)
	local plain = StageRunner.Run(newMembers(), 1, 7)
	check("Without record there is no event log (cheap path)", plain.Events == nil and plain.Roster == nil)
	check("Recording does not change the outcome", plain.Won == outcome.Won and plain.Duration == outcome.Duration)

	-- a ghost partner is marked in the roster so clients can draw it see-through
	local PT = m.ProfileTemplate
	local live, offline = PT.New(), PT.New()
	local ghostSnap = m.Party.MakeSnapshot(offline, 2002, "Ghosty", nil, 0)
	local mixed = StageRunner.Run({ { Id = "1001", Name = "Live", Profile = live }, { Id = "2002", Name = "Ghosty", Snapshot = ghostSnap } }, 1, 3, nil, true)
	local ghostFlag, liveFlag = false, false
	for _, entry in ipairs(mixed.Roster) do
		if entry.Id == "2002" then
			ghostFlag = entry.Ghost == true
		elseif entry.Id == "1001" then
			liveFlag = entry.Ghost == true
		end
	end
	check("An offline partner is marked as a ghost in the roster", ghostFlag and not liveFlag)

	-- shared hub layout
	local World = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("World"))
	local seen, distinct, clear = {}, true, true
	local ox1, _, oz1 = World.ArenaOrigin(1)
	for slot = 1, 24 do
		local x, y, z = World.ArenaOrigin(slot)
		local key = x .. "," .. z
		if seen[key] then
			distinct = false
		end
		seen[key] = { x, z }
	end
	for a = 1, 24 do
		for b = a + 1, 24 do
			local pa, pb = seen[select(1, World.ArenaOrigin(a)) .. "," .. select(3, World.ArenaOrigin(a))], seen[select(1, World.ArenaOrigin(b)) .. "," .. select(3, World.ArenaOrigin(b))]
			if math.abs(pa[1] - pb[1]) < World.ARENA_WIDTH and math.abs(pa[2] - pb[2]) < World.ARENA_DEPTH then
				clear = false
			end
		end
	end
	check("Arena slots 1-24 are at distinct places", distinct)
	check("Arena pads never overlap", clear)
	check("Arena 1 is in front of the spawn", oz1 < select(3, World.SpawnPosition()) and ox1 ~= nil)

	-- town districts (docs/TOWN.md): clear of the plaza, the lots and each other, and a short walk from the fountain
	local districtsOk, walkOk, lotsOk = true, true, true
	local ids = World.DistrictOrder
	for i, id in ipairs(ids) do
		local d = World.Districts[id]
		local x, z = World.DistrictPoint(id)
		local fromCentre = math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2)
		if fromCentre - d.Size < World.PLAZA.Radius + 10 then
			districtsOk = false
		end
		if fromCentre / 16 > 15 then -- 16 studs/s walk: at most ~15 s from the fountain
			walkOk = false
		end
		for j = i + 1, #ids do
			local o = World.Districts[ids[j]]
			local ox, oz = World.DistrictPoint(ids[j])
			if math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2) < d.Size + o.Size + 10 then
				districtsOk = false
			end
		end
		for slot = 1, World.MAX_LOTS do
			local ax, _, az = World.ArenaOrigin(slot)
			local nx = math.clamp(x, ax - World.ARENA_WIDTH / 2, ax + World.ARENA_WIDTH / 2)
			local nz = math.clamp(z, az - World.ARENA_DEPTH / 2, az + World.ARENA_DEPTH / 2)
			if math.sqrt((x - nx) ^ 2 + (z - nz) ^ 2) < d.Size + 10 then
				lotsOk = false
			end
		end
	end
	check("Town districts are clear of the plaza and of each other", districtsOk)
	check("Every district is at most ~15 s walk from the fountain", walkOk)
	check("Town districts are clear of the battle lots", lotsOk)
	-- the Boss Field (world boss + season Colossus) sits outside the town, clear of every district and the ring road
	local f = World.BossField
	local fieldOk = math.sqrt((f.X - World.PLAZA.X) ^ 2 + (f.Z - World.PLAZA.Z) ^ 2) - f.Radius > World.TOWN_RING + 10
	for _, id in ipairs(ids) do
		local x, z = World.DistrictPoint(id)
		if math.sqrt((x - f.X) ^ 2 + (z - f.Z) ^ 2) < World.Districts[id].Size + f.Radius + 5 then
			fieldOk = false
		end
	end
	for _, spot in pairs(World.BossSpots) do
		if math.sqrt((spot.X - f.X) ^ 2 + (spot.Z - f.Z) ^ 2) > f.Radius then
			fieldOk = false
		end
	end
	check("The Boss Field is outside the town and holds both bosses", fieldOk)
	local tx, tz = World.PlazaPoint("Tree")
	local gx, gz = World.DistrictPoint("Grove")
	check("The Wishing Tree stands in the Wishing Grove", math.sqrt((tx - gx) ^ 2 + (tz - gz) ^ 2) < World.Districts.Grove.Size)

	print(("PresentationTests done: %d passed, %d failed"):format(passed, failed))
end
