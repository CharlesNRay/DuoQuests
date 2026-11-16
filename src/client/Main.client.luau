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
Screens.Hero = HeroScreen.Hero
Screens.Map = MapScreen.Map
Screens.Quests = require(script.Parent.UI.QuestScreen).Quests
Screens.Guild = require(script.Parent.UI.GuildScreen).Guild
Screens.Premium = require(script.Parent.UI.PremiumScreen).Premium
Screens.Season = require(script.Parent.UI.SeasonScreen).Season
Screens.Cosmetics = require(script.Parent.UI.CosmeticsScreen).Cosmetics
Screens.Codes = require(script.Parent.UI.CodesScreen).Codes
Screens.Store = require(script.Parent.UI.StoreScreen).Store
Screens.Character = require(script.Parent.UI.CharacterScreen).Character
local CosmeticsVisuals = require(script.Parent.Battle.CosmeticsVisuals)
CosmeticsVisuals.Init()
local World = require(Shared.World)
local Zones = require(Shared.Zones)
local Arenas = require(script.Parent.Battle.Arenas)
local Hub = require(script.Parent.Battle.Hub)
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
	Merchant = Vector2.new(540, 292), Blacksmith = Vector2.new(540, 292), Wish = Vector2.new(640, 352), Store = Vector2.new(640, 336), Boss = Vector2.new(640, 310), Quests = Vector2.new(640, 330), Premium = Vector2.new(640, 330), Season = Vector2.new(640, 330), Cosmetics = Vector2.new(640, 330), Codes = Vector2.new(540, 300), Character = Vector2.new(640, 340), Guild = Vector2.new(720, 340),
}
local SHOP_NPC = { Merchant = "Merchant", Blacksmith = "Blacksmith", Wish = "Tree" }
local panel = Kit.frame({ Name = "Panel", Size = UDim2.new(0, 500, 0, 286), Position = UDim2.new(0.5, -250, 0, 42), BackgroundColor3 = Kit.Colors.Bg, Visible = false, ZIndex = 5, Parent = root })
Kit.new("UIStroke", { Color = Color3.fromRGB(90, 98, 140), Thickness = 2, Parent = panel })
Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 208, 225)), Rotation = 90, Parent = panel })
do -- a banner across the top of every window
	local header = Kit.frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(46, 52, 84), ZIndex = 1, Parent = panel })
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 176, 205)), Rotation = 90, Parent = header })
	Kit.new("UIStroke", { Color = Color3.fromRGB(255, 196, 70), Thickness = 1.5, Transparency = 0.55, Parent = header })
end
body = Kit.new("Frame", { Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 50), BackgroundTransparency = 1, Parent = panel })
local title = Kit.label({ Size = UDim2.new(1, -70, 0, 36), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 20, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.4, Parent = panel })
Kit.button({ Size = UDim2.fromOffset(44, 36), Position = UDim2.new(1, -52, 0, 6), Text = "X", BackgroundColor3 = Color3.fromRGB(200, 70, 70), Parent = panel }, function()
	current = nil
	lastDrawn = nil
	panel.Visible = false
	Kit.HideTip()
end)

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
	Hub.SetDailyReady(state.Player.Daily ~= nil and state.Player.Daily.CanClaim == true)
	syncWorld()
	if current then
		if current == "Boss" and extra.Boss == nil then
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

local QUIET_ACTIONS = { ChooseClass = true, CreateCharacter = true, RenameCharacter = true, UpdateCharacter = true }
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
	title.Text = label
	local size = PANEL_SIZES[name] or PANEL_DEFAULT
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	panel.Position = UDim2.new(0.5, -size.X / 2, 0, if size.Y > 290 then 2 else 6) -- slid up so the menu dock stays visible
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
hud.OnPartner = function()
	extra.HeroTab = "Partner"
	open("Hero", "Hero", true)
end
hud.OnParty = function() open("Party", "Party", true) end
hud:AddButton("Hero", "dock", "🧙", "Hero", function() open("Hero", "Hero") end)
hud:AddButton("Skills", "dock", "⚔️", "Skills", function() open("Skills", "Skills") end)
hud:AddButton("Pets", "dock", "🐱", "Pets", function() open("Pets", "Pets") end)
hud:AddButton("Party", "dock", "👥", "Party", function() open("Party", "Party") end)

-- Studio only: a test button that grants gold, boosts and gear so every screen can be exercised.
if RunService:IsStudio() then
	hud:AddButton("DevLevel", "mini", "⬆", "+5 levels (Studio only)", function() call("DevLevel") end)
	hud:AddButton("Dev", "mini", "🧪", "Test items (Studio only)", function() call("DevGrant") end)
	hud:AddButton("DevPremium", "mini", "★", "Toggle premium pass (Studio only)", function() call("DevPremium") end)
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
	Tree = function() open("Wish", "Wishing Tree", true) end,
})
hud:AddButton("Plaza", "mini", "⛲", "Plaza (leave the battle view)", function()
	if BattleCamera.IsBattleView() then
		stopWatching()
	end
	goPlaza()
end)
hud:AddButton("Home", "mini", "🏠", "Home: your arena and your battle", function()
	goHome()
	if extra.WatchMine then
		extra.WatchMine()
	end
end)
hud:AddButton("Boss", "mini", "👹", "Bosses", function()
	extra.Boss = nil
	open("Boss", "Bosses")
end)
hud:AddButton("Guild", "mini", "🛡️", "Guild", function()
	extra.Guild, extra.GuildMsg, extra.GuildResults = nil, nil, nil
	open("Guild", "Guild")
end)
hud:AddButton("Store", "mini", "🛍️", "Store", function()
	extra.StoreTab = extra.StoreTab or "Premium"
	open("Store", "Store")
end)
hud:AddButton("Quests", "mini", "📜", "Quests & Season Pass", function() open("Quests", "Quests & Season Pass") end)
-- the fight log lives in the battle view (its bar has a Log button)
hud.OnLog = function() open("Log", "Last Fight") end

push.OnClientEvent:Connect(function(kind, info)
	if kind == "World" then
		applyWorld(info)
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
		task.spawn(function()
			while fighting do
				task.wait(0.2) -- let the party's current fight finish first
			end
			fighting = true
			extra.WatchMine()
			hud:Notify("⚔ " .. tostring(info.Label) .. "!")
			liveLog:Play(info, 0.8)
			arenas:Play(info.Slot, info, function()
				fighting = false
				hud:Notify(("You dealt %d damage to %s!"):format(info.Damage or 0, tostring(info.Label)))
				local ok, fresh = api:InvokeServer("GetState")
				if ok and fresh then state = fresh end
				extra.Boss = nil
				extra.RefreshBoss()
				open("Boss", "Bosses", true)
			end)
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
-- a brand new player starts in the character creator
if state and state.Player.Character and not state.Player.Character.Created then
	extra.CharMsg = nil
	extra.PickClass = nil
	open("Character", "Choose your class")
end
