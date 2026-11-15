--[[
	BossService (ModuleScript)
	Location: ServerScriptService > Server > Services > BossService

	Runs the two boss events (rules in Shared/Bosses, data in Shared/Config/Bosses).

	  BossService.Init(push, getProfile)
	  BossService.GetState(player, profile)       -> table for the client's Boss window
	  BossService.Strike(player, profile, which)  "World" | "Season" -> true, { Damage, ... } | false, reason
	  BossService.Claim(player, profile, id)      -> true, lines | false, reason
	  BossService.Hatch(player, profile)          -> true, petId | false, reason

	WORLD BOSS  a giant that stands by the plaza on a timer; everyone strikes it; at the end of its timer
	            players get every damage tier they reached (this server only).
	SEASON BOSS shared by all servers: each server batches its players' damage and adds it to one
	            DataStore counter every few seconds (UpdateAsync); the shared total is the boss's permanent
	            health loss. In Studio (no DataStore access) it falls back to a local counter.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared.Bosses)
local Quests = require(Shared.Quests)
local Cfg = require(Shared.Config.Bosses)
local SeasonConfig = require(Shared.Config.Seasons)

local BossService = {}

local IS_STUDIO = RunService:IsStudio()
local WORLD = Cfg.World
local SEASON = Cfg.Season
local seasonId = SeasonConfig.CurrentSeasonId
local seasonInfo = SeasonConfig.Seasons[seasonId]

local push, getProfile
local worldModel, colossusModel, hpLabel
local rng = Random.new()

-- world boss state ----------------------------------------------------------------------------------
local world = { Active = false, StartsAt = 0, EndsAt = 0, Totals = {}, Strikes = {}, LastStrike = {}, Frontier = {} }

local function firstSpawn() return IS_STUDIO and WORLD.StudioFirstSpawn or WORLD.FirstSpawnSeconds end
local function interval() return IS_STUDIO and WORLD.StudioInterval or WORLD.IntervalSeconds end
local function duration() return IS_STUDIO and WORLD.StudioDuration or WORLD.DurationSeconds end

-- season boss state ---------------------------------------------------------------------------------
local season = { GlobalDamage = 0, Pending = 0, Strikes = 0 }
local store

local function glowPart(parent, name, size, position, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Slate
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

-- Models --------------------------------------------------------------------------------------------

local function buildWorldBoss()
	local c = WORLD.Look.Color
	local color = Color3.fromRGB(c[1], c[2], c[3])
	local h = WORLD.Look.Height
	local model = Instance.new("Model")
	model.Name = "WorldBoss"
	local root = glowPart(model, "Body", Vector3.new(h * 0.5, h * 0.55, h * 0.35), Vector3.new(0, h * 0.55, 0), color)
	root.Shape = Enum.PartType.Block
	model.PrimaryPart = root
	local function limb(name, size, offset)
		local part = glowPart(model, name, size, root.Position + offset, color:Lerp(Color3.new(0, 0, 0), 0.2))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
		return part
	end
	limb("Head", Vector3.new(h * 0.32, h * 0.3, h * 0.3), Vector3.new(0, h * 0.42, 0))
	limb("ArmL", Vector3.new(h * 0.16, h * 0.5, h * 0.16), Vector3.new(-h * 0.36, 0, 0))
	limb("ArmR", Vector3.new(h * 0.16, h * 0.5, h * 0.16), Vector3.new(h * 0.36, 0, 0))
	limb("LegL", Vector3.new(h * 0.18, h * 0.45, h * 0.18), Vector3.new(-h * 0.14, -h * 0.5, 0))
	limb("LegR", Vector3.new(h * 0.18, h * 0.45, h * 0.18), Vector3.new(h * 0.14, -h * 0.5, 0))
	for _, side in ipairs({ -1, 1 }) do
		local eye = limb("Eye", Vector3.new(h * 0.06, h * 0.06, h * 0.04), Vector3.new(side * h * 0.08, h * 0.45, -h * 0.16))
		eye.Color = Color3.fromRGB(255, 80, 60)
		eye.Material = Enum.Material.Neon
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(240, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, h * 0.5, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = root
	tag.Parent = root
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "👹 " .. WORLD.Name
	label.Parent = tag
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Challenge"
	prompt.ObjectText = WORLD.Name
	prompt.MaxActivationDistance = h * 0.9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		push:FireClient(player, "OpenBoss", "World")
	end)
	model.Parent = workspace
	return model
end

local function buildColossus()
	local c = SEASON.Look.Color
	local color = Color3.fromRGB(c[1], c[2], c[3])
	local h = SEASON.Look.Height
	local model = Instance.new("Model")
	model.Name = "SeasonBoss"
	local origin = Vector3.new(0, 0, 190)
	local altar = glowPart(model, "Altar", Vector3.new(34, 3, 34), origin + Vector3.new(0, 1.5, 0), Color3.fromRGB(110, 110, 118))
	local body = glowPart(model, "Body", Vector3.new(h * 0.45, h * 0.45, h * 0.3), origin + Vector3.new(0, 3 + h * 0.35, 0), color)
	model.PrimaryPart = body
	glowPart(model, "Head", Vector3.new(h * 0.22, h * 0.2, h * 0.2), origin + Vector3.new(0, 3 + h * 0.72, 0), color:Lerp(Color3.new(1, 1, 1), 0.1))
	glowPart(model, "ArmL", Vector3.new(h * 0.14, h * 0.42, h * 0.14), origin + Vector3.new(-h * 0.3, 3 + h * 0.35, 0), color:Lerp(Color3.new(0, 0, 0), 0.2))
	glowPart(model, "ArmR", Vector3.new(h * 0.14, h * 0.42, h * 0.14), origin + Vector3.new(h * 0.3, 3 + h * 0.35, 0), color:Lerp(Color3.new(0, 0, 0), 0.2))
	for _, side in ipairs({ -1, 1 }) do
		local eye = glowPart(model, "Eye", Vector3.new(h * 0.04, h * 0.04, h * 0.03), origin + Vector3.new(side * h * 0.05, 3 + h * 0.74, -h * 0.1), Color3.fromRGB(150, 255, 150), nil, Enum.Material.Neon)
		eye.Name = "Eye"
	end
	for _, part in ipairs(model:GetChildren()) do
		part.Anchored = true
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(300, 70)
	tag.StudsOffsetWorldSpace = Vector3.new(0, h * 0.55, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = body
	tag.Parent = body
	hpLabel = Instance.new("TextLabel")
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.fromRGB(190, 255, 190)
	hpLabel.TextStrokeTransparency = 0.3
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextScaled = true
	hpLabel.Text = SEASON.Name
	hpLabel.Parent = tag
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Challenge"
	prompt.ObjectText = SEASON.Name
	prompt.MaxActivationDistance = 40
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
	prompt.Triggered:Connect(function(player)
		push:FireClient(player, "OpenBoss", "Season")
	end)
	model.Parent = workspace
	return model
end

-- Season health -------------------------------------------------------------------------------------

local function seasonNow()
	return os.time()
end

local function seasonHealth()
	return Bosses.SeasonHealth(SEASON, season.GlobalDamage + season.Pending, seasonNow(), seasonInfo.StartsAt, seasonInfo.EndsAt)
end

local function refreshColossus()
	local _, fraction = seasonHealth()
	if hpLabel then
		hpLabel.Text = fraction > 0 and ("%s  %d%%"):format(SEASON.Name, math.ceil(fraction * 100)) or (SEASON.Name .. " - defeated")
	end
	if colossusModel then
		for _, part in ipairs(colossusModel:GetChildren()) do
			if part.Name == "Eye" then
				part.Transparency = fraction > 0 and 0 or 1
			end
		end
	end
end

local function syncSeason()
	local delta = season.Pending
	if store then
		local ok, result = pcall(function()
			return store:UpdateAsync("S" .. seasonId, function(old)
				return (old or 0) + delta
			end)
		end)
		if ok and type(result) == "number" then
			season.GlobalDamage = result
			season.Pending -= delta
			return
		end
	end
	-- Studio / failure: keep it local so the loop still works
	season.GlobalDamage += delta
	season.Pending -= delta
end

-- World boss loop -----------------------------------------------------------------------------------

local function startWorldEvent()
	world.Active = true
	world.StartsAt = os.time()
	world.EndsAt = world.StartsAt + duration()
	world.Totals, world.Strikes, world.LastStrike, world.Frontier = {}, {}, {}, {}
	if worldModel then
		worldModel.Parent = workspace
	end
	push:FireAllClients("BossEvent", { Kind = "WorldStart", Name = WORLD.Name, Seconds = duration() })
end

local function endWorldEvent()
	world.Active = false
	if worldModel then
		worldModel.Parent = nil
	end
	for userId, damage in pairs(world.Totals) do
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and getProfile(player)
		if profile then
			local frontier = profile.Season.HighestStage
			local tiers = Bosses.TiersReached(WORLD, damage, frontier)
			local lines = {}
			for _, tier in ipairs(tiers) do
				for _, line in ipairs(Bosses.GrantRewards(profile, tier.Rewards, frontier)) do
					table.insert(lines, line)
				end
			end
			push:FireClient(player, "BossEvent", { Kind = "WorldEnd", Damage = damage, Tiers = #tiers, Lines = lines })
		end
	end
	push:FireAllClients("BossEvent", { Kind = "WorldGone" })
end

-- API -----------------------------------------------------------------------------------------------

local function describeTiers(profile)
	local frontier = profile.Season.HighestStage
	local scale = Bosses.DamageScale(frontier)
	local list = {}
	for _, tier in ipairs(WORLD.Tiers) do
		table.insert(list, { Id = tier.Id, Name = tier.Name, Need = math.floor(tier.Damage * scale), Rewards = Bosses.Describe(tier.Rewards) })
	end
	return list
end

function BossService.GetState(player, profile)
	local now = os.time()
	local frontier = profile.Season.HighestStage
	local my = world.Totals[player.UserId] or 0
	local sinceStrike = os.clock() - (world.LastStrike[player.UserId] or -1e9)
	local worldState = {
		Name = WORLD.Name,
		Active = world.Active,
		EndsIn = world.Active and math.max(0, world.EndsAt - now) or 0,
		NextIn = (not world.Active) and math.max(0, (world.NextAt or now) - now) or 0,
		Damage = my,
		Strikes = world.Strikes[player.UserId] or 0,
		MaxStrikes = WORLD.MaxStrikes,
		CooldownLeft = math.max(0, math.ceil(WORLD.StrikeCooldown - sinceStrike)),
		Tiers = describeTiers(profile),
		Reached = #Bosses.TiersReached(WORLD, my, frontier),
	}

	local hp, fraction = seasonHealth()
	local chargeSeconds = IS_STUDIO and SEASON.StudioChargeSeconds or SEASON.ChargeSeconds
	local charges, nextIn = Bosses.Charges(profile, seasonId, now, chargeSeconds, SEASON.MaxCharges)
	local record = Bosses.Record(profile, seasonId)
	local thresholds = {}
	local crossed = {}
	for _, t in ipairs(Bosses.SeasonCrossed(SEASON, fraction)) do
		crossed[t.Id] = true
	end
	for _, t in ipairs(SEASON.Thresholds) do
		table.insert(thresholds, {
			Id = t.Id, Name = t.Name, Pct = t.Pct, Reached = crossed[t.Id] == true,
			Claimed = record.Claimed[t.Id] == true, Rewards = Bosses.Describe(t.Rewards),
		})
	end
	local seasonState = {
		Name = SEASON.Name,
		Health = math.floor(hp),
		MaxHealth = SEASON.MaxHealth,
		Fraction = fraction,
		Dead = hp <= 0,
		EndsIn = math.max(0, seasonInfo.EndsAt - now),
		Damage = record.Damage,
		Strikes = record.Strikes,
		Charges = charges,
		MaxCharges = SEASON.MaxCharges,
		NextChargeIn = math.ceil(nextIn),
		Egg = record.Egg,
		Hatched = record.Hatched,
		Thresholds = thresholds,
		EggPet = SEASON.EggPet,
		MinContribution = SEASON.MinContribution,
	}
	return { World = worldState, Season = seasonState }
end

local function runFight(profile, player, cfg, frontier, partner)
	local members = { { Id = tostring(player.UserId), Name = player.Name, Profile = profile } }
	if partner then
		table.insert(members, { Id = partner.Id, Name = partner.Name, Snapshot = partner.Snapshot })
	end
	local damage, _, fight = Bosses.Strike(members, cfg, frontier, rng:NextInteger(1, 1e9), true)
	return damage, fight
end

function BossService.Strike(player, profile, which, partner)
	local frontier = profile.Season.HighestStage
	if which == "World" then
		if not world.Active then
			return false, "NotActive"
		end
		local userId = player.UserId
		if (world.Strikes[userId] or 0) >= WORLD.MaxStrikes then
			return false, "NoStrikesLeft"
		end
		if os.clock() - (world.LastStrike[userId] or -1e9) < WORLD.StrikeCooldown then
			return false, "Cooldown"
		end
		world.LastStrike[userId] = os.clock()
		world.Strikes[userId] = (world.Strikes[userId] or 0) + 1
		local damage, fight = runFight(profile, player, WORLD, frontier, partner)
		Quests.Record(profile, "Strike", 1)
		world.Totals[userId] = (world.Totals[userId] or 0) + damage
		return true, { Damage = damage, Total = world.Totals[userId], Reached = #Bosses.TiersReached(WORLD, world.Totals[userId], frontier), Fight = fight, Label = WORLD.Name }
	elseif which == "Season" then
		local _, fraction = seasonHealth()
		if fraction <= 0 then
			return false, "Defeated"
		end
		local chargeSeconds = IS_STUDIO and SEASON.StudioChargeSeconds or SEASON.ChargeSeconds
		local ok, reason = Bosses.SpendCharge(profile, seasonId, os.time(), chargeSeconds, SEASON.MaxCharges)
		if not ok then
			return false, reason
		end
		local damage, fight = runFight(profile, player, SEASON, frontier, partner)
		-- the season boss is much tougher, so a strike is worth a lot more of its health bar
		damage = math.floor(damage * (SEASON.DamageMult or 1))
		Quests.Record(profile, "Strike", 1)
		local record = Bosses.Record(profile, seasonId)
		record.Damage += damage
		record.Strikes += 1
		season.Pending += damage
		refreshColossus()
		local _, after = seasonHealth()
		return true, { Damage = damage, Fraction = after, Fight = fight, Label = SEASON.Name }
	end
	return false, "BadArgs"
end

function BossService.Claim(player, profile, thresholdId)
	local _, fraction = seasonHealth()
	return Bosses.Claim(profile, seasonId, SEASON, thresholdId, fraction, profile.Season.HighestStage)
end

function BossService.Hatch(player, profile)
	return Bosses.Hatch(profile, seasonId, SEASON)
end

function BossService.Init(pushRemote, profileGetter)
	push, getProfile = pushRemote, profileGetter
	worldModel = buildWorldBoss()
	worldModel:PivotTo(CFrame.new(105, WORLD.Look.Height * 0.55, 150))
	worldModel.Parent = nil
	colossusModel = buildColossus()

	if not IS_STUDIO then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("DuoQuestSeasonBoss")
		end)
		store = ok and result or nil
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync("S" .. seasonId)
		end)
		season.GlobalDamage = ok and type(value) == "number" and value or 0
	end
	refreshColossus()

	task.spawn(function() -- season sync
		while true do
			task.wait(SEASON.SyncSeconds)
			if season.Pending ~= 0 or store then
				syncSeason()
			end
			refreshColossus()
		end
	end)

	task.spawn(function() -- world event schedule
		world.NextAt = os.time() + firstSpawn()
		while true do
			task.wait(1)
			if not world.Active and os.time() >= world.NextAt then
				startWorldEvent()
			elseif world.Active and os.time() >= world.EndsAt then
				endWorldEvent()
				world.NextAt = os.time() + interval()
			end
		end
	end)

	game:BindToClose(function()
		if season.Pending ~= 0 then
			syncSeason()
		end
	end)
end

return BossService
