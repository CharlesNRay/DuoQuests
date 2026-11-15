--[[
	Leaderboards (ModuleScript)
	Location: ReplicatedStorage > Shared > Leaderboards

	Pure ranking rules; the server service stores and fetches the numbers.

	  Leaderboards.Categories           list of { Id, Name, Unit }
	  Leaderboards.ScoreFor(categoryId, profile)   -> whole number
	  Leaderboards.Rank(entries, limit)  entries: { { UserId, Name, Value } }
	                                     -> sorted rows { Rank, UserId, Name, Value }
	                                     (highest first; ties broken by name then id,
	                                     equal values share no rank: rank is the
	                                     position in the list)
	  Leaderboards.PositionOf(rows, userId)  -> rank or nil
	  Leaderboards.Format(categoryId, value) -> "Stage 42" / "Level 17"

	Categories are SEASONAL: stored per season, so a new season starts a fresh
	board. Legacy / all-time boards can be added later as extra categories.
]]

local Leaderboards = {}

Leaderboards.Categories = {
	{ Id = "Stage", Name = "Furthest stage", Unit = "Stage" },
	{ Id = "Level", Name = "Highest level", Unit = "Level" },
}

local SCORERS = {
	Stage = function(profile)
		return profile.Season.HighestStage
	end,
	Level = function(profile)
		return profile.Season.Level
	end,
}

function Leaderboards.IsCategory(categoryId)
	return SCORERS[categoryId] ~= nil
end

function Leaderboards.ScoreFor(categoryId, profile)
	local scorer = SCORERS[categoryId]
	assert(scorer ~= nil, "Unknown leaderboard category: " .. tostring(categoryId))
	return math.max(0, math.floor(scorer(profile)))
end

function Leaderboards.Rank(entries, limit)
	local sorted = {}
	for _, entry in ipairs(entries) do
		if type(entry.Value) == "number" and entry.UserId ~= nil then
			table.insert(sorted, { UserId = entry.UserId, Name = entry.Name or "?", Value = entry.Value })
		end
	end
	table.sort(sorted, function(a, b)
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		if a.Name ~= b.Name then
			return a.Name < b.Name
		end
		return a.UserId < b.UserId
	end)
	local rows = {}
	for index, entry in ipairs(sorted) do
		if limit and index > limit then
			break
		end
		entry.Rank = index
		table.insert(rows, entry)
	end
	return rows
end

function Leaderboards.PositionOf(rows, userId)
	for _, row in ipairs(rows) do
		if row.UserId == userId then
			return row.Rank
		end
	end
	return nil
end

function Leaderboards.Format(categoryId, value)
	for _, category in ipairs(Leaderboards.Categories) do
		if category.Id == categoryId then
			return ("%s %d"):format(category.Unit, value)
		end
	end
	return tostring(value)
end

return Leaderboards
