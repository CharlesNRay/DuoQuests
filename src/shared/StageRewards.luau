--[[
	StageRewards (ModuleScript): every stage you clear leaves a reward to collect on the map (once per season).

	Every stage pays gold, shards and Wishstones. Boss stages (every 10th) pay much more and ALWAYS include a Pet Wish and a
	Skill Wish ticket (more at higher boss stages).

	  StageRewards.For(stage)                -> { Gold, Shards, Wishstones, PetWish, SkillWish, Boss }
	  StageRewards.Text(stage)               -> "1.2K gold, 3 shards, 2 Wishstones, 1 Pet Wish ..."
	  StageRewards.Status(profile, stage)    -> "Locked" (not cleared yet) | "Ready" | "Claimed"
	  StageRewards.Claim(profile, stage)     -> true, reward   reasons: "BadStage", "NotCleared", "AlreadyClaimed"
	  StageRewards.ClaimAll(profile)         -> true, { Count, Gold, Shards, Wishstones, PetWish, SkillWish } (Count may be 0)
	  StageRewards.ReadyCount(profile)       -> how many are waiting
]]
local Progression = require(script.Parent.Progression)
local Stages = require(script.Parent.Stages)
local Consumables = require(script.Parent.Consumables)
local NumberFormat = require(script.Parent.Util.NumberFormat)

local StageRewards = {}

function StageRewards.For(stage)
	local clear = Progression.ClearRewards(stage, true, nil)
	local boss = Stages.IsBoss(stage)
	local reward = {
		Boss = boss,
		Gold = clear.Gold * (if boss then 8 else 2),
		Shards = clear.Shards * 2,
		Wishstones = if boss then 6 else (if stage % 5 == 0 then 2 else 1),
		PetWish = 0,
		SkillWish = 0,
	}
	if boss then
		local tickets = 1 + stage // 40 -- a boss always pays wishes: 1 of each, more on later bosses
		reward.PetWish, reward.SkillWish = tickets, tickets
	end
	return reward
end

function StageRewards.Text(stage)
	local r = StageRewards.For(stage)
	local parts = { ("%s gold"):format(NumberFormat.Short(r.Gold)), ("%d shards"):format(r.Shards), ("%d Wishstone%s"):format(r.Wishstones, if r.Wishstones == 1 then "" else "s") }
	if r.PetWish > 0 then
		table.insert(parts, ("%d Pet Wish"):format(r.PetWish))
	end
	if r.SkillWish > 0 then
		table.insert(parts, ("%d Skill Wish"):format(r.SkillWish))
	end
	return table.concat(parts, ", ")
end

local function claims(profile)
	local season = profile.Season
	if type(season.StageClaims) ~= "table" then
		season.StageClaims = {}
	end
	-- keyed by the stage as a STRING ("5"): a table keyed by stage numbers with gaps does not survive being
	-- sent to the client or saved. Older data used numbers: move them over.
	local claimsTable = season.StageClaims
	for key, value in pairs(claimsTable) do
		if type(key) == "number" then
			claimsTable[key] = nil
			claimsTable[tostring(key)] = value
		end
	end
	return claimsTable
end

-- the claimed stages as a plain sorted list of numbers (safe to send to the client)
function StageRewards.ClaimedList(profile)
	local list = {}
	for key in pairs(claims(profile)) do
		local stage = tonumber(key)
		if stage then
			table.insert(list, stage)
		end
	end
	table.sort(list)
	return list
end

function StageRewards.Status(profile, stage)
	if claims(profile)[tostring(stage)] then
		return "Claimed"
	end
	if stage < profile.Season.HighestStage then
		return "Ready"
	end
	return "Locked"
end

local function pay(profile, stage)
	local r = StageRewards.For(stage)
	local currencies = profile.Season.Currencies
	currencies.Gold += r.Gold
	currencies.Shards += r.Shards
	currencies.Wishstones = (currencies.Wishstones or 0) + r.Wishstones
	if r.PetWish > 0 then
		Consumables.Grant(profile, "PetWish", r.PetWish)
	end
	if r.SkillWish > 0 then
		Consumables.Grant(profile, "SkillWish", r.SkillWish)
	end
	claims(profile)[tostring(stage)] = true
	return r
end

function StageRewards.Claim(profile, stage)
	if type(stage) ~= "number" or stage < 1 or stage ~= math.floor(stage) then
		return false, "BadStage"
	end
	local status = StageRewards.Status(profile, stage)
	if status == "Claimed" then
		return false, "AlreadyClaimed"
	elseif status == "Locked" then
		return false, "NotCleared"
	end
	return true, pay(profile, stage)
end

function StageRewards.ReadyCount(profile)
	local n = 0
	local done = claims(profile)
	for stage = 1, profile.Season.HighestStage - 1 do
		if not done[tostring(stage)] then
			n += 1
		end
	end
	return n
end

function StageRewards.ClaimAll(profile)
	local total = { Count = 0, Gold = 0, Shards = 0, Wishstones = 0, PetWish = 0, SkillWish = 0 }
	local done = claims(profile)
	for stage = 1, profile.Season.HighestStage - 1 do
		if not done[tostring(stage)] then
			local r = pay(profile, stage)
			total.Count += 1
			total.Gold += r.Gold
			total.Shards += r.Shards
			total.Wishstones += r.Wishstones
			total.PetWish += r.PetWish
			total.SkillWish += r.SkillWish
		end
	end
	return true, total
end

return StageRewards
