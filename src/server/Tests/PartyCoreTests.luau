--[[
	PartyCoreTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PartyCoreTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PartyCoreTests)()

	Uses in-memory stores, so it never touches real DataStores.
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		ProfileTemplate = require(Shared.ProfileTemplate),
		Party = require(Shared.Party),
		TableUtil = require(Shared.Util.TableUtil),
		PartyCore = require(script.Parent.Parent.Services.PartyCore),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local ProfileTemplate, Party, TableUtil, PartyCore = m.ProfileTemplate, m.Party, m.TableUtil, m.PartyCore
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

	print("Running PartyCoreTests...")

	-- An in-memory store with the same shape as the DataStore-backed one.
	local function newStore()
		local data = {}
		local store = { Data = data }
		function store:Get(k)
			return true, if data[k] ~= nil then TableUtil.DeepCopy(data[k]) else nil
		end
		function store:Update(k, transform)
			local result = transform(if data[k] ~= nil then TableUtil.DeepCopy(data[k]) else nil)
			if result ~= nil then
				data[k] = TableUtil.DeepCopy(result)
			end
			return true, result
		end
		function store:Remove(k)
			data[k] = nil
			return true
		end
		return store
	end

	local clock = { T = 1000 }
	local parties, codes = newStore(), newStore()
	local idCounter = 0
	local function deps(serverId, randomFn)
		return {
			Parties = parties,
			Codes = codes,
			ServerId = serverId or "serverA",
			Now = function()
				return clock.T
			end,
			Random = randomFn or function(n)
				return math.random(1, n)
			end,
			NewId = function()
				idCounter += 1
				return "party" .. idCounter
			end,
		}
	end

	local function player(className)
		local profile = ProfileTemplate.New()
		profile.Season.ClassId = className or "Warrior"
		return profile
	end

	local A, B, C = 1001, 1002, 1003
	local d = deps("serverA")

	-- Create -----------------------------------------------------------------------
	local profA = player("Warrior")
	local okCreate, partyA = PartyCore.CreateSolo(d, A, "Aiden", profA, 1)
	check("A new player gets an open solo party", okCreate and #partyA.Members == 1 and Party.IsOpen(partyA) and profA.Permanent.PartyId == partyA.PartyId)
	check("The solo party has the member's snapshot", partyA.Snapshots["1001"] ~= nil and partyA.Snapshots["1001"].ClassId == "Warrior")
	check("The record is stored", select(1, PartyCore.Get(d, partyA.PartyId)) == true)
	check("Unknown parties are reported", select(2, PartyCore.Get(d, "nope")) == "NoParty")

	-- Hosting --------------------------------------------------------------------------
	local okHost, hosted = PartyCore.AcquireHost(d, partyA.PartyId)
	check("The first server becomes host", okHost and hosted.Host.JobId == "serverA")
	local dB = deps("serverB")
	local okOther, reasonOther, hostInfo = PartyCore.AcquireHost(dB, partyA.PartyId)
	check("A second server is told the party is hosted elsewhere", not okOther and reasonOther == "HostedElsewhere" and hostInfo.JobId == "serverA")
	check("The same server can re-acquire", (PartyCore.AcquireHost(d, partyA.PartyId)))
	clock.T += PartyCore.HOST_TIMEOUT + 1
	check("A silent host times out and another server takes over", (PartyCore.AcquireHost(dB, partyA.PartyId)))
	check("The old host has lost its right to save", select(2, PartyCore.SaveProgress(d, hosted, {})) == "LostHost")
	check("Only the host can release", (function()
		PartyCore.ReleaseHost(d, partyA.PartyId) -- serverA is not the host any more
		return select(3, PartyCore.AcquireHost(d, partyA.PartyId)) ~= nil
	end)())
	PartyCore.ReleaseHost(dB, partyA.PartyId)
	check("A released party can be taken at once", (PartyCore.AcquireHost(d, partyA.PartyId)))

	-- Saving progress ---------------------------------------------------------------------
	local _, record = PartyCore.Get(d, partyA.PartyId)
	record.Stage, record.Frontier = 7, 7
	record.Snapshots["1001"].Level = 12
	record.Pending["1001"] = { Gold = 5 }
	local okSave, saved, changed = PartyCore.SaveProgress(d, record, { ["1001"] = true })
	check("The host saves progress", okSave and not changed and saved.Stage == 7 and saved.Frontier == 7 and saved.Snapshots["1001"].Level == 12 and saved.Pending["1001"].Gold == 5)
	check("Saving refreshes the host timestamp", saved.Host.At == clock.T)
	record.Snapshots["1001"].Level = 99
	local _, notManaged = PartyCore.SaveProgress(d, record, {})
	check("Snapshots of members the host does not manage are left alone", notManaged.Snapshots["1001"].Level == 12)

	-- Join codes --------------------------------------------------------------------------
	check("Codes are normalised and validated", PartyCore.NormalizeCode(" ab c2 3d ") == "ABC23D" and PartyCore.NormalizeCode("ABC") == nil and PartyCore.NormalizeCode("ABCDE0") == nil and PartyCore.NormalizeCode(5) == nil)
	check("Only a member can make a code", select(2, PartyCore.CreateCode(d, partyA.PartyId, B)) == "NotMember")
	local okCode, code, expires = PartyCore.CreateCode(d, partyA.PartyId, A)
	check("A member of an open party can make a code", okCode and #code == PartyCore.CODE_LENGTH and PartyCore.NormalizeCode(code) == code and expires == clock.T + PartyCore.CODE_TTL)

	local collisions = 0
	local sameCode = deps("serverA", function(n)
		collisions += 1
		return if collisions <= 6 then 1 else 2 -- six chars all "A", then all "B"
	end)
	local profX = player()
	local _, partyX = PartyCore.CreateSolo(sameCode, 2001, "X", profX, 1)
	PartyCore.CreateCode(sameCode, partyX.PartyId, 2001) -- takes AAAAAA
	collisions = 0
	local profY = player()
	local _, partyY = PartyCore.CreateSolo(sameCode, 2002, "Y", profY, 1)
	local okY, codeY = PartyCore.CreateCode(sameCode, partyY.PartyId, 2002)
	check("A code that is already taken is not reused", okY and codeY ~= "AAAAAA")

	-- leaving a party must never send you back to stage 1: a new solo party starts at your own frontier
	local profL = player("Warrior")
	profL.Season.HighestStage = 37
	local _, partyL = PartyCore.CreateSolo(deps("serverL"), 3001, "Lea", profL, 1)
	check("A new solo party starts at the player's frontier, not stage 1", partyL.Stage == 37 and partyL.Frontier == 37)

	-- Join ----------------------------------------------------------------------------------
	local profB = player("Cleric")
	profB.Season.HighestStage = 3
	local dB2 = deps("serverB")
	local _, partyB = PartyCore.CreateSolo(dB2, B, "Bea", profB, 1)
	profA.Season.HighestStage = 25
	local _, stored = PartyCore.Get(d, partyA.PartyId)
	stored.Snapshots["1001"].Frontier = 25
	stored.Stage, stored.Frontier = 25, 25
	PartyCore.SaveProgress(d, stored, { ["1001"] = true })

	check("A bad code is refused", select(2, PartyCore.JoinByCode(dB2, B, "Bea", profB, 1, "ZZZZZZ")) == "BadCode" and select(2, PartyCore.JoinByCode(dB2, B, "Bea", profB, 1, "!!")) == "BadCode")
	check("You cannot join your own party", select(2, PartyCore.JoinByCode(d, A, "Aiden", profA, 1, code)) == "OwnParty")

	local okJoin, joined, abandoned = PartyCore.JoinByCode(dB2, B, "Bea", profB, 1, code)
	check("A player joins by code", okJoin and #joined.Members == 2 and joined.Members[2] == B and profB.Permanent.PartyId == partyA.PartyId)
	check("The pair starts at the weaker member's frontier", joined.Stage == 3 and joined.Frontier == 3)
	check("The joiner's own solo party is deleted", abandoned == partyB.PartyId and select(2, PartyCore.Get(d, partyB.PartyId)) == "NoParty")
	check("Membership changes bump the revision", joined.Rev == 2)
	check("A pair still has free seats (parties hold up to 4)", Party.IsOpen(joined) and Party.MAX_MEMBERS == 4)
	check("Both members have ghosts", joined.Snapshots["1001"] ~= nil and joined.Snapshots["1002"].ClassId == "Cleric")

	-- The host sees the membership change instead of overwriting it.
	record.Stage = 50
	local _, afterJoin, membershipChanged = PartyCore.SaveProgress(d, record, { ["1001"] = true })
	check("A host with a stale revision does not overwrite the new membership", membershipChanged and #afterJoin.Members == 2 and afterJoin.Stage == 3)

	-- A party with a free seat can still make a code; a full one (4) cannot take anyone
	local okMore = PartyCore.CreateCode(d, partyA.PartyId, A)
	check("A pair can make another code for its free seats", okMore == true)
	check("A party of four is full", not Party.IsOpen({ Members = { 1, 2, 3, 4 } }))

	-- Already in a pair
	local profC = player()
	local _, partyC = PartyCore.CreateSolo(d, C, "Cy", profC, 1)
	local _, codeC = PartyCore.CreateCode(d, partyC.PartyId, C)
	check("Someone already in a pair must leave first", select(2, PartyCore.JoinByCode(dB2, B, "Bea", profB, 1, codeC)) == "AlreadyInParty")

	-- Expired code
	clock.T += PartyCore.CODE_TTL + 1
	local profD = player()
	check("An expired code is refused", select(2, PartyCore.JoinByCode(d, 1004, "Dee", profD, 1, codeC)) == "BadCode")

	-- Leave ------------------------------------------------------------------------------------
	local okLeave, remaining = PartyCore.Leave(dB2, B, profB)
	check("Leaving clears the player's party", okLeave and remaining == 1 and profB.Permanent.PartyId == nil)
	local _, afterLeave = PartyCore.Get(d, partyA.PartyId)
	check("The remaining member keeps an open party and its stage", #afterLeave.Members == 1 and afterLeave.Members[1] == A and Party.IsOpen(afterLeave) and afterLeave.Stage == 3)
	check("The leaver's ghost and pending gains are removed", afterLeave.Snapshots["1002"] == nil and afterLeave.Pending["1002"] == nil)
	check("Leaving again is refused", select(2, PartyCore.Leave(dB2, B, profB)) == "NoParty")
	local okLast, none = PartyCore.Leave(d, A, profA)
	check("The last member leaving deletes the party", okLast and none == 0 and select(2, PartyCore.Get(d, partyA.PartyId)) == "NoParty")

	print(("PartyCoreTests done: %d passed, %d failed"):format(passed, failed))
end
