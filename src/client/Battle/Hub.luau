--[[
	Hub (ModuleScript): interactable props near the spawn, so the menus live in the
	world like in other Roblox games as well as on the HUD.

	  Hub.Build(handlers, origin)  handlers = { Map = fn, Ranks = fn, Daily = fn }; origin = the
	                               centre of YOUR arena: the props stand in front of it (home base)
	  Hub.SetDailyReady(bool)

	Each prop is a client-side Part with a ProximityPrompt (press E / tap).
]]
local Hub = {}

local folder
local chestPrompt

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function prompt(on, action, object, handler)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = on
	pr.Triggered:Connect(function()
		handler()
	end)
	return pr
end

local function sign(on, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = on
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor or Color3.fromRGB(255, 236, 190)
	label.Parent = gui
end

local function board(position, title, color, action, handler)
	local root = Instance.new("Model")
	root.Name = title
	root.Parent = folder
	part(root, { Name = "PostL", Size = Vector3.new(0.8, 8, 0.8), Position = position + Vector3.new(-3.6, 4, 0), Color = Color3.fromRGB(110, 76, 48), Material = Enum.Material.Wood })
	part(root, { Name = "PostR", Size = Vector3.new(0.8, 8, 0.8), Position = position + Vector3.new(3.6, 4, 0), Color = Color3.fromRGB(110, 76, 48), Material = Enum.Material.Wood })
	local face = part(root, { Name = "Face", Size = Vector3.new(9, 5, 0.6), Position = position + Vector3.new(0, 6, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	sign(face, Enum.NormalId.Front, title)
	sign(face, Enum.NormalId.Back, title)
	prompt(face, action, title, handler)
	return face
end

function Hub.Build(handlers, origin)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "DuoQuestInteractables"
	folder.Parent = workspace

	local front = origin + Vector3.new(0, 0, 31)
	board(front + Vector3.new(-14, 0, 0), "WORLD MAP", Color3.fromRGB(40, 90, 150), "Open map", handlers.Map)
	board(front + Vector3.new(14, 0, 0), "RANKINGS", Color3.fromRGB(110, 50, 140), "View leaderboards", handlers.Ranks)

	-- daily gift chest
	local chest = Instance.new("Model")
	chest.Name = "Daily Gift"
	chest.Parent = folder
	local base = part(chest, { Name = "Base", Size = Vector3.new(4, 2.4, 3), Position = front + Vector3.new(27, 1.2, 2), Color = Color3.fromRGB(150, 100, 56), Material = Enum.Material.Wood })
	part(chest, { Name = "Lid", Size = Vector3.new(4.2, 1, 3.2), Position = front + Vector3.new(27, 2.9, 2), Color = Color3.fromRGB(255, 196, 70), Material = Enum.Material.Metal })
	chestPrompt = prompt(base, "Daily gift", "Daily Login", handlers.Daily)
end

function Hub.SetDailyReady(ready)
	if chestPrompt then
		chestPrompt.ObjectText = if ready then "Daily Login - ready!" else "Daily Login"
	end
end

return Hub
