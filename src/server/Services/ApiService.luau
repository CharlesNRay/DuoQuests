--[[
	ApiService (ModuleScript)
	Location: ServerScriptService > Server > Services > ApiService

	The doorway between the UI and the game rules. The client sends a request
	by name (Api:InvokeServer(action, ...)); the server checks the arguments,
	runs the same Economy / Party functions the tests cover, and answers
	(ok, data | reason). The client can only ask; it can never change its own
	data.

	Actions
	  GetState                          -> full UI state (see buildState)
	  EquipSkills(ids)                  -> ok | false, reason
	  LevelSlot(slotIndex)
	  Wish(kind, tierId, method, count) the Wishing Tree (kind Pet|Skill; method Ticket|Currency; count 1|10)
	  UnlockSkillWithPick(abilityId)    use a free pick
	  EquipPassives(ids)
	  LevelPassiveSlot(slotIndex)
	  SetUltimate(ultimateId)           the party's ultimate (either member)
	  GetLeaderboard(categoryId)        top rows + your own score, "Stage" or "Level"
	  Inspect(userId)                   public card of a party member on this server
	  ChooseSubclass(subclassId)        pick a subclass path (once per season)
	  EquipGear(itemId, wornSlot?) / UnequipGear(slot) / SellGear(itemId)   equipment (8 worn slots)
	  UseConsumable(id, petId?) / BuyConsumable(id, count)   the Stash: boosts, pet food, Merchant supplies
	  ClaimDaily()                      today's login reward
	  ClaimQuest(index) / ClaimQuestBonus() / ClaimWeeklyQuest(index) / ClaimWeeklyBonus() / BuyPremium(itemId) / ClaimPass(level|"All")   daily quests and the season pass
	  EquipPet(petId)  the companion that follows you and its bonus
	  SetStage(stage)                   pick any unlocked stage from the map (either member)
	  Advance()                         step up one stage after a loss held the party back
	  SetGhostLoadout(ids)              edit the PARTNER's ghost skills
	  RevertMyGhost()                   undo the latest edit to MY ghost
	  CreateCode() / JoinByCode(code) / Leave()

	Push events to clients: see Shared/Remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Economy)
local Passives = require(Shared.Passives)
local Progression = require(Shared.Progression)
local Skills = require(Shared.Skills)
local SkillProgress = require(Shared.SkillProgress)
local Party = require(Shared.Party)
local Pets = require(Shared.Pets)
local Gear = require(Shared.Gear)
local Consumables = require(Shared.Consumables)
local Wishing = require(Shared.Wishing)
local BossService = require(script.Parent.BossService)
local Hero = require(Shared.Hero)
local World = require(Shared.World)
local Daily = require(Shared.Daily)
local Quests = require(Shared.Quests)
local Premium = require(Shared.Premium)
local Subclasses = require(Shared.Subclasses)
local Abilities = require(Shared.Config.Abilities)

local DataService = require(script.Parent.DataService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Leaderboards = require(Shared.Leaderboards)

local ApiService = {}

local MIN_INTERVAL = 0.1 -- seconds between requests from one player
local lastCall = {} -- [userId] = os.clock()

local function isList(value, maxLength)
	if type(value) ~= "table" or #value > maxLength then
		return false
	end
	for key, item in pairs(value) do
		if type(key) ~= "number" or type(item) ~= "string" then
			return false
		end
	end
	return true
end

local function subclassChoices(profile, classId)
	local list = {}
	for _, def in ipairs(Subclasses.Available(profile, classId)) do
		local names = {}
		for _, skillId in ipairs(def.Skills) do
			table.insert(names, Abilities[skillId].DisplayName)
		end
		table.insert(list, { Id = def.Id, Name = def.DisplayName, Description = def.Description, Summary = Subclasses.Describe(def.Id), SkillNames = names })
	end
	return list
end

-- Shops only work when the player's character is standing at them.
local function nearShop(player, shop)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return World.NearShop(root.Position.X, root.Position.Z, shop)
end

local function suppliesOf(profile)
	local rows = {}
	for _, id in ipairs(Consumables.Order) do
		local def = Consumables.Defs[id]
		local price = Consumables.Price(def, profile.Season.HighestStage)
		if price then
			table.insert(rows, { Id = id, Name = def.DisplayName, Glyph = def.Glyph, Description = def.Description, Price = price, Kind = def.Kind })
		end
	end
	return rows
end

local function heroSheetOf(profile)
	local season = profile.Season
	local classId = season.ClassId
	local petId, petLevel, petRank = Pets.Active(profile)
	return Hero.Sheet({
		ClassId = classId,
		Level = season.Level,
		PassiveIds = season.PassiveLoadouts[classId],
		PassiveLevels = season.PassiveSlotLevels[classId],
		SubclassId = Subclasses.Current(profile, classId),
		Gear = (season.Equipment and season.Equipment.Equipped) or {},
		PetId = petId,
		PetLevel = petLevel,
		PetRank = petRank,
	})
end

local function buildState(player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local season = profile.Season
	local classId = season.ClassId

	local state = {
		Player = {
			UserId = player.UserId,
			Name = player.Name,
			ClassId = classId,
			Level = season.Level,
			XP = season.XP,
			XPNeeded = Progression.XPToNext(season.Level),
			Gold = season.Currencies.Gold,
			Shards = season.Currencies.Shards,
			Wishstones = season.Currencies.Wishstones or 0,
			SkillPicks = season.Currencies.SkillPicks,
			Frontier = season.HighestStage,
			Loadout = table.clone(season.Loadouts[classId]),
			SlotLevels = SkillProgress.SlotLevelsFor(season, season.Loadouts[classId]),
			SkillInfo = SkillProgress.Info(season),
			SkillReady = SkillProgress.AnyReady(season),
			Owned = table.clone(season.OwnedAbilities),
			PassiveIds = table.clone(season.PassiveLoadouts[classId]),
			PassiveLevels = table.clone(season.PassiveSlotLevels[classId]),
			PassiveSlots = Passives.SlotsAt(season.HighestStage),
			Pets = Pets.List(profile),
			Wishing = { Pet = Wishing.Info(profile, "Pet"), Skill = Wishing.Info(profile, "Skill") },
			ActivePet = (Pets.Active(profile)),
			SubclassId = Subclasses.Current(profile, classId),
			SubclassChoices = subclassChoices(profile, classId),
			SubclassUnlockLevel = (Subclasses.Choices(classId, Subclasses.Current(profile, classId))[1] or {}).UnlockLevel,
			Gear = Gear.List(profile),
			Stash = Consumables.List(profile),
			Buffs = Consumables.Active(profile, os.time()),
			Supplies = suppliesOf(profile),
			Sheet = heroSheetOf(profile),
			Daily = Daily.Status(profile, os.time()),
			Quests = Quests.Daily(profile, os.time()),
			WeeklyQuests = Quests.Weekly(profile, os.time()),
			Pass = Quests.Pass(profile),
			Sunstones = Premium.Sunstones(profile),
			PremiumShop = Premium.List(profile),
			SunstonePacks = Premium.Packs(profile),
		},
	}

	local party = PartyService.GetState(player)
	if party then
		party.Partner = PartyService.GetPartner(player)
		party.Ultimate = PartyService.GetUltimateInfo(player)
		party.MyGhostEdits = PartyService.GetMyGhostHistory(player)
		state.Party = party
	end
	state.LastClaim = PartyService.GetLastClaim(player)
	return state
end

-- After a build change, the partner's ghost of this player must match.
local function afterBuildChange(player)
	PartyService.RefreshSnapshot(player)
end

local handlers = {}

function handlers.GetWorld()
	return true, WorldService.Snapshot()
end

function handlers.Inspect(_, _, userId)
	if type(userId) ~= "number" then
		return false, "BadArgs"
	end
	local info = PartyService.GetInspect(userId)
	if not info then
		return false, "NotHere"
	end
	return true, info
end

function handlers.GetLeaderboard(player, _, categoryId)
	if type(categoryId) ~= "string" or not Leaderboards.IsCategory(categoryId) then
		return false, "BadArgs"
	end
	return true, LeaderboardService.Get(categoryId, player.UserId)
end

function handlers.GetState(player)
	return true, buildState(player)
end

function handlers.EquipSkills(player, profile, ids)
	if not isList(ids, Skills.SLOTS) then
		return false, "BadArgs"
	end
	local ok, reason = Economy.Equip(profile, profile.Season.ClassId, ids)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

-- Skills grow by hand: spend XP on a rank, or apply a higher tier that a wish brought (see SkillProgress).
function handlers.RankUpSkill(player, profile, abilityId)
	if type(abilityId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = SkillProgress.RankUp(profile, abilityId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.UpgradeSkill(player, profile, abilityId)
	if type(abilityId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = SkillProgress.Upgrade(profile, abilityId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

-- Pets: spend banked duplicate copies on a rank.
function handlers.RankUpPet(player, profile, petId)
	if type(petId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Pets.RankUp(profile, petId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

-- Wishing Tree: pet and skill wishes (the only way to get most pets; skills are unlocked by wishing or free picks).
function handlers.Wish(player, profile, kind, tierId, method, count)
	if type(kind) ~= "string" or type(tierId) ~= "string" or type(method) ~= "string" or type(count) ~= "number" then
		return false, "BadArgs"
	end
	if not nearShop(player, "Tree") then
		return false, "TooFar"
	end
	local ok, data = Wishing.Wish(profile, kind, tierId, method, count)
	if ok then
		Quests.Record(profile, "Wish", #data.Results)
		afterBuildChange(player)
	end
	return ok, data
end

-- Bosses: the world boss (this server, timed) and the season boss (all servers).
function handlers.BossState(player, profile)
	return true, BossService.GetState(player, profile)
end

-- Only what the client needs to replay a fight as animation.
local REPLAYED = { Damage = true, Heal = true, Cast = true, Death = true, Revive = true, Ultimate = true, End = true, Spawn = true, Telegraph = true, Status = true, StatusEnd = true }
local pushRemote

-- A boss strike is a real fight in YOUR arena: the party's normal fights pause, you (and anyone near) watch it.
local function playBossFight(player, fight, label, damage)
	local partyState = PartyService.GetState(player)
	local slot = partyState and WorldService.SlotOf(partyState.PartyId)
	if not slot then
		return
	end
	local events = {}
	for _, event in ipairs(fight.Events or {}) do
		if REPLAYED[event.Type] then
			table.insert(events, event)
		end
	end
	PartyService.HoldFights(player, fight.Duration + 6)
	local payload = { Slot = slot, PartyId = partyState.PartyId, Stage = partyState.Stage, Won = fight.Won, Duration = fight.Duration, Roster = fight.Roster, Events = events, Label = label, Damage = damage }
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			pushRemote:FireClient(other, "ArenaFight", payload)
		end
	end
	pushRemote:FireClient(player, "BossFight", payload)
end

function handlers.BossStrike(player, profile, which)
	if which ~= "World" and which ~= "Season" then
		return false, "BadArgs"
	end
	local ok, data = BossService.Strike(player, profile, which, PartyService.GetPartnerSnapshot(player))
	if ok then
		local fight = data.Fight
		data.Fight = nil
		if fight then
			playBossFight(player, fight, data.Label, data.Damage)
		end
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.BossClaim(player, profile, thresholdId)
	if type(thresholdId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, data = BossService.Claim(player, profile, thresholdId)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.BossHatch(player, profile)
	local ok, data = BossService.Hatch(player, profile)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.UnlockSkillWithPick(player, profile, abilityId)
	if type(abilityId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Economy.UnlockAbilityWithPick(profile, profile.Season.ClassId, abilityId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.EquipPassives(player, profile, ids)
	if not isList(ids, Passives.SLOTS) then
		return false, "BadArgs"
	end
	local ok, reason = Economy.EquipPassives(profile, profile.Season.ClassId, ids)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.LevelPassiveSlot(player, profile, slotIndex)
	if type(slotIndex) ~= "number" then
		return false, "BadArgs"
	end
	local ok, reason = Economy.LevelPassiveSlot(profile, profile.Season.ClassId, slotIndex)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.EquipPet(player, profile, petId)
	if type(petId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Pets.Equip(profile, petId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.EquipGear(player, profile, itemId, wornSlot)
	if type(itemId) ~= "string" or (wornSlot ~= nil and type(wornSlot) ~= "string") then
		return false, "BadArgs"
	end
	local ok, reason = Gear.Equip(profile, itemId, wornSlot)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.UnequipGear(player, profile, slotName)
	if type(slotName) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Gear.Unequip(profile, slotName)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

-- Selling and upgrading only happen at the Merchant and the Blacksmith in the plaza.
function handlers.SellGear(player, profile, itemId)
	if type(itemId) ~= "string" then
		return false, "BadArgs"
	end
	if not nearShop(player, "Merchant") then
		return false, "TooFar"
	end
	return Gear.Sell(profile, itemId)
end

function handlers.SellBulk(player, profile, mode)
	if type(mode) ~= "string" and not isList(mode, 5) then
		return false, "BadArgs"
	end
	if not nearShop(player, "Merchant") then
		return false, "TooFar"
	end
	local ok, count, gold = Gear.SellBulk(profile, mode)
	if ok then
		afterBuildChange(player)
	end
	return ok, if ok then { Count = count, Gold = gold } else count
end

function handlers.UpgradeBag(player, profile)
	if not nearShop(player, "Merchant") then
		return false, "TooFar"
	end
	local ok, data = Gear.UpgradeBag(profile)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.UpgradeGear(player, profile, itemId)
	if type(itemId) ~= "string" then
		return false, "BadArgs"
	end
	if not nearShop(player, "Blacksmith") then
		return false, "TooFar"
	end
	local ok, result = Gear.Upgrade(profile, itemId)
	if ok then
		afterBuildChange(player)
	end
	return ok, result
end

-- The Stash: use a boost, feed a pet, buy supplies at the Merchant.
function handlers.UseConsumable(player, profile, id, petId, force)
	if type(id) ~= "string" or (petId ~= nil and type(petId) ~= "string") then
		return false, "BadArgs"
	end
	local ok, result = Consumables.Use(profile, id, os.time(), petId, force == true)
	if ok then
		if petId then
			Quests.Record(profile, "Feed", 1)
		end
		afterBuildChange(player)
	end
	return ok, result
end

function handlers.BuyConsumable(player, profile, id, count)
	if type(id) ~= "string" or (count ~= nil and type(count) ~= "number") then
		return false, "BadArgs"
	end
	if not nearShop(player, "Merchant") then
		return false, "TooFar"
	end
	return Consumables.Buy(profile, id, count)
end

-- Studio-only test helper (press F7 in the client): gold, shards and a few of everything.
function handlers.DevGrant(player, profile)
	if not game:GetService("RunService"):IsStudio() then
		return false, "Forbidden"
	end
	profile.Season.Currencies.Gold += 5000
	profile.Season.Currencies.Shards += 600
	profile.Season.Currencies.Wishstones = (profile.Season.Currencies.Wishstones or 0) + 60
	for _, id in ipairs(Consumables.Order) do
		Consumables.Grant(profile, id, if id == "PetWish" or id == "SkillWish" then 12 else 3)
	end
	for i = 1, 12 do
		local t = Gear.Types[(i - 1) % #Gear.Types + 1]
		Gear.Grant(profile, 5 + i * 3, { Slot = t, Rarity = if i % 5 == 0 then "Epic" elseif i % 2 == 0 then "Rare" else "Common" })
	end
	afterBuildChange(player)
	return true
end

function handlers.ClaimDaily(_, profile)
	return Daily.Claim(profile, os.time())
end

-- Daily quests and the season pass
function handlers.ClaimQuest(_, profile, index)
	if type(index) ~= "number" then
		return false, "BadArgs"
	end
	return Quests.ClaimQuest(profile, index, os.time())
end

function handlers.ClaimQuestBonus(_, profile)
	return Quests.ClaimBonus(profile, os.time())
end

function handlers.ClaimWeeklyQuest(_, profile, index)
	if type(index) ~= "number" then
		return false, "BadArgs"
	end
	return Quests.ClaimWeekly(profile, index, os.time())
end

function handlers.ClaimWeeklyBonus(_, profile)
	return Quests.ClaimWeeklyBonus(profile, os.time())
end

function handlers.ClaimPass(_, profile, level, track)
	if level == "All" then
		local claimed = Quests.ClaimAllPass(profile)
		return claimed > 0, if claimed > 0 then claimed else "NothingToClaim"
	end
	if type(level) ~= "number" then
		return false, "BadArgs"
	end
	return Quests.ClaimPass(profile, level, if track == "Premium" then "Premium" else "Free")
end

-- The Premium shop: spend Sunstones on fixed-content items (never wishes or tickets).
function handlers.BuyPremium(player, profile, itemId)
	if type(itemId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, data = Premium.Buy(profile, itemId)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

-- Studio only: Sunstones without paying, so the shop can be tried.
function handlers.DevSunstones(_, profile)
	if not game:GetService("RunService"):IsStudio() then
		return false, "Forbidden"
	end
	Premium.AddSunstones(profile, 1000)
	return true
end

-- Studio only: flips the premium pass track so it can be tried without a purchase.
function handlers.DevPremium(_, profile)
	if not game:GetService("RunService"):IsStudio() then
		return false, "Forbidden"
	end
	local owned = not Quests.Pass(profile).Premium
	Quests.SetPremium(profile, owned)
	return true, owned
end

function handlers.ChooseSubclass(player, profile, subclassId)
	if type(subclassId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Subclasses.Choose(profile, profile.Season.ClassId, subclassId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.Advance(player, _)
	return PartyService.Advance(player)
end

function handlers.SetStage(player, _, stage)
	if type(stage) ~= "number" then
		return false, "BadArgs"
	end
	return PartyService.SetStage(player, stage)
end

function handlers.SetUltimate(player, _, ultimateId)
	if type(ultimateId) ~= "string" then
		return false, "BadArgs"
	end
	return PartyService.SetUltimate(player, ultimateId)
end

function handlers.SetGhostLoadout(player, _, ids)
	if not isList(ids, Skills.SLOTS) then
		return false, "BadArgs"
	end
	local partner = PartyService.GetPartner(player)
	if not partner then
		return false, "NoPartner"
	end
	return PartyService.SetGhostLoadout(player, partner.UserId, ids)
end

function handlers.RevertMyGhost(player)
	return PartyService.RevertGhostLoadout(player)
end

function handlers.CreateCode(player)
	return PartyService.CreateCode(player)
end

function handlers.JoinByCode(player, _, code)
	if type(code) ~= "string" or #code > 12 then
		return false, "BadArgs"
	end
	return PartyService.JoinByCode(player, code)
end

function handlers.Leave(player)
	return PartyService.Leave(player)
end

local PROFILE_FREE = { GetState = true, GetWorld = true, Inspect = true, GetLeaderboard = true, CreateCode = true, JoinByCode = true, Leave = true, RevertMyGhost = true }

-- Tells a client its Sunstones changed (a Robux purchase just went through) so it refreshes its screen.
function ApiService.PushState(player)
	if pushRemote then
		pushRemote:FireClient(player, "Purchase", {})
	end
end

function ApiService.Init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	folder.Parent = ReplicatedStorage

	local api = Instance.new("RemoteFunction")
	api.Name = Remotes.Api
	api.Parent = folder

	local push = Instance.new("RemoteEvent")
	push.Name = Remotes.Push
	push.Parent = folder

	WorldService.Init(push)
	BossService.Init(push, DataService.GetProfile)

	api.OnServerInvoke = function(player, action, ...)
		local now = os.clock()
		-- cheap read-only calls are not throttled, so a refresh right after an action is never refused
		local readOnly = action == "GetState" or action == "BossState" or action == "GetWorld"
		if not readOnly then
			if lastCall[player.UserId] and now - lastCall[player.UserId] < MIN_INTERVAL then
				return false, "TooFast"
			end
			lastCall[player.UserId] = now
		end

		local handler = type(action) == "string" and handlers[action] or nil
		if handler == nil then
			return false, "UnknownAction"
		end
		if action == "GetState" or action == "GetWorld" or action == "Inspect" or action == "GetLeaderboard" then
			return handler(player, nil, ...)
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return false, "NoProfile"
		end
		local ok, result, extra = pcall(handler, player, profile, ...)
		if not ok then
			warn("[ApiService] " .. tostring(action) .. " failed: " .. tostring(result))
			return false, "ServerError"
		end
		return result, extra
	end

	pushRemote = push
	local function replayEvents(outcome)
		local events = {}
		for _, event in ipairs(outcome.Events or {}) do
			if REPLAYED[event.Type] then
				table.insert(events, event)
			end
		end
		return events
	end

	PartyService.SetFightListener(function(record, outcome, onlineList, waitSeconds)
		local events = replayEvents(outcome)
		-- everyone else on the server sees the fight in its arena
		local isMember = {}
		for _, member in ipairs(onlineList) do
			isMember[member.UserId] = true
		end
		local slot = WorldService.SlotOf(record.PartyId)
		local arena = { Slot = slot, PartyId = record.PartyId, Stage = outcome.Stage, Won = outcome.Won, Duration = outcome.Duration, Roster = outcome.Roster, Events = events }
		for _, other in ipairs(Players:GetPlayers()) do
			if not isMember[other.UserId] then
				push:FireClient(other, "ArenaFight", arena)
			end
		end

		for _, member in ipairs(onlineList) do
			local player = Players:GetPlayerByUserId(member.UserId)
			if player then
				local reward = outcome.Rewards and outcome.Rewards[tostring(member.UserId)]
				push:FireClient(player, "Fight", {
					Slot = slot,
					Stage = outcome.Stage,
					Won = outcome.Won,
					TimedOut = outcome.TimedOut,
					Duration = outcome.Duration,
					NextStage = outcome.NextStage,
					Wait = waitSeconds,
					Roster = outcome.Roster,
					Events = events,
					Reward = reward and { Gold = reward.Gold, XP = reward.XP, Shards = reward.Shards, Wishstones = reward.Wishstones, Item = reward.Item and Gear.Name(reward.Item) or nil, Pets = reward.PetsGained } or nil,
				})
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCall[player.UserId] = nil
	end)
end

return ApiService
