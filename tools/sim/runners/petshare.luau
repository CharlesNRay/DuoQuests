local P = require("./ProfileTemplate"); local Bosses = require("./Bosses"); local FS = require("./FightStats"); local Cfg = require("./Config/Bosses")
local function run(sub, level, petId, stage)
	local p = P.New()
	p.Season.ClassId = "Ranger"; p.Season.Level = level; p.Season.HighestStage = stage
	p.Season.Subclasses = { Ranger = sub }
	p.Permanent.Pets[petId] = true; p.Season.ActivePet = petId
	local d, secs, fight = Bosses.Challenge({ { Id = "1", Name = "A", Profile = p } }, Cfg.World, stage, 5, true)
	local st = FS.Compute(fight)
	local hero, pet = 0, 0
	for _, r in ipairs(st.Rows) do if r.Kind == "Pet" then pet += r.Damage elseif r.Kind == "Hero" then hero += r.Damage end end
	print(sub, petId, level, "total", d, "hero", math.floor(hero), "pet", math.floor(pet), "pet share", math.floor(pet / math.max(1, hero + pet) * 100) .. "%")
end
for _, lv in ipairs({ 10, 30, 60 }) do
	for _, petId in ipairs({ "Foxling", "Arcanix" }) do
		run("Sharpshooter", lv, petId, lv); run("Beastmaster", lv, petId, lv)
	end
end
