--[[
	MenuBattle (ModuleScript): a "fake" auto battle that plays behind the main menu.

	It runs the REAL combat simulation locally (Shared/StageRunner) for two made-up heroes, a Warrior in the player's own avatar
	and a Cleric, and replays it in a private 3D arena far from the world with the same Replay/Actor code the game uses, so the menu
	shows genuine shields, heals, buffs, poison and bleeds. Nothing here touches the server or any save.

	  MenuBattle.Start()   builds the arena, takes the camera, dims the light to dusk, and loops fights
	  MenuBattle.Stop()    removes it all and gives the camera and lighting back
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.ProfileTemplate)
local StageRunner = require(Shared.StageRunner)
local Classes = require(Shared.Config.Classes)
local Zones = require(Shared.Zones)
local Scene = require(script.Parent.Scene)
local Replay = require(script.Parent.Replay)

local MenuBattle = {}

local ORIGIN = Vector3.new(4000, 300, 4000) -- far from the plaza and every arena
-- (stage, level) pairs the made-up party can win with a bit of drama: the fights last 12 to 18 seconds
local FIGHTS = { { 28, 12 }, { 33, 14 }, { 38, 16 }, { 33, 13 }, { 28, 11 } }

local running = false
local scene, replay
local saved

local function member(id, name, classId, level, loadout)
	local profile = ProfileTemplate.New()
	profile.Season.ClassId = classId
	profile.Season.Level = level
	ProfileTemplate.GrantClassStarters(profile.Season, classId)
	for _, ability in ipairs(Classes[classId].AbilityPool) do
		profile.Season.OwnedAbilities[ability] = true
	end
	profile.Season.Loadouts[classId] = loadout
	return { Id = id, Name = name, Profile = profile }
end

local function newFight(index)
	local stage, level = table.unpack(FIGHTS[(index - 1) % #FIGHTS + 1])
	for attempt = 1, 4 do
		local party = {
			member(tostring(Players.LocalPlayer.UserId), Players.LocalPlayer.DisplayName, "Warrior", level, { "Taunt", "IronSkin", "ShieldBash", "Whirlwind" }),
			member("-7", "Mira", "Cleric", level, { "Heal", "DivineShield", "Blessing", "Smite" }),
		}
		local outcome = StageRunner.Run(party, stage, math.random(1, 1000000), nil, true)
		if outcome.Won or attempt == 4 then
			return { Roster = outcome.Roster, Events = outcome.Events, Duration = outcome.Duration, Won = outcome.Won }, stage
		end
	end
end

function MenuBattle.Start()
	if running then
		return true
	end
	local ok = pcall(function()
		scene = Scene.new(ORIGIN)
		replay = Replay.new(scene)
		scene:SetZone(Zones.ForStage(30).Theme)
	end)
	if not ok then
		MenuBattle.Stop()
		return false
	end
	running = true

	-- dusk lighting (this client only) and a fixed side-on camera
	saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	TweenService:Create(Lighting, TweenInfo.new(1.5), { ClockTime = 18.6, Brightness = 1.6, Ambient = Color3.fromRGB(90, 70, 120), OutdoorAmbient = Color3.fromRGB(120, 90, 140) }):Play()
	RunService:BindToRenderStep("DuoQuestMenuCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 38
		local view = cam.ViewportSize
		local aspect = view.X / math.max(1, view.Y)
		local halfTan = math.tan(math.rad(cam.FieldOfView) / 2)
		local distance = math.max(46 / (2 * halfTan * aspect), 20 / (2 * halfTan))
		local t = os.clock()
		local look = ORIGIN + Vector3.new(math.sin(t * 0.4) * 1.2, 7.2, 0) -- looks above the fighters so they sit low on the screen
		cam.CFrame = CFrame.lookAt(look + Vector3.new(math.sin(t * 0.25) * 2, 1.5, distance), look)
	end)

	task.spawn(function()
		local index = 0
		while running do
			index += 1
			local info, stage = newFight(index)
			if not running then
				break
			end
			local finished = false
			scene:SetZone(Zones.ForStage(stage).Theme)
			replay:Play(info, function()
				finished = true
			end)
			local started = os.clock()
			while running and not finished and os.clock() - started < info.Duration + 5 do
				task.wait(0.25)
			end
			local rest = os.clock()
			while running and os.clock() - rest < 2.2 do -- they walk on to the next fight
				task.wait(0.25)
			end
		end
	end)
	return true
end

function MenuBattle.Stop()
	running = false
	pcall(function()
		RunService:UnbindFromRenderStep("DuoQuestMenuCamera")
	end)
	if replay then
		pcall(function()
			replay:Destroy()
		end)
		replay = nil
	end
	if scene then
		pcall(function()
			scene:Destroy()
		end)
		scene = nil
	end
	if saved then
		TweenService:Create(Lighting, TweenInfo.new(0.6), saved):Play()
		saved = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
end

return MenuBattle
