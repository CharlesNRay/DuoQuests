--[[
	ClassMastery (ModuleScript): per-class mastery that carries across seasons (Config/ClassMastery).

	  ClassMastery.Of(profile, classId)          -> { Level, XP, Need } (Need = XP for the next level, nil at the cap)
	  ClassMastery.Add(profile, classId, xp)     -> levels gained; grants the class titles
	  ClassMastery.OnClear(profile, stage, isFrontier, firstBoss)  mastery XP for a won stage (Progression.ApplyClear calls it)
	  ClassMastery.Mods(profile, classId)        -> { { Stat, Mode, Value } } the class's perks (ExtraMods)
	  ClassMastery.Status(profile)               -> every class's row for the Mastery screen

	Saved in Permanent.Mastery[classId] = { Level, XP } (string keys).
]]
local Config = require(script.Parent.Config.ClassMastery)
local Classes = require(script.Parent.Config.Classes)

local ClassMastery = {}

function ClassMastery.XPToNext(level)
	if level >= Config.MaxLevel then
		return nil
	end
	return Config.XPBase + Config.XPPerLevel * level
end

local function row(profile, classId)
	local perm = profile.Permanent
	perm.Mastery = perm.Mastery or {}
	local r = perm.Mastery[classId]
	if not r then
		r = { Level = 0, XP = 0 }
		perm.Mastery[classId] = r
	end
	return r
end

function ClassMastery.Of(profile, classId)
	local r = (profile.Permanent.Mastery or {})[classId] or { Level = 0, XP = 0 }
	return { Level = r.Level, XP = r.XP, Need = ClassMastery.XPToNext(r.Level) }
end

local function className(classId)
	local def = Classes[classId]
	return (def and def.DisplayName) or classId
end

function ClassMastery.TitleFor(classId, level)
	local best
	for _, t in ipairs(Config.Titles) do
		if level >= t.Level then
			best = className(classId) .. " " .. t.Suffix
		end
	end
	return best
end

function ClassMastery.Add(profile, classId, xp)
	if not classId or not Classes[classId] or (xp or 0) <= 0 then
		return 0
	end
	local r = row(profile, classId)
	if r.Level >= Config.MaxLevel then
		return 0
	end
	r.XP += xp
	local gained = 0
	while r.Level < Config.MaxLevel and r.XP >= ClassMastery.XPToNext(r.Level) do
		r.XP -= ClassMastery.XPToNext(r.Level)
		r.Level += 1
		gained += 1
		for _, t in ipairs(Config.Titles) do
			if r.Level == t.Level then
				profile.Permanent.Titles = profile.Permanent.Titles or {}
				profile.Permanent.Titles[className(classId) .. " " .. t.Suffix] = true
			end
		end
	end
	if r.Level >= Config.MaxLevel then
		r.XP = 0
	end
	return gained
end

function ClassMastery.OnClear(profile, isFrontier, isBoss)
	local classId = profile.Season.ClassId
	local xp = 0
	if isFrontier then
		xp += Config.XP.Frontier
		if isBoss then
			xp += Config.XP.Boss
		end
	end
	return ClassMastery.Add(profile, classId, xp)
end

function ClassMastery.PerkValue(level)
	return Config.PerkValue * (math.min(level, Config.MaxLevel) // Config.PerkEvery)
end

function ClassMastery.Mods(profile, classId)
	local v = ClassMastery.PerkValue(ClassMastery.Of(profile, classId or profile.Season.ClassId).Level)
	local mods = {}
	if v > 0 then
		for _, stat in ipairs(Config.PerkStats) do
			table.insert(mods, { Stat = stat, Mode = "Mul", Value = v })
		end
	end
	return mods
end

function ClassMastery.Status(profile)
	local out = { Classes = {}, MaxLevel = Config.MaxLevel, PerkEvery = Config.PerkEvery, PerkValue = Config.PerkValue, XP = Config.XP, Titles = Config.Titles }
	for classId, def in pairs(Classes) do
		if type(def) == "table" and def.AbilityPool then
			local m = ClassMastery.Of(profile, classId)
			table.insert(out.Classes, {
				ClassId = classId, Name = className(classId), Level = m.Level, XP = m.XP, Need = m.Need,
				Perk = ClassMastery.PerkValue(m.Level), Title = ClassMastery.TitleFor(classId, m.Level),
				Current = profile.Season.ClassId == classId,
			})
		end
	end
	table.sort(out.Classes, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

return ClassMastery
