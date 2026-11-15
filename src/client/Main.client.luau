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
local BattleCamera = require(script.Parent.Battle.BattleCamera)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local api = folder:WaitForChild(Remotes.Api)
local push = folder:WaitForChild(Remotes.Push)

local gui = Kit.new("ScreenGui", { Name = "DuoQuestUI", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
local root = Kit.new("Frame", { Name = "Root", Size = UDim2.fromOffset(844, 390), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local scale = Kit.new("UIScale", { Parent = root })
local function fit()
	local view = gui.AbsoluteSize
	scale.Scale = math.min(view.X / 844, view.Y / 390)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

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
local function applyWorld(snapshot)
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

local panel = Kit.frame({ Name = "Panel", Size = UDim2.new(0, 500, 0, 300), Position = UDim2.new(0.5, -250, 0, 46), BackgroundColor3 = Kit.Colors.Bg, Visible = false, ZIndex = 5, Parent = root })
local body = Kit.new("Frame", { Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 50), BackgroundTransparency = 1, Parent = panel })
local title = Kit.label({ Size = UDim2.new(1, -70, 0, 36), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 20, Font = Enum.Font.GothamBold, Parent = panel })
Kit.button({ Size = UDim2.fromOffset(44, 36), Position = UDim2.new(1, -52, 0, 6), Text = "X", Parent = panel }, function()
	current = nil
	panel.Visible = false
end)

local function redraw()
	if not state then return end
	hud:Render(state)
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

local function open(name, label)
	current = name
	title.Text = label
	panel.Visible = true
	redraw()
end

hud:AddNav("Skills", function() open("Skills", "Skills") end)
hud:AddNav("Passives", function() open("Passives", "Passives") end)
hud:AddNav("Pets", function() open("Pets", "Pets") end)
hud:AddNav("Ultimate", function() open("Ultimate", "Party Ultimate") end)
hud:AddNav("Map", function() open("Map", "World Map") end)
hud:AddNav("Party", function() open("Party", "Party") end)

push.OnClientEvent:Connect(function(kind, info)
	if kind == "World" then
		applyWorld(info)
	elseif kind == "ArenaFight" then
		arenas:Play(info.Slot, info)
	elseif kind == "Fight" then
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
local viewButton
viewButton = hud:AddNav("Battle view", function()
	local battle = not BattleCamera.IsBattleView()
	BattleCamera.SetBattleView(battle)
	viewButton.Text = battle and "Walk" or "Battle view"
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
