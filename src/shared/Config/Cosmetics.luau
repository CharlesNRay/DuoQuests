--[[
	Cosmetics (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Cosmetics

	Looks only: they never change power. Four slots, one equipped per slot:
	  Aura   a glow of particles around your hero
	  Kill   a burst when your party defeats an enemy (only you see yours in the fight scene)
	  Name   the colour of your name above your head (everyone sees it)
	  Title  a line above your name (Permanent.Titles holds the owned ones; see Titles below)

	Source:  "Shop"    bought with Sunstones (Cost)
	         "Season"  prizes from the end-of-season rewards (Config/SeasonRewards), never sold
	Prize ids for the CLASS prizes (Aura_<class>, Kill_<class>, Name_<class>) are made from ClassLooks at load.

	Look = { Color = {r,g,b}, Color2 = {r,g,b}? (a second colour mixed in), Rainbow = true? }
	Every number and colour is a first guess.
]]

local function item(id, slot, name, source, cost, color, extra)
	local def = { Id = id, Slot = slot, Name = name, Source = source, Cost = cost, Color = color }
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	return def
end

local Items = {
	-- Auras (shop)
	item("Aura_Flame", "Aura", "Flame aura", "Shop", 200, { 255, 120, 40 }, { Color2 = { 255, 60, 30 } }),
	item("Aura_Frost", "Aura", "Frost aura", "Shop", 200, { 150, 220, 255 }, { Color2 = { 220, 245, 255 } }),
	item("Aura_Nature", "Aura", "Nature aura", "Shop", 200, { 120, 220, 100 }, { Color2 = { 220, 255, 150 } }),
	item("Aura_Void", "Aura", "Void aura", "Shop", 250, { 140, 70, 220 }, { Color2 = { 30, 10, 60 } }),
	item("Aura_Starlight", "Aura", "Starlight aura", "Shop", 250, { 255, 240, 160 }, { Color2 = { 255, 255, 255 } }),
	item("Aura_Rainbow", "Aura", "Rainbow aura", "Shop", 400, { 255, 255, 255 }, { Rainbow = true }),
	-- Auras (season prizes)
	item("Aura_Champion", "Aura", "Champion aura", "Season", 0, { 255, 205, 70 }, { Color2 = { 255, 245, 190 } }),
	item("Aura_Silver", "Aura", "Silver aura", "Season", 0, { 200, 210, 225 }, { Color2 = { 255, 255, 255 } }),
	item("Aura_Bronze", "Aura", "Bronze aura", "Season", 0, { 205, 130, 70 }, { Color2 = { 255, 200, 140 } }),
	item("Aura_Elite", "Aura", "Elite aura", "Season", 0, { 120, 200, 255 }, { Color2 = { 200, 235, 255 } }),

	-- Kill effects (shop)
	item("Kill_Confetti", "Kill", "Confetti burst", "Shop", 150, { 255, 120, 200 }, { Rainbow = true }),
	item("Kill_Hearts", "Kill", "Hearts", "Shop", 150, { 255, 100, 140 }),
	item("Kill_Lightning", "Kill", "Lightning", "Shop", 200, { 255, 245, 120 }, { Color2 = { 150, 200, 255 } }),
	item("Kill_Petals", "Kill", "Petals", "Shop", 150, { 255, 170, 200 }, { Color2 = { 255, 230, 235 } }),
	item("Kill_Soulfire", "Kill", "Soulfire", "Shop", 300, { 110, 255, 200 }, { Color2 = { 40, 160, 255 } }),
	-- Kill effects (season prizes)
	item("Kill_Sparks", "Kill", "Sparks kill effect", "Season", 0, { 255, 220, 120 }, { Color2 = { 255, 150, 60 } }),

	-- Name colours (shop)
	item("Name_Gold", "Name", "Gold name", "Shop", 80, { 255, 210, 80 }),
	item("Name_Azure", "Name", "Azure name", "Shop", 80, { 110, 190, 255 }),
	item("Name_Rose", "Name", "Rose name", "Shop", 80, { 255, 130, 170 }),
	item("Name_Mint", "Name", "Mint name", "Shop", 80, { 130, 240, 180 }),
	item("Name_Violet", "Name", "Violet name", "Shop", 80, { 190, 140, 255 }),
	item("Name_Crimson", "Name", "Crimson name", "Shop", 80, { 235, 70, 70 }),
	item("Name_Rainbow", "Name", "Rainbow name", "Shop", 250, { 255, 255, 255 }, { Rainbow = true }),
	-- Name colours (season prizes)
	item("Name_Laurel", "Name", "Laurel name colour", "Season", 0, { 160, 220, 110 }),
}

-- Class prizes: a look per class for each slot (Source = "Season").
local ClassLooks = {
	Warrior = { { 230, 80, 70 }, { 255, 170, 120 } },
	Cleric = { { 255, 235, 150 }, { 255, 255, 255 } },
	Mage = { { 110, 150, 255 }, { 190, 150, 255 } },
}
local SlotNames = { Aura = "aura", Kill = "kill effect", Name = "name colour" }
for classId, colours in pairs(ClassLooks) do
	for slot, word in pairs(SlotNames) do
		table.insert(Items, item(slot .. "_" .. classId, slot, classId .. " " .. word, "Season", 0, colours[1], { Color2 = colours[2], Class = classId }))
	end
end

-- Titles bought with Sunstones (season-prize titles come from Config/SeasonRewards and are just saved strings).
local ShopTitles = {
	{ Id = "the Brave", Cost = 100 },
	{ Id = "Starseeker", Cost = 100 },
	{ Id = "Pet Whisperer", Cost = 100 },
	{ Id = "Wishbringer", Cost = 150 },
	{ Id = "the Unbroken", Cost = 150 },
}

return {
	Slots = { "Aura", "Kill", "Name", "Title" },
	SlotLabels = { Aura = "Auras", Kill = "Kill effects", Name = "Name colours", Title = "Titles" },
	Items = Items,
	ShopTitles = ShopTitles,
}
