--[[
	MenuBattle (ModuleScript): a "fake" auto battle that plays behind the main menu.

	It runs the REAL combat simulation locally (Shared/StageRunner) for a made-up party of four (like every fight in the game): a Warrior in the
	player's own avatar, a Cleric, a Mage and a Ranger, and replays it in a private 3D arena far from the world with the same Replay/Actor code the game uses, so the menu
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
-- (stage, level) pairs the gearless four-hero party wins, 8 to 18 s each (stage 10 is a boss). The Warrior wears the
-- player's own avatar, so it should rarely fall: it dies in 0-23% of these fights (a level lower and it dies in nearly
-- all). Checked headless 2026-11-23, 30 seeds each, 149/150 won. The old pairs (stage 28-38 at level 11-16) were set
-- for two heroes before the balance passes and ended in a 1 s wipe.
local FIGHTS = { { 9, 12 }, { 11, 19 }, { 10, 14 }, { 12, 24 }, { 13, 27 } }

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
			member("-8", "Ilsa", "Mage", level, { "Fireball", "Blizzard", "ChainLightning", "Meteor" }),
			member("-9", "Wren", "Ranger", level, { "PowerShot", "Volley", "Snare", "ExplosiveArrow" }),
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
	local ok, why = pcall(function()
		scene = Scene.new(ORIGIN)
		replay = Replay.new(scene)
		scene:SetZone(Zones.ForStage(5).Theme)
	end)
	if not ok then
		warn("[IdlePartyQuest] menu battle could not start: " .. tostring(why))
		MenuBattle.Stop()
		return false
	end
	running = true

	-- dusk lighting (this client only) and a fixed side-on camera
	saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	TweenService:Create(Lighting, TweenInfo.new(1.5), { ClockTime = 17.4, Brightness = 2.6, Ambient = Color3.fromRGB(130, 105, 150), OutdoorAmbient = Color3.fromRGB(165, 135, 165) }):Play()
	RunService:BindToRenderStep("IdlePartyMenuCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 38
		local view = cam.ViewportSize
		local aspect = view.X / math.max(1, view.Y)
		local halfTan = math.tan(math.rad(cam.FieldOfView) / 2)
		local distance = math.max(64 / (2 * halfTan * aspect), 30 / (2 * halfTan))
		local t = os.clock()
		local look = ORIGIN + Vector3.new(math.sin(t * 0.4) * 1.2, 12.2, 0) -- looks above the fighters so they sit low on the screen
		cam.CFrame = CFrame.lookAt(look + Vector3.new(math.sin(t * 0.25) * 2, 1.5, distance), look)
	end)

	task.spawn(function()
		local index = 0
		while running do
			index += 1
			local okFight, info, stage = pcall(newFight, index)
			if not okFight then
				warn("[IdlePartyQuest] menu battle fight failed: " .. tostring(info))
				task.wait(3)
				continue
			end
			if not running then
				break
			end
			local finished = false
			scene:SetZone(Zones.ForStage(5).Theme)
			local okPlay, err = pcall(replay.Play, replay, info, function()
				finished = true
			end)
			if not okPlay then
				warn("[IdlePartyQuest] menu battle replay failed: " .. tostring(err))
				finished = true
			end
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
		RunService:UnbindFromRenderStep("IdlePartyMenuCamera")
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
