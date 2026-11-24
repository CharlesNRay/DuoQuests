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
	  GetSeasonRewards()                brackets, your live standing, and finished seasons' rewards waiting to be claimed
	  ClaimSeasonRewards(seasonId)      collect a finished season's reward (once)
	  ChooseClass(classId)   the class picker (once); starts auto-combat. Older: CreateCharacter(name, classId, look, useAvatar) / UpdateCharacter(look, useAvatar) / RenameCharacter(name)   the character creator (once; look free; rename costs Sunstones)
	  RedeemCode(text)   -> ok, { Success, Reason?, Lines? }   (wrong tries are limited: 5 a minute, then a short lock)
	  BuyCosmetic(id) / BuyCosmeticBundle(bundleId) / EquipCosmetic(slot, id|nil)   auras, kill effects, name colours, titles (Sunstones)
	  Inspect(userId)                   public card of a party member on this server
	  ChooseSubclass(subclassId)        pick a subclass path (once per season)
	  EquipGear(itemId, wornSlot?) / EquipBestGear() (highest Item Power of every type) / UnequipGear(slot) / SellGear(itemId)   equipment (8 worn slots)
	  UseConsumable(id, petId?) / BuyConsumable(id, count)   the Stash: boosts, pet food, Merchant supplies
	  ClaimDaily()                      today's login reward
	  ClaimQuest(index) / ClaimQuestBonus() / ClaimWeeklyQuest(index) / ClaimWeeklyBonus() / BuyPremium(itemId) / ClaimPass(level|"All")   daily quests and the season pass
	  EquipPet(petId)  the companion that follows you and its bonus
	  BuyPetWithShards(petId) / CondensePetShards(rarity|"All")   pet shards (duplicates past max rank)
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
local PetGear = require(Shared.PetGear)
local Passives = require(Shared.Passives)
local Progression = require(Shared.Progression)
local Skills = require(Shared.Skills)
local SkillProgress = require(Shared.SkillProgress)
local Party = require(Shared.Party)
local Pets = require(Shared.Pets)
local Power = require(Shared.Power)
local Gear = require(Shared.Gear)
local Consumables = require(Shared.Consumables)
local Gifts = require(Shared.Gifts)
local Runes = require(Shared.Runes)
local RunesConfig = require(Shared.Config.Runes)
local Wishing = require(Shared.Wishing)
local BossService = require(script.Parent.BossService)
local GuildService = require(script.Parent.GuildService)
local Hero = require(Shared.Hero)
local World = require(Shared.World)
local Daily = require(Shared.Daily)
local Quests = require(Shared.Quests)
local Premium = require(Shared.Premium)
local Passes = require(Shared.Passes)
local StageRewards = require(Shared.StageRewards)
local Subclasses = require(Shared.Subclasses)
local Abilities = require(Shared.Config.Abilities)

local DataService = require(script.Parent.DataService)
local PlaytestService = require(script.Parent.PlaytestService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Leaderboards = require(Shared.Leaderboards)
local SeasonRewards = require(Shared.SeasonRewards)
local Cosmetics = require(Shared.Cosmetics)
local Codes = require(Shared.Codes)
local Classes = require(Shared.Config.Classes)
local Character = require(Shared.Character)
local Characters = require(Shared.Characters)
local Tutorial = require(Shared.Tutorial)
local Activities = require(Shared.Activities)
local Errands = require(Shared.Errands)
local Talents = require(Shared.Talents)
local Fishing = require(Shared.Fishing)
local TrainingDummy = require(Shared.TrainingDummy)
local TownLeisure = require(Shared.TownLeisure)
local Sparring = require(Shared.Sparring)
local Market = require(Shared.Market)
local WeaponService = require(script.Parent.WeaponService)
local CharacterConfig = require(Shared.Config.Character)
local TextService = game:GetService("TextService")
local CodeList = require(script.Parent.Parent.Data.CodeList) -- server only: clients never see the list
local CosmeticConfig = require(Shared.Config.Cosmetics)
local SeasonRewardConfig = require(Shared.Config.SeasonRewards)
local SeasonConfig = require(Shared.Config.Seasons)
local SeasonResultsService = require(script.Parent.SeasonResultsService)

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
		ExtraMods = (function()
			local mods = table.clone(Pets.Collection(profile).Mods)
			for _, mod in ipairs(Talents.Mods(profile)) do
				table.insert(mods, mod)
			end
			return mods
		end)(),
	})
end

local cosmeticsOf -- defined below
local characterOf -- defined below

