-- Relic probe: every town relic and the other prompt spots within 16 studs of it (town prompts reach 14 studs and only
-- one E prompt shows at a time, so a relic close to another prompt may be impossible to pick up).
-- Run: py -3 sync.py, copy into .build/hl6, luau relicprobe.luau
local World = require("./World")
local relics, others = {}, {}
for id in pairs(World.TownSpots) do
	if id:sub(1, 5) == "Relic" then table.insert(relics, id) else table.insert(others, id) end
end
table.sort(relics)
for _, r in ipairs(relics) do
	local rx, rz = World.TownSpot(r)
	local near = {}
	for _, o in ipairs(others) do
		local ok, ox, oz = pcall(World.TownSpot, o)
		if ok and ox then
			local d = math.sqrt((rx - ox) ^ 2 + (rz - oz) ^ 2)
			if d < 16 then table.insert(near, ("%s %.1f"):format(o, d)) end
		end
	end
	for name in pairs(World.PlazaSpots or {}) do
		local ok, px, pz = pcall(World.PlazaPoint, name)
		if ok and px then
			local d = math.sqrt((rx - px) ^ 2 + (rz - pz) ^ 2)
			if d < 16 then table.insert(near, ("plaza %s %.1f"):format(name, d)) end
		end
	end
	print(r, ("%.0f,%.0f"):format(rx, rz), table.concat(near, ", "))
end
