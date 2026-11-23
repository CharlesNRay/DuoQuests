--[[
	Main (LocalScript)
	Location: StarterPlayer > StarterPlayerScripts > Client > Main

	Builds the UI on an reference-size layout (Kit.RefW x Kit.RefH) stretched to fill any screen, keeps a
	copy of the server's state, and redraws after every action or fight.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Screens = require(script.Parent.UI.Screens)
local Shops = require(script.Parent.UI.Shops)
local HeroScreen = require(script.Parent.UI.HeroScreen)
local MapScreen = require(script.Parent.UI.MapScreen)
local SkillsScreen = require(script.Parent.UI.SkillsScreen)
local LiveLog = require(script.Parent.UI.LiveLog)
Screens.Skills = SkillsScreen.Skills
Screens.Merchant = Shops.Merchant
Screens.Blacksmith = Shops.Blacksmith
Screens.Trainer = Shops.Trainer
Screens.PetStore = Shops.PetStore
Screens.RuneCarver = Shops.RuneCarver
Screens.Hero = HeroScreen.Hero
Screens.Map = MapScreen.Map
Screens.Quests = require(script.Parent.UI.QuestScreen).Quests
Screens.Battle = require(script.Parent.UI.BattleScreen).Battle
Screens.Guild = require(script.Parent.UI.GuildScreen).Guild
Screens.Premium = require(script.Parent.UI.PremiumScreen).Premium
Screens.Season = require(script.Parent.UI.SeasonScreen).Season
Screens.Cosmetics = require(script.Parent.UI.CosmeticsScreen).Cosmetics
Screens.Dev = require(script.Parent.UI.DevScreen).Dev
Screens.Codes = require(script.Parent.UI.CodesScreen).Codes
Screens.Store = require(script.Parent.UI.StoreScreen).Store
Screens.Character = require(script.Parent.UI.CharacterScreen).Character
local CosmeticsVisuals = require(script.Parent.Battle.CosmeticsVisuals)
CosmeticsVisuals.Init()
local World = require(Shared.World)
local Zones = require(Shared.Zones)
local Arenas = require(script.Parent.Battle.Arenas)
local Hub = require(script.Parent.Battle.Hub)
local Town = require(script.Parent.Battle.Town)
local Sound = require(script.Parent.Sound)
local Celebrate = require(script.Parent.UI.Celebrate)
local FishingGame = require(script.Parent.UI.FishingGame)
local StagesModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Stages"))
local BossArena = require(script.Parent.Battle.BossArena)
local PetFollower = require(script.Parent.Battle.PetFollower)
local BattleCamera = require(script.Parent.Battle.BattleCamera)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local api = folder:WaitForChild(Remotes.Api)
local push = folder:WaitForChild(Remotes.Push)

local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- we have our own rankings
end)
-- the class weapon is only a cosmetic: keep Roblox's hotbar (which would list it over our HUD) off
task.spawn(function()
	for _ = 1, 20 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end) then
			break
		end
		task.wait(0.5)
	end
end)