-- Who you can gift to (2026-11-22): real players online on this server who share your party or your guild.
local function giftTargets(player, profile)
	local out, seen = {}, {}
	for _, mate in ipairs(PartyService.GetTeammates(player)) do
		local other = (not mate.IsCompanion) and Players:GetPlayerByUserId(mate.UserId)
		if other and DataService.GetProfile(other) then
			seen[other.UserId] = true
			table.insert(out, { UserId = other.UserId, Name = mate.Name, Via = "Party" })
		end
	end
	local myGuild = profile.Permanent.Guild and profile.Permanent.Guild.Id
	if myGuild then
		for _, other in ipairs(Players:GetPlayers()) do
			local theirs = other ~= player and not seen[other.UserId] and DataService.GetProfile(other)
			if theirs and theirs.Permanent.Guild and theirs.Permanent.Guild.Id == myGuild then
				table.insert(out, { UserId = other.UserId, Name = other.DisplayName, Via = "Guild" })
			end
		end
	end
	return out
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
			Name = Character.DisplayName(profile, player.Name),
			ClassId = classId,
			Level = season.Level,
			XP = season.XP,
			XPNeeded = Progression.XPToNext(season.Level),
			Paragon = season.Paragon and season.Paragon.Level or 0,
			ParagonXP = season.Paragon and season.Paragon.XP or 0,
			ParagonNeed = Progression.ParagonXPToNext(season.Paragon and season.Paragon.Level or 0),
			Gold = season.Currencies.Gold,
			Shards = season.Currencies.Shards,
			Wishstones = season.Currencies.Wishstones or 0,
			SkillPicks = season.Currencies.SkillPicks,
			Frontier = season.HighestStage,
			Runes = Runes.List(profile),
			RunePouch = RunesConfig.Pouch.Gold,
			Loadout = table.clone(season.Loadouts[classId]),
			SlotLevels = SkillProgress.SlotLevelsFor(season, season.Loadouts[classId], classId),
			PetGear = PetGear.View(profile, os.time()),
			SlotBase = table.clone(season.SlotLevels[classId] or {}),
			SkillInfo = SkillProgress.Info(season),
			SkillReady = SkillProgress.AnyReady(season),
			Owned = table.clone(season.OwnedAbilities),
			PassiveIds = table.clone(season.PassiveLoadouts[classId]),
			PassiveLevels = table.clone(season.PassiveSlotLevels[classId]),
			PassiveSlots = Passives.SlotsAt(season.HighestStage),
			Pets = Pets.List(profile),
			IP = Power.Hero(profile),
			Tutorial = Tutorial.Of(profile),
			Activities = Activities.Of(profile, os.time()),
			Market = Market.Of(profile, os.time(), SeasonConfig.CurrentSeasonId),
			PetShards = Pets.Shards(profile),
			PetShardInfo = { PetCost = require(Shared.Config.Pets).Shards.PetCost, CondenseCost = require(Shared.Config.Pets).Shards.CondenseCost },
			PetCollection = (function() local c = Pets.Collection(profile) return { Points = c.Points, Percent = c.Percent } end)(),
			PetFoodOverflow = math.floor(profile.Permanent.PetFoodOverflow or 0), -- pet shard bar filled by food fed to capped pets
			GiftTargets = giftTargets(player, profile),
			GiftsLeft = Gifts.Left(profile, os.time()),
			Giftable = Gifts.Giftable,
			Wishing = { Pet = Wishing.Info(profile, "Pet"), Skill = Wishing.Info(profile, "Skill") },
			ActivePet = (Pets.Active(profile)),
			SecondPet = (Pets.Second(profile)), -- VIP second pet slot (nil when empty or not VIP)
			HasSecondPetSlot = Pets.HasSecondSlot(profile),
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
			Passes = Passes.List(profile),
			StageClaims = StageRewards.ClaimedList(profile), -- a list of stage numbers
			Perks = Passes.Perks(profile),
			PremiumOffer = Premium.Offer(profile),
			SunstonePacks = Premium.Packs(profile),
			Cosmetics = cosmeticsOf(profile),
			Character = characterOf(profile),
			Errands = Errands.Status(profile, os.time()), -- town errands (docs/TOWN.md phase 2)
			Settings = profile.Permanent.Settings, -- sound sliders (client/Sound), nil = defaults
			CanReadLog = PlaytestService.CanRead(player), -- the Feedback screen shows the playtest log (Studio / the place's creator)
			Talents = Talents.Status(profile), -- level-up points (Shared/Talents)
			Fishing = Fishing.Status(profile, Daily.DayNumber(os.time())), -- the fishing pond (catches left today, fish log)
			DummyBest = profile.Season.DummyBest or 0, -- best party DPS on the training dummy
			Relics = TownLeisure.Relics(profile), -- hidden relics found this season
			PetPlayed = TownLeisure.PetPlayed(profile, Daily.DayNumber(os.time())), -- the pet park today
			Sparring = Sparring.Stats(profile), -- duels won and lost in the sparring ring
		},
	}

	local party = PartyService.GetState(player)
	if party then
		party.Teammates = PartyService.GetTeammates(player)
		party.Partner = party.Teammates[1]
		party.Ultimate = PartyService.GetUltimateInfo(player)
		party.MyGhostEdits = PartyService.GetMyGhostHistory(player)
		state.Party = party
	end
	state.LastClaim = PartyService.GetLastClaim(player)
	return state
end

-- The cosmetics screen's data: what is worn, and the list for each slot.
function cosmeticsOf(profile)
	local lists = {}
	for _, slot in ipairs(CosmeticConfig.Slots) do
		lists[slot] = Cosmetics.List(profile, slot)
	end
	return { Equipped = Cosmetics.Equipped(profile), Lists = lists, Slots = CosmeticConfig.Slots, Labels = CosmeticConfig.SlotLabels, Bundles = Cosmetics.Bundles(profile) }
end

-- Everyone's looks are shown from attributes on the player (the client draws the aura, name colour and title from them).
-- Character creator state for the client: what is saved plus every option (the lists are in Config/Character).
function characterOf(profile)
	local c = Character.Get(profile)
	local classes = {}
	for _, classId in ipairs({ "Warrior", "Cleric", "Mage", "Ranger", "Rogue", "Summoner" }) do
		local def = Classes[classId]
		if def then
			local paths = {}
			for _, sub in ipairs(Subclasses.Choices(classId, nil)) do
				table.insert(paths, { Id = sub.Id, Name = sub.DisplayName, Text = sub.Description })
			end
			table.insert(classes, {
				Paths = paths,
				Id = classId, Name = def.DisplayName or classId, Role = def.Role, Blurb = def.Blurb, WeaponName = def.Weapon and def.Weapon.Name, WeaponText = def.Weapon and def.Weapon.Text,
				Playable = Character.Playable(profile, classId),
			})
		end
	end
	return {
		Created = c.Created, Name = c.Name, Look = c.Look, UseAvatar = c.UseAvatar, Renames = c.Renames,
		RenameCost = CharacterConfig.RenameCost, Classes = classes,
		MaxCharacters = Characters.Max(profile), SlotPass = { Owned = Passes.Has(profile, "CharacterSlots"), Robux = require(Shared.Config.Premium).Passes.CharacterSlots.Robux, Extra = require(Shared.Config.Premium).Passes.CharacterSlots.Perks.CharacterSlots }, Characters = Characters.List(profile), Active = Characters.Active(profile), InGame = Characters.Entered(profile),
		NameMin = CharacterConfig.Name.Min, NameMax = CharacterConfig.Name.Max,
		Skins = CharacterConfig.Skins, Hairs = CharacterConfig.HairColors, Outfits = CharacterConfig.Outfits,
	}
