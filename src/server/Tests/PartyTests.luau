--[[
	PartyTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > PartyTests

	Not run automatically. In Studio's Command Bar (View > Command Bar), run:

	  require(game.ServerScriptService.Server.Tests.PartyTests)()
]]

local function loadModules(override)
	if override then
		return override
	end
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return {
		ProfileTemplate = require(Shared.ProfileTemplate),
		Party = require(Shared.Party),
		Offline = require(Shared.Offline),
		Progression = require(Shared.Progression),
		OfflineConfig = require(Shared.Config.Offline),
	}
end

return function(modulesOverride)
	local m = loadModules(modulesOverride)
	local ProfileTemplate, Party, Offline, Progression = m.ProfileTemplate, m.Party, m.Offline, m.Progression
	local OfflineConfig = m.OfflineConfig
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

	print("Running PartyTests...")

	local H = 3600
	local WARRIOR_ID, CLERIC_ID = 1001, 1002

	local function newPlayers()
		local warrior, cleric = ProfileTemplate.New(), ProfileTemplate.New()
		cleric.Season.ClassId = "Cleric"
		return warrior, cleric
	end

	-- A party with both snapshots saved, as after both have logged out once.
	local function newParty(warrior, cleric, now)
		local party = Party.New("party1", 1, WARRIOR_ID, CLERIC_ID, now or 1000)
		Party.RefreshSnapshot(party, WARRIOR_ID, "Warrior", warrior, now or 1000)
		Party.RefreshSnapshot(party, CLERIC_ID, "Cleric", cleric, now or 1000)
		return party
	end

	-- Offline tiers -----------------------------------------------------------
	local function near(a, b)
		return math.abs(a - b) < 0.01
	end
	check("Under the minimum there is nothing to estimate", Offline.EffectiveSeconds(0) == 0)
	check("First 12 hours pay 50%", near(Offline.EffectiveSeconds(6 * H), 3 * H) and near(Offline.EffectiveSeconds(12 * H), 6 * H))
	check("12-24 hours pay 30%", near(Offline.EffectiveSeconds(24 * H), 6 * H + 0.3 * 12 * H))
	check("24-72 hours pay 15%", near(Offline.EffectiveSeconds(72 * H), 6 * H + 0.3 * 12 * H + 0.15 * 48 * H))
	check("After 72 hours it still earns (no hard cap)", Offline.EffectiveSeconds(200 * H) > Offline.EffectiveSeconds(72 * H))
	check("Every extra hour earns less than the one before", (Offline.EffectiveSeconds(13 * H) - Offline.EffectiveSeconds(12 * H)) < (Offline.EffectiveSeconds(12 * H) - Offline.EffectiveSeconds(11 * H)) and (Offline.EffectiveSeconds(100 * H) - Offline.EffectiveSeconds(99 * H)) < (Offline.EffectiveSeconds(30 * H) - Offline.EffectiveSeconds(29 * H)))

	-- Snapshots and the ghost loadout ----------------------------------------
	local warrior, cleric = newPlayers()
	warrior.Season.OwnedAbilities.ShieldWall = true
	local party = newParty(warrior, cleric)
	local snap = party.Snapshots[tostring(WARRIOR_ID)]
	check("A snapshot copies class, level, slots and starts with the player's loadout", snap.ClassId == "Warrior" and snap.Level == 1 and #snap.SlotLevels == 4 and snap.GhostLoadout[1] == warrior.Season.Loadouts.Warrior[1] and snap.Owned.ShieldWall == true)
	check("The snapshot is independent of the profile", (function()
		warrior.Season.SlotLevels.Warrior[1] = 9
		return snap.SlotLevels[1] == 1
	end)())
	warrior.Season.SlotLevels.Warrior[1] = 1

	local newLoadout = { "ShieldWall", "Taunt", "IronSkin", "ShieldBash" }
	check("The partner can set the owner's ghost loadout", Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, newLoadout, 2000) and snap.GhostLoadout[1] == "ShieldWall")
	check("The owner's own live loadout is untouched", warrior.Season.Loadouts.Warrior[1] ~= "ShieldWall")
	check("The owner can set it too", Party.SetGhostLoadout(party, WARRIOR_ID, WARRIOR_ID, { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" }, 2001))
	Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, newLoadout, 2002)
	check("A stranger cannot edit", select(2, Party.SetGhostLoadout(party, 555, WARRIOR_ID, newLoadout, 2003)) == "NotMember")
	check("Unowned skills are rejected", select(2, Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, { "LastStand", "Taunt", "IronSkin", "ShieldBash" }, 2004)) == "NotOwned")
	check("Duplicates and other classes' skills are rejected", select(2, Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, { "Taunt", "Taunt", "IronSkin", "ShieldBash" }, 2005)) == "Duplicate" and select(2, Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, { "Heal", "Taunt", "IronSkin", "ShieldBash" }, 2006)) == "WrongClass")
	check("A partial loadout is rejected", select(2, Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, { "Taunt", "IronSkin" }, 2007)) == "NeedFullLoadout")
	check("Edits are logged with who made them", #snap.History == 3 and snap.History[#snap.History].By == CLERIC_ID)
	check("The owner can revert the last change in one step", Party.RevertGhostLoadout(party, WARRIOR_ID) and snap.GhostLoadout[1] == "Taunt" and #snap.History == 2)
	check("Nothing to revert once the history is empty", (function()
		Party.RevertGhostLoadout(party, WARRIOR_ID)
		Party.RevertGhostLoadout(party, WARRIOR_ID)
		return select(2, Party.RevertGhostLoadout(party, WARRIOR_ID)) == "NothingToRevert"
	end)())
	Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, newLoadout, 2100)
	Party.RefreshSnapshot(party, WARRIOR_ID, "Warrior", warrior, 2200)
	check("Refreshing the snapshot keeps the partner-edited ghost loadout", party.Snapshots[tostring(WARRIOR_ID)].GhostLoadout[1] == "ShieldWall")
	warrior.Season.OwnedAbilities.ShieldWall = nil
	Party.RefreshSnapshot(party, WARRIOR_ID, "Warrior", warrior, 2300)
	check("A ghost loadout that is no longer valid falls back to the live loadout", party.Snapshots[tostring(WARRIOR_ID)].GhostLoadout[1] == warrior.Season.Loadouts.Warrior[1])
	for i = 1, 8 do
		Party.SetGhostLoadout(party, CLERIC_ID, WARRIOR_ID, if i % 2 == 0 then { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" } else { "IronSkin", "Taunt", "ShieldBash", "Whirlwind" }, 2400 + i)
	end
	check("History keeps only the latest few changes", #party.Snapshots[tostring(WARRIOR_ID)].History == Party.HISTORY_LIMIT)

	-- Shared stage: partner progress ----------------------------------------------
	warrior, cleric = newPlayers()
	party = newParty(warrior, cleric)
	local gold0 = cleric.Season.Currencies.Gold
	local won = 0
	for seed = 1, 6 do
		local outcome = Party.OnlineTick(party, { { UserId = WARRIOR_ID, Name = "Warrior", Profile = warrior } }, seed, 1100 + seed)
		if outcome.Won then
			won += 1
		end
	end
	check("An online player with the partner's ghost clears stages", won >= 3 and party.Frontier > 3)
	check("The online player is paid for each clear", warrior.Season.HighestStage == party.Frontier and warrior.Season.Currencies.Gold > 0)
	check("The offline partner's profile does not change by itself", cleric.Season.HighestStage == 1 and cleric.Season.Currencies.Gold == gold0)
	local frontierBefore = party.Frontier
	local result = Party.Claim(party, CLERIC_ID, cleric)
	check("On login the partner is credited for every stage cleared", result.CatchUp.Stages == frontierBefore - 1 and cleric.Season.HighestStage == frontierBefore)
	check("The partner earned gold, XP and shards for those stages", result.CatchUp.Gold > 0 and result.CatchUp.XP > 0 and result.CatchUp.Shards > 0 and cleric.Season.Currencies.Gold == result.CatchUp.Gold)
	check("The partner got the same frontier rewards the player did", cleric.Season.Currencies.Shards == warrior.Season.Currencies.Shards)
	local again = Party.Claim(party, CLERIC_ID, cleric)
	check("Claiming twice pays nothing more", again.CatchUp.Stages == 0 and again.Afk == nil)

	-- Both online
	local weakW, weakC = newPlayers()
	local pair = newParty(weakW, weakC)
	local out2 = Party.OnlineTick(pair, { { UserId = WARRIOR_ID, Name = "Warrior", Profile = weakW }, { UserId = CLERIC_ID, Name = "Cleric", Profile = weakC } }, 4, 1500)
	check("Both online: both are paid", out2.Won and weakW.Season.Currencies.Gold > 0 and weakC.Season.Currencies.Gold == weakW.Season.Currencies.Gold)

	-- Losing and nobody online
	local strongParty = newParty(newPlayers())
	strongParty.Stage, strongParty.Frontier = 90, 90
	local frail = ProfileTemplate.New()
	local lossOutcome = Party.OnlineTick(strongParty, { { UserId = WARRIOR_ID, Name = "Warrior", Profile = frail } }, 3, 1200)
	check("A loss steps the party back and keeps the frontier", not lossOutcome.Won and strongParty.Stage == 89 and strongParty.Frontier == 90)
	local before = strongParty.Stage
	local none, reason = Party.OnlineTick(strongParty, {}, 3, 1300)
	check("Both offline: the party never advances", none == nil and reason == "NoneOnline" and strongParty.Stage == before and strongParty.Frontier == 90)

	-- AFK ---------------------------------------------------------------------------
	warrior, cleric = newPlayers()
	party = newParty(warrior, cleric, 10000)
	party.Stage, party.Frontier = 20, 20
	warrior.Season.HighestStage, cleric.Season.HighestStage = 20, 20
	Party.RefreshSnapshot(party, WARRIOR_ID, "Warrior", warrior, 10000)
	Party.RefreshSnapshot(party, CLERIC_ID, "Cleric", cleric, 10000)
	local estimate = Party.OpenSession(party, 1, WARRIOR_ID, "Warrior", warrior, false, 10000 + 10 * H)
	check("Logging in after a both-offline gap queues AFK gains for BOTH members", estimate ~= nil and party.Pending[tostring(WARRIOR_ID)] ~= nil and party.Pending[tostring(CLERIC_ID)] ~= nil)
	check("AFK never moves the frontier", party.Frontier == 20 and warrior.Season.HighestStage == 20)
	check("The party farms a stage it can actually clear", estimate.Stage <= 20 and estimate.Stage >= 1 and party.Stage == estimate.Stage)

	local afkClaim = Party.Claim(party, WARRIOR_ID, warrior)
	check("The member claims their AFK gains at login", afkClaim.Afk ~= nil and afkClaim.Afk.Gold > 0 and afkClaim.Afk.XP > 0 and warrior.Season.Currencies.Gold >= afkClaim.Afk.Gold)
	check("A second claim pays no AFK", Party.Claim(party, WARRIOR_ID, warrior).Afk == nil)
	local partnerClaim = Party.Claim(party, CLERIC_ID, cleric)
	check("The partner can still claim the same gap's gains later", partnerClaim.Afk ~= nil and partnerClaim.Afk.Gold > 0)

	-- AFK is a reduced rate compared with playing live at the same stage.
	local liveW, liveC = newPlayers()
	local snapW = Party.MakeSnapshot(liveW, WARRIOR_ID, "Warrior", nil, 0)
	snapW.Frontier = 1
	local members = {
		{ Id = "1001", Name = "Warrior", Snapshot = snapW },
		{ Id = "1002", Name = "Cleric", Snapshot = Party.MakeSnapshot(liveC, CLERIC_ID, "Cleric", nil, 0) },
	}
	local est12 = Offline.Estimate(members, 5, 12 * H)
	local liveFights = (12 * H) / (est12.FightSeconds + OfflineConfig.Intermission)
	local livePerClear = Progression.ClearRewards(est12.Stage, true).Gold
	local ratio = est12.Rewards["1001"].Gold / (liveFights * livePerClear)
	check("12 hours offline pays about 50% of playing live", ratio > 0.47 and ratio < 0.53)
	local est200 = Offline.Estimate(members, 5, 200 * H)
	check("Longer gaps always pay more, with no cap", est200.Rewards["1001"].XP > est12.Rewards["1001"].XP)
	check("But much less than live play would", est200.Rewards["1001"].Gold < 200 * H / (est12.FightSeconds + OfflineConfig.Intermission) * livePerClear * 0.2)
	check("Gaps under the minimum are ignored", Offline.Estimate(members, 5, 30) == nil)

	-- The farm stage steps down to what the party can clear.
	local farmStage = Offline.FindFarmStage(members, 90)
	check("A weak party's AFK stage is below the stage it was on", farmStage < 90 and farmStage >= 1)

	-- Partner online: no AFK gap is counted.
	local p3w, p3c = newPlayers()
	local p3 = newParty(p3w, p3c, 50000)
	local none3 = Party.OpenSession(p3, 1, WARRIOR_ID, "Warrior", p3w, true, 50000 + 10 * H)
	check("No AFK gap when the partner is online", none3 == nil and next(p3.Pending) == nil)
	check("Opening a session restarts the inactivity clock", p3.LastActiveAt == 50000 + 10 * H)
	Party.CloseSession(p3, WARRIOR_ID, "Warrior", p3w, 60000)
	check("Closing a session saves the snapshot and marks the time", p3.LastActiveAt == 60000 and p3.Snapshots[tostring(WARRIOR_ID)].SavedAt == 60000)

	-- A partner who has never logged in cannot farm AFK yet.
	local solo = Party.New("solo", 1, WARRIOR_ID, CLERIC_ID, 100)
	local soloW = ProfileTemplate.New()
	check("Without a partner snapshot there is no AFK", Party.OpenSession(solo, 1, WARRIOR_ID, "Warrior", soloW, false, 100 + 5 * H) == nil)

	-- A solo player (a party of one, companions in the other seats) earns while away too.
	local alone = Party.NewOpen("alone", 1, WARRIOR_ID, 100, 1)
	local aloneP = ProfileTemplate.New()
	aloneP.Season.ClassId = "Warrior"
	Party.SyncCompanions(alone, aloneP, 100)
	check("A solo player's first login has no AFK (no snapshot yet)", Party.OpenSession(alone, 1, WARRIOR_ID, "Solo", aloneP, false, 100) == nil)
	Party.CloseSession(alone, WARRIOR_ID, "Solo", aloneP, 200)
	local soloEst = Party.OpenSession(alone, 1, WARRIOR_ID, "Solo", aloneP, false, 200 + 5 * H)
	local soloPending = alone.Pending[tostring(WARRIOR_ID)]
	check("A solo player earns AFK gold and XP while away", soloEst ~= nil and soloPending ~= nil and soloPending.Gold > 0 and soloPending.XP > 0 and soloPending.Fights > 0)
	local soloClaim = Party.Claim(alone, WARRIOR_ID, aloneP)
	check("The solo AFK gains are paid at login", soloClaim.Afk ~= nil and soloClaim.Afk.Gold == soloPending.Gold and alone.Pending[tostring(WARRIOR_ID)] == nil)

	-- companions spend their owner's talent points by their own role (a talented player tank outlasted them before)
	aloneP.Season.Level = 41
	local comps = Party.SyncCompanions(alone, aloneP, 300)
	local function modOf(companion, stat)
		local total = 0
		for _, mod in ipairs(companion.CollectionMods or {}) do
			if mod.Stat == stat then
				total += mod.Value
			end
		end
		return total
	end
	local mage, healer = nil, nil
	for _, c in ipairs(comps) do
		if c.ClassId == "Cleric" then healer = c end
		if c.ClassId == "Mage" then mage = c end
	end
	check("Companions get their owner's talent points", healer ~= nil and modOf(healer, "Attack") > 0 and mage ~= nil and modOf(mage, "Attack") > 0)

	-- Season reset
	local sp = newParty(newPlayers())
	sp.Stage, sp.Frontier = 40, 40
	sp.Pending[tostring(WARRIOR_ID)] = { Gold = 5 }
	check("A new season resets the shared stage but keeps the party", Party.EnsureSeason(sp, 2) and sp.Stage == 1 and sp.Frontier == 1 and next(sp.Pending) == nil and sp.PartyId == "party1" and #sp.Members == 2)
	check("The same season is left alone", not Party.EnsureSeason(sp, 2))
	sp.Stage, sp.Frontier = 9, 9
	check("An older season never wipes a newer record", not Party.EnsureSeason(sp, 1) and sp.SeasonId == 2 and sp.Frontier == 9)

	-- A stronger player joining a weaker one carries them up.
	local strong, weak = ProfileTemplate.New(), ProfileTemplate.New()
	weak.Season.ClassId = "Cleric"
	strong.Season.HighestStage = 25
	local carry = Party.New("c", 1, WARRIOR_ID, CLERIC_ID, 0, 25, 3)
	check("A party starts at the weaker member's frontier", carry.Stage == 3 and carry.Frontier == 3)
	Party.RefreshSnapshot(carry, WARRIOR_ID, "Strong", strong, 0)
	Party.RefreshSnapshot(carry, CLERIC_ID, "Weak", weak, 0)
	Party.OpenSession(carry, 1, WARRIOR_ID, "Strong", strong, true, 10)
	check("The stronger player does not lift the party's stage", carry.Frontier == 3 and carry.Stage == 3)
	local strongGold = strong.Season.Currencies.Gold
	local carried = Party.OnlineTick(carry, { { UserId = WARRIOR_ID, Name = "Strong", Profile = strong } }, 9, 20)
	check("The pair clears the weaker member's stage and moves up", carried.Won and carry.Frontier == 4 and strong.Season.HighestStage == 25)
	check("The stronger player is paid the reduced replay rate for old stages", carried.Rewards["1001"].FrontierClear == false and strong.Season.Currencies.Gold > strongGold)
	local weakClaim = Party.Claim(carry, CLERIC_ID, weak)
	check("The weaker player is paid full frontier rewards for the carried stage", weakClaim.CatchUp.Stages == 3 and weak.Season.HighestStage == 4 and weakClaim.CatchUp.Gold > 0)

	-- stage selection from the map (farming)
	local fp = newParty(strong, weak, 1000)
	fp.Frontier = 5
	fp.Stage = 5
	check("A member can pick an unlocked earlier stage", Party.SetStage(fp, WARRIOR_ID, 2) and fp.Stage == 2 and fp.Farm == true)
	check("Locked stages are refused", select(2, Party.SetStage(fp, WARRIOR_ID, 6)) == "Locked")
	check("Bad stages are refused", select(2, Party.SetStage(fp, WARRIOR_ID, 0)) == "BadStage" and select(2, Party.SetStage(fp, WARRIOR_ID, 1.5)) == "BadStage")
	check("Strangers cannot pick a stage", select(2, Party.SetStage(fp, 99999, 1)) == "NotMember")
	local farmed = Party.OnlineTick(fp, { { UserId = WARRIOR_ID, Name = "Strong", Profile = strong } }, 5, 2000)
	check("A won farm fight stays on the same stage", farmed.Won and fp.Stage == 2 and fp.Frontier == 5)
	Party.SetStage(fp, WARRIOR_ID, 5)
	check("Picking the frontier ends farming", fp.Farm == nil and fp.Stage == 5)

	-- a loss holds on the prior stage until the players advance
	local hold = newParty(strong, weak, 1000)
	hold.Frontier = 60
	hold.Stage = 60
	local lost = Party.OnlineTick(hold, { { UserId = WARRIOR_ID, Name = "Strong", Profile = strong } }, 3, 3000)
	check("A loss steps back one stage and holds", not lost.Won and hold.Stage == 59 and hold.Farm == true)
	local still = Party.OnlineTick(hold, { { UserId = WARRIOR_ID, Name = "Strong", Profile = strong } }, 3, 4000)
	check("A held party does not climb back on its own", hold.Stage <= 59)
	hold.Stage = 59
	check("Advance moves one stage up", Party.Advance(hold, WARRIOR_ID) and hold.Stage == 60)
	check("Advance stops at the frontier", select(2, Party.Advance(hold, WARRIOR_ID)) == "Locked")

	print(("PartyTests done: %d passed, %d failed"):format(passed, failed))
end