-- The UI fills the whole screen (below Roblox's top bar). A UIScale sizes everything for the
-- screen, and the root is stretched by the inverse so the edges really are the screen edges.
local gui = Kit.new("ScreenGui", { Name = "DuoQuestUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
local root = Kit.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local scale = Kit.new("UIScale", { Parent = root })
local function fit()
	local view = gui.AbsoluteSize
	local s = math.max(0.5, math.min(view.X / Kit.RefW, view.Y / Kit.RefH))
	scale.Scale = s
	root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
Kit.SetupTooltips(root, scale)

local hud = Hud.new(root)
local state
local liveLog = LiveLog.new(root, Screens.BuildLog, Screens.DamageMeter)
local fighting = false
local arenas = Arenas.new(Players.LocalPlayer.UserId)

local stopWatching -- defined below; the Plaza button needs it
-- Teleports: "Home" stands you in front of your own arena (facing it); "Plaza" goes back to the fountain.
local function teleport(cframe)
	local character = Players.LocalPlayer.Character
	if character then
		character:PivotTo(cframe)
	end
end
local function goHome()
	local mine = arenas:MySlot()
	if not mine then
		return
	end
	local origin = arenas:OriginOf(mine)
	local spot = origin + Vector3.new(0, 4, 40)
	teleport(CFrame.lookAt(spot, Vector3.new(origin.X, spot.Y, origin.Z)))
end
local function goPlaza()
	local x, y, z = World.SpawnPosition()
	teleport(CFrame.lookAt(Vector3.new(x, y + 2, z), Vector3.new(World.PLAZA.X, y + 2, World.PLAZA.Z)))
end

-- Take the world snapshot: build/refresh every party's arena and aim the battle
-- camera at ours. The first time we know our slot we place the character.
local current, extra, call, body -- set below; declared here so the world callbacks can see them
local lastDrawn -- which panel was drawn last (so a redraw can keep its scroll position)
extra = {}
local lastWorld
local lastMapKey
local mapPinKey = function(snapshot)
	local parts = {}
	for _, party in ipairs(snapshot.Parties or {}) do
		table.insert(parts, party.Slot .. ":" .. (party.Stage or 0) .. ":" .. #(party.Members or {}))
	end
	return table.concat(parts, ",")
end
local function applyWorld(snapshot)
	lastWorld = snapshot
	extra.World = snapshot
	arenas:Apply(snapshot)
	local mine = arenas:MySlot()
	if mine then
		BattleCamera.SetTarget(arenas:OriginOf(mine))
	end
	local taken = {}
	for _, party in ipairs(snapshot.Parties or {}) do
		taken[party.Slot] = true
	end
	Hub.SetLots(taken)
	-- keep the map's player pins current without redrawing it every few seconds for nothing
	local key = mapPinKey(snapshot)
	if key ~= lastMapKey then
		lastMapKey = key
		if current == "Map" and state then
			Screens.Map(body, state, call, extra)
		end
	end
end

local function refreshWorld()
	local ok, snapshot = api:InvokeServer("GetWorld")
	if ok and snapshot then
		applyWorld(snapshot)
	end
end

local function syncWorld()
	-- arenas follow the server's world snapshots; nothing to do per redraw
end
-- current: name of the open panel, or nil

-- every screen can pick its own panel size (reference units); the rest use the default
local PANEL_DEFAULT = Vector2.new(500, 286)
local PANEL_SIZES = {
	Map = Vector2.new(640, 298), Hero = Vector2.new(640, 298), Skills = Vector2.new(660, 344),
	Merchant = Vector2.new(540, 292), Blacksmith = Vector2.new(540, 292), Trainer = Vector2.new(540, 330), PetStore = Vector2.new(560, 330), RuneCarver = Vector2.new(600, 330), Wish = Vector2.new(640, 352), Store = Vector2.new(640, 336), Boss = Vector2.new(640, 310), Battle = Vector2.new(640, 330), Quests = Vector2.new(640, 330), Premium = Vector2.new(640, 330), Season = Vector2.new(640, 330), Cosmetics = Vector2.new(640, 330), Codes = Vector2.new(540, 300), Character = Vector2.new(640, 340), Guild = Vector2.new(720, 340), Dev = Vector2.new(640, 330), Party = Vector2.new(700, 330), Bag = Vector2.new(640, 330), Errands = Vector2.new(620, 330), Settings = Vector2.new(620, 330), Talents = Vector2.new(660, 340), Dummy = Vector2.new(600, 300),
}
local SHOP_NPC = { Merchant = "Merchant", Blacksmith = "Blacksmith", Trainer = "Trainer", PetStore = "PetStore", RuneCarver = "RuneCarver", Wish = "Tree" }
local panel = Kit.frame({ Name = "Panel", Size = UDim2.new(0, 500, 0, 286), Position = UDim2.new(0.5, -250, 0, 42), BackgroundColor3 = Kit.Colors.Bg, Visible = false, ZIndex = 5, Parent = root })
Kit.new("UIStroke", { Color = Color3.fromRGB(12, 14, 24), Thickness = 2.5, Parent = panel })
Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 200, 220)), Rotation = 90, Parent = panel })
do -- header ribbon with a gold underline
	local header = Kit.frame({ Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(58, 66, 112), ZIndex = 1, Parent = panel })
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 156, 190)), Rotation = 90, Parent = header })
	Kit.frame({ Size = UDim2.new(1, -4, 0, 2), Position = UDim2.fromOffset(2, 42), BackgroundColor3 = Color3.fromRGB(255, 196, 70), BackgroundTransparency = 0.25, ZIndex = 1, Parent = panel })
end
body = Kit.new("Frame", { Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 50), BackgroundTransparency = 1, Parent = panel })
local title = Kit.label({ Size = UDim2.new(1, -70, 0, 36), Position = UDim2.fromOffset(14, 3), Text = "", TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5, Parent = panel })
local closeBtn = Kit.button({ Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -40, 0, 5), Text = "X", TextSize = 16, BackgroundColor3 = Color3.fromRGB(205, 72, 72), Parent = panel }, function()
	current = nil
	lastDrawn = nil
	panel.Visible = false
	Kit.HideTip()
end)
closeBtn.UICorner.CornerRadius = UDim.new(0, 16)

