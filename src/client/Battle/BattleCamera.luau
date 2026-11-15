--[[
	BattleCamera (ModuleScript): the fixed side view of your own arena, plus the
	switch back to normal Roblox walking.

	  BattleCamera.Start()
	  BattleCamera.SetTarget(origin)    Vector3 centre of your arena (nil = none)
	  BattleCamera.SetBattleView(on)    true: fixed side view; false: walk camera
	  BattleCamera.IsBattleView()

	Fits any screen shape (phone, tablet, PC) by choosing the distance that shows
	the whole pad width and height.
]]
local RunService = game:GetService("RunService")

local BattleCamera = {}

local WIDTH_NEEDED = 54
local HEIGHT_NEEDED = 22

local target = nil
local battleView = false -- Main switches it on from the Battle view button
local started = false

function BattleCamera.SetTarget(origin)
	target = origin
end

function BattleCamera.SetBattleView(on)
	battleView = on
	local cam = workspace.CurrentCamera
	if not on then
		cam.CameraType = Enum.CameraType.Custom
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
end

function BattleCamera.IsBattleView()
	return battleView
end

function BattleCamera.Start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("DuoQuestBattleCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not battleView or not target then
			return
		end
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 40
		local view = cam.ViewportSize
		local aspect = view.X / math.max(1, view.Y)
		local halfTan = math.tan(math.rad(cam.FieldOfView) / 2)
		local distance = math.max(WIDTH_NEEDED / (2 * halfTan * aspect), HEIGHT_NEEDED / (2 * halfTan))
		local sway = math.sin(os.clock() * 0.6) * 0.4
		local look = target + Vector3.new(sway, 5.5, 0)
		cam.CFrame = CFrame.lookAt(look + Vector3.new(0, 2.5, distance), look)
	end)
end

return BattleCamera
