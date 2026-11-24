--[[
	Sound (ModuleScript): music and sound effects (ids in Shared/Config/Audio).

	Three SoundGroups under SoundService (Music, Effects, Interface); the player's sliders (Master x channel) set their
	volumes. Settings live on the server profile (handler SaveSettings) so they follow the player; Sound.Apply(settings)
	is called whenever the state arrives.

	  Sound.Apply(settings)              { Master, Music, Effects, Interface } each 0..1 (nil = defaults)
	  Sound.Play(name)                   a 2D sound (interface, big moments)
	  Sound.PlayAt(name, position)       a 3D sound in the world (combat): only nearby fights are heard
	  Sound.Music(trackName | nil)       cross-fades to that track (Town, Stage, Dungeon, WorldBoss, SeasonBoss, GuildRaid)
	  Sound.Settings()                   the current slider values

	Studio only: Workspace attribute StudioMute = true silences everything (set in Edit mode before an automated test
	run so the owner does not hear it; cleared afterwards). It is ignored in the live game.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Audio"))

local Sound = {}

local groups = {}
for _, name in ipairs({ "Music", "Effects", "Interface" }) do
	local g = SoundService:FindFirstChild("IPQ_" .. name) or Instance.new("SoundGroup")
	g.Name = "IPQ_" .. name
	g.Parent = SoundService
	groups[name] = g
end

local settings = table.clone(Config.Defaults)

function Sound.Settings()
	return table.clone(settings)
end

function Sound.Apply(new)
	for _, channel in ipairs(Config.Channels) do
		local v = new and tonumber(new[channel])
		settings[channel] = if v then math.clamp(v, 0, 1) else Config.Defaults[channel]
	end
	local mute = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("StudioMute") == true
	for name, g in pairs(groups) do
		g.Volume = if mute then 0 else settings.Master * settings[name]
	end
end
Sound.Apply(nil)
workspace:GetAttributeChangedSignal("StudioMute"):Connect(function()
	Sound.Apply(settings)
end)

local lastPlayed = {} -- [name] = os.clock(): the same effect at most every MIN_GAP seconds (a big fight has many hits)
local MIN_GAP = 0.06

local function make(name)
	local def = Config.Sfx[name]
	if not def then
		return nil
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < MIN_GAP then
		return nil
	end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(def.Ids[math.random(1, #def.Ids)])
	s.Volume = def.Volume or 0.5
	if def.Pitch then
		s.PlaybackSpeed = def.Pitch[1] + math.random() * (def.Pitch[2] - def.Pitch[1])
	end
	s.SoundGroup = groups[def.Group or "Effects"]
	return s
end

function Sound.Play(name)
	local s = make(name)
	if not s then
		return
	end
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	Debris:AddItem(s, 15)
end

function Sound.PlayAt(name, position)
	if typeof(position) ~= "Vector3" then
		return Sound.Play(name)
	end
	local s = make(name)
	if not s then
		return
	end
	local at = Instance.new("Attachment")
	at.WorldPosition = position
	at.Parent = workspace.Terrain
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 18
	s.RollOffMaxDistance = 110
	s.Parent = at
	s:Play()
	Debris:AddItem(at, 8)
end

-- music: two players that cross-fade, so a change of scene never cuts the sound dead
local current, currentName = nil, nil
local FADE = 1.6

function Sound.Music(name)
	if name == currentName then
		return
	end
	currentName = name
	local old = current
	current = nil
	if old then
		local tween = TweenService:Create(old, TweenInfo.new(FADE), { Volume = 0 })
		tween.Completed:Connect(function()
			old:Destroy()
		end)
		tween:Play()
	end
	local def = name and Config.Music[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Music_" .. name
	s.SoundId = "rbxassetid://" .. tostring(def.Id)
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = groups.Music
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(FADE), { Volume = def.Volume or 0.4 }):Play()
	current = s
end

return Sound