-- guild screens read through here (no redraw), actions go through call()
function extra.Raw(action, ...)
	local ok, data = api:InvokeServer(action, ...)
	if not ok then
		task.wait(0.3)
		ok, data = api:InvokeServer(action, ...)
	end
	return ok, data
end
function extra.RefreshGuild()
	local ok, data = extra.Raw("GuildState")
	if ok and data then
		extra.Guild = data
	end
end

function extra.RefreshBoss()
	local ok, data = api:InvokeServer("BossState")
	if not ok then
		task.wait(0.3) -- the server rate-limits calls made back to back
		ok, data = api:InvokeServer("BossState")
	end
	if ok and data then
		extra.Boss = data
		extra.BossAt = os.clock()
	end
end

local offerPopup = nil
local menu -- the main menu (built below)
local tutorial -- the guided first session (built below)
local open -- defined below; the pop-up's shop button needs it
local function redraw()
	if not state then return end
	extra.State = state
	hud:Render(state)
	if state.Player.Cosmetics then
		CosmeticsVisuals.SetKill(state.Player.Cosmetics.Equipped.Kill)
	end
	-- a pop-up offer (the Subclass Pack at the subclass level) shows once, until the player closes it
	if state.Player.PremiumOffer == nil then
		offerPopup = nil
	elseif offerPopup == nil then
		offerPopup = require(script.Parent.UI.PremiumScreen).Popup(root, state, call, function(tab)
			extra.PremiumTab = tab
			extra.PremiumMsg = nil
			extra.StoreTab = "Premium"
			open("Store", "Store", true)
		end)
	end
	if menu and menu.Visible then
		menu:Render(state)
	end
	Hub.SetDailyReady(state.Player.Daily ~= nil and state.Player.Daily.CanClaim == true)
	Town.SetErrands(state.Player.Errands)
	Town.SetRelics(state.Player.Relics and state.Player.Relics.Found)
	-- sound settings come from the account once; after that the Settings screen owns them
	if not extra.SoundApplied then
		extra.SoundApplied = true
		Sound.Apply(state.Player.Settings)
	end
	-- level up: a big card, sparkles and a fanfare, wherever the player is
	local level = state.Player.Level
	if extra.LastLevel and level and level > extra.LastLevel then
		Sound.Play("LevelUp")
		Celebrate.Sparkle()
		local gained = level - extra.LastLevel
		Celebrate.Show(root, ("LEVEL %d!"):format(level), ("+%d talent point%s to spend - open ✨ Talents"):format(gained, if gained == 1 then "" else "s"), Color3.fromRGB(255, 214, 90))
	end
	extra.LastLevel = level
	local talents = state.Player.Talents
	hud:SetBadge("Talents", talents ~= nil and talents.Free > 0)
	if extra.RenderErrandTracker then
		extra.RenderErrandTracker(state.Player.Errands)
	end
	syncWorld()
	if current then
		if (current == "Boss" or current == "Battle") and extra.Boss == nil then
			extra.RefreshBoss()
		end
		if current == "Guild" and extra.Guild == nil then
			extra.RefreshGuild()
		end
		-- redrawing a panel (after an upgrade, say) must not throw the player back to the top of its lists
		local saved
		if lastDrawn == current and not extra.SkillsScrollTop then
			saved = {}
			for _, d in ipairs(body:GetDescendants()) do
				if d:IsA("ScrollingFrame") then
					table.insert(saved, d.CanvasPosition)
				end
			end
		end
		lastDrawn = current
		Screens[current](body, state, call, extra)
		extra.SkillsScrollTop = nil
		if saved and #saved > 0 then
			local frames = {}
			for _, d in ipairs(body:GetDescendants()) do
				if d:IsA("ScrollingFrame") then
					table.insert(frames, d)
				end
			end
			local function restore()
				for i, frame in ipairs(frames) do
					if saved[i] and frame.Parent then
						frame.CanvasPosition = saved[i]
					end
				end
			end
			restore()
			-- the canvas size updates a frame later (AutomaticCanvasSize), so set it again once it has grown
			task.defer(restore)
			task.delay(0.05, restore)
		end
	end
end

