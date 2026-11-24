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

function Arenas:MySlot()
	return self.Mine
end

local function makeCard(origin)
	local anchor = Instance.new("Part")
	anchor.Name = "ArenaCard"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = origin:PointToWorldSpace(Vector3.new(0, 15, World.ARENA_DEPTH / 2 + 3))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 120)
	gui.MaxDistance = 55 -- only readable when you are close; far cards would overlap
	gui.Adornee = anchor
	gui.Parent = anchor
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, -8)
	label.Position = UDim2.fromOffset(6, 4)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = frame
	return anchor, label
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
	prompt.Name = "DuoQuestWatch"
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
	arena = { Slot = slot, Scene = scene, Replay = Replay.new(scene), Anchor = anchor, Label = label, Pad = pad, Prompt = prompt, Fighting = false, Zone = nil }
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

local function cardText(party, zone)
	local lines = { ("<b>%s</b>  -  Stage %d%s"):format(zone.Name, party.Stage, Stages.IsBoss(party.Stage) and " BOSS" or "") }
	for _, member in ipairs(party.Members) do
		local pet = member.PetId and PetConfig.Defs[member.PetId]
		table.insert(lines, ("%s  Lv %d %s%s%s"):format(member.Name, member.Level, member.ClassId, pet and ("  + " .. pet.DisplayName) or "", member.Online and "" or "  (ghost)"))
	end
	return table.concat(lines, "\n")
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
			self.BySlot[slot] = nil
		end
	end
	for _, party in ipairs(snapshot.Parties) do
		local arena = self:_get(party.Slot)
		local zone = Zones.ForStage(party.Stage)
		if arena.Zone ~= zone.Name then
			arena.Zone = zone.Name
			arena.Scene:SetZone(zone.Theme)
		end
		arena.Label.Text = cardText(party, zone)
		arena.Prompt.ActionText = if party.Slot == self.Mine then "Battle view" else "Watch battle"
		arena.Prompt.ObjectText = (party.Members[1] and party.Members[1].Name or "") .. " - " .. zone.Name
		if not arena.Fighting then
			arena.Replay:Idle(rosterOf(party))
		end
		arena.Replay.OnBanner = if party.Slot == self.Mine then self.OnBanner else nil
		self:_wireClicks(arena)
	end
end

-- Draw a fight in a slot. Others' fights are skipped when you are far away.
function Arenas:Play(slot, info, onDone)
	local arena = self:_get(slot)
	if slot ~= self.Mine and distanceTo(arena.Scene.Origin) > WATCH_DISTANCE then
		if onDone then
			onDone()
		end
		return
	end
	arena.Fighting = true
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
