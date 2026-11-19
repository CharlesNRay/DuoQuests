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
local NumberFormat = require(Shared.Util.NumberFormat)
local Ultimates = require(Shared.Config.Ultimates)
local Actor = require(script.Parent.Actor)
local StatusLook = require(script.Parent.StatusLook)
local CosmeticsVisuals = require(script.Parent.CosmeticsVisuals)
local SkillEffects = require(script.Parent.SkillEffects)
local Models = require(script.Parent.Models)

local Replay = {}
Replay.__index = Replay

local INTRO = 0.8 -- seconds for monsters to run in before the first blow
-- The server waits Duration + 2s between fights, so the whole replay
-- (INTRO + Duration + the tail below) must stay under that.
-- Formation: each team stands in a Front and a Back row; fighters in a row stand side by side (spread across the depth lanes).
local ROW_X = { Party = { Front = -7, Back = -14 }, Enemy = { Front = 8, Back = 16 } }
local LANE = 3.8
local ROW_SPREAD = 19 -- a row never spreads wider than this (4 heroes + pets + summons stay on the pad)
local HERO_X = { -9, -14, -11, -16 } -- (only used for the idle walk before a fight is set up)

local ELEMENT_COLORS = {
	Holy = Color3.fromRGB(255, 240, 150),
	Fire = Color3.fromRGB(255, 120, 60),
	Ice = Color3.fromRGB(150, 220, 255),
	Physical = Color3.fromRGB(255, 255, 255),
}

