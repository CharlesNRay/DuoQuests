--[[
	WishAnim (ModuleScript): the wishing sequence.
	  WishAnim.Play(parent, kind, rows, onDone) -> overlay Frame
	    parent   the Wishing Tree panel (the overlay covers it)
	    kind     "Pet" | "Skill"
	    rows     the wish results ({ Id, Rarity, New?, Upgrade?, Copies?, DupXP? })
	    onDone   called when the player closes it (or it closes itself)

	A star falls into the tree's light, pulses and shakes (its colour hints at the best thing you got), rings spread,
	then it bursts and the results flip face-up one at a time, rarest last. Rare and better pull a sparkle burst,
	Legendary also flashes gold and shakes the stage. Tap anywhere to skip ahead; tap again to close.
]]
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local Abilities = require(Shared.Config.Abilities)
local PetConfig = require(Shared.Config.Pets)

local WishAnim = {}

local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
local WHITE = Color3.fromRGB(255, 255, 255)

local function tween(inst, time, props, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- little diamonds that fly out from a point (offsets are pixels from the centre of `stage`)
local function sparkles(stage, cx, cy, color, count, distance, life)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.5
		local far = distance * (0.6 + math.random() * 0.6)
		local size = math.random(5, 10)
		local p = Kit.new("Frame", {
			Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BorderSizePixel = 0,
			BackgroundColor3 = if i % 3 == 0 then WHITE else color, Position = UDim2.new(0.5, cx, 0.5, cy), ZIndex = 35, Parent = stage,
		})
		tween(p, life, { Position = UDim2.new(0.5, cx + math.cos(angle) * far, 0.5, cy + math.sin(angle) * far), BackgroundTransparency = 1, Rotation = 225, Size = UDim2.fromOffset(2, 2) })
		task.delay(life + 0.05, function()
			p:Destroy()
		end)
	end
end

-- an expanding ring
local function ring(stage, cx, cy, color, size, life)
	local r = Kit.new("Frame", { Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, cx, 0.5, cy), ZIndex = 33, Parent = stage })
	Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = r })
	local stroke = Kit.new("UIStroke", { Color = color, Thickness = 3, Parent = r })
	tween(r, life, { Size = UDim2.fromOffset(size, size) })
	tween(stroke, life, { Transparency = 1, Thickness = 1 })
	task.delay(life + 0.05, function()
		r:Destroy()
	end)
end

local function look(kind, row)
	if kind == "Pet" then
		return (PetConfig.Defs[row.Id] or {}).DisplayName or row.Id
	end
	return (Abilities[row.Id] or {}).DisplayName or row.Id
end

local function tagText(row)
	if row.New then
		return "NEW!"
	elseif row.Upgrade then
		return "▲ " .. tostring(row.Rarity)
	elseif row.Copies then
		return "+1 copy"
	end
	if row.Shard then
		return "+" .. tostring(row.Shards or 1) .. " shard"
	end
	return ("+%d xp"):format(row.DupXP or 0)
end