local QUIET_ACTIONS = { ChooseClass = true, MakeCharacter = true, PlayCharacter = true, CreateCharacter = true, RenameCharacter = true, UpdateCharacter = true }
-- feedback for claiming, buying and upgrading (2026-11-23, owner: "a sound effect or special effect when claiming things")
local CLAIM_FX = {
	ClaimDaily = "claim", ClaimQuest = "claim", ClaimWeeklyQuest = "claim", ClaimPass = "claim", ClaimStage = "claim",
	ExpeditionCollect = "claim", GuildClaimMission = "claim", GuildRaidClaim = "claim", Gift = "claim",
	ClaimQuestBonus = "big", ClaimWeeklyBonus = "big", ClaimAllStages = "big", BossClaim = "big", ClaimSeasonRewards = "big", RedeemCode = "big", BossHatch = "big",
	MarketBuy = "buy", BuyConsumable = "buy", BuyPetEgg = "buy", BuyPetGearCrate = "buy", BuyRunePouch = "buy", BuyCosmetic = "buy", BuyCosmeticBundle = "buy", BuyPremium = "buy", BuyPetWithShards = "buy",
	UpgradeGear = "upgrade", CarveRune = "upgrade", UpgradeBag = "upgrade", GuildBuy = "upgrade",
	LevelSlot = "power", RankUpSkill = "power", RankUpPet = "power", UpgradeSkill = "power", LevelPassiveSlot = "power", ConsumeSkillCopies = "power",
	SpendTalent = "power", AutoTalents = "power", UseConsumable = "power", UnlockSkillWithPick = "power", ChooseSubclass = "big",
}
local FX_LOOKS = {
	claim = { Sounds = { "Coins", "Reward" }, Color = Color3.fromRGB(255, 214, 90), Count = 14 },
	big = { Sounds = { "Coins", "Errand" }, Color = Color3.fromRGB(255, 214, 90), Count = 24, Sparkle = true },
	buy = { Sounds = { "Purchase" }, Color = Color3.fromRGB(120, 230, 140), Count = 10 },
	upgrade = { Sounds = { "Upgrade", "Reward" }, Color = Color3.fromRGB(255, 150, 70), Count = 16 },
	power = { Sounds = { "PowerUp" }, Color = Color3.fromRGB(130, 190, 255), Count = 14 },
}
function call(action, ...)
	local ok, data = api:InvokeServer(action, ...)
	if action == "CreateCode" and ok then
		extra.Code = data
	end
	if not ok then
		warn("[DuoQuest] " .. action .. " failed: " .. tostring(data))
		if QUIET_ACTIONS[action] then
			return ok, data -- the screen shows its own message
		end
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Text = "Could not do that: " .. tostring(data), TextColor3 = Kit.Colors.Bad, Parent = body })
	else
		-- something claimed, bought or upgraded: a sound and a burst of stars where you clicked
		local fx = CLAIM_FX[action]
		if fx then
			local look = FX_LOOKS[fx]
			for _, name in ipairs(look.Sounds) do
				Sound.Play(name)
			end
			Celebrate.Burst(look.Color, look.Count)
			if look.Sparkle then
				Celebrate.Sparkle(look.Color)
			end
		end
		-- the server rate-limits back-to-back calls (0.1s), so a refresh sent right after an action can be
		-- refused: retry shortly instead of leaving the screen stale
		local fresh, newState
		for attempt = 1, 4 do
			fresh, newState = api:InvokeServer("GetState")
			if fresh then
				break
			end
			task.wait(0.12 * attempt)
		end
		if fresh then state = newState end
		redraw()
	end
	return ok, data
end

-- Centre the panel, slid up so the menu dock stays visible. While the tutorial card is out on the left,
-- push the panel right so the card does not cover it (as far as the screen allows).
local TUTORIAL_CARD_RIGHT = 8 + 340 + 8 -- card x + width (Tutorial.luau WIDTH) + gap, in root units
local function placePanel()
	local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
	local y = if h > 290 then 2 else 6
	local rootW = root.Size.X.Offset
	local left = rootW / 2 - w / 2
	if tutorial and tutorial.Shown and left < TUTORIAL_CARD_RIGHT then
		left = math.max(left, math.min(TUTORIAL_CARD_RIGHT, rootW - w - 8))
	end
	panel.Position = UDim2.fromOffset(left, y)
end

function open(name, label, keep)
	if current == name and panel.Visible and not keep then
		current = nil
		lastDrawn = nil
		panel.Visible = false
		Kit.HideTip()
		return
	end
	current = name
	lastDrawn = nil
	if tutorial then
		tutorial:Opened(name)
	end
	title.Text = label
	local size = PANEL_SIZES[name] or PANEL_DEFAULT
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	placePanel()
	if not panel.Visible then
		Sound.Play("Open")
	end
	panel.Visible = true
	redraw()
end

local function inspect(userId)
	if userId <= 0 then
		return -- the starter ghost has no profile to show
	end
	if userId == Players.LocalPlayer.UserId then
		open("Party", "Party")
		return
	end
	local ok, info = api:InvokeServer("Inspect", userId)
	if ok and info then
		extra.Inspect = info
		open("Inspect", info.Name)
	end
