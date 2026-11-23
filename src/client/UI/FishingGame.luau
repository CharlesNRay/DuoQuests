--[[
	FishingGame (ModuleScript): the fishing mini-game at the Wishing Grove pond (Shared/Fishing on the server).
	Cast, wait for the bobber to dunk, then press REEL in time. The server checks the timing.

	  FishingGame.Start(root, api, hooks)   hooks = { Bobber(mode), Sound(name), OnCatch(info), StillNear() -> bool }
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local FishingGame = {}

local card = nil

local function close(hooks)
	if card then
		card:Destroy()
		card = nil
	end
	if hooks and hooks.Bobber then
		hooks.Bobber(nil)
	end
end

function FishingGame.Start(root, api, hooks)
	close(hooks)
	local frame = Kit.frame({ Name = "FishingGame", Size = UDim2.fromOffset(320, 150), Position = UDim2.new(0.5, -380, 1, -250), BackgroundColor3 = C.Bg, ZIndex = 30, Parent = root })
	card = frame
	Kit.new("UIStroke", { Color = Color3.fromRGB(120, 190, 240), Thickness = 2, Parent = frame })
	local title = Kit.label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 8), Text = "🎣 Fishing", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 210, 255), ZIndex = 31, Parent = frame })
	local text = Kit.label({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 36), Text = "Casting...", TextSize = 14, TextWrapped = true, ZIndex = 31, Parent = frame })
	local state = "idle" -- idle | waiting | bite | done
	local token = 0
	local button
	Kit.button({ Size = UDim2.fromOffset(90, 40), Position = UDim2.new(1, -100, 1, -50), Text = "Close", BackgroundColor3 = C.Panel, ZIndex = 31, Parent = frame }, function()
		token += 1
		close(hooks)
	end)
	local function setButton(label, active)
		button.Text = label
		button.BackgroundColor3 = if active then C.Accent else C.PanelLight
		button.TextColor3 = if active then Color3.fromRGB(30, 24, 10) else C.Text
	end
	local cast
	local function reel()
		if state ~= "waiting" and state ~= "bite" then
			return
		end
		state = "done"
		token += 1
		local ok, data = api:InvokeServer("FishReel")
		hooks.Bobber(nil)
		if ok and type(data) == "table" then
			title.Text = ("%s %s!"):format(data.Glyph or "🐟", data.Name or "A fish")
			if data.Paid and #(data.Reward or {}) > 0 then
				text.Text = ("+%s   (%d paid catches left today)"):format(table.concat(data.Reward, ", "), data.Left or 0)
			elseif data.Paid then
				text.Text = "Nothing in it but pond water. Try again!"
			else
				text.Text = "A fine catch! (No more paid catches today - it goes in your fish log.)"
			end
			hooks.Sound(if data.Paid and #(data.Reward or {}) > 0 then "Reward" else "Pop")
			if hooks.OnCatch then
				hooks.OnCatch(data)
			end
		else
			title.Text = "🎣 It got away..."
			text.Text = if data == "TooEarly" then "Too early! Wait for the bobber to dunk under." elseif data == "TooLate" then "Too slow! The fish stole the bait." else "Something went wrong. Try again."
		end
		setButton("Cast again", true)
	end
	function cast()
		if hooks.StillNear and not hooks.StillNear() then
			title.Text = "🎣 Fishing"
			text.Text = "Stand on the dock to fish."
			return
		end
		token += 1
		local mine = token
		state = "idle"
		title.Text = "🎣 Fishing"
		text.Text = "Casting..."
		local ok, data = api:InvokeServer("FishCast")
		if mine ~= token or not card then
			return
		end
		if not ok then
			text.Text = if data == "TooFar" then "Stand on the dock to fish." else "Could not cast. Try again."
			setButton("Cast", true)
			return
		end
		state = "waiting"
		hooks.Bobber("wait")
		hooks.Sound("Pop")
		text.Text = "Waiting for a bite... reel in when the bobber dunks!"
		setButton("REEL", false)
		task.delay(data.Wait or 3, function()
			if mine ~= token or state ~= "waiting" or not card then
				return
			end
			state = "bite"
			hooks.Bobber("bite")
			hooks.Sound("Coins")
			title.Text = "❗ BITE! ❗"
			text.Text = "Reel it in now!"
			setButton("REEL!", true)
		end)
	end
	button = Kit.button({ Size = UDim2.new(1, -120, 0, 40), Position = UDim2.new(0, 10, 1, -50), Text = "REEL", ZIndex = 31, Parent = frame }, function()
		if state == "waiting" or state == "bite" then
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
