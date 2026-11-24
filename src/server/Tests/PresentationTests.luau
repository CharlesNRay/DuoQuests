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
		StageConfig = require(Shared.Config.Stages),
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
	-- stages 1-100: ten real-world zones; 101-200: ten elemental / magical ones; every zone names its scenery and backdrop
	local styles = { Hills = true, Peaks = true, Cave = true, Dunes = true, Volcano = true, Swamp = true, Ruins = true, Sky = true, Storm = true, Reef = true, Pyre = true, Fungal = true, Aurora = true, Astral = true, Void = true, Radiant = true, Gale = true, Slime = true, Arcane = true }
	local complete, names = true, {}
	for _, zone in ipairs(ZoneConfig) do
		complete = complete and type(zone.Scenery) == "string" and styles[zone.Backdrop] == true and zone.Decor ~= nil and not names[zone.Name]
		names[zone.Name] = true
	end
	check("20 zones (200 stages), each with a known backdrop and a unique name", count == 20 and complete)
	check("Slime Meadows ends in the Rainbow Slime; other zones keep the boss rotation", Stages.Build(190).Enemies[1].EnemyId == "RainbowSlime" and Stages.Build(180).Enemies[1].EnemyId ~= "RainbowSlime" and Stages.Build(390).Enemies[1].EnemyId == "RainbowSlime")
	do -- stages 101-200 have monsters and a boss of their own (not the stage 1-100 ones again)
		local StageConfig = m.StageConfig
		local early, ok = {}, true
		for zone = 1, 10 do
			for _, id in ipairs(StageConfig.ZonePools[zone]) do
				early[id] = true
			end
		end
		for zone = 11, 20 do
			local pool = StageConfig.ZonePools[zone]
			ok = ok and pool ~= nil and #pool == 3
			for _, id in ipairs(pool or {}) do
				ok = ok and Enemies[id] ~= nil and not early[id] and Enemies[id].IsBoss == false
			end
			local boss = ZoneConfig[zone].Boss
			ok = ok and boss ~= nil and Enemies[boss] ~= nil and Enemies[boss].IsBoss == true
			local built = Stages.Build(zone * 10)
			ok = ok and built.Enemies[1].EnemyId == boss
		end
		check("Zones 11-20 field their own 3 monsters and their own boss", ok)
	end
	check("Stage 101 is Stormspire Peaks and 201 loops back to the meadow", Zones.ForStage(101).Theme.Name == "Stormspire Peaks" and Zones.ForStage(201).Theme.Name == "Sunny Meadow" and Zones.ForStage(201).Loop == 2)
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
			-- the lots face the homes street from both sides (turns 180 degrees apart, so the same axes): compare in a's axes
			local yaw = select(4, World.ArenaOrigin(a))
			local dx, dz = pa[1] - pb[1], pa[2] - pb[2]
			local lx, lz = dx * math.cos(yaw) - dz * math.sin(yaw), dx * math.sin(yaw) + dz * math.cos(yaw)
			if math.abs(lx) < World.ARENA_WIDTH - 0.01 and math.abs(lz) < World.ARENA_DEPTH - 0.01 then
				clear = false
			end
		end
	end
	check("Arena slots 1-24 are at distinct places", distinct)
	check("Arena pads never overlap", clear)
	check("Arena 1 is off the plaza", ox1 ~= nil and math.sqrt((ox1 - World.PLAZA.X) ^ 2 + (oz1 - World.PLAZA.Z) ^ 2) > World.PLAZA.Radius + World.ARENA_WIDTH / 2)

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
	-- the Dungeon Gate and the Expedition Camp sit outside the town: beyond the ring, clear of districts, lots and the Boss Field
	local outsideOk = true
	for _, id in ipairs({ "ExpeditionCamp" }) do
		local x, z = World.TownSpot(id)
		local r = math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2)
		if r < World.TOWN_RING + 30 or math.abs(x) > 330 then
			outsideOk = false
		end
		for _, did in ipairs(ids) do
			local dx, dz = World.DistrictPoint(did)
			if math.sqrt((x - dx) ^ 2 + (z - dz) ^ 2) < World.Districts[did].Size + 30 then
				outsideOk = false
			end
		end
		if math.sqrt((x - f.X) ^ 2 + (z - f.Z) ^ 2) < f.Radius + 30 then
			outsideOk = false
		end
		for slot = 1, World.MAX_LOTS do
			local ax, _, az = World.ArenaOrigin(slot)
			if math.abs(x - ax) < World.ARENA_WIDTH / 2 + 30 and math.abs(z - az) < World.ARENA_DEPTH / 2 + 30 then
				outsideOk = false
			end
		end
	end
	check("The Expedition Camp stands outside town, clear of everything", outsideOk)
	-- the town wall rings everything that is the town, and the places outside it are outside it
	local wall = World.TOWN_WALL
	local function r(x, z)
		return math.sqrt((x - World.PLAZA.X) ^ 2 + (z - World.PLAZA.Z) ^ 2)
	end
	local inside = true
	for _, did in ipairs(ids) do
		local x, z = World.DistrictPoint(did)
		inside = inside and r(x, z) + World.Districts[did].Size + 8 < wall.Radius
	end
	-- lots 1-4 stand inside the wall, lots 5-8 outside the Homes gate; none straddles the wall (corners in the lot's own
	-- turned frame: the pad, the front strip toward the street and the apron behind)
	local lotsClear, outsideLots = true, 0
	for slot = 1, World.MAX_LOTS do
		local ax, _, az, yaw = World.ArenaOrigin(slot)
		local c, sn = math.cos(yaw), math.sin(yaw)
		local ins, outs = 0, 0
		for _, lx in ipairs({ -World.ARENA_WIDTH / 2, World.ARENA_WIDTH / 2 }) do
			for _, lz in ipairs({ World.ARENA_DEPTH / 2 + 8, -World.ARENA_DEPTH / 2 - World.APRON_DEPTH }) do
				-- local -> world (inverse of the frame used by Town.clearOfEverything)
				local wx, wz = ax + lx * c + lz * sn, az - lx * sn + lz * c
				local d = r(wx, wz)
				if d + 6 < wall.Radius then
					ins += 1
				elseif d - 6 > wall.Radius then
					outs += 1
				end
			end
		end
		if ins ~= 4 and outs ~= 4 then
			lotsClear = false
		end
		if outs == 4 then
			outsideLots += 1
		end
	end
	local homesGate = false
	for _, g in ipairs(wall.Gates) do
		homesGate = homesGate or (not g.Hill and g.Angle == World.HOMES_STREET.Angle)
	end
	check("The town wall rings the plaza and every district", inside)
	check("No lot straddles the town wall (lots 1-4 inside, 5-8 outside)", lotsClear and outsideLots == World.MAX_LOTS - 4)
	check("The homes street goes through a gate in the wall", homesGate)
	-- every lot that can ever exist (LOT_LIMIT = Max Players) stands on ground: the town Ground part (720 x 840 centred
	-- on (0, 20), WorldService) or the strip outside the Homes gate (World.OuterGround), corners included
	local gx, gz, gyaw, glen, gwid = World.OuterGround()
	local function onGround(x, z)
		if math.abs(x) <= 360 and math.abs(z - 20) <= 420 then
			return true
		end
		local dx, dz = x - gx, z - gz
		local along = dx * math.sin(gyaw) + dz * math.cos(gyaw)
		local across = dx * math.cos(gyaw) - dz * math.sin(gyaw)
		return math.abs(along) <= glen / 2 and math.abs(across) <= gwid / 2
	end
	local floorOk = true
	for slot = 1, World.LOT_LIMIT do
		local ax, _, az, yaw = World.ArenaOrigin(slot)
		local c, sn = math.cos(yaw), math.sin(yaw)
		for _, lx in ipairs({ -World.ARENA_WIDTH / 2, World.ARENA_WIDTH / 2 }) do
			for _, lz in ipairs({ World.ARENA_DEPTH / 2 + 8, -World.ARENA_DEPTH / 2 - World.APRON_DEPTH }) do
				if not onGround(ax + lx * c + lz * sn, az - lx * sn + lz * c) then
					floorOk = false
				end
			end
		end
	end
	check("Every lot (overflow lots up to Max Players included) stands on ground", floorOk and World.LOT_LIMIT >= World.MAX_PLAYERS)
	local dgx, dgz = World.TownSpot("DungeonGate")
	local ecx, ecz = World.TownSpot("ExpeditionCamp")
	check("The Giant Bosses field and the Expedition Camp are outside the wall", r(f.X, f.Z) - f.Radius > wall.Radius + 4 and r(ecx, ecz) - 24 > wall.Radius)
	check("The Dungeon is built into the wall", math.abs(r(dgx, dgz) - wall.Radius) < 40)
	local mainGate, bossGate, dungeonHill = false, false, false
	local function angleOf(x, z)
		return math.deg(math.atan2(x - World.PLAZA.X, -(z - World.PLAZA.Z))) % 360
	end
	local function near(a, b, tol)
		return math.abs(((a - b + 180) % 360) - 180) <= tol
	end
	for _, g in ipairs(wall.Gates) do
		mainGate = mainGate or (g.Main and g.Angle == 180)
		bossGate = bossGate or (not g.Hill and near(g.Angle, angleOf(f.X, f.Z), 10))
		dungeonHill = dungeonHill or (g.Hill and near(g.Angle, angleOf(dgx, dgz), 6))
	end
	check("The main gate is south, a gate faces the Giant Bosses, the Dungeon hill stands in the wall", mainGate and bossGate and dungeonHill)
	-- the shops stand in the Market
	local marketOk = true
	local mx, mz = World.DistrictPoint("Market")
	for _, shop in ipairs({ "Merchant", "PetStore", "Trainer", "Blacksmith", "RuneCarver", "Store" }) do
		local sx, sz = World.PlazaPoint(shop)
		marketOk = marketOk and math.sqrt((sx - mx) ^ 2 + (sz - mz) ^ 2) < World.Districts.Market.Size
	end
	check("Every shop stands in the Market", marketOk)
	local spacingOk = true
	for a, sa in pairs(World.PlazaSpots) do
		for b, sb in pairs(World.PlazaSpots) do
			if a < b and ((sa.Radius or 0) < 70) == ((sb.Radius or 0) < 70) then -- plaza boards with each other, Market stalls with each other
				local ax2, az2 = World.PlazaPoint(a)
				local bx2, bz2 = World.PlazaPoint(b)
				if math.sqrt((ax2 - bx2) ^ 2 + (az2 - bz2) ^ 2) < 18 then
					spacingOk = false
				end
			end
		end
	end
	check("Plaza boards and Market stalls are at least 18 studs apart", spacingOk)

	print(("PresentationTests done: %d passed, %d failed"):format(passed, failed))
end
