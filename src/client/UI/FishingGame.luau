--[[
	FishingGame (ModuleScript): the fishing skill check at the Wishing Grove pond (Shared/Fishing on the server).
	Cast, wait for the bobber to dunk; then a needle sweeps round a dial - press REEL while it is in the gold zone.
	If it makes its laps without a press, the fish gets away and you cast again. The server checks the timing.

	  FishingGame.Start(root, api, hooks)   hooks = { Bobber(mode), Sound(name), OnCatch(info), StillNear() -> bool }
]]
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local FishingGame = {}

local card, spinConn = nil, nil
local DIAL = 124

local function stopSpin()
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
end

local function close(hooks)
	stopSpin()
	if card then
		card:Destroy()
		card = nil
	end
	if hooks and hooks.Bobber then
		hooks.Bobber(nil)
	end
end

function FishingGame.Start(root, api, hooks)
	if card then
		return -- already fishing: the prompt can fire again while the card is up
	end
	local frame = Kit.frame({ Name = "FishingGame", Size = UDim2.fromOffset(330, 200), Position = UDim2.new(0.5, -165, 0, 70), BackgroundColor3 = C.Bg, ZIndex = 30, Parent = root })
	card = frame
	Kit.new("UIStroke", { Color = Color3.fromRGB(120, 190, 240), Thickness = 2, Parent = frame })
	local title = Kit.label({ Size = UDim2.new(1, -DIAL - 30, 0, 26), Position = UDim2.fromOffset(12, 8), Text = "🎣 Fishing", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 210, 255), ZIndex = 31, Parent = frame })
	local text = Kit.label({ Size = UDim2.new(1, -DIAL - 30, 0, 80), Position = UDim2.fromOffset(12, 36), Text = "Casting...", TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31, Parent = frame })

	-- the dial: a ring, the gold zone round its rim, and a needle that sweeps clockwise from the top
	local dial = Kit.frame({ Size = UDim2.fromOffset(DIAL, DIAL), Position = UDim2.new(1, -DIAL - 12, 0, 12), BackgroundColor3 = Color3.fromRGB(24, 30, 48), NoCorner = true, ZIndex = 31, Parent = frame })
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dial })
	Kit.new("UIStroke", { Color = Color3.fromRGB(120, 190, 240), Thickness = 2, Parent = dial })
	local zoneDots = {}
	local function drawZone(zone, width)
		for _, d in ipairs(zoneDots) do
			d:Destroy()
		end
		zoneDots = {}
		if not zone then
			return
		end
		for deg = zone, zone + width, 3 do
			local a = math.rad(deg)
			local r = DIAL / 2 - 9
			local dot = Kit.frame({ Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r), BackgroundColor3 = Color3.fromRGB(255, 200, 70), NoCorner = true, ZIndex = 32, Parent = dial })
			Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
			table.insert(zoneDots, dot)
		end
	end
	-- the needle lives in a dial-sized holder that rotates round the dial's centre
	local holder = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, ZIndex = 33, Parent = dial })
	Kit.frame({ Size = UDim2.fromOffset(4, DIAL / 2 - 6), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 34, Parent = holder })
	local hub = Kit.frame({ Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(230, 60, 60), NoCorner = true, ZIndex = 35, Parent = dial })
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hub })
	holder.Visible = false

	local state = "idle" -- idle | waiting | spinning | done
	local token = 0
	local spinStart, info = nil, nil
	local button
	Kit.button({ Size = UDim2.fromOffset(90, 44), Position = UDim2.new(1, -102, 1, -54), Text = "Close", BackgroundColor3 = C.Panel, ZIndex = 31, Parent = frame }, function()
		token += 1
		close(hooks)
	end)
	local function setButton(label, active)
		button.Text = label
		button.BackgroundColor3 = if active then C.Accent else C.PanelLight
		button.TextColor3 = if active then Color3.fromRGB(30, 24, 10) else C.Text
	end
	local function finish()
		state = "done"
		stopSpin()
		hooks.Bobber(nil)
		setButton("Cast again", true)
	end
	local function reel()
		local elapsed = if spinStart then os.clock() - spinStart else 0
		local wasSpinning = state == "spinning"
		finish()
		token += 1
		local ok, data = api:InvokeServer("FishReel", elapsed)
		if ok and type(data) == "table" then
			title.Text = ("%s %s!"):format(data.Glyph or "🐟", data.Name or "A fish")
			if data.Paid and #(data.Reward or {}) > 0 then
				text.Text = ("+%s\n(%d paid catches left today)"):format(table.concat(data.Reward, ", "), data.Left or 0)
			elseif data.Paid then
				text.Text = "Nothing in it but pond water. Try again!"
			else
				text.Text = "A fine catch! No more paid catches today - it goes in your fish log."
			end
			hooks.Sound(if data.Paid and #(data.Reward or {}) > 0 then "Reward" else "Pop")
			if hooks.OnCatch then
				hooks.OnCatch(data)
			end
		else
			title.Text = "🎣 It got away..."
			text.Text = if data == "TooEarly" or not wasSpinning then "Too early! Wait for the bobber to dunk under."
				elseif data == "Missed" then "Missed! Press REEL while the needle is in the gold."
				else "Too slow! The fish stole the bait."
			hooks.Sound("Defeat")
		end
	end
	local function cast()
		if hooks.StillNear and not hooks.StillNear() then
			title.Text = "🎣 Fishing"
			text.Text = "Stand on the dock to fish."
			return
		end
		token += 1
		local mine = token
		state = "idle"
		spinStart = nil
		holder.Visible = false
		drawZone(nil)
		title.Text = "🎣 Fishing"
		text.Text = "Casting..."
		local ok, data = api:InvokeServer("FishCast")
		if mine ~= token or card ~= frame then
			return
		end
		if not ok then
			text.Text = if data == "TooFar" then "Stand on the dock to fish." else "Could not cast. Try again."
			setButton("Cast", true)
			return
		end
		info = data
		state = "waiting"
		hooks.Bobber("wait")
		hooks.Sound("Pop")
		text.Text = "Waiting for a bite...\nWhen it bites, press REEL while the needle is in the gold."
		setButton("REEL", false)
		task.delay(data.Wait or 3, function()
			if mine ~= token or state ~= "waiting" or card ~= frame then
				return
			end
			state = "spinning"
			hooks.Bobber("bite")
			hooks.Sound("Coins")
			title.Text = "❗ BITE! ❗"
			text.Text = "Press REEL in the gold!"
			setButton("REEL!", true)
			drawZone(info.Zone, info.ZoneWidth)
			holder.Visible = true
			holder.Rotation = 0
			spinStart = os.clock()
			local limit = (info.Laps or 2) * 360 / (info.Speed or 220)
			spinConn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - spinStart
				holder.Rotation = (t * (info.Speed or 220)) % 360
				if t > limit and state == "spinning" then
					finish()
					title.Text = "🎣 It got away..."
					text.Text = "Too slow! The fish stole the bait. Cast again."
					hooks.Sound("Defeat")
					-- tell the server, so the cast is used up
					task.spawn(function()
						api:InvokeServer("FishReel", t)
					end)
				end
			end)
		end)
	end
	button = Kit.button({ Size = UDim2.new(1, -126, 0, 44), Position = UDim2.new(0, 12, 1, -54), Text = "REEL", ZIndex = 31, Parent = frame }, function()
		if state == "waiting" or state == "spinning" then
			reel()
		else
			cast()
		end
	end)
	cast()
end

function FishingGame.Close(hooks)
	close(hooks)
end

function FishingGame.IsOpen()
	return card ~= nil
end

return FishingGame