end

function ApiService.ApplyLook(player, profile)
	local look = Cosmetics.Look(profile)
	player:SetAttribute("CosAura", look.Aura)
	player:SetAttribute("CosKill", look.Kill)
	player:SetAttribute("CosName", look.Name)
	player:SetAttribute("CosTitle", look.Title)
	-- the character creator's look: the fight scene draws heroes from these (the plaza avatar is the player's own)
	local c = Character.Get(profile)
	if c.Created then
		local colors = Character.Colors(profile)
		player:SetAttribute("CharName", Character.DisplayName(profile, player.DisplayName))
		player:SetAttribute("CharAvatar", c.UseAvatar)
		player:SetAttribute("CharSkin", Color3.fromRGB(table.unpack(colors.Skin)))
		player:SetAttribute("CharHair", Color3.fromRGB(table.unpack(colors.Hair)))
		player:SetAttribute("CharOutfit", Color3.fromRGB(table.unpack(colors.Outfit)))
		task.spawn(WeaponService.Give, player, profile.Season.ClassId) -- the class weapon on their Roblox character
	end
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

function handlers.ConsumeSkillCopies(player, profile, abilityId, rarity)
	if type(abilityId) ~= "string" or (rarity ~= nil and type(rarity) ~= "string") then
		return false, "BadArgs"
	end
	local ok, reason = SkillProgress.Consume(profile, abilityId, rarity or "All")
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

-- Guilds (shared across servers, see GuildService)
local playBossFight -- defined below with the boss handlers; the guild raid uses it too
local function guildCall(player, fn, ...)
	local ok, data = fn(...)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end
function handlers.GuildState(player, profile) return GuildService.State(player, profile) end
function handlers.GuildSearch(player, profile, query) return GuildService.Search(player, profile, query) end
function handlers.GuildCreate(player, profile, name, tag, open) return guildCall(player, GuildService.Create, player, profile, name, tag, open) end
function handlers.GuildJoin(player, profile, id) return guildCall(player, GuildService.Join, player, profile, id) end
function handlers.GuildLeave(player, profile) return guildCall(player, GuildService.Leave, player, profile) end
function handlers.GuildKick(player, profile, userId) return GuildService.Kick(player, profile, userId) end
function handlers.GuildRank(player, profile, userId, rank) return GuildService.SetRank(player, profile, userId, rank) end
function handlers.GuildTransfer(player, profile, userId) return GuildService.Transfer(player, profile, userId) end
function handlers.GuildApprove(player, profile, userId, accept) return GuildService.Approve(player, profile, userId, accept) end
function handlers.GuildInfo(player, profile, fields) return GuildService.SetInfo(player, profile, fields) end
function handlers.GuildChat(player, profile, text) return GuildService.Chat(player, profile, text) end
function handlers.GuildBuy(player, profile, upgradeId) return guildCall(player, GuildService.Buy, player, profile, upgradeId) end
function handlers.GuildClaimMission(player, profile, kind, index) return GuildService.ClaimMission(player, profile, kind, index) end
function handlers.GuildRaid(player, profile)
	return GuildService.RaidChallenge(player, profile, PartyService.GetTeamSnapshots(player), function(fight, label, damage)
		playBossFight(player, fight, label, damage, nil, "GuildRaid")
	end)
end
function handlers.GuildRaidClaim(player, profile, which) return GuildService.RaidClaim(player, profile, which) end
function handlers.GuildWish(player, profile, count) return guildCall(player, GuildService.Wish, player, profile, count) end

-- Bosses: the world boss (this server, timed) and the season boss (all servers).
function handlers.BossState(player, profile)
	return true, BossService.GetState(player, profile)
end

-- Only what the client needs to replay a fight as animation.
local REPLAYED = { Damage = true, Heal = true, Cast = true, Death = true, Revive = true, Ultimate = true, End = true, Spawn = true, Telegraph = true, Status = true, StatusEnd = true, Wave = true }
local pushRemote

-- A boss challenge is a real fight in YOUR arena: the party's normal fights pause, you (and anyone near) watch it.
function playBossFight(player, fight, label, damage, extraInfo, kind)
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
	PartyService.HoldFights(player, fight.Duration + 14)
	local payload = { Slot = slot, PartyId = partyState.PartyId, Stage = partyState.Stage, Won = fight.Won, Duration = fight.Duration, Roster = fight.Roster, Events = events, Label = label, Damage = damage, Extra = extraInfo, Kind = kind } -- Kind picks the music
	-- the fight is played in a private boss arena on the challenger's screen, so nobody else watches it
	pushRemote:FireClient(player, "BossFight", payload)
end

function handlers.BossChallenge(player, profile, which)
	if which ~= "World" and which ~= "Season" then
		return false, "BadArgs"
	end
	local ok, data = BossService.Challenge(player, profile, which, PartyService.GetTeamSnapshots(player))
	if ok then
		local fight = data.Fight
		data.Fight = nil
		if fight then
			playBossFight(player, fight, data.Label, data.Damage, nil, if which == "World" then "WorldBoss" else "SeasonBoss")
		end
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.MarketBuy(player, profile, id)
	if type(id) ~= "string" then
		return false, "BadArgs"
	end
	local ok, lines = Market.Buy(profile, id, os.time(), SeasonConfig.CurrentSeasonId)
	if ok then
		afterBuildChange(player)
	end
	return ok, lines
end

-- Dungeons and expeditions (see Shared/Activities). A dungeon run plays its last floor in the boss arena.
function handlers.DungeonRun(player, profile, id)
	if type(id) ~= "string" then
		return false, "BadArgs"
	end
	local members = { { Id = tostring(player.UserId), Name = player.Name, Profile = profile } }
	for _, mate in ipairs(PartyService.GetTeamSnapshots(player)) do
		table.insert(members, { Id = mate.Id, Name = mate.Name, Snapshot = mate.Snapshot })
	end
	local ok, result = Activities.RunDungeon(profile, members, id, math.random(1, 1e9), os.time(), true)
	if ok then
		local fight = result.Fight
		result.Fight = nil
		if fight then
			playBossFight(player, fight, result.Name, 0, { Floors = result.Floors, Cleared = result.Cleared, Lines = result.Lines }, "Dungeon")
		end
		afterBuildChange(player)
	end
	return ok, result