end
arenas.OnInspect = inspect
arenas.OnBanner = function(text, color)
	hud:ShowBanner(text, color)
end

-- other players' avatars can be clicked too
local function wireCharacter(player, character)
	if player == Players.LocalPlayer then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:FindFirstChildOfClass("ClickDetector") == nil then
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 60
		detector.Parent = root
		detector.MouseClick:Connect(function()
			inspect(player.UserId)
		end)
	end
end
local function wirePlayer(player)
	if player.Character then
		task.spawn(wireCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		wireCharacter(player, character)
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	wirePlayer(player)
end
Players.PlayerAdded:Connect(wirePlayer)

local function showBoard(categoryId, keep)
	extra.BoardCategory = categoryId
	local ok, data = api:InvokeServer("GetLeaderboard", categoryId)
	extra.Board = if ok then data else nil
	open("Ranks", "Leaderboards", keep)
end
local function showSeason(keep)
	local ok, data = api:InvokeServer("GetSeasonRewards")
	extra.SeasonData = if ok then data else nil
	open("Season", "Season Rewards", keep)
end
PetFollower.new(function()
	local pet = state and state.Player and state.Player.ActivePet
	return if pet then { pet } else {}
end)
extra.OpenPanel = function(name, label)
	open(name, label, true)
end
extra.RefreshSeason = function()
	showSeason(true)
end
extra.OpenSeason = function()
	extra.SeasonMsg = nil
	showSeason()
end
extra.ShowBoard = function(categoryId)
	showBoard(categoryId, true)
end
hud.OnMap = function() open("Map", "World Map") end
hud.OnAdvance = function() call("Advance") end
hud.OnPartner = function(index)
	extra.HeroTab = if (index or 1) <= 1 then "Partner" else "Mate" .. index
	open("Hero", "Hero", true)
end
hud.OnParty = function() open("Party", "Party", true) end
hud:AddButton("Hero", "dock", "🧙", "Hero", function() open("Hero", "Hero") end)
hud:AddButton("Skills", "dock", "⚔️", "Skills", function() open("Skills", "Skills") end)
hud:AddButton("Pets", "dock", "🐱", "Pets", function() open("Pets", "Pets") end)
hud:AddButton("Party", "dock", "👥", "Party", function() open("Party", "Party") end)
hud:AddButton("Talents", "dock", "✨", "Talents", function() open("Talents", "Talents") end)
Screens.Talents = require(script.Parent.UI.TalentScreen).Talents

-- Studio only: one test panel with every cheat (levels, stages, gold, items, pets, dailies, world boss, premium).
if RunService:IsStudio() then
	hud:AddButton("Dev", "mini", "🧪", "Test cheats (Studio only)", function() open("Dev", "Test cheats") end)
end

hud:AddButton("Bag", "dock", "🎒", "Bag", function() open("Bag", "Bag") end)

-- the plaza: boards, chest and the two shop NPCs open the same screens as the dock
local function shopOpen(name, label)
	-- server checks the distance too; the prompt is only 14 studs wide, so this is just the screen
	open(name, label, true)
end
Hub.Build({
	Map = function() open("Map", "World Map", true) end,
	Ranks = function() showBoard(extra.BoardCategory or "Stage") end,
	Season = function() extra.OpenSeason() end,
	Daily = function() open("Daily", "Daily Login", true) end,
	Merchant = function() shopOpen("Merchant", "Merchant - sell gear") end,
	Blacksmith = function() shopOpen("Blacksmith", "Blacksmith - upgrade gear") end,
	Trainer = function() shopOpen("Trainer", "Skill Trainer - level skill slots") end,
	PetStore = function() shopOpen("PetStore", "Pet Store - eggs & pet gear") end,
	RuneCarver = function() shopOpen("RuneCarver", "Rune Carver - carve runes onto gear") end,
	Tree = function() open("Wish", "Wishing Tree", true) end,
	Store = function()
		extra.StoreTab = extra.StoreTab or "Market"
		open("Store", "Store", true)
	end,
})
-- places in and around town that open a screen: Dungeon Gate, Expedition Camp, Guild Board
Town.OnPlace = function(id)
	if id == "DungeonGate" then
		extra.BattleTab = "Dungeons"
		open("Battle", "Dungeons", true)
	elseif id == "ExpeditionCamp" then
		extra.BattleTab = "Expeditions"
		open("Battle", "Expeditions", true)
	elseif id == "GuildBoard" then
		extra.Guild = nil
		open("Guild", "Guild", true)
	elseif id == "Dummy" then
		extra.RunDummy()
	elseif id == "PetPark" then
		task.spawn(function()
			local ok, data = api:InvokeServer("PetPlay")
			if ok and type(data) == "table" then
				Town.Say("PetPark", "Your pet had a great time! " .. table.concat(data.Lines or {}, ", "))
				Sound.Play("Reward")
				Celebrate.Sparkle(Color3.fromRGB(255, 170, 210))
			else
				Town.Say("PetPark", if data == "DoneToday" then "Your pet is tired out. Come back tomorrow!" elseif data == "NoPet" then "Bring a pet to play! (Pets screen)" else "Come closer to play.")
			end
		end)
	elseif tostring(id):sub(1, 5) == "Relic" then
		task.spawn(function()
			local ok, data = api:InvokeServer("TakeRelic", id)
			if ok and type(data) == "table" then
				Sound.Play(if data.All then "LevelUp" else "Reward")
				Celebrate.Sparkle(Color3.fromRGB(120, 230, 255))
				Celebrate.Show(root, if data.All then "ALL RELICS FOUND!" else ("RELIC %d / %d"):format(data.Found, data.Total), table.concat(data.Lines or {}, "  "), Color3.fromRGB(120, 230, 255))
				local fresh, newState = api:InvokeServer("GetState")
				if fresh and newState then
					state = newState
					redraw()
				end
			end
		end)
	elseif id == "Pond" then
		FishingGame.Start(root, api, {
			Bobber = Town.Bobber,
			Sound = Sound.Play,
			StillNear = function()
				local character = Players.LocalPlayer.Character
				local r = character and character:FindFirstChild("HumanoidRootPart")
				return r ~= nil and World.NearSpot(r.Position.X, r.Position.Z, "Pond")
			end,
		})
	end
end
-- the training dummy: your party hits it for 20 s on the server, the screen shows each hero's damage per second
Screens.Dummy = require(script.Parent.UI.DummyScreen).Dummy
local dummyRunning = false
function extra.RunDummy()
	if dummyRunning then
		return
	end
	dummyRunning = true
	extra.Dummy = nil
	open("Dummy", "Training Dummy", true)
	local ok, data = api:InvokeServer("TrainDummy")
	dummyRunning = false
	if ok and type(data) == "table" then
		extra.Dummy = data
		Sound.Play("Reward")
	else
		extra.Dummy = { Seconds = 0, Total = 0, Rows = {}, Best = 0 }
	end
	if current == "Dummy" then
		redraw()
	end
end

-- Town errands (docs/TOWN.md phase 2): prompts at the townsfolk and pick-up spots, the Notice Board opens the list,
-- and a small tracker shows the errand in hand.
do
	local tracker = Kit.frame({ Name = "ErrandTracker", Size = UDim2.fromOffset(280, 66), Position = UDim2.new(0, 8, 1, -180), BackgroundColor3 = Kit.Colors.Bg, BackgroundTransparency = 0.12, Visible = false, Parent = root })
	Kit.new("UIStroke", { Color = Color3.fromRGB(255, 196, 70), Thickness = 1.5, Parent = tracker })
	local head = Kit.label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 4), Text = "", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = Kit.Colors.Accent, Parent = tracker })
	local body = Kit.label({ Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 24), Text = "", TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = tracker })
	extra.RenderErrandTracker = function(info)
		local active = info and info.Active
		tracker.Visible = active ~= nil
		if active then
			head.Text = ("📜 %s  (%d/%d)"):format(active.Name, active.Step, active.Steps)
			body.Text = active.Text
		end
	end
	local busy = false
	local REFUSALS = { Busy = "Finish the errand you have first!", DoneToday = "Thanks again! Come back tomorrow.", Nothing = "Nothing I need today - try the Notice Board!" }
	Town.OnErrand = function(spotId)
		if busy then
			return
		end
		busy = true
		local ok, data = api:InvokeServer("Errand", spotId)
		if ok and type(data) == "table" then
			if data.Kind == "Started" then
				Town.Say(spotId, data.Line)
				Sound.Play("Pop")
			elseif data.Kind == "Done" then
				Town.Say(spotId, "Thank you! Here: " .. table.concat(data.Reward or {}, ", "))
				Sound.Play("Errand")
				Celebrate.Sparkle(Color3.fromRGB(150, 220, 255))
				Celebrate.Show(root, "ERRAND DONE!", table.concat(data.Reward or {}, "  +  "), Color3.fromRGB(150, 220, 255))
			else
				Town.Say(spotId, "Here you go!")
				Sound.Play("Pop")
			end
			local fresh, newState = api:InvokeServer("GetState")
			if fresh and newState then
				state = newState
				redraw()
			end
		elseif REFUSALS[data] then
			Town.Say(spotId, REFUSALS[data])
		end
		busy = false
	end
	Town.OnBoard = function()
		open("Errands", "Notice Board - town errands", true)
	end
