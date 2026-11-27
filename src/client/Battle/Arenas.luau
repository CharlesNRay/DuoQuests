--[[
	Arenas (ModuleScript): every party's battle pad in the shared world.

	The server tells us which parties are on this server and which arena slot each
	one fights in (WorldService). We build a Scene + Replay for each slot, keep an
	info card above it, and replay fights as they happen: your own party's through
	the normal "Fight" push, everyone else's through "ArenaFight" (only when you
	are close enough to see it).

	  local arenas = Arenas.new(localUserId)
	  arenas:Apply(snapshot)            snapshot = WorldService.Snapshot()
	  arenas:Play(slot, info, onDone)   draw a fight in a slot
	  arenas:MySlot()                   slot of the party you are in (or nil)
	  arenas:OriginOf(slot)             CFrame of the arena (centre + turn; .Position is the centre)
	  arenas.OnBanner                   optional function(text, color) for YOUR arena's callouts
	  arenas.OnInspect                  optional function(userId): a hero was clicked
	  arenas.OnWatch                    optional function(slot, origin): the "Watch battle" pad was used
	                                    (every arena has one in front of it; yours reads "Battle view")
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Zones = require(Shared.Zones)
local Stages = require(Shared.Stages)
local PetConfig = require(Shared.Config.Pets)
local Kit = require(script.Parent.Parent.UI.Kit)
local Scene = require(script.Parent.Scene)
local Replay = require(script.Parent.Replay)

local Arenas = {}
Arenas.__index = Arenas

local WATCH_DISTANCE = 170 -- studs; farther arenas are not animated

function Arenas.new(localUserId)
	return setmetatable({ UserId = localUserId, BySlot = {}, Mine = nil }, Arenas)
end

function Arenas:OriginOf(slot)
	local x, y, z, yaw = World.ArenaOrigin(slot)
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- the zone theme (Config/Zones entry) an arena is showing, or nil
function Arenas:ThemeOf(slot)
	local arena = self.BySlot[slot]
	return arena and arena.Theme
end

function Arenas:MySlot()
	return self.Mine
end

-- The battle card over a lot (owner 2026-11-24 mockup): a header bar (zone left, big STAGE right) and a table of the
-- party with aligned columns HERO | LV | CLASS | PET, a class colour dot and a small "ghost" tag. It floats high over the
-- front of the lot so the damage numbers pop below it instead of over it.
local CARD_W = 340
local HEAD_H, COLS_H, ROW_H = 34, 18, 26
local CARD_GOLD = Color3.fromRGB(242, 193, 78)

local function cardLabel(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	for key, value in pairs(props) do
		t[key] = value
	end
	return t
end

local buildCard -- defined below makeCard

local function makeCard(origin)
	local anchor = Instance.new("Part")
	anchor.Name = "ArenaCard"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = origin:PointToWorldSpace(Vector3.new(0, 24, World.ARENA_DEPTH / 2 + 3))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(CARD_W, HEAD_H + COLS_H + 4 * ROW_H + 10)
	gui.MaxDistance = 160 -- the homes street: you read the lots' cards walking by (constant size on screen)
	gui.Adornee = anchor
	gui.Parent = anchor
	local card = buildCard(gui)
	card.Gui = gui
	return anchor, card
end

-- the card itself (header, column headings, rows) inside `parent` (a BillboardGui, or the screen panel)
buildCard = function(parent)
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	frame.BackgroundTransparency = 0.1
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = CARD_GOLD
	stroke.Thickness = 2
	-- header: zone on the left, the stage big on the right, a line under it
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.Size = UDim2.new(1, 0, 0, HEAD_H)
	head.BackgroundColor3 = CARD_GOLD
	head.BackgroundTransparency = 0.84
	head.Parent = frame
	Instance.new("UICorner", head).CornerRadius = UDim.new(0, 12)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.fromOffset(0, HEAD_H)
	line.BackgroundColor3 = CARD_GOLD
	line.BackgroundTransparency = 0.5
	line.BorderSizePixel = 0
	line.Parent = frame
	cardLabel({ Name = "Zone", Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.fromOffset(12, 0), TextColor3 = Color3.fromRGB(216, 220, 239), Font = Enum.Font.GothamMedium, Parent = head })
	cardLabel({ Name = "Stage", Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 215, 106), Font = Enum.Font.GothamBlack, TextSize = 18, Parent = head })
	-- column headings
	local dim = Color3.fromRGB(141, 147, 179)
	local function heading(text, x, w, right)
		cardLabel({ Text = text, Size = UDim2.fromOffset(w, COLS_H), Position = UDim2.fromOffset(x, HEAD_H + 3), TextColor3 = dim, TextSize = 11, Font = Enum.Font.GothamBlack, TextXAlignment = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left, Parent = frame })
	end
	heading("HERO", 35, 110)
	heading("LV", 150, 40, true)
	heading("CLASS", 204, 70)
	heading("PET", 276, 60)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(0, HEAD_H + COLS_H + 3)
	rows.Size = UDim2.new(1, 0, 1, -(HEAD_H + COLS_H + 3))
	rows.Parent = frame
	return { Frame = frame, Rows = rows }
end

-- A wooden sign at the lot's street edge saying whose home it is, facing the street (owner 2026-11-24), so people
-- walking by read it without walking up to the lot.
local function makeOwnerSign(origin)
	local folder = Instance.new("Folder")
	folder.Name = "OwnerSign"
	local base = origin * CFrame.new(-World.ARENA_WIDTH / 2 + 10, 0, World.ARENA_DEPTH / 2 + 3)
	local function piece(name, size, cf, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Parent = folder
		return p
	end
	local wood = Color3.fromRGB(120, 84, 52)
	piece("PostL", Vector3.new(0.5, 7, 0.5), base * CFrame.new(-4.2, 3.5, 0), wood, Enum.Material.Wood)
	piece("PostR", Vector3.new(0.5, 7, 0.5), base * CFrame.new(4.2, 3.5, 0), wood, Enum.Material.Wood)
	local board = piece("Board", Vector3.new(9.4, 3.2, 0.35), base * CFrame.new(0, 5.6, 0), Color3.fromRGB(88, 62, 40), Enum.Material.WoodPlanks)
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(300, 100)
		gui.LightInfluence = 0.2
		gui.Parent = board
		-- the owner's name big on top, "with ..." (the rest of the party) smaller underneath
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -36, 0.56, -6)
		name.Position = UDim2.fromOffset(18, 6)
		name.BackgroundTransparency = 1
		name.TextScaled = true
		name.Font = Enum.Font.GothamBlack
		name.TextColor3 = Color3.fromRGB(255, 232, 180)
		name.Text = ""
		name.Parent = gui
		local rest = Instance.new("TextLabel")
		rest.Size = UDim2.new(1, -44, 0.3, 0)
		rest.Position = UDim2.new(0, 22, 0.6, 0)
		rest.BackgroundTransparency = 1
		rest.TextScaled = true
		rest.Font = Enum.Font.GothamMedium
		rest.TextColor3 = Color3.fromRGB(225, 205, 165)
		rest.Text = ""
		rest.Parent = gui
		table.insert(labels, { Name = name, Rest = rest })
	end
	folder.Parent = workspace
	return folder, labels
end

-- -> big line (whose home), small line (the rest of the party)
local function ownerText(party)
	local first = party.Members[1]
	if not first then
		return "Empty lot", ""
	end
	local others = {}
	for index = 2, #party.Members do
		table.insert(others, party.Members[index].Name)
	end
	return ("%s's home"):format(first.Name), if #others > 0 then "with " .. table.concat(others, ", ") else ""
end

-- A gold pad in front of the arena with a "Watch battle" prompt: step up to it and
-- use it to snap the camera to that fight (anyone can watch anyone).
local function makePad(origin)
	local pad = Instance.new("Part")
	pad.Name = "WatchPad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, 5, 5)
	pad.CFrame = origin * CFrame.new(0, 0.2, World.ARENA_DEPTH / 2 + 6) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = Color3.fromRGB(255, 196, 70)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.25
	pad.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "IdlePartyWatch"
	prompt.ActionText = "Watch battle"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = pad
	return pad, prompt
end

function Arenas:_get(slot)
	local arena = self.BySlot[slot]
	if arena then
		return arena
	end
	local origin = self:OriginOf(slot)
	local scene = Scene.new(origin)
	local anchor, label = makeCard(origin)
	local pad, prompt = makePad(origin)
	local signFolder, signLabels = makeOwnerSign(origin)
	arena = { Slot = slot, Scene = scene, Replay = Replay.new(scene), Anchor = anchor, Label = label, Pad = pad, Prompt = prompt, Sign = signFolder, SignLabels = signLabels, Fighting = false, Zone = nil }
	prompt.Triggered:Connect(function()
		if self.OnWatch then
			self.OnWatch(slot, origin)
		end
	end)
	self.BySlot[slot] = arena
	return arena
end

local function distanceTo(origin)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - origin).Magnitude or 0
end

