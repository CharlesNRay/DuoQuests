--[[
	SkillProgress (ModuleScript)
	Location: ReplicatedStorage > Shared > SkillProgress

	Tier, rank and XP of the skills a player owns (Season.SkillState[abilityId] = { Tier, Rank, XP, Pending? }).
	A skill with no entry is rank 1 at its base rarity. Only tiers ABOVE the skill's own base rarity add levels
	(the base rarity's stronger numbers are already in Config/Abilities). Data: Config/SkillProgress. Pure functions; each action returns
	true, or false plus a reason, and changes NOTHING when it fails.

	  SkillProgress.Get(season, id)              -> { Tier, Rank, XP, Pending?, XPNeeded?, CanRank, CanUpgrade, Level }
	  SkillProgress.Level(season, id)            -> effective combat level (Rank + tier bonus), 1..20
	  SkillProgress.LevelMap(season)             -> { [id] = level } for every owned skill
	  SkillProgress.LevelsFor(loadout, map)      -> list of levels by slot
	  SkillProgress.Receive(season, id, rarity)  a skill copy was won: returns "New" | "Upgrade" | "Copy", amount?
	  SkillProgress.Consume(profile, id, rarity|"All")  spend banked copies (same or lower rarity) as XP
	  SkillProgress.RankUp(profile, id)          spend XP for the next rank  (reasons: "NotOwned", "MaxRank", "NotEnoughXP")
	  SkillProgress.Upgrade(profile, id)         apply a waiting higher tier   (reasons: "NotOwned", "NothingWaiting")
	  SkillProgress.Rows(season, classId, ids)   -> rows for the UI
]]

local Abilities = require(script.Parent.Config.Abilities)
local Config = require(script.Parent.Config.SkillProgress)
local Rarities = require(script.Parent.Config.Rarities)
local SubclassConfig = require(script.Parent.Config.Subclasses)

local SkillProgress = {}
SkillProgress.Config = Config

local TIER_RANK = {}
for index, name in ipairs(Config.TierOrder) do
	TIER_RANK[name] = index
end
SkillProgress.TierRank = TIER_RANK

-- rarities outside the four tiers (Uncommon) count as the tier below them
local function tierName(rarity)
	if TIER_RANK[rarity] then
		return rarity
	end
	local order = Rarities[rarity] and Rarities[rarity].Order or 1
	return if order >= 3 then "Epic" elseif order >= 2 then "Rare" else "Common"
end

local function baseTier(id)
	local def = Abilities[id]
	return tierName(def and def.Rarity or "Common")
end
SkillProgress.BaseTier = baseTier

-- A subclass path's signature skills arrive as Legendary the first time you wish one up.
local subclassSkills
function SkillProgress.IsSubclassSkill(id)
	if subclassSkills == nil then
		subclassSkills = {}
		for _, def in pairs(SubclassConfig.Defs) do
			for _, skillId in ipairs(def.Skills or {}) do
				subclassSkills[skillId] = true
			end
		end
	end
	return subclassSkills[id] == true
end

local function stateOf(season, id, create)
	season.SkillState = season.SkillState or {}
	local s = season.SkillState[id]
	if s == nil and create then
		s = { Tier = baseTier(id), Rank = 1, XP = 0 }
		season.SkillState[id] = s
	end
	return s
end

local function copiesOf(s)
	local out = {}
	for rarity, n in pairs(s.Copies or {}) do
		if n > 0 then
			out[rarity] = n
		end
	end
	return out
end

local function copyXP(s)
	local total = 0
	for rarity, n in pairs(s.Copies or {}) do
		total += n * (Config.DupXP[rarity] or 0)
	end
	return total
end

function SkillProgress.XPNeeded(rank)
	return Config.RankXP[rank]
end

function SkillProgress.Get(season, id)
	local s = stateOf(season, id, false) or { Tier = baseTier(id), Rank = 1, XP = 0 }
	local rank = math.clamp(s.Rank or 1, 1, Config.MaxRank)
	local need = Config.RankXP[rank]
	local owned = season.OwnedAbilities[id] ~= nil
	return {
		Tier = s.Tier or baseTier(id), Rank = rank, MaxRank = Config.MaxRank, XP = s.XP or 0, XPNeeded = need, Pending = s.Pending,
		CanRank = owned and need ~= nil and (s.XP or 0) >= need,
		CanUpgrade = owned and s.Pending ~= nil and TIER_RANK[s.Pending] > TIER_RANK[s.Tier or baseTier(id)],
		Copies = copiesOf(s), CopyXP = copyXP(s), CanConsume = owned and rank < Config.MaxRank and copyXP(s) > 0,
		Level = rank + math.max(0, Config.TierBonus[s.Tier or baseTier(id)] - Config.TierBonus[baseTier(id)]),
	}
end

function SkillProgress.Level(season, id)
	return math.clamp(SkillProgress.Get(season, id).Level, 1, 20)
end

function SkillProgress.LevelMap(season)
	local map = {}
	for id in pairs(season.OwnedAbilities) do
		if Abilities[id] then
			map[id] = SkillProgress.Level(season, id)
		end
	end
	return map
end

function SkillProgress.LevelsFor(loadout, map)
	local levels = {}
	for index, id in ipairs(loadout or {}) do
		levels[index] = (map and map[id]) or 1
	end
	return levels
end

function SkillProgress.SlotLevelsFor(season, loadout)
	return SkillProgress.LevelsFor(loadout, SkillProgress.LevelMap(season))
end

-- { [id] = Get(...) } for every owned skill (what the client shows)
function SkillProgress.Info(season)
	local info = {}
	for id in pairs(season.OwnedAbilities) do
		if Abilities[id] then
			info[id] = SkillProgress.Get(season, id)
		end
	end
	return info
end

-- A copy of a skill at `rarity` was won (the skill is already owned, or is being given now).
-- "New": first copy (held at the rarity it dropped as; a subclass skill is always Legendary). "Upgrade": a higher tier is now waiting (any lower waiting
-- copy turns into XP). "Copy": spare copy, banked until the player consumes it for XP (SkillProgress.Consume).
function SkillProgress.Receive(season, id, rarity)
	rarity = tierName(rarity)
	if season.OwnedAbilities[id] == nil then
		season.OwnedAbilities[id] = true
		local s = stateOf(season, id, true)
		s.Tier = if SkillProgress.IsSubclassSkill(id) then "Legendary" elseif TIER_RANK[rarity] > TIER_RANK[baseTier(id)] then rarity else baseTier(id)
		return "New"
	end
	local s = stateOf(season, id, true)
	local holding = if s.Pending and TIER_RANK[s.Pending] > TIER_RANK[s.Tier] then s.Pending else s.Tier
	if TIER_RANK[rarity] > TIER_RANK[holding] then
		local displaced = nil
		if s.Pending and TIER_RANK[s.Pending] > TIER_RANK[s.Tier] then
			displaced = s.Pending
			s.Copies = s.Copies or {}
			s.Copies[displaced] = (s.Copies[displaced] or 0) + 1
		end
		s.Pending = rarity
		return "Upgrade", displaced
	end
	s.Copies = s.Copies or {}
	s.Copies[rarity] = (s.Copies[rarity] or 0) + 1
	return "Copy", 1
end

-- Consume banked copies for XP. rarity = "Common" | "Rare" | "Epic" | "Legendary" | "All"; only copies of the same or a lower
-- rarity than the skill's tier (or the tier waiting) are used. Reasons: "NotOwned", "MaxRank", "NoCopies"
function SkillProgress.Consume(profile, id, rarity)
	local season = profile.Season
	if type(id) ~= "string" or Abilities[id] == nil or season.OwnedAbilities[id] == nil then
		return false, "NotOwned"
	end
	local s = stateOf(season, id, true)
	if s.Rank >= Config.MaxRank then
		return false, "MaxRank"
	end
	local ceiling = math.max(TIER_RANK[s.Tier], s.Pending and TIER_RANK[s.Pending] or 0)
	local gained, used = 0, 0
	for _, name in ipairs(Config.TierOrder) do
		local n = s.Copies and s.Copies[name] or 0
		if n > 0 and (rarity == "All" or rarity == nil or rarity == name) and TIER_RANK[name] <= ceiling then
			gained += n * Config.DupXP[name]
			used += n
			s.Copies[name] = 0
		end
	end
	if used == 0 then
		return false, "NoCopies"
	end
	s.XP = (s.XP or 0) + gained
	return true, gained
end

function SkillProgress.RankUp(profile, id)
	local season = profile.Season
	if type(id) ~= "string" or Abilities[id] == nil or season.OwnedAbilities[id] == nil then
		return false, "NotOwned"
	end
	local s = stateOf(season, id, true)
	if s.Rank >= Config.MaxRank then
		return false, "MaxRank"
	end
	local need = Config.RankXP[s.Rank]
	if (s.XP or 0) < need then
		return false, "NotEnoughXP"
	end
	s.XP -= need
	s.Rank += 1
	return true, s.Rank
end

function SkillProgress.Upgrade(profile, id)
	local season = profile.Season
	if type(id) ~= "string" or Abilities[id] == nil or season.OwnedAbilities[id] == nil then
		return false, "NotOwned"
	end
	local s = stateOf(season, id, true)
	if s.Pending == nil or TIER_RANK[s.Pending] <= TIER_RANK[s.Tier] then
		return false, "NothingWaiting"
	end
	s.Tier, s.Pending = s.Pending, nil
	return true, s.Tier
end

-- Is anything on the Skills page ready to be pressed? (a badge for the dock)
function SkillProgress.AnyReady(season)
	for id in pairs(season.OwnedAbilities) do
		if Abilities[id] then
			local g = SkillProgress.Get(season, id)
			if g.CanRank or g.CanUpgrade or g.CanConsume then
				return true
			end
		end
	end
	return false
end

return SkillProgress
