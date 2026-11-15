--[[
	Main (LocalScript)
	Location: StarterPlayer > StarterPlayerScripts > Client > Main

	Builds the UI on an 844x390 reference frame scaled to any screen, keeps a
	copy of the server's state, and redraws after every action or fight.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Screens = require(script.Parent.UI.Screens)
local Zones = require(Shared.Zones)
local Arenas = require(script.Parent.Battle.Arenas)
local Hub = require(script.Parent.Battle.Hub)
local BattleCamera = require(script.Parent.Battle.BattleCamera)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local api = folder:WaitForChild(Remotes.Api)
local push = folder:WaitForChild(Remotes.Push)

local gui = Kit.new("ScreenGui", { Name = "DuoQuestUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
local root = Kit.new("Frame", { Name = "Root", Size = UDim2.fromOffset(844, 390), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local scale = Kit.new("UIScale", { Parent = root })
local function fit()
	local view = gui.AbsoluteSize
	scale.Scale = math.min(view.X / 844, view.Y / 390)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
Kit.SetupTooltips(root, scale)

local hud = Hud.new(root)
local state
local fighting = false
local arenas = Arenas.new(Players.LocalPlayer.UserId)

-- Stand the character in front of our own arena (the open side, facing it), so we
-- start in the world and can walk off; "Battle view" snaps to the side camera.
local function standInFront()
	local mine = arenas:MySlot()
	local character = Players.LocalPlayer.Character
	if not (mine and character) then
		return
	end
	local origin = arenas:OriginOf(mine)
	local spot = origin + Vector3.new(0, 4, 32)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(origin.X, spot.Y, origin.Z)))
end

-- Take the world snapshot: build/refresh every party's arena and aim the battle
-- camera at ours. The first time we know our slot we place the character.
local placed = false
local lastWorld
local function applyWorld(snapshot)
	lastWorld = snapshot
	arenas:Apply(snapshot)
	local mine = arenas:MySlot()
	if mine then
		BattleCamera.SetTarget(arenas:OriginOf(mine))
		if not placed then
			placed = true
			standInFront()
		end
	end
end

-- after dying/respawning, come back in front of the arena
Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	standInFront()
end)

local function refreshWorld()
	local ok, snapshot = api:InvokeServer("GetWorld")
	if ok and snapshot then
		applyWorld(snapshot)
	end
end

local function syncWorld()
	-- arenas follow the server's world snapshots; nothing to do per redraw
end
local current -- name of the open panel, or nil
local extra = {}
local call

local panel = Kit.frame({ Name = "Panel", Size = UDim2.new(0, 500, 0, 286), Position = UDim2.new(0.5, -250, 0, 42), BackgroundColor3 = Kit.Colors.Bg, Visible = false, ZIndex = 5, Parent = root })
local body = Kit.new("Frame", { Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 50), BackgroundTransparency = 1, Parent = panel })
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
hud:AddButton("Skills", "left", "⚔️", "Skills", function() open("Skills", "Skills") end)
hud:AddButton("Passives", "left", "📜", "Passives", function() open("Passives", "Passives") end)
hud:AddButton("Pets", "left", "🐾", "Pets", function() open("Pets", "Pets") end)
hud:AddButton("Party", "left", "👥", "Party", function() open("Party", "Party") end)

hud:AddButton("Map", "right", "🗺️", "Map", function() open("Map", "World Map") end)
hud:AddButton("Gear", "right", "🛡️", "Gear", function() open("Gear", "Gear & Sets") end)
hud:AddButton("Bag", "right", "🎒", "Bag", function() open("Bag", "Bag") end)
hud:AddButton("Daily", "right", "🎁", "Daily", function() open("Daily", "Daily Login") end)
hud:AddButton("Ranks", "right", "🏆", "Ranks", function() showBoard(extra.BoardCategory or "Stage") end)

hud:AddButton("Log", "corner", "📋", "Fight log", function() open("Log", "Last Fight") end)

-- the same menus as props in the hub
Hub.Build({
	Map = function() open("Map", "World Map") end,
	Ranks = function() showBoard(extra.BoardCategory or "Stage") end,
	Daily = function() open("Daily", "Daily Login") end,
})

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

hud:AddButton("View", "corner", "🎥", "Battle view", function()
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