end

function handlers.ExpeditionStart(_, profile, id)
	return Activities.StartExpedition(profile, id, os.time())
end

function handlers.ExpeditionCollect(player, profile)
	local ok, lines = Activities.CollectExpedition(profile, os.time())
	if ok then
		afterBuildChange(player)
	end
	return ok, lines
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

-- Pet shards: buy a pet (or a copy of one) of a rarity, and condense shards into the next rarity.
function handlers.BuyPetWithShards(player, profile, petId)
	if type(petId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Pets.BuyWithShards(profile, petId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.CondensePetShards(_, profile, rarity)
	if type(rarity) ~= "string" then
		return false, "BadArgs"
	end
	return Pets.Condense(profile, rarity)
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

-- VIP second pet slot (petId "" empties it)
function handlers.EquipSecondPet(player, profile, petId)
	if type(petId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, reason = Pets.EquipSecond(profile, petId)
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

function handlers.EquipBestGear(player, profile)
	local ok, changed = Gear.EquipBest(profile)
	if ok and changed > 0 then
		afterBuildChange(player)
	end
	return ok, changed
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

-- Selling and upgrading only happen at the Merchant, the Blacksmith and the Skill Trainer in the plaza.
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

-- Pet gear: wearing it works anywhere; buying it only at the Pet Store in the plaza
function handlers.EquipPetGear(player, profile, pieceId)
	local ok, reason = PetGear.Equip(profile, pieceId)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.UnequipPetGear(player, profile, slot)
	local ok, reason = PetGear.Unequip(profile, slot)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.SellPetGear(player, profile, pieceId)
	local ok, gold = PetGear.Sell(profile, pieceId)
	return ok, gold
end

function handlers.BuyPetGearCrate(player, profile, crateId)
	if type(crateId) ~= "string" then
		return false, "BadArgs"
	end
	if not nearShop(player, "PetStore") then
		return false, "TooFar"
	end
	return PetGear.BuyCrate(profile, crateId)
end

function handlers.BuyPetEgg(player, profile)
	if not nearShop(player, "PetStore") then
		return false, "TooFar"
	end
	return PetGear.BuyEgg(profile, os.time())
end

-- The Skill Trainer levels a skill SLOT (the level stays with the slot when you swap the skill in it)
function handlers.LevelSlot(player, profile, slotIndex)
	if type(slotIndex) ~= "number" then
		return false, "BadArgs"
	end
	if not nearShop(player, "Trainer") then
		return false, "TooFar"
	end
	local ok, reason = Economy.LevelSlot(profile, profile.Season.ClassId, slotIndex)
	if ok then
		afterBuildChange(player)
	end
	return ok, reason
end

-- Runes: carve one onto a gear piece (anywhere, from the Bag); buy a random one at the Blacksmith.
function handlers.CarveRune(player, profile, itemId, key, confirm)
	if type(itemId) ~= "string" or type(key) ~= "string" then
		return false, "BadArgs"
	end
	if not nearShop(player, "RuneCarver") then
		return false, "TooFar"
	end
	local ok, data = Runes.Carve(profile, itemId, key, confirm == true)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.BuyRunePouch(player, profile)
	if not nearShop(player, "RuneCarver") then
		return false, "TooFar"
	end
	return Runes.BuyPouch(profile)
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

function handlers.Gift(player, profile, targetUserId, itemId, count)
	if type(targetUserId) ~= "number" or type(itemId) ~= "string" then
		return false, "BadArgs"
	end
	local allowed = false
	for _, t in ipairs(giftTargets(player, profile)) do
		if t.UserId == targetUserId then allowed = true end
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local targetProfile = target and DataService.GetProfile(target)
	if not allowed or not targetProfile then
		return false, "NotReachable" -- must be online here and in your party or guild
	end
	local ok, result = Gifts.Give(profile, targetProfile, itemId, count, os.time())
	if ok and pushRemote then
		local def = Consumables.Defs[itemId]
		pushRemote:FireClient(target, "Gift", { From = player.DisplayName, Item = def and def.DisplayName or itemId, Glyph = def and def.Glyph or "🎁", Count = count })
	end
	return ok, result
end

function handlers.BuyConsumable(player, profile, id, count)
	if type(id) ~= "string" or (count ~= nil and type(count) ~= "number") then
		return false, "BadArgs"
	end
	local isPetFood = Consumables.Defs[id] ~= nil and Consumables.Defs[id].Kind == "PetFood"
	if not nearShop(player, "Merchant") and not (isPetFood and nearShop(player, "PetStore")) then
		return false, "TooFar"
	end
	return Consumables.Buy(profile, id, count)
end

-- Studio-only cheat panel (HUD 🧪 "Test"): every test shortcut goes through here.
local DEV_ACTIONS = {}
function DEV_ACTIONS.Gold(profile, n)
	profile.Season.Currencies.Gold += 50000000 * n
	return ("+%dM gold"):format(50 * n)
end
function DEV_ACTIONS.Items(profile)
	local c = profile.Season.Currencies
	c.Shards += 6000
	c.Wishstones = (c.Wishstones or 0) + 60
	for _, id in ipairs(Consumables.Order) do
		Consumables.Grant(profile, id, if id == "PetWish" or id == "SkillWish" then 12 else 3)
	end
	for i = 1, 12 do
		local t = Gear.Types[(i - 1) % #Gear.Types + 1]
		Gear.Grant(profile, math.max(5, profile.Season.HighestStage) + i, { Slot = t, Rarity = if i % 5 == 0 then "Epic" elseif i % 2 == 0 then "Rare" else "Common" })
	end
	return "Shards, wishes, boosts and 12 gear"
end
function DEV_ACTIONS.StageGear(profile)
	-- an Epic piece of every type at the current frontier (two rings), then wear the best
	local stage = profile.Season.HighestStage
	for _, t in ipairs(Gear.Types) do
		for _ = 1, if t == "Ring" then 2 else 1 do
			Gear.Grant(profile, stage, { Slot = t, Rarity = "Epic", Roll = 1 })
		end
	end
	local _, changed = Gear.EquipBest(profile)
	return ("Epic stage %d gear, %d pieces worn"):format(stage, changed or 0)
end
function DEV_ACTIONS.Level(profile, n)
	for _ = 1, n do
		Progression.AddXP(profile.Season, Progression.XPToNext(profile.Season.Level))
	end
	return "Level " .. profile.Season.Level
end
function DEV_ACTIONS.Stage(profile, n, player)
	-- clears each stage like a real win (rewards, XP, frontier quests), then moves the party there
	local season = profile.Season
	local target = season.HighestStage + n
	while season.HighestStage < target do
		Progression.ApplyClear(profile, season.HighestStage)
	end
	PartyService.DevSetFrontier(player, season.HighestStage)
	return ("Stage %d, level %d"):format(season.HighestStage, season.Level)
end
function DEV_ACTIONS.Pets(profile)
	local PetConfig = require(Shared.Config.Pets)
	profile.Permanent.Pets = profile.Permanent.Pets or {}
	local acc = Pets.Account(profile)
	for _, petId in ipairs(PetConfig.Order) do
		profile.Permanent.Pets[petId] = true
		acc.PetLevels[petId] = PetConfig.MaxLevel -- shown capped at the hero's level
	end
	return "All pets, max level (capped at your level)"
end
function DEV_ACTIONS.Daily(profile)
	local a = profile.Permanent.Activities
	if type(a) == "table" then
		a.Day = 0 -- refills dungeon keys and daily bonuses on the next read
		if a.Expedition then
			a.Expedition.EndsAt = 0
		end
	end
	profile.Season.Gifts = nil
	if profile.Season.Errands then
		profile.Season.Errands.Day = -1 -- town errands come back on the next read
	end
	return "Dungeon keys, daily bonuses, town errands and gift limits reset; expedition ready"
end
function DEV_ACTIONS.WorldBoss()
	local ok, reason = BossService.DevStartWorld()
	return if ok then "World boss is up" else nil, reason
end
function DEV_ACTIONS.Wishes(profile, n)
	-- Wishstones (every wish costs 3-8) plus Skill and Pet Wish tickets
	local c = profile.Season.Currencies
	c.Wishstones = (c.Wishstones or 0) + 500 * n
	Consumables.Grant(profile, "SkillWish", 25 * n)
	Consumables.Grant(profile, "PetWish", 25 * n)
	return ("+%d Wishstones, +%d Skill and Pet Wish tickets"):format(500 * n, 25 * n)
end
function DEV_ACTIONS.Sunstones(profile)
	Premium.AddSunstones(profile, 1000)
	return "+1,000 Sunstones"
end
function DEV_ACTIONS.SlotPass(profile)
	local owned = profile.Permanent.Passes or {}
	profile.Permanent.Passes = owned
	owned.CharacterSlots = if owned.CharacterSlots then nil else true
	return if owned.CharacterSlots then "Extra Character Slots pass on (4 slots)" else "Extra Character Slots pass off (2 slots)"
end
function DEV_ACTIONS.Premium(profile)
	local owned = not Quests.Pass(profile).Premium
	Quests.SetPremium(profile, owned)
	return if owned then "Premium pass on" else "Premium pass off"
end

-- the playtest log (Services/PlaytestService): tester feedback, client errors, and the owner's reader
function handlers.SendFeedback(player, profile, topic, text, where)
	return PlaytestService.Feedback(player, profile, topic, text, where)
end
function handlers.ReportError(player, profile, text, where)
	return PlaytestService.ClientError(player, profile, text, where)
end
function handlers.PlaytestRead(player, _, days)
	if not PlaytestService.CanRead(player) then
		return false, "Forbidden"
	end
	return true, PlaytestService.Read(days)
end

function handlers.Dev(player, profile, action, n)
	if not game:GetService("RunService"):IsStudio() then
		return false, "Forbidden"
	end
	local fn = type(action) == "string" and DEV_ACTIONS[action]
	if not fn then
		return false, "BadArgs"
	end
	n = if type(n) == "number" then math.clamp(math.floor(n), 1, 100) else 1
	local text, reason = fn(profile, n, player)
	if text == nil then
		return false, reason
	end
	afterBuildChange(player)
	return true, text
end

-- the guided first session: the client moves through the steps, the server keeps the place and pays once
function handlers.TutorialAdvance(_, profile, step)
	return Tutorial.Advance(profile, step)
end

function handlers.TutorialSkip(_, profile)
	return Tutorial.Skip(profile)
end

function handlers.TutorialFinish(_, profile)
	return Tutorial.Finish(profile)
end

function handlers.TutorialComplete(_, profile, step)
	return Tutorial.Complete(profile, step)
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

-- Game Pass (VIP): opens Roblox's purchase prompt. Ownership is granted by PremiumService when the purchase finishes.
function handlers.BuyPass(player, _, passId)
	if type(passId) ~= "string" then
		return false, "BadArgs"
	end
	local def = require(Shared.Config.Premium).Passes[passId]
	if not def then
		return false, "BadPass"
	end
	if def.GamePassId == 0 then
		return false, "NotAvailable" -- the pass does not exist in the creator dashboard yet
	end
	game:GetService("MarketplaceService"):PromptGamePassPurchase(player, def.GamePassId)
	return true
end

-- The player closed a pop-up offer (the Subclass Pack): from now on it is listed in the shop.
function handlers.DismissPremiumOffer(_, profile, itemId)
	if type(itemId) ~= "string" then
		return false, "BadArgs"
	end
	return Premium.DismissOffer(profile, itemId)
end

-- End-of-season rewards. Live standing is cached for a minute (it reads the shared boards).
local liveCache = nil
local function liveResults()
	if liveCache == nil or os.clock() - liveCache.At > 60 then
		local results = SeasonResultsService.Live()
		if results then
			liveCache = { At = os.clock(), Results = results }
		end
	end
	return liveCache and liveCache.Results or nil
end

local function describe(standing)
	return {
		Ranked = standing.Ranked, Score = standing.Score, Percent = standing.Percent, Rank = standing.Rank,
		ClassRank = standing.ClassRank, ClassId = standing.ClassId,
		Percentile = standing.Percentile and standing.Percentile.Label or nil,
		RankLabel = standing.RankReward and standing.RankReward.Label or nil,
	}
end

function handlers.GetSeasonRewards(player, profile)
	local out = { Brackets = SeasonRewards.Brackets(), MinStage = SeasonRewardConfig.MinStage, Pending = {} }
	local seasonId = SeasonConfig.CurrentSeasonId
	local season = SeasonConfig.Seasons[seasonId]
	out.Season = { Id = seasonId, Name = season and season.Name or "", EndsAt = season and season.EndsAt or 0 }
	local score = math.max(0, math.floor(profile.Season.HighestStage))
	local results = liveResults()
	if results then
		local standing = SeasonRewards.Standing(results, { UserId = player.UserId, Score = score, ClassId = profile.Season.ClassId })
		out.Live = describe(standing)
		out.Live.Projected = SeasonRewards.Reward(standing).Sunstones
		out.Live.Players = results.Total
	else
		out.Live = { Ranked = false, Score = score }
	end
	for id, def in pairs(SeasonConfig.Seasons) do
		if SeasonResultsService.Ended(id) and not SeasonRewards.Claimed(profile, id) then
			local final = SeasonResultsService.Results(id)
			if final then
				local info = SeasonResultsService.InfoFor(player.UserId, id, final, profile)
				local standing = SeasonRewards.Standing(final, info)
				if standing.Ranked then
					local reward = SeasonRewards.Reward(standing)
					table.insert(out.Pending, { SeasonId = id, Name = def.Name, Standing = describe(standing), Reward = reward })
				end
			end
		end
	end
	table.sort(out.Pending, function(a, b)
		return a.SeasonId < b.SeasonId
	end)
	return true, out
end

function handlers.ClaimSeasonRewards(player, profile, seasonId)
	if type(seasonId) ~= "number" or SeasonConfig.Seasons[seasonId] == nil then
		return false, "BadArgs"
	end
	if not SeasonResultsService.Ended(seasonId) then
		return false, "NotOver"
	end
	local final = SeasonResultsService.Results(seasonId)
	if not final then
		return false, "Unavailable"
	end
	local info = SeasonResultsService.InfoFor(player.UserId, seasonId, final, profile)
	local ok, reward = SeasonRewards.Claim(profile, seasonId, final, info)
	if ok then
		ApiService.ApplyLook(player, profile) -- new titles may be worn straight away
	end
	return ok, reward
end

local codeTries = {} -- [userId] = { Wrong = n, Since = t, LockedUntil = t }

-- Roblox's text filter: a name it would hide (#####) is refused. Studio has no filter access, so it passes there.
local function filterOk(player, text)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return true
	end
	return result == text
end

-- Main menu: make a character (just a class choice, up to Characters.Max(profile)). It does not start playing it.
function handlers.MakeCharacter(player, profile, classId)
	if type(classId) ~= "string" then
		return false, "BadArgs"
	end
	local ok, result = Characters.Create(profile, classId)
	if not ok then
		return false, result
	end
	return true, result
end

-- Main menu: play a character. The first time this session it spawns the player's avatar and joins their party;
-- switching later re-joins the party as the other character (only when nobody else is online in it).
function handlers.PlayCharacter(player, profile, slot)
	if type(slot) ~= "number" then
		return false, "BadArgs"
	end
	local wasIn = Characters.Entered(profile)
	local before = Characters.Active(profile)
	if wasIn and before ~= slot and PartyService.OnlineCount(player) > 1 then
		return false, "LeavePartyFirst"
	end
	local ok, reason = Characters.Select(profile, slot)
	if not ok then
		return false, reason
	end
	Characters.Enter(profile)
	if not wasIn then
		PartyService.OnPlayerReady(player, profile)
	elseif before ~= slot then
		PartyService.OnPlayerLeaving(player)
		PartyService.OnPlayerReady(player, profile)
	end
	ApiService.ApplyLook(player, profile)
	if player.Character == nil then
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
			ApiService.ApplyLook(player, profile) -- the weapon needs the new avatar
		end)
	end
	afterBuildChange(player)
	return true
end

-- Older clients: choosing a class makes a character and plays it.
function handlers.ChooseClass(player, profile, classId)
	local ok, slot = handlers.MakeCharacter(player, profile, classId)
	if not ok then
		return false, slot
	end
	return handlers.PlayCharacter(player, profile, slot)
end

function handlers.CreateCharacter(player, profile, name, classId, look, useAvatar)
	if type(name) ~= "string" or type(classId) ~= "string" or (look ~= nil and type(look) ~= "table") then
		return false, "BadArgs"
	end
	if Character.Get(profile).Created then
		return false, "AlreadyCreated"
	end
	local valid, cleaned = Character.CheckName(name)
	if not valid then
		return false, cleaned
	end
	if not filterOk(player, cleaned) then
		return false, "Blocked"
	end
	local ok, reason = Character.Create(profile, cleaned, classId, look, useAvatar)
	if ok then
		ApiService.ApplyLook(player, profile)
		PartyService.RenamePlayer(player, Character.DisplayName(profile, player.Name))
		afterBuildChange(player)
	end
	return ok, reason
end

function handlers.UpdateCharacter(player, profile, look, useAvatar)
	if type(look) ~= "table" then
		return false, "BadArgs"
	end
	local ok, reason = Character.SetLook(profile, look, useAvatar)
	if ok then
		ApiService.ApplyLook(player, profile)
	end
	return ok, reason
end

function handlers.RenameCharacter(player, profile, name)
	if type(name) ~= "string" then
		return false, "BadArgs"
	end
	local valid, cleaned = Character.CheckName(name)
	if not valid then
		return false, cleaned
	end
	if not filterOk(player, cleaned) then
		return false, "Blocked"
	end
	local ok, cost = Character.Rename(profile, cleaned, Premium)
	if ok then
		ApiService.ApplyLook(player, profile)
		PartyService.RenamePlayer(player, Character.DisplayName(profile, player.Name))
	end
	return ok, cost
end

function handlers.RedeemCode(player, profile, text)
	if type(text) ~= "string" then
		return false, "BadArgs"
	end
	local now = os.time()
	local t = codeTries[player.UserId]
	if t == nil or now - t.Since > 60 then
		t = { Wrong = 0, Since = now, LockedUntil = 0 }
		codeTries[player.UserId] = t
	end
	if now < t.LockedUntil then
		return true, { Success = false, Reason = "Slow", Wait = t.LockedUntil - now }
	end
	local ok, result = Codes.Redeem(profile, text, now, CodeList)
	if ok then
		return true, { Success = true, Lines = result.Lines }
	end
	if result == "Invalid" or result == "Empty" then
		t.Wrong += 1
		if t.Wrong >= 5 then
			t.LockedUntil = now + 30
			t.Wrong = 0
		end
	end
	return true, { Success = false, Reason = result }
end

function handlers.BuyCosmetic(player, profile, id)
	if type(id) ~= "string" then
		return false, "BadArgs"
	end
	local ok, data = Cosmetics.Buy(profile, id)
	if ok then
		ApiService.ApplyLook(player, profile)
	end
	return ok, data
end

function handlers.BuyCosmeticBundle(player, profile, bundleId)
	if type(bundleId) ~= "string" then
		return false, "BadArgs"
	end
	return Cosmetics.BuyBundle(profile, bundleId)
end

function handlers.EquipCosmetic(player, profile, slot, id)
	if type(slot) ~= "string" or (id ~= nil and type(id) ~= "string") then
		return false, "BadArgs"
	end
	local ok, reason = Cosmetics.Equip(profile, slot, id)
	if ok then
		ApiService.ApplyLook(player, profile)
	end
	return ok, reason
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

-- Map rewards: every cleared stage leaves one reward to collect (boss stages always include wishes)
function handlers.ClaimStage(player, profile, stage)
	local ok, data = StageRewards.Claim(profile, stage)
	if ok then
		afterBuildChange(player)
	end
	return ok, data
end

function handlers.ClaimAllStages(player, profile)
	local ok, data = StageRewards.ClaimAll(profile)
	if ok and data.Count > 0 then
		afterBuildChange(player)
	end
	return ok, data
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

-- targetUserId: which teammate's ghost (optional: the first teammate)
function handlers.SetGhostLoadout(player, _, ids, targetUserId)
	if not isList(ids, Skills.SLOTS) then
		return false, "BadArgs"
	end
	local target = nil
	for _, mate in ipairs(PartyService.GetTeammates(player)) do
		if target == nil or mate.UserId == targetUserId then
			target = mate
		end
		if mate.UserId == targetUserId then
			break
		end
	end
	if not target then
		return false, "NoPartner"
	end
	return PartyService.SetGhostLoadout(player, target.UserId, ids)
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

-- Town errands: press the prompt at an errand spot (an NPC, the tavern, the hay pile, the cat ...). The player must be there.
function handlers.Errand(player, profile, spotId)
	if type(spotId) ~= "string" or not World.TownSpots[spotId] then
		return false, "BadArgs"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not World.NearSpot(root.Position.X, root.Position.Z, spotId) then
		return false, "TooFar"
	end
	return Errands.Interact(profile, spotId, os.time(), math.random)
end

-- Town activities (docs/TOWN.md phases 3-4): the fishing pond and the training dummy. You must stand at them.
local fishCasts = {} -- [userId] = the cast in the water (server clock)
local dummyUsed = {} -- [userId] = os.clock() of the last dummy test

local function nearSpot(player, spotId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and World.NearSpot(root.Position.X, root.Position.Z, spotId)
end

function handlers.FishCast(player)
	if not nearSpot(player, "Pond") then
		return false, "TooFar"
	end
	local cast, info = Fishing.Cast(os.clock(), math.random)
	fishCasts[player.UserId] = cast
	return true, info
end

function handlers.FishReel(player, profile, elapsed)
	local cast = fishCasts[player.UserId]
	fishCasts[player.UserId] = nil
	return Fishing.Reel(profile, cast, os.clock(), Daily.DayNumber(os.time()), math.random, if type(elapsed) == "number" then elapsed else nil)
end

function handlers.PetPlay(player, profile)
	if not nearSpot(player, "PetPark") then
		return false, "TooFar"
	end
	local ok, info = TownLeisure.PetPlay(profile, Daily.DayNumber(os.time()))
	if ok then
		afterBuildChange(player)
	end
	return ok, info
end

function handlers.TakeRelic(player, profile, id)
	if type(id) ~= "string" or not World.TownSpots[id] then
		return false, "BadArgs"
	end
	if not nearSpot(player, id) then
		return false, "TooFar"
	end
	return TownLeisure.TakeRelic(profile, id)
end

-- Sparring ring: duel another hero on this server, or one of your party's companions (Shared/Sparring).
local sparUsed = {}

local function sparOpponents(player)
	local list, seen = {}, {}
	for _, other in ipairs(Players:GetPlayers()) do
		local otherProfile = other ~= player and DataService.GetProfile(other)
		if otherProfile and otherProfile.Season.ClassId then
			seen[tostring(other.UserId)] = true
			table.insert(list, { Key = "p:" .. other.UserId, Name = Character.DisplayName(otherProfile, other.Name), ClassId = otherProfile.Season.ClassId, Level = otherProfile.Season.Level, Kind = "Player" })
		end
	end
	for _, mate in ipairs(PartyService.GetTeamSnapshots(player)) do
		if not seen[mate.Id] and mate.Snapshot then
			table.insert(list, { Key = "c:" .. mate.Id, Name = mate.Name, ClassId = mate.Snapshot.ClassId, Level = mate.Snapshot.Level, Kind = if tonumber(mate.Id) and tonumber(mate.Id) < 0 then "Companion" else "Partner" })
		end
	end
	return list
end

function handlers.SparList(player)
	return true, sparOpponents(player)
end

function handlers.SparFight(player, profile, key)
	if type(key) ~= "string" then
		return false, "BadArgs"
	end
	if not nearSpot(player, "Ring") then
		return false, "TooFar"
	end
	local last = sparUsed[player.UserId]
	if last and os.clock() - last < 5 then
		return false, "Busy"
	end
	local them
	if key:sub(1, 2) == "p:" then
		local other = Players:GetPlayerByUserId(tonumber(key:sub(3)) or 0)
		local otherProfile = other and other ~= player and DataService.GetProfile(other)
		if otherProfile then
			them = { Id = tostring(other.UserId), Name = Character.DisplayName(otherProfile, other.Name), Profile = otherProfile }
		end
	elseif key:sub(1, 2) == "c:" then
		for _, mate in ipairs(PartyService.GetTeamSnapshots(player)) do
			if mate.Id == key:sub(3) then
				them = mate
			end
		end
	end
	if not them then
		return false, "NoOpponent"
	end
	sparUsed[player.UserId] = os.clock()
	local me = { Id = tostring(player.UserId), Name = Character.DisplayName(profile, player.Name), Profile = profile }
	local duel = Sparring.Duel(me, them, math.random(1, 1000000))
	-- only what the client needs to replay the first bout as animation
	local events = {}
	for _, event in ipairs(duel.Fight.Events or {}) do
		if REPLAYED[event.Type] then
			table.insert(events, event)
		end
	end
	duel.Fight.Events = events
	duel.Lines = Sparring.Record(profile, duel.Won, Daily.DayNumber(os.time()))
	duel.Opponent = them.Name
	duel.Stats = Sparring.Stats(profile)
	return true, duel
end

function handlers.TrainDummy(player, profile)
	if not nearSpot(player, "Dummy") then
		return false, "TooFar"
	end
	local last = dummyUsed[player.UserId]
	if last and os.clock() - last < 8 then
		return false, "Busy"
	end
	dummyUsed[player.UserId] = os.clock()
	local members = { { Id = tostring(player.UserId), Name = Character.DisplayName(profile, player.Name), Profile = profile } }
	for _, mate in ipairs(PartyService.GetTeamSnapshots(player)) do
		table.insert(members, mate)
	end
	local result = TrainingDummy.Run(members, profile.Season.HighestStage or 1, math.random(1, 1000000))
	result.Best = TrainingDummy.Record(profile, result.Total)
	return true, result
end

-- Talents: level-up points (Shared/Talents). Spending changes the hero's stats, so the party's fights pick it up.
function handlers.SpendTalent(player, profile, id, n)
	if type(id) ~= "string" then
		return false, "BadArgs"
	end
	local ok, err = Talents.Spend(profile, id, if type(n) == "number" then math.clamp(n, 1, 10) else 1)
	if ok then
		afterBuildChange(player)
	end
	return ok, err
end

function handlers.ResetTalents(player, profile)
	Talents.Reset(profile)
	afterBuildChange(player)
	return true
end

function handlers.AutoTalents(player, profile)
	local n = Talents.AutoSpend(profile)
	if n > 0 then
		afterBuildChange(player)
	end
	return true, n
end

-- Sound settings: { Master, Music, Effects, Interface, SavedMaster } each 0..1, kept with the account.
function handlers.SaveSettings(_, profile, values)
	if type(values) ~= "table" then
		return false, "BadArgs"
	end
	local clean = {}
	for _, key in ipairs({ "Master", "Music", "Effects", "Interface", "SavedMaster" }) do
		local v = tonumber(values[key])
		if v then
			clean[key] = math.clamp(math.floor(v * 100 + 0.5) / 100, 0, 1)
		end
	end
	local hud = tonumber(values.HudScale)
	if hud and hud == hud then
		clean.HudScale = math.clamp(math.floor(hud * 10 + 0.5) / 10, 0.7, 1.3) -- the HUD size slider
	end
	profile.Permanent.Settings = clean
	return true
end

function handlers.ErrandAbandon(_, profile)
	return Errands.Abandon(profile, os.time())
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
	GuildService.Init(DataService.GetProfile, afterBuildChange)

	api.OnServerInvoke = function(player, action, ...)
		local now = os.clock()
		-- cheap read-only calls are not throttled, so a refresh right after an action is never refused
		local readOnly = action == "GetState" or action == "BossState" or action == "GuildState" or action == "GuildSearch" or action == "GetWorld" or action == "ReportError" -- ReportError has its own limit
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
		local ok, result, extra = xpcall(handler, debug.traceback, player, profile, ...)
		if not ok then
			warn("[ApiService] " .. tostring(action) .. " failed: " .. tostring(result))
			PlaytestService.ServerError(tostring(result), "handler " .. tostring(action))
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
				-- a skipped tutorial pays its wishes when the first boss falls: tell the player what arrived
				local tutorialText = nil
				if reward and reward.TutorialReward then
					local parts = {}
					for id, count in pairs(reward.TutorialReward) do
						local def = Consumables.Defs[id]
						table.insert(parts, ("%d %s%s"):format(count, if def then def.DisplayName else id, if count > 1 then "es" else ""))
					end
					table.sort(parts)
					tutorialText = "🎁 First boss beaten! Tutorial reward: " .. table.concat(parts, " + ") .. ". Spend them at the Wishing Tree."
				end
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
					Reward = reward and { Gold = reward.Gold, XP = reward.XP, Shards = reward.Shards, Wishstones = reward.Wishstones, Item = reward.Item and Gear.Name(reward.Item, member.Profile and member.Profile.Season.ClassId) or nil, Pets = reward.PetsGained, Tutorial = tutorialText, Rune = reward.Rune, Lucky = reward.LuckyFind } or nil,
				})
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCall[player.UserId] = nil
		codeTries[player.UserId] = nil
	end)
end

return ApiService
