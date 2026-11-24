--[[
	WorldService (ModuleScript)
	Location: ServerScriptService > Server > Services > WorldService

	The shared hub. Every party hosted on this server gets an ARENA slot; all
	players on the server can walk up and watch. This service decides slots and
	tells every client who is in which arena. Fights are drawn by the clients from
	the event logs the party service already produces (see ApiService).

	  WorldService.Init(push)         push = the RemoteEvent for pushes
	  WorldService.SlotOf(partyId)    -> slot number (assigned on first use)
	  WorldService.Snapshot()         -> { Parties = { { PartyId, Slot, Stage, Frontier, Members } } }
	  Members: { { UserId, Name, ClassId, Level, Online } }

	Pushes "World" (the snapshot) to everyone every few seconds.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").World)
local PartyService = require(script.Parent.PartyService)

local WorldService = {}

local BROADCAST_INTERVAL = 3
local slotOf = {} -- [partyId] = slot
local usedSlots = {} -- [slot] = partyId
local pushRemote = nil

local function claimSlot(partyId)
	if slotOf[partyId] then
		return slotOf[partyId]
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	slotOf[partyId] = slot
	usedSlots[slot] = partyId
	return slot
end

function WorldService.SlotOf(partyId)
	return claimSlot(partyId)
end

function WorldService.Snapshot()
	local parties = {}
	local live = {}
	for _, summary in ipairs(PartyService.GetHostedSummaries()) do
		live[summary.PartyId] = true
		summary.Slot = claimSlot(summary.PartyId)
		table.insert(parties, summary)
	end
	-- free the slots of parties that are gone
	for partyId, slot in pairs(slotOf) do
		if not live[partyId] then
			slotOf[partyId] = nil
			usedSlots[slot] = nil
		end
	end
	table.sort(parties, function(a, b)
		return a.Slot < b.Slot
	end)
	return { Parties = parties }
end

-- The walkable hub: grass floor, a spawn pad and daylight. Arenas themselves are
-- drawn by the clients (see client/Battle/Arenas) so each party's zone looks right.
function WorldService.BuildHub()
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)

	local hub = Instance.new("Folder")
	hub.Name = "IdlePartyHub"
	hub.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Ground"
	floor.Anchored = true
	floor.Size = Vector3.new(720, 2, 840) -- covers the Boss Field (north) and the town
	floor.Position = Vector3.new(0, -1, 20)
	floor.Color = Color3.fromRGB(96, 160, 84)
	floor.Material = Enum.Material.Grass
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = hub
	-- a grass strip outside the Homes gate under lots 5-8 and the overflow lots (World.OuterGround)
	do
		local gx, gz, yaw, length, width = World.OuterGround()
		local strip = floor:Clone()
		strip.Name = "HomesGround"
		strip.Size = Vector3.new(width, 2, length)
		strip.CFrame = CFrame.new(gx, -1.01, gz) * CFrame.Angles(0, yaw, 0)
		strip.Parent = hub
	end

	local x, y, z = World.SpawnPosition()
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 0.2, 14)
	spawn.Position = Vector3.new(x, 0.65, z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(230, 200, 120)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Parent = hub
end

-- Called by LeaderboardService after each refresh: textByCategory[id] = lines.
function WorldService.SetBoardText(textByCategory)
	local hub = workspace:FindFirstChild("IdlePartyHub")
	local sign = hub and hub:FindFirstChild("LeaderboardSign")
	local label = sign and sign:FindFirstChild("Board") and sign.Board:FindFirstChild("Text")
	if label then
		local parts = {}
		for _, category in ipairs(require(ReplicatedStorage.Shared.Leaderboards).Categories) do
			if not category.Class then -- the sign shows the overall boards; class boards are on the Ranks screen
				table.insert(parts, textByCategory[category.Id] or "")
			end
		end
		label.Text = table.concat(parts, "\n\n")
	end
end

function WorldService.Init(push)
	WorldService.BuildHub()
	pushRemote = push
	task.spawn(function()
		while true do
			task.wait(BROADCAST_INTERVAL)
			if #Players:GetPlayers() > 0 then
				pushRemote:FireAllClients("World", WorldService.Snapshot())
			end
		end
	end)
end

return WorldService
