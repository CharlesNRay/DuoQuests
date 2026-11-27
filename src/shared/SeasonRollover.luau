--[[
	SeasonRollover (ModuleScript)
	Location: ReplicatedStorage > Shared > SeasonRollover

	Moves a profile into a new season (pure; DataService calls it on every load, so it runs on the first join after a
	switch). Every character (the active one in profile.Season and the others in Permanent.Slots) keeps its class and
	starts again at level 1 with its starter skills. Config/Seasons.Carry says what it keeps (unused items, bag size,
	wish pity). Everything under Permanent is untouched.

	Also on a rollover:
	  * Permanent.SeasonHistory["<old id>"].Characters = { { ClassId, Level, HighestStage, SubclassId } } (kept forever)
	  * Wishstones won from a season's rewards while the player was still in that season wait in
	    Permanent.SeasonRewards.CarryWishstones and arrive in the new season (SeasonRewards.Claim puts them there)
	  * Permanent.SeasonNews = { From, To, At, Characters } for the "new season" card (cleared by SeasonRollover.SeenNews)

	  SeasonRollover.Needed(profile, seasonId)     -> true when any character is in an older season
	  SeasonRollover.Apply(profile, seasonId, now) -> the news table, or nil when nothing changed
	  SeasonRollover.SeenNews(profile)             -- the card was shown
]]

local Config = require(script.Parent.Config.Seasons)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local SeasonRollover = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

local function seasons(profile)
	-- { { get = fn, set = fn } } for every character's season table
	local out = {}
	table.insert(out, {
		get = function()
			return profile.Season
		end,
		set = function(s)
			profile.Season = s
		end,
	})
	for _, slot in ipairs(profile.Permanent.Slots or {}) do
		if slot.Season ~= nil then
			table.insert(out, {
				get = function()
					return slot.Season
				end,
				set = function(s)
					slot.Season = s
				end,
			})
		end
	end
	return out
end

function SeasonRollover.Needed(profile, seasonId)
	for _, entry in ipairs(seasons(profile)) do
		local s = entry.get()
		if type(s) == "table" and (s.SeasonId or 0) < seasonId then
			return true
		end
	end
	return false
end

-- Fresh season data for one character, with what it carries over.
local function fresh(old, seasonId)
	local classId = old.ClassId or "Warrior"
	local new = ProfileTemplate.NewSeasonData(seasonId)
	new.ClassId = classId
	ProfileTemplate.GrantClassStarters(new, classId)
	local carry = Config.Carry or {}
	if carry.Stash and type(old.Stash) == "table" then
		new.Stash = deepCopy(old.Stash)
	end
	if carry.BagUpgrades and old.Equipment and old.Equipment.BagUpgrades then
		new.Equipment.BagUpgrades = old.Equipment.BagUpgrades
	end
	if carry.WishPity and type(old.WishPity) == "table" then
		new.WishPity = deepCopy(old.WishPity)
	end
	return new
end

local function summary(old)
	local classId = old.ClassId or "Warrior"
	return {
		ClassId = classId,
		Level = old.Level or 1,
		HighestStage = old.HighestStage or 1,
		SubclassId = old.Subclasses and old.Subclasses[classId] or nil,
	}
end

function SeasonRollover.Apply(profile, seasonId, now)
	if not SeasonRollover.Needed(profile, seasonId) then
		return nil
	end
	local perm = profile.Permanent
	perm.SeasonHistory = perm.SeasonHistory or {}
	local from = nil
	local rows = {}
	local created = perm.Character and perm.Character.Created
	for index, entry in ipairs(seasons(profile)) do
		local old = entry.get()
		if type(old) == "table" and (old.SeasonId or 0) < seasonId then
			local oldId = old.SeasonId or 0
			from = if from == nil then oldId else math.max(from, oldId)
			-- the active season of a player who never made a character is only a placeholder: no summary
			if index > 1 or created then
				local row = summary(old)
				table.insert(rows, row)
				local key = tostring(oldId)
				local history = perm.SeasonHistory[key] or {}
				history.Characters = history.Characters or {}
				table.insert(history.Characters, table.clone(row)) -- its own copy: a table saved twice is refused
				perm.SeasonHistory[key] = history
			end
			entry.set(fresh(old, seasonId))
		end
	end
	-- season prize Wishstones that were claimed before the switch
	local rewards = perm.SeasonRewards
	if rewards and (rewards.CarryWishstones or 0) > 0 then
		local currencies = profile.Season.Currencies
		currencies.Wishstones = (currencies.Wishstones or 0) + rewards.CarryWishstones
		rewards.CarryWishstones = nil
	end
	local news = { From = from or 0, To = seasonId, At = now or os.time(), Characters = rows }
	if #rows > 0 then
		perm.SeasonNews = news
	end
	return news
end

function SeasonRollover.SeenNews(profile)
	profile.Permanent.SeasonNews = nil
end

return SeasonRollover