local function rosterOf(party)
	local roster = {}
	for _, member in ipairs(party.Members) do
		table.insert(roster, {
			Id = tostring(member.UserId),
			Name = member.Online and member.Name or (member.Name .. " (ghost)"),
			Team = "Party",
			Ghost = not member.Online,
			DefId = member.ClassId,
			PetId = member.PetId,
			MaxHealth = 100,
			UserId = member.UserId,
		})
	end
	return roster
end

local function fillCard(card, party, zone)
	local head = card.Frame.Head
	head.Zone.Text = zone.Name
	local boss = Stages.IsBoss(party.Stage)
	head.Stage.Text = ("STAGE %d%s"):format(party.Stage, if boss then " BOSS" else "")
	head.Stage.TextColor3 = if boss then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(255, 215, 106)
	for _, child in ipairs(card.Rows:GetChildren()) do
		child:Destroy()
	end
	for i, member in ipairs(party.Members) do
		local y = (i - 1) * ROW_H
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.Position = UDim2.fromOffset(0, y)
		row.Parent = card.Rows
		-- a real player's Roblox headshot ringed in their class colour; companions (ids below 0) a class colour dot
		local classColor = Kit.Colors[member.ClassId] or Color3.fromRGB(200, 200, 200)
		local userId = tonumber(member.UserId) or 0
		if userId > 0 then
			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.fromOffset(20, 20)
			icon.Position = UDim2.fromOffset(9, (ROW_H - 20) / 2)
			icon.BackgroundColor3 = Color3.fromRGB(40, 44, 64)
			icon.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(userId)
			icon.Parent = row
			Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
			local ring = Instance.new("UIStroke", icon)
			ring.Color = classColor
			ring.Thickness = 2
		else
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(10, 10)
			dot.Position = UDim2.fromOffset(14, (ROW_H - 10) / 2)
			dot.BackgroundColor3 = classColor
			dot.Parent = row
			Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		end
		local nameX = 35
		local name = cardLabel({ Text = member.Name, Size = UDim2.fromOffset(if member.Online then 108 else 76, ROW_H), Position = UDim2.fromOffset(nameX, 0), Parent = row })
		if not member.Online then
			local w = math.min(76, name.TextBounds.X + 2)
			name.Size = UDim2.fromOffset(w, ROW_H)
			cardLabel({ Text = "ghost", Size = UDim2.fromOffset(36, ROW_H), Position = UDim2.fromOffset(nameX + w + 4, 1), TextSize = 10, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(154, 160, 192), Parent = row })
		end
		cardLabel({ Text = tostring(member.Level or 1), Size = UDim2.fromOffset(40, ROW_H), Position = UDim2.fromOffset(150, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 215, 106), Font = Enum.Font.GothamBlack, Parent = row })
		cardLabel({ Text = tostring(member.ClassId or ""), Size = UDim2.fromOffset(70, ROW_H), Position = UDim2.fromOffset(204, 0), Parent = row })
		local pet = member.PetId and PetConfig.Defs[member.PetId]
		cardLabel({ Text = pet and pet.DisplayName or "-", Size = UDim2.fromOffset(CARD_W - 286, ROW_H), Position = UDim2.fromOffset(276, 0), TextColor3 = if pet then Color3.fromRGB(185, 230, 166) else Color3.fromRGB(110, 116, 140), Parent = row })
	end
	local size = UDim2.fromOffset(CARD_W, HEAD_H + COLS_H + #party.Members * ROW_H + 10)
	if card.Gui then
		card.Gui.Size = size
	else
		card.Frame.Size = size
	end
end

-- Make every hero in an arena clickable (a click opens their inspect card).
function Arenas:_wireClicks(arena)
	for id, hero in pairs(arena.Replay.Heroes) do
		local root = hero.Model and hero.Model.PrimaryPart
		if root and root:FindFirstChildOfClass("ClickDetector") == nil then
			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = 400
			detector.Parent = root
			detector.MouseClick:Connect(function()
				if self.OnInspect then
					self.OnInspect(tonumber(id))
				end
			end)
		end
	end
end

-- What a lot's card, sign and idle heroes show: World snapshots arrive every 3 s, and rebuilding all of it for every
-- party each time was pure waste (stress test 2026-11-27), so Apply redraws a lot only when this changes.
local function partySig(party)
	local parts = { tostring(party.Stage) }
	for _, m in ipairs(party.Members or {}) do
		table.insert(parts, ("%s/%s/%s/%s/%s/%s"):format(tostring(m.UserId), tostring(m.Name), tostring(m.Level), tostring(m.ClassId), tostring(m.PetId), tostring(m.Online)))
	end
	return table.concat(parts, "|")
end

function Arenas:Apply(snapshot)
	local seen = {}
	self.Mine = nil
	for _, party in ipairs(snapshot.Parties) do
		seen[party.Slot] = true
		for _, member in ipairs(party.Members) do
			if member.UserId == self.UserId then
				self.Mine = party.Slot
			end
		end
	end
	for slot, arena in pairs(self.BySlot) do
		if not seen[slot] and slot ~= self.Mine then
			arena.Replay:Destroy()
			arena.Scene:Destroy()
			arena.Anchor:Destroy()
			arena.Pad:Destroy()
			arena.Sign:Destroy()
			self.BySlot[slot] = nil
		end
	end
	for _, party in ipairs(snapshot.Parties) do
		local arena = self:_get(party.Slot)
		local zone = Zones.ForStage(party.Stage)
		if arena.Zone ~= zone.Name then
			arena.Zone = zone.Name
			arena.Theme = zone.Theme
			arena.Scene:SetZone(zone.Theme)
			if self.OnZone then
				self.OnZone(party.Slot, zone.Theme) -- Main re-tints the sky if this is the fight being watched
			end
		end
		local sig = partySig(party)
		arena.Party, arena.ZoneDef = party, zone
		if arena.CardSig ~= sig then
			arena.CardSig = sig
			fillCard(arena.Label, party, zone)
			if self.FocusSlot == party.Slot and self.Screen then
				fillCard(self.Screen, party, zone)
			end
			local big, small = ownerText(party)
			for _, signLabel in ipairs(arena.SignLabels) do
				signLabel.Name.Text = big
				signLabel.Rest.Text = small
			end
		end
		arena.Prompt.ActionText = if party.Slot == self.Mine then "Battle view" else "Watch battle"
		arena.Prompt.ObjectText = (party.Members[1] and party.Members[1].Name or "") .. " - " .. zone.Name
		if not arena.Fighting and arena.IdleSig ~= sig then
			arena.IdleSig = sig
			arena.Replay:Idle(rosterOf(party))
		end
		arena.Replay.OnBanner = if party.Slot == self.Mine then self.OnBanner else nil
		self:_wireClicks(arena)
	end
end

-- The battle card as a fixed panel on the screen (owner 2026-11-24: the floating card was hard to read zoomed in or
-- out). Main calls Arenas:Focus(slot) with the fight you watch or the lot you stand at; that lot's world card hides
-- while its panel shows.
function Arenas:SetScreenParent(parent)
	self.Screen = buildCard(parent)
	local f = self.Screen.Frame
	f.Name = "BattleCardPanel"
	f.Position = UDim2.fromOffset(10, 176) -- under the HUD's party list, top-left
	f.Size = UDim2.fromOffset(CARD_W, HEAD_H + COLS_H + 4 * ROW_H + 10)
	f.Visible = false
	f.ZIndex = 5
	Instance.new("UIScale", f).Scale = 0.82
end

function Arenas:Focus(slot)
	self.FocusSlot = slot
	local arena = slot and self.BySlot[slot]
	for s, a in pairs(self.BySlot) do
		if a.Label and a.Label.Gui then
			a.Label.Gui.Enabled = s ~= slot or not self.Screen
		end
	end
	if not self.Screen then
		return
	end
	if arena and arena.Party then
		fillCard(self.Screen, arena.Party, arena.ZoneDef)
		self.Screen.Frame.Visible = true
	else
		self.Screen.Frame.Visible = false
	end
end

-- How many OTHER parties' fights may animate at once (yours always does). Stress test 2026-11-27 (StressTest, 16 lots,
-- standing among them): 8 animating lots on a PC cost ~2 ms a frame on average but p95 rose 21 -> 25-33 ms; phones
-- are several times slower, so touch screens and low graphics settings watch fewer neighbours.
local function othersCap()
	local cap = 6
	local okQ, quality = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if Kit.Touch then
		cap = 3
	end
	if okQ and quality ~= 0 and quality <= 3 then -- 0 = Automatic
		cap = math.min(cap, 3)
	end
	return cap
end

function Arenas:_othersFighting()
	local n = 0
	for s, arena in pairs(self.BySlot) do
		if s ~= self.Mine and arena.Fighting then
			n += 1
		end
	end
	return n
end

-- Draw a fight in a slot. Others' fights are skipped when you are far away, or when enough of them already play.
function Arenas:Play(slot, info, onDone)
	local arena = self:_get(slot)
	if slot ~= self.Mine and (distanceTo(arena.Scene.Origin) > WATCH_DISTANCE or (not arena.Fighting and self:_othersFighting() >= othersCap())) then
		if onDone then
			onDone()
		end
		return
	end
	arena.Fighting = true
	arena.IdleSig = nil -- the next snapshot after this fight lines the heroes up again
	arena.Replay.OnBanner = if slot == self.Mine then self.OnBanner else nil
	if slot == self.Mine and self.OnBanner and Stages.IsBoss(info.Stage) then
		self.OnBanner("BOSS STAGE", Color3.fromRGB(255, 120, 90))
	end
	arena.Replay:Play(info, function()
		self:_wireClicks(arena)
		arena.Fighting = false
		if onDone then
			onDone()
		end
	end)
	self:_wireClicks(arena)
end

return Arenas
