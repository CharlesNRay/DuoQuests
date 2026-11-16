--[[
	Character (ModuleScript)
	Location: ReplicatedStorage > Shared > Character

	The character creator's rules: name, class and look. Pure logic; the server wraps Name in Roblox's text filter.
	Saved in Permanent.Character = { Created, Name, Look = { Skin, Hair, Outfit }, UseAvatar, Renames }.

	  Character.Get(profile)                      -> the saved table (filled with defaults)
	  Character.CheckName(text)                   -> true, cleaned | false, "TooShort" | "TooLong" | "BadCharacters" | "Blocked"
	  Character.CleanLook(look)                   -> { Skin, Hair, Outfit } valid indexes (bad values fall back to defaults)
	  Character.Playable(profile, classId)        -> boolean (a class that exists and is not Locked; picking it at creation unlocks it)
	  Character.Create(profile, name, classId, look, useAvatar) -> true | false, reason ("AlreadyCreated", "BadClass", or a name reason)
	  Character.SetLook(profile, look, useAvatar) -> true | false, "NotCreated"
	  Character.Rename(profile, name, premium)    -> true, cost | false, reason ("NotCreated", "NotEnough", name reasons)
	  Character.DisplayName(profile, fallback)    -> the chosen name, or fallback
	  Character.Colors(profile)                   -> { Skin = {r,g,b}, Hair = ..., Outfit = ..., UseAvatar } for drawing
]]

local Config = require(script.Parent.Config.Character)
local Classes = require(script.Parent.Config.Classes)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local Character = {}

function Character.Get(profile)
	local c = profile.Permanent.Character
	if c == nil then
		c = {}
		profile.Permanent.Character = c
	end
	c.Created = c.Created == true
	c.Name = c.Name or ""
	c.Look = c.Look or { Skin = Config.Defaults.Skin, Hair = Config.Defaults.Hair, Outfit = Config.Defaults.Outfit }
	c.UseAvatar = c.UseAvatar == true
	c.Renames = c.Renames or 0
	return c
end

function Character.CheckName(text)
	if type(text) ~= "string" then
		return false, "TooShort"
	end
	local cleaned = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if cleaned:find("[^%w _%-]") then
		return false, "BadCharacters"
	end
	if #cleaned < Config.Name.Min then
		return false, "TooShort"
	end
	if #cleaned > Config.Name.Max then
		return false, "TooLong"
	end
	local letters = cleaned:lower():gsub("[^%a]", "")
	for _, word in ipairs(Config.Blocked) do
		if letters:find(word, 1, true) then
			return false, "Blocked"
		end
	end
	return true, cleaned
end

local function index(value, list, default)
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= #list then
		return value
	end
	return default
end

function Character.CleanLook(look)
	look = type(look) == "table" and look or {}
	return {
		Skin = index(look.Skin, Config.Skins, Config.Defaults.Skin),
		Hair = index(look.Hair, Config.HairColors, Config.Defaults.Hair),
		Outfit = index(look.Outfit, Config.Outfits, Config.Defaults.Outfit),
	}
end

function Character.Playable(profile, classId)
	local def = Classes[classId]
	return def ~= nil and not def.Locked
end

function Character.Create(profile, name, classId, look, useAvatar)
	local c = Character.Get(profile)
	if c.Created then
		return false, "AlreadyCreated"
	end
	local ok, cleaned = Character.CheckName(name)
	if not ok then
		return false, cleaned
	end
	if not Character.Playable(profile, classId) then
		return false, "BadClass"
	end
	c.Created = true
	c.Name = cleaned
	c.Look = Character.CleanLook(look)
	c.UseAvatar = useAvatar == true
	profile.Permanent.UnlockedClasses[classId] = true
	ProfileTemplate.GrantClassStarters(profile.Season, classId)
	profile.Season.ClassId = classId
	return true
end

-- The simple flow: a player only picks a class. Their Roblox name and avatar are used, so there is no name or look to set.
function Character.ChooseClass(profile, classId)
	local c = Character.Get(profile)
	if c.Created then
		return false, "AlreadyCreated"
	end
	if not Character.Playable(profile, classId) then
		return false, "BadClass"
	end
	c.Created = true
	c.Name = ""
	c.UseAvatar = true
	profile.Permanent.UnlockedClasses[classId] = true
	ProfileTemplate.GrantClassStarters(profile.Season, classId)
	profile.Season.ClassId = classId
	return true
end

function Character.SetLook(profile, look, useAvatar)
	local c = Character.Get(profile)
	if not c.Created then
		return false, "NotCreated"
	end
	c.Look = Character.CleanLook(look)
	c.UseAvatar = useAvatar == true
	return true
end

function Character.Rename(profile, name, premium)
	local c = Character.Get(profile)
	if not c.Created then
		return false, "NotCreated"
	end
	local ok, cleaned = Character.CheckName(name)
	if not ok then
		return false, cleaned
	end
	if cleaned == c.Name then
		return true, 0
	end
	local spent, why = premium.SpendSunstones(profile, Config.RenameCost)
	if not spent then
		return false, why
	end
	c.Name = cleaned
	c.Renames += 1
	return true, Config.RenameCost
end

function Character.DisplayName(profile, fallback)
	local c = Character.Get(profile)
	if c.Created and c.Name ~= "" then
		return c.Name
	end
	return fallback
end

function Character.Colors(profile)
	local c = Character.Get(profile)
	return {
		Skin = Config.Skins[c.Look.Skin], Hair = Config.HairColors[c.Look.Hair], Outfit = Config.Outfits[c.Look.Outfit], UseAvatar = c.UseAvatar,
	}
end

return Character