end
hud:AddButton("Plaza", "travel", "⛲", "Plaza", function()
	if BattleCamera.IsBattleView() then
		stopWatching()
	end
	goPlaza()
end)
hud:AddButton("Home", "travel", "🏠", "Home", function()
	goHome()
	if extra.WatchMine then
		extra.WatchMine()
	end
end)
hud:AddButton("Battle", "mini", "⚔️", "Battle: bosses, dungeons, expeditions", function()
	extra.BattleTab = nil
	open("Battle", "Battle")
end)
hud:AddButton("Store", "mini", "🛍️", "Store", function()
	extra.StoreTab = extra.StoreTab or "Market"
	open("Store", "Store")
end)
hud:AddButton("Quests", "mini", "📜", "Quests & Season Pass", function() open("Quests", "Quests & Season Pass") end)
hud:AddButton("Settings", "mini", "⚙️", "Settings (sound)", function() open("Settings", "Settings") end)
Screens.Settings = require(script.Parent.UI.SettingsScreen).Settings
extra.SaveSettings = function(values)
	task.spawn(function()
		api:InvokeServer("SaveSettings", values)
	end)
end
Kit.OnClick = function()
	Sound.Play("Click")
end
-- the fight log lives in the battle view (its bar has a Log button)
hud.OnLog = function() open("Log", "Last Fight") end

