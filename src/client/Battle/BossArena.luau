--[[
	BossArena (ModuleScript): the private arena for the world boss, the season boss and guild raids.

	A boss challenge is not played in your own arena. The camera moves to a separate scorched arena far from the world, the
	fight is replayed there with the same Replay code as every other battle, and when it ends a results card shows how it went.

	  BossArena.Play(info, onClose)   info = the "BossFight" push (Roster, Events, Duration, Won, Label, Damage)
	  BossArena.IsActive()
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FightStats = require(Shared.FightStats)
local Scene = require(script.Parent.Scene)
local Replay = require(script.Parent.Replay)
local Kit = require(script.Parent.Parent.UI.Kit)
local Sound = require(script.Parent.Parent.Sound)

local BossArena = {}

local ORIGIN = Vector3.new(-4000, 300, 4000)
local THEME = { Name = "Boss Arena", Ground = { 58, 40, 40 }, Sky = { 96, 30, 28 }, Accent = { 255, 90, 40 }, Scenery = "LavaRocks", Brightness = 1.4, Material = "Basalt", Decor = { Kind = "Embers", Color = { 255, 130, 40 } } }
local GOLD = Color3.fromRGB(255, 196, 70)

local active = false
local scene, replay, resultGui, leaveGui, saved
local leaving = false

local function restore()
	pcall(function()
		RunService:UnbindFromRenderStep("IdlePartyBossCamera")
	end)
	if replay then
		pcall(function() replay:Destroy() end)
		replay = nil
	end
	if scene then
		pcall(function() scene:Destroy() end)
		scene = nil
	end
	if resultGui then
		resultGui:Destroy()
		resultGui = nil
	end
	if leaveGui then
		leaveGui:Destroy()
		leaveGui = nil
	end
	if saved then
		TweenService:Create(Lighting, TweenInfo.new(0.6), saved):Play()
		saved = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
	active = false
end

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	while true do
		local nxt, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = nxt
		if k == 0 then
			break
		end
	end
	return s
end

local function showResults(info, onClose)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IdlePartyBossResults"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	resultGui = gui

	local extra = info.Extra
	local won = if extra then extra.Cleared >= extra.Floors else info.Won == true
	local headline = if won then "VICTORY" elseif extra and extra.Cleared > 0 then "WAVES CLEARED" else "DEFEATED"
	Sound.Play(if won then "Victory" else "Defeat")
	local summary = if extra then ("Waves  %d / %d     Time  %ds"):format(extra.Cleared, extra.Floors, math.floor(info.Duration or 0)) else ("Damage dealt  %s     Time  %ds"):format(commas(info.Damage or 0), math.floor(info.Duration or 0))
	local prize = if extra and #(extra.Lines or {}) > 0 then "Rewards: " .. table.concat(extra.Lines, ", ") else nil
	local prizeHeight = if prize then 16 * math.ceil(#prize / 46) + 6 else 0
	local accent = if won then Color3.fromRGB(96, 214, 130) else Color3.fromRGB(235, 90, 90)
	local rows = FightStats.Compute({ Roster = info.Roster, Events = info.Events, Duration = info.Duration }).Rows
	local card = Kit.frame({ Size = UDim2.fromOffset(340, 120 + math.min(#rows, 4) * 30 + 56 + prizeHeight), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(16, 19, 32), Parent = gui })
	Kit.new("UIStroke", { Color = accent, Thickness = 2, Parent = card })
	Kit.frame({ Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = accent, NoCorner = true, Parent = card })
	Kit.label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 12), Text = headline, TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = card })
	Kit.label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 44), Text = tostring(info.Label or "Boss"), TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = card })
	Kit.label({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 66), Text = summary, TextSize = 13, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = card })
	for i = 1, math.min(#rows, 4) do
		local row = rows[i]
		local y = 98 + (i - 1) * 30
		local bar = Kit.frame({ Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, y), BackgroundColor3 = Color3.fromRGB(30, 34, 54), Parent = card })
		Kit.frame({ Size = UDim2.fromScale(math.clamp(row.Share or 0, 0.02, 1), 1), BackgroundColor3 = FightStats.PlayerColor(row.Color), BackgroundTransparency = 0.45, Parent = bar })
		Kit.label({ Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(8, 0), Text = row.Name, TextSize = 12, TextWrapped = false, TextStrokeTransparency = 1, Parent = bar })
		Kit.label({ Size = UDim2.new(0.4, -8, 1, 0), Position = UDim2.fromScale(0.6, 0), Text = commas(row.Damage or 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, TextStrokeTransparency = 1, Parent = bar })
	end
	if prize then
		Kit.label({ Size = UDim2.new(1, -24, 0, prizeHeight), Position = UDim2.new(0, 12, 1, -52 - prizeHeight), Text = prize, TextSize = 12, TextColor3 = Color3.fromRGB(196, 202, 222), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	end
	Kit.button({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 12, 1, -46), Text = "Continue", TextSize = 15, BackgroundColor3 = accent, TextColor3 = Color3.fromRGB(10, 24, 14), Parent = card }, function()
		restore()
		if onClose then
			onClose()
		end
	end)
	card.Position = UDim2.new(0.5, 0, 0.5, 40)
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

function BossArena.IsActive()
	return active
end

function BossArena.Play(info, onClose)
	if active then
		return false
	end
	active = true
	local ok, why = pcall(function()
		scene = Scene.new(ORIGIN)
		replay = Replay.new(scene)
		scene:SetZone(THEME)
	end)
	if not ok then
		warn("[IdlePartyQuest] boss arena could not start: " .. tostring(why))
		restore()
		return false
	end
	saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	TweenService:Create(Lighting, TweenInfo.new(1), { ClockTime = 19, Brightness = 2, Ambient = Color3.fromRGB(150, 80, 70), OutdoorAmbient = Color3.fromRGB(170, 90, 80) }):Play()
	RunService:BindToRenderStep("IdlePartyBossCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 40
		local view = cam.ViewportSize
		local halfTan = math.tan(math.rad(cam.FieldOfView) / 2)
		local distance = math.max(64 / (2 * halfTan * view.X / math.max(1, view.Y)), 32 / (2 * halfTan))
		local look = ORIGIN + Vector3.new(0, 11, 0)
		cam.CFrame = CFrame.lookAt(look + Vector3.new(math.sin(os.clock() * 0.2) * 3, 2, distance), look)
	end)
	-- Leave fight: the result is already decided on the server, so leaving just skips ahead to the results card
	leaving = false
	pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "IdlePartyBossLeave"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 55
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		leaveGui = gui
		Kit.button({ Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -16, 0, 70), AnchorPoint = Vector2.new(1, 0), Text = "Leave fight", TextSize = 14, BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = gui }, function()
			leaving = true
		end)
		-- banners from the replay (dungeon waves, ultimates, big boss attacks), below the HUD's stage card (they sat on it)
		replay.OnBanner = function(text, color)
			local label = Kit.label({ Size = UDim2.fromOffset(500, 40), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0), Text = text, TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = color or GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui })
			task.delay(2.2, function()
				label:Destroy()
			end)
		end
	end)
	task.spawn(function()
		task.wait(1)
		local finished = false
		local played, err = pcall(replay.Play, replay, info, function()
			finished = true
		end)
		if not played then
			warn("[IdlePartyQuest] boss arena replay failed: " .. tostring(err))
			finished = true
		end
		local started = os.clock()
		while active and not finished and not leaving and os.clock() - started < (info.Duration or 30) + 8 do
			task.wait(0.25)
		end
		if leaveGui then
			leaveGui:Destroy()
			leaveGui = nil
		end
		if active then
			if leaving then
				pcall(function() replay.Token += 1 end) -- stop the replay where it is
			else
				task.wait(1.2)
			end
			showResults(info, onClose)
		end
	end)
	return true
end

return BossArena
