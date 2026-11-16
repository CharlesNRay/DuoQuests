--[[
	Main (Script)
	Location: ServerScriptService > Server > Main

	Starts the server services in order and connects players to them.
	Future services get required and initialised here.
]]

local Players = game:GetService("Players")

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PartyService = require(Services.PartyService)
local ApiService = require(Services.ApiService)
local GuildService = require(Services.GuildService)
local LeaderboardService = require(Services.LeaderboardService)
local WorldService = require(Services.WorldService)
local PremiumService = require(Services.PremiumService)
local SeasonResultsService = require(Services.SeasonResultsService)

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
		("[DuoQuest] %s loaded - Season %d, %s, level %d"):format(
			player.Name,
			profile.Season.SeasonId,
			profile.Season.ClassId,
			profile.Season.Level
		)
	)

	PartyService.OnPlayerReady(player, profile)
	GuildService.OnPlayerReady(player, profile)
	ApiService.ApplyLook(player, profile)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PartyService.OnPlayerLeaving(player) -- while the profile is still loaded
	GuildService.OnPlayerLeaving(player, DataService.GetProfile(player))
	DataService.ReleaseProfile(player)
end)

-- Cover players who joined before this script finished starting.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
