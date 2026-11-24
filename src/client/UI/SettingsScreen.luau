--[[
	SettingsScreen (ModuleScript): sound settings (master, music, effects, interface), each 0-100% in steps of 10, a
	mute switch, the HUD size (70-130%, extra.SetHudScale: the HUD only, panels keep their size) and the Main menu button. Changes apply at once (Sound.Apply) and are saved on the server (handler SaveSettings) a moment later.

	  SettingsScreen.Settings(container, state, call, extra)
]]
local Kit = require(script.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local C = Kit.Colors

local SettingsScreen = {}

local ROWS = {
	{ Key = "Master", Label = "Master volume", Hint = "Everything" },
	{ Key = "Music", Label = "Music", Hint = "Town, battle, dungeon and boss themes" },
	{ Key = "Effects", Label = "Battle sounds", Hint = "Hits, spells, heals, bosses" },
	{ Key = "Interface", Label = "Interface", Hint = "Clicks, rewards, level-ups" },
}

local saveToken = 0

function SettingsScreen.Settings(container, state, _, extra)
	Kit.clear(container)
	local values = Sound.Settings()
	local function save()
		Sound.Apply(values)
		saveToken += 1
		local mine = saveToken
		task.delay(0.6, function() -- one save after the clicks stop
			if mine == saveToken and extra.SaveSettings then
				values.HudScale = if extra.HudScale then extra.HudScale() else nil
				extra.SaveSettings(values)
			end
		end)
	end
	local list = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = list })
	Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = "🔊 Sound", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, Parent = list })
	local redraw
	local bars = {}
	for _, r in ipairs(ROWS) do
		local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.PanelLight, Parent = list })
		Kit.label({ Size = UDim2.fromOffset(170, 20), Position = UDim2.fromOffset(10, 2), Text = r.Label, TextSize = 15, Font = Enum.Font.GothamBold, Parent = row })
		Kit.label({ Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(10, 21), Text = r.Hint, TextSize = 11, TextColor3 = C.Dim, Parent = row })
		local track = Kit.frame({ Size = UDim2.new(1, -400, 0, 12), Position = UDim2.new(0, 220, 0.5, -6), BackgroundColor3 = Color3.fromRGB(30, 34, 52), Parent = row })
		local fill = Kit.frame({ Size = UDim2.fromScale(values[r.Key], 1), BackgroundColor3 = C.Accent, Parent = track })
		local pct = Kit.label({ Size = UDim2.fromOffset(50, 22), Position = UDim2.new(1, -170, 0.5, -11), Text = "", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		bars[r.Key] = { Fill = fill, Pct = pct }
		Kit.button({ Size = UDim2.fromOffset(44, 34), Position = UDim2.new(1, -116, 0.5, -17), Text = "-", TextSize = 20, Parent = row }, function()
			values[r.Key] = math.max(0, math.floor(values[r.Key] * 10 + 0.5) / 10 - 0.1)
			save()
			redraw()
		end)
		Kit.button({ Size = UDim2.fromOffset(44, 34), Position = UDim2.new(1, -62, 0.5, -17), Text = "+", TextSize = 20, Parent = row }, function()
			values[r.Key] = math.min(1, math.floor(values[r.Key] * 10 + 0.5) / 10 + 0.1)
			save()
			redraw()
		end)
	end
	local muteRow = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.PanelLight, Parent = list })
	local muteButton = Kit.button({ Size = UDim2.fromOffset(190, 32), Position = UDim2.fromOffset(10, 4), Text = "", Parent = muteRow }, function()
		if values.Master > 0 then
			values.SavedMaster = values.Master
			values.Master = 0
		else
			values.Master = values.SavedMaster or 0.8
		end
		save()
		redraw()
	end)
	Kit.label({ Size = UDim2.new(1, -220, 0, 32), Position = UDim2.fromOffset(212, 4), Text = "Settings are saved with your account.", TextSize = 12, TextColor3 = C.Dim, Parent = muteRow })
	-- HUD size: everything on screen grows or shrinks (the panel too, so you see it at once)
	if extra.SetHudScale then
		local hudRow = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.PanelLight, Parent = list })
		Kit.label({ Size = UDim2.fromOffset(170, 20), Position = UDim2.fromOffset(10, 2), Text = "HUD size", TextSize = 15, Font = Enum.Font.GothamBold, Parent = hudRow })
		Kit.label({ Size = UDim2.fromOffset(240, 16), Position = UDim2.fromOffset(10, 21), Text = "The HUD: buttons, cards and the skill bar", TextSize = 11, TextColor3 = C.Dim, Parent = hudRow })
		local pct = Kit.label({ Size = UDim2.fromOffset(60, 34), Position = UDim2.new(1, -180, 0.5, -17), Text = "", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = hudRow })
		local function show()
			pct.Text = ("%d%%"):format(math.floor(extra.HudScale() * 100 + 0.5))
		end
		local function step(by)
			extra.SetHudScale(extra.HudScale() + by)
			show()
			save()
		end
		Kit.button({ Size = UDim2.fromOffset(44, 34), Position = UDim2.new(1, -116, 0.5, -17), Text = "-", TextSize = 20, Parent = hudRow }, function()
			step(-0.1)
		end)
		Kit.button({ Size = UDim2.fromOffset(44, 34), Position = UDim2.new(1, -62, 0.5, -17), Text = "+", TextSize = 20, Parent = hudRow }, function()
			step(0.1)
		end)
		show()
	end
	-- back to the main menu (switch character, make a new one); the only way there once you are in the game
	if extra.OpenMenu then
		local menuRow = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.PanelLight, Parent = list })
		Kit.button({ Name = "MainMenuButton", Size = UDim2.fromOffset(190, 32), Position = UDim2.fromOffset(10, 4), Text = "🏠 Main menu", BackgroundColor3 = C.Accent, TextColor3 = C.Bg, Parent = menuRow }, function()
			extra.OpenMenu()
		end)
		Kit.label({ Size = UDim2.new(1, -220, 0, 34), Position = UDim2.fromOffset(212, 6), Text = "Switch character or make a new one. Your fights keep going.", TextSize = 12, TextWrapped = true, TextColor3 = C.Dim, Parent = menuRow })
	end
	redraw = function()
		for key, bar in pairs(bars) do
			bar.Fill.Size = UDim2.fromScale(math.clamp(values[key], 0, 1), 1)
			bar.Pct.Text = ("%d%%"):format(math.floor(values[key] * 100 + 0.5))
		end
		muteButton.Text = if values.Master > 0 then "🔇 Mute all" else "🔊 Unmute"
		muteButton.BackgroundColor3 = if values.Master > 0 then C.PanelLight else C.Accent
	end
	redraw()
end

return SettingsScreen