push.OnClientEvent:Connect(function(kind, info)
	if kind == "World" then
		applyWorld(info)
	elseif kind == "Gift" then
		hud:Notify(("🎁 %s sent you %s %s x%d!"):format(tostring(info.From), tostring(info.Glyph), tostring(info.Item), info.Count or 1))
		task.spawn(function()
			local ok, fresh = api:InvokeServer("GetState")
			if ok and fresh then
				state = fresh
				redraw()
			end
		end)
	elseif kind == "Purchase" then
		-- a Robux purchase went through: refresh so the new Sunstones show
		task.spawn(function()
			local ok, fresh = api:InvokeServer("GetState")
			if ok and fresh then
				state = fresh
				redraw()
				hud:Notify("🔶 Thank you! Your Sunstones were added.")
			end
		end)
	elseif kind == "OpenBoss" then
		extra.BossTab = info
		extra.Boss = nil
		open("Boss", "Bosses", true)
	elseif kind == "BossEvent" then
		if info.Kind == "WorldStart" then
			hud:Notify(("👹 %s has appeared in the plaza! (%d min)"):format(info.Name, math.floor(info.Seconds / 60)))
		elseif info.Kind == "WorldEnd" then
			extra.BossMsg = ("Boss over! You dealt %d (%d tiers): %s"):format(info.Damage, info.Tiers, table.concat(info.Lines, ", "))
			extra.BossTab = "World"
			extra.Boss = nil
			local ok, fresh = api:InvokeServer("GetState")
			if ok and fresh then state = fresh end
			open("Boss", "Bosses", true)
		end
	elseif kind == "BossFight" then
		extra.BossMusic = info.Kind or "WorldBoss"
		task.spawn(function()
			current, lastDrawn = nil, nil
			panel.Visible = false
			Kit.HideTip()
			liveLog:Play(info, 0.8)
			liveLog:SetOpen(false) -- the boss stands on the right where the meter sits; "+" opens it again
			hud:Notify("⚔ " .. tostring(info.Label) .. "!")
			local started = BossArena.Play(info, function()
				local ok, fresh = api:InvokeServer("GetState")
				if ok and fresh then state = fresh end
				extra.Boss = nil
				extra.RefreshBoss()
				open("Battle", "Battle", true)
			end)
			if not started then
				hud:Notify(("You dealt %d damage to %s!"):format(info.Damage or 0, tostring(info.Label)))
				extra.Boss = nil
				extra.RefreshBoss()
			end
		end)
	elseif kind == "ArenaFight" then
		arenas:Play(info.Slot, info)
	elseif kind == "Fight" then
		extra.LastFight = info
		if current == "Log" then
			redraw()
		end
		hud:OnFight(info)
		liveLog:Play(info, 0.8)
		fighting = true
		arenas:Play(info.Slot, info, function()
			fighting = false
			if info.Won then
				Sound.Play(if info.Stage and StagesModule.IsBoss(info.Stage) then "BossClear" else "StageClear")
			end
			if info.Reward and info.Reward.Tutorial then
				hud:Notify(info.Reward.Tutorial)
			end
			local ok, fresh = api:InvokeServer("GetState")
			if ok and fresh then
				state = fresh
			end
			redraw()
			refreshWorld()
		end)
	end
end)

