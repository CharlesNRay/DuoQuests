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
Screens.Merchant = Shops.Merchant
Screens.Blacksmith = Shops.Blacksmith
Screens.Hero = HeroScreen.Hero
Screens.Map = MapScreen.Map
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
local fighting = false
local arenas = Arenas.new(Players.LocalPlayer.UserId)

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
	Map = Vector2.new(640, 304), Hero = Vector2.new(640, 304),
	Merchant = Vector2.new(540, 296), Blacksmith = Vector2.new(540, 296),
}
local SHOP_NPC = { Merchant = "Merchant", Blacksmith = "Blacksmith" }
local panel = Kit.frame({ Name = "Panel", Size = UDim2.new(0, 500, 0, 286), Position = UDim2.new(0.5, -250, 0, 42), BackgroundColor3 = Kit.Colors.Bg, Visible = false, ZIndex = 5, Parent = root })
body = Kit.new("Frame", { Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 50), BackgroundTransparency = 1, Parent = panel })
local title = Kit.label({ Size = UDim2.new(1, -70, 0, 36), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 20, Font = Enum.Font.GothamBold, Parent = panel })
Kit.button({ Size = UDim2.fromOffset(44, 36), Position = UDim2.new(1, -52, 0, 6), Text = "X", Parent = panel }, function()
	current = nil
	panel.Visible = false
	Kit.HideTip()
end)

local function redraw()
	if not state then return end
	hud:Render(state)
	Hub.SetDailyReady(state.Player.Daily ~= nil and state.Player.Daily.CanClaim == true)
	syncWorld()
	if current then
		Screens[current](body, state, call, extra)
	end
end

function call(action, ...)
	local ok, data = api:InvokeServer(action, ...)
	if action == "CreateCode" and ok then
		extra.Code = data
	end
	if not ok then
		warn("[DuoQuest] " .. action .. " failed: " .. tostring(data))
		Kit.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Text = "Could not do that: " .. tostring(data), TextColor3 = Kit.Colors.Bad, Parent = body })
	else
		local fresh, newState = api:InvokeServer("GetState")
		if fresh then state = newState end
		redraw()
	end
	return ok, data
end

local function open(name, label, keep)
	if current == name and panel.Visible and not keep then
		current = nil
		panel.Visible = false
		Kit.HideTip()
		return
	end
	current = name
	title.Text = label
	local size = PANEL_SIZES[name] or PANEL_DEFAULT
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	panel.Position = UDim2.new(0.5, -size.X / 2, 0, if size.Y > 290 then 34 else 42)
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
extra.ShowBoard = function(categoryId)
	showBoard(categoryId, true)
end
hud:AddButton("Hero", "dock", "🧙", "Hero", function() open("Hero", "Hero") end)
hud:AddButton("Skills", "dock", "⚔️", "Skills", function() open("Skills", "Skills") end)
hud:AddButton("Passives", "dock", "📜", "Passives", function() open("Passives", "Passives") end)
hud:AddButton("Pets", "dock", "🐱", "Pets", function() open("Pets", "Pets") end)
hud:AddButton("Party", "dock", "👥", "Party", function() open("Party", "Party") end)

hud:AddButton("Map", "dock", "🗺️", "Map", function() open("Map", "World Map") end)
hud:AddButton("Gear", "dock", "🛡️", "Gear", function() open("Gear", "Gear & Sets") end)
hud:AddButton("Bag", "dock", "🎒", "Bag", function() open("Bag", "Bag") end)
hud:AddButton("Daily", "dock", "🎁", "Daily", function() open("Daily", "Daily Login") end)
hud:AddButton("Ranks", "dock", "🏆", "Ranks", function() showBoard(extra.BoardCategory or "Stage") end)

-- the plaza: boards, chest and the two shop NPCs open the same screens as the dock
local function shopOpen(name, label)
	-- server checks the distance too; the prompt is only 14 studs wide, so this is just the screen
	open(name, label, true)
end
Hub.Build({
	Map = function() open("Map", "World Map", true) end,
	Ranks = function() showBoard(extra.BoardCategory or "Stage") end,
	Daily = function() open("Daily", "Daily Login", true) end,
	Merchant = function() shopOpen("Merchant", "Merchant - sell gear") end,
	Blacksmith = function() shopOpen("Blacksmith", "Blacksmith - upgrade gear") end,
})
hud:AddButton("Plaza", "mini", "⛲", "Plaza", goPlaza)
hud:AddButton("Home", "mini", "🏠", "Home", goHome)
hud:AddButton("Log", "mini", "📋", "Fight log", function() open("Log", "Last Fight") end)

push.OnClientEvent:Connect(function(kind, info)
	if kind == "World" then
		applyWorld(info)
	elseif kind == "ArenaFight" then
		arenas:Play(info.Slot, info)
	elseif kind == "Fight" then
		extra.LastFight = info
		if current == "Log" then
			redraw()
		end
		hud:OnFight(info)
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
			panel.Visible = false
			Kit.HideTip()
		end
	end
end)

BattleCamera.Start()
BattleCamera.SetBattleView(false) -- start walking around, not in the fixed battle view
-- Camera: walk around, snap to your own battle, or watch someone else's.
local watchingSlot = nil
local function stopWatching()
	watchingSlot = nil
	local mine = arenas:MySlot()
	if mine then
		BattleCamera.SetTarget(arenas:OriginOf(mine))
	end
	BattleCamera.SetBattleView(false)
	hud:SetWatching(nil)
	hud:SetButtonText("View", "🎥", "Battle view")
end

local function watch(slot, origin)
	local mine = arenas:MySlot()
	watchingSlot = slot
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
	hud:SetButtonText("View", "🚶", "Walk")
end
arenas.OnWatch = watch

hud:AddButton("View", "mini", "🎥", "Battle view", function()
	if BattleCamera.IsBattleView() then
		stopWatching()
	else
		local mine = arenas:MySlot()
		if mine then
			watch(mine, arenas:OriginOf(mine))
		end
	end
end)

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
