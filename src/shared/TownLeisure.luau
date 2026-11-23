--[[
	TownLeisure (ModuleScript): the pet park and the hidden relics (docs/TOWN.md phases 3 and 5). Pure.

	Pet park (Wishing Grove): once a day, play with your active pet: it gains PET_XP (or shard progress when it is
	already at your level).
	  TownLeisure.PetPlay(profile, day)   -> true, { Lines } | false, "DoneToday" | "NoPet"
	  TownLeisure.PetPlayed(profile, day) -> bool

	Relics: RELIC_COUNT glowing relics hidden round the town (World.TownSpots Relic1..N). Each pays RELIC_STONES
	Wishstones once a season; finding them all adds ALL_BONUS Wishstones and the title ALL_TITLE.
	Season.Relics = { [relicId] = true }
	  TownLeisure.TakeRelic(profile, id)  -> true, { Lines, Found, Total, All } | false, "BadRelic" | "Found"
	  TownLeisure.Relics(profile)         -> { Found = { [id] = true }, Count, Total }
]]
local Pets = require(script.Parent.Pets)
local Cosmetics = require(script.Parent.Cosmetics)

local TownLeisure = {}

TownLeisure.PET_XP = 4000
TownLeisure.RELIC_COUNT = 10
TownLeisure.RELIC_STONES = 2
TownLeisure.ALL_BONUS = 10
TownLeisure.ALL_TITLE = "Relic Hunter"

function TownLeisure.PetPlayed(profile, day)
	return profile.Season.PetPlayDay == day
end

function TownLeisure.PetPlay(profile, day)
	if TownLeisure.PetPlayed(profile, day) then
		return false, "DoneToday"
	end
	local petId = Pets.Active(profile)
	if not petId then
		return false, "NoPet"
	end
	profile.Season.PetPlayDay = day
	local ok, gained = Pets.AddXP(profile, petId, TownLeisure.PET_XP)
	if ok then
		return true, { Lines = { ("+%d pet XP"):format(TownLeisure.PET_XP) .. (if (gained or 0) > 0 then (" (+%d level%s!)"):format(gained, if gained == 1 then "" else "s") else "") } }
	end
	-- at your level already: the fun becomes shard progress, like pet food
	Pets.OverflowFood(profile, petId, TownLeisure.PET_XP)
	return true, { Lines = { "Your pet is at your level: the playtime became pet shard progress" } }
end

local function isRelic(id)
	local n = tonumber(tostring(id):match("^Relic(%d+)$"))
	return n ~= nil and n >= 1 and n <= TownLeisure.RELIC_COUNT
end

function TownLeisure.Relics(profile)
	local found = profile.Season.Relics or {}
	local count = 0
	for id in pairs(found) do
		if isRelic(id) then
			count += 1
		end
	end
	return { Found = table.clone(found), Count = count, Total = TownLeisure.RELIC_COUNT }
end

function TownLeisure.TakeRelic(profile, id)
	if not isRelic(id) then
		return false, "BadRelic"
	end
	profile.Season.Relics = profile.Season.Relics or {}
	if profile.Season.Relics[id] then
		return false, "Found"
	end
	profile.Season.Relics[id] = true
	local c = profile.Season.Currencies
	c.Wishstones = (c.Wishstones or 0) + TownLeisure.RELIC_STONES
	local lines = { ("+%d Wishstones"):format(TownLeisure.RELIC_STONES) }
	local status = TownLeisure.Relics(profile)
	local all = status.Count >= TownLeisure.RELIC_COUNT
	if all then
		c.Wishstones += TownLeisure.ALL_BONUS
		Cosmetics.GrantTitle(profile, TownLeisure.ALL_TITLE)
		table.insert(lines, ("All relics found! +%d Wishstones and the title \"%s\""):format(TownLeisure.ALL_BONUS, TownLeisure.ALL_TITLE))
	end
	return true, { Lines = lines, Found = status.Count, Total = status.Total, All = all }
end

return TownLeisure