-- animate the plaza, and shut a shop when you walk away from its NPC (the server refuses it anyway)
RunService.Heartbeat:Connect(function(dt)
	Hub.Update(dt)
	-- music follows what you are looking at: a boss arena (its own theme), your battle, or the town
	Sound.Music(if BossArena.IsActive() then (extra.BossMusic or "WorldBoss") elseif BattleCamera.IsBattleView() then "Stage" else "Town")
	local shop = current and SHOP_NPC[current]
	if shop then
		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and not World.NearShop(rootPart.Position.X, rootPart.Position.Z, shop) then
			current = nil
			lastDrawn = nil
			panel.Visible = false
			Kit.HideTip()
		end
	end
end)

BattleCamera.Start()
BattleCamera.SetBattleView(false) -- start walking around, not in the fixed battle view
-- Camera: walk around, snap to your own battle, or watch someone else's.
local watchingSlot = nil
function stopWatching()
	watchingSlot = nil
	local mine = arenas:MySlot()
	if mine then
		BattleCamera.SetTarget(arenas:OriginOf(mine))
	end
	BattleCamera.SetBattleView(false)
	hud:SetWatching(nil)
end

local function watch(slot, origin)
	local mine = arenas:MySlot()
	watchingSlot = slot
	current = nil
	lastDrawn = nil -- close any open panel; it would cover the fight
	panel.Visible = false
	Kit.HideTip()
	BattleCamera.SetTarget(origin)
	BattleCamera.SetBattleView(true)
	local label = "Your battle"
	if slot ~= mine then
		label = "Watching a battle"
		for _, party in ipairs(lastWorld and lastWorld.Parties or {}) do
			if party.Slot == slot and party.Members[1] then
				label = "Watching " .. party.Members[1].Name .. "'s party"
			end
		end
	end
	hud:SetWatching(label, stopWatching)
	if tutorial then
		tutorial:Opened("Watch") -- the tutorial's last step: watch a battle
	end
end
arenas.OnWatch = watch
function extra.WatchMine()
	local mine = arenas:MySlot()
	if mine then
		watch(mine, arenas:OriginOf(mine))
	end
end

-- first state (the server may still be loading the profile)
for _ = 1, 40 do
	local ok, fresh = api:InvokeServer("GetState")
	if ok and fresh then
		state = fresh
		break
	end
	task.wait(0.5)
end
redraw()
refreshWorld()
-- everyone starts at the main menu: nobody spawns until they press Play on a character
menu = require(script.Parent.UI.MainMenu).new(root, call, extra, require(script.Parent.UI.CharacterScreen))
tutorial = require(script.Parent.UI.Tutorial).new(root, hud, call, function()
	return state, menu ~= nil and menu.Visible -- the card stays up while a panel is open, so the "open this" and info steps can be read
end)
-- keep an open panel clear of the tutorial card as the card slides in/out or the screen resizes
tutorial.Card:GetPropertyChangedSignal("Visible"):Connect(placePanel)
root:GetPropertyChangedSignal("Size"):Connect(placePanel)
-- "Take me there" on a tutorial step: stop watching, then stand a few studs from that plaza spot, facing it
-- (inside its prompt range, so the player only has to press the prompt)
tutorial.GoTo = function(spot)
	if not World.PlazaSpots[spot] then
		return
	end
	if BattleCamera.IsBattleView() then
		stopWatching()
	end
	local sx, sz = World.PlazaPoint(spot)
	local toCentre = Vector3.new(World.PLAZA.X - sx, 0, World.PLAZA.Z - sz)
	local stand = Vector3.new(sx, 4, sz) + (if toCentre.Magnitude > 0 then toCentre.Unit * 14 else Vector3.new(0, 0, 14))
	teleport(CFrame.lookAt(stand, Vector3.new(sx, 4, sz)))
	-- turn the camera to look over the hero's shoulder at the spot, so its prompt is on screen
	task.defer(function()
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType == Enum.CameraType.Custom then
			local spotPos = Vector3.new(sx, 6, sz)
			local away = stand - Vector3.new(sx, 4, sz)
			local eye = stand + (if away.Magnitude > 0 then away.Unit * 12 else Vector3.new(0, 0, 12)) + Vector3.new(0, 7, 0)
			cam.CFrame = CFrame.lookAt(eye, spotPos)
		end
	end)
end
extra.OpenMenu = function()
	current = nil
	lastDrawn = nil
	panel.Visible = false
	if state then
		menu:Show(state)
	end
end
if state then
	menu:Show(state)
end