function WishAnim.Play(parent, kind, rows, onDone)
	local best = "Common"
	for _, row in ipairs(rows) do
		if (RANK[row.Rarity] or 1) > RANK[best] then
			best = row.Rarity
		end
	end
	local bestColor = Kit.rarityColor(best)
	-- the first time a Legendary is found is the big moment: a longer, quieter build-up and a held reveal
	local firstLegend = false
	for _, row in ipairs(rows) do
		if row.Rarity == "Legendary" and row.New then
			firstLegend = true
		end
	end
	-- rarest last, so the best one is the finale
	local order = {}
	for index, row in ipairs(rows) do
		table.insert(order, { Row = row, Index = index })
	end
	table.sort(order, function(a, b)
		local ra, rb = RANK[a.Row.Rarity] or 1, RANK[b.Row.Rarity] or 1
		if ra ~= rb then
			return ra < rb
		end
		return a.Index < b.Index
	end)

	local overlay = Kit.new("Frame", { Name = "WishAnim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = if kind == "Pet" then Color3.fromRGB(6, 20, 18) else Color3.fromRGB(14, 10, 32), BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 30, ClipsDescendants = true, Active = true, Parent = parent })
	Kit.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = overlay })
	local stage = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 31, Parent = overlay })
	local flash = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 38, Parent = overlay })
	local hint = Kit.label({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 1, -26), Text = "Tap to skip", TextSize = 12, TextColor3 = Kit.Colors.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 39, Parent = overlay })
	local catcher = Kit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 45, Parent = overlay })

	local skipped, finished, closed = false, false, false
	local function pause(seconds)
		if not skipped and overlay.Parent then
			task.wait(seconds)
		end
	end
	local function alive()
		return overlay.Parent ~= nil and not closed
	end
	local function close()
		if closed then
			return
		end
		closed = true
		overlay:Destroy()
		if onDone then
			onDone()
		end
	end
	catcher.Activated:Connect(function()
		if finished then
			close()
		else
			skipped = true
		end
	end)

	task.spawn(function()
		-- 1. a star falls into the light, building up
		local orb = Kit.new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, -0.1, 0), ZIndex = 34, Parent = stage })
		local glow = Kit.new("UIStroke", { Color = Color3.fromRGB(150, 210, 255), Thickness = 3, Parent = orb })
		if not skipped then
			tween(orb, 0.85, { Position = UDim2.new(0.5, 0, 0.5, -10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for i = 1, 8 do
				if skipped or not alive() then
					break
				end
				local trail = Kit.new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = Color3.fromRGB(170, 220, 255), BorderSizePixel = 0, Position = orb.Position + UDim2.fromOffset(math.random(-8, 8), 0), ZIndex = 33, Parent = stage })
				tween(trail, 0.5, { BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2), Position = trail.Position + UDim2.fromOffset(math.random(-12, 12), 20) })
				task.delay(0.55, function()
					trail:Destroy()
				end)
				pause(0.1)
			end
		end
		if not alive() then
			return
		end
		-- 2. it gathers power: it grows, shakes and its colour moves towards the best result
		orb.Position = UDim2.new(0.5, 0, 0.5, -10)
		if not skipped then
			tween(orb, 1.1, { Size = UDim2.fromOffset(58, 58), BackgroundColor3 = bestColor }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(glow, 1.1, { Color = bestColor, Thickness = 8 })
			for i = 1, 3 do
				ring(stage, 0, -10, bestColor, 150 + i * 40, 0.5)
				for _ = 1, 3 do
					if skipped or not alive() then
						break
					end
					orb.Position = UDim2.new(0.5, math.random(-4, 4), 0.5, -10 + math.random(-4, 4))
					pause(0.06)
				end
				pause(0.1)
			end
		end
		if not alive() then
			return
		end
		-- 2b. first Legendary: everything goes quiet, the light turns gold and slowly beats
		if firstLegend and not skipped then
			local gold = Kit.Colors.Legendary
			hint.Text = "..."
			tween(overlay, 0.6, { BackgroundColor3 = Color3.fromRGB(14, 10, 4) })
			tween(orb, 1.2, { BackgroundColor3 = gold, Size = UDim2.fromOffset(74, 74) })
			tween(glow, 1.2, { Color = gold, Thickness = 12 })
			for beat = 1, 4 do
				if skipped or not alive() then
					break
				end
				ring(stage, 0, -10, gold, 120 + beat * 60, 0.9)
				orb.Position = UDim2.new(0.5, math.random(-2, 2), 0.5, -10 + math.random(-2, 2))
				pause(0.28 - beat * 0.04)
				sparkles(stage, 0, -10, gold, 4 + beat * 2, 40 + beat * 20, 0.8)
				pause(0.55 - beat * 0.08)
			end
			-- one held breath, then a very fast flicker before the burst
			pause(0.6)
			for _ = 1, 6 do
				if skipped or not alive() then
					break
				end
				flash.BackgroundColor3 = gold
				flash.BackgroundTransparency = 0.7
				pause(0.04)
				flash.BackgroundTransparency = 1
				pause(0.04)
			end
			hint.Text = "Tap to skip"
		end
		if not alive() then
			return
		end
		-- 3. burst
		orb:Destroy()
		flash.BackgroundColor3 = if RANK[best] >= 4 then Kit.Colors.Legendary else WHITE
		flash.BackgroundTransparency = if RANK[best] >= 3 then 0.2 else 0.55
		tween(flash, 0.45, { BackgroundTransparency = 1 })
		ring(stage, 0, -10, bestColor, 260, 0.6)
		sparkles(stage, 0, -10, bestColor, 18 + RANK[best] * 4, 150, 0.8)
		pause(0.35)
		if not alive() then
			return
		end

		-- 4. the results flip face-up one by one
		local n = #order
		local cols = math.min(n, 5)
		local rowsCount = math.ceil(n / cols)
		local big = n == 1
		local cw, ch = if big then 120 else 70, if big then 150 else 92
		local gap = 8
		local totalW = cols * (cw + gap) - gap
		local totalH = rowsCount * (ch + gap) - gap
		hint.Text = "Tap to skip"
		for i, entry in ipairs(order) do
			if not alive() then
				return
			end
			local row = entry.Row
			local rarity = row.Rarity or "Common"
			local color = Kit.rarityColor(rarity)
			local col, rowIndex = (i - 1) % cols, (i - 1) // cols
			local cx = -totalW / 2 + col * (cw + gap) + cw / 2
			local cy = -totalH / 2 + rowIndex * (ch + gap) + ch / 2 - 6
			local card = Kit.new("Frame", { Size = UDim2.fromOffset(cw, ch), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, cx, 0.5, cy - 30), BackgroundColor3 = Color3.fromRGB(34, 38, 60), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 36, Parent = stage })
			Kit.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
			local stroke = Kit.new("UIStroke", { Color = Kit.Colors.Common, Thickness = 2, Parent = card })
			local back = Kit.label({ Size = UDim2.fromScale(1, 1), Text = "?", TextSize = if big then 56 else 36, Font = Enum.Font.GothamBlack, TextColor3 = Kit.Colors.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 37, Parent = card })
			-- face (built now, shown after the flip)
			local face = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 37, Parent = card })
			local icon = cw - 18
			local props = { Size = UDim2.fromOffset(icon, icon), Position = UDim2.fromOffset(9, 8), Tier = rarity }
			if kind == "Pet" then
				Icons.Pet(face, row.Id, props)
			else
				local def = Abilities[row.Id]
				if def then
					Icons.Skill(face, def, props)
				end
			end
			Kit.label({ Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(2, ch - 38), Text = look(kind, row), TextSize = if big then 13 else 10, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 38, Parent = face })
			Kit.label({ Size = UDim2.new(1, -4, 0, 16), Position = UDim2.fromOffset(2, ch - 22), Text = tagText(row), TextSize = if big then 13 else 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextColor3 = if row.New or row.Upgrade then color else Kit.Colors.Dim, ZIndex = 38, Parent = face })

			-- drop in, then flip
			tween(card, 0.18, { Position = UDim2.new(0.5, cx, 0.5, cy) }, Enum.EasingStyle.Back)
			pause(0.2)
			if alive() and rarity == "Legendary" and row.New and not skipped then
				-- the card trembles face-down with a gold edge before it turns over
				stroke.Color = Kit.Colors.Legendary
				stroke.Thickness = 4
				back.TextColor3 = Kit.Colors.Legendary
				for beat = 1, 3 do
					if skipped or not alive() then
						break
					end
					ring(stage, cx, cy, Kit.Colors.Legendary, cw + 80, 0.7)
					pause(0.45)
				end
				pause(0.35)
			end
			if alive() then
				tween(card, 0.1, { Size = UDim2.fromOffset(0, ch) })
				pause(0.1)
				if alive() then
					back.Visible = false
					face.Visible = true
					stroke.Color = color
					stroke.Thickness = if RANK[rarity] >= 2 then 3 else 2
					tween(card, 0.22, { Size = UDim2.fromOffset(cw, ch) }, Enum.EasingStyle.Back)
					if RANK[rarity] >= 2 then
						ring(stage, cx, cy, color, cw + 60, 0.5)
						sparkles(stage, cx, cy, color, 6 + RANK[rarity] * 3, 60 + RANK[rarity] * 14, 0.7)
					end
					if RANK[rarity] >= 4 then
						flash.BackgroundColor3 = Kit.Colors.Legendary
						flash.BackgroundTransparency = 0.45
						tween(flash, 0.6, { BackgroundTransparency = 1 })
						if row.New then
							flash.BackgroundTransparency = 0.1
							tween(flash, 1.1, { BackgroundTransparency = 1 })
							sparkles(stage, cx, cy, Kit.Colors.Legendary, 36, 190, 1.2)
							ring(stage, cx, cy, WHITE, cw + 220, 0.9)
							Kit.label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 10), Text = "✦  NEW LEGENDARY  ✦", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = Kit.Colors.Legendary, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 40, Parent = stage })
						end
						for _ = 1, if row.New then 10 else 5 do
							if skipped or not alive() then
								break
							end
							stage.Position = UDim2.fromOffset(math.random(-5, 5), math.random(-5, 5))
							pause(0.04)
						end
						stage.Position = UDim2.new()
					end
				end
			end
			pause(if n > 5 then 0.1 else 0.22)
		end
		if not alive() then
			return
		end
		finished = true
		hint.Text = "Tap to continue"
		hint.TextColor3 = Kit.Colors.Text
		-- closes by itself quickly, so the Wish buttons underneath are never blocked for long (the results stay in the panel)
		task.delay(1.6, function()
			if alive() then
				close()
			end
		end)
	end)

	return overlay
end

return WishAnim
