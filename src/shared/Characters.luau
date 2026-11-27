--[[
	Characters (ModuleScript)
	Location: ReplicatedStorage > Shared > Characters

	The main menu's characters. A character is just a class choice with its own season progress (level, gear, skills,
	stage frontier, currencies). A player keeps up to Max(profile) of them (MAX, +2 with the "Extra Character Slots"
	Game Pass, Config/Premium) and picks one to play at the main menu.

	Saved in Permanent.Slots (a list) and Permanent.ActiveSlot (0 = none yet):
	  Slots[i] = { ClassId, Season = <that character's season data, only while it is NOT the one being played> }
	profile.Season always holds the season data of the ACTIVE character, so the rest of the game needs no changes. Selecting
	another character stashes the current Season in its slot and loads the other one.

	Permanent.Character.Created is kept true while a character is active, so older checks keep working.

	  Characters.MAX                        -> 2 (without the pass)
	  Characters.Max(profile)               -> MAX + the pass's CharacterSlots (4 with it)
	  Characters.Ensure(profile)            -- migrates an old single-class profile into slot 1 (safe to call any time)
	  Characters.List(profile)              -> { { Slot, ClassId, Level, HighestStage, SubclassId?, Active } }
	  Characters.Create(profile, classId)   -> true, slot | false, "Full" | "BadClass"   (does not start playing it)
	  Characters.Select(profile, slot)      -> true | false, "BadSlot"   (makes it the active character)
	  Characters.Active(profile)            -> slot number or 0
	  Characters.Enter(profile) / Characters.Entered(profile)   per-session: has the player pressed Play yet? (not saved)
]]

local ProfileTemplate = require(script.Parent.ProfileTemplate)
local SeasonClock = require(script.Parent.SeasonClock)
local Character = require(script.Parent.Character)
local Gear = require(script.Parent.Gear)
local Passes = require(script.Parent.Passes)

local Characters = {}

Characters.MAX = 2

function Characters.Max(profile)
	return Characters.MAX + (Passes.Perks(profile).CharacterSlots or 0)
end

local entered = setmetatable({}, { __mode = "k" }) -- [profile] = true once the player has picked a character this session

local function slots(profile)
	local p = profile.Permanent
	p.Slots = p.Slots or {}
	p.ActiveSlot = p.ActiveSlot or 0
	return p.Slots
end

function Characters.Ensure(profile)
	local list = slots(profile)
	local p = profile.Permanent
	if #list == 0 and Character.Get(profile).Created then
		list[1] = { ClassId = profile.Season.ClassId }
		p.ActiveSlot = 1
	end
	if p.ActiveSlot > #list then
		p.ActiveSlot = 0
	end
end

function Characters.Active(profile)
	Characters.Ensure(profile)
	return profile.Permanent.ActiveSlot
end

function Characters.Enter(profile)
	entered[profile] = true
end

function Characters.Entered(profile)
	return entered[profile] == true
end

function Characters.List(profile)
	Characters.Ensure(profile)
	local active = profile.Permanent.ActiveSlot
	local out = {}
	for index, slot in ipairs(profile.Permanent.Slots) do
		local season = if index == active then profile.Season else slot.Season
		season = season or {}
		table.insert(out, {
			Slot = index, ClassId = slot.ClassId, Level = season.Level or 1, HighestStage = season.HighestStage or 1,
			SubclassId = season.Subclasses and season.Subclasses[slot.ClassId] or nil, Active = index == active,
		})
	end
	return out
end

function Characters.Create(profile, classId)
	Characters.Ensure(profile)
	local list = profile.Permanent.Slots
	if #list >= Characters.Max(profile) then
		return false, "Full"
	end
	if not Character.Playable(profile, classId) then
		return false, "BadClass"
	end
	local season = ProfileTemplate.NewSeasonData(SeasonClock.CurrentId())
	season.ClassId = classId
	ProfileTemplate.GrantClassStarters(season, classId)
	profile.Permanent.UnlockedClasses[classId] = true
	table.insert(list, { ClassId = classId, Season = season })
	return true, #list
end

function Characters.Select(profile, slot)
	Characters.Ensure(profile)
	local list = profile.Permanent.Slots
	if type(slot) ~= "number" or slot ~= math.floor(slot) or list[slot] == nil then
		return false, "BadSlot"
	end
	local active = profile.Permanent.ActiveSlot
	if slot ~= active then
		if active ~= 0 and list[active] then
			list[active].Season = profile.Season
		end
		profile.Season = list[slot].Season or ProfileTemplate.NewSeasonData(SeasonClock.CurrentId())
		list[slot].Season = nil
		profile.Season.ClassId = list[slot].ClassId
		profile.Permanent.ActiveSlot = slot
	end
	local c = Character.Get(profile)
	c.Created = true
	c.UseAvatar = true -- heroes wear the player's own Roblox avatar
	Gear.EnsureStarter(profile) -- every character owns a weapon
	return true
end

return Characters
