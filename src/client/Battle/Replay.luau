--[[
	Replay (ModuleScript): plays a finished fight as animation.

	The server decides the fight and sends its event log (Combat/Simulation
	events) plus a roster. This module only draws it: monsters run in, heroes
	and monsters trade blows, damage numbers float up, skills flash, the dead
	fall. Nothing here can change an outcome.

	  local replay = Replay.new(scene)
	  replay:Play(info, onDone)     info = a "Fight" push (Roster, Events, Won, ...)
	  replay:Idle(state)            standing between fights / before the first one
	  replay.OnBanner               optional function(text, color) for big callouts

	Heroes use the player's real avatar when it can be loaded (a plain body
	until then); partners and ghosts too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)
local Ultimates = require(Shared.Config.Ultimates)
local Actor = require(script.Parent.Actor)
local CosmeticsVisuals = require(script.Parent.CosmeticsVisuals)
local Models = require(script.Parent.Models)

local Replay = {}
Replay.__index = Replay

local INTRO = 0.8 -- seconds for monsters to run in before the first blow
-- The server waits Duration + 2s between fights, so the whole replay
-- (INTRO + Duration + the tail below) must stay under that.
local HERO_X = { -9, -14 }
local ENEMY_X = { 9, 15, 21 }

local ELEMENT_COLORS = {
	Holy = Color3.fromRGB(255, 240, 150),
	Fire = Color3.fromRGB(255, 120, 60),
	Ice = Color3.fromRGB(150, 220, 255),
	Physical = Color3.fromRGB(255, 255, 255),
}

function Replay.new(scene)
	return setmetatable({ Scene = scene, Heroes = {}, Enemies = {}, Token = 0 }, Replay)
end

local function floatText(scene, pos, text, color, size)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos
	anchor.Parent = scene.Folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 36)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size or 22
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local function flash(scene, pos, color, size)
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Transparency = 0.3
	orb.Size = Vector3.new(1, 1, 1)
	orb.Position = pos
	orb.Parent = scene.Folder
	TweenService:Create(orb, TweenInfo.new(0.4), { Size = Vector3.new(size, size, size), Transparency = 1 }):Play()
	Debris:AddItem(orb, 0.5)
end

local function bolt(scene, from, to, color)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	local streak = Instance.new("Part")
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.Material = Enum.Material.Neon
	streak.Color = color
	streak.Size = Vector3.new(0.4, 0.4, length)
	streak.CFrame = CFrame.lookAt(mid, to)
	streak.Parent = scene.Folder
	TweenService:Create(streak, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.1, 0.1, length) }):Play()
	Debris:AddItem(streak, 0.3)
end

