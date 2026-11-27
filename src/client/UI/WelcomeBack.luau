--[[
	WelcomeBack (ModuleScript): the "while you were away" card shown once after entering the game.

	The server pays everything at login (Party.Claim) and keeps the result as state.LastClaim:
	  CatchUp = { Stages, Gold, XP, Shards, SkillPicks, LevelsGained }   stages your party cleared while you were gone
	  Afk     = { Gold, XP, Shards, Fights, Seconds, Stage, LevelsGained } the AFK farming while everyone was offline
	  At      = os.time() of the claim (so the same claim is only shown once)

	  waiting = { { glyph, text, onClick? } }   things ready for you now (an expedition back, the daily chest), listed under
	                                           the rewards; with onClick the line is a button (closes the card, then calls it)

	  WelcomeBack.Worth(claim, waiting)        -> true when there is anything to show
	  WelcomeBack.Show(root, claim, waiting)   the card (stays until Nice! is pressed)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Short = require(ReplicatedStorage:WaitForChild("Shared").Util.NumberFormat).Short
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local WelcomeBack = {}

local open = nil

local function duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm"):format(math.max(1, m))
end

function WelcomeBack.Worth(claim, waiting)
	if waiting and #waiting > 0 then
		return true
	end
	if type(claim) ~= "table" then
		return false
	end
	local afk, catch = claim.Afk, claim.CatchUp
	return (afk ~= nil and ((afk.Gold or 0) > 0 or (afk.XP or 0) > 0)) or (catch ~= nil and (catch.Stages or 0) > 0)
end

function WelcomeBack.Show(root, claim, waiting)
	waiting = waiting or {}
	if open then
		open:Destroy()
	end
	local afk, catch = claim.Afk, claim.CatchUp
	local earned = WelcomeBack.Worth(claim, nil)
	local gold = (afk and afk.Gold or 0) + (catch and catch.Gold or 0)
	local xp = (afk and afk.XP or 0) + (catch and catch.XP or 0)
	local shards = (afk and afk.Shards or 0) + (catch and catch.Shards or 0)
	local levels = (afk and afk.LevelsGained or 0) + (catch and catch.LevelsGained or 0)

	local card = Kit.frame({ Name = "WelcomeBack", Size = UDim2.fromOffset(400, 252), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), BackgroundColor3 = C.Panel, ZIndex = 60, Parent = root })
	open = card
	Kit.new("UIStroke", { Color = C.Accent, Thickness = 2, Parent = card })
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	Kit.label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 10), Text = "🌙 Welcome back!", TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 61, Parent = card })
	local intro
	if afk and (afk.Seconds or 0) > 0 then
		intro = ("Your party kept fighting while you were away: %s fights on stage %d."):format(Short(afk.Fights or 0), afk.Stage or 1)
	elseif earned then
		intro = "Your party kept going while you were away."
	else
		intro = "Some things are waiting for you."
	end
	Kit.label({ Size = UDim2.new(1, -30, 0, 36), Position = UDim2.fromOffset(15, 42), Text = intro, TextSize = 13, TextColor3 = C.Dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 61, Parent = card })

	-- the rewards, one row each
	local rows = {}
	if earned then
		table.insert(rows, { "🪙", "Gold", "+" .. Short(gold) })
		table.insert(rows, { "⭐", "XP", "+" .. Short(xp) })
	end
	if shards > 0 then
		table.insert(rows, { "💎", "Shards", "+" .. Short(shards) })
	end
	if levels > 0 then
		table.insert(rows, { "⬆", "Levels", "+" .. tostring(levels) })
	end
	if catch and (catch.Stages or 0) > 0 then
		table.insert(rows, { "🏁", "New stages cleared by your party", tostring(catch.Stages) })
	end
	local list = Kit.frame({ Size = UDim2.new(1, -40, 0, #rows * 24), Position = UDim2.fromOffset(20, 82), BackgroundTransparency = 1, NoCorner = true, ZIndex = 61, Parent = card })
	for i, row in ipairs(rows) do
		local y = (i - 1) * 24
		Kit.label({ Size = UDim2.new(0.7, 0, 0, 22), Position = UDim2.fromOffset(0, y), Text = row[1] .. "  " .. row[2], TextSize = 15, Font = Enum.Font.GothamBold, ZIndex = 62, Parent = list })
		Kit.label({ Size = UDim2.new(0.3, 0, 0, 22), Position = UDim2.new(0.7, 0, 0, y), Text = row[3], TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 62, Parent = list })
	end
	-- what is waiting for you now
	local wy = 82 + #rows * 24 + (if #rows > 0 then 6 else 0)
	for i, w in ipairs(waiting) do
		if type(w[3]) == "function" then
			-- a line with somewhere to go: a button that closes the card and opens it
			Kit.button({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, wy + (i - 1) * 24), Text = w[1] .. "  " .. w[2] .. "  >", TextSize = 13, Font = Enum.Font.GothamBold, BackgroundColor3 = C.PanelLight, TextColor3 = C.Accent, ZIndex = 62, Parent = card }, function()
				if open == card then
					open = nil
				end
				card:Destroy()
				w[3]()
			end)
		else
			Kit.label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, wy + (i - 1) * 24), Text = w[1] .. "  " .. w[2], TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.Accent, TextWrapped = true, ZIndex = 62, Parent = card })
		end
	end
	card.Size = UDim2.fromOffset(400, wy + #waiting * 24 + 70)

	local foot = if afk and (afk.Seconds or 0) > 0 then ("Away %s. Away fights pay less the longer you are gone."):format(duration(afk.Seconds)) else ""
	Kit.label({ Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 1, -62), Text = foot, TextSize = 11, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 61, Parent = card })
	Kit.button({ Size = UDim2.fromOffset(140, 36), Position = UDim2.new(0.5, -70, 1, -44), Text = "Nice!", BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(30, 24, 10), ZIndex = 62, Parent = card }, function()
		if open == card then
			open = nil
		end
		card:Destroy()
	end)
	return card
end

return WelcomeBack
