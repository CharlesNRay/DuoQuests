--[[
	DummyScreen (ModuleScript): results of the training dummy test (handler TrainDummy -> Shared/TrainingDummy).
	extra.Dummy = the last result { Seconds, Total, Rows = { { Name, DPS, Damage } }, Best } or nil while it runs;
	extra.RunDummy() runs it again.

	  DummyScreen.Dummy(container, state, call, extra)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Short = require(ReplicatedStorage:WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local DummyScreen = {}

function DummyScreen.Dummy(container, state, _, extra)
	Kit.clear(container)
	local result = extra.Dummy
	local head = Kit.frame({ Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = C.PanelLight, Parent = container })
	if not result then
		Kit.label({ Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 3), Text = "🎯 Your party is hitting the dummy for 20 seconds...", TextSize = 16, Font = Enum.Font.GothamBold, Parent = head })
		return
	end
	Kit.label({ Size = UDim2.new(1, -170, 0, 26), Position = UDim2.fromOffset(10, 4), Text = ("🎯 Party damage: %s per second"):format(Short(result.Total)), TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = head })
	local best = math.max(result.Best or 0, state.Player.DummyBest or 0)
	Kit.label({ Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(10, 30), Text = if result.Total >= best then "A new personal best!" else ("Your best: %s per second"):format(Short(best)), TextSize = 13, TextColor3 = if result.Total >= best then C.Good else C.Dim, Parent = head })
	-- "Test again" counts down while the dummy recovers (8 s between tests), so a quick press never blanks the results
	local again = Kit.button({ Size = UDim2.fromOffset(140, 40), Position = UDim2.new(1, -150, 0.5, -20), Text = "Test again", BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), Parent = head }, function()
		if extra.RunDummy and not (extra.DummyReadyAt and os.clock() < extra.DummyReadyAt) then
			extra.RunDummy()
		end
	end)
	local function tick()
		local left = if extra.DummyReadyAt then math.ceil(extra.DummyReadyAt - os.clock()) else 0
		if left > 0 then
			again.Text = ("Again in %ds"):format(left)
			again.BackgroundColor3 = C.Panel
			again.TextColor3 = C.Dim
		else
			again.Text = "Test again"
			again.BackgroundColor3 = C.Accent
			again.TextColor3 = Color3.fromRGB(30, 24, 10)
		end
		return left > 0
	end
	if tick() then
		task.spawn(function()
			while again.Parent and tick() do
				task.wait(0.25)
			end
		end)
	end
	if result.Error then
		Kit.label({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 64), Text = result.Error, TextSize = 14, TextColor3 = C.Dim, Parent = container })
	end
	local top = (result.Rows[1] and result.Rows[1].DPS) or 1
	for index, row in ipairs(result.Rows) do
		local r = Kit.frame({ Size = UDim2.new(1, -8, 0, 32), Position = UDim2.fromOffset(0, 62 + (index - 1) * 36), BackgroundColor3 = C.Panel, Parent = container })
		Kit.label({ Size = UDim2.fromOffset(160, 32), Position = UDim2.fromOffset(10, 0), Text = row.Name, TextSize = 14, Font = Enum.Font.GothamBold, Parent = r })
		local track = Kit.frame({ Size = UDim2.new(1, -300, 0, 14), Position = UDim2.new(0, 175, 0.5, -7), BackgroundColor3 = Color3.fromRGB(30, 34, 52), Parent = r })
		Kit.frame({ Size = UDim2.fromScale(math.clamp(row.DPS / math.max(top, 1), 0.02, 1), 1), BackgroundColor3 = if index == 1 then C.Accent else Color3.fromRGB(120, 170, 240), Parent = track })
		Kit.label({ Size = UDim2.fromOffset(110, 32), Position = UDim2.new(1, -118, 0, 0), Text = Short(row.DPS) .. "/s", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
	end
	Kit.label({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 1, -20), Text = "The dummy has no armour and never hits back: this is your party's raw damage. Pets and summons count for their owner.", TextSize = 11, TextColor3 = C.Dim, Parent = container })
end

return DummyScreen