function Replay.new(scene)
	return setmetatable({ Scene = scene, Heroes = {}, Enemies = {}, Minions = {}, Token = 0 }, Replay)
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
-- The hero's body: the character creator's blocky look, or the player's Roblox avatar. Read from attributes the server
-- sets on the player, and re-applied when they change (heroes persist between fights).
local function applyBody(hero, entry)
	local owner = entry.UserId and entry.UserId > 0 and Players:GetPlayerByUserId(entry.UserId) or nil
	local custom = owner ~= nil and owner:GetAttribute("CharSkin") ~= nil and owner:GetAttribute("CharAvatar") ~= true
	local key = if custom then table.concat({ tostring(owner:GetAttribute("CharSkin")), tostring(owner:GetAttribute("CharHair")), tostring(owner:GetAttribute("CharOutfit")) }, "|") else "avatar"
	if hero.BodyKey == key then
		return
	end
	hero.BodyKey = key
	if custom then
		hero:SetModel(Models.Hero(entry.DefId, { Skin = owner:GetAttribute("CharSkin"), Hair = owner:GetAttribute("CharHair"), Outfit = owner:GetAttribute("CharOutfit") }))
	elseif entry.UserId and entry.UserId > 0 then -- ghosts like the starter companion have no avatar
		task.spawn(function()
			local ok, rig = pcall(function()
				return Players:CreateHumanoidModelFromUserId(entry.UserId)
			end)
			if ok and rig and not hero.Destroyed and hero.BodyKey == key then
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

-- Works out where every fighter stands from its row and join order. Fighters who have arrived are moved there at once.
function Replay:_layout()
	local groups = {}
	for _, actor in ipairs(self.Formation or {}) do
		if not actor.Destroyed and actor.Alive ~= false then
			local key = actor.Team .. "/" .. actor.Row
			groups[key] = groups[key] or {}
			table.insert(groups[key], actor)
		end
	end
	for key, list in pairs(groups) do
		local team, row = string.match(key, "(%a+)/(%a+)")
		table.sort(list, function(a, b)
			return a.Order < b.Order
		end)
		local n = #list
		for i, actor in ipairs(list) do
			local x = ROW_X[team][row] + (if i % 2 == 0 then (if team == "Party" then -1.2 else 1.2) else 0)
			local z = (i - (n + 1) / 2) * math.min(LANE, ROW_SPREAD / math.max(1, n - 1))
			actor.HomeX, actor.HomeZ = x, z
			if actor.Arrived then
				actor:Place(x, z)
				if actor.Pet then
					actor.Pet:Place(x - 3.5, z)
				end
			end
		end
	end
end

function Replay:_enlist(actor, team, row)
	for index, other in ipairs(self.Formation) do
		if other == actor then
			table.remove(self.Formation, index)
			break
		end
	end
	actor.Team, actor.Row = team, row or "Front"
	self.OrderCounter = (self.OrderCounter or 0) + 1
	actor.Order = self.OrderCounter
	table.insert(self.Formation, actor)
end

function Replay:_hero(entry, index)
	local hero = self.Heroes[entry.Id]
	if hero == nil then
		local owner = entry.UserId and entry.UserId > 0 and Players:GetPlayerByUserId(entry.UserId) or nil
		hero = Actor.new(self.Scene, Models.Hero(entry.DefId), { Name = owner and owner:GetAttribute("CharName") or entry.Name, Facing = 1, MaxHealth = entry.MaxHealth })
		hero.ClassId = entry.DefId
		hero.Pet = Actor.new(self.Scene, Models.Pet(entry.PetId), { Name = "Pet", Facing = 1, MaxHealth = 1 })
		hero.PetId = entry.PetId
		hero.Pet.Bar.Enabled = false
		self.Heroes[entry.Id] = hero
	end
	applyBody(hero, entry)
	do -- cosmetic aura of this hero's player (set by the server on the player)
		local owner = entry.UserId and entry.UserId > 0 and Players:GetPlayerByUserId(entry.UserId) or nil
		local auraId = owner and owner:GetAttribute("CosAura") or nil
		hero:SetAura(CosmeticsVisuals.AuraBuilder(auraId), auraId or "none")
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
	hero:ClearStatuses()
	hero:SetHealth(entry.MaxHealth, true)
	if not hero.Alive then
		hero:Rise()
	end
	hero.Model.Parent = self.Scene.Folder
	hero.Arrived = true
	self:_enlist(hero, "Party", entry.Row)
	hero:Place(HERO_X[index] or HERO_X[#HERO_X], 0)
	hero.Pet:Place((HERO_X[index] or -14) - 3.5, 0)
	return hero
end

-- Everyone walks (or stands) together: the scenery scrolls and the heroes and pets run their walk cycle.
function Replay:_setWalking(on)
	self.Scene:Walk(on)
	for _, hero in pairs(self.Heroes) do
		hero:SetWalking(on)
		if hero.Pet then
			hero.Pet:SetWalking(on)
		end
	end
end

function Replay:Idle(roster)
	self.Formation = {}
	self.OrderCounter = 0
	for index, entry in ipairs(roster) do
		if entry.Team == "Party" then
			self:_hero(entry, index)
		end
	end
	self:_layout() -- walk side by side in the same formation they fight in, not in a single file line
	self:_setWalking(true)
end

function Replay:_clearEnemies()
	for _, enemy in pairs(self.Enemies) do
		enemy:Destroy()
	end
	self.Enemies = {}
	for _, minion in pairs(self.Minions) do
		minion:Destroy()
	end
	self.Minions = {}
end

local function actorFor(self, id)
	return self.Heroes[id] or self.Enemies[id] or self.Minions[id]
end

-- chest positions of the living fighters on a side
local function positionsOf(actors)
	local out = {}
	for _, actor in pairs(actors) do
		if actor.Alive and not actor.Destroyed then
			table.insert(out, actor:Pos())
		end
	end
	table.sort(out, function(a, b)
		return a.X < b.X
	end)
	return out
end

-- Skill effects must never break a replay.
local function safely(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[DuoQuest] skill effect failed: " .. tostring(err))
	end
end

function Replay:Play(info, onDone)
	self.Spawned = 0
	self.SpawnedMinions = 0
	self.Formation = {}
	self.OrderCounter = 0
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
			actor.AttackStyle = Models.AttackStyle(entry.DefId)
			self.Enemies[entry.Id] = actor
			self:_enlist(actor, "Enemy", entry.Row)
		end
	end
	self:_layout() -- (heroes were placed as they were listed; monsters have not arrived yet)
	for _, actor in pairs(self.Enemies) do
		actor:Place((actor.HomeX or 10) + 30, actor.HomeZ or 0)
		task.spawn(function()
			local startX, endX = actor.X, actor.HomeX or 10
			local t0 = os.clock()
			while os.clock() - t0 < INTRO and not actor.Destroyed do
				actor:Place(startX + (endX - startX) * ((os.clock() - t0) / INTRO), actor.HomeZ)
				task.wait()
			end
			if not actor.Destroyed then
				actor.Arrived = true
				actor:Place(endX, actor.HomeZ)
			end
		end)
	end
	self:_setWalking(false)

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
			-- a clear win beat for the short pause before the next wave (only on your own arena)
			if self.OnBanner and info.Stage then
				self.OnBanner(("STAGE %d CLEARED"):format(info.Stage), Color3.fromRGB(120, 230, 140))
			end
		end
	end)
	-- fight over: walk on toward the next one
	task.delay(INTRO + info.Duration + 0.4, function()
		if self.Token == token then
			self:_setWalking(true)
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
		if e.Sacrifice or e.Devoured then
			-- health paid for a dark spell, or a minion consumed: a dark puff and the number, no strike
			target:SetHealth(e.TargetHealth or target.Health)
			flash(scene, target:Pos(), Color3.fromRGB(150, 40, 70), 4)
			floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), "-" .. NumberFormat.Short(e.Amount or 0), Color3.fromRGB(190, 60, 100), 22)
			return
		end
		local dot = StatusLook.DotTag(e.Tag)
		if dot then
			-- a damage-over-time tick: no strike, just a tinted pulse on the victim and a coloured number
			target:SetHealth(e.TargetHealth or target.Health)
			target:Tint(dot.Color, 0.4, 0.35)
			floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), dot.Glyph .. NumberFormat.Short(e.Amount or 0), dot.Color, 18)
			return
		end
		source:Attack(source.AttackStyle, target.X)
		local c = ELEMENT_COLORS[e.Element or "Physical"] or ELEMENT_COLORS.Physical
		if e.Tag == "BasicAttack" then
			safely(SkillEffects.Hit, scene, nil, source:Pos(), target:Pos(), source.ClassId)
		elseif SkillEffects.HasStyle(e.Tag) then
			safely(SkillEffects.Hit, scene, e.Tag, source:Pos(), target:Pos())
		else
			bolt(scene, source:Pos(), target:Pos(), c)
		end
		target:Flinch()
		target:Absorb(e.Absorbed)
		target:SetHealth(e.TargetHealth or target.Health)
		local text = NumberFormat.Short(e.Amount or 0) .. (if e.Crit then "!" else "")
		floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), text, if e.Crit then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1), if e.Crit then 28 else 22)
	elseif t == "Heal" then
		local target = actorFor(self, e.Target)
		if target then
			target:SetHealth(e.TargetHealth or target.Health)
			target:HealFx()
			floatText(scene, target:Pos() + Vector3.new(0, 1.5, 0), "+" .. NumberFormat.Short(e.Amount or 0), Color3.fromRGB(110, 235, 140), 22)
			safely(SkillEffects.Heal, scene, e.Tag, target:Pos())
		end
	elseif t == "Status" then
		local target = actorFor(self, e.Target)
		if target then
			local cast = self.LastCast and self.LastCast[e.Source]
			local ability = cast and math.abs((e.T or 0) - cast.T) < 0.06 and cast.Ability or nil
			safely(SkillEffects.Status, scene, e.Status, target:Pos(), ability)
			safely(target.AddStatus, target, e.Status, { Duration = e.Duration, Amount = e.Amount, Stacks = e.Stacks })
		end
	elseif t == "StatusEnd" then
		local target = actorFor(self, e.Target)
		if target then
			if e.Reason == "Consumed" and (e.Stacks or 0) > 0 then -- a finisher used up its combo layers
				local look = StatusLook.Of(e.Status)
				safely(floatText, scene, target:Pos() + Vector3.new(0, 4.5, 0), ("COMBO x%d!"):format(e.Stacks), look.Color, 15 + math.min(e.Stacks, 5) * 2)
			end
			safely(target.RemoveStatus, target, e.Status, e.Reason)
		end
	elseif t == "Cast" then
		local source = actorFor(self, e.Source)
		local def = Abilities[e.Ability]
		if source and def then
			if not def.Quiet then
				floatText(scene, source:Pos() + Vector3.new(0, 3, 0), def.DisplayName, Color3.fromRGB(255, 230, 150), 16)
			end
			self.LastCast = self.LastCast or {}
			self.LastCast[e.Source] = { Ability = e.Ability, T = e.T or 0 }
			if def.Enemy and self.Enemies[e.Source] then
				-- a monster skill has its own motion (the hit that follows still lunges)
				source:Attack(def.Anim or "Cast", source.X - 1)
			end
			local heroActor = self.Heroes[e.Source]
			if def.Pet and heroActor and heroActor.Pet then
				-- the pet itself darts in at the enemies and strikes
				local nearest
				for _, enemy in pairs(self.Enemies) do
					if nearest == nil or enemy.X < nearest.X then
						nearest = enemy
					end
				end
				heroActor.Pet:Attack("Lunge", if nearest then nearest.X else heroActor.X + 8)
				flash(scene, heroActor.Pet:Pos() + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 240, 170), 2)
			elseif SkillEffects.HasStyle(e.Ability) then
				local isHero = self.Heroes[e.Source] ~= nil or self.Minions[e.Source] ~= nil
				safely(SkillEffects.Cast, scene, {
					Ability = e.Ability, SourcePos = source:Pos(), SourceIsHero = isHero,
					AllyPositions = positionsOf(if isHero then self.Heroes else self.Enemies),
					EnemyPositions = positionsOf(if isHero then self.Enemies else self.Heroes),
					PetPos = if isHero and source.Pet and tostring(e.Ability):sub(1, 4) == "Pet_" then source.Pet:Pos() else nil,
				})
			else
				flash(scene, source:Pos(), Color3.fromRGB(255, 230, 150), 3)
			end
		end
	elseif t == "Ultimate" then
		local def = Ultimates.Defs[e.Ability]
		if self.OnBanner and def then
			self.OnBanner(def.DisplayName, Color3.fromRGB(190, 110, 255))
		end
		safely(SkillEffects.Ultimate, scene, e.Ability, { AllyPositions = positionsOf(self.Heroes), EnemyPositions = positionsOf(self.Enemies) })
	elseif t == "Death" then
		local target = actorFor(self, e.Target)
		if target then
			target:SetHealth(0)
			if self.Enemies[e.Target] or self.Minions[e.Target] then
				CosmeticsVisuals.KillEffect(scene.Folder, target:Pos())
				target:FadeOut()
				if self.Minions[e.Target] == target then
					-- a summon leaves the field for good (fading leaves its eyes and decals behind otherwise)
					task.delay(0.8, function()
						if self.Minions[e.Target] == target then
							self.Minions[e.Target] = nil
							target:Destroy()
							self:_layout()
						end
					end)
				end
			else
				target:Fall()
			end
		end
	elseif t == "Spawn" then
		local entry = e.Entity
		if entry and entry.Team == "Party" and not self.Minions[entry.Id] then
			-- a summoner raised a minion: it takes the front row (summons are there to tank), beside the others
			local actor = Actor.new(scene, Models.Enemy(entry.DefId), { Name = entry.Name, Facing = 1, MaxHealth = entry.MaxHealth })
			self.Minions[entry.Id] = actor
			actor.Arrived = true
			self:_enlist(actor, "Party", entry.Row or "Front")
			actor:Place(ROW_X.Party.Front - 6, 0)
			self:_layout()
			flash(scene, actor:Pos(), Color3.fromRGB(150, 60, 190), 5)
		elseif entry and entry.Team ~= "Party" and not self.Enemies[entry.Id] then
			-- a boss summoned a minion: it joins the enemy front row, in front of the boss
			local actor = Actor.new(scene, Models.Enemy(entry.DefId), { Name = entry.Name, Facing = -1, MaxHealth = entry.MaxHealth })
			actor.AttackStyle = Models.AttackStyle(entry.DefId)
			self.Enemies[entry.Id] = actor
			actor.Arrived = true
			self:_enlist(actor, "Enemy", entry.Row or "Front")
			actor:Place(ROW_X.Enemy.Front + 5, 0)
			self:_layout()
			flash(scene, actor:Pos(), Color3.fromRGB(150, 230, 150), 4)
		end
	elseif t == "Wave" then
		-- a dungeon's next wave: clear away the fallen and announce it (the boss is the last wave)
		for id, enemy in pairs(self.Enemies) do
			if enemy.Alive == false or (enemy.Health or 1) <= 0 then
				self.Enemies[id] = nil
				enemy:Destroy()
			end
		end
		self:_layout()
		if self.OnBanner then
			self.OnBanner(if e.Wave == e.Of then "The boss appears!" else ("Wave %d / %d"):format(e.Wave, e.Of), Color3.fromRGB(255, 170, 70))
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
			safely(SkillEffects.Revive, scene, target:Pos())
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
	self.Formation = {}
	self.Heroes = {}
end

return Replay
