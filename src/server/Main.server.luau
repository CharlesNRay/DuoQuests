--[[
	Main (Script)
	Location: ServerScriptService > Server > Main

	Starts the server services in order and connects players to them.
	Future services get required and initialised here.
]]

local Players = game:GetService("Players")
Players.CharacterAutoLoads = false -- nobody spawns until they pick a character at the main menu
local ReplicatedStorage = game:GetService("ReplicatedStorage")
game:GetService("StarterPlayer").CharacterWalkSpeed = require(ReplicatedStorage:WaitForChild("Shared").World).WALK_SPEED

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PartyService = require(Services.PartyService)
local ApiService = require(Services.ApiService)
local GuildService = require(Services.GuildService)
local LeaderboardService = require(Services.LeaderboardService)
local WorldService = require(Services.WorldService)
local PremiumService = require(Services.PremiumService)
local SeasonResultsService = require(Services.SeasonResultsService)
local PlaytestService = require(Services.PlaytestService)

PlaytestService.Init() -- first, so errors while the rest starts are recorded
DataService.Init()
PartyService.Init()
ApiService.Init()
PremiumService.Init(DataService.GetProfile, DataService.SaveNow, ApiService.PushState)
LeaderboardService.Init(WorldService.SetBoardText)
SeasonResultsService.Init()

local function onPlayerAdded(player)
	local profile, reason = DataService.LoadProfile(player)
	if not profile then
		if reason ~= "PlayerLeft" and reason ~= "AlreadyLoading" then
			player:Kick("Could not load your data (" .. tostring(reason) .. "). Please rejoin.")
		end
		return
	end

	print(
		("[IdlePartyQuest] %s loaded - Season %d, %s, level %d"):format(
			player.Name,
			profile.Season.SeasonId,
			profile.Season.ClassId,
			profile.Season.Level
		)
	)

	PlaytestService.Joined(player, profile)
	GuildService.OnPlayerReady(player, profile) -- the party and avatar start when they press Play
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PartyService.OnPlayerLeaving(player) -- while the profile is still loaded
	PlaytestService.Left(player, DataService.GetProfile(player))
	GuildService.OnPlayerLeaving(player, DataService.GetProfile(player))
	DataService.ReleaseProfile(player)
end)

-- A new season can start while this server runs (Shared/SeasonClock). Profiles move into it when they load, so players
-- who are online at the switch are asked to rejoin (their data saves as they leave). Test seasons (Studio cheat) do not kick.
local SeasonClock = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SeasonClock)
task.spawn(function()
	local running = SeasonClock.CurrentId()
	while true do
		task.wait(30)
		local current = SeasonClock.CurrentId()
		if current ~= running then
			running = current
			if not SeasonClock.IsTest() then
				local name = (SeasonClock.Def(current) or {}).Name or ("Season " .. current)
				for _, player in ipairs(Players:GetPlayers()) do
					player:Kick(("%s has begun! Rejoin to start the new season. Your pets, passes and collections are kept."):format(name))
				end
			end
		end
	end
end)

-- Cover players who joined before this script finished starting.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
