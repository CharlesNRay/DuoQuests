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
		ExtraMods = Pets.Collection(profile).Mods,
	})
end

local cosmeticsOf -- defined below
local characterOf -- defined below

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
			Passes = Passes.List(profile),
			StageClaims = profile.Season.StageClaims or {},
			Perks = Passes.Perks(profile),
			PremiumOffer = Premium.Offer(profile),
			SunstonePacks = Premium.Packs(profile),
			Cosmetics = cosmeticsOf(profile),
			Character = characterOf(profile),
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
		MaxCharacters = Characters.MAX, Characters = Characters.List(profile), Active = Characters.Active(profile), InGame = Characters.Entered(profile),
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
function handlers.GuildBuy(player, profile, upgradeId) return guildCall(player, GuildService.Buy, player, profile, upgradeId) end
function handlers.GuildClaimMission(player, profile, kind, index) return GuildService.ClaimMission(player, profile, kind, index) end
function handlers.GuildRaid(player, profile)
	return GuildService.RaidChallenge(player, profile, PartyService.GetPartnerSnapshot(player), function(fight, label, damage)
		playBossFight(player, fight, label, damage)
	end)
end
function handlers.GuildRaidClaim(player, profile, which) return GuildService.RaidClaim(player, profile, which) end
function handlers.GuildWish(player, profile, count) return guildCall(player, GuildService.Wish, player, profile, count) end

-- Bosses: the world boss (this server, timed) and the season boss (all servers).
function handlers.BossState(player, profile)
	return true, BossService.GetState(player, profile)
end

-- Only what the client needs to replay a fight as animation.
local REPLAYED = { Damage = true, Heal = true, Cast = true, Death = true, Revive = true, Ultimate = true, End = true, Spawn = true, Telegraph = true, Status = true, StatusEnd = true }
local pushRemote

-- A boss challenge is a real fight in YOUR arena: the party's normal fights pause, you (and anyone near) watch it.
local function playBossFight(player, fight, label, damage, extraInfo)
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
	local payload = { Slot = slot, PartyId = partyState.PartyId, Stage = partyState.Stage, Won = fight.Won, Duration = fight.Duration, Roster = fight.Roster, Events = events, Label = label, Damage = damage, Extra = extraInfo }
	-- the fight is played in a private boss arena on the challenger's screen, so nobody else watches it
	pushRemote:FireClient(player, "BossFight", payload)
end

function handlers.BossChallenge(player, profile, which)
	if which ~= "World" and which ~= "Season" then
		return false, "BadArgs"
	end
	local ok, data = BossService.Challenge(player, profile, which, PartyService.GetPartnerSnapshot(player))
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
	local partner = PartyService.GetPartnerSnapshot(player)
	if partner then
		table.insert(members, { Id = partner.Id, Name = partner.Name, Snapshot = partner.Snapshot })
	end
	local ok, result = Activities.RunDungeon(profile, members, id, math.random(1, 1e9), os.time(), true)
	if ok then
		local fight = result.Fight
		result.Fight = nil
		if fight then
			playBossFight(player, fight, result.Name, 0, { Floors = result.Floors, Cleared = result.Cleared, Lines = result.Lines })
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
	local isPetFood = Consumables.Defs[id] ~= nil and Consumables.Defs[id].Kind == "PetFood"
	if not nearShop(player, "Merchant") and not (isPetFood and nearShop(player, "PetStore")) then
		return false, "TooFar"
	end
	return Consumables.Buy(profile, id, count)
end

-- Studio-only test helper (the 🧪 "Test items" HUD button): gold, shards and a few of everything.
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

-- Studio-only: level up (5 levels per press) to test progression quickly.
function handlers.DevLevel(player, profile)
	if not game:GetService("RunService"):IsStudio() then
		return false, "Forbidden"
	end
	for _ = 1, 5 do
		Progression.AddXP(profile.Season, Progression.XPToNext(profile.Season.Level))
	end
	afterBuildChange(player)
	return true, profile.Season.Level
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

-- Main menu: make a character (just a class choice, up to Characters.MAX). It does not start playing it.
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
	GuildService.Init(DataService.GetProfile, afterBuildChange)

	api.OnServerInvoke = function(player, action, ...)
		local now = os.clock()
		-- cheap read-only calls are not throttled, so a refresh right after an action is never refused
		local readOnly = action == "GetState" or action == "BossState" or action == "GuildState" or action == "GuildSearch" or action == "GetWorld"
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
					Reward = reward and { Gold = reward.Gold, XP = reward.XP, Shards = reward.Shards, Wishstones = reward.Wishstones, Item = reward.Item and Gear.Name(reward.Item, member.Profile and member.Profile.Season.ClassId) or nil, Pets = reward.PetsGained } or nil,
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