-- Heroes persist between fights; (re)build them for a roster entry.
function Replay:_hero(entry, index)
	local hero = self.Heroes[entry.Id]
	if hero == nil then
		hero = Actor.new(self.Scene, Models.Hero(entry.DefId), { Name = entry.Name, Facing = 1, MaxHealth = entry.MaxHealth })
		hero.Pet = Actor.new(self.Scene, Models.Pet(entry.PetId), { Name = "Pet", Facing = 1, MaxHealth = 1 })
		hero.PetId = entry.PetId
		hero.Pet.Bar.Enabled = false
		self.Heroes[entry.Id] = hero
		-- the real avatar, when available
		if entry.UserId and entry.UserId > 0 then -- ghosts like the starter companion have no avatar
			task.spawn(function()
				local ok, rig = pcall(function()
					return Players:CreateHumanoidModelFromUserId(entry.UserId)
				end)
				if ok and rig and not hero.Destroyed then
					for _, d in ipairs(rig:GetDescendants()) do
						if d:IsA("Script") or d:IsA("LocalScript") then
							d:Destroy()
						end
					end
					hero:SetModel(rig)
				end
			end)
		end
	end
	if hero.Look ~= entry.Look then
		hero:SetLook(entry.Look)
	end
	if hero.Ghost ~= (entry.Ghost == true) then
		hero:SetGhost(entry.Ghost == true)
	end
	if hero.PetId ~= entry.PetId then
		hero.PetId = entry.PetId
		hero.Pet:SetModel(Models.Pet(entry.PetId))
	end
	hero.MaxHealth = entry.MaxHealth
	hero:SetHealth(entry.MaxHealth)
	if not hero.Alive then
		hero:Rise()
	end
	hero.Model.Parent = self.Scene.Folder
	hero:Place(HERO_X[index] or HERO_X[#HERO_X])
	hero.Pet:Place((HERO_X[index] or -14) - 3.5)
	return hero
end

function Replay:Idle(roster)
	for index, entry in ipairs(roster) do
		if entry.Team == "Party" then
			self:_hero(entry, index)
		end
	end
	self.Scene:Walk(true)
end

function Replay:_clearEnemies()
	for _, enemy in pairs(self.Enemies) do
		enemy:Destroy()
	end
	self.Enemies = {}
end

local function actorFor(self, id)
	return self.Heroes[id] or self.Enemies[id]
end

function Replay:Play(info, onDone)
	self.Spawned = 0
	self.Token += 1
	local token = self.Token
	self:_clearEnemies()
	local scene = self.Scene

	local heroIndex, enemyIndex = 0, 0
	for _, entry in ipairs(info.Roster) do
		if entry.Team == "Party" then
			heroIndex += 1
			self:_hero(entry, heroIndex)
		else
			enemyIndex += 1
			local actor = Actor.new(scene, Models.Enemy(entry.DefId), { Name = entry.Name, Facing = -1, MaxHealth = entry.MaxHealth })
			actor:Place(ENEMY_X[enemyIndex] + 30)
			self.Enemies[entry.Id] = actor
			task.spawn(function()
				local startX, endX = actor.X, ENEMY_X[enemyIndex]
				local t0 = os.clock()
				while os.clock() - t0 < INTRO and not actor.Destroyed do
					actor:Place(startX + (endX - startX) * ((os.clock() - t0) / INTRO))
					task.wait()
				end
				if not actor.Destroyed then
					actor:Place(endX)
				end
			end)
		end
	end
	scene:Walk(false)

	local function later(t, fn)
		task.delay(INTRO + t, function()
			if self.Token == token then
				fn()
			end
		end)
	end

	for _, e in ipairs(info.Events) do
		later(e.T, function()
			self:_event(e)
		end)
	end

	later(info.Duration + 0.1, function()
		if info.Won then
			for _, hero in pairs(self.Heroes) do
				hero:Cheer()
			end
		end
	end)
	-- fight over: walk on toward the next one
	task.delay(INTRO + info.Duration + 0.4, function()
		if self.Token == token then
			scene:Walk(true)
		end
		if onDone then
			onDone() -- always refresh state, even if the next fight already began
		end
	end)
end

function Replay:_event(e)
	local scene = self.Scene
	local t = e.Type
	if t == "Damage" then
		local source, target = actorFor(self, e.Source), actorFor(self, e.Target)
		if not (source and target) then
			return
		end
		source:Lunge(target.X)
		local c = ELEMENT_COLORS[e.Element or "Physical"] or ELEMENT_COLORS.Physical
		if e.Tag ~= "BasicAttack" then
			bolt(scene, source:Pos(), target:Pos(), c)
		end
		target:Flinch()
		target:SetHealth(e.TargetHealth or target.Health)
		local text = tostring(math.floor((e.Amount or 0) + 0.5)) .. (if e.Crit then "!" else "")
		floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), text, if e.Crit then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1), if e.Crit then 28 else 22)
	elseif t == "Heal" then
		local target = actorFor(self, e.Target)
		if target then
			target:SetHealth(e.TargetHealth or target.Health)
			floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), "+" .. math.floor((e.Amount or 0) + 0.5), Color3.fromRGB(110, 235, 140), 22)
			flash(scene, target:Pos(), Color3.fromRGB(110, 235, 140), 4)
		end
	elseif t == "Cast" then
		local source = actorFor(self, e.Source)
		local def = Abilities[e.Ability]
		if source and def then
			floatText(scene, source:Pos() + Vector3.new(0, 3, 0), def.DisplayName, Color3.fromRGB(255, 230, 150), 16)
			flash(scene, source:Pos(), Color3.fromRGB(255, 230, 150), 3)
		end
	elseif t == "Ultimate" then
		local def = Ultimates.Defs[e.Ability]
		if self.OnBanner and def then
			self.OnBanner(def.DisplayName, Color3.fromRGB(190, 110, 255))
		end
		for _, hero in pairs(self.Heroes) do
			flash(scene, hero:Pos(), Color3.fromRGB(190, 110, 255), 7)
		end
	elseif t == "Death" then
		local target = actorFor(self, e.Target)
		if target then
			target:SetHealth(0)
			if self.Enemies[e.Target] then
				CosmeticsVisuals.KillEffect(scene.Folder, target:Pos())
				target:FadeOut()
			else
				target:Fall()
			end
		end
	elseif t == "Spawn" then
		-- a boss summoned a minion: it joins the enemy side
		local entry = e.Entity
		if entry and not self.Enemies[entry.Id] then
			self.Spawned = (self.Spawned or 0) + 1
			local x = ENEMY_X[#ENEMY_X] + 4 + ((self.Spawned - 1) % 4) * 3.5
			local actor = Actor.new(scene, Models.Enemy(entry.DefId), { Name = entry.Name, Facing = -1, MaxHealth = entry.MaxHealth })
			actor:Place(x)
			self.Enemies[entry.Id] = actor
			flash(scene, actor:Pos(), Color3.fromRGB(150, 230, 150), 4)
		end
	elseif t == "Telegraph" then
		-- a big hit is coming: warn the player so they can see why a shield matters
		local def = Abilities[e.Ability]
		local source = actorFor(self, e.Source)
		if def and source then
			floatText(scene, source:Pos() + Vector3.new(0, 5, 0), def.DisplayName .. "!", Color3.fromRGB(255, 90, 80), 26)
		end
		if def and self.OnBanner then
			self.OnBanner(def.DisplayName .. " incoming!", Color3.fromRGB(255, 90, 80))
		end
	elseif t == "Revive" then
		local target = actorFor(self, e.Target)
		if target then
			target:Rise()
			target:SetHealth(e.TargetHealth or 1)
			flash(scene, target:Pos(), Color3.fromRGB(255, 240, 150), 6)
		end
	end
end

function Replay:Destroy()
	self.Token += 1
	self:_clearEnemies()
	for _, hero in pairs(self.Heroes) do
		hero.Pet:Destroy()
		hero:Destroy()
	end
	self.Heroes = {}
end

return Replay
